//! Thin C ABI over vodozemac. ALL ratchets and their 3DH handshake are
//! provided by the audited Apache-2.0 vodozemac crate, not custom crypto.
//! The caller provides a random 32-byte key from OS secure storage. Every
//! returned account/session pickle is encrypted by vodozemac before crossing
//! the Dart FFI boundary. NEVER log requests, responses or pickle keys.

use base64::{engine::general_purpose::STANDARD as BASE64, Engine as _};
use serde_json::{json, Value};
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::panic::{catch_unwind, AssertUnwindSafe};
use vodozemac::{
    Curve25519PublicKey,
    olm::{Account, AccountPickle, OlmMessage, Session, SessionConfig, SessionPickle},
    megolm::{GroupSession, GroupSessionPickle, InboundGroupSession,
        InboundGroupSessionPickle, MegolmMessage, SessionConfig as GroupConfig,
        SessionKey},
};

type CryptoResult<T> = Result<T, &'static str>;

fn required<'a>(v: &'a Value, key: &str) -> CryptoResult<&'a str> {
    v.get(key).and_then(Value::as_str).ok_or("missing_required_field")
}

fn key(v: &Value) -> CryptoResult<[u8; 32]> {
    let bytes = BASE64.decode(required(v, "pickle_key_b64")?)
        .map_err(|_| "invalid_state_key")?;
    bytes.try_into().map_err(|_| "invalid_state_key_length")
}

fn b64(v: &Value, name: &str) -> CryptoResult<Vec<u8>> {
    BASE64.decode(required(v, name)?).map_err(|_| "invalid_base64")
}

fn account(v: &Value, k: &[u8; 32]) -> CryptoResult<Account> {
    let pickle = AccountPickle::from_encrypted(
        required(v, "account_pickle")?, k
    ).map_err(|_| "invalid_account_pickle")?;
    Ok(Account::from_pickle(pickle))
}

fn session(v: &Value, k: &[u8; 32]) -> CryptoResult<Session> {
    let pickle = SessionPickle::from_encrypted(
        required(v, "session_pickle")?, k
    ).map_err(|_| "invalid_session_pickle")?;
    Ok(Session::from_pickle(pickle))
}

fn curve(v: &Value, name: &str) -> CryptoResult<Curve25519PublicKey> {
    Curve25519PublicKey::from_slice(&b64(v, name)?)
        .map_err(|_| "invalid_curve25519_key")
}

fn handle(v: &Value) -> CryptoResult<Value> {
    let command = required(v, "op")?;
    if command == "bridge_version" {
        return Ok(json!({"abi":1,"crypto":"vodozemac","version":"0.11.1"}));
    }
    let k = key(v)?;
    match command {
        "account_create" => {
            let device = required(v, "device_id")?;
            let mut a = Account::new();
            a.generate_one_time_keys(24);
            let identity = a.identity_keys();
            let curve_bytes = identity.curve25519.to_bytes();
            let ed_bytes = identity.ed25519.to_bytes();
            let mut sign_bytes = format!(
                "orbit-m13-signed-prekey-v1|{}|1|", device
            ).into_bytes();
            sign_bytes.extend_from_slice(&curve_bytes);
            let signature = a.sign(&sign_bytes);
            let mut public_keys: Vec<String> = a.one_time_keys().values()
                .map(|p| BASE64.encode(p.to_bytes())).collect();
            public_keys.sort();
            let published: Vec<Value> = public_keys.iter().enumerate()
                .map(|(i, p)| json!({
                    "key_id": i + 1,
                    "public_x25519": p
                })).collect();
            a.mark_keys_as_published();
            Ok(json!({
                "account_pickle": a.pickle().encrypt(&k),
                "identity_ed25519": BASE64.encode(ed_bytes),
                "signed_prekey_x25519": BASE64.encode(curve_bytes),
                "signed_prekey_signature": BASE64.encode(signature.to_bytes()),
                "signed_prekey_id": 1,
                "one_time_prekeys": published,
            }))
        }
        "session_outbound" => {
            let a = account(v, &k)?;
            let peer_identity = curve(v, "recipient_curve_b64")?;
            let otp = curve(v, "recipient_one_time_b64")?;
            let s = a.create_outbound_session(
                SessionConfig::version_1(), peer_identity, otp
            ).map_err(|_| "session_creation_failed")?;
            Ok(json!({
                "session_pickle": s.pickle().encrypt(&k),
                "session_id": s.session_id(),
            }))
        }
        "session_encrypt" => {
            let mut s = session(v, &k)?;
            let clear = b64(v, "plaintext_b64")?;
            let m = s.encrypt(&clear).map_err(|_| "olm_encrypt_failed")?;
            let (kind, body) = m.to_parts();
            Ok(json!({
                "session_pickle": s.pickle().encrypt(&k),
                "session_id": s.session_id(),
                "message_type": kind,
                "ciphertext_b64": BASE64.encode(body),
            }))
        }
        "session_inbound" => {
            let mut a = account(v, &k)?;
            let peer = curve(v, "sender_curve_b64")?;
            let kind = v.get("message_type").and_then(Value::as_u64)
                .ok_or("invalid_message_type")? as usize;
            if kind != 0 { return Err("inbound_session_requires_prekey"); }
            let m = OlmMessage::from_parts(kind, &b64(v, "ciphertext_b64")?)
                .map_err(|_| "invalid_olm_message")?;
            let OlmMessage::PreKey(prekey) = m else {
                return Err("inbound_session_requires_prekey");
            };
            let inbound = a.create_inbound_session(
                SessionConfig::version_1(), peer, &prekey
            ).map_err(|_| "olm_inbound_failed")?;
            Ok(json!({
                "account_pickle": a.pickle().encrypt(&k),
                "session_pickle": inbound.session.pickle().encrypt(&k),
                "session_id": inbound.session.session_id(),
                "plaintext_b64": BASE64.encode(inbound.plaintext),
            }))
        }
        "session_decrypt" => {
            let mut s = session(v, &k)?;
            let kind = v.get("message_type").and_then(Value::as_u64)
                .ok_or("invalid_message_type")? as usize;
            let m = OlmMessage::from_parts(kind, &b64(v, "ciphertext_b64")?)
                .map_err(|_| "invalid_olm_message")?;
            let clear = s.decrypt(&m).map_err(|_| "olm_authentication_failed")?;
            Ok(json!({
                "session_pickle": s.pickle().encrypt(&k),
                "session_id": s.session_id(),
                "plaintext_b64": BASE64.encode(clear),
            }))
        }
        "group_create" => {
            let group = GroupSession::new(GroupConfig::version_1());
            Ok(json!({
                "session_id": group.session_id(),
                "group_pickle": group.pickle().encrypt(&k),
                "session_key": group.session_key().to_base64(),
            }))
        }
        "group_encrypt" => {
            let pickle = GroupSessionPickle::from_encrypted(
                required(v, "group_pickle")?, &k
            ).map_err(|_| "invalid_group_pickle")?;
            let mut group = GroupSession::from_pickle(pickle);
            let clear = b64(v, "plaintext_b64")?;
            let m = group.encrypt(&clear);
            Ok(json!({
                "session_id": group.session_id(),
                "group_pickle": group.pickle().encrypt(&k),
                "message_b64": m.to_base64(),
            }))
        }
        "group_import" => {
            let session_key = SessionKey::from_base64(
                required(v, "session_key")?
            ).map_err(|_| "invalid_group_session_key")?;
            let inbound = InboundGroupSession::new(
                &session_key, GroupConfig::version_1()
            );
            Ok(json!({
                "inbound_pickle": inbound.pickle().encrypt(&k),
            }))
        }
        "group_decrypt" => {
            let pickle = InboundGroupSessionPickle::from_encrypted(
                required(v, "inbound_pickle")?, &k
            ).map_err(|_| "invalid_inbound_group_pickle")?;
            let mut inbound = InboundGroupSession::from_pickle(pickle);
            let msg = MegolmMessage::from_base64(
                required(v, "message_b64")?
            ).map_err(|_| "invalid_group_message")?;
            let result = inbound.decrypt(&msg)
                .map_err(|_| "group_authentication_failed")?;
            Ok(json!({
                "inbound_pickle": inbound.pickle().encrypt(&k),
                "plaintext_b64": BASE64.encode(result.plaintext),
                "message_index": result.message_index,
            }))
        }
        _ => Err("unsupported_crypto_operation"),
    }
}

fn response(value: Result<Value, &'static str>) -> *mut c_char {
    let result = match value {
        Ok(v) => json!({"ok": true, "value": v}),
        Err(e) => json!({"ok": false, "error": e}),
    };
    let serialized = result.to_string();
    CString::new(serialized)
        .expect("serde_json never writes an unescaped NUL")
        .into_raw()
}

/// UTF-8 JSON RPC; request includes encrypted account/session pickles, key
/// material from OS storage and plaintext only for the duration of this call.
/// Never save either the request buffer or returned raw plaintext.
#[no_mangle]
pub unsafe extern "C" fn orbit_vodozemac_call(
    request: *const c_char,
) -> *mut c_char {
    let value = catch_unwind(AssertUnwindSafe(|| {
        if request.is_null() { return Err("null_crypto_request"); }
        let bytes = CStr::from_ptr(request).to_bytes();
        if bytes.len() > 1_000_000 { return Err("crypto_request_too_large"); }
        let decoded: Value = serde_json::from_slice(bytes)
            .map_err(|_| "invalid_crypto_request")?;
        handle(&decoded)
    }));
    match value {
        Ok(outcome) => response(outcome),
        Err(_) => response(Err("native_crypto_error")),
    }
}

/// Free every bridge result with the same Rust allocator that created it.
#[no_mangle]
pub unsafe extern "C" fn orbit_vodozemac_free(ptr: *mut c_char) {
    if !ptr.is_null() {
        drop(CString::from_raw(ptr));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn olm_double_ratchet_roundtrip_and_rejects_modified_ciphertext() {
        let alice = Account::new();
        let mut bob = Account::new();
        bob.generate_one_time_keys(1);
        let one_time = *bob.one_time_keys().values()
            .next().expect("created a one-time prekey");
        let mut outgoing = alice.create_outbound_session(
            SessionConfig::version_1(),bob.curve25519_key(),one_time
        ).expect("created authenticated Olm session");
        let prekey = outgoing.encrypt(b"first confidential message")
            .expect("encrypted with Olm");
        let OlmMessage::PreKey(pre) = prekey else {
            panic!("first Olm message must carry prekey metadata");
        };
        let incoming = bob.create_inbound_session(
            SessionConfig::version_1(),alice.curve25519_key(),&pre
        ).expect("created matching authenticated receive session");
        assert_eq!(incoming.plaintext,b"first confidential message");
        let mut receiver=incoming.session;
        let reply=receiver.encrypt(b"reply from receiver")
            .expect("Double Ratchet reply");
        assert_eq!(outgoing.decrypt(&reply).expect("authenticated reply"),
            b"reply from receiver");
        let mut altered=reply.to_parts().1;
        if altered.len()>8 { altered[8]^=0x40; }
        let forged=OlmMessage::from_parts(reply.message_type() as usize,&altered);
        if let Ok(m)=forged {
            assert!(outgoing.decrypt(&m).is_err());
        }
    }

    #[test]
    fn megolm_sender_key_rotation_excludes_previous_epoch() {
        let mut previous=GroupSession::new(GroupConfig::version_1());
        let mut oldRecipient=InboundGroupSession::new(
            &previous.session_key(),GroupConfig::version_1());
        let oldMessage=previous.encrypt(b"before roster change");
        assert_eq!(oldRecipient.decrypt(&oldMessage)
            .expect("first group key").plaintext,b"before roster change");

        // Must create an entirely unrelated sender ratchet on roster change.
        let mut rotated=GroupSession::new(GroupConfig::version_1());
        assert_ne!(previous.session_id(),rotated.session_id());
        let newMessage=rotated.encrypt(b"after member removal");
        assert!(oldRecipient.decrypt(&newMessage).is_err());
        let mut remaining=InboundGroupSession::new(
            &rotated.session_key(),GroupConfig::version_1());
        assert_eq!(remaining.decrypt(&newMessage)
            .expect("remaining member has new key").plaintext,
            b"after member removal");
    }

    #[test]
    fn ffi_validates_input_and_never_unwraps_a_client_panic() {
        let bad=CString::new("{not-json").unwrap();
        let response=unsafe {orbit_vodozemac_call(bad.as_ptr())};
        assert!(!response.is_null());
        let text=unsafe {CStr::from_ptr(response)}.to_str().unwrap().to_owned();
        unsafe {orbit_vodozemac_free(response)};
        assert!(text.contains("\\"ok\\":false"));
    }
}

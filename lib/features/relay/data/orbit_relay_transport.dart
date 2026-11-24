import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'orbit_relay_protocol.dart';

typedef RelaySign=Future<String> Function(String message);
typedef RelayAccept=Future<Map<String,Object?>> Function(Map<String,dynamic> packet,String transcript);
typedef RelayPeer=({String host,int port});

/// Native Android NSD / iOS Bonjour discovery. No stable identifier, lease,
/// name, public key or message is included in the published service record.
class OrbitRelayDiscovery {
  static const _channel=MethodChannel('orbit/relay_discovery');
  Future<void> start(int port)=>_channel.invokeMethod<void>('start',{'name':'o-'+relayNonce().substring(0,24),'port':port});
  Future<List<RelayPeer>> peers() async {
    final list=await _channel.invokeListMethod<Object?>('peers')??[];
    return list.whereType<Map>().map((v)=>(host:v['host'] as String,port:v['port'] as int))
      .where((v)=>relayLocalAddress(v.host)&&v.port>=1024&&v.port<=65535).take(24).toList();
  }
  Future<void> stop()=>_channel.invokeMethod<void>('stop');
}
bool relayLocalAddress(String host){
  final ip=InternetAddress.tryParse(host);
  if(ip==null||ip.type!=InternetAddressType.IPv4)return false;
  final bytes=ip.rawAddress;
  return bytes[0]==10||(bytes[0]==172&&bytes[1]>=16&&bytes[1]<=31)||
    (bytes[0]==192&&bytes[1]==168)||(bytes[0]==169&&bytes[1]==254);
}
/// Length-prefixed, bounded TCP frames over actual local OS sockets.
/// Reject malformed/oversized frames before decoding, never log payloads.
class _Wire {
  _Wire(this.socket):_stream=StreamIterator<Uint8List>(socket);
  final Socket socket;
  final StreamIterator<Uint8List> _stream;
  Uint8List _current=Uint8List(0);
  int _offset=0;
  static const maxFrame=150000;
  Future<Uint8List> _take(int n) async {
    final out=Uint8List(n);
    var written=0;
    while(written<n){
      if(_offset==_current.length){
        relayCheck(await _stream.moveNext().timeout(const Duration(seconds:5)),'Relay connection closed.');
        _current=_stream.current;_offset=0;
      }
      final count=(n-written).clamp(0,_current.length-_offset).toInt();
      out.setRange(written,written+count,_current,_offset);
      written+=count;_offset+=count;
    }
    return out;
  }
  Future<Map<String,dynamic>> receive() async {
    final len=ByteData.sublistView(await _take(4)).getUint32(0);
    relayCheck(len>0&&len<=maxFrame,'Relay frame too large.');
    return relayMap(jsonDecode(utf8.decode(await _take(len))));
  }
  Future<void> send(Map<String,Object?> value) async {
    final data=utf8.encode(jsonEncode(value));
    relayCheck(data.isNotEmpty&&data.length<=maxFrame,'Relay frame too large.');
    final length=ByteData(4)..setUint32(0,data.length);
    socket.add(length.buffer.asUint8List());socket.add(data);
    await socket.flush().timeout(const Duration(seconds:5));
  }
  Future<void> close() async {socket.destroy();await _stream.cancel();}
}
class _Channel {
  _Channel(this.wire,this.secret,this.transcript,this.sender);
  final _Wire wire;
  final SecretKey secret;
  final String transcript;
  final bool sender;
  final _cipher=AesGcm.with256bits();
  int _out=0,_in=0;
  List<int> _aad(bool outbound,int sequence)=>utf8.encode(
    'orbit-relay-channel-v1|$transcript|'+((outbound==sender)?'s':'r')+'|$sequence');
  Future<void> send(Map<String,Object?> packet) async {
    final box=await _cipher.encrypt(utf8.encode(jsonEncode(packet)),secretKey:secret,aad:_aad(true,_out++));
    await wire.send({'n':base64Encode(box.nonce),'c':base64Encode(box.cipherText),'m':base64Encode(box.mac.bytes)});
  }
  Future<Map<String,dynamic>> receive() async {
    final raw=await wire.receive();
    final box=SecretBox(base64Decode(raw['c'] as String),
      nonce:relayBytes(raw['n'] as String,12),mac:Mac(relayBytes(raw['m'] as String,16)));
    return relayMap(jsonDecode(utf8.decode(await _cipher.decrypt(box,secretKey:secret,aad:_aad(false,_in++)))));
  }
}
/// Same-LAN/hotspot socket transport, not an internet proxy. Ephemeral
/// X25519/HKDF + AEAD protect the lease/metadata. Receiver proves its M13
/// identity before any sender lease or ciphertext is disclosed.
class OrbitRelayTransport {
  OrbitRelayTransport({OrbitRelayDiscovery? discovery}):_discovery=discovery??OrbitRelayDiscovery();
  final OrbitRelayDiscovery _discovery;
  ServerSocket? _server;
  final Set<Socket> _active={};
  Timer? _expiry;
  bool get running=>_server!=null;
  // Test discovery uses the same real sockets on a private interface.
  int? get localPort=>_server?.port;
  Future<_Channel> _open(_Wire wire,bool sender) async {
    final x=X25519(),key=await x.newKeyPair(),pub=await key.extractPublicKey();
    final own=base64Encode(pub.bytes);
    late String remote;
    if(sender){
      await wire.send({'v':1,'ephemeral':own});
      final hello=await wire.receive();relayCheck(hello['v']==1,'Relay protocol mismatch.');
      remote=hello['ephemeral'] as String;
    }else{
      final hello=await wire.receive();relayCheck(hello['v']==1,'Relay protocol mismatch.');
      remote=hello['ephemeral'] as String;
      await wire.send({'v':1,'ephemeral':own});
    }
    final transcript=relayHash(sender?[own,remote]:[remote,own]);
    final shared=await x.sharedSecretKey(keyPair:key,
      remotePublicKey:SimplePublicKey(relayBytes(remote,32),type:KeyPairType.x25519));
    final secret=await Hkdf(hmac:Hmac.sha256(),outputLength:32).deriveKey(
      secretKey:shared,nonce:utf8.encode(transcript),info:utf8.encode('orbit-relay-channel-v1'));
    return _Channel(wire,secret,transcript,sender);
  }
  Future<void> start({required RelaySign sign,required RelayAccept accept,
      Duration duration=const Duration(minutes:10)}) async {
    await stop();
    final server=await ServerSocket.bind(InternetAddress.anyIPv4,0,shared:false);
    _server=server;
    _expiry=Timer(duration,()=>unawaited(stop()));
    server.listen((socket){
      if(_server!=server||_active.length>=4||!relayLocalAddress(socket.remoteAddress.address)){
        socket.destroy();return;
      }
      _active.add(socket);
      unawaited(_receive(socket,sign,accept));
    },onError:(_){unawaited(stop());});
    try{await _discovery.start(server.port);}catch(_){await stop();rethrow;}
  }
  Future<void> _receive(Socket socket,RelaySign sign,RelayAccept accept) async {
    final wire=_Wire(socket);
    try{
      await (() async {
        final channel=await _open(wire,false);
        await channel.send({'proof':await sign('orbit-relay-peer-v1|'+channel.transcript)});
        final packet=await channel.receive();
        final receipt=await accept(packet,channel.transcript);
        await channel.send(receipt);
      })().timeout(const Duration(seconds:15));
    }catch(_){/* No receipt for invalid peer or incomplete transfer. */}
    finally{_active.remove(socket);await wire.close();}
  }
  Future<Map<String,dynamic>?> transfer(OrbitRelayLease lease,
      Map<String,Object?> packet,RelaySign sign) async {
    if(!running)return null;
    final peers=await _discovery.peers();
    for(final peer in peers.take(8)){
      if(!running)return null;
      if(!relayLocalAddress(peer.host)||peer.port<1024||peer.port>65535)continue;
      Socket? socket;_Wire? wire;
      try{
        socket=await Socket.connect(peer.host,peer.port,timeout:const Duration(seconds:2));
        if(!running){socket.destroy();return null;}
        _active.add(socket);
        wire=_Wire(socket);
        final result=await (() async {
          final channel=await _open(wire!,true);
          final proof=await channel.receive();
          relayCheck(await relayVerify('orbit-relay-peer-v1|'+channel.transcript,
            proof['proof'] as String,lease.peerKey),'Unrecognized Relay peer.');
          final signature=await sign('orbit-relay-sender-v1|'+channel.transcript+'|'+lease.id+'|'+
            (packet['envelope_id'] as String)+'|'+(packet['digest'] as String)+'|'+(packet['peer_digest'] as String));
          await channel.send({...packet,'sender_proof':signature});
          return channel.receive();
        })().timeout(const Duration(seconds:15));
        return result;
      }catch(_){/* Try only bounded local endpoints; never disclose to an unverified peer. */}
      finally{if(socket!=null)_active.remove(socket);if(wire!=null){await wire.close();}else{socket?.destroy();}}
    }
    return null;
  }
  Future<void> stop() async {
    _expiry?.cancel();_expiry=null;
    final server=_server;_server=null;
    for(final socket in _active){socket.destroy();}
    _active.clear();await server?.close();
    try{await _discovery.stop();}catch(_){}
  }
}

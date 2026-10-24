#!/usr/bin/env python3
"""Fail-closed prerequisite checker for Orbit's *signed* native M5 release.

This script never accesses signing secrets or Firebase, and never signs or
publishes anything. Use real credentials in CI secrets or the release machine.
"""
import os
import re
import sys
from pathlib import Path


def val(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise ValueError(f"Required environment variable missing: {name}")
    return value


def android() -> None:
    package = val("ORBIT_ANDROID_APPLICATION_ID")
    if package.startswith("com.example.") or not re.fullmatch(
        r"[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+", package
    ):
        raise ValueError("Android production package must be non-placeholder.")
    signing = Path(val("ORBIT_ANDROID_KEYSTORE_PATH"))
    if not signing.is_file():
        raise ValueError("Android signing keystore must exist outside the repository.")
    for key in (
        "ORBIT_ANDROID_KEYSTORE_PASSWORD",
        "ORBIT_ANDROID_KEY_ALIAS",
        "ORBIT_ANDROID_KEY_PASSWORD",
    ):
        val(key)
    published_package = val("ORBIT_ANDROID_PACKAGE")
    if package != published_package:
        raise ValueError("Android app ID differs from Firebase/assetlinks backend package.")
    fingerprint = val("ORBIT_ANDROID_SHA256")
    if not re.fullmatch(r"(?:[0-9A-Fa-f]{2}:){31}[0-9A-Fa-f]{2}", fingerprint):
        raise ValueError("Missing valid release certificate SHA-256 fingerprint.")
    print("Android release identity prerequisites present; signing and device tests remain.")


def ios() -> None:
    team = val("ORBIT_IOS_TEAM_ID")
    bundle = val("ORBIT_IOS_BUNDLE_ID")
    if not re.fullmatch(r"[A-Z0-9]{10}", team):
        raise ValueError("Apple Team ID must be exactly 10 alphanumeric characters.")
    if bundle.lower().startswith("com.example.") or not re.fullmatch(
        r"[A-Za-z][A-Za-z0-9-]*(?:\.[A-Za-z][A-Za-z0-9-]*)+", bundle
    ):
        raise ValueError("iOS Bundle ID must be non-placeholder.")
    if val("ORBIT_IOS_APP_ID") != f"{team}.{bundle}":
        raise ValueError("iOS app ID does not match the AASA backend identifier.")
    print("iOS identity prerequisites present; Apple signing/device tests remain.")


if __name__ == "__main__":
    try:
        if len(sys.argv) != 2 or sys.argv[1] not in ("android", "ios"):
            raise ValueError("Usage: python3 scripts/m5_native_release_preflight.py android|ios")
        {"android": android, "ios": ios}[sys.argv[1]]()
    except ValueError as error:
        print(f"Orbit native release BLOCKED: {error}", file=sys.stderr)
        sys.exit(1)

# /// script
# dependencies = ["pyjwt", "cryptography", "requests"]
# ///
"""App Store Connect のバージョン状態と IAP 状態を表示する。

使い方:
  ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_KEY_PATH=~/Downloads/AuthKey_XXXX.p8 \
    uv run scripts/asc_version_state.py

環境変数は fastlane の beta レーンと同じ ASC_KEY_ID / ASC_ISSUER_ID を使う。
鍵は ASC_KEY_PATH の .p8 ファイルから読む(値を環境変数に載せない)。
"""

import os
import sys
import time
from pathlib import Path

import jwt
import requests

APP_ID = "6761187661"
API = "https://api.appstoreconnect.apple.com"


def token() -> str:
    key_id = os.environ["ASC_KEY_ID"]
    issuer = os.environ["ASC_ISSUER_ID"]
    key = Path(os.path.expanduser(os.environ["ASC_KEY_PATH"])).read_text()
    now = int(time.time())
    return jwt.encode(
        {"iss": issuer, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
        key,
        algorithm="ES256",
        headers={"kid": key_id},
    )


def main() -> int:
    headers = {"Authorization": f"Bearer {token()}"}

    versions = requests.get(
        f"{API}/v1/apps/{APP_ID}/appStoreVersions",
        params={"limit": 5, "fields[appStoreVersions]": "versionString,appStoreState,releaseType"},
        headers=headers,
        timeout=30,
    )
    versions.raise_for_status()
    print("App Store versions:")
    for v in versions.json()["data"]:
        a = v["attributes"]
        print(f"  {a['versionString']:>6} | {a['appStoreState']:<28} | release={a.get('releaseType')}")

    iaps = requests.get(
        f"{API}/v1/apps/{APP_ID}/inAppPurchasesV2",
        params={"fields[inAppPurchases]": "name,productId,state"},
        headers=headers,
        timeout=30,
    )
    iaps.raise_for_status()
    print("In-app purchases:")
    for p in iaps.json()["data"]:
        a = p["attributes"]
        print(f"  {a['name']:<8} | {a['productId']:<32} | {a['state']}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyError as e:
        print(f"環境変数が未設定: {e}", file=sys.stderr)
        sys.exit(2)

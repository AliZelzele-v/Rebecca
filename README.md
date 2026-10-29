<p align="center"><img src="assets/images/rebecca.png" width="160" alt="Rebecca logo" /></p>

# Rebecca · ربکا

**0.0.2** · A black-and-white proxy client based on the full official [Hiddify App source](https://github.com/hiddify/hiddify-app).

[![Android build](https://github.com/AliZelzele-v/Rebecca/actions/workflows/rebecca-android.yml/badge.svg)](https://github.com/AliZelzele-v/Rebecca/actions/workflows/rebecca-android.yml)

## What changed

- Rebecca name, R artwork, splash screen, launcher and notification branding.
- Black default appearance, monochrome controls and typography.
- Configurations are grouped by subscription. Expand a group to see its servers directly underneath it, including while disconnected.
- Traffic usage and expiry use the original subscription metadata. Delay testing and selection use the actual VPN core; there are no simulated pings or connections.
- Selecting a server activates its subscription and connects through the original engine. The UI waits for the core before applying a selection and reports a timeout if that fails.
- Android application ID: `app.rebecca.vpn`. Display version: `0.0.2`, build number: `2`.

## Android download

Open [Rebecca Android builds](https://github.com/AliZelzele-v/Rebecca/actions/workflows/rebecca-android.yml), choose a **successful** run and download the `Rebecca-0.0.2-Android` artifact. Extract its ZIP and choose the APK for your architecture; most recent Android phones use `arm64-v8a`. These are individual installable APKs, not an APK bundle requiring a special installer. GitHub may require sign-in for artifact downloads. A running or failed job does not provide a verified APK.

The workflow currently uses the upstream debug signing fallback when no release keystore is configured. Production distribution needs a stable owner-controlled signing key. Desktop and Apple source projects are retained; this fork currently validates Android builds only.

## Using subscriptions

1. Add your provider's subscription link using the existing add/import controls.
2. Open **Configurations / پیکربندی‌ها**.
3. Expand a subscription and tap a server. Group controls retain upstream update, edit, export and delete actions.
4. Grant Android's VPN permission when prompted. Connection status comes from the real engine.

Rebecca does not create a VPN server or operate an account service. A valid server or subscription is required.

## Build from source

Use Flutter **3.38.5**, Java **17** and the Android SDK. The Android core artifact and its SHA-256 are pinned in `dependencies/rebecca-android-core.json`. Upstream main requires its newer development bridge interfaces; the older stable `core.version` artifact is incompatible with that source. Python 3.12 or newer is required for safe archive extraction.

```sh
flutter pub get
make common-prepare
python3 scripts/prepare_android_core.py
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test test/features/profile/profile_nodes_test.dart test/features/profile/rebecca_theme_test.dart
flutter build apk --release --split-per-abi --target lib/main_prod.dart --build-name 0.0.2 --build-number 2
```

The GitHub Actions workflow executes preparation, generation, analysis, tests and compilation. Source imports and native bridge namespaces retain their original internal names so engine integration remains compatible.

## Upstream and license

Rebecca is a public fork of Hiddify App, based on upstream commit `c174e46ec523337b81158639307e6dddd118e5df`. The original protocol engines, import formats, subscription updating, routing and settings remain upstream implementations.

Copyright and credit belong to Hiddify and its contributors for their original work. Rebecca modifications retain the same [Hiddify Extended GPLv3 license](LICENSE.md). See [privacy information](PRIVACY.md) and [original upstream documentation](docs/UPSTREAM_README.md). Upstream documentation links and screenshots describe Hiddify; they are preserved for technical reference.

## Owner-signed updates

Publish through **Rebecca Android → Run workflow → publish=true**. For an already successful build of the exact current commit, **Publish verified Rebecca APKs** signs and publishes that run without compiling it again. Production publication requires the private repository secret `REBECCA_ANDROID_SIGNING`; `scripts/prepare_rebecca_signing.py` consumes the encrypted PKCS#12 keystore and never commits it. Publishing is blocked without this secret. The owner must retain an offline backup. Never put a signing key or its password into Git.

The publisher creates `update.json`, per-ABI APKs and compact `.rbkpatch` assets from a previous signed release. The client announces a new release when opened/resumed, chooses a delta only when the installed APK's SHA-256 matches a supported base, downloads the advertised bytes, reconstructs the exact signed target with bounded IO, verifies its full SHA-256, then opens Android's installer. Package name, increasing version and signing certificate are checked natively. A failed delta does **not** silently trigger a large full download: the user chooses whether to download the full APK.

Patch sizes depend on unchanged archive entries. Updates changing the native core or lacking a matching base may require a full APK. Android still asks for installation approval. This self-distributed updater is not a Google Play update implementation. The initial 0.0.1 debug build cannot be silently migrated to a different owner signing key: back up subscriptions before a one-time reinstall if the signing certificates differ.

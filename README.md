# Mi Band 7 Companion

`Mi Band 7 Companion` is a Flutter-based Android app being reworked from a notification helper into the foundation of a Gadgetbridge-style companion for Xiaomi Mi Band 7 devices.

Today, the app focuses on the first hard parts of that journey:

- tracking whether the band was paired in the correct vendor app
- importing and normalizing a 32-byte auth key from pasted logs, rooted database output, or token-tool output
- preparing Android BLE permissions for direct device discovery
- scanning for likely Mi Band / Xiaomi / Huami BLE candidates
- keeping a journal of pairing and discovery work
- posting a relay notification smoke test while direct protocol work is still in progress

## Important limitation

Mi Band 7 does **not** expose an official public SDK for direct third-party app messaging or Zepp OS app deployment.

Modern Xiaomi / Huami pairing also uses a server-backed authentication key. That means:

- you must pair in `Zepp Life`, `Zepp`, or `Mi Fitness` first
- you must extract or recover the auth key after vendor pairing
- unpairing in the vendor app or factory-resetting the band invalidates that key

## Features

- vendor-app pairing baseline tracking
- auth key extraction assistant for pasted logs / JSON / manual keys
- BLE permission readiness checks
- BLE scan for likely Mi Band candidates
- persisted companion journal
- Android notification smoke test for relay validation

## Run the app

```bash
flutter pub get
flutter run -d android
```

## Build an APK

```bash
flutter build apk
```

## Test and validate

```bash
flutter test
flutter analyze
```

## Android package

- App name: `Mi Band 7 Companion`
- Dart package: `miband_7_notifier`
- Android application ID: `com.cmwen.miband7notifier`

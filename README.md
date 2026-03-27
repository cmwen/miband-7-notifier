# Mi Band 7 Notifier

`Mi Band 7 Notifier` is a Flutter-based Android app built from the `min-android-app-template`.

Its purpose is simple: create Android notifications that can be mirrored to a paired Xiaomi Mi Band 7 through `Mi Fitness` or `Zepp Life`.

## Important limitation

Mi Band 7 does **not** expose an official public SDK for direct third-party app messaging or Zepp OS app deployment.

Because of that, this project uses the most practical and stable path:

- the app posts a normal Android notification
- Android shows it on the phone
- Mi Fitness / Zepp Life mirrors it to the band when notification access is enabled

## Features

- request Android notification permission
- compose custom notification titles and bodies
- save the last draft locally
- keep a short history of recently sent notifications
- tap a recent notification to load it back into the composer
- show setup guidance for Mi Band 7 notification mirroring

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

- App name: `Mi Band 7 Notifier`
- Dart package: `miband_7_notifier`
- Android application ID: `com.cmwen.miband7notifier`

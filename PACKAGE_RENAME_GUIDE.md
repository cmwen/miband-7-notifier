# Package Name Rename Guide

**CRITICAL**: Before running your app, you MUST update the package name from the template default `com.cmwen.min_flutter_template` to your own package name. Failure to do so will cause app launch issues.

## Why This Matters

The package name (also called application ID) uniquely identifies your app on Android devices and app stores. Using the template's default package name will cause conflicts and launch failures.

## Quick Checklist

- [ ] Update `android/app/build.gradle.kts` (namespace and applicationId)
- [ ] Update `android/app/src/main/kotlin/.../MainActivity.kt` (package declaration and file path)
- [ ] Update `android/app/src/main/AndroidManifest.xml` (optional: app label)
- [ ] Update `pubspec.yaml` (name field)
- [ ] Update `lib/main.dart` (imports if needed)
- [ ] Update `test/widget_test.dart` (imports)
- [ ] Run `flutter clean && flutter pub get`
- [ ] Test app launch on Android

## Step-by-Step Instructions

### 1. Choose Your Package Name

Format: `com.yourcompany.yourapp` (all lowercase, no hyphens, use underscores for multi-word names)

Examples:
- `com.acme.todo_app`
- `com.mycompany.awesome_app`
- `com.example.my_flutter_app`

### 2. Update Android Package Configuration

#### File: `android/app/build.gradle.kts`

```kotlin
android {
    namespace = "com.yourcompany.yourapp"  // Change this
    
    defaultConfig {
        applicationId = "com.yourcompany.yourapp"  // Change this (must match namespace)
        // ...
    }
}
```

**CRITICAL**: `namespace` and `applicationId` MUST match exactly.

#### File: `android/app/src/main/kotlin/com/cmwen/min_flutter_template/MainActivity.kt`

1. Update the package declaration at the top:
```kotlin
package com.yourcompany.yourapp  // Change this
```

2. Move the file to match your package structure:
```bash
# From terminal in android/app/src/main/kotlin/:
mkdir -p com/yourcompany/yourapp
mv com/cmwen/min_flutter_template/MainActivity.kt com/yourcompany/yourapp/
rm -rf com/cmwen  # Clean up old package directory
```

Or use your IDE's refactoring feature to rename the package.

#### File: `android/app/src/main/AndroidManifest.xml` (Optional)

Update the app's display name:
```xml
<application
    android:label="Your App Name"
    <!-- ... -->
```

### 3. Update Flutter Configuration

#### File: `pubspec.yaml`

```yaml
name: your_app_name  # Change to match your app (use underscores, not hyphens)
description: "Your app description"
```

**Note**: Use underscores for multi-word names (e.g., `my_awesome_app`).

#### File: `lib/main.dart`

Update app title:
```dart
title: 'Your App Name',  // Change this
home: const MyHomePage(title: 'Your App Name'),  // Change this
```

#### File: `test/widget_test.dart`

Update import to match new package name:
```dart
import 'package:your_app_name/main.dart';  // Change this
```

### 4. Clean and Rebuild

```bash
flutter clean
flutter pub get
flutter run
```

## Automated Rename (Recommended)

Ask AI to rename the package for you:

```
@flutter-developer Please rename this Flutter app from "min_flutter_template" to "my_awesome_app" 
and update the package from "com.cmwen.min_flutter_template" to "com.mycompany.my_awesome_app".

Update all files including:
- pubspec.yaml (name, description)
- lib/main.dart (imports, title)
- test/widget_test.dart (imports)
- android/app/build.gradle.kts (namespace, applicationId)
- android/app/src/main/kotlin/.../MainActivity.kt (package declaration and move file)
- android/app/src/main/AndroidManifest.xml (label)

After updates, run flutter clean && flutter pub get and verify compilation.
```

## Common Mistakes to Avoid

1. **Mismatched namespace and applicationId**: These MUST be identical in `build.gradle.kts`
2. **Forgot to move MainActivity.kt**: The file path must match the package structure
3. **Used hyphens instead of underscores**: Dart package names use underscores
4. **Forgot to update test imports**: Tests will fail if imports don't match
5. **Didn't run flutter clean**: Old build artifacts can cause issues

## Verification

After renaming, verify everything works:

```bash
# Check for errors
flutter analyze

# Run tests
flutter test

# Build and run on Android
flutter run

# Check the installed package name
adb shell pm list packages | grep yourcompany
```

## iOS and Other Platforms

For iOS/macOS, update bundle identifiers in Xcode:

1. Open `ios/Runner.xcodeproj` in Xcode
2. Select Runner target → General → Bundle Identifier
3. Change to `com.yourcompany.yourapp`

For web, update `web/manifest.json`:
```json
{
  "name": "Your App Name",
  "short_name": "YourApp"
}
```

## Troubleshooting

### App Won't Launch

**Error**: "Unable to load assets" or crash on startup
**Solution**: Verify package name in MainActivity.kt matches build.gradle.kts exactly

### Build Fails with "package does not exist"

**Solution**: Make sure MainActivity.kt file path matches package structure:
- Package: `com.example.app`
- Path: `kotlin/com/example/app/MainActivity.kt`

### Import Errors in Tests

**Solution**: Update import in `test/widget_test.dart` to match `pubspec.yaml` name field

## References

- [Android Application ID](https://developer.android.com/studio/build/application-id)
- [Flutter Package Names](https://dart.dev/tools/pub/pubspec#name)
- [APP_CUSTOMIZATION.md](APP_CUSTOMIZATION.md) - Complete customization guide

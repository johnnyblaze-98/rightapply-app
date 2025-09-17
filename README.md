## RightApply — Fresh Flutter Starter

This repo has been reset to a clean Flutter starter so you can build from scratch.

### Run (Windows, cmd.exe)

```
flutter pub get
flutter run -d windows
```

Or build a release:

```
flutter build windows
start build\windows\x64\runner\Release\rightapply.exe
```

### What changed?
- Removed previous integrations, AWS infra, and custom pages
- Kept a default counter app in `lib/main.dart`
- Simplified `pubspec.yaml` to core dependencies
- Reset the widget test to the default counter smoke test

### Next steps
Start adding your own screens, dependencies, and services as needed.

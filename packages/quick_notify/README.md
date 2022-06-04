# quick_notify

A cross-platform (Android/iOS/Web/Windows/macOS/Linux) notification plugin for Flutter

## Usage

### Handle permisson

```dart
var hasPermission = await QuickNotify.hasPermission();
print('hasPermission $hasPermission');
```

```dart
var requestPermission = await QuickNotify.requestPermission();
print('requestPermission $requestPermission');
```

### Post notification

```dart
await QuickNotify.notify(
  title: 'My title',
  content: 'My content',
);
```
# Launcher Shortcuts - Flutter Plugin

![Pub Version](https://img.shields.io/pub/v/launcher_shortcuts)
![License](https://img.shields.io/badge/license-MIT-blue)
![GitHub Stars](https://img.shields.io/github/stars/camilo1498/launcher_shortcuts?style=social)
![GitHub User](https://img.shields.io/badge/GitHub-camilo1498-blue?logo=github)

⭐ **Support this project!** If you find this package useful, please consider giving it a star
on [GitHub](https://github.com/camilo1498/launcher_shortcuts). Your support helps maintain and
improve
this package for everyone!

A comprehensive Flutter plugin for managing dynamic app shortcuts on both iOS and Android platforms.
This package provides a unified API to create, manage, and handle app shortcuts with support for
both cold starts (app launched from shortcut) and hot starts (shortcut activated while app is
running).

## Features

- 📱 **Cross-Platform Support**: Works seamlessly on both iOS and Android
- 🔄 **Stream-Based Events**: Handle shortcut actions through a convenient stream interface
- ❄️ **Cold Start Support**: Properly handles app launches from shortcuts
- 🔥 **Hot Start Support**: Handles shortcut activations while app is running
- 🎯 **Dynamic Shortcuts**: Create and manage shortcuts programmatically
- 🖼️ **Custom Icons from Flutter Assets**: Use icons from your Flutter assets for both platforms
- 📋 **Subtitles**: Optional subtitles for shortcuts (iOS only)

## Demo

### Android

<div style="display: flex; flex-wrap: wrap; gap: 20px;">
  <div>
    <img src="https://github.com/camilo1498/launcher_shortcuts/blob/master/media_doc/Android_test.gif" width="250" alt="Android Demo">
  </div>
</div>

### iOS

<div style="display: flex; flex-wrap: wrap; gap: 20px;">
  <div>
    <img src="https://github.com/camilo1498/launcher_shortcuts/blob/master/media_doc/IOS_test.gif" width="250" alt="iOS Demo">
  </div>
</div>

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  launcher_shortcuts: ^latest_version
```

Also, add your shortcut icons to the `assets` section in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/launcher/  # directory containing your shortcut icons
```

## Platform-Specific Setup

### Android

* Min SDK version is 25
* In your `AndroidManifest.xml`, add the following within the `<application>` tag:

```xml

<activity android:launchMode="singleInstance"></activity>
```

The key attribute is `android:launchMode="singleInstance"` which prevents app duplication when using
shortcuts.

### iOS

* Min iOS version is 12.0
* No additional setup is required for iOS. The plugin automatically handles everything through the
  AppDelegate.

## Basic Usage

### 1. Initialize the plugin

Ensure to use `initialize` after `WidgetsFlutterBinding.ensureInitialized()` in your `main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LauncherShortcuts.initialize();
  runApp(MyApp());
}
```

### 2. Set up shortcut handling

```dart
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();

    // Listen for shortcut events
    LauncherShortcuts.shortcutStream.listen(_handleShortcut);
  }

  void _handleShortcut(String type) {
    // Navigate based on shortcut type
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState?.pushNamed(type);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      // ... rest of your app configuration
    );
  }
}
```

### 3. Create and register shortcuts

```dart
Future<void> _registerShortcuts() async {
  try {
    await LauncherShortcuts.setShortcuts([
      ShortcutItem(
        type: '/search',
        localizedTitle: 'Search',
        androidConfig: AndroidConfig(icon: 'assets/launcher/search.png'),
        iosConfig: IosConfig(
          icon: 'search',
          localizedSubtitle: 'Find items quickly',
        ),
      ),
      ShortcutItem(
        type: '/settings',
        localizedTitle: 'Settings',
        androidConfig: AndroidConfig(icon: 'assets/launcher/settings.png'),
        iosConfig: IosConfig(
          icon: 'settings',
          localizedSubtitle: 'App configuration',
        ),
      ),
    ]);
  } catch (e) {
    print('Error setting shortcuts: $e');
  }
}
```

### 4. Clear shortcuts when needed

```dart
Future<void> _clearShortcuts() async {
  try {
    await LauncherShortcuts.clearShortcuts();
  } catch (e) {
    print('Error clearing shortcuts: $e');
  }
}
```

## Advanced Usage

### Handling cold starts

The plugin automatically handles cold starts (when the app is launched from a shortcut). The
shortcut action will be delivered through the same stream as hot start actions.

### Custom navigation handling

```dart
void _handleShortcut(String type) {
  if (navigatorKey.currentState != null) {
    // For cold starts, replace the initial route
    if (navigatorKey.currentState!.canPop()) {
      navigatorKey.currentState?.pushReplacementNamed(type);
    } else {
      navigatorKey.currentState?.pushNamed(type);
    }
  }
}
```

### Validating shortcut actions

```dart
// Define valid routes in your app
final List<String> _validRoutes = ['/search', '/settings', '/profile'];

bool _isValidRoute(String action) {
  return _validRoutes.contains(action);
}

void _handleShortcut(String type) {
  if (_isValidRoute(type) && navigatorKey.currentState != null) {
    // Handle valid route
    navigatorKey.currentState?.pushNamed(type);
  }
}
```

## API Reference

### LauncherShortcuts Class

| Method                                   | Description                                          |
|------------------------------------------|------------------------------------------------------|
| `initialize()`                           | Initializes the plugin and sets up platform handlers |
| `setShortcuts(List<ShortcutItem> items)` | Sets the dynamic shortcuts for the app               |
| `clearShortcuts()`                       | Clears all dynamic shortcuts                         |
| `dispose()`                              | Cleans up resources when no longer needed            |

### ShortcutItem Class

| Property         | Description                                                 |
|------------------|-------------------------------------------------------------|
| `type`           | Unique identifier for the shortcut (typically a route path) |
| `localizedTitle` | The title displayed for the shortcut                        |
| `androidConfig`  | Android-specific configuration (icon, localizedLongLabel)   |
| `iosConfig`      | iOS-specific configuration (icon, subtitle)                 |

### AndroidConfig

| Property             | Description                        |
|----------------------|------------------------------------|
| `icon`               | Path to the icon in Flutter assets |
| `localizedLongLabel` | The long label for teh shortcut    |

### IosConfig

| Property            | Description                        |
|---------------------|------------------------------------|
| `icon`              | Name of the icon in asset catalog  |
| `localizedSubtitle` | Optional subtitle for the shortcut |

### Stream

| Property         | Description                                              |
|------------------|----------------------------------------------------------|
| `shortcutStream` | Stream that emits shortcut action strings when activated |

## FAQ

**Q: Can I use this plugin with existing navigation solutions?**  
A: Yes! The plugin emits shortcut actions through a stream that you can integrate with any
navigation solution.

**Q: How does it handle multiple shortcut activations?**  
A: All shortcut activations are delivered through the stream in the order they occur.

**Q: Are there limitations on the number of shortcuts?**  
A: Both iOS and Android have platform-specific limits on the number of dynamic shortcuts.

**Q: Can I use custom icons for shortcuts?**  
A: Yes, you can specify icon paths that correspond to assets in your Flutter project.

## Limitations

- The number of dynamic shortcuts is limited by platform constraints
- Subtitle support is only available on iOS
- Custom icon support requires platform-specific resource setup

## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

## License

MIT - See [LICENSE](LICENSE) for details.

## Acknowledgments

This plugin is inspired by the need for a unified shortcut handling solution that works seamlessly
across both iOS and Android platforms with proper cold start support.

---

⭐ **Found this package helpful?** Please consider giving it a star
on [GitHub](https://github.com/camilo1498/launcher_shortcuts) to show your support and help others
discover it!
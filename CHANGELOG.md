# Changelog - Launcher Shortcuts Plugin

## [1.1.4] - Flutter Assets Icons SVG for android

## [1.1.3] - Flutter Assets Icons & Platform-Specific Config

### Added

- **Flutter Assets Support**: Now you can use icons from Flutter assets for both Android and iOS
- **Platform-Specific Configuration**: Added `AndroidConfig` and `IosConfig` to allow
  platform-specific properties for each shortcut
- **Improved Error Handling**: Enhanced error handling and logging for icon loading and
  initialization

### Changed

- **API Structure**: The `ShortcutItem` class now uses nested configuration objects for
  platform-specific settings
- **Icon Loading**: Improved icon loading mechanism using `FlutterLoader` on Android and asset
  catalog on iOS

### Fixed

- **Android Icon Loading**: Fixed issue where icons from Flutter assets were not showing on Android
- **iOS Initializer**: Fixed Swift compiler error by using correct initializer for
  `UIApplicationShortcutIcon`

## [1.0.11] - Fixed License

## [1.0.0] - Initial Release

### Features

- **Cross-Platform Support**: Full support for both iOS and Android app shortcuts
- **Stream-Based Architecture**: Event handling through Dart streams for both cold and hot starts
- **Dynamic Shortcut Management**: Programmatic creation and removal of shortcuts
- **Cold Start Handling**: Proper support for app launches from shortcuts
- **Custom Icons & Subtitles**: Support for platform-specific icons and optional subtitles
- **Unified API**: Consistent interface across both platforms

### Android Specific

- **SingleInstance Launch Mode**: Prevents app duplication when using shortcuts
- **Intent Flag Management**: Proper handling of activity flags to maintain single instance behavior
- **ShortcutManager Integration**: Uses Android's native ShortcutManager API

### iOS Specific

- **AppDelegate Integration**: Seamless integration with iOS app lifecycle
- **UIApplicationShortcutItem Support**: Native iOS quick actions implementation
- **Background/Foreground Handling**: Proper handling of shortcuts in all app states

### Technical Implementation

- **Pigeon Code Generation**: Type-safe platform channel communication
- **Plugin Architecture**: Clean separation between platform-specific implementations
- **Error Handling**: Comprehensive exception handling and error reporting
- **Lifecycle Management**: Proper handling of activity/fragment lifecycle events

## [0.0.3] - Bug Fixes & Optimizations

### Fixed

- **Android Intent Processing**: Resolved issues with intent flag conflicts
- **Stream Management**: Improved handling of multiple stream subscribers
- **Memory Leaks**: Fixed potential memory leaks in stream controllers
- **Initialization Race Conditions**: Improved async initialization handling

### Optimized

- **Performance**: Reduced overhead in shortcut registration process
- **Code Structure**: Improved code organization and documentation
- **Error Messages**: More descriptive error messages for debugging

## [0.0.2] - Enhanced Features

### Added

- **Custom Icon Support**: Expanded support for various icon types and formats
- **Validation Utilities**: Built-in validation for shortcut actions and routes
- **Extended Configuration**: Additional options for shortcut customization
- **Example App**: Comprehensive example demonstrating all features

### Improved

- **Documentation**: Complete API documentation with usage examples
- **Platform Consistency**: More consistent behavior between iOS and Android
- **Error Recovery**: Better handling of edge cases and error conditions

## [0.0.1] - Stability Release

### Fixed

- **Cold Start Reliability**: Improved handling of app launches from shortcuts
- **Stream Consistency**: Ensured consistent event delivery across app states
- **Navigation Integration**: Better compatibility with various navigation solutions
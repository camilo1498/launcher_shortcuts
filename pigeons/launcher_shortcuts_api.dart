import 'package:pigeon/pigeon.dart';

/// Represents a shortcut item that can be displayed in the app's context menu
/// or as a dynamic/pinned shortcut, depending on the platform.
class ShortcutItem {
  /// Creates a new [ShortcutItem].
  ///
  /// The [type] is a unique identifier for the shortcut. This is used to
  /// distinguish between different shortcut actions.
  /// The [localizedTitle] is the primary text displayed for the shortcut.
  ShortcutItem(this.type, this.localizedTitle);

  /// A unique identifier for the shortcut. This is used by the application
  /// to identify which shortcut action was performed by the user.
  String type;

  /// Optional iOS-specific configuration for this shortcut item.
  /// This includes properties like subtitle and icon specific to iOS.
  IosConfig? iosConfig;

  /// The localized text that will be displayed as the main label for this
  /// shortcut. For example, "Compose new message".
  String localizedTitle;

  /// Optional Android-specific configuration for this shortcut item.
  /// This includes properties like the icon specific to Android.
  AndroidConfig? androidConfig;
}

/// Android-specific configuration for a [ShortcutItem].
class AndroidConfig {
  AndroidConfig(this.icon);

  /// The name of the icon resource (e.g., a drawable resource name like
  /// "ic_shortcut_add"). This is optional.
  String? icon;

  /// An optional localized subtitle for this shortcut. This text is displayed
  /// below the [ShortcutItem.localizedLongLabel] on iOS.
  String? localizedLongLabel;
}

/// iOS-specific configuration for a [ShortcutItem].
class IosConfig {
  /// Creates an iOS-specific configuration.
  ///
  /// The [icon] is the name of the icon resource (e.g., from an asset
  /// catalog) to be used for the shortcut on iOS.
  /// The [localizedSubtitle] provides additional descriptive text for the
  /// shortcut.
  IosConfig(this.icon, this.localizedSubtitle);

  /// The name of the icon resource (e.g., "UIApplicationShortcutIconTypeAdd"
  /// or a custom icon name from an asset catalog). This is optional.
  String? icon;

  /// An optional localized subtitle for this shortcut. This text is displayed
  /// below the [ShortcutItem.localizedTitle] on iOS.
  String? localizedSubtitle;
}

/// Configuration for generating platform-specific Pigeon code.
///
/// This setup directs Pigeon to generate Dart, Swift, and Kotlin files
/// for inter-platform communication, specifying output paths and package names.
@ConfigurePigeon(
  PigeonOptions(
    copyrightHeader: 'pigeons/copyright.txt',
    dartOut: 'lib/src/launcher_shortcuts_api.g.dart',
    swiftOut: 'ios/Classes/launcher_shortcuts_api.g.swift',
    kotlinOptions: KotlinOptions(package: 'com.pco.camilo.launcher_shortcuts'),
    kotlinOut:
        'android/src/main/kotlin/com/pco/camilo/launcher_shortcuts/LauncherShortcutsApi.kt',
  ),
)
/// Defines the primary API for managing shortcuts on the host platform
/// (iOS/Android). This API is called from Flutter to native.
@HostApi()
abstract class ShortcutsApi {
  /// Sets (or replaces) the list of dynamic shortcut items for the application.
  ///
  /// This will overwrite any existing dynamic shortcuts.
  /// The [itemsList] contains the [ShortcutItem]s to be set.
  @async
  void setShortcutItems(List<ShortcutItem> itemsList);

  /// Clears all previously set dynamic shortcut items from the application.
  void clearShortcutItems();

  /// Notifies the native side that the Flutter application is initialized
  /// and ready to receive and process shortcut actions or other calls.
  @async
  void setFlutterReady();
}

/// Defines the API for handling shortcut actions launched on iOS.
/// This API is called from the native iOS side to Flutter when a shortcut
/// is tapped by the user.
@FlutterApi()
abstract class IOSShortcutsApi {
  /// Called when a shortcut action is launched on iOS.
  ///
  /// The [action] is the `type` (unique identifier) of the
  /// [ShortcutItem] that was launched by the user.
  void launchAction(String action);
}

/// Defines the API for managing shortcuts specifically on the Android platform.
/// This API is called from Flutter to native Android.
@HostApi()
abstract class AndroidShortcutsApi {
  /// Retrieves the initial action if the app was launched from a shortcut.
  ///
  /// Returns the `type` (unique identifier) of the [ShortcutItem] if the app
  /// was launched via a shortcut, or null if not launched from a shortcut
  /// or if no action is pending.
  String? getLaunchAction();

  /// Sets the list of dynamic shortcut items on Android.
  ///
  /// This will overwrite any existing dynamic shortcuts. Static shortcuts
  /// defined in `shortcuts.xml` are not affected.
  /// The [itemsList] contains the [ShortcutItem]s to be set.
  @async
  void setShortcutItems(List<ShortcutItem> itemsList);

  /// Clears all previously set dynamic shortcut items on Android.
  /// Static shortcuts defined in `shortcuts.xml` are not affected.
  void clearShortcutItems();

  /// Notifies the Android native side that the Flutter application is
  /// initialized and ready to receive and process shortcut actions.
  @async
  void setFlutterReady();
}

/// Defines the API for handling shortcut actions launched on Android.
/// This API is called from the native Android side to Flutter when a shortcut
/// is tapped by the user.
@FlutterApi()
abstract class AndroidShortcutsFlutterApi {
  /// Called when a shortcut action is launched on Android.
  ///
  /// The [action] is the `type` (unique identifier) of the
  /// [ShortcutItem] that was launched. This corresponds to the intent action
  /// or shortcut ID from the Android system.
  void launchAction(String action);
}

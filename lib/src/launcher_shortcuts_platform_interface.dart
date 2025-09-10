import 'package:launcher_shortcuts/src/launcher_shortcuts_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:flutter/services.dart';

/// The interface that platform-specific implementations of `launcher_shortcut`
/// must extend.
///
/// This class defines the basic API for interacting with app shortcuts.
/// Platform-specific implementations will provide concrete versions of these
/// methods.
abstract class LauncherShortcutsPlatform extends PlatformInterface {
  /// Constructs an [LauncherShortcutsPlatform].
  ///
  /// The [token] parameter is used to verify that the platform instance has
  /// been properly initialized.
  LauncherShortcutsPlatform() : super(token: _token);

  static final Object _token = Object();

  static LauncherShortcutsPlatform _instance = MethodChannelLauncherShortcuts();

  /// The default instance of [LauncherShortcutsPlatform] to use.
  ///
  /// Defaults to [MethodChannelLauncherShortcuts].
  static LauncherShortcutsPlatform get instance => _instance;

  /// Sets the instance of [LauncherShortcutsPlatform].
  ///
  /// This is used by tests to override the default instance with a mock one.
  static set instance(LauncherShortcutsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Sets a handler for method calls from the native platform to Dart.
  ///
  /// This handler is invoked when the native platform sends a message to
  /// the Flutter application, typically as a result of a shortcut being
  /// activated.
  ///
  /// The [handler] function should process the [MethodCall] and return a
  /// [Future] that completes with the result of the call.
  void setMethodCallHandler(Future<dynamic> Function(MethodCall call)? handler);

  /// Configures all shortcuts in the system.
  ///
  /// This method replaces any existing shortcuts with the ones provided in
  /// the [items] list. Each item in the list is a [Map] representing a
  /// shortcut, with platform-specific keys and values.
  ///
  /// Throws a [PlatformException] if the shortcuts cannot be set.
  Future<void> setShortcuts(List<Map<String, dynamic>> items);

  /// Retrieves and consumes the action that launched the app.
  ///
  /// This is typically used to handle "cold start" scenarios where the app
  /// is launched by a shortcut. The method returns a [String] representing
  /// the action associated with the shortcut, or `null` if the app was not
  /// launched by a shortcut.
  ///
  /// The action is "consumed" meaning subsequent calls may return `null`
  /// or a different value if another launch action occurs.
  Future<String?> getLaunchAction();
}

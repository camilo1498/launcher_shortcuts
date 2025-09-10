import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:launcher_shortcuts/src/launcher_shortcuts_platform_interface.dart';

/// An implementation of [LauncherShortcutsPlatform] that uses method channels.
///
/// This class interacts with the native platform (Android/iOS) to manage
/// app shortcuts.
class MethodChannelLauncherShortcuts extends LauncherShortcutsPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel('launcher_shortcut');

  /// Sets a callback that is invoked when a platform method is called.
  ///
  /// The [handler] is a function that takes a [MethodCall] and returns
  /// a [Future] that completes with the result of the method call.
  @override
  void setMethodCallHandler(
    Future<dynamic> Function(MethodCall call)? handler,
  ) {
    methodChannel.setMethodCallHandler(handler);
  }

  /// Sets the dynamic shortcuts for the application.
  ///
  /// Each shortcut is represented by a map containing its properties.
  /// The [items] parameter is a list of these maps.
  @override
  Future<void> setShortcuts(List<Map<String, dynamic>> items) async {
    await methodChannel.invokeMethod('setShortcuts', {'items': items});
  }

  /// Retrieves the ID of the shortcut that launched the app, if any.
  ///
  /// Returns a [Future] that completes with the shortcut ID as a [String],
  /// or `null` if the app was not launched by a shortcut.
  @override
  Future<String?> getLaunchAction() async {
    return await methodChannel.invokeMethod<String>('getLaunchAction');
  }
}

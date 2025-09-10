import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:launcher_shortcuts/launcher_shortcuts.dart';

/// A class that provides methods for managing app shortcuts.
///
/// This class handles the initialization of platform-specific shortcut
/// handlers, setting and clearing shortcuts, and managing shortcut action
/// events. It ensures that shortcut actions are queued and processed
/// correctly, even if they occur before the app is fully initialized or
/// listeners are attached.
class LauncherShortcuts {
  /// Stream controller for broadcasting shortcut actions.
  ///
  /// This controller is used to manage and dispatch shortcut events to
  /// listeners. When a listener subscribes, if there's a pending action,
  /// it's immediately emitted. This ensures that actions are not missed if
  /// they arrive before a listener is active.
  static final StreamController<String>
  _shortcutController = StreamController<String>.broadcast(
    onListen: () {
      // If a pending action exists when a listener is added, emit it.
      // This handles cases where an action was received before any part of the
      // app started listening to the [shortcutStream].
      if (_pendingAction != null) {
        _shortcutController.add(_pendingAction!);
        _pendingAction = null; // Clear the action once emitted.
      }
    },
  );

  /// Stores a shortcut action that was received before the [shortcutStream]
  /// had any listeners or before initialization was complete.
  ///
  /// This ensures that no shortcut actions are lost if they occur early in
  /// the app lifecycle (e.g., from a cold start). The action is processed
  /// once a listener is attached or [getColdStartAction] is called.
  static String? _pendingAction;

  /// Flag to indicate if the [LauncherShortcuts] plugin has been initialized.
  ///
  /// Initialization involves setting up platform-specific handlers and
  /// fetching any initial launch actions. It's crucial for ensuring that
  /// shortcut operations can be safely performed.
  static bool _isInitialized = false;

  /// Flag to indicate if the [_shortcutController] currently has listeners.
  ///
  /// This is used to determine whether to broadcast an action immediately
  /// via the stream or store it as a [_pendingAction] if no listeners are
  /// currently active.
  static bool _hasListener = false;

  /// A completer that resolves when the initial cold start action has been
  /// processed and the plugin is fully initialized.
  ///
  /// This is used by [getColdStartAction] to allow consumers to await
  /// the completion of the asynchronous initialization process before
  /// attempting to retrieve a cold start action.
  static Completer<void>? _initializationCompleter = Completer<void>();

  /// A stream that emits the string identifier of a shortcut action when
  /// it is invoked by the user.
  ///
  /// Listen to this stream to handle shortcut actions in your Flutter app.
  /// For example, you can use the action identifier to navigate to a
  /// specific part of your application.
  static Stream<String> get shortcutStream => _shortcutController.stream;

  /// Initializes the app shortcuts plugin.
  ///
  /// Sets up platform-specific handlers (for iOS and Android) and retrieves
  /// any pending launch action that might have triggered the app's start.
  /// This method should be called early in the app's lifecycle, typically
  /// in `main()` before `runApp()`.
  ///
  /// It ensures that the native side is ready and that any action that
  /// launched the app (cold start) is captured.
  ///
  /// Throws [AppShortcutException] if initialization fails on the native
  /// platform.
  static Future<void> initialize() async {
    // Set up platform-specific API handlers.
    if (Platform.isIOS) {
      // For iOS, set up the handler that receives quick actions from native.
      IOSShortcutsApi.setUp(_IOSQuickActionsHandler());
    } else if (Platform.isAndroid) {
      // For Android, set up the handler for shortcut intents.
      AndroidShortcutsFlutterApi.setUp(_AndroidQuickActionsHandler());
    }

    try {
      // Notify the native side that Flutter is ready to process actions.
      // This is important for scenarios where native code might queue actions.
      await setFlutterReady();

      if (Platform.isAndroid) {
        // On Android, explicitly check for any launch action that started the
        // app. This is typically an intent action.
        final String? action = await getLaunchAction();
        if (action != null && action.isNotEmpty) {
          _pendingAction = action; // Store it as a pending action.
          // If already initialized (e.g., re-initialization) and has listeners,
          // process the action immediately.
          if (_isInitialized && _hasListener) {
            _shortcutController.add(_pendingAction!);
            _pendingAction = null; // Clear after processing.
          }
        }
      }

      // Mark the plugin as initialized.
      _isInitialized = true;

      // Complete the initialization completer if it hasn't been completed yet.
      // This signals that `getColdStartAction` can now safely proceed.
      if (!(_initializationCompleter?.isCompleted ?? true)) {
        _initializationCompleter!.complete();
      }
    } on Exception catch (e, s) {
      // Log the error for debugging purposes.
      debugPrint('Error initializing shortcuts: $e\n$s');
      // If the completer is still active, complete it with an error.
      if (!(_initializationCompleter?.isCompleted ?? true)) {
        _initializationCompleter!.completeError(
          AppShortcutException('Failed to initialize platform services'),
        );
      }
      // Rethrow as a specific exception type for the caller to handle.
      throw AppShortcutException('Failed to initialize app shortcuts');
    }
  }

  /// Gets the initial shortcut action that launched the app (cold start).
  ///
  /// This method waits for the [initialize] method to complete before
  /// returning the pending action, if any. This is useful for routing
  /// based on the shortcut that opened the app.
  ///
  /// It should be called after [initialize] and typically once during app
  /// startup to determine if the app was launched via a shortcut.
  ///
  /// Returns the action string if available, otherwise `null`.
  static Future<String?> getColdStartAction() async {
    // Await the completion of the initialization process if it's ongoing.
    if (_initializationCompleter != null) {
      await _initializationCompleter!.future;
    }
    // Retrieve the pending action. This might have been set during initialize().
    final String? action = _pendingAction;
    // Clear the pending action after it has been retrieved for cold start,
    // as it's considered consumed for this purpose.
    _pendingAction = null;
    return action;
  }

  /// Checks for listeners on the [_shortcutController] and processes any
  /// pending action if listeners are present and the plugin is initialized.
  ///
  /// This method is typically called internally when a new listener subscribes
  /// or after a shortcut action is received from the native side to ensure
  /// timely processing of queued actions.
  static void checkForListeners() {
    // Update the status of whether there are active listeners.
    _hasListener = _shortcutController.hasListener;

    // If there's a pending action, and listeners are active,
    // and the plugin is initialized, emit the action.
    if (_pendingAction != null && _hasListener && _isInitialized) {
      _shortcutController.add(_pendingAction!);
      _pendingAction = null; // Clear the action once emitted.
    }
  }

  /// Sets the dynamic shortcuts for the app.
  ///
  /// Takes a list of [ShortcutItem] objects to be set. These shortcuts
  /// are typically displayed when a user long-presses the app icon on
  /// supported platforms (Android and iOS).
  /// If the list is empty, no action is taken.
  ///
  /// Throws [AppShortcutException] if setting shortcuts fails on the
  /// native platform.
  static Future<void> setShortcuts(List<ShortcutItem> items) async {
    // If the list of items is empty, there's nothing to set.
    if (items.isEmpty) return;

    if (Platform.isAndroid) {
      try {
        // Use the Android-specific API to set shortcut items.
        final AndroidShortcutsApi androidHost = AndroidShortcutsApi();
        await androidHost.setShortcutItems(items);
      } on Exception catch (e, s) {
        // Log error and rethrow as a specific exception.
        debugPrint('Error setting Android shortcuts: $e\n$s');
        throw AppShortcutException('Failed to set Android shortcuts');
      }
    } else if (Platform.isIOS) {
      try {
        // Use the iOS-specific API to set shortcut items.
        final ShortcutsApi iosHost = ShortcutsApi();
        await iosHost.setShortcutItems(items);
      } on Exception catch (e, s) {
        // Log error and rethrow as a specific exception.
        debugPrint('Error setting iOS shortcuts: $e\n$s');
        throw AppShortcutException('Failed to set iOS shortcuts');
      }
    }
  }

  /// Clears all dynamic shortcuts for the app.
  ///
  /// This removes all previously set dynamic shortcuts from the app icon
  /// menu on supported platforms.
  ///
  /// Throws [AppShortcutException] if clearing shortcuts fails on the
  /// native platform.
  static Future<void> clearShortcuts() async {
    if (Platform.isAndroid) {
      try {
        // Use the Android-specific API to clear shortcut items.
        final AndroidShortcutsApi androidHost = AndroidShortcutsApi();
        await androidHost.clearShortcutItems();
      } on Exception catch (e, s) {
        // Log error and rethrow as a specific exception.
        debugPrint('Error clearing Android shortcuts: $e\n$s');
        throw AppShortcutException('Failed to clear Android shortcuts');
      }
    } else if (Platform.isIOS) {
      try {
        // Use the iOS-specific API to clear shortcut items.
        final ShortcutsApi iosHost = ShortcutsApi();
        await iosHost.clearShortcutItems();
      } on Exception catch (e, s) {
        // Log error and rethrow as a specific exception.
        debugPrint('Error clearing iOS shortcuts: $e\n$s');
        throw AppShortcutException('Failed to clear iOS shortcuts');
      }
    }
  }

  /// Gets the initial shortcut action that launched the app (Android only).
  ///
  /// This method is primarily for Android to retrieve the intent action
  /// that might have started the activity. On iOS, launch actions are
  /// typically handled through the `AppDelegate` and communicated via
  /// the [_IOSQuickActionsHandler].
  ///
  /// Returns the action string if available, otherwise `null`.
  /// Returns `null` immediately if not on Android.
  static Future<String?> getLaunchAction() async {
    // This functionality is specific to Android.
    if (!Platform.isAndroid) {
      return null;
    }

    try {
      // Call the native Android method to get the launch action.
      final AndroidShortcutsApi androidHost = AndroidShortcutsApi();
      return await androidHost.getLaunchAction();
    } on Exception catch (e, s) {
      // Log error and return null, as this is a non-critical retrieval.
      debugPrint('Error getting launch action: $e\n$s');
      return null;
    }
  }

  /// Notifies the native side that Flutter is ready to receive shortcut actions.
  ///
  /// This should be called after the Flutter UI is sufficiently initialized
  /// (e.g., after `runApp` and initial routing) to handle incoming shortcut
  /// actions. It signals to the native platform (iOS and Android) that it can
  /// safely send shortcut data, which might have been queued.
  static Future<void> setFlutterReady() async {
    if (Platform.isIOS) {
      try {
        // Notify iOS native side.
        final ShortcutsApi iosHost = ShortcutsApi();
        await iosHost.setFlutterReady();
      } on Exception catch (e, s) {
        // Log error but don't rethrow, as this might not be critical
        // depending on the app's lifecycle management.
        debugPrint('Error setting Flutter ready on iOS: $e\n$s');
      }
    } else if (Platform.isAndroid) {
      try {
        // Notify Android native side.
        final AndroidShortcutsApi androidHost = AndroidShortcutsApi();
        await androidHost.setFlutterReady();
      } on Exception catch (e, s) {
        // Log error but don't rethrow.
        debugPrint('Error setting Flutter ready on Android: $e\n$s');
      }
    }
  }

  /// Adds a shortcut action to the stream or stores it as a pending action.
  ///
  /// This method is called internally by platform-specific handlers
  /// ([_IOSQuickActionsHandler] and [_AndroidQuickActionsHandler]) when a
  /// shortcut action is received from the native side.
  ///
  /// If the action is deemed invalid by [_isValidAction], it is ignored.
  /// If the plugin is initialized and the [shortcutStream] has listeners,
  /// the action is added to the [_shortcutController]. Otherwise, the action
  /// is stored as [_pendingAction] to be processed later.
  static void _addShortcutAction(String action) {
    // Validate the action before processing.
    if (!_isValidAction(action)) {
      debugPrint('Ignoring invalid shortcut action: $action');
      return;
    }

    // If the plugin is initialized and there are active listeners,
    // emit the action directly.
    if (_isInitialized && _hasListener) {
      _shortcutController.add(action);
    } else {
      // Otherwise, store as a pending action. This handles cases where actions
      // arrive before listeners are attached or before initialization.
      _pendingAction = action;
      // If initialization is complete, but there was no listener at the time
      // the action arrived, we call checkForListeners. This is useful if a
      // listener is attached shortly after the action is received.
      if (_isInitialized) {
        checkForListeners();
      }
    }
  }

  /// Checks if a given [action] string is considered valid.
  ///
  /// This method provides a basic filter. For example, it's used here to
  /// ignore generic Android intent actions that are not meant as app-specific
  /// shortcuts. This validation can be expanded based on the expected format
  /// of shortcut actions (e.g., checking against a list of known valid routes
  /// or patterns specific to the application).
  ///
  /// Returns `true` if the action is valid, `false` otherwise.
  static bool _isValidAction(String action) {
    // Example validation: Filter out generic Android intent actions.
    // This prevents common intents like 'android.intent.action.MAIN'
    // from being treated as app shortcuts.
    // Customize this logic based on your app's expected action formats.
    return !action.contains('android.intent.action');
  }

  /// Disposes the shortcut stream controller and clears the completer.
  ///
  /// This should be called when the app shortcuts functionality is no longer
  /// needed, such as in the `dispose` method of your main application widget
  /// or when the application is shutting down. This helps prevent memory leaks
  /// by closing the [_shortcutController] and releasing associated resources.
  static void dispose() {
    _shortcutController.close(); // Close the stream controller.
    _initializationCompleter = null; // Clean up the completer.
  }
}

/// Handles shortcut callbacks from the iOS platform.
///
/// This class acts as a bridge between the native iOS quick action handling
/// (communicated via platform channels using the `Pigeon` generated
/// `IOSShortcutsApi`) and the Dart [LauncherShortcuts] manager.
/// It receives the `action` string from iOS and forwards it to
/// [LauncherShortcuts._addShortcutAction] for processing.
class _IOSQuickActionsHandler extends IOSShortcutsApi {
  /// Called by the native iOS code when a quick action is launched.
  @override
  void launchAction(String action) {
    // Add the received action to the AppShortcuts manager.
    LauncherShortcuts._addShortcutAction(action);
    // After adding, check if listeners are now available to process it,
    // especially if this action arrived before listeners were set up.
    LauncherShortcuts.checkForListeners();
  }
}

/// Handles shortcut callbacks from the Android platform.
///
/// This class acts as a bridge between the native Android shortcut handling
/// (communicated via platform channels using the `Pigeon` generated
/// `AndroidShortcutsFlutterApi`, typically from `FlutterActivity` or a
/// similar Android component) and the Dart [LauncherShortcuts] manager.
/// It receives the `action` string from Android and forwards it to
/// [LauncherShortcuts._addShortcutAction].
class _AndroidQuickActionsHandler extends AndroidShortcutsFlutterApi {
  /// Called by the native Android code when a shortcut intent is received.
  @override
  void launchAction(String action) {
    // Add the received action to the AppShortcuts manager.
    LauncherShortcuts._addShortcutAction(action);
    // After adding, check if listeners are now available, similar to iOS.
    LauncherShortcuts.checkForListeners();
  }
}

/// A generic exception for app shortcut operations.
///
/// This exception is thrown when an error occurs during an app shortcut
/// operation, such as initialization, setting, or clearing shortcuts.
/// It provides a [message] detailing the nature of the error, which can
/// be useful for debugging or displaying user-friendly error messages.
class AppShortcutException implements Exception {
  /// A message describing the error.
  final String message;

  /// Creates an [AppShortcutException] with the given [message].
  AppShortcutException(this.message);

  @override
  String toString() => 'AppShortcutException: $message';
}

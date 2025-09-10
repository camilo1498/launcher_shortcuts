package com.pco.camilo.launcher_shortcuts

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger

/**
 * [FlutterPlugin] and [ActivityAware] implementation for the AppShortcuts plugin.
 *
 * This plugin handles communication between Flutter and the native Android
 * platform for managing app shortcuts. It correctly manages lifecycle events
 * to ensure that communication channels and handlers are set up and torn down
 * at appropriate times.
 */
class LauncherShortcutsPlugin : FlutterPlugin, ActivityAware {

  /** Reference to the current Android [Activity]. Null if not attached. */
  private var activity: Activity? = null

  /**
   * [BinaryMessenger] for communication between Flutter and native platform.
   * Initialized in [onAttachedToEngine] and cleared in
   * [onDetachedFromEngine].
   */
  private var flutterMessenger: BinaryMessenger? = null

  /**
   * Instance of [LauncherShortcutsHandler] for handling Android-specific
   * shortcut logic. Initialized in [setupApis] when an [Activity] is
   * available and cleared in [onDetachedFromEngine].
   */
  private var androidApi: LauncherShortcutsHandler? = null

  /**
   * Instance of [AndroidShortcutsFlutterApi] for sending messages from native
   * to Flutter. Initialized in [onAttachedToEngine] and cleared in
   * [onDetachedFromEngine].
   */
  private var flutterApi: AndroidShortcutsFlutterApi? = null

  /**
   * Called when the plugin is attached to the Flutter engine.
   *
   * Initializes [flutterMessenger] and [flutterApi]. It then attempts to
   * set up the method channel APIs via [setupApis], which might fully
   * complete if an [Activity] is already available (e.g., if
   * [onAttachedToActivity] was called before this).
   *
   * @param binding The binding for Flutter plugin, providing access to
   *                engine components like the [BinaryMessenger].
   */
  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    // Initialize the messenger for communication with Flutter.
    flutterMessenger = binding.binaryMessenger

    // Initialize the Flutter API (native to Flutter calls) with the messenger.
    flutterApi = AndroidShortcutsFlutterApi(binding.binaryMessenger)

    // Attempt to setup the Android and Flutter APIs. This might not fully
    // initialize androidApi if the activity is not yet available.
    setupApis()
  }

  /**
   * Sets up the Android (Flutter to native) and Flutter (native to Flutter)
   * APIs for communication.
   *
   * This method initializes [androidApi] using the current [activity] and
   * sets up the method channel communication if both [activity] and
   * [flutterMessenger] are available. It ensures that [flutterApi] is
   * passed to [androidApi] for callbacks.
   */
  private fun setupApis() {
    // Ensure both activity and flutterMessenger are available before proceeding.
    activity?.let { act ->
      flutterMessenger?.let { messenger ->
        // Initialize the Android API handler with the current activity.
        androidApi = LauncherShortcutsHandler(act)

        // Link the Flutter API to the Android API.
        // flutterApi is guaranteed non-null here if flutterMessenger is
        // non-null, as it's initialized directly after flutterMessenger
        // in onAttachedToEngine.
        androidApi?.setFlutterApi(flutterApi!!)

        // Set up the method channel for Flutter to call Android methods.
        AndroidShortcutsApi.setUp(messenger, androidApi)
      }
    }
  }

  /**
   * Called when the plugin is detached from the Flutter engine.
   *
   * Clears all references to [flutterMessenger], [androidApi], and
   * [flutterApi] to ensure proper cleanup, break circular references,
   * and prevent memory leaks.
   *
   * @param binding The binding for Flutter plugin.
   */
  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    // Clear references to avoid memory leaks and ensure a clean state
    // if the plugin is re-attached later.
    flutterMessenger = null
    androidApi = null // This also helps break any potential cycles with activity.
    flutterApi = null
  }

  // ActivityAware Lifecycle Methods

  /**
   * Called when the plugin is attached to an [Activity].
   *
   * Initializes the local [activity] reference. It then registers a listener
   * for new intents (e.g., when the app is already running and a shortcut is
   * tapped). Crucially, it calls [setupApis] to establish communication
   * channels and then calls `androidApi?.handleIntent` to process the
   * intent that started the activity (important for cold starts via shortcuts).
   *
   * @param binding The binding for activity, providing access to the
   *                [Activity] and lifecycle callbacks.
   */
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    // Initialize the activity reference.
    activity = binding.activity

    // Register listener for new intents. This handles cases where the app is
    // already running and receives a new intent (e.g., from a shortcut).
    binding.addOnNewIntentListener { intent ->
      // Ensure the activity is brought to the foreground if it exists
      intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or
              Intent.FLAG_ACTIVITY_CLEAR_TOP or
              Intent.FLAG_ACTIVITY_SINGLE_TOP

      // For launchMode="singleInstance" or "singleTask", the Android system
      // typically handles intent flags like FLAG_ACTIVITY_CLEAR_TOP.
      // This ensures the intent is passed to our handler.
      androidApi?.handleIntent(intent)

      // Indicate that the intent has been handled.
      true
    }

    // Setup the Android and Flutter APIs, now that an activity is available.
    setupApis()
    // Handle the initial intent that might have started this activity.
    // This is crucial for cold starts initiated by an app shortcut.
    androidApi?.handleIntent(binding.activity.intent)
  }

  /**
   * Called when the activity is detached from the plugin due to a
   * configuration change (e.g., screen rotation, theme change).
   *
   * Clears the local [activity] reference. The plugin will typically be
   * reattached to a new activity instance shortly via
   * [onReattachedToActivityForConfigChanges].
   */
  override fun onDetachedFromActivityForConfigChanges() {
    // Clear the activity reference as it's about to be destroyed and
    // replaced due to a configuration change.
    activity = null
  }

  /**
   * Called when the plugin is reattached to an [Activity] after a
   * configuration change.
   *
   * Re-initializes the local [activity] reference with the new activity
   * instance, re-registers the listener for new intents, and calls
   * [setupApis] to re-establish communication channels with the new
   * activity context.
   *
   * @param binding The binding for the new activity instance.
   */
  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    // Re-initialize the activity reference with the new instance.
    activity = binding.activity

    // Re-register listener for new intents with the new activity instance.
    binding.addOnNewIntentListener { intent ->
      // Similar to onAttachedToActivity, this ensures new intents are
      // processed by our handler after a configuration change.
      androidApi?.handleIntent(intent)
      true // Indicate that the intent has been handled.
    }

    // Re-setup the Android and Flutter APIs with the new activity.
    setupApis()
    // Generally, the activity's intent (binding.activity.intent) doesn't
    // need to be re-handled here as it's the same intent that caused the
    // original activity creation (or a subsequent onNewIntent), which should
    // have already been processed or will be if it's a new one via listener.
  }

  /**
   * Called when the [Activity] is detached from the plugin, and this is
   * not due to a configuration change (e.g., activity is being finished).
   *
   * Clears the local [activity] reference. If [androidApi] holds a direct
   * reference to the activity, it might become stale. However, [setupApis]
   * ensures [androidApi] is re-created with a valid activity if one
   * becomes available later. [androidApi] is also cleared in
   * [onDetachedFromEngine].
   */
  override fun onDetachedFromActivity() {
    // Clear the activity reference as the activity is being destroyed or the
    // plugin is no longer associated with it for other reasons.
    activity = null
  }
}

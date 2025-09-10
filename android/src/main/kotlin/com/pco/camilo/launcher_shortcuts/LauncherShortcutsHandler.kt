package com.pco.camilo.launcher_shortcuts

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.drawable.Icon
import android.util.Log
import com.caverock.androidsvg.SVG
import java.lang.Exception
import androidx.core.graphics.createBitmap

/**
 * Manages Android-specific application shortcut functionalities.
 *
 * This class interfaces with the Android [ShortcutManager] to dynamically
 * set, clear, and manage app shortcuts. It is also responsible for
 * processing intent actions that are triggered by shortcut interactions.
 *
 * @property context The application's [Context] for accessing system services.
 */
class LauncherShortcutsHandler(private val context: Context) : AndroidShortcutsApi {

    /**
     * Stores the last pending launch action triggered by a shortcut.
     * This is used when a shortcut is tapped before Flutter is fully ready
     * to receive the action (e.g., during a cold start).
     */
    private var pendingLaunchAction: String? = null

    /**
     * Flutter API instance for communication from native to Flutter.
     * This allows sending shortcut actions and other messages back to the
     * Flutter side of the application. It's set via [setFlutterApi].
     */
    private var flutterApi: AndroidShortcutsFlutterApi? = null

    /**
     * Tracks if Flutter is ready to receive launch actions.
     * This flag prevents sending actions to Flutter before it has initialized
     * its side of the communication channel and called [setFlutterReady].
     */
    private var isFlutterReady = false

    /**
     * Sets the Flutter API interface for communication from native to Flutter.
     * This is typically called by the plugin's setup logic when Flutter
     * initializes the communication channel.
     *
     * @param flutterApi The Flutter API implementation provided by Pigeon.
     */
    fun setFlutterApi(flutterApi: AndroidShortcutsFlutterApi) {
        this.flutterApi = flutterApi
    }

    /**
     * Retrieves the last pending launch action triggered by a shortcut.
     *
     * This action is cleared after being retrieved to ensure it's processed
     * only once by the Flutter side, typically on app startup.
     *
     * @return The pending launch action string (e.g., a shortcut type or ID),
     * or null if no action is pending.
     */
    override fun getLaunchAction(): String? {
        // Retrieve the current pending launch action.
        val action = pendingLaunchAction

        // Clear the pending action after retrieval to prevent reprocessing.
        pendingLaunchAction = null

        return action
    }

    /**
     * Sets the dynamic shortcut items for the application.
     *
     * This method updates the app's dynamic shortcuts based on the provided
     * list of [ShortcutItem]s. It builds [ShortcutInfo] objects and uses
     * the [ShortcutManager] to apply them.
     *
     * The [callback] is invoked with `Result.success(Unit)` if the shortcuts
     * are set successfully. If an error occurs (e.g., `ShortcutManager` is
     * unavailable, or the launch activity cannot be found), the [callback]
     * is invoked with `Result.failure(Exception)`.
     *
     * @param itemsList A list of [ShortcutItem] objects representing the
     * shortcuts to be set.
     * @param callback A callback function to report the result of the
     * operation (success or failure).
     */
    override fun setShortcutItems(itemsList: List<ShortcutItem>, callback: (Result<Unit>) -> Unit) {
        val result = runCatching {
            // Obtain ShortcutManager; crucial for managing shortcuts.
            // Throws IllegalStateException if the service is not available.
            val shortcutManager = context.getSystemService(ShortcutManager::class.java)
                ?: throw IllegalStateException("ShortcutManager not available")

            // Initialize FlutterLoader to access assets specified in pubspec.yaml.
            // This is necessary for loading icons from Flutter's asset system.
            val flutterLoader = io.flutter.embedding.engine.loader.FlutterLoader()
            flutterLoader.startInitialization(context)
            flutterLoader.ensureInitializationComplete(context, null)

            val shortcuts = itemsList.map { item ->
                // Create an Intent that will be triggered when the shortcut is tapped.
                val intent = Intent(context, getLaunchActivity()).apply {
                    // Define a unique action for the intent to distinguish it.
                    action = "${context.packageName}.SHORTCUT_${item.type}"
                    // Pass the shortcut type/ID as an extra for identification
                    // in handleIntent or by the launched activity.
                    putExtra("shortcut_action", item.type)
                    // Flags to ensure the activity starts in a new task,
                    // clears the task stack above it if already running,
                    // and ensures only one instance of the activity handles it.
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP
                }

                // Build the ShortcutInfo object using a builder pattern.
                val builder = ShortcutInfo.Builder(context, item.type)
                    // Set the short label (visible to user). Fallback to item.type
                    // if localizedTitle is blank.
                    .setShortLabel(item.localizedTitle.takeIf { it.isNotBlank() } ?: item.type)
                    .setIntent(intent)

                // Set long label only if it's not null or blank.
                val longLabel = item.androidConfig?.localizedLongLabel
                if (!longLabel.isNullOrBlank()) {
                    builder.setLongLabel(longLabel)
                }

                // Attempt to load and set the icon from Flutter assets if specified.
                // Attempt to load and set the icon from Flutter assets if specified.
                item.androidConfig?.icon?.let { assetRelativePath ->
                    try {
                        // Validate extension before trying to decode.
                        val lowerPath = assetRelativePath.lowercase()
                        val assetKey = flutterLoader.getLookupKeyForAsset(assetRelativePath)

                        when {
                            lowerPath.endsWith(".svg") -> {
                                try {
                                    // Render SVG to Bitmap using AndroidSVG
                                    context.assets.open(assetKey).use { inputStream ->
                                        val svg = SVG.getFromInputStream(
                                            inputStream
                                        )
                                        val picture = svg.renderToPicture()
                                        val bitmap = createBitmap(
                                            picture.width.coerceAtLeast(1),
                                            picture.height.coerceAtLeast(1)
                                        )
                                        val canvas = android.graphics.Canvas(bitmap)
                                        canvas.drawPicture(picture)
                                        builder.setIcon(Icon.createWithBitmap(bitmap))
                                    }
                                } catch (e: Exception) {
                                    Log.e(
                                        "LauncherShortcuts",
                                        "Error rendering SVG: $assetRelativePath",
                                        e
                                    )
                                }
                            }

                            lowerPath.endsWith(".png") ||
                                    lowerPath.endsWith(".jpg") ||
                                    lowerPath.endsWith(".jpeg") ||
                                    lowerPath.endsWith(".webp") -> {
                                // Raster formats → decode directly
                                context.assets.open(assetKey).use { inputStream ->
                                    val bitmap = BitmapFactory.decodeStream(inputStream)
                                    if (bitmap != null) {
                                        builder.setIcon(Icon.createWithBitmap(bitmap))
                                    } else {
                                        Log.w(
                                            "LauncherShortcuts",
                                            "Failed to decode raster image for asset: $assetRelativePath"
                                        )
                                    }
                                }
                            }

                            else -> {
                                // Skip unsupported formats silently
                                Log.w(
                                    "LauncherShortcuts",
                                    "Unsupported icon format: $assetRelativePath"
                                )
                            }
                        }
                    } catch (e: Exception) {
                        // Log errors during icon loading but don't fail shortcut creation.
                        // The shortcut will be created without this specific icon.
                        Log.e(
                            "LauncherShortcuts",
                            "Error loading asset icon: $assetRelativePath",
                            e
                        )
                    }
                }

                builder.build()
            }
            // Set/update the dynamic shortcuts. This replaces any existing list.
            shortcutManager.dynamicShortcuts = shortcuts
        }
        // Report the overall result (success or failure) via the callback.
        callback(result)
    }


    /**
     * Clears all dynamic shortcut items for the application.
     * This uses the [ShortcutManager] to remove all previously set dynamic
     * shortcuts.
     */
    override fun clearShortcutItems() {
        // Obtain the ShortcutManager system service.
        val shortcutManager = context.getSystemService(ShortcutManager::class.java)

        // Remove all dynamic shortcuts.
        // The safe call `?.` ensures no error if shortcutManager is null,
        // though this is unlikely on supported API levels.
        shortcutManager?.removeAllDynamicShortcuts()
    }

    /**
     * Notifies the handler that Flutter is ready to receive launch actions.
     *
     * This is called by Flutter when it has initialized and is ready to handle
     * callbacks from the native side, such as shortcut activation events.
     * If a pending launch action exists when this method is called, it is
     * immediately sent to Flutter via [flutterApi]. The pending action is
     * then cleared.
     *
     * @param callback A callback function to report the result of setting
     * the ready state. Typically signals `Result.success(Unit)`.
     */
    override fun setFlutterReady(callback: (Result<Unit>) -> Unit) {
        // Mark Flutter as ready to receive actions.
        isFlutterReady = true
        // If there's a pending action and Flutter is now ready, send it.
        pendingLaunchAction?.let { action ->
            // Send the action to Flutter. The callback for launchAction is
            // often a no-op if no specific response is needed from Flutter.
            flutterApi?.launchAction(action) { /* No-op callback for launchAction */ }
            // Clear the action once it has been (attempted to be) sent.
            pendingLaunchAction = null
        }
        // Signal that this operation (setting Flutter ready state) was successful.
        callback(Result.success(Unit))
    }

    /**
     * Retrieves the main launch activity class for the application.
     *
     * This is used to create intents for shortcuts, ensuring that tapping a
     * shortcut brings the correct application activity to the foreground.
     *
     * @return The [Class] of the main launch activity.
     * @throws Exception if the launch intent for the package cannot be
     * retrieved, if the launch activity's component name (which includes the
     * class name) cannot be determined, or if the class itself cannot be loaded
     * via [Class.forName].
     */
    private fun getLaunchActivity(): Class<*> {
        // Get the package manager from the application context.
        val packageManager = context.packageManager

        // Retrieve the default launch intent for the application's package.
        // This intent typically points to the main entry point of the app.
        val intent = packageManager.getLaunchIntentForPackage(context.packageName)
            ?: throw Exception("No launch activity found for package ${context.packageName}")

        // Extract the component name (package/class) from the intent.
        val componentName = intent.component
            ?: throw Exception("Launch activity componentName not found in intent")

        val className = componentName.className
        // Load and return the Class object for the launch activity using its name.
        return Class.forName(className)
    }

    /**
     * Handles incoming intents, particularly those triggered by shortcuts.
     *
     * If the intent contains a "shortcut_action" extra, this action is
     * extracted. If Flutter is ready ([isFlutterReady] is true), the action is
     * sent immediately to the Flutter side via [flutterApi]. Otherwise, it's
     * stored as [pendingLaunchAction] to be processed later when Flutter
     * signals readiness (see [setFlutterReady]).
     *
     * The "shortcut_action" extra is removed from the intent after processing
     * to prevent it from being handled multiple times if the same Intent
     * instance is passed to this method again (e.g., due to activity
     * lifecycle events like `onNewIntent` followed by `onResume` with the
     * same intent).
     *
     * @param intent The intent to handle. It might be null (e.g., if an
     * activity is started without a specific intent), in which case this
     * method does nothing.
     */
    fun handleIntent(intent: Intent?) {
        // Safely access intent extras; if intent or extra is null, action will be null.
        val action = intent?.getStringExtra("shortcut_action")

        if (action != null) {
            // If Flutter is initialized and ready, send the action immediately.
            if (isFlutterReady) {
                flutterApi?.launchAction(action) { /* No-op callback */ }
            } else {
                // Otherwise, Flutter is not ready (e.g., during cold start).
                // Store the action as pending; it will be sent when
                // setFlutterReady() is called by the Flutter side.
                pendingLaunchAction = action
            }

            // Remove the "shortcut_action" extra from the intent.
            // This is crucial to prevent the action from being processed
            // multiple times if this method is called again with the same
            // Intent object (e.g., activity lifecycle onNewIntent -> onResume).
            intent.removeExtra("shortcut_action")
        }
    }
}

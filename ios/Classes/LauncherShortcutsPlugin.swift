import Flutter
import UIKit

/// A protocol defining the contract for an object that can provide and manage
/// an array of `UIApplicationShortcutItem` instances.
///
/// This abstraction is primarily used to facilitate testing by allowing
/// mock implementations of shortcut item sources.
protocol ShortcutItemProviding: AnyObject {
    /// The application\'s dynamic shortcut items.
    ///
    /// Setting this property should update the application\'s displayed
    /// shortcuts. Getting it should return the currently set shortcuts.
    var shortcutItems: [UIApplicationShortcutItem]? { get set }
}

/// Extends `UIApplication` to conform to the `ShortcutItemProviding` protocol.
///
/// This allows `UIApplication.shared` to be used as the default provider
/// for application shortcut items, interacting directly with the iOS system.
extension UIApplication: ShortcutItemProviding {}

/// The main plugin class for the `launcher_shortcuts` Flutter plugin on iOS.
///
/// This class is responsible for:
/// - Establishing communication with the Flutter side of the plugin.
/// - Managing dynamic application shortcut items.
/// - Responding to application lifecycle events related to shortcut
///   activation.
public final class LauncherShortcutsPlugin: NSObject, FlutterPlugin, ShortcutsApi {
    /// The API used for sending messages and invoking methods on the Flutter
    /// side.
    /// This is used to notify Flutter about shortcut activations.
    private let flutterApi: IOSShortcutsApiProtocol

    /// The provider for `UIApplicationShortcutItem` instances.
    ///
    /// This is abstracted via the `ShortcutItemProviding` protocol to allow
    /// for dependency injection, primarily for testing purposes. It defaults
    /// to `UIApplication.shared`.
    private let shortcutProvider: ShortcutItemProviding

    /// Stores the `type` string of a shortcut item if the application was
    /// launched from a terminated state by that shortcut.
    ///
    /// This value is captured in `application(_:didFinishLaunchingWithOptions:)`
    /// and processed in `applicationDidBecomeActive(_:)`. It is cleared after
    /// being processed.
    private var launchingShortcutType: String?

    /// A flag indicating whether the Flutter side has signaled that it is
    /// initialized and ready to receive shortcut action events.
    /// Defaults to `false`.
    private var isFlutterReady = false

    /// Stores a shortcut action `type` string if it was received (e.g., via
    /// `performActionFor`) before Flutter was ready to handle it.
    ///
    /// This action is processed once `isFlutterReady` becomes `true`.
    private var pendingAction: String?

    /// A static reference to the plugin instance.
    ///
    /// This allows other parts of the native application (e.g., AppDelegate)
    /// to access the plugin instance if necessary, though this is generally
    /// not required for typical plugin operation.
    private static var instance: LauncherShortcutsPlugin?

    /// Registers this plugin with the Flutter engine.
    ///
    /// This static method is called by Flutter when the plugin is first
    /// registered. It sets up the method channel, application delegate,
    /// and initializes the plugin instance.
    ///
    /// - Parameter registrar: The `FlutterPluginRegistrar` provided by the
    ///   Flutter engine, used for accessing the binary messenger, registering
    ///   delegates, etc.
    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()
        // Initialize the Flutter API for communication back to Dart.
        let flutterApi = IOSShortcutsApi(binaryMessenger: messenger)
        // Create the plugin instance with the Flutter API.
        let instance = LauncherShortcutsPlugin(flutterApi: flutterApi)
        // Set up the Pigeon-generated API for calls from Dart to native.
        ShortcutsApiSetup.setUp(binaryMessenger: messenger, api: instance)
        // Register the plugin as an application delegate to receive lifecycle
        // events.
        registrar.addApplicationDelegate(instance)
        // Store the static instance.
        self.instance = instance
    }

    /// Initializes a new plugin instance.
    ///
    /// - Parameters:
    ///   - flutterApi: An object conforming to `IOSShortcutsApiProtocol`, used
    ///     for sending messages to the Flutter side.
    ///   - shortcutProvider: An object conforming to `ShortcutItemProviding`,
    ///     used to manage the application\'s shortcut items. Defaults to
    ///     `UIApplication.shared`.
    init(
        flutterApi: IOSShortcutsApiProtocol,
        shortcutProvider: ShortcutItemProviding = UIApplication.shared
    ) {
        self.flutterApi = flutterApi
        self.shortcutProvider = shortcutProvider
        super.init()
    }

    // MARK: - ShortcutsApi Implementation

    /// Sets the dynamic shortcut items for the application.
    ///
    /// This method is called from the Flutter side to update the app\'s
    /// dynamic shortcuts. It maps the provided `ShortcutItem` DTOs to
    /// `UIApplicationShortcutItem` instances.
    ///
    /// - Parameters:
    ///   - itemsList: An array of `ShortcutItem` data transfer objects,
    ///     each representing a shortcut to be set.
    ///   - completion: A closure that is called with the result of the
    ///     operation. It receives `.success(())` if the items are set
    ///     (or an empty list is processed), or an error if one occurs
    ///     (though this implementation currently does not produce errors).
    func setShortcutItems(
        itemsList: [ShortcutItem],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        shortcutProvider.shortcutItems = itemsList.compactMap { item in
            // Map the platform-agnostic icon name to a
            // UIApplicationShortcutIcon if provided.
            let icon = item.iosConfig?.icon.map {
                UIApplicationShortcutIcon(templateImageName: $0)
            }
            return UIApplicationShortcutItem(
                type: item.type,
                localizedTitle: item.localizedTitle,
                localizedSubtitle: item.iosConfig?.localizedSubtitle,
                icon: icon,
                userInfo: nil  // UserInfo is not currently used.
            )
        }
        completion(.success(()))
    }

    /// Clears all dynamic shortcut items for the application.
    ///
    /// This method is called from the Flutter side. It conforms to a
    /// potentially throwing API contract from Pigeon, but this specific
    /// implementation does not currently throw any errors.
    func clearShortcutItems() throws {
        shortcutProvider.shortcutItems = []
    }

    /// Notifies the plugin that the Flutter side is initialized and ready to
    /// handle shortcut actions.
    ///
    /// If a `pendingAction` (a shortcut action received before Flutter was
    /// ready) exists, it will be processed immediately.
    ///
    /// - Parameter completion: A closure that is called with the result of the
    ///   operation. It receives `.success(())` upon completion.
    func setFlutterReady(completion: @escaping (Result<Void, Error>) -> Void) {
        isFlutterReady = true
        // If there was an action waiting for Flutter to be ready, handle it now.
        if let action = pendingAction {
            handleShortcut(action)
            pendingAction = nil  // Clear the pending action after handling.
        }
        completion(.success(()))
    }

    // MARK: - UIApplicationDelegate Implementation

    /// Handles the scenario where the app is launched from a terminated state
    /// via a shortcut item.
    ///
    /// This method checks the `launchOptions` for a shortcut item. If found,
    /// it stores the shortcut\'s `type` and returns `false` to prevent
    /// `application(_:performActionFor:completionHandler:)` from being
    /// called redundantly.
    ///
    /// - Parameters:
    ///   - application: The singleton `UIApplication` object.
    ///   - launchOptions: A dictionary indicating the reason the app was
    ///     launched. This may contain the `UIApplication.LaunchOptionsKey
    ///     .shortcutItem` key.
    /// - Returns: `false` if the app was launched by a shortcut item,
    ///   indicating that the shortcut launch has been acknowledged. `true`
    ///   otherwise.
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions:
            [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if let shortcutItem = launchOptions?[.shortcutItem]
            as? UIApplicationShortcutItem
        {
            // Store the type of the shortcut that launched the app.
            // This will be processed in `applicationDidBecomeActive`.
            launchingShortcutType = shortcutItem.type
            // Return false to indicate we\'ve handled the shortcut launch.
            // This prevents `performActionFor` from being called for this
            // initial launch shortcut.
            return false
        }
        return true
    }

    /// Handles shortcut item processing when the app becomes active.
    ///
    /// This method is called after `didFinishLaunchingWithOptions` (for cold
    /// starts) or when the app returns from the background. It processes any
    /// `launchingShortcutType` captured at launch or any `pendingAction`
    /// that was queued while Flutter was not ready.
    ///
    /// - Parameter application: The singleton `UIApplication` object.
    public func applicationDidBecomeActive(_ application: UIApplication) {
        // Process shortcut from a cold start, if any.
        if let type = launchingShortcutType {
            if isFlutterReady {
                handleShortcut(type)
            } else {
                // If Flutter is not ready yet, store this as a pending action.
                pendingAction = type
            }
            // Clear the launching shortcut type as it\'s been acknowledged.
            launchingShortcutType = nil
        }

        // Process any other pending action if Flutter is now ready.
        // This can happen if a shortcut was activated while the app was in the
        // background and Flutter wasn\'t ready, then became active.
        if let action = pendingAction, isFlutterReady {
            handleShortcut(action)
            pendingAction = nil
        }
    }

    /// Handles shortcut item selection when the app is already running (either
    /// in the foreground or background).
    ///
    /// If Flutter is ready, the shortcut action is handled immediately.
    /// Otherwise, it is stored as a `pendingAction`.
    ///
    /// - Parameters:
    ///   - application: The singleton `UIApplication` object.
    ///   - shortcutItem: The `UIApplicationShortcutItem` that was selected by
    ///     the user.
    ///   - completionHandler: A block to call with a Boolean value. `true`
    ///     indicates the shortcut action was handled (or will be handled).
    /// - Returns: Always returns `true` as the action is either handled
    ///   immediately or queued.
    public func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) -> Bool {
        if isFlutterReady {
            handleShortcut(shortcutItem.type)
        } else {
            // If Flutter is not ready, store the action to be handled later.
            pendingAction = shortcutItem.type
        }
        // Indicate that the shortcut action has been (or will be) handled.
        completionHandler(true)
        return true
    }

    // MARK: - Private Helper Methods

    /// Sends the shortcut action `type` to the Flutter side via the
    /// `flutterApi`.
    ///
    /// This method dispatches the call to the main thread to ensure UI-related
    /// Flutter calls are safe.
    ///
    /// - Parameter type: The `type` string of the shortcut item that was
    ///   activated.
    private func handleShortcut(_ type: String) {
        DispatchQueue.main.async {
            self.flutterApi.launchAction(action: type) { result in
                // The result of the Flutter call can be logged or handled
                // here if needed in the future (e.g., for error reporting).
                if case .failure(let error) = result {
                    // Example: Log error if Flutter side reports an issue.
                    NSLog("Error from Flutter launchAction: \(error)")
                }
            }
        }
    }

    /// Provides static access to the plugin instance.
    ///
    /// This can be used by other parts of the native iOS application (e.g.,
    /// `AppDelegate`) to interact with the plugin if necessary, although such
    /// direct interaction is generally discouraged in favor of Flutter-side
    /// control and standard plugin lifecycle management.
    ///
    /// - Returns: The singleton instance of `LauncherShortcutsPlugin`, or `nil`
    ///   if the plugin has not been registered or has been deallocated.
    public static func getInstance() -> LauncherShortcutsPlugin? {
        return instance
    }
}

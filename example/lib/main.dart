import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:launcher_shortcuts/launcher_shortcuts.dart';
import 'package:launcher_shortcuts_example/sub_pages/first_page.dart';
import 'package:launcher_shortcuts_example/sub_pages/second_page.dart';

/// Initializes the application and sets up app shortcuts.
///
/// Ensures Flutter bindings are initialized, initializes the [LauncherShortcuts]
/// plugin, and runs the [MyApp] widget.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize the app shortcuts plugin before running the app.
  await LauncherShortcuts.initialize();
  runApp(const MyApp());
}

/// The root widget of the application.
///
/// This widget is a [StatefulWidget] that sets up the main application
/// structure and state.
class MyApp extends StatefulWidget {
  /// Creates an instance of [MyApp].
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

/// The state for the [MyApp] widget.
///
/// Manages the [NavigatorState] and listens for app shortcut events.
class _MyAppState extends State<MyApp> {
  /// A global key for accessing the [NavigatorState].
  ///
  /// This key is used to navigate programmatically in response to app
  /// shortcut activations.
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Force listener check on initialization. This ensures that any pending
    // shortcut actions are processed when the app starts or the state
    // is initialized.
    LauncherShortcuts.checkForListeners();

    // Subscribe to the shortcut stream to handle incoming shortcut events.
    // This listener will be invoked when a shortcut is activated.
    LauncherShortcuts.shortcutStream.listen(_handleShortcut);
  }

  /// Handles incoming app shortcut actions.
  ///
  /// Navigates to the appropriate route based on the [type] of the
  /// activated shortcut. If the navigator can pop, it replaces the current
  /// route; otherwise, it pushes a new route. This handles both cold starts
  /// and warm starts.
  void _handleShortcut(String type) {
    if (navigatorKey.currentState != null) {
      // For a cold start (or if no pages are in the stack), replace the
      // initial route. Otherwise, push the new route.
      if (navigatorKey.currentState!.canPop()) {
        navigatorKey.currentState?.pushReplacementNamed(type);
      } else {
        navigatorKey.currentState?.pushNamed(type);
      }
    }
  }

  @override
  void dispose() {
    // Dispose of the AppShortcuts resources, particularly the stream
    // subscription, when the widget is disposed to prevent memory leaks.
    LauncherShortcuts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AppShortcuts Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      navigatorKey: navigatorKey,
      routes: {
        '/': (context) => const ShortcutDemoPage(),
        FirstPage.path: (context) => const FirstPage(),
        SecondPage.path: (context) => const SecondPage(),
      },
      initialRoute: '/',
      // Handles unknown routes by navigating to the main demo page.
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const ShortcutDemoPage(),
        );
      },
    );
  }
}

/// A page demonstrating the app shortcuts functionality.
///
/// Allows users to register and clear app shortcuts. It serves as the
/// main screen of the example application.
class ShortcutDemoPage extends StatefulWidget {
  /// Creates an instance of [ShortcutDemoPage].
  const ShortcutDemoPage({super.key});

  @override
  State<ShortcutDemoPage> createState() => _ShortcutDemoPageState();
}

/// The state for the [ShortcutDemoPage] widget.
///
/// Manages the registration and clearing of app shortcuts.
class _ShortcutDemoPageState extends State<ShortcutDemoPage> {
  @override
  void initState() {
    super.initState();
    // Register initial shortcuts when the page is created.
    _registerShortcuts();
  }

  /// Registers a set of predefined app shortcuts.
  ///
  /// This method demonstrates how to use [LauncherShortcuts.setShortcuts]
  /// to define dynamic shortcuts for the application. These shortcuts
  /// allow users to quickly access specific parts of the app.
  Future<void> _registerShortcuts() async {
    try {
      await LauncherShortcuts.setShortcuts([
        ShortcutItem(
          type: FirstPage.path,
          localizedTitle: 'Search',
          androidConfig: AndroidConfig(icon: 'assets/launcher/search.png'),
          iosConfig: IosConfig(
            icon: 'search',
            localizedSubtitle: 'Go to find something',
          ),
        ),

        ShortcutItem(
          type: SecondPage.path,
          localizedTitle: 'Create Post',
          androidConfig: AndroidConfig(icon: 'assets/launcher/add_file.png'),
          iosConfig: IosConfig(
            icon: 'add_file',
            localizedSubtitle: 'Go to create a new post',
          ),
        ),
      ]);
    } catch (e) {
      log('Error setting shortcuts: $e');
    }
  }

  /// Clears all previously registered app shortcuts.
  ///
  /// Shows a [SnackBar] message to confirm the action or to display an error
  /// if the operation fails.
  Future<void> _clearShortcuts() async {
    try {
      await LauncherShortcuts.clearShortcuts();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Shortcuts cleared')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error clearing shortcuts: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AppShortcuts Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Main Page', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, FirstPage.path);
              },
              child: const Text('Go to First Page'),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, SecondPage.path);
              },
              child: const Text('Go to Second Page'),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: _clearShortcuts,
              child: const Text('Clear Shortcuts'),
            ),
          ],
        ),
      ),
    );
  }
}

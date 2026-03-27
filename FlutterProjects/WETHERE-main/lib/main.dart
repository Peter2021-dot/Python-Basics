import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'providers/journey_provider.dart';
import 'providers/application_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'firebase_options.dart';
import 'services/payment_service.dart';
import 'services/notification_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase and capture failures so the app shows a helpful error
  // instead of a blank white screen.
  Object? initError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    initError = e;
    // print stack to console for logs
    // ignore: avoid_print
    print('Firebase.initializeApp error: $e\n$st');
  }

  // Initialize Stripe (skip on web - not fully supported)
  if (!kIsWeb) {
    try {
      await PaymentService().init();
    } catch (e) {
      print('Stripe initialization error: $e');
    }
  }

  // Initialize Notifications (skip on web - FCM has limited web support)
  if (!kIsWeb) {
    try {
      await NotificationService().initialize();
    } catch (e) {
      print('Notification initialization error: $e');
    }
  }


  runApp(MyApp(initError: initError));
}

class MyApp extends StatelessWidget {
  final Object? initError;
  const MyApp({this.initError, super.key});

  @override
  Widget build(BuildContext context) {
    if (initError != null) {
      return MaterialApp(
        title: 'Togetherness',
        debugShowCheckedModeBanner: false,
        home: InitializationErrorPage(error: initError),
      );
    }

    // ✅ FIX: Wrap the ENTIRE MaterialApp with MultiProvider
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => JourneyProvider()),
        // Add more providers here as needed:
        ChangeNotifierProvider(create: (_) => ApplicationProvider()),
        // ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return ShadApp.custom(
            themeMode: themeProvider.themeMode,
            darkTheme: ShadThemeData(
              brightness: Brightness.dark,
              colorScheme: const ShadSlateColorScheme.dark(),
            ),
            appBuilder: (context) {
              final themeData = ShadTheme.of(context);
              return MaterialApp(
                title: 'WeThere',
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                  fontFamily: themeData.textTheme.family,
                  extensions: themeData.extensions,
                  colorScheme: ColorScheme(
                    brightness: themeData.brightness,
                    primary: themeData.colorScheme.primary,
                    onPrimary: themeData.colorScheme.primaryForeground,
                    secondary: themeData.colorScheme.secondary,
                    onSecondary: themeData.colorScheme.secondaryForeground,
                    error: themeData.colorScheme.destructive,
                    onError: themeData.colorScheme.destructiveForeground,
                    surface: themeData.colorScheme.background,
                    onSurface: themeData.colorScheme.foreground,
                  ),
                  scaffoldBackgroundColor: themeData.colorScheme.background,
                  brightness: themeData.brightness,
                  dividerTheme: DividerThemeData(
                    color: themeData.colorScheme.border,
                    thickness: 1,
                  ),
                  textSelectionTheme: TextSelectionThemeData(
                    cursorColor: themeData.colorScheme.primary,
                    selectionColor: themeData.colorScheme.selection,
                    selectionHandleColor: themeData.colorScheme.primary,
                  ),
                  iconTheme: IconThemeData(
                    size: 16,
                    color: themeData.colorScheme.foreground,
                  ),
                  scrollbarTheme: ScrollbarThemeData(
                    crossAxisMargin: 1,
                    mainAxisMargin: 1,
                    thickness: const WidgetStatePropertyAll(8),
                    radius: const Radius.circular(999),
                    thumbColor: WidgetStatePropertyAll(themeData.colorScheme.border),
                  ),
                ),
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                ],
                builder: (context, child) {
                  return ShadAppBuilder(child: child!);
                },
                // Use RootPage to handle authenticated vs unauthenticated state
                home: const RootPage(),
              );
            },
          );
        },
      ),
    );
  }
}

class InitializationErrorPage extends StatelessWidget {
  final Object? error;
  const InitializationErrorPage({this.error, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Initialization Error')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'There was an error initializing the app:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                error?.toString() ?? 'Unknown error',
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 20),
              const Text('Common issues:'),
              const SizedBox(height: 8),
              const Text('• Check that google-services.json (Android) is in android/app/'),
              const Text('• Check that GoogleService-Info.plist (iOS) is in ios/Runner/'),
              const Text('• Ensure Firebase project is properly configured'),
              const Text('• Run "flutter clean" and rebuild'),
              const SizedBox(height: 20),
              const Text('Check your console logs for the full stack trace.'),
            ],
          ),
        ),
      ),
    );
  }
}

class RootPage extends StatelessWidget {
  const RootPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading spinner while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // User is logged in - go to HomePage
        if (snapshot.hasData && snapshot.data != null) {
          return const HomePage();
        }

        // User is not logged in - go to LoginPage
        return const LoginPage();
      },
    );
  }
}

// flutter run -d web-server --web-port=8080
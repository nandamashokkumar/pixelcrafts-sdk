# Example integration

Minimal Flutter app showing `pixelcrafts_auth` wired end-to-end. Five files:

```
main.dart                   App bootstrap — Firebase init + PCAuth.configure
api_client.dart             Your Dio with the SDK interceptor attached
app_router.dart             GoRouter with auth-state redirect
screens/login_screen.dart   Sign-in form
screens/home_screen.dart    Authenticated landing
```

## `main.dart`

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:pixelcrafts_auth/pixelcrafts_auth.dart';

import 'firebase_options.dart';  // your app's, from `flutterfire configure`
import 'app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  PCAuth.configure(const PCAuthConfig(appId: 'example'));
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(routerConfig: appRouter);
  }
}
```

## `api_client.dart`

```dart
import 'package:dio/dio.dart';
import 'package:pixelcrafts_auth/pixelcrafts_auth.dart';

final apiClient = Dio(
  BaseOptions(baseUrl: 'https://api.pixelcrafts.app/api/v1'),
)..interceptors.add(PCAuth.instance.interceptor);

// Now every apiClient.get / post is authenticated automatically.
```

## `app_router.dart`

```dart
import 'package:go_router/go_router.dart';
import 'package:pixelcrafts_auth/pixelcrafts_auth.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  refreshListenable: _AuthListenable(),
  redirect: (context, state) {
    final authState = PCAuth.instance.currentState;
    final isLoggingIn = state.matchedLocation == '/login';
    if (authState == PCAuthState.unauthenticated && !isLoggingIn) {
      return '/login';
    }
    if (authState == PCAuthState.authenticated && isLoggingIn) {
      return '/';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
  ],
);

class _AuthListenable extends ChangeNotifier {
  _AuthListenable() {
    PCAuth.instance.authStateChanges.listen((_) => notifyListeners());
    // Also route on session-expired (handled separately because the
    // interceptor calls this directly when refresh fails).
    PCAuth.instance.onSessionExpired = notifyListeners;
  }
}
```

## `screens/login_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:pixelcrafts_auth/pixelcrafts_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() { _busy = true; _error = null; });
    try {
      await PCAuth.instance.signInWithEmail(_email.text, _password.text);
      // Router redirects automatically on state change.
    } on PCSignInException catch (e) {
      if (!e.cancelled) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInGoogle() async {
    setState(() => _busy = true);
    try {
      await PCAuth.instance.signInWithGoogle();
    } on PCSignInException catch (e) {
      if (!e.cancelled) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    if (_email.text.isEmpty) {
      setState(() => _error = 'Enter your email first');
      return;
    }
    try {
      await PCAuth.instance.sendPasswordResetEmail(_email.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reset email sent to ${_email.text}')),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            ElevatedButton(onPressed: _busy ? null : _signIn, child: const Text('Sign in')),
            TextButton(onPressed: _busy ? null : _signInGoogle, child: const Text('Sign in with Google')),
            TextButton(onPressed: _busy ? null : _forgotPassword, child: const Text('Forgot password?')),
          ],
        ),
      ),
    );
  }
}
```

## `screens/home_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:pixelcrafts_auth/pixelcrafts_auth.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = PCAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: Text('Hello ${user?.email ?? "?"}')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => PCAuth.instance.signOut(),
          child: const Text('Sign out'),
        ),
      ),
    );
  }
}
```

That's the complete loop. ~100 lines of consumer code; the SDK handles every async edge case behind the surface.

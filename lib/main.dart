import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kioku/signup_page.dart';
import 'firebase_options.dart';
import 'landing_page.dart';
import 'browser_page.dart';
import 'api_send.dart';
import 'edge_panel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'proj_chat.dart';
import 'test_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
   
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Supabase.initialize(
    url: 'https://ajadkbptgmwmjrsotcvr.supabase.co',
    anonKey: dotenv.env['supabasekey']!
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kioku',
        theme: ThemeData(
        primarySwatch: Colors.indigo,
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.indigo,
          foregroundColor: Color.fromARGB(255, 236, 141, 245),
          shape: CircleBorder(),
        ),),
      initialRoute: '/', // default route
      routes: {
        '/': (context) => const AuthGate(), // checks auth
        '/login': (context) => const LandingPage(),
        '/browser': (context) => const BrowserPage(),
        '/signup' : (context) => const SignUpPage(),
        '/api_send': (context) =>const ApiSend(projectId:"ffd"),
        '/chat_proj':(context)=> const ProjectChatScreen(projectId:"ffd"),
        '/make_test': (context) {
  final pageUrl = ModalRoute.of(context)!.settings.arguments as String?;
  return MCQTestScreen(projectId:"ff" ?? '');
},

      },
    );
  }
}

/// Checks auth and redirects to correct page
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // User already logged in
    if (user != null) {
      // Navigate to browser page
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/browser');
      });
    } else {
      // Navigate to login page
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
    }

    // Show splash/loading while checking auth
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

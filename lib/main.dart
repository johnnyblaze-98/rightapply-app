
import 'package:flutter/material.dart';
import 'device_authentication.dart';
import 'admin_page.dart';


void main() {
  runApp(const AppWithSplash());
}


class AppWithSplash extends StatefulWidget {
  const AppWithSplash({super.key});

  @override
  State<AppWithSplash> createState() => _AppWithSplashState();
}

class _AppWithSplashState extends State<AppWithSplash> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _startApp();
  }

  Future<void> _startApp() async {
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _showSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RightApply.ai',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => _showSplash ? SplashScreen() : DeviceAuthenticationPage(),
        '/admin': (context) => AdminPage(),
      },
    );
  }
}


class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.08),
                    blurRadius: 32,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              padding: EdgeInsets.all(32),
              child: Icon(Icons.devices, color: Color(0xFF1565C0), size: 64),
            ),
            SizedBox(height: 32),
            Text(
              'RightApply.ai',
              style: TextStyle(fontSize: 28, color: Color(0xFF1565C0), fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            SizedBox(height: 10),
            Text(
              'Enterprise Device Management',
              style: TextStyle(fontSize: 18, color: Color(0xFF222B45), fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'This app helps you securely authenticate and manage your devices. Please wait while we set things up for you.',
                style: TextStyle(fontSize: 15, color: Color(0xFF4A5568)),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Color(0xFF1565C0)),
            SizedBox(height: 24),
            Text(
              'Tip: Tap anywhere to continue if loading takes too long.',
              style: TextStyle(fontSize: 13, color: Color(0xFF90A4AE)),
            ),
          ],
        ),
      ),
    );
  }
}


// Removed duplicate MyApp class and legacy comments for clarity.


// Removed legacy MyHomePage widget. DeviceAuthenticationPage is now the entry point.

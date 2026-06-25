import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../dashboard/home_shell.dart';
import '../widgets/auth_button.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ///  Gradient Background
          Container(
            decoration: const BoxDecoration(gradient: AppTheme.gradient),
          ),

          ///  Unsplash Background Image (Network)
          Positioned.fill(
            child: Opacity(
              opacity: 0.12, // tuned for Unsplash contrast
              child: Image.network(
                // same Unsplash medical / healthcare style image
                "https://images.unsplash.com/photo-1588776814546-1ffcf47267a5?auto=format&fit=crop&w=1350&q=80",
                fit: BoxFit.cover,
              ),
            ),
          ),

          ///  Foreground Content
          SafeArea(
            child: Column(
              children: [
                const Spacer(),

                const Text(
                  "Welcome",
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  "Your medicine monitoring dashboard",
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),

                const SizedBox(height: 60),

                /// Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "You're all set!",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        "Manage your devices, monitor levels and configure reorder settings.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),

                      const SizedBox(height: 30),

                      AuthButton(
                        label: "Go to Dashboard",
                        onTap: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HomeShell(),
                            ),
                            (_) => false,
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

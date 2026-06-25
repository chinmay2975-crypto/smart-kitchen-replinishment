import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../repository/auth_repository.dart';
import 'welcome_page.dart';

enum OTPFlowType { signup, signin }

class OTPPage extends StatelessWidget {
  final OTPFlowType flowType;

  // signup-only fields
  final String? name;
  final String? surname;
  final String? address;
  final String? email;
  final String? phone;
  final String? password;
  final String? city;
  final String? state;
  final int? pincode;

  const OTPPage({
    super.key,
    required this.flowType,
    this.name,
    this.surname,
    this.address,
    this.email,
    this.phone,
    this.password,
    this.city,
    this.state,
    this.pincode,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// Background Gradient
          Container(
            decoration: const BoxDecoration(gradient: AppTheme.gradient),
          ),

          /// Background Image
          Opacity(
            opacity: 0.06,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(
                    "https://images.unsplash.com/photo-1518770660439-4636190af475",
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          /// Title
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  "Verify OTP",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          /// Card
          Center(
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Enter OTP",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),

                  const SizedBox(height: 20),

                  /// Fake OTP input
                  TextField(
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: "••••••",
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  /// Continue
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                      onPressed: () async {
                        try {
                          final repo = AuthRepository();

                          if (flowType == OTPFlowType.signup) {
                            // REAL SIGNUP
                            await repo.signUpWithPassword(
                              email: email!,
                              password: password!,
                              name: name!,
                              surname: surname!,
                              address: address!,
                              phone: phone!,
                              city: city!,
                              state: state!,
                              pincode: pincode!,
                            );
                          }

                          // signin already done BEFORE OTP page

                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WelcomePage(),
                            ),
                            (_) => false,
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      },
                      child: const Text(
                        "Continue",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

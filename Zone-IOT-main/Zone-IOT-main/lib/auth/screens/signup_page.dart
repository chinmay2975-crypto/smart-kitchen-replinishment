import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'otp_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final nameController = TextEditingController();
  final surnameController = TextEditingController();
  final addressController = TextEditingController();
  final cityController = TextEditingController();
  final stateController = TextEditingController();
  final pincodeController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  bool _showPassword = false;

  @override
  void dispose() {
    nameController.dispose();
    surnameController.dispose();
    addressController.dispose();
    cityController.dispose();
    stateController.dispose();
    pincodeController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    // 🔒 EMPTY CHECK
    if (nameController.text.trim().isEmpty ||
        surnameController.text.trim().isEmpty ||
        addressController.text.trim().isEmpty ||
        cityController.text.trim().isEmpty ||
        stateController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty ||
        pincodeController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      _showError('All fields are required');
      return;
    }

    // 📮 PINCODE
    final pincode = int.tryParse(pincodeController.text.trim());
    if (pincode == null || pincode <= 0) {
      _showError('Invalid pincode');
      return;
    }

    // 📧 EMAIL
    final email = emailController.text.trim();
    if (!email.contains('@')) {
      _showError('Please enter a valid email');
      return;
    }

    // 🔑 PASSWORD VALIDATION
    final password = passwordController.text.trim();

    if (password.length < 8) {
      _showError('Password must be at least 8 characters');
      return;
    }

    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasNumber = RegExp(r'\d').hasMatch(password);

    if (!hasLetter || !hasNumber) {
      _showError('Password must contain letters and numbers');
      return;
    }

    // 🚪 OTP PAGE = GATEPASS ONLY
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OTPPage(
          flowType: OTPFlowType.signup,
          name: nameController.text.trim(),
          surname: surnameController.text.trim(),
          address: addressController.text.trim(),
          city: cityController.text.trim(),
          state: stateController.text.trim(),
          pincode: pincode,
          email: email,
          phone: phoneController.text.trim(),
          password: password,
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2C2C54), Color(0xFF40407A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  "New User Registration",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.96),
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
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _inputField(
                            controller: nameController,
                            label: "Name",
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _inputField(
                            controller: surnameController,
                            label: "Surname",
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    _inputField(
                      controller: addressController,
                      label: "Address",
                    ),

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _inputField(
                            controller: cityController,
                            label: "City",
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _inputField(
                            controller: stateController,
                            label: "State",
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    _inputField(
                      controller: pincodeController,
                      label: "Pincode",
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                    ),

                    const SizedBox(height: 16),
                    _inputField(controller: emailController, label: "Email"),

                    const SizedBox(height: 16),
                    _inputField(
                      controller: passwordController,
                      label: "Password",
                      obscure: !_showPassword,
                      suffix: IconButton(
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _showPassword = !_showPassword);
                        },
                      ),
                    ),

                    const SizedBox(height: 16),
                    _inputField(
                      controller: phoneController,
                      label: "Phone",
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                    ),

                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
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
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:iot/auth/repository/auth_repository.dart';
import 'package:iot/theme/app_theme.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final newController = TextEditingController();
  final confirmController = TextEditingController();

  bool loading = false;
  bool showPassword = false;

  @override
  void dispose() {
    newController.dispose();
    confirmController.dispose();
    super.dispose();
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

  Future<void> _submit() async {
    final newPassword = newController.text.trim();
    final confirmPassword = confirmController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showError('All fields are required');
      return;
    }

    if (newPassword.length < 8) {
      _showError('Password must be at least 8 characters long');
      return;
    }

    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(newPassword);
    final hasNumber = RegExp(r'\d').hasMatch(newPassword);

    if (!hasLetter || !hasNumber) {
      _showError('Password must contain letters and numbers');
      return;
    }

    if (newPassword != confirmPassword) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => loading = true);

    try {
      await AuthRepository().updatePassword(newPassword: newPassword);

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text("Change Password")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _field("New Password", newController, suffix: _toggle()),
            const SizedBox(height: 16),
            _field("Confirm Password", confirmController, suffix: _toggle()),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: loading ? null : _submit,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Update Password"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggle() {
    return IconButton(
      icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
      onPressed: () {
        setState(() => showPassword = !showPassword);
      },
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: !showPassword,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

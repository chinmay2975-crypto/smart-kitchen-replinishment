import 'dart:async';

class ResendOtpService {
  /// TEMPLATE: Send OTP (email or phone)
  Future<(bool, String)> sendOtp(String email, String phone) async {
    try {
      // TODO: implement actual RESEND API call

      print("Sending OTP to email: $email and phone: $phone");

      return (true, "OTP sent successfully");
    } catch (e) {
      return (false, e.toString());
    }
  }

  /// TEMPLATE: Verify OTP
  Future<(bool, String)> verifyOtp(
    String email,
    String phone,
    String otp,
  ) async {
    try {
      // TODO: implement verify OTP logic

      print("Verifying OTP: $otp for $email / $phone");

      return (true, "OTP verified");
    } catch (e) {
      return (false, e.toString());
    }
  }
}

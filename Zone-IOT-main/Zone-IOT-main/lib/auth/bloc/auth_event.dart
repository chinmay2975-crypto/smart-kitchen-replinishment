import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

// ------------------------ SIGN UP ------------------------

class SignUpSubmitted extends AuthEvent {
  final String name;
  final String surname;
  final String address;
  final String email;
  final String phone;

  SignUpSubmitted({
    required this.name,
    required this.surname,
    required this.address,
    required this.email,
    required this.phone,
  });

  @override
  List<Object?> get props => [name, surname, address, email, phone];
}

// ------------------------ SIGN IN ------------------------

class SignInSubmitted extends AuthEvent {
  final String email;
  final String phone;

  SignInSubmitted({required this.email, required this.phone});

  @override
  List<Object?> get props => [email, phone];
}

// ------------------------ OTP VERIFY ------------------------

class VerifyOtp extends AuthEvent {
  final String email;
  final String phone;
  final String otp;

  VerifyOtp({required this.email, required this.phone, required this.otp});

  @override
  List<Object?> get props => [email, phone, otp];
}

// ------------------------ RESET ------------------------

class ResetAuth extends AuthEvent {}

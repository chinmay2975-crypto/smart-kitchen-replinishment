import 'package:flutter_bloc/flutter_bloc.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(AuthInitial()) {
    // SIGN UP → OTP screen (UI only)
    on<SignUpSubmitted>((event, emit) async {
      emit(AuthLoading());
      emit(OtpSent());
    });

    // SIGN IN → OTP screen (UI only)
    on<SignInSubmitted>((event, emit) async {
      emit(AuthLoading());
      emit(OtpSent());
    });

    // VERIFY OTP → success (UI only)
    on<VerifyOtp>((event, emit) async {
      emit(AuthLoading());
      emit(AuthSuccess(null));
    });

    // RESET
    on<ResetAuth>((event, emit) {
      emit(AuthInitial());
    });
  }
}

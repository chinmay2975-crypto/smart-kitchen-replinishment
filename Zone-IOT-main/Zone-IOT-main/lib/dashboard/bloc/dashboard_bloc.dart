import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/repository/auth_repository.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final AuthRepository authRepository;
  final SupabaseClient _client = Supabase.instance.client;

  DashboardBloc(this.authRepository) : super(DashboardInitial()) {
    on<DashboardStarted>(_onStarted);
    on<DashboardLogoutRequested>(_onLogout);
  }

  Future<void> _onStarted(
    DashboardStarted event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoading());

    try {
      // Wait until Supabase restores auth session
      await _client.auth.onAuthStateChange.first;

      final user = _client.auth.currentUser;

      if (user == null) {
        emit(DashboardUnauthenticated());
        return;
      }

      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      emit(DashboardLoaded(user: user, profile: profile));
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }

  Future<void> _onLogout(
    DashboardLogoutRequested event,
    Emitter<DashboardState> emit,
  ) async {
    await authRepository.signOut();
    emit(DashboardUnauthenticated());
  }
}

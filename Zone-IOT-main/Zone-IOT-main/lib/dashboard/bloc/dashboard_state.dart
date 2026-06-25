import 'package:supabase_flutter/supabase_flutter.dart';

abstract class DashboardState {}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardUnauthenticated extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final User user;
  final Map<String, dynamic> profile;

  DashboardLoaded({required this.user, required this.profile});
}

class DashboardError extends DashboardState {
  final String message;
  DashboardError(this.message);
}

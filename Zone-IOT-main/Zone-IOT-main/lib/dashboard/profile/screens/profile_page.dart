import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iot/dashboard/profile/screens/change_password_page.dart';
import 'package:iot/dashboard/profile/screens/edit_profile_page.dart';
import 'package:iot/dashboard/profile/repository/profile_repository.dart';

import '../../../theme/app_theme.dart';
import '../../bloc/dashboard_bloc.dart';
import '../../bloc/dashboard_event.dart';
import '../../bloc/dashboard_state.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final profileRepo = ProfileRepository();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: BlocBuilder<DashboardBloc, DashboardState>(
          builder: (context, state) {
            if (state is DashboardLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is DashboardError) {
              return Center(
                child: Text(state.message, textAlign: TextAlign.center),
              );
            }

            if (state is DashboardUnauthenticated) {
              return const Center(child: Text("User not logged in"));
            }

            if (state is DashboardLoaded) {
              final profile = state.profile;
              final user = state.user;

              final name =
                  "${profile['name'] ?? ''} ${profile['surname'] ?? ''}".trim();
              final email = user.email ?? '';
              final phone = profile['phone'] ?? 'Not provided';

              // IMPORTANT: address is INT FK
              final int? addressId = profile['address'];

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// -------------------------
                    /// PROFILE HEADER
                    /// -------------------------
                    Center(
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: 48,
                            backgroundColor: AppTheme.accent,
                            child: Icon(
                              Icons.person,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            name.isEmpty ? "User" : name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    /// -------------------------
                    /// ACCOUNT INFORMATION
                    /// -------------------------
                    const Text(
                      "Account Information",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    _infoTile(
                      icon: Icons.phone,
                      title: "Phone Number",
                      value: phone,
                    ),

                    /// -------------------------
                    /// DEFAULT ADDRESS (FK RESOLVED HERE)
                    /// -------------------------
                    addressId == null
                        ? _infoTile(
                            icon: Icons.location_on,
                            title: "Default Address",
                            value: "Not provided",
                          )
                        : FutureBuilder<Map<String, dynamic>?>(
                            future: profileRepo.getAddressById(addressId),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return _infoTile(
                                  icon: Icons.location_on,
                                  title: "Default Address",
                                  value: "Loading address...",
                                );
                              }

                              if (!snapshot.hasData || snapshot.data == null) {
                                return _infoTile(
                                  icon: Icons.location_on,
                                  title: "Default Address",
                                  value: "Address not found",
                                );
                              }

                              final addr = snapshot.data!;
                              final formatted =
                                  '${addr['address']}, '
                                  '${addr['city']}, '
                                  '${addr['state']} - '
                                  '${addr['pincode']}';

                              return _infoTile(
                                icon: Icons.location_on,
                                title: "Default Address",
                                value: formatted,
                              );
                            },
                          ),

                    _infoTile(
                      icon: Icons.verified_user,
                      title: "Account Status",
                      value: "Verified",
                    ),

                    const SizedBox(height: 24),

                    /// -------------------------
                    /// PREFERENCES
                    /// -------------------------
                    const Text(
                      "Preferences",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    _actionTile(
                      icon: Icons.edit,
                      title: "Edit Profile",
                      onTap: () async {
                        final updated = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditProfilePage(profile: profile),
                          ),
                        );
                        if (updated == true) {
                          context.read<DashboardBloc>().add(DashboardStarted());
                        }
                      },
                    ),

                    _actionTile(
                      icon: Icons.lock,
                      title: "Change Password",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChangePasswordPage(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 30),

                    /// -------------------------
                    /// LOGOUT
                    /// -------------------------
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.logout),
                        label: const Text(
                          "Logout",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        onPressed: () {
                          context.read<DashboardBloc>().add(
                            DashboardLogoutRequested(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            }

            return const Center(child: Text("Initializing..."));
          },
        ),
      ),
    );
  }

  /// -------------------------
  /// INFO TILE (UNCHANGED)
  /// -------------------------
  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// -------------------------
  /// ACTION TILE (UNCHANGED)
  /// -------------------------
  Widget _actionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppTheme.accent),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

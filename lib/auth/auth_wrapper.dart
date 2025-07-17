import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../utils/enums.dart';
import 'login_screen.dart';
import '../screens/leader/leader_dashboard.dart';
import '../screens/pastor/pastor_dashboard.dart';
import '../screens/bishop/bishop_dashboard.dart';
import '../screens/treasurer/treasurer_dashboard.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading screen while checking authentication state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // User is not signed in
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        // User is signed in, get user data and navigate to appropriate dashboard
        return FutureBuilder<UserModel?>(
          future: authService.getCurrentUserData(),
          builder: (context, userSnapshot) {
            // Show loading while fetching user data
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading your dashboard...'),
                    ],
                  ),
                ),
              );
            }

            // Handle errors or missing user data
            if (userSnapshot.hasError ||
                !userSnapshot.hasData ||
                userSnapshot.data == null) {
              return const LoginScreen();
            }

            final UserModel user = userSnapshot.data!;

            // Check if user account is active
            if (user.status == Status.suspended) {
              return _buildStatusScreen(
                icon: Icons.block,
                title: 'Account Suspended',
                message:
                    'Your account has been suspended. Please contact an administrator.',
                color: Colors.red,
                showSignOut: true,
              );
            }

            if (user.status == Status.pending) {
              return _buildStatusScreen(
                icon: Icons.pending,
                title: 'Account Pending',
                message:
                    'Your account is pending approval. Please wait for an administrator to activate your account.',
                color: Colors.orange,
                showSignOut: true,
              );
            }

            if (user.status == Status.inactive) {
              return _buildStatusScreen(
                icon: Icons.pause_circle,
                title: 'Account Inactive',
                message:
                    'Your account is currently inactive. Please contact an administrator.',
                color: Colors.grey,
                showSignOut: true,
              );
            }

            // Navigate to role-based dashboard
            return _buildRoleDashboard(user);
          },
        );
      },
    );
  }

  Widget _buildStatusScreen({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
    bool showSignOut = false,
  }) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 80, color: color),
              const SizedBox(height: 24),
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              if (showSignOut) ...[
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () async {
                    await AuthService().signOut();
                  },
                  child: const Text('Sign Out'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleDashboard(UserModel user) {
    switch (user.role) {
      case UserRole.bishop:
        // Use the actual BishopDashboard instead of placeholder
        return BishopDashboard(user: user);
      case UserRole.pastor:
        // Use the actual PastorDashboard instead of placeholder
        return PastorDashboard(user: user);
      case UserRole.treasurer:
        return TreasurerDashboard(user: user);
      case UserRole.leader:
        // Use the actual LeaderDashboard instead of placeholder
        return LeaderDashboard(user: user);
    }
  }

  Widget _buildPlaceholderDashboard({
    required String role,
    required UserModel user,
    required Color color,
    required IconData icon,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$role Dashboard'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await AuthService().signOut();
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        const Icon(Icons.person),
                        const SizedBox(width: 8),
                        Text(user.fullName),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout),
                        SizedBox(width: 8),
                        Text('Sign Out'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 100, color: color),
              const SizedBox(height: 24),
              Text(
                'Welcome, ${user.firstName}!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'You are signed in as a $role',
                style: const TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Account Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('Name', user.fullName),
                      _buildInfoRow('Email', user.email),
                      _buildInfoRow('Role', user.role.displayName),
                      _buildInfoRow('Status', user.status.displayName),
                      if (user.phoneNumber != null)
                        _buildInfoRow('Phone', user.phoneNumber!),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '🚧 Dashboard under construction!\n\n'
                  'This is a placeholder dashboard. The actual role-specific dashboards and features will be implemented in upcoming tasks.',
                  style: TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

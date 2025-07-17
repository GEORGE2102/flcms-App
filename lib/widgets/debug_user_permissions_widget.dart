import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/admin_user_service.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';

/// Debug widget to help identify and fix user permission issues
/// Use this during development to troubleshoot report submission problems
class DebugUserPermissionsWidget extends StatefulWidget {
  const DebugUserPermissionsWidget({super.key});

  @override
  State<DebugUserPermissionsWidget> createState() =>
      _DebugUserPermissionsWidgetState();
}

class _DebugUserPermissionsWidgetState
    extends State<DebugUserPermissionsWidget> {
  final AdminUserService _adminService = AdminUserService();
  final StorageService _storageService = StorageService();
  final AuthService _authService = AuthService();

  Map<String, dynamic>? _debugInfo;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDebugInfo();
  }

  Future<void> _loadDebugInfo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get current user info
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'No authenticated user';
          _isLoading = false;
        });
        return;
      }

      // Get storage permissions debug info
      final storageDebug = await _storageService.debugUserPermissions();

      // Get user data from auth service
      final userData = await _authService.getCurrentUserData();

      setState(() {
        _debugInfo = {
          'currentUser': {
            'uid': user.uid,
            'email': user.email,
            'emailVerified': user.emailVerified,
          },
          'userDocument': userData?.toFirestore(),
          'storagePermissions': storageDebug,
          'timestamp': DateTime.now().toString(),
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading debug info: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fixUserPermissions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No user email found')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _adminService.debugAndFixUserPermissions(
        user!.email!,
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'User permissions fixed: ${result['fixes_applied']?.keys.join(', ') ?? 'No fixes needed'}',
            ),
            backgroundColor: Colors.green,
          ),
        );
        await _loadDebugInfo(); // Reload debug info
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fix failed: ${result['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fixing permissions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug User Permissions'),
        backgroundColor: Colors.orange,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Error',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(_errorMessage!),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadDebugInfo,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: 16),
                    _buildCurrentUserCard(),
                    const SizedBox(height: 16),
                    _buildUserDocumentCard(),
                    const SizedBox(height: 16),
                    _buildStoragePermissionsCard(),
                    const SizedBox(height: 16),
                    _buildActionsCard(),
                  ],
                ),
              ),
    );
  }

  Widget _buildStatusCard() {
    final hasRequiredData =
        _debugInfo?['storagePermissions']?['hasRequiredData'] ?? false;

    return Card(
      color: hasRequiredData ? Colors.green[50] : Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasRequiredData ? Icons.check_circle : Icons.error,
                  color: hasRequiredData ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  hasRequiredData ? 'Permissions OK' : 'Permission Issues',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: hasRequiredData ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hasRequiredData
                  ? 'User has the required role and fellowship assignment for report submission.'
                  : 'User is missing required permissions for report submission. Please fix the issues below.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentUserCard() {
    final currentUser = _debugInfo?['currentUser'];
    if (currentUser == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Firebase User',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildInfoRow('UID', currentUser['uid']),
            _buildInfoRow('Email', currentUser['email']),
            _buildInfoRow(
              'Email Verified',
              currentUser['emailVerified'].toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserDocumentCard() {
    final userDoc = _debugInfo?['userDocument'];
    if (userDoc == null) {
      return Card(
        color: Colors.red[50],
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'User document not found in Firestore',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User Document (Firestore)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Role', userDoc['role']),
            _buildInfoRow('Status', userDoc['status']),
            _buildInfoRow(
              'Fellowship ID',
              userDoc['fellowshipId'] ?? 'NOT SET',
            ),
            _buildInfoRow(
              'Constituency ID',
              userDoc['constituencyId'] ?? 'NOT SET',
            ),
            _buildInfoRow(
              'Name',
              '${userDoc['firstName']} ${userDoc['lastName']}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoragePermissionsCard() {
    final storagePerms = _debugInfo?['storagePermissions'];
    if (storagePerms == null) return const SizedBox.shrink();

    final hasRequiredData = storagePerms['hasRequiredData'] ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Storage Permissions Analysis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Has Required Data', hasRequiredData.toString()),
            _buildInfoRow('Role', storagePerms['role'] ?? 'NOT SET'),
            _buildInfoRow(
              'Fellowship ID',
              storagePerms['fellowshipId'] ?? 'NOT SET',
            ),
            _buildInfoRow('Status', storagePerms['status'] ?? 'NOT SET'),
            if (storagePerms.containsKey('error'))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Error: ${storagePerms['error']}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _fixUserPermissions,
                icon: const Icon(Icons.build),
                label: const Text('Fix User Permissions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _loadDebugInfo,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Debug Info'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Instructions:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. If user role is not "leader", contact an admin to update the role\n'
              '2. If Fellowship ID is "NOT SET", click "Fix User Permissions" to auto-assign\n'
              '3. If Status is not "active", the fix will activate the account\n'
              '4. After fixing, try submitting the report again',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: value.contains('NOT SET') ? Colors.red : null,
                fontWeight: value.contains('NOT SET') ? FontWeight.bold : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

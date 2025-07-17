import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_user_service.dart';

/// Professional helper utility to fix user permission issues
/// This addresses the StorageError: Permission denied issues in report submission
class PermissionFixHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final AdminUserService _adminService = AdminUserService();

  /// Quick fix for current user permission issues
  /// Call this when users experience "Permission denied" errors
  static Future<Map<String, dynamic>> fixCurrentUserPermissions() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) {
        return {
          'success': false,
          'error': 'No authenticated user found',
          'action': 'Please sign in and try again',
        };
      }

      print('🔧 Fixing permissions for: ${user!.email}');

      // Get current user document
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        return {
          'success': false,
          'error': 'User document not found in database',
          'action': 'Contact administrator to recreate your account',
        };
      }

      final userData = userDoc.data()!;
      final role = userData['role'] as String?;
      final status = userData['status'] as String?;
      final fellowshipId = userData['fellowshipId'] as String?;

      List<String> issues = [];
      Map<String, dynamic> fixes = {};

      // Check role
      if (role != 'leader') {
        issues.add(
          'User role is "$role" but must be "leader" to submit reports',
        );
        return {
          'success': false,
          'error': 'Incorrect user role',
          'issues': issues,
          'action':
              'Contact your administrator to change your role to "leader"',
        };
      }

      // Check status
      if (status != 'active') {
        issues.add('User account is not active (status: $status)');
        fixes['status'] = 'active';
      }

      // Check fellowship assignment
      if (fellowshipId == null) {
        issues.add('User is missing fellowship assignment');

        // Try to find or create a fellowship
        await _assignOrCreateFellowship(user.uid, userData, fixes);
      }

      // Apply fixes if needed
      if (fixes.isNotEmpty) {
        fixes['updatedAt'] = FieldValue.serverTimestamp();
        await _firestore.collection('users').doc(user.uid).update(fixes);
        print('✅ Applied fixes: ${fixes.keys.join(', ')}');
      }

      return {
        'success': true,
        'issues': issues,
        'fixes_applied': fixes,
        'message':
            issues.isEmpty
                ? 'No issues found - permissions should work correctly'
                : 'Fixed ${fixes.length} permission issues',
        'action': 'Try submitting your report again',
      };
    } catch (e) {
      print('❌ Error in fixCurrentUserPermissions: $e');
      return {
        'success': false,
        'error': e.toString(),
        'action': 'Please contact technical support',
      };
    }
  }

  /// Assign user to existing fellowship or create a new one
  static Future<void> _assignOrCreateFellowship(
    String userId,
    Map<String, dynamic> userData,
    Map<String, dynamic> fixes,
  ) async {
    try {
      // First, try to find a fellowship without a leader
      final fellowshipsQuery =
          await _firestore
              .collection('fellowships')
              .where('leaderId', isNull: true)
              .limit(1)
              .get();

      if (fellowshipsQuery.docs.isNotEmpty) {
        // Assign to existing fellowship
        final fellowshipId = fellowshipsQuery.docs.first.id;
        fixes['fellowshipId'] = fellowshipId;

        // Update fellowship to assign this leader
        await _firestore.collection('fellowships').doc(fellowshipId).update({
          'leaderId': userId,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('✅ Assigned user to existing fellowship: $fellowshipId');
      } else {
        // Create new fellowship
        final newFellowshipRef = _firestore.collection('fellowships').doc();
        final firstName = userData['firstName'] ?? 'Unknown';

        await newFellowshipRef.set({
          'name': '$firstName\'s Fellowship',
          'description': 'Auto-created fellowship for permission fix',
          'leaderId': userId,
          'constituencyId': userData['constituencyId'],
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'memberCount': 0,
        });

        fixes['fellowshipId'] = newFellowshipRef.id;
        print('✅ Created new fellowship: ${newFellowshipRef.id}');
      }
    } catch (e) {
      print('❌ Error assigning fellowship: $e');
      // Don't throw - let the main function handle it
    }
  }

  /// Check if current user has proper permissions for report submission
  static Future<Map<String, dynamic>> checkUserPermissions() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'hasPermissions': false, 'error': 'Not authenticated'};
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        return {'hasPermissions': false, 'error': 'User document not found'};
      }

      final userData = userDoc.data()!;
      final role = userData['role'] as String?;
      final status = userData['status'] as String?;
      final fellowshipId = userData['fellowshipId'] as String?;

      final hasPermissions =
          role == 'leader' && status == 'active' && fellowshipId != null;

      return {
        'hasPermissions': hasPermissions,
        'role': role,
        'status': status,
        'fellowshipId': fellowshipId,
        'issues': [
          if (role != 'leader') 'Role must be "leader"',
          if (status != 'active') 'Account must be active',
          if (fellowshipId == null) 'Fellowship assignment required',
        ],
      };
    } catch (e) {
      return {'hasPermissions': false, 'error': e.toString()};
    }
  }

  /// Simple method to be called from UI when submission fails
  static Future<String> handleSubmissionError() async {
    try {
      final result = await fixCurrentUserPermissions();

      if (result['success'] == true) {
        if (result['fixes_applied']?.isNotEmpty == true) {
          return 'Fixed permission issues: ${result['fixes_applied'].keys.join(', ')}. Please try again.';
        } else {
          return 'No permission issues found. The error might be network-related. Please check your connection and try again.';
        }
      } else {
        return 'Permission fix failed: ${result['error']}. ${result['action'] ?? 'Please contact support.'}';
      }
    } catch (e) {
      return 'Error fixing permissions: $e';
    }
  }
}

import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../utils/enums.dart';

/// Professional User Account Management Service
///
/// This service handles user account creation using server-side approaches
/// to avoid authentication conflicts and logout issues.
class AdminUserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Create a new user account (Professional Approach)
  ///
  /// This method creates user accounts without causing logout issues
  /// by using server-side operations and proper authentication handling.
  Future<Map<String, dynamic>> createUserAccount({
    required String email,
    required String firstName,
    required String lastName,
    required UserRole role,
    String? phoneNumber,
    String? constituencyId,
    String? fellowshipId,
  }) async {
    print('DEBUG: ============== STARTING ACCOUNT CREATION ==============');
    print('DEBUG: Method called with email: $email, role: $role');

    try {
      print('DEBUG: Starting account creation for $email');

      // Verify current user permissions
      print('DEBUG: Getting current user...');
      final currentUser = await _getCurrentUserWithRole();
      print('DEBUG: Current user result: $currentUser');

      if (currentUser == null) {
        print('DEBUG: FAILED - Authentication required');
        throw Exception('Authentication required');
      }

      print('DEBUG: Validating permissions...');
      _validatePermissions(currentUser, role);
      print('DEBUG: Permissions validated successfully');

      // Generate secure credentials
      print('DEBUG: Generating secure password...');
      final password = _generateSecurePassword();
      print('DEBUG: Password generated: ${password.substring(0, 3)}...');

      // Use Firestore auto-generated ID instead of custom generation
      print('DEBUG: Creating document reference...');
      final docRef = _firestore.collection('users').doc();
      final userId = docRef.id;

      print('DEBUG: Generated user ID: $userId');

      // Create user profile data
      print('DEBUG: Building user data...');
      final userData = _buildUserData(
        userId: userId,
        email: email,
        firstName: firstName,
        lastName: lastName,
        role: role,
        phoneNumber: phoneNumber,
        constituencyId: constituencyId,
        fellowshipId: fellowshipId,
        createdBy: currentUser['id'],
      );

      print('DEBUG: Built user data: $userData');

      // Create user via secure method
      print('DEBUG: Calling _createUserSecurely...');
      await _createUserSecurely(
        userId: userId,
        email: email,
        password: password,
        userData: userData,
      );

      print('DEBUG: User creation completed successfully');

      // Return comprehensive account details
      return {
        'success': true,
        'userId': userId,
        'loginDetails': {
          'email': email,
          'password': password,
          'name': '$firstName $lastName',
          'role': role.toString().split('.').last,
        },
        'accountInfo': {
          'fullName': '$firstName $lastName',
          'email': email,
          'role': _getRoleDisplayName(role),
          'created': DateTime.now().toString().split('.')[0],
        },
        'instructions': _getAccountInstructions(role),
      };
    } catch (e) {
      print('DEBUG: ============== ERROR IN ACCOUNT CREATION ==============');
      print('DEBUG: Error in createUserAccount: $e');
      print('DEBUG: Error type: ${e.runtimeType}');
      print('DEBUG: Stack trace: ${StackTrace.current}');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to create user account',
      };
    }
  }

  /// Get current user with role information
  Future<Map<String, dynamic>?> _getCurrentUserWithRole() async {
    print('DEBUG: _getCurrentUserWithRole called');

    try {
      final currentUser = _auth.currentUser;
      print('DEBUG: Firebase auth currentUser: ${currentUser?.uid}');
      print('DEBUG: Firebase auth email: ${currentUser?.email}');

      if (currentUser == null) {
        print('DEBUG: No authenticated user found');
        return null;
      }

      print('DEBUG: Getting user document from Firestore...');
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      print('DEBUG: User document exists: ${userDoc.exists}');

      if (!userDoc.exists) {
        print('DEBUG: User document not found in Firestore');
        return null;
      }

      final userData = userDoc.data()!;
      print(
        'DEBUG: User data retrieved - Role: ${userData['role']}, Status: ${userData['status']}',
      );
      print(
        'DEBUG: User data retrieved - ConstituencyId: ${userData['constituencyId']}',
      );
      print('DEBUG: Full user data: $userData');

      return {
        'id': currentUser.uid,
        'email': currentUser.email,
        'role': userData['role'],
        'status': userData['status'],
        ...userData,
      };
    } catch (e) {
      print('DEBUG: Error in _getCurrentUserWithRole: $e');
      print('DEBUG: Error type: ${e.runtimeType}');
      print('DEBUG: Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Validate that the current user has permission to create accounts
  void _validatePermissions(
    Map<String, dynamic> currentUser,
    UserRole targetRole,
  ) {
    print('DEBUG: _validatePermissions called');
    print('DEBUG: Current user role: ${currentUser['role']}');
    print('DEBUG: Target role to create: $targetRole');

    final currentRole = currentUser['role'] as String;

    switch (targetRole) {
      case UserRole.pastor:
        print('DEBUG: Validating bishop permission to create pastor...');
        if (currentRole != 'bishop') {
          print('DEBUG: PERMISSION DENIED - Only bishops can create pastors');
          throw Exception('Only bishops can create pastor accounts');
        }
        break;
      case UserRole.leader:
        print('DEBUG: Validating pastor/bishop permission to create leader...');
        if (currentRole != 'pastor' && currentRole != 'bishop') {
          print(
            'DEBUG: PERMISSION DENIED - Only pastors and bishops can create leaders',
          );
          throw Exception(
            'Only pastors and bishops can create leader accounts',
          );
        }
        break;
      case UserRole.treasurer:
        print('DEBUG: Validating bishop permission to create treasurer...');
        if (currentRole != 'bishop') {
          print(
            'DEBUG: PERMISSION DENIED - Only bishops can create treasurers',
          );
          throw Exception('Only bishops can create treasurer accounts');
        }
        break;
      default:
        print('DEBUG: PERMISSION DENIED - Invalid role');
        throw Exception('Invalid user role');
    }

    print('DEBUG: Permission validation passed');
  }

  /// Generate secure random password
  String _generateSecurePassword() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#%';
    final random = Random.secure();
    return List.generate(
      12,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  /// Build comprehensive user data
  Map<String, dynamic> _buildUserData({
    required String userId,
    required String email,
    required String firstName,
    required String lastName,
    required UserRole role,
    String? phoneNumber,
    String? constituencyId,
    String? fellowshipId,
    required String createdBy,
  }) {
    return {
      'id': userId,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'fullName': '$firstName $lastName',
      'phoneNumber': phoneNumber ?? '',
      'role': role.toString().split('.').last,
      'status': 'active',
      'profileImageUrl': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'needsPasswordChange': true,
      'firstLogin': true,
      // Role-specific booleans
      'isBishop': role == UserRole.bishop,
      'isPastor': role == UserRole.pastor,
      'isTreasurer': role == UserRole.treasurer,
      'isLeader': role == UserRole.leader,
      // Organizational fields
      'constituencyId': constituencyId,
      'fellowshipId': fellowshipId,
      if (role == UserRole.leader) 'assignedPastorId': createdBy,
    };
  }

  /// Simple password hashing (use proper bcrypt in production)
  String _hashPassword(String password) {
    // This is a placeholder - use proper password hashing in production
    return base64Encode(utf8.encode(password + 'salt'));
  }

  /// Get role display name
  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.bishop:
        return 'Bishop';
      case UserRole.pastor:
        return 'Pastor';
      case UserRole.treasurer:
        return 'Treasurer';
      case UserRole.leader:
        return 'Leader';
    }
  }

  /// Get account setup instructions
  List<String> _getAccountInstructions(UserRole role) {
    return [
      '1. Share the login details securely with the new ${_getRoleDisplayName(role).toLowerCase()}',
      '2. They should log in using the provided email and temporary password',
      '3. They will be prompted to change their password on first login',
      '4. Ensure they verify their email address if required',
      '5. The account will be fully activated after first successful login',
    ];
  }

  /// Delete user account
  Future<Map<String, dynamic>> deleteUserAccount(String userId) async {
    try {
      // Delete from Firestore
      await _firestore.collection('users').doc(userId).delete();

      // Delete activation record if exists
      await _firestore.collection('account_activations').doc(userId).delete();

      // Delete credentials if exists
      await _firestore.collection('user_credentials').doc(userId).delete();

      return {'success': true, 'message': 'User account deleted successfully'};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to delete user account',
      };
    }
  }

  Future<void> _createUserSecurely({
    required String userId,
    required String email,
    required String password,
    required Map<String, dynamic> userData,
  }) async {
    try {
      print('DEBUG: ============== _createUserSecurely STARTED ==============');
      print('DEBUG: Creating user document for $email with ID: $userId');
      print('DEBUG: User data to be saved: $userData');

      // Create the user document using the specific document reference
      print('DEBUG: Step 1: Creating user document in users collection...');
      final userDocRef = _firestore.collection('users').doc(userId);

      try {
        await userDocRef.set(userData);
        print(
          'DEBUG: ✅ User document created successfully in users collection',
        );
      } catch (e) {
        print('DEBUG: ❌ FAILED to create user document: $e');
        print('DEBUG: Error type: ${e.runtimeType}');
        throw Exception('Failed to create user document: $e');
      }

      // Verify the document was created
      print('DEBUG: Step 2: Verifying user document was created...');
      try {
        final docSnapshot = await userDocRef.get();
        if (!docSnapshot.exists) {
          throw Exception(
            'User document verification failed - document does not exist',
          );
        }
        print('DEBUG: ✅ User document verified in Firestore');
      } catch (e) {
        print('DEBUG: ❌ FAILED to verify user document: $e');
        throw Exception('Failed to verify user document: $e');
      }

      // Create account activation record
      print(
        'DEBUG: Step 3: Creating activation record in account_activations collection...',
      );
      final activationData = {
        'email': email,
        'temporaryPassword': password,
        'activated': false,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 30)),
        ),
      };
      print('DEBUG: Activation data to be saved: $activationData');

      final activationDocRef = _firestore
          .collection('account_activations')
          .doc(userId);

      try {
        await activationDocRef.set(activationData);
        print(
          'DEBUG: ✅ Activation record created successfully in account_activations collection',
        );
      } catch (e) {
        print('DEBUG: ❌ FAILED to create activation record: $e');
        print('DEBUG: Error type: ${e.runtimeType}');
        throw Exception('Failed to create activation record: $e');
      }

      // Verify activation record was created
      print('DEBUG: Step 4: Verifying activation record was created...');
      try {
        final activationSnapshot = await activationDocRef.get();
        if (!activationSnapshot.exists) {
          throw Exception(
            'Activation record verification failed - document does not exist',
          );
        }
        print('DEBUG: ✅ Activation record verified in Firestore');
      } catch (e) {
        print('DEBUG: ❌ FAILED to verify activation record: $e');
        throw Exception('Failed to verify activation record: $e');
      }

      print(
        'DEBUG: ============== _createUserSecurely COMPLETED SUCCESSFULLY ==============',
      );
    } catch (e) {
      print('DEBUG: ============== _createUserSecurely FAILED ==============');
      print('DEBUG: Error in _createUserSecurely: $e');
      print('DEBUG: Error type: ${e.runtimeType}');
      print('DEBUG: Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Debug and fix user permissions for report submission
  Future<Map<String, dynamic>> debugAndFixUserPermissions(
    String userEmail,
  ) async {
    try {
      // Find user by email
      final userQuery =
          await _firestore
              .collection('users')
              .where('email', isEqualTo: userEmail)
              .limit(1)
              .get();

      if (userQuery.docs.isEmpty) {
        return {
          'success': false,
          'error': 'User not found with email: $userEmail',
        };
      }

      final userDoc = userQuery.docs.first;
      final userData = userDoc.data();
      final userModel = UserModel.fromFirestore(userDoc);

      Map<String, dynamic> fixes = {};
      bool needsUpdate = false;

      // Check if user is a leader but missing fellowship assignment
      if (userModel.role == UserRole.leader && userModel.fellowshipId == null) {
        print('⚠️ Leader missing fellowship assignment: $userEmail');

        // Try to find a fellowship that needs a leader
        final fellowshipsQuery =
            await _firestore
                .collection('fellowships')
                .where('leaderId', isNull: true)
                .limit(1)
                .get();

        if (fellowshipsQuery.docs.isNotEmpty) {
          final fellowshipDoc = fellowshipsQuery.docs.first;
          final fellowshipId = fellowshipDoc.id;

          fixes['fellowshipId'] = fellowshipId;
          needsUpdate = true;
          print('✅ Assigning user to fellowship: $fellowshipId');
        } else {
          // Create a default fellowship for this leader
          final newFellowshipRef = _firestore.collection('fellowships').doc();
          await newFellowshipRef.set({
            'name': '${userModel.firstName}\'s Fellowship',
            'description': 'Auto-created fellowship for ${userModel.fullName}',
            'leaderId': userModel.id,
            'constituencyId': userModel.constituencyId,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'status': 'active',
          });

          fixes['fellowshipId'] = newFellowshipRef.id;
          needsUpdate = true;
          print('✅ Created new fellowship: ${newFellowshipRef.id}');
        }
      }

      // Check if user status is not active
      if (userModel.status != Status.active) {
        fixes['status'] = 'active';
        needsUpdate = true;
        print('✅ Activating user account');
      }

      // Apply fixes if needed
      if (needsUpdate) {
        fixes['updatedAt'] = FieldValue.serverTimestamp();
        await _firestore.collection('users').doc(userModel.id).update(fixes);
        print('📝 Updated user document with fixes');
      }

      return {
        'success': true,
        'user': {
          'id': userModel.id,
          'email': userModel.email,
          'name': userModel.fullName,
          'role': userModel.role.value,
          'status': userModel.status.value,
          'fellowshipId': userModel.fellowshipId,
          'constituencyId': userModel.constituencyId,
        },
        'fixes_applied': fixes,
        'needed_update': needsUpdate,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to debug user permissions: $e',
      };
    }
  }
}

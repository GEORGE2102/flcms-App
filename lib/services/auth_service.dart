import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../utils/enums.dart';
import 'invitation_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final InvitationService _invitationService = InvitationService();

  // Current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current Firebase user
  User? get currentFirebaseUser => _auth.currentUser;

  // Current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Get current user data with role information
  Future<UserModel?> getCurrentUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;

      return UserModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get current user data: $e');
    }
  }

  /// Register new user with role assignment and optional invitation token
  Future<UserModel> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required UserRole role,
    String? phoneNumber,
    String? constituencyId,
    String? fellowshipId,
    String? assignedPastorId,
    String? invitationToken,
  }) async {
    try {
      // Validate invitation token if provided (especially for pastors)
      Map<String, dynamic>? invitationData;
      if (invitationToken != null) {
        invitationData = await _invitationService.validateInvitationToken(
          invitationToken,
        );
        if (invitationData == null) {
          throw Exception(
            'Invalid or expired invitation code. Please check your code or request a new invitation.',
          );
        }

        // Verify email matches invitation
        final invitationEmail = invitationData['data']['email'] as String;
        if (invitationEmail.toLowerCase() != email.toLowerCase()) {
          throw Exception(
            'Email does not match the invitation. Please use the email address that received the invitation.',
          );
        }

        // Verify role matches invitation
        final invitationRole = UserRole.fromString(
          invitationData['data']['role'] as String,
        );
        if (invitationRole != role) {
          throw Exception(
            'Role does not match the invitation. Expected: ${invitationRole.displayName}',
          );
        }
      }

      // Check if user profile already exists in Firestore (created by admin)
      final existingUserQuery =
          await _firestore
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

      if (existingUserQuery.docs.isNotEmpty) {
        // User profile exists (likely created by Bishop)
        final existingUserDoc = existingUserQuery.docs.first;
        final existingUser = UserModel.fromFirestore(existingUserDoc);

        // Create Firebase Auth account for existing profile
        final UserCredential result = await _auth
            .createUserWithEmailAndPassword(email: email, password: password);

        final User? user = result.user;
        if (user == null) {
          throw Exception('Failed to create authentication account');
        }

        // Update display name
        await user.updateDisplayName('$firstName $lastName');

        // Activate the existing profile and update any missing fields
        final updateData = <String, dynamic>{
          'status': Status.active.value,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        };

        // Update name fields if they're different (user might want to use different name)
        if (firstName != existingUser.firstName) {
          updateData['firstName'] = firstName;
        }
        if (lastName != existingUser.lastName) {
          updateData['lastName'] = lastName;
        }
        if (phoneNumber != null && phoneNumber != existingUser.phoneNumber) {
          updateData['phoneNumber'] = phoneNumber;
        }

        // Update the Firestore document with the Firebase Auth UID
        await _firestore.collection('users').doc(user.uid).set({
          ...existingUser.toFirestore(),
          'id': user.uid, // Update ID to match Firebase Auth UID
          ...updateData,
        });

        // Delete the old document if the ID changed
        if (existingUser.id != user.uid) {
          await _firestore.collection('users').doc(existingUser.id).delete();
        }

        // Mark invitation as accepted if token was provided
        if (invitationData != null) {
          await _invitationService.acceptInvitation(
            invitationData['invitationId'],
          );

          // Send welcome email
          await _invitationService.sendWelcomeEmail(
            email: email,
            firstName: firstName,
            lastName: lastName,
            role: role,
          );
        }

        // Return updated user data
        final updatedUser = existingUser.copyWith(
          id: user.uid,
          firstName: updateData['firstName'] ?? existingUser.firstName,
          lastName: updateData['lastName'] ?? existingUser.lastName,
          phoneNumber: updateData['phoneNumber'] ?? existingUser.phoneNumber,
          status: Status.active,
          updatedAt: DateTime.now(),
        );

        return updatedUser;
      }

      // No existing profile - create new user normally
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user == null) {
        throw Exception('Failed to create user account');
      }

      // Update display name
      await user.updateDisplayName('$firstName $lastName');

      // Create user document with appropriate status
      Status status = Status.pending;

      // Auto-activate first Bishop account or if this is a self-registration by existing pastor
      if (role == UserRole.bishop) {
        final bishopsQuery =
            await _firestore
                .collection('users')
                .where('role', isEqualTo: UserRole.bishop.value)
                .limit(1)
                .get();

        if (bishopsQuery.docs.isEmpty) {
          status = Status.active; // First bishop is auto-activated
        }
      }

      final userData = UserModel(
        id: user.uid,
        email: email,
        firstName: firstName,
        lastName: lastName,
        role: role,
        phoneNumber: phoneNumber,
        constituencyId: constituencyId,
        fellowshipId: fellowshipId,
        assignedPastorId: assignedPastorId,
        status: status,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save user data to Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(userData.toFirestore());

      // Mark invitation as accepted if token was provided
      if (invitationData != null) {
        await _invitationService.acceptInvitation(
          invitationData['invitationId'],
        );

        // Send welcome email
        await _invitationService.sendWelcomeEmail(
          email: email,
          firstName: firstName,
          lastName: lastName,
          role: role,
        );
      }

      return userData;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    print('DEBUG: AUTH - signInWithEmailAndPassword called with email: $email');

    try {
      print('DEBUG: AUTH - Attempting Firebase Auth login...');
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('DEBUG: AUTH - Firebase Auth login successful');
      final User? user = result.user;
      if (user == null) {
        print('DEBUG: AUTH - Firebase Auth returned null user');
        throw Exception('Failed to sign in');
      }

      print('DEBUG: AUTH - Getting user data from Firestore...');
      // Get user data from Firestore
      final userModel = await getCurrentUserData();
      if (userModel == null) {
        print('DEBUG: AUTH - User data not found in Firestore');
        throw Exception('User data not found');
      }

      print('DEBUG: AUTH - User status: ${userModel.status}');
      // Check if user account is active
      if (userModel.status == Status.suspended) {
        print('DEBUG: AUTH - User account is suspended');
        await signOut();
        throw Exception(
          'Your account has been suspended. Please contact an administrator.',
        );
      }

      if (userModel.status == Status.pending) {
        print('DEBUG: AUTH - User account is pending');
        await signOut();
        throw Exception(
          'Your account is pending approval. Please wait for an administrator to activate your account.',
        );
      }

      print('DEBUG: AUTH - Login successful, returning user model');
      return userModel;
    } on FirebaseAuthException catch (e) {
      print(
        'DEBUG: AUTH - FirebaseAuthException caught: ${e.code}, ${e.message}',
      );
      // Handle the case where user doesn't exist in Firebase Auth but might have an activation record
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        print(
          'DEBUG: AUTH - User not found or invalid credential, trying activation login...',
        );
        return await _handleActivationLogin(email, password);
      }
      throw Exception(_getAuthErrorMessage(e.code));
    } catch (e) {
      print('DEBUG: AUTH - General exception caught: $e');
      throw Exception('Sign in failed: $e');
    }
  }

  /// Handle login for users created by admin (activation records)
  Future<UserModel> _handleActivationLogin(
    String email,
    String password,
  ) async {
    print('DEBUG: ACTIVATION - _handleActivationLogin called');
    print(
      'DEBUG: ACTIVATION - Email: $email, Password: ${password.substring(0, 3)}...',
    );

    try {
      print('DEBUG: ACTIVATION - Checking for activation record...');
      // Check for activation record
      final activationQuery =
          await _firestore
              .collection('account_activations')
              .where('email', isEqualTo: email)
              .where('temporaryPassword', isEqualTo: password)
              .limit(1)
              .get();

      print('DEBUG: ACTIVATION - Query details:');
      print('DEBUG: ACTIVATION - Searching for email: "$email"');
      print('DEBUG: ACTIVATION - Searching for password: "$password"');
      print(
        'DEBUG: ACTIVATION - Found ${activationQuery.docs.length} activation records',
      );

      // Debug: Let's also check all activation records to see what's available
      final allActivationsQuery =
          await _firestore.collection('account_activations').get();
      print(
        'DEBUG: ACTIVATION - Total activation records in collection: ${allActivationsQuery.docs.length}',
      );
      for (var doc in allActivationsQuery.docs) {
        final data = doc.data();
        print(
          'DEBUG: ACTIVATION - Available record: email="${data['email']}", password="${data['temporaryPassword']}", activated=${data['activated']}',
        );
      }

      if (activationQuery.docs.isEmpty) {
        print('DEBUG: ACTIVATION - No activation record found');
        throw Exception('Invalid email or password');
      }

      final activationDoc = activationQuery.docs.first;
      final activationData = activationDoc.data();
      print(
        'DEBUG: ACTIVATION - Activation record found: ${activationData['email']}',
      );

      // Check if activation record is expired
      final expiresAt = (activationData['expiresAt'] as Timestamp).toDate();
      print(
        'DEBUG: ACTIVATION - Expires at: $expiresAt, Current time: ${DateTime.now()}',
      );
      if (DateTime.now().isAfter(expiresAt)) {
        print('DEBUG: ACTIVATION - Activation record is expired');
        throw Exception(
          'Account activation has expired. Please contact an administrator.',
        );
      }

      print('DEBUG: ACTIVATION - Looking for user document...');
      // Find the user document
      final userQuery =
          await _firestore
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

      print(
        'DEBUG: ACTIVATION - Found ${userQuery.docs.length} user documents',
      );
      if (userQuery.docs.isEmpty) {
        print('DEBUG: ACTIVATION - User account not found in Firestore');
        throw Exception('User account not found');
      }

      final userDoc = userQuery.docs.first;
      final userData = userDoc.data();
      print(
        'DEBUG: ACTIVATION - User document found: ${userData['firstName']} ${userData['lastName']}',
      );

      print('DEBUG: ACTIVATION - Creating Firebase Auth account...');
      // Create Firebase Auth account
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user == null) {
        print('DEBUG: ACTIVATION - Failed to create Firebase Auth account');
        throw Exception('Failed to create authentication account');
      }

      print(
        'DEBUG: ACTIVATION - Firebase Auth account created with UID: ${user.uid}',
      );

      // Update display name
      final displayName = '${userData['firstName']} ${userData['lastName']}';
      print('DEBUG: ACTIVATION - Updating display name to: $displayName');
      await user.updateDisplayName(displayName);

      print('DEBUG: ACTIVATION - Updating user document in Firestore...');
      // Update user document with Firebase Auth UID and activate
      await _firestore.collection('users').doc(user.uid).set({
        ...userData,
        'id': user.uid,
        'status': 'active',
        'firstLogin': true,
        'needsPasswordChange': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('DEBUG: ACTIVATION - Marking activation as completed...');
      // Mark activation as completed
      await _firestore
          .collection('account_activations')
          .doc(activationDoc.id)
          .update({
            'activated': true,
            'activatedAt': FieldValue.serverTimestamp(),
          });

      // Delete old user document if ID changed
      if (userDoc.id != user.uid) {
        print('DEBUG: ACTIVATION - Deleting old user document: ${userDoc.id}');
        await _firestore.collection('users').doc(userDoc.id).delete();
      }

      print('DEBUG: ACTIVATION - Getting updated user document...');
      // Return the user model
      final updatedUserDoc =
          await _firestore.collection('users').doc(user.uid).get();
      final userModel = UserModel.fromFirestore(updatedUserDoc);

      print(
        'DEBUG: ACTIVATION - Activation completed successfully for: ${userModel.fullName}',
      );
      return userModel;
    } catch (e) {
      print('DEBUG: ACTIVATION - Error in _handleActivationLogin: $e');
      throw Exception('Account activation failed: $e');
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.code));
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  /// Send invitation email to new pastors
  /// This attempts to send a password reset email as an invitation
  Future<void> sendInvitationEmail(String email) async {
    try {
      // Try to send password reset email
      // This will only work if the email already has a Firebase Auth account
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        // Email doesn't have Firebase Auth account yet
        // This is expected for new pastor invitations
        // The pastor will need to register first, then their account will be activated
        throw Exception(
          'Pastor needs to register first using this email: $email',
        );
      } else {
        throw Exception(_getAuthErrorMessage(e.code));
      }
    } catch (e) {
      throw Exception('Invitation email failed: $e');
    }
  }

  /// Update user profile
  Future<UserModel> updateUserProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? profileImageUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user signed in');

    try {
      final currentUserData = await getCurrentUserData();
      if (currentUserData == null) throw Exception('User data not found');

      // Update display name in Firebase Auth if name changed
      if (firstName != null || lastName != null) {
        final newDisplayName =
            '${firstName ?? currentUserData.firstName} ${lastName ?? currentUserData.lastName}';
        await user.updateDisplayName(newDisplayName);
      }

      // Update user document in Firestore
      final updatedUser = currentUserData.copyWith(
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        profileImageUrl: profileImageUrl,
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(user.uid)
          .update(updatedUser.toFirestore());

      return updatedUser;
    } catch (e) {
      throw Exception('Profile update failed: $e');
    }
  }

  /// Check if current user has specific role
  Future<bool> hasRole(UserRole role) async {
    final userData = await getCurrentUserData();
    return userData?.role == role;
  }

  /// Check if current user can manage another user
  Future<bool> canManageUser(String targetUserId) async {
    final currentUser = await getCurrentUserData();
    if (currentUser == null) return false;

    try {
      final targetUserDoc =
          await _firestore.collection('users').doc(targetUserId).get();
      if (!targetUserDoc.exists) return false;

      final targetUser = UserModel.fromFirestore(targetUserDoc);
      return currentUser.canManage(targetUser);
    } catch (e) {
      return false;
    }
  }

  /// Get users that current user can manage
  Stream<List<UserModel>> getManagedUsers() {
    return getCurrentUserData().asStream().asyncExpand((currentUser) {
      if (currentUser == null) return Stream.value([]);

      Query query = _firestore.collection('users');

      switch (currentUser.role) {
        case UserRole.bishop:
          // Bishop can see all users
          break;
        case UserRole.pastor:
          // Pastor can see leaders assigned to them
          query = query.where('assignedPastorId', isEqualTo: currentUser.id);
          break;
        case UserRole.treasurer:
          // Treasurers can't manage other users
          return Stream.value([]);
        case UserRole.leader:
          // Leaders can't manage other users
          return Stream.value([]);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .where((user) => currentUser.canManage(user))
            .toList();
      });
    });
  }

  /// Activate/deactivate user (admin function)
  Future<void> updateUserStatus(String userId, Status newStatus) async {
    final currentUser = await getCurrentUserData();
    if (currentUser == null || !currentUser.isBishop) {
      throw Exception('Insufficient permissions');
    }

    try {
      await _firestore.collection('users').doc(userId).update({
        'status': newStatus.value,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to update user status: $e');
    }
  }

  /// Create initial admin/bishop account (only for first-time setup)
  /// This bypasses the normal pending approval process
  Future<UserModel> createInitialAdminAccount({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phoneNumber,
  }) async {
    try {
      // Check if any Bishop accounts already exist
      final bishopsQuery =
          await _firestore
              .collection('users')
              .where('role', isEqualTo: UserRole.bishop.value)
              .limit(1)
              .get();

      if (bishopsQuery.docs.isNotEmpty) {
        throw Exception(
          'Admin account already exists. Use normal registration process.',
        );
      }

      // Create Firebase Auth user
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user == null) {
        throw Exception('Failed to create admin account');
      }

      // Update display name
      await user.updateDisplayName('$firstName $lastName');

      // Create user document in Firestore with ACTIVE status (bypass pending)
      final now = DateTime.now();
      final userModel = UserModel(
        id: user.uid,
        email: email,
        firstName: firstName,
        lastName: lastName,
        role: UserRole.bishop, // Set as Bishop
        status: Status.active, // Set as ACTIVE (not pending)
        phoneNumber: phoneNumber,
        createdAt: now,
        updatedAt: now,
        constituencyId: null, // Bishops don't belong to a constituency
        fellowshipId: null, // Bishops don't belong to a fellowship
        assignedPastorId: null, // Bishops don't have assigned pastors
      );

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(userModel.toFirestore());

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.code));
    } catch (e) {
      throw Exception('Admin account creation failed: $e');
    }
  }

  /// Convert Firebase Auth error codes to user-friendly messages
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'user-not-found':
        return 'No user found for this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'operation-not-allowed':
        return 'Signing in with Email and Password is not enabled.';
      default:
        return 'An authentication error occurred.';
    }
  }
}

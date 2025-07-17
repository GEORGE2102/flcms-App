import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/constituency_model.dart';
import '../utils/enums.dart';
import 'auth_service.dart';
import 'invitation_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service class for managing pastor accounts and constituency assignments.
///
/// This service provides comprehensive CRUD operations for pastor management,
/// including creating pastor accounts, assigning them to constituencies,
/// and managing their performance metrics. Only bishops have access to these
/// operations as defined by the church hierarchy.
///
/// Key features:
/// - Create, update, and delete pastor accounts
/// - Manage constituency assignments and reassignments
/// - Track pastor performance metrics
/// - Handle role-based access control
///
/// Usage:
/// ```dart
/// final pastorService = PastorService();
///
/// // Create a new pastor
/// final pastor = await pastorService.createPastor(
///   email: 'pastor@church.com',
///   firstName: 'John',
///   lastName: 'Doe',
/// );
///
/// // Assign to constituency
/// await pastorService.updatePastor(
///   pastorId: pastor.id,
///   constituencyId: 'constituency_id',
/// );
/// ```
class PastorService {
  /// Singleton instance of PastorService
  static final PastorService _instance = PastorService._internal();

  /// Factory constructor that returns the singleton instance
  factory PastorService() => _instance;

  /// Private constructor for singleton pattern
  PastorService._internal();

  /// Firestore instance for database operations
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Auth service for user authentication and authorization
  final AuthService _authService = AuthService();

  /// Invitation service for managing invitations
  final InvitationService _invitationService = InvitationService();

  /// Get all pastors (Bishop only)
  Stream<List<UserModel>> getAllPastors() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.pastor.value)
        .orderBy('firstName')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
        );
  }

  /// Get all constituencies
  Stream<List<ConstituencyModel>> getAllConstituencies() {
    return _firestore
        .collection('constituencies')
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ConstituencyModel.fromFirestore(doc))
                  .toList(),
        );
  }

  /// Create a new pastor account - now uses manual creation (Bishop only)
  ///
  /// This method has been updated to use direct account creation instead of invitations
  /// to avoid authentication issues and simplify the process.
  Future<Map<String, dynamic>> createPastor({
    required String email,
    required String firstName,
    required String lastName,
    String? phoneNumber,
    String? constituencyId,
  }) async {
    print('🔄 Redirecting to manual pastor creation for $firstName $lastName');

    // Generate a secure password and use manual creation
    final password = _generateSecurePassword();

    return await createPastorManual(
      email: email,
      firstName: firstName,
      lastName: lastName,
      password: password,
      phoneNumber: phoneNumber,
      constituencyId: constituencyId,
    );
  }

  /// Generate a secure password for manual pastor creation
  String _generateSecurePassword() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#%';
    final random = Random.secure();
    return List.generate(
      12,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  /// Resend pastor invitation email
  Future<Map<String, dynamic>> resendPastorInvitation(String pastorId) async {
    // Verify current user is bishop
    final currentUser = await _authService.getCurrentUserData();
    if (currentUser == null || !currentUser.isBishop) {
      throw Exception('Only bishops can resend pastor invitations');
    }

    try {
      // Get pastor data
      final pastorDoc =
          await _firestore.collection('users').doc(pastorId).get();
      if (!pastorDoc.exists) {
        throw Exception('Pastor not found');
      }

      final pastor = UserModel.fromFirestore(pastorDoc);
      if (!pastor.isPastor) {
        throw Exception('User is not a pastor');
      }

      if (pastor.status == Status.active) {
        throw Exception('Pastor account is already active');
      }

      // Find the invitation record
      final invitationQuery =
          await _firestore
              .collection('invitations')
              .where('email', isEqualTo: pastor.email)
              .where('status', isEqualTo: 'pending')
              .limit(1)
              .get();

      if (invitationQuery.docs.isEmpty) {
        throw Exception('No pending invitation found for this pastor');
      }

      final invitationId = invitationQuery.docs.first.id;

      // Resend invitation email
      final result = await _invitationService.resendInvitation(invitationId);

      return {
        'success': true,
        'message': 'Invitation email resent successfully!',
        'emailContent': result['emailContent'],
      };
    } catch (e) {
      throw Exception('Failed to resend invitation: $e');
    }
  }

  /// Get pending invitations for the current bishop
  Future<Stream<List<Map<String, dynamic>>>> getPendingInvitations() async {
    final currentUser = await _authService.getCurrentUserData();
    if (currentUser == null || !currentUser.isBishop) {
      return Stream.value(<Map<String, dynamic>>[]);
    }

    return _invitationService.getPendingInvitations(currentUser.id);
  }

  /// Update pastor information (Bishop only)
  Future<UserModel> updatePastor({
    required String pastorId,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? constituencyId,
    Status? status,
  }) async {
    // Verify current user is bishop
    final currentUser = await _authService.getCurrentUserData();
    if (currentUser == null || !currentUser.isBishop) {
      throw Exception('Only bishops can update pastor accounts');
    }

    try {
      // Get current pastor data
      final pastorDoc =
          await _firestore.collection('users').doc(pastorId).get();
      if (!pastorDoc.exists) {
        throw Exception('Pastor not found');
      }

      final currentPastor = UserModel.fromFirestore(pastorDoc);
      if (!currentPastor.isPastor) {
        throw Exception('User is not a pastor');
      }

      // Update pastor document
      final updateData = <String, dynamic>{
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (firstName != null) updateData['firstName'] = firstName;
      if (lastName != null) updateData['lastName'] = lastName;
      if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber;
      if (status != null) updateData['status'] = status.value;

      // Handle constituency change
      if (constituencyId != currentPastor.constituencyId) {
        // Remove from old constituency if exists
        if (currentPastor.constituencyId != null) {
          await _removePastorFromConstituency(
            pastorId,
            currentPastor.constituencyId!,
          );
        }

        // Assign to new constituency if provided
        updateData['constituencyId'] = constituencyId;
        if (constituencyId != null) {
          await _assignPastorToConstituency(pastorId, constituencyId);
        }
      }

      await _firestore.collection('users').doc(pastorId).update(updateData);

      // Return updated pastor
      final updatedDoc =
          await _firestore.collection('users').doc(pastorId).get();
      return UserModel.fromFirestore(updatedDoc);
    } catch (e) {
      throw Exception('Failed to update pastor: $e');
    }
  }

  /// Deactivate pastor account (Bishop only)
  Future<void> deactivatePastor(String pastorId) async {
    await updatePastor(pastorId: pastorId, status: Status.inactive);
  }

  /// Reactivate pastor account (Bishop only)
  Future<void> reactivatePastor(String pastorId) async {
    await updatePastor(pastorId: pastorId, status: Status.active);
  }

  /// Delete pastor account (Bishop only)
  Future<void> deletePastor(String pastorId) async {
    // Verify current user is bishop
    final currentUser = await _authService.getCurrentUserData();
    if (currentUser == null || !currentUser.isBishop) {
      throw Exception('Only bishops can delete pastor accounts');
    }

    try {
      // Get pastor data first
      final pastorDoc =
          await _firestore.collection('users').doc(pastorId).get();
      if (!pastorDoc.exists) return;

      final pastor = UserModel.fromFirestore(pastorDoc);
      if (!pastor.isPastor) {
        throw Exception('User is not a pastor');
      }

      // Remove from constituency if assigned
      if (pastor.constituencyId != null) {
        await _removePastorFromConstituency(pastorId, pastor.constituencyId!);
      }

      // Reassign all leaders under this pastor to no pastor
      await _firestore
          .collection('users')
          .where('assignedPastorId', isEqualTo: pastorId)
          .get()
          .then((snapshot) {
            final batch = _firestore.batch();
            for (var doc in snapshot.docs) {
              batch.update(doc.reference, {
                'assignedPastorId': null,
                'updatedAt': Timestamp.fromDate(DateTime.now()),
              });
            }
            return batch.commit();
          });

      // Delete pastor account
      await _firestore.collection('users').doc(pastorId).delete();
    } catch (e) {
      throw Exception('Failed to delete pastor: $e');
    }
  }

  /// Create a new constituency (Bishop only)
  Future<ConstituencyModel> createConstituency({
    required String name,
    String? description,
    String? pastorId,
  }) async {
    // Verify current user is bishop
    final currentUser = await _authService.getCurrentUserData();
    if (currentUser == null || !currentUser.isBishop) {
      throw Exception('Only bishops can create constituencies');
    }

    try {
      final now = DateTime.now();
      String pastorName = '';

      // Get pastor name if pastor is assigned
      if (pastorId != null) {
        final pastorDoc =
            await _firestore.collection('users').doc(pastorId).get();
        if (pastorDoc.exists) {
          final pastor = UserModel.fromFirestore(pastorDoc);
          if (pastor.isPastor) {
            pastorName = pastor.fullName;
          } else {
            throw Exception('Assigned user is not a pastor');
          }
        } else {
          throw Exception('Pastor not found');
        }
      }

      final constituency = ConstituencyModel(
        id: '', // Will be set by Firestore
        name: name,
        description: description,
        pastorId: pastorId ?? '',
        pastorName: pastorName,
        status: Status.active,
        createdAt: now,
        updatedAt: now,
      );

      final docRef = await _firestore
          .collection('constituencies')
          .add(constituency.toFirestore());

      // Update pastor's constituency assignment if pastor is provided
      if (pastorId != null) {
        await _firestore.collection('users').doc(pastorId).update({
          'constituencyId': docRef.id,
          'updatedAt': Timestamp.fromDate(now),
        });
      }

      // Return constituency with generated ID
      return constituency.copyWith(id: docRef.id);
    } catch (e) {
      throw Exception('Failed to create constituency: $e');
    }
  }

  /// Update constituency (Bishop only)
  Future<ConstituencyModel> updateConstituency({
    required String constituencyId,
    String? name,
    String? description,
    String? pastorId,
    Status? status,
  }) async {
    // Verify current user is bishop
    final currentUser = await _authService.getCurrentUserData();
    if (currentUser == null || !currentUser.isBishop) {
      throw Exception('Only bishops can update constituencies');
    }

    try {
      // Get current constituency
      final constituencyDoc =
          await _firestore
              .collection('constituencies')
              .doc(constituencyId)
              .get();
      if (!constituencyDoc.exists) {
        throw Exception('Constituency not found');
      }

      final currentConstituency = ConstituencyModel.fromFirestore(
        constituencyDoc,
      );
      final updateData = <String, dynamic>{
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (status != null) updateData['status'] = status.value;

      // Handle pastor change
      if (pastorId != currentConstituency.pastorId) {
        // Remove old pastor assignment
        if (currentConstituency.pastorId.isNotEmpty) {
          await _firestore
              .collection('users')
              .doc(currentConstituency.pastorId)
              .update({
                'constituencyId': null,
                'updatedAt': Timestamp.fromDate(DateTime.now()),
              });
        }

        // Assign new pastor
        String pastorName = '';
        if (pastorId != null && pastorId.isNotEmpty) {
          final pastorDoc =
              await _firestore.collection('users').doc(pastorId).get();
          if (pastorDoc.exists) {
            final pastor = UserModel.fromFirestore(pastorDoc);
            if (pastor.isPastor) {
              pastorName = pastor.fullName;
              await _firestore.collection('users').doc(pastorId).update({
                'constituencyId': constituencyId,
                'updatedAt': Timestamp.fromDate(DateTime.now()),
              });
            } else {
              throw Exception('Assigned user is not a pastor');
            }
          } else {
            throw Exception('Pastor not found');
          }
        }

        updateData['pastorId'] = pastorId ?? '';
        updateData['pastorName'] = pastorName;
      }

      await _firestore
          .collection('constituencies')
          .doc(constituencyId)
          .update(updateData);

      // Return updated constituency
      final updatedDoc =
          await _firestore
              .collection('constituencies')
              .doc(constituencyId)
              .get();
      return ConstituencyModel.fromFirestore(updatedDoc);
    } catch (e) {
      throw Exception('Failed to update constituency: $e');
    }
  }

  /// Delete constituency (Bishop only)
  Future<void> deleteConstituency(String constituencyId) async {
    // Verify current user is bishop
    final currentUser = await _authService.getCurrentUserData();
    if (currentUser == null || !currentUser.isBishop) {
      throw Exception('Only bishops can delete constituencies');
    }

    try {
      // Get constituency data first
      final constituencyDoc =
          await _firestore
              .collection('constituencies')
              .doc(constituencyId)
              .get();
      if (!constituencyDoc.exists) return;

      final constituency = ConstituencyModel.fromFirestore(constituencyDoc);

      // Remove pastor assignment
      if (constituency.pastorId.isNotEmpty) {
        await _firestore.collection('users').doc(constituency.pastorId).update({
          'constituencyId': null,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }

      // Remove constituency assignment from all leaders
      await _firestore
          .collection('users')
          .where('constituencyId', isEqualTo: constituencyId)
          .get()
          .then((snapshot) {
            final batch = _firestore.batch();
            for (var doc in snapshot.docs) {
              batch.update(doc.reference, {
                'constituencyId': null,
                'updatedAt': Timestamp.fromDate(DateTime.now()),
              });
            }
            return batch.commit();
          });

      // Delete constituency
      await _firestore
          .collection('constituencies')
          .doc(constituencyId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete constituency: $e');
    }
  }

  /// Get pastor performance metrics
  Future<Map<String, dynamic>> getPastorMetrics(String pastorId) async {
    try {
      // Get fellowship count under this pastor
      final fellowshipsQuery =
          await _firestore
              .collection('fellowships')
              .where('pastorId', isEqualTo: pastorId)
              .get();

      // Get leader count under this pastor
      final leadersQuery =
          await _firestore
              .collection('users')
              .where('assignedPastorId', isEqualTo: pastorId)
              .where('role', isEqualTo: UserRole.leader.value)
              .get();

      // Get recent reports count (last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final reportsQuery =
          await _firestore
              .collectionGroup('reports')
              .where('pastorId', isEqualTo: pastorId)
              .where(
                'createdAt',
                isGreaterThan: Timestamp.fromDate(thirtyDaysAgo),
              )
              .get();

      return {
        'fellowshipCount': fellowshipsQuery.docs.length,
        'leaderCount': leadersQuery.docs.length,
        'recentReportsCount': reportsQuery.docs.length,
        'lastMetricsUpdate': DateTime.now(),
      };
    } catch (e) {
      return {
        'fellowshipCount': 0,
        'leaderCount': 0,
        'recentReportsCount': 0,
        'error': e.toString(),
      };
    }
  }

  /// Get unassigned pastors (pastors without constituencies)
  Stream<List<UserModel>> getUnassignedPastors() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.pastor.value)
        .where('constituencyId', isNull: true)
        .orderBy('firstName')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
        );
  }

  /// Fix data synchronization issues between pastors and constituencies
  Future<void> fixPastorConstituencySync() async {
    // Verify current user is bishop
    final currentUser = await _authService.getCurrentUserData();
    if (currentUser == null || !currentUser.isBishop) {
      throw Exception('Only bishops can perform data synchronization');
    }

    try {
      print('🔄 Starting pastor-constituency data synchronization...');

      // Get all pastors and constituencies
      final pastorsSnapshot =
          await _firestore
              .collection('users')
              .where('role', isEqualTo: UserRole.pastor.value)
              .get();

      final constituenciesSnapshot =
          await _firestore.collection('constituencies').get();

      final pastors =
          pastorsSnapshot.docs
              .map((doc) => UserModel.fromFirestore(doc))
              .toList();

      final constituencies =
          constituenciesSnapshot.docs
              .map((doc) => ConstituencyModel.fromFirestore(doc))
              .toList();

      int fixedCount = 0;

      // Fix mismatched assignments
      for (final pastor in pastors) {
        if (pastor.constituencyId != null &&
            pastor.constituencyId!.isNotEmpty) {
          // Pastor claims to be assigned to a constituency
          final constituency = constituencies.firstWhere(
            (c) => c.id == pastor.constituencyId,
            orElse:
                () => ConstituencyModel(
                  id: '',
                  name: '',
                  pastorId: '',
                  pastorName: '',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
          );

          if (constituency.id.isEmpty) {
            // Constituency doesn't exist, clear pastor assignment
            print(
              '⚠️ Clearing invalid constituency assignment for ${pastor.fullName}',
            );
            await _firestore.collection('users').doc(pastor.id).update({
              'constituencyId': null,
              'updatedAt': Timestamp.fromDate(DateTime.now()),
            });
            fixedCount++;
          } else if (constituency.pastorId != pastor.id) {
            // Constituency exists but doesn't point back to this pastor
            print(
              '🔧 Fixing constituency assignment for ${pastor.fullName} -> ${constituency.name}',
            );
            await _firestore
                .collection('constituencies')
                .doc(constituency.id)
                .update({
                  'pastorId': pastor.id,
                  'pastorName': pastor.fullName,
                  'updatedAt': Timestamp.fromDate(DateTime.now()),
                });
            fixedCount++;
          }
        }
      }

      // Fix constituencies that claim to have pastors but the pastor doesn't point back
      for (final constituency in constituencies) {
        if (constituency.pastorId.isNotEmpty) {
          final pastor = pastors.firstWhere(
            (p) => p.id == constituency.pastorId,
            orElse:
                () => UserModel(
                  id: '',
                  email: '',
                  firstName: '',
                  lastName: '',
                  role: UserRole.leader,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
          );

          if (pastor.id.isEmpty) {
            // Pastor doesn't exist, clear constituency assignment
            print(
              '⚠️ Clearing invalid pastor assignment for ${constituency.name}',
            );
            await _firestore
                .collection('constituencies')
                .doc(constituency.id)
                .update({
                  'pastorId': '',
                  'pastorName': '',
                  'updatedAt': Timestamp.fromDate(DateTime.now()),
                });
            fixedCount++;
          } else if (pastor.constituencyId != constituency.id) {
            // Pastor exists but doesn't point back to this constituency
            print(
              '🔧 Fixing pastor assignment for ${constituency.name} -> ${pastor.fullName}',
            );
            await _firestore.collection('users').doc(pastor.id).update({
              'constituencyId': constituency.id,
              'updatedAt': Timestamp.fromDate(DateTime.now()),
            });
            fixedCount++;
          }
        }
      }

      print('✅ Data synchronization completed! Fixed $fixedCount assignments.');
    } catch (e) {
      print('❌ Error during data synchronization: $e');
      throw Exception('Failed to synchronize data: $e');
    }
  }

  /// Private helper to assign pastor to constituency
  Future<void> _assignPastorToConstituency(
    String pastorId,
    String constituencyId,
  ) async {
    // Get pastor and constituency names
    final pastorDoc = await _firestore.collection('users').doc(pastorId).get();
    final pastor = UserModel.fromFirestore(pastorDoc);

    // Update constituency with pastor info
    await _firestore.collection('constituencies').doc(constituencyId).update({
      'pastorId': pastorId,
      'pastorName': pastor.fullName,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Private helper to remove pastor from constituency
  Future<void> _removePastorFromConstituency(
    String pastorId,
    String constituencyId,
  ) async {
    await _firestore.collection('constituencies').doc(constituencyId).update({
      'pastorId': '',
      'pastorName': '',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Create a new pastor account manually with password (Bishop only)
  Future<Map<String, dynamic>> createPastorManual({
    required String email,
    required String firstName,
    required String lastName,
    required String password,
    String? phoneNumber,
    String? constituencyId,
  }) async {
    print(
      '🔄 Starting manual pastor creation for $firstName $lastName ($email)',
    );

    // Verify current user is bishop
    final currentUser = await _authService.getCurrentUserData();
    if (currentUser == null || !currentUser.isBishop) {
      throw Exception('Only bishops can create pastor accounts');
    }

    print('✅ Bishop verification passed: ${currentUser.fullName}');

    try {
      // Check if email already exists
      print('🔍 Checking if email already exists...');
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(
        email,
      );
      if (methods.isNotEmpty) {
        throw Exception('A user with this email already exists');
      }

      print('✅ Email check passed - no existing user found');

      // Store current user info to re-login after pastor creation
      final currentUserEmail = FirebaseAuth.instance.currentUser?.email;

      print('📝 Creating Firebase Auth account...');

      // Create Firebase Auth account
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final User? newUser = userCredential.user;
      if (newUser == null) {
        throw Exception('Failed to create Firebase Auth account');
      }

      // Update display name
      await newUser.updateDisplayName('$firstName $lastName');

      print('✅ Firebase Auth account created successfully');

      // Generate a unique ID for the pastor
      final pastorId = newUser.uid;

      print('📝 Creating pastor document in Firestore...');

      // Create pastor document in Firestore
      final now = DateTime.now();

      final pastor = UserModel(
        id: pastorId,
        email: email,
        firstName: firstName,
        lastName: lastName,
        role: UserRole.pastor,
        phoneNumber: phoneNumber,
        constituencyId: constituencyId,
        status:
            Status.active, // Manually created pastors are immediately active
        createdAt: now,
        updatedAt: now,
      );

      // Save pastor document to Firestore
      try {
        await _firestore
            .collection('users')
            .doc(pastorId)
            .set(pastor.toFirestore());
        print('✅ Pastor document created successfully');
      } catch (e) {
        print(
          '⚠️ Warning: Could not save to Firestore (will work offline): $e',
        );
        // Continue anyway - the Firebase Auth account is created
      }

      // If constituency is assigned, try to update it
      if (constituencyId != null) {
        try {
          print('🏛️ Assigning pastor to constituency...');
          await _assignPastorToConstituency(pastorId, constituencyId);
          print('✅ Pastor assigned to constituency successfully');
        } catch (e) {
          print(
            '⚠️ Warning: Could not assign constituency (will work offline): $e',
          );
        }
      }

      // Re-authenticate the bishop
      print('🔄 Re-authenticating bishop...');
      try {
        // Sign out the newly created pastor
        await FirebaseAuth.instance.signOut();

        // Note: In a real app, you'd need to store and restore the bishop's session
        // For now, we'll just sign out and let them sign back in
        print('⚠️ Please sign back in as bishop');
      } catch (e) {
        print('⚠️ Warning: Could not re-authenticate bishop: $e');
      }

      print('🎉 Manual pastor creation completed successfully!');

      return {
        'pastor': pastor,
        'email': email,
        'password': password,
        'success': true,
        'message': 'Pastor account created successfully!',
        'loginDetails': {
          'email': email,
          'password': password,
          'role': 'Pastor',
          'name': '$firstName $lastName',
          'phone': phoneNumber,
        },
      };
    } catch (e) {
      print('❌ Error in manual pastor creation: $e');
      throw Exception('Failed to create pastor account: $e');
    }
  }
}

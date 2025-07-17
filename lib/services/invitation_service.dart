import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../utils/enums.dart';

class InvitationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate a secure invitation token
  String _generateInvitationToken() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(
      8,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  /// Create a pastor invitation with automated email
  Future<Map<String, dynamic>> createPastorInvitation({
    required String email,
    required String firstName,
    required String lastName,
    required String bishopName,
    required String bishopId,
    String? phoneNumber,
    String? constituencyId,
  }) async {
    print('📧 Starting invitation creation for $firstName $lastName ($email)');

    try {
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(days: 7)); // 7-day expiration
      final token = _generateInvitationToken();

      print('🔑 Generated invitation token: $token');

      // Create invitation record
      print('📝 Creating invitation record in Firestore...');
      final invitationData = {
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'phoneNumber': phoneNumber,
        'role': UserRole.pastor.value,
        'constituencyId': constituencyId,
        'token': token,
        'invitedBy': bishopName,
        'invitedById': bishopId,
        'invitedAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'status': 'pending',
        'type': 'pastor_invitation',
        'remindersSent': 0,
        'lastReminderAt': null,
      };

      final invitationRef = await _firestore
          .collection('invitations')
          .add(invitationData);

      print('✅ Invitation record created with ID: ${invitationRef.id}');

      // Generate email content
      print('📄 Generating email content...');
      final emailContent = _generateInvitationEmailContent(
        firstName: firstName,
        lastName: lastName,
        email: email,
        bishopName: bishopName,
        token: token,
        expiresAt: expiresAt,
      );

      print('✅ Email content generated');

      // Send email
      print('📤 Sending invitation email...');
      await _sendInvitationEmail(
        email: email,
        subject: 'Invitation to First Love Church Management System',
        content: emailContent,
      );

      print('✅ Invitation email sent successfully');

      final result = {
        'invitationId': invitationRef.id,
        'token': token,
        'expiresAt': expiresAt,
        'emailContent': emailContent,
        'success': true,
      };

      print('🎉 Invitation creation completed successfully!');
      return result;
    } catch (e) {
      print('❌ Error creating invitation: $e');
      throw Exception('Failed to create pastor invitation: $e');
    }
  }

  /// Generate email content for pastor invitation
  String _generateInvitationEmailContent({
    required String firstName,
    required String lastName,
    required String email,
    required String bishopName,
    required String token,
    required DateTime expiresAt,
  }) {
    final expiryDate = '${expiresAt.day}/${expiresAt.month}/${expiresAt.year}';

    return '''
Dear $firstName $lastName,

Greetings in the name of our Lord Jesus Christ!

You have been invited by Bishop $bishopName to join the First Love Church Management System (FLCMS) as a Pastor.

🔐 Your Account Details:
• Email: $email
• Role: Pastor
• Invited by: Bishop $bishopName
• Invitation Code: $token

📱 To activate your account:

1. Download the FLCMS mobile app
2. Tap "Create New Account"
3. Enter your email: $email
4. Select role: "Pastor" 
5. Enter this invitation code: $token
6. Create your secure password
7. Complete your profile setup

⏰ Important: This invitation expires on $expiryDate

📞 Need Help?
If you encounter any issues during registration, please contact:
• Bishop $bishopName
• Church IT Support: support@firstlovechurch.org

We're excited to have you join our digital ministry platform!

Blessings,
First Love Church IT Team

---
This is an automated message from the First Love Church Management System.
''';
  }

  /// Send invitation email (simulated - integrate with actual email service)
  Future<void> _sendInvitationEmail({
    required String email,
    required String subject,
    required String content,
  }) async {
    // Simulate email sending with console output
    print('📧 EMAIL SENT TO: $email');
    print('📋 SUBJECT: $subject');
    print('📄 CONTENT:\n$content');
    print('=' * 50);

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // TODO: In production, integrate with email service:
    // - SendGrid, Mailgun, AWS SES, etc.
  }

  /// Validate invitation token
  Future<Map<String, dynamic>?> validateInvitationToken(String token) async {
    try {
      final snapshot =
          await _firestore
              .collection('invitations')
              .where('token', isEqualTo: token.toUpperCase())
              .where('status', isEqualTo: 'pending')
              .limit(1)
              .get();

      if (snapshot.docs.isEmpty) {
        return null; // Invalid token
      }

      final invitation = snapshot.docs.first.data();
      final expiresAt = (invitation['expiresAt'] as Timestamp).toDate();

      if (DateTime.now().isAfter(expiresAt)) {
        // Mark as expired
        await snapshot.docs.first.reference.update({
          'status': 'expired',
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
        return null; // Expired token
      }

      return {'invitationId': snapshot.docs.first.id, 'data': invitation};
    } catch (e) {
      print('Error validating invitation token: $e');
      return null;
    }
  }

  /// Mark invitation as accepted
  Future<void> acceptInvitation(String invitationId) async {
    await _firestore.collection('invitations').doc(invitationId).update({
      'status': 'accepted',
      'acceptedAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Resend invitation email
  Future<Map<String, dynamic>> resendInvitation(String invitationId) async {
    try {
      final invitationDoc =
          await _firestore.collection('invitations').doc(invitationId).get();

      if (!invitationDoc.exists) {
        throw Exception('Invitation not found');
      }

      final data = invitationDoc.data()!;

      // Check if still valid
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        throw Exception('Invitation has expired');
      }

      // Generate reminder email content
      final emailContent = '''
REMINDER: ${_generateInvitationEmailContent(firstName: data['firstName'], lastName: data['lastName'], email: data['email'], bishopName: data['invitedBy'], token: data['token'], expiresAt: expiresAt)}

Note: This is a reminder. Your original invitation is still valid.
''';

      // Send reminder email
      await _sendInvitationEmail(
        email: data['email'],
        subject: 'REMINDER: Invitation to First Love Church Management System',
        content: emailContent,
      );

      // Update reminder count
      await invitationDoc.reference.update({
        'remindersSent': (data['remindersSent'] ?? 0) + 1,
        'lastReminderAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      return {'success': true, 'emailContent': emailContent};
    } catch (e) {
      throw Exception('Failed to resend invitation: $e');
    }
  }

  /// Get all pending invitations for a bishop
  Stream<List<Map<String, dynamic>>> getPendingInvitations(String bishopId) {
    return _firestore
        .collection('invitations')
        .where('invitedById', isEqualTo: bishopId)
        .where('status', isEqualTo: 'pending')
        .orderBy('invitedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => {'id': doc.id, ...doc.data()})
                  .toList(),
        );
  }

  /// Send welcome email after successful registration
  Future<void> sendWelcomeEmail({
    required String email,
    required String firstName,
    required String lastName,
    required UserRole role,
  }) async {
    final content = '''
Dear $firstName $lastName,

Welcome to the First Love Church Management System!

🎉 Your account has been successfully activated:
• Email: $email
• Role: ${role.displayName}
• Status: Active

🔐 Security Reminder:
• Keep your login credentials secure
• Don't share your password with anyone
• Contact support if you suspect unauthorized access

📱 Getting Started:
• Explore your dashboard to familiarize yourself with features
• Update your profile information in settings
• Contact your supervising Bishop for guidance

📞 Support:
• Your supervising Bishop
• IT Support: support@firstlovechurch.org

We're blessed to have you as part of our digital ministry!

Blessings,
First Love Church IT Team
''';

    await _sendInvitationEmail(
      email: email,
      subject: 'Welcome to First Love Church Management System!',
      content: content,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/fellowship_model.dart';
import '../../services/admin_user_service.dart';
import '../../utils/enums.dart';

/// Comprehensive Leader Management Screen for Pastors
class LeaderManagementScreen extends StatefulWidget {
  final UserModel user;

  const LeaderManagementScreen({super.key, required this.user});

  @override
  State<LeaderManagementScreen> createState() => _LeaderManagementScreenState();
}

class _LeaderManagementScreenState extends State<LeaderManagementScreen>
    with SingleTickerProviderStateMixin {
  final AdminUserService _adminUserService = AdminUserService();
  late TabController _tabController;

  // Streams for real-time data
  Stream<List<UserModel>>? _leadersStream;
  Stream<List<FellowshipModel>>? _fellowshipsStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeStreams();
  }

  void _initializeStreams() {
    // Stream for leaders in this pastor's constituency
    _leadersStream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: UserRole.leader.value)
        .where('constituencyId', isEqualTo: widget.user.constituencyId)
        .orderBy('firstName')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
        );

    // Stream for fellowships in this pastor's constituency
    _fellowshipsStream = FirebaseFirestore.instance
        .collection('fellowships')
        .where('constituencyId', isEqualTo: widget.user.constituencyId)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => FellowshipModel.fromFirestore(doc))
                  .toList(),
        );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leader Management'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.orange.shade100,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Leaders'),
            Tab(icon: Icon(Icons.home_work), text: 'Fellowships'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildLeadersTab(), _buildFellowshipsTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateLeaderDialog,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Leader'),
      ),
    );
  }

  Widget _buildLeadersTab() {
    return StreamBuilder<List<UserModel>>(
      stream: _leadersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() => _initializeStreams()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final leaders = snapshot.data ?? [];

        if (leaders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Leaders Yet',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create your first leader account to get started',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _showCreateLeaderDialog,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Create First Leader'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.people, color: Colors.orange, size: 32),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${leaders.length} Leader${leaders.length != 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'In your constituency',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      const Spacer(),
                      _buildStatsChip(
                        'Active',
                        leaders.where((l) => l.status == Status.active).length,
                        Colors.green,
                      ),
                      const SizedBox(width: 8),
                      _buildStatsChip(
                        'Inactive',
                        leaders
                            .where((l) => l.status == Status.inactive)
                            .length,
                        Colors.red,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Leaders List
              Expanded(
                child: ListView.builder(
                  itemCount: leaders.length,
                  itemBuilder: (context, index) {
                    final leader = leaders[index];
                    return _buildLeaderCard(leader);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderCard(UserModel leader) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              leader.status == Status.active
                  ? Colors.green.shade100
                  : Colors.red.shade100,
          child: Icon(
            Icons.person,
            color:
                leader.status == Status.active
                    ? Colors.green.shade700
                    : Colors.red.shade700,
          ),
        ),
        title: Text(
          leader.fullName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(leader.email, overflow: TextOverflow.ellipsis, maxLines: 1),
            if (leader.phoneNumber?.isNotEmpty == true)
              Text('📱 ${leader.phoneNumber!}'),
            if (leader.fellowshipId != null && leader.fellowshipId!.isNotEmpty)
              Text('🏠 Fellowship ID: ${leader.fellowshipId}'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color:
                    leader.status == Status.active
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                leader.status.value.toUpperCase(),
                style: TextStyle(
                  color:
                      leader.status == Status.active
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleLeaderAction(value, leader),
          itemBuilder:
              (context) => [
                const PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility, size: 18),
                      SizedBox(width: 8),
                      Text('View Details'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Edit Info'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value:
                      leader.status == Status.active
                          ? 'deactivate'
                          : 'activate',
                  child: Row(
                    children: [
                      Icon(
                        leader.status == Status.active
                            ? Icons.block
                            : Icons.check_circle,
                        size: 18,
                        color:
                            leader.status == Status.active
                                ? Colors.red
                                : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        leader.status == Status.active
                            ? 'Deactivate'
                            : 'Activate',
                      ),
                    ],
                  ),
                ),
              ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildFellowshipsTab() {
    return StreamBuilder<List<FellowshipModel>>(
      stream: _fellowshipsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final fellowships = snapshot.data ?? [];

        if (fellowships.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.home_work_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Fellowships',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Go to Fellowships tab to create fellowships in your constituency',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.home_work,
                        color: Colors.orange,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${fellowships.length} Fellowship${fellowships.length != 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'In your constituency',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: fellowships.length,
                  itemBuilder: (context, index) {
                    final fellowship = fellowships[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.shade100,
                          child: Icon(
                            Icons.home_work,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        title: Text(
                          fellowship.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (fellowship.description?.isNotEmpty == true)
                              Text(fellowship.description!),
                            if (fellowship.leaderId != null &&
                                fellowship.leaderId!.isNotEmpty)
                              Text('👤 Leader ID: ${fellowship.leaderId}'),
                            if (fellowship.meetingLocation != null &&
                                fellowship.meetingLocation!.isNotEmpty)
                              Text('📍 ${fellowship.meetingLocation}'),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleLeaderAction(String action, UserModel leader) {
    switch (action) {
      case 'view':
        _showLeaderDetails(leader);
        break;
      case 'edit':
        _showEditLeaderDialog(leader);
        break;
      case 'activate':
      case 'deactivate':
        _toggleLeaderStatus(leader);
        break;
    }
  }

  void _showLeaderDetails(UserModel leader) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('${leader.fullName} Details'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow('Name:', leader.fullName),
                  _buildDetailRow('Email:', leader.email),
                  _buildDetailRow(
                    'Phone:',
                    leader.phoneNumber?.isNotEmpty == true
                        ? leader.phoneNumber!
                        : 'Not provided',
                  ),
                  _buildDetailRow('Role:', 'Leader'),
                  _buildDetailRow('Status:', leader.status.value.toUpperCase()),
                  _buildDetailRow(
                    'Fellowship:',
                    leader.fellowshipId ?? 'Not assigned',
                  ),
                  _buildDetailRow(
                    'Created:',
                    leader.createdAt.toString().split(' ')[0],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showEditLeaderDialog(UserModel leader) {
    final firstNameController = TextEditingController(text: leader.firstName);
    final lastNameController = TextEditingController(text: leader.lastName);
    final phoneController = TextEditingController(text: leader.phoneNumber);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit ${leader.fullName}'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                      ),
                      validator:
                          (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                      ),
                      validator:
                          (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context);
                    await _updateLeader(
                      leader,
                      firstNameController.text.trim(),
                      lastNameController.text.trim(),
                      phoneController.text.trim(),
                    );
                  }
                },
                child: const Text('Update'),
              ),
            ],
          ),
    );
  }

  Future<void> _updateLeader(
    UserModel leader,
    String firstName,
    String lastName,
    String phone,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(leader.id)
          .update({
            'firstName': firstName,
            'lastName': lastName,
            'fullName': '$firstName $lastName',
            'phoneNumber': phone,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leader updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update leader: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleLeaderStatus(UserModel leader) async {
    final newStatus =
        leader.status == Status.active ? Status.inactive : Status.active;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(leader.id)
          .update({
            'status': newStatus.value,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Leader ${newStatus.value}d successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update leader status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCreateLeaderDialog() {
    final formKey = GlobalKey<FormState>();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    String? selectedFellowshipId;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.person_add, color: Colors.orange),
                SizedBox(width: 8),
                Text('Create New Leader Account'),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator:
                          (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator:
                          (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                        hintText: 'leader@example.com',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value?.isEmpty == true) return 'Required';
                        if (!RegExp(
                          r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                        ).hasMatch(value!)) {
                          return 'Invalid email format';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                        hintText: '+1234567890',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    // Fellowship assignment
                    StreamBuilder<List<FellowshipModel>>(
                      stream: _fellowshipsStream,
                      builder: (context, snapshot) {
                        final fellowships = snapshot.data ?? [];
                        return DropdownButtonFormField<String>(
                          value: selectedFellowshipId,
                          decoration: const InputDecoration(
                            labelText: 'Fellowship Assignment (Optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.home_work),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('No Fellowship Assignment'),
                            ),
                            ...fellowships.map(
                              (fellowship) => DropdownMenuItem<String>(
                                value: fellowship.id,
                                child: Text(fellowship.name),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            selectedFellowshipId = value;
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context);
                    await _createLeaderAccount(
                      firstName: firstNameController.text.trim(),
                      lastName: lastNameController.text.trim(),
                      email: emailController.text.trim(),
                      phoneNumber: phoneController.text.trim(),
                      fellowshipId: selectedFellowshipId,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Create Leader'),
              ),
            ],
          ),
    );
  }

  Future<void> _createLeaderAccount({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    String? fellowshipId,
  }) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            title: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Creating Leader Account...'),
              ],
            ),
            content: Text(
              'Please wait while we create the leader account securely.',
            ),
          ),
    );

    try {
      // Use the professional AdminUserService
      final result = await _adminUserService.createUserAccount(
        email: email,
        firstName: firstName,
        lastName: lastName,
        role: UserRole.leader,
        phoneNumber: phoneNumber.isNotEmpty ? phoneNumber : null,
        constituencyId: widget.user.constituencyId,
        fellowshipId: fellowshipId,
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (result['success'] == true) {
        // Show success dialog with login details
        _showAccountCreatedDialog(result);
      } else {
        _showErrorDialog(
          'Failed to create leader account',
          result['error'] ?? 'Unknown error',
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorDialog('Error Creating Leader', e.toString());
    }
  }

  void _showAccountCreatedDialog(Map<String, dynamic> result) {
    final loginDetails = result['loginDetails'] as Map<String, dynamic>;
    final accountInfo = result['accountInfo'] as Map<String, dynamic>;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 12),
                Text('Leader Account Created!'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'The leader account has been created successfully.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 20),

                  // Account Information
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Account Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow('Name:', accountInfo['fullName']),
                        _buildInfoRow('Email:', accountInfo['email']),
                        _buildInfoRow('Role:', accountInfo['role']),
                        _buildInfoRow('Created:', accountInfo['created']),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Login Details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.security,
                              color: Colors.orange.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Login Details (Share Securely)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow('Email:', loginDetails['email']),
                        _buildInfoRow('Password:', loginDetails['password']),
                        const SizedBox(height: 8),
                        Text(
                          'The leader must change this password on first login.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next Steps:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text('1. Share login details securely with the leader'),
                        Text('2. Leader logs in with provided credentials'),
                        Text('3. Leader will be prompted to change password'),
                        Text(
                          '4. Account will be fully activated after first login',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Done'),
              ),
            ],
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
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 8),
                Text(title),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }
}

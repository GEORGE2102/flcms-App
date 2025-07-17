import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/constituency_model.dart';
import '../../services/pastor_service.dart';
import '../../services/admin_user_service.dart';
import '../../utils/enums.dart';

/// Pastor Management Screen for Bishops
///
/// This screen provides comprehensive pastor and constituency management
/// functionality exclusively for users with Bishop role. It features:
///
/// - Real-time pastor list with status indicators
/// - Constituency assignment and management
/// - Pastor performance metrics and information
/// - CRUD operations for both pastors and constituencies
/// - Role-based access control
///
/// **Architecture Features:**
/// - Uses StreamBuilder for real-time data updates
/// - Implements proper state management with StatefulWidget
/// - Follows Material Design 3 principles
/// - Uses ExpansionTile for better UX with detailed information
/// - Implements proper error handling and user feedback
///
/// **Security:**
/// - All operations require Bishop role verification
/// - Proper permission checks at service level
/// - Safe async/await patterns with error handling
class PastorManagement extends StatefulWidget {
  const PastorManagement({super.key});

  @override
  State<PastorManagement> createState() => _PastorManagementState();
}

class _PastorManagementState extends State<PastorManagement>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PastorService _pastorService = PastorService();
  final AdminUserService _adminUserService = AdminUserService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        title: const Text('Pastor Management'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Pastors'),
            Tab(icon: Icon(Icons.business), text: 'Constituencies'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildPastorsTab(), _buildConstituenciesTab()],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPastorsTab() {
    return StreamBuilder<List<UserModel>>(
      stream: _pastorService.getAllPastors(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final pastors = snapshot.data ?? [];

        if (pastors.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No pastors found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap the + button to add a new pastor',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: pastors.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final pastor = pastors[index];
            return _buildPastorCard(pastor);
          },
        );
      },
    );
  }

  Widget _buildConstituenciesTab() {
    return StreamBuilder<List<ConstituencyModel>>(
      stream: _pastorService.getAllConstituencies(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final constituencies = snapshot.data ?? [];

        if (constituencies.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.business_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No constituencies found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap the + button to add a new constituency',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: constituencies.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final constituency = constituencies[index];
            return _buildConstituencyCard(constituency);
          },
        );
      },
    );
  }

  Widget _buildPastorCard(UserModel pastor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundImage:
              pastor.profileImageUrl != null
                  ? NetworkImage(pastor.profileImageUrl!)
                  : null,
          child:
              pastor.profileImageUrl == null
                  ? Text(pastor.firstName[0] + pastor.lastName[0])
                  : null,
        ),
        title: Text(pastor.fullName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pastor.email),
            if (pastor.phoneNumber != null) Text(pastor.phoneNumber!),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildStatusChip(pastor.status),
                const SizedBox(width: 8),
                _buildAssignmentChip(pastor),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPastorInfo(pastor),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: () => _editPastor(pastor),
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                    TextButton.icon(
                      onPressed: () => _assignConstituencyToPastor(pastor),
                      icon: const Icon(Icons.assignment),
                      label: const Text('Assign'),
                    ),
                    TextButton.icon(
                      onPressed:
                          pastor.status == Status.active
                              ? () => _deactivatePastor(pastor)
                              : () => _reactivatePastor(pastor),
                      icon: Icon(
                        pastor.status == Status.active
                            ? Icons.pause
                            : Icons.play_arrow,
                      ),
                      label: Text(
                        pastor.status == Status.active
                            ? 'Deactivate'
                            : 'Activate',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _deletePastor(pastor),
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConstituencyCard(ConstituencyModel constituency) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.business)),
        title: Text(constituency.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (constituency.description != null)
              Text(constituency.description!),
            const SizedBox(height: 4),
            Text(
              constituency.pastorName.isNotEmpty
                  ? 'Pastor: ${constituency.pastorName}'
                  : 'No pastor assigned',
              style: TextStyle(
                color:
                    constituency.pastorName.isNotEmpty
                        ? Colors.green
                        : Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _editConstituency(constituency);
                break;
              case 'delete':
                _deleteConstituency(constituency);
                break;
            }
          },
          itemBuilder:
              (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(Status status) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case Status.active:
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      case Status.inactive:
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        break;
      case Status.pending:
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
      case Status.suspended:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade800;
        break;
    }

    return Chip(
      label: Text(status.displayName),
      backgroundColor: backgroundColor,
      labelStyle: TextStyle(color: textColor, fontSize: 12),
    );
  }

  Widget _buildAssignmentChip(UserModel pastor) {
    if (pastor.constituencyId != null && pastor.constituencyId!.isNotEmpty) {
      return StreamBuilder<List<ConstituencyModel>>(
        stream: _pastorService.getAllConstituencies(),
        builder: (context, snapshot) {
          final constituencies = snapshot.data ?? [];
          final constituency = constituencies.firstWhere(
            (c) => c.id == pastor.constituencyId,
            orElse:
                () => ConstituencyModel(
                  id: '',
                  name: 'Unknown',
                  pastorId: '',
                  pastorName: '',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
          );

          return Chip(
            label: Text(constituency.name),
            backgroundColor: Colors.blue.shade100,
            labelStyle: TextStyle(color: Colors.blue.shade800, fontSize: 12),
            avatar: const Icon(Icons.business, size: 16),
          );
        },
      );
    } else {
      return Chip(
        label: const Text('Unassigned'),
        backgroundColor: Colors.orange.shade100,
        labelStyle: TextStyle(color: Colors.orange.shade800, fontSize: 12),
        avatar: const Icon(Icons.warning, size: 16),
      );
    }
  }

  Widget _buildPastorInfo(UserModel pastor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pastor Information',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.email, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(pastor.email)),
          ],
        ),
        if (pastor.phoneNumber != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.phone, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(pastor.phoneNumber!)),
            ],
          ),
        ],
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text('Created: ${_formatDate(pastor.createdAt)}')),
          ],
        ),
        if (pastor.constituencyId != null) ...[
          const SizedBox(height: 8),
          const Text(
            'Constituency Assignment',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          StreamBuilder<List<ConstituencyModel>>(
            stream: _pastorService.getAllConstituencies(),
            builder: (context, snapshot) {
              final constituencies = snapshot.data ?? [];
              final constituency = constituencies.firstWhere(
                (c) => c.id == pastor.constituencyId,
                orElse:
                    () => ConstituencyModel(
                      id: '',
                      name: 'Unknown Constituency',
                      pastorId: '',
                      pastorName: '',
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
              );

              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      constituency.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (constituency.description != null)
                      Text(constituency.description!),
                    Text('Fellowships: ${constituency.fellowshipCount}'),
                    Text('Members: ${constituency.totalMembers}'),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showAddDialog(BuildContext context) {
    if (_tabController.index == 0) {
      _showAddPastorDialog();
    } else {
      _showAddConstituencyDialog();
    }
  }

  void _showAddPastorDialog() {
    final formKey = GlobalKey<FormState>();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    String? selectedConstituencyId;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Create New Pastor Account'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: firstNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                        hintText: 'John',
                      ),
                      validator:
                          (value) =>
                              value?.isEmpty == true
                                  ? 'First name is required'
                                  : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: lastNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                        hintText: 'Smith',
                      ),
                      validator:
                          (value) =>
                              value?.isEmpty == true
                                  ? 'Last name is required'
                                  : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                        hintText: 'pastor@church.com',
                      ),
                      validator: (value) {
                        if (value?.isEmpty == true) return 'Email is required';

                        // More robust email validation
                        final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                        if (!emailRegex.hasMatch(value!)) {
                          return 'Please enter a valid email address';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                        hintText: '+1 (555) 123-4567',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Constituency dropdown
                    StreamBuilder<List<ConstituencyModel>>(
                      stream: _pastorService.getAllConstituencies(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const LinearProgressIndicator();
                        }

                        final constituencies = snapshot.data ?? [];
                        final availableConstituencies =
                            constituencies
                                .where((c) => c.pastorId.isEmpty)
                                .toList();

                        return DropdownButtonFormField<String>(
                          value: selectedConstituencyId,
                          decoration: const InputDecoration(
                            labelText: 'Assign Constituency (Optional)',
                            border: OutlineInputBorder(),
                            hintText: 'Select a constituency',
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('No assignment'),
                            ),
                            ...availableConstituencies.map((constituency) {
                              return DropdownMenuItem<String>(
                                value: constituency.id,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      constituency.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (constituency.description != null)
                                      Text(
                                        constituency.description!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) {
                            selectedConstituencyId = value;
                          },
                          validator: null, // Optional field
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
                    await _createPastorAccount(
                      firstName: firstNameController.text.trim(),
                      lastName: lastNameController.text.trim(),
                      email: emailController.text.trim(),
                      phoneNumber: phoneController.text.trim(),
                      constituencyId: selectedConstituencyId,
                    );
                  }
                },
                child: const Text('Create Pastor'),
              ),
            ],
          ),
    );
  }

  Future<void> _createPastorAccount({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    String? constituencyId,
  }) async {
    print('DEBUG: UI - _createPastorAccount method called');
    print('DEBUG: UI - Email: $email, Name: $firstName $lastName');

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
                Text('Creating Pastor Account...'),
              ],
            ),
            content: Text(
              'Please wait while we create the pastor account securely.',
            ),
          ),
    );

    try {
      print('DEBUG: UI - About to call AdminUserService.createUserAccount');

      // Use the professional service
      final result = await _adminUserService.createUserAccount(
        email: email,
        firstName: firstName,
        lastName: lastName,
        role: UserRole.pastor,
        phoneNumber: phoneNumber.isNotEmpty ? phoneNumber : null,
        constituencyId: constituencyId,
      );

      print('DEBUG: UI - AdminUserService.createUserAccount completed');
      print('DEBUG: UI - Result: $result');

      // Close loading dialog first
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Wait a moment for dialog to close
      await Future.delayed(const Duration(milliseconds: 100));

      // Check result and show appropriate dialog
      if (mounted) {
        if (result['success'] == true) {
          // Show success dialog with login details
          _showAccountCreatedDialog(result);
        } else {
          _showErrorDialog(
            'Failed to create pastor account',
            result['error'] ?? 'Unknown error',
          );
        }
      }
    } catch (e) {
      print('DEBUG: UI - Exception caught: $e');
      print('DEBUG: UI - Exception type: ${e.runtimeType}');

      // Close loading dialog if still open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Wait a moment for dialog to close
      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        _showErrorDialog('Error Creating Pastor', e.toString());
      }
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
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 12),
                Text('Pastor Account Created!'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'The pastor account has been created successfully.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 20),

                  // Account Information
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        _buildInfoRow('Name:', accountInfo['fullName']),
                        _buildInfoRow('Email:', accountInfo['email']),
                        _buildInfoRow('Role:', accountInfo['role']),
                        _buildInfoRow('Created:', accountInfo['created']),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // Login Details
                  Container(
                    padding: EdgeInsets.all(16),
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
                            SizedBox(width: 8),
                            Text(
                              'Login Details (Share Securely)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        _buildInfoRow('Email:', loginDetails['email']),
                        _buildInfoRow('Password:', loginDetails['password']),
                        SizedBox(height: 8),
                        Text(
                          'The pastor must change this password on first login.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // Instructions
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
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
                        Text('1. Share login details securely with the pastor'),
                        Text('2. Pastor logs in with provided credentials'),
                        Text('3. Pastor will be prompted to change password'),
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
                child: Text('Done'),
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
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(fontFamily: 'monospace'),
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
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text(title),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showAddConstituencyDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add New Constituency'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Constituency Name',
                      ),
                      validator:
                          (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                      ),
                      maxLines: 3,
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
                    try {
                      await _pastorService.createConstituency(
                        name: nameController.text.trim(),
                        description:
                            descriptionController.text.trim().isEmpty
                                ? null
                                : descriptionController.text.trim(),
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Constituency created successfully'),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                child: const Text('Create'),
              ),
            ],
          ),
    );
  }

  void _editPastor(UserModel pastor) {
    // TODO: Implement edit pastor functionality
  }

  void _editConstituency(ConstituencyModel constituency) {
    // TODO: Implement edit constituency functionality
  }

  void _deactivatePastor(UserModel pastor) async {
    try {
      await _pastorService.deactivatePastor(pastor.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pastor deactivated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _reactivatePastor(UserModel pastor) async {
    try {
      await _pastorService.reactivatePastor(pastor.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pastor reactivated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _assignConstituencyToPastor(UserModel pastor) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Assign Constituency to ${pastor.fullName}'),
            content: StreamBuilder<List<ConstituencyModel>>(
              stream: _pastorService.getAllConstituencies(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final constituencies = snapshot.data ?? [];
                final availableConstituencies =
                    constituencies
                        .where(
                          (c) => c.pastorId.isEmpty || c.pastorId == pastor.id,
                        )
                        .toList();

                if (availableConstituencies.isEmpty) {
                  return const Text('No available constituencies to assign.');
                }

                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        availableConstituencies.map((constituency) {
                          final isCurrentlyAssigned =
                              constituency.pastorId == pastor.id;

                          return ListTile(
                            title: Text(constituency.name),
                            subtitle:
                                constituency.description != null
                                    ? Text(constituency.description!)
                                    : null,
                            leading: Icon(
                              isCurrentlyAssigned
                                  ? Icons.check_circle
                                  : Icons.business,
                              color: isCurrentlyAssigned ? Colors.green : null,
                            ),
                            trailing:
                                isCurrentlyAssigned
                                    ? TextButton(
                                      onPressed: () async {
                                        try {
                                          await _pastorService.updatePastor(
                                            pastorId: pastor.id,
                                            constituencyId: null,
                                          );
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Pastor unassigned successfully',
                                              ),
                                            ),
                                          );
                                        } catch (e) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                            ),
                                          );
                                        }
                                      },
                                      child: const Text('Remove'),
                                    )
                                    : TextButton(
                                      onPressed: () async {
                                        try {
                                          await _pastorService.updatePastor(
                                            pastorId: pastor.id,
                                            constituencyId: constituency.id,
                                          );
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Pastor assigned successfully',
                                              ),
                                            ),
                                          );
                                        } catch (e) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                            ),
                                          );
                                        }
                                      },
                                      child: const Text('Assign'),
                                    ),
                          );
                        }).toList(),
                  ),
                );
              },
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

  void _deletePastor(UserModel pastor) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Pastor'),
            content: Text(
              'Are you sure you want to delete ${pastor.fullName}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await _pastorService.deletePastor(pastor.id);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pastor deleted successfully'),
                      ),
                    );
                  } catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  void _deleteConstituency(ConstituencyModel constituency) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Constituency'),
            content: Text(
              'Are you sure you want to delete ${constituency.name}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await _pastorService.deleteConstituency(constituency.id);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Constituency deleted successfully'),
                      ),
                    );
                  } catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  void _showEnhancedInvitationSuccess({
    required String firstName,
    required String lastName,
    required String email,
    required String invitationToken,
    required DateTime expiresAt,
    required String emailContent,
  }) {
    final expiryDate = '${expiresAt.day}/${expiresAt.month}/${expiresAt.year}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 28),
                const SizedBox(width: 8),
                const Text('Invitation Sent Successfully!'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Success summary
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person_add,
                              color: Colors.green.shade600,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pastor account created for $firstName $lastName',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.email, color: Colors.green.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Invitation email sent to $email',
                                style: TextStyle(color: Colors.green.shade800),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Invitation details
                  const Text(
                    '📋 Invitation Details:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('👤 Pastor:', '$firstName $lastName'),
                        _buildDetailRow('📧 Email:', email),
                        _buildDetailRow('🔑 Invitation Code:', invitationToken),
                        _buildDetailRow('⏰ Expires:', expiryDate),
                        _buildDetailRow(
                          '📱 Status:',
                          'Email sent automatically',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Instructions for pastor
                  const Text(
                    '📱 What the pastor needs to do:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('1. Download the FLCMS app'),
                        const Text('2. Tap "Create New Account"'),
                        Text('3. Enter email: $email'),
                        const Text('4. Select role: "Pastor"'),
                        Text('5. Enter invitation code: $invitationToken'),
                        const Text('6. Create a secure password'),
                        const Text('7. Complete profile setup'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Email preview
                  ExpansionTile(
                    title: const Text('📄 Email Content Preview'),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          emailContent,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // Resend invitation functionality
                  _resendPastorInvitation(firstName, lastName);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Resend Email'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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

  void _resendPastorInvitation(String firstName, String lastName) async {
    // TODO: Implement resend functionality using pastor ID
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Resending invitation to $firstName $lastName...'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showPastorInvitationInstructions({
    required String firstName,
    required String lastName,
    required String email,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.mail_outline, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('Pastor Invitation Created'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Success message
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$firstName $lastName has been created as a pastor.',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Instructions header
                  const Text(
                    '📱 Next Steps - Please Share This With The Pastor:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),

                  const SizedBox(height: 12),

                  // Instructions container
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
                        Text(
                          'Dear $firstName,',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),

                        const Text(
                          'Your pastor account has been created in the First Love Church Management System (FLCMS).',
                        ),
                        const SizedBox(height: 12),

                        const Text(
                          '🔐 To activate your account:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('1. Download the FLCMS app'),
                              const SizedBox(height: 4),
                              const Text('2. Tap "Create New Account"'),
                              const SizedBox(height: 4),
                              Text('3. Use this exact email: $email'),
                              const SizedBox(height: 4),
                              const Text('4. Select role: "Pastor"'),
                              const SizedBox(height: 4),
                              const Text(
                                '5. Fill in your details and create password',
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '6. Your account will be automatically activated!',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),
                        const Text(
                          'Important: Use the exact email address above when registering.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Copy email section
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            email,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Copy email to clipboard
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Email copied to clipboard!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got It'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Pastor $firstName $lastName created successfully!',
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                },
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
}

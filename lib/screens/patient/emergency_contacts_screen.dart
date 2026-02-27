import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/glass_container.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  List<Map<String, String>> _contacts = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final auth = context.read<AuthProvider>();
    final contacts = await auth.getEmergencyContacts();
    if (mounted) {
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveContacts() async {
    setState(() => _isSaving = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.saveEmergencyContacts(_contacts);
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '✅ Emergency contacts saved'
                : '❌ Failed to save contacts',
          ),
          backgroundColor: success ? AppTheme.success : AppTheme.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _addContact() {
    if (_contacts.length >= AppConstants.maxEmergencyContacts) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ Maximum ${AppConstants.maxEmergencyContacts} contacts allowed',
          ),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }
    _showContactDialog();
  }

  void _editContact(int index) {
    _showContactDialog(existingContact: _contacts[index], editIndex: index);
  }

  void _deleteContact(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove Contact',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Remove ${_contacts[index]['name']} from emergency contacts?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _contacts.removeAt(index));
              _saveContacts();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showContactDialog({
    Map<String, String>? existingContact,
    int? editIndex,
  }) {
    final nameController = TextEditingController(
      text: existingContact?['name'] ?? '',
    );
    final phoneController = TextEditingController(
      text: existingContact?['phone'] ?? '',
    );
    final relationController = TextEditingController(
      text: existingContact?['relation'] ?? '',
    );
    final isEditing = editIndex != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isEditing ? Icons.edit : Icons.person_add,
              color: AppTheme.primary,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              isEditing ? 'Edit Contact' : 'Add Contact',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: AppTheme.textHint,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                style: const TextStyle(color: AppTheme.textPrimary),
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(
                    Icons.phone_outlined,
                    color: AppTheme.textHint,
                  ),
                  hintText: '+91XXXXXXXXXX',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: relationController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Relation',
                  prefixIcon: Icon(
                    Icons.family_restroom,
                    color: AppTheme.textHint,
                  ),
                  hintText: 'e.g. Father, Mother, Spouse',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              final relation = relationController.text.trim();

              if (name.isEmpty || phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Name and phone are required'),
                    backgroundColor: AppTheme.warning,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
                return;
              }

              Navigator.pop(ctx);
              setState(() {
                final contact = {
                  'name': name,
                  'phone': phone,
                  'relation': relation.isNotEmpty ? relation : 'Contact',
                };
                if (isEditing) {
                  _contacts[editIndex] = contact;
                } else {
                  _contacts.add(contact);
                }
              });
              _saveContacts();
            },
            child: Text(
              isEditing ? 'Update' : 'Add',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Info Banner ──
                  GlassContainer(
                    borderColor: AppTheme.danger.withValues(alpha: 0.3),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm,
                            ),
                          ),
                          child: const Icon(
                            Icons.emergency,
                            color: AppTheme.danger,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Auto-Emergency Alert',
                                style: TextStyle(
                                  color: AppTheme.danger,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'When vitals stay critical for ${AppConstants.criticalSustainedDurationSecs}s, '
                                'all contacts below will be automatically called and messaged.',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Contact Count ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Contacts (${_contacts.length}/${AppConstants.maxEmergencyContacts})',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_isSaving)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Contact Cards ──
                  if (_contacts.isEmpty)
                    GlassContainer(
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.person_add_alt_1,
                              color: AppTheme.textHint,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No emergency contacts added yet',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap + to add your first contact',
                              style: TextStyle(
                                color: AppTheme.textHint,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...List.generate(_contacts.length, (index) {
                      final contact = _contacts[index];
                      final isFirst = index == 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassContainer(
                          borderColor: isFirst
                              ? AppTheme.primary.withValues(alpha: 0.3)
                              : null,
                          child: Row(
                            children: [
                              // Avatar
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: isFirst
                                      ? AppTheme.primaryGradient
                                      : AppTheme.accentGradient,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    (contact['name'] ?? 'U')[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          contact['name'] ?? '',
                                          style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (isFirst) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primary
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'PRIMARY',
                                              style: TextStyle(
                                                color: AppTheme.primary,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${contact['relation']} • ${contact['phone']}',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Actions
                              IconButton(
                                onPressed: () => _editContact(index),
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: AppTheme.textHint,
                                  size: 20,
                                ),
                              ),
                              IconButton(
                                onPressed: () => _deleteContact(index),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppTheme.danger,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 16),

                  // ── How it works ──
                  GlassContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppTheme.info,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'How it works',
                              style: TextStyle(
                                color: AppTheme.info,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildInfoRow(
                          Icons.timer,
                          'Vitals monitored continuously in real-time',
                        ),
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          Icons.warning_amber,
                          'Critical threshold sustained for ${AppConstants.criticalSustainedDurationSecs}s triggers alert',
                        ),
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          Icons.sms,
                          'SMS sent to ALL contacts automatically',
                        ),
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          Icons.phone,
                          'Phone call placed to PRIMARY contact',
                        ),
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          Icons.snooze,
                          '${AppConstants.autoEmergencyCooldownSecs ~/ 60}-min cooldown between triggers',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: _contacts.length < AppConstants.maxEmergencyContacts
          ? FloatingActionButton(
              onPressed: _addContact,
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.person_add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.textHint, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

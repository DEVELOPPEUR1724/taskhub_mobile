import 'package:flutter/material.dart';

import '../../models/project.dart';
import '../../services/chat_service.dart';

const _adaiOrange = Color(0xFFE57A44);

final _chatServiceForCreation = ChatService();

class CreateConversationScreen extends StatefulWidget {
  const CreateConversationScreen({super.key});

  @override
  State<CreateConversationScreen> createState() => _CreateConversationScreenState();
}

class _CreateConversationScreenState extends State<CreateConversationScreen> {
  final _nameController = TextEditingController();

  String _type = 'channel';

  List<ProjectMember> _users = [];
  bool _isLoadingUsers = true;
  String? _usersError;
  final Set<int> _selectedMemberIds = {};

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoadingUsers = true;
      _usersError = null;
    });
    try {
      final users = await _chatServiceForCreation.getUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoadingUsers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingUsers = false;
        _usersError = 'Erreur lors du chargement des collègues';
      });
    }
  }

  void _toggleMember(int memberId) {
    setState(() {
      if (_type == 'direct') {
        // Discussion privée : un seul interlocuteur possible.
        _selectedMemberIds
          ..clear()
          ..add(memberId);
      } else if (_selectedMemberIds.contains(memberId)) {
        _selectedMemberIds.remove(memberId);
      } else {
        _selectedMemberIds.add(memberId);
      }
    });
  }

  bool get _canSubmit {
    if (_selectedMemberIds.isEmpty) return false;
    if (_type == 'channel' && _nameController.text.trim().isEmpty) return false;
    return true;
  }

  Future<void> _submit() async {
    if (!_canSubmit || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      if (_type == 'channel') {
        await _chatServiceForCreation.createGroup(
          name: _nameController.text.trim(),
          memberIds: _selectedMemberIds.toList(),
        );
      } else {
        await _chatServiceForCreation.createDirect(_selectedMemberIds.first);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFFF453A),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle conversation', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Type',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _TypeOption(
                          label: 'Groupe',
                          icon: Icons.groups_outlined,
                          selected: _type == 'channel',
                          onTap: () => setState(() {
                            _type = 'channel';
                            _selectedMemberIds.clear();
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TypeOption(
                          label: 'Discussion privée',
                          icon: Icons.person_outline,
                          selected: _type == 'direct',
                          onTap: () => setState(() {
                            _type = 'direct';
                            if (_selectedMemberIds.length > 1) {
                              final first = _selectedMemberIds.first;
                              _selectedMemberIds
                                ..clear()
                                ..add(first);
                            }
                          }),
                        ),
                      ),
                    ],
                  ),
                  if (_type == 'channel') ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Nom du groupe',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Ex : Mobile App',
                        filled: true,
                        fillColor: colors.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    _type == 'channel' ? 'Participants' : 'Choisir un collègue',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  _buildUsersList(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _canSubmit && !_isSubmitting ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _adaiOrange,
                    disabledBackgroundColor: colors.outlineVariant,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Créer',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersList() {
    final colors = Theme.of(context).colorScheme;
    if (_isLoadingUsers) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_usersError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_usersError!, style: TextStyle(color: colors.onSurfaceVariant)),
          TextButton(onPressed: _loadUsers, child: const Text('Réessayer')),
        ],
      );
    }
    if (_users.isEmpty) {
      return Text('Aucun collègue disponible', style: TextStyle(color: colors.onSurfaceVariant));
    }
    return Column(
      children: _users.map((user) {
        final selected = _selectedMemberIds.contains(user.id);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: selected ? _adaiOrange.withOpacity(0.08) : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? _adaiOrange : Colors.transparent),
          ),
          child: ListTile(
            onTap: () => _toggleMember(user.id),
            leading: CircleAvatar(
              backgroundImage: NetworkImage('https://i.pravatar.cc/100?u=${user.id}'),
            ),
            title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: user.role != null ? Text(user.role!) : null,
            trailing: Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? _adaiOrange : colors.onSurfaceVariant,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TypeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? _adaiOrange.withOpacity(0.08) : colors.surface,
          border: Border.all(color: selected ? _adaiOrange : colors.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: selected ? _adaiOrange : colors.onSurface),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? _adaiOrange : colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

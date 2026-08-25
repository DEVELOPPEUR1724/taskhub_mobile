import 'package:flutter/material.dart';

import '../../models/profile.dart';
import '../../services/profil_service.dart';
import '../../services/auth_service.dart';
import '../../theme/theme_controller.dart';
import '../flow1/login_screen.dart';
import 'editProfil_screen.dart';
import 'security_screen.dart';

final _profilService = ProfilService();
final _authService = AuthService();

const _adaiOrange = Color(0xFFE57A44);

class ProfilUserScreen extends StatefulWidget {
  const ProfilUserScreen({super.key});

  @override
  State<ProfilUserScreen> createState() => _ProfilUserScreenState();
}

class _ProfilUserScreenState extends State<ProfilUserScreen> {
  Profile? _profile;
  bool _isLoading = true;
  String? _errorMessage;
  bool _pushNotificationsEnabled = true;
  final String _language = 'Français'; // préférence locale, pas dans l'API

  @override
  void initState() {
    super.initState();
    _loadProfil();
  }

  Future<void> _loadProfil() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final profile = await _profilService.getProfil();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement du profil';
      });
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se déconnecter'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _authService.logout();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF453A)),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        TextButton(onPressed: _loadProfil, child: const Text('Réessayer')),
                      ],
                    ),
                  ),
                )
              : _buildContent(_profile!),
    );
  }

  Widget _buildContent(Profile profile) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mon profil',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              const CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(
                  'https://dashboard-wally-process-interne.adaiexpertise.fr/logo_sans_fond.png',
                ),
                backgroundColor: Colors.transparent,
              ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundImage: NetworkImage('https://i.pravatar.cc/200?u=${profile.id}'),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile.role,
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF0DE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_none, color: _adaiOrange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications push',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: colors.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Recevoir les notifications sur votre appareil',
                        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _pushNotificationsEnabled,
                  activeColor: _adaiOrange,
                  onChanged: (value) => setState(() => _pushNotificationsEnabled = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          ListenableBuilder(
            listenable: themeController,
            builder: (context, _) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.outlineVariant),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF0DE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.dark_mode_outlined, color: _adaiOrange, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mode sombre',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: colors.onSurface),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Basculer vers un thème sombre',
                            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: themeController.isDarkMode,
                      activeColor: _adaiOrange,
                      onChanged: themeController.setDarkMode,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          Text(
            'Mon compte',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.onSurface),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _AccountRow(
                  icon: Icons.person_outline,
                  label: 'Informations personnelles',
                  onTap: () async {
                    final updated = await Navigator.of(context).push<Profile>(
                      MaterialPageRoute(builder: (context) => EditProfilScreen(profile: profile)),
                    );
                    if (updated != null) setState(() => _profile = updated);
                  },
                ),
                Divider(height: 1, color: colors.outlineVariant),
                _AccountRow(
                  icon: Icons.verified_user_outlined,
                  label: 'Sécurité',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const SecurityScreen()),
                    );
                  },
                ),
                Divider(height: 1, color: colors.outlineVariant),
                _AccountRow(
                  icon: Icons.language_outlined,
                  label: 'Langue',
                  trailingText: _language,
                  onTap: () {
                    // TODO: afficher le sélecteur de langue
                  },
                ),
                Divider(height: 1, color: colors.outlineVariant),
                _AccountRow(
                  icon: Icons.info_outline,
                  label: 'À propos',
                  onTap: () {
                    // TODO: naviguer vers l'écran à propos
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Color(0xFFFF453A), size: 18),
              label: const Text(
                'Se déconnecter',
                style: TextStyle(color: Color(0xFFFF453A), fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFF453A)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Vous serez déconnecté et votre session sera révoquée sur tous vos appareils.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailingText;
  final VoidCallback onTap;

  const _AccountRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colors.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 14, color: colors.onSurface),
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText!,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(width: 6),
            ],
            Icon(Icons.chevron_right, size: 18, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

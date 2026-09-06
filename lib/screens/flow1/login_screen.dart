import 'dart:async';

import 'package:flutter/material.dart';

import './loading_screen.dart';
import '../../services/auth_service.dart';
import '../../services/push_service.dart';

final authService = AuthService();

const _adaiOrange = Color(0xFFE57A44);
const _adaiBrown = Color(0xFF3E2B1F);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
 
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
    final result =
      await authService.login(
        _emailController.text,
        _passwordController.text,
      );
    print(result.message);
    print(result.user.name);
    print(result.user.role);
    print(result.token);

    // Non bloquant : registerDevice() avale déjà ses propres erreurs (voir
    // PushService), la connexion ne doit pas échouer si le push échoue.
    unawaited(PushService.instance.registerDevice());

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const LoadingScreen(),
      ),
    );
    
  } catch(e){
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: const Color(0xFFFF453A),
      ),
    );
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
  }

  void _handleBiometricLogin() {
    // TODO: brancher la connexion biométrique
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                
                key: _formKey,
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.network(
                    'https://dashboard-wally-process-interne.adaiexpertise.fr/logo_sans_fond.png',
                    height: 110,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(height: 110),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ADAI',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: colors.brightness == Brightness.dark ? Colors.white : _adaiBrown,
                    ),
                  ),
                  const Text(
                    'TASKHUB',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 4,
                      color: _adaiOrange,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Bienvenue',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Connectez-vous à votre espace\nde pilotage',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
                  ),
                  const SizedBox(height: 28),

                  TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'votre@email.com',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'L\'email est requis';
                    }
                    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Email invalide';
                    }
                    return null;
                  },
                ),
                  const SizedBox(height: 18),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Votre mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Le mot de passe est requis';
                    }
                    if (value.length < 6) {
                      return 'Minimum 6 caractères';
                    }
                    return null;
                  },
                ),

                  // _FieldLabel('Mot de passe'),
                  // const SizedBox(height: 6),
                  // TextField(
                  //   controller: _passwordController,
                  //   obscureText: _obscurePassword,
                  //   decoration: InputDecoration(
                  //     hintText: 'Votre mot de passe',
                  //     prefixIcon: const Icon(Icons.lock_outline),
                  //     suffixIcon: IconButton(
                  //       icon: Icon(
                  //         _obscurePassword
                  //             ? Icons.visibility_off_outlined
                  //             : Icons.visibility_outlined,
                  //       ),
                  //       onPressed: () {
                  //         setState(() => _obscurePassword = !_obscurePassword);
                  //       },
                  //     ),
                  //   ),
                  // ),
                  const SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(foregroundColor: _adaiOrange),
                      child: const Text('Mot de passe oublié ?'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _adaiOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Se connecter',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(child: Divider(color: colors.outlineVariant)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('ou', style: TextStyle(color: colors.onSurfaceVariant)),
                      ),
                      Expanded(child: Divider(color: colors.outlineVariant)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _handleBiometricLogin,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Se connecter avec biométrie'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.onSurface,
                        side: BorderSide(color: colors.outlineVariant),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, size: 16, color: colors.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        'Accès réservé aux utilisateurs invités',
                        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// class _FieldLabel extends StatelessWidget {
//   final String text;
//   const _FieldLabel(this.text);

//   @override
//   Widget build(BuildContext context) {
//     return Align(
//       alignment: Alignment.centerLeft,
//       child: Text(
//         text,
//         style: const TextStyle(
//           fontWeight: FontWeight.w600,
//           fontSize: 13,
//           color: Colors.black87,
//         ),
//       ),
//     );
//   }
// }

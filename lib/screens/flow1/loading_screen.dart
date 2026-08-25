import 'package:flutter/material.dart';

import '../../widgets/main_scaffold.dart';
import './error_screen.dart';



const _adaiOrange = Color(0xFFE57A44);
const _adaiBrown = Color(0xFF3E2B1F);

class LoadingScreen  extends StatefulWidget {
  const LoadingScreen ({super.key});

  @override
  State<LoadingScreen > createState() => _LoadingScreen();
}

class _LoadingScreen  extends State<LoadingScreen > {
  @override
  void initState() {
    super.initState();
    _prepareWorkspace();
  }

    Future<void> _prepareWorkspace() async {
      // TODO: remplacer par la vraie vérification (token stocké, appel API, etc.)
      await Future.delayed(const Duration(seconds: 5));
      final bool isLoggedIn = true; // TODO: résultat réel de la vérification
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) =>
              isLoggedIn ? const MainScaffold() : const ErrorScreen(),
        ),
      );
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
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
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : _adaiBrown,
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
              const SizedBox(height: 32),
              const CircularProgressIndicator(color: _adaiOrange),
              const SizedBox(height: 16),
              Text(
                'Vérification de votre session',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


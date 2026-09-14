import 'package:flutter/material.dart';

import 'assistant_launcher_button.dart';
import '../screens/flow2/tasklist_screen.dart';
import '../screens/flow3/conversationList_screen.dart';
import '../screens/flow4/profilUser_screen.dart';
import '../screens/flow4/resumeIA_screen.dart';
import '../screens/flow5/projetList_screen.dart';
import '../screens/flow6/pointage_screen.dart';

const _adaiOrange = Color(0xFFE57A44);

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  static const _pages = [
    ResumeIAScreen(),
    ProjetListScreen(),
    TaskListScreen(),
    ConversationListScreen(), // TODO: ChatScreen réel
    PointageScreen(),
    ProfilUserScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
            // Bouton flottant persistant sur tous les onglets, équivalent du
            // lanceur de chat IA en bas à droite du dashboard web.
            const Positioned(
              bottom: 16,
              right: 16,
              child: AssistantLauncherButton(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _adaiOrange,
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome_outlined),
            label: 'Avancement',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            label: 'Projets',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            label: 'Tâches',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time_outlined),
            label: 'Pointage',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

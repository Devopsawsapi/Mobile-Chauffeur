import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../dashboard/dashboard_page.dart';
import '../trips/trip_creation_page.dart';
import '../chat/chat_page.dart';
import '../map/map_page.dart';
import '../profile/profile_page.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});
  @override State<MainDashboard> createState() => _MainState();
}

class _MainState extends State<MainDashboard> {
  int _idx = 0;

  void _goTo(int index) => setState(() => _idx = index);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    body: IndexedStack(index: _idx, children: [
      DashboardPage(
        onNewTrip: () => _goTo(1), // ✅ Nouveau trajet → onglet index 1
        onHistory: () => _goTo(1), // ✅ ou navigation directe
      ),
      const TripCreationPage(),
      const ChatPage(),
      const MapPage(),
      const ProfilePage(),
    ]),
    bottomNavigationBar: Container(
      decoration: BoxDecoration(
        color: C.card,
        border: Border(top: BorderSide(color: C.border)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)]),
      child: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        backgroundColor: Colors.transparent, elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: C.orange, unselectedItemColor: C.muted,
        selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded),          label: 'Tableau'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline_rounded),  label: 'Trajet'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline_rounded), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined),                label: 'GPS'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded),      label: 'Profil'),
        ],
      ),
    ),
  );
}
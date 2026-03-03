import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../widgets/tt_logo.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override State<AuthScreen> createState() => _AuthState();
}

class _AuthState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); }
  @override void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Column(children: [
        const SizedBox(height: 8),
        const TTIconLogo(size: 52, glow: true),
        const SizedBox(height: 16),
        Container(height: 52,
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14)),
          child: TabBar(
            controller: _tab,
            indicator: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFF5A623), Color(0xFFE8921A)]),
              borderRadius: BorderRadius.circular(12)),
            dividerColor: Colors.transparent,
            padding: const EdgeInsets.all(4),
            labelColor: Colors.white, unselectedLabelColor: C.muted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            tabs: const [Tab(text: 'Inscription'), Tab(text: 'Connexion')])),
      ])),
      Expanded(child: TabBarView(
        controller: _tab,
        children: const [RegisterScreen(), LoginScreen()])),
    ])),
  );
}

import 'package:flutter/material.dart';
import '../core/constants/colors.dart';
import '../core/services/api_service.dart';
import '../core/constants/api_endpoints.dart';
import '../core/models/driver_model.dart';
import '../widgets/tt_logo.dart';
import 'auth/auth_screen.dart';
import 'dashboard/main_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashState();
}

class _SplashState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _scale, _fade;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _scale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0, 0.7, curve: Curves.elasticOut)));
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0, 0.5)));
    _c.forward();
    _checkAuth();
  }

  @override void dispose() { _c.dispose(); super.dispose(); }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));
    final token = await ApiService.getToken();
    if (!mounted) return;
    if (token != null) {
      final res = await ApiService.get(Api.me);
      if (res['success'] == true && mounted) {
        currentDriver = DriverModel.fromJson(res);
        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const MainDashboard()));
        return;
      }
      await ApiService.clearToken();
    }
    if (mounted) Navigator.pushReplacement(context,
      MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    body: Container(
      decoration: BoxDecoration(gradient: RadialGradient(
        center: Alignment.center, radius: 1.2,
        colors: [C.orange.withOpacity(0.08), C.bg, C.bg])),
      child: Center(child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Column(
          mainAxisAlignment: MainAxisAlignment.center, children: [
          Opacity(opacity: _fade.value,
            child: Transform.scale(scale: _scale.value,
              child: const TTIconLogo(size: 120, glow: true))),
          const SizedBox(height: 28),
          Opacity(opacity: _fade.value, child: const TTTextLogo(fontSize: 42)),
          const SizedBox(height: 8),
          Opacity(opacity: _fade.value,
            child: const Text('ESPACE CONDUCTEUR',
              style: TextStyle(color: C.muted, fontSize: 11, letterSpacing: 4, fontWeight: FontWeight.w600))),
          const SizedBox(height: 60),
          Opacity(opacity: _fade.value,
            child: const SizedBox(width: 28, height: 28,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(C.orange), strokeWidth: 2.5))),
        ]))),
    ),
  );
}

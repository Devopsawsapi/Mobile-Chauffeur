import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/models/driver_model.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/tt_logo.dart';
import '../../widgets/app_widgets.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override State<MapPage> createState() => _MapState();
}

class _MapState extends State<MapPage> {
  bool _started = false; String? _tripId;
  List<dynamic> _trips = []; bool _loadingTrips = true;

  @override void initState() { super.initState(); _loadTrips(); }

  Future<void> _loadTrips() async {
    setState(() => _loadingTrips = true);
    final res = await ApiService.get(Api.trips);
    setState(() {
      _loadingTrips = false;
      if (res['success'] == true) {
        _trips = res['data'] ?? [];
        final active = _trips.where((t) => t['status'] == 'in_progress').toList();
        if (active.isNotEmpty) {
          _tripId = active.first['id'].toString();
          _started = true;
        }
      }
    });
  }

  Future<void> _toggleTrip() async {
    if (_started && _tripId != null) {
      final res = await ApiService.post('${Api.trips}/$_tripId/end', {});
      if (res['success'] == true) setState(() { _started = false; _tripId = null; });
      else if (mounted) snack(context, res['message'] ?? 'Erreur', error: true);
    } else {
      setState(() => _started = true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: AppBar(backgroundColor: C.card, elevation: 0,
      title: Row(children: [
        const TTIconLogo(size: 34, glow: false), const SizedBox(width: 10),
        const TTTextLogo(fontSize: 18), const SizedBox(width: 8),
        const Text('· Navigation GPS', style: TextStyle(color: C.muted, fontSize: 13))]),
      actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded, color: C.orange), onPressed: _loadTrips)
      ],
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: C.border))),
    body: Stack(children: [
      Container(
        decoration: const BoxDecoration(gradient: LinearGradient(
          colors: [Color(0xFF0B1824), Color(0xFF162233), Color(0xFF0D1F30)],
          begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: CustomPaint(painter: _MapPainter(), child: const SizedBox.expand())),
      Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 64, height: 64,
          decoration: BoxDecoration(color: C.orange.withOpacity(0.2), shape: BoxShape.circle,
            border: Border.all(color: C.orange, width: 2),
            boxShadow: [BoxShadow(color: C.orange.withOpacity(0.5), blurRadius: 20)]),
          child: const Icon(Icons.my_location_rounded, color: C.orange, size: 32)),
        const SizedBox(height: 10),
        Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: C.card.withOpacity(0.9), borderRadius: BorderRadius.circular(12)),
          child: Text(currentDriver.city ?? 'Position actuelle',
            style: const TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 13))),
      ])),
      Positioned(bottom: 0, left: 0, right: 0,
        child: Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: C.card,
            border: Border(top: BorderSide(color: C.border)),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
          child: OBtn(
            text: _started ? 'TERMINER LE TRAJET' : 'DÉMARRER LE TRAJET',
            icon: _started ? Icons.flag_rounded : Icons.navigation_rounded,
            colors: _started
              ? [C.error, const Color(0xFFCC1A1A)]
              : [C.orange, const Color(0xFFE8921A)],
            onTap: _toggleTrip))),
    ]));
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final g = Paint()..color = C.orange.withOpacity(0.05)..strokeWidth = 1;
    for (double x = 0; x < s.width;  x += 28) canvas.drawLine(Offset(x, 0), Offset(x, s.height), g);
    for (double y = 0; y < s.height; y += 28) canvas.drawLine(Offset(0, y), Offset(s.width, y), g);
    final r = Paint()..color = C.orange.withOpacity(0.2)..strokeWidth = 4..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, s.height * 0.38), Offset(s.width, s.height * 0.52), r);
  }
  @override bool shouldRepaint(covariant CustomPainter o) => false;
}

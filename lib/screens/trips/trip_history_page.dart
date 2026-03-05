import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/tt_logo.dart';
import 'driver_bookings_page.dart';

class TripHistoryPage extends StatefulWidget {
  const TripHistoryPage({super.key});
  @override State<TripHistoryPage> createState() => _THState();
}

class _THState extends State<TripHistoryPage> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<dynamic> _trips = [];
  bool _loading = true;

  @override void initState() { super.initState(); _tab = TabController(length: 4, vsync: this); _load(); }
  @override void dispose()   { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get(Api.trips);
    if (mounted) setState(() {
      _loading = false;
      _trips   = res['data'] is List ? res['data'] : [];
    });
  }

  List<dynamic> get _filtered {
    switch (_tab.index) {
      case 1: return _trips.where((t) => t['status'] == 'in_progress').toList();
      case 2: return _trips.where((t) => t['status'] == 'completed').toList();
      case 3: return _trips.where((t) => ['cancelled','rejected'].contains(t['status'])).toList();
      default: return _trips;
    }
  }

  // FIX: démarrage avec logique places + démarrage manuel
  Future<void> _startTrip(Map t) async {
    final tripId        = t['id'];
    final confirmedSeats = (t['confirmed_seats'] ?? 0) as int;
    final totalSeats     = (t['total_seats']     ?? t['available_seats'] ?? 0) as int;
    final allFull        = totalSeats > 0 && confirmedSeats >= totalSeats;

    if (!allFull) {
      // Proposer démarrage manuel
      final choice = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: C.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.warning_amber_rounded, color: C.orange, size: 22),
            SizedBox(width: 8),
            Text('Places non complètes', style: TextStyle(color: C.text, fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          content: Text(
            '$confirmedSeats/$totalSeats places confirmées.\n\nDémarrer quand même ?',
            style: const TextStyle(color: C.muted, height: 1.5)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Annuler', style: TextStyle(color: C.muted))),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'force'),
              style: ElevatedButton.styleFrom(backgroundColor: C.orange),
              child: const Text('Démarrer quand même', style: TextStyle(color: Colors.white))),
          ]));
      if (choice != 'force') return;
      // Démarrage forcé
      final res = await ApiService.post(Api.tripStart(tripId), {'force': true});
      if (!mounted) return;
      snack(context, res['success'] == true ? '🚗 Trajet démarré !' : res['message'] ?? 'Erreur',
        error: res['success'] != true);
      if (res['success'] == true) _load();
    } else {
      // Toutes les places confirmées — démarrage normal
      final ok = await _confirmDialog('Démarrer le trajet ?', 'Toutes les places sont confirmées.');
      if (!ok) return;
      final res = await ApiService.post(Api.tripStart(tripId), {});
      if (!mounted) return;
      snack(context, res['success'] == true ? '🚗 Trajet démarré !' : res['message'] ?? 'Erreur',
        error: res['success'] != true);
      if (res['success'] == true) _load();
    }
  }

  Future<void> _endTrip(dynamic tripId) async {
    final ok = await _confirmDialog('Terminer le trajet ?', 'Le statut passera à "Terminé".');
    if (!ok) return;
    final res = await ApiService.post(Api.tripEnd(tripId), {});
    if (!mounted) return;
    snack(context, res['success'] == true ? '🏁 Trajet terminé !' : res['message'] ?? 'Erreur',
      error: res['success'] != true);
    if (res['success'] == true) _load();
  }

  Future<bool> _confirmDialog(String title, String subtitle) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: C.text, fontWeight: FontWeight.w700)),
        content: Text(subtitle, style: const TextStyle(color: C.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: C.muted))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: C.orange),
            child: const Text('Confirmer', style: TextStyle(color: Colors.white))),
        ])) ?? false;

  Color  _statusColor(String s) {
    switch (s) {
      case 'in_progress': return Colors.blue;
      case 'completed':   return Colors.green;
      case 'cancelled': case 'rejected': return C.error;
      default: return C.orange;
    }
  }
  String _statusLabel(String s) {
    switch (s) {
      case 'pending':     return 'En attente';
      case 'in_progress': return 'En cours';
      case 'completed':   return 'Terminé';
      case 'cancelled':   return 'Annulé';
      case 'rejected':    return 'Rejeté';
      default:            return s;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: AppBar(
      backgroundColor: C.card, elevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: C.text),
        onPressed: () => Navigator.pop(context)),
      title: Row(children: [
        const TTIconLogo(size: 28, glow: false), const SizedBox(width: 8),
        const Text('Mes trajets', style: TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 16)),
      ]),
      actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded, color: C.muted, size: 20), onPressed: _load),
        IconButton(icon: const Icon(Icons.people_rounded, color: C.blue, size: 22),
          tooltip: 'Toutes les réservations',
          onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const DriverBookingsPage())).then((_) => _load())),
      ],
      bottom: PreferredSize(preferredSize: const Size.fromHeight(49),
        child: Column(children: [
          Container(height: 1, color: C.border),
          TabBar(
            controller: _tab,
            onTap: (_) => setState(() {}),
            isScrollable: true,
            indicator: const UnderlineTabIndicator(
              borderSide: BorderSide(color: C.orange, width: 2)),
            labelColor: C.orange, unselectedLabelColor: C.muted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            tabs: const [Tab(text: '🗂 Tous'), Tab(text: '🚗 Actifs'), Tab(text: '🏁 Terminés'), Tab(text: '❌ Annulés')]),
        ]))),
    body: _loading
      ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(C.orange)))
      : RefreshIndicator(
          onRefresh: _load, color: C.orange,
          child: _filtered.isEmpty
            ? ListView(children: const [
                SizedBox(height: 80),
                Center(child: Column(children: [
                  Icon(Icons.directions_car_outlined, color: C.muted, size: 56),
                  SizedBox(height: 12),
                  Text('Aucun trajet', style: TextStyle(color: C.muted, fontSize: 14)),
                ])),
              ])
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filtered.length,
                itemBuilder: (_, i) => _tripCard(_filtered[i]))));

  Widget _tripCard(Map t) {
    final status    = (t['status'] ?? 'pending').toString();
    final departure = t['departure'] ?? t['pickup_address'] ?? '';
    final dest      = t['destination'] ?? t['dropoff_address'] ?? '';
    final date      = (t['departure_date'] ?? '').toString();
    final time      = (t['departure_time'] ?? '').toString();
    final price     = (t['price_per_seat'] ?? t['amount'] ?? 0);
    final seats     = t['available_seats'] ?? 0;
    final confirmed = t['confirmed_seats'] ?? 0;
    final total     = t['total_seats'] ?? seats;
    final lugKg     = t['luggage_weight_kg'] ?? 20;
    final lugIncl   = t['luggage_included'] ?? 1;
    final extraFee  = t['extra_luggage_fee'] ?? 0;
    final extraSlots= t['extra_luggage_slots'] ?? 0;
    final vType     = t['vehicle_type'] ?? '';
    final bookCnt   = t['bookings_count'] ?? 0;
    final tripId    = t['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header statut + date ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _statusColor(status).withOpacity(0.07),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(status).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8)),
              child: Text(_statusLabel(status),
                style: TextStyle(color: _statusColor(status), fontSize: 12, fontWeight: FontWeight.w700))),
            const Spacer(),
            const Icon(Icons.calendar_today_outlined, color: C.muted, size: 12),
            const SizedBox(width: 4),
            Text('$date${time.isNotEmpty ? "  $time" : ""}',
              style: const TextStyle(color: C.muted, fontSize: 12)),
          ])),

        Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Itinéraire ──────────────────────────────────────────────
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              const Icon(Icons.my_location_rounded, color: C.blue, size: 16),
              Container(width: 1, height: 22, color: C.border.withOpacity(0.5)),
              const Icon(Icons.location_on_rounded, color: C.orange, size: 16),
            ]),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(departure, style: const TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 10),
              Text(dest, style: const TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 14)),
            ])),
          ]),

          const SizedBox(height: 12),
          const Divider(height: 1, color: C.border),
          const SizedBox(height: 12),

          // ── Prix + Places confirmées ────────────────────────────────
          Row(children: [
            // Prix
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: C.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.attach_money_rounded, color: C.orange, size: 14),
                Text('${(price as num).toStringAsFixed(0)} FCFA',
                  style: const TextStyle(color: C.orange, fontWeight: FontWeight.w800, fontSize: 13)),
              ])),
            const SizedBox(width: 10),
            // Places: confirmés/total
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (confirmed >= total && total > 0)
                  ? Colors.green.withOpacity(0.1) : C.surface,
                borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Icon(Icons.people_outline_rounded,
                  color: (confirmed >= total && total > 0) ? Colors.green : C.muted, size: 14),
                const SizedBox(width: 4),
                Text('$confirmed/$total places',
                  style: TextStyle(
                    color: (confirmed >= total && total > 0) ? Colors.green : C.muted,
                    fontSize: 12, fontWeight: FontWeight.w600)),
              ])),
            if (vType.isNotEmpty) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.directions_car, color: C.muted, size: 13),
                  const SizedBox(width: 4),
                  Text(vType, style: const TextStyle(color: C.muted, fontSize: 11)),
                ])),
            ],
          ]),

          // FIX: Bagages complets ─────────────────────────────────────
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: C.surface, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: C.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.luggage, color: C.muted, size: 14),
                const SizedBox(width: 6),
                Text('$lugIncl bagage(s) inclus · ${lugKg}kg max',
                  style: const TextStyle(color: C.muted, fontSize: 12)),
              ]),
              if ((extraFee as num) > 0 || (extraSlots as int) > 0) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.add_box_outlined, color: C.orange, size: 13),
                  const SizedBox(width: 6),
                  Text(
                    '${extraSlots > 0 ? "$extraSlots place(s) excédent · " : ""}'
                    '${(extraFee as num) > 0 ? "+${(extraFee as num).toStringAsFixed(0)} FCFA/kg" : ""}',
                    style: const TextStyle(color: C.orange, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ],
            ])),

          // ── Réservations résumé ─────────────────────────────────────
          if ((bookCnt as int) > 0) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => DriverBookingsPage(
                  tripId: tripId,
                  totalSeats: total is int ? total : int.tryParse('$total') ?? 0,
                ))).then((_) => _load()),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: C.border)),
                child: Row(children: [
                  const Icon(Icons.people_rounded, color: C.blue, size: 16),
                  const SizedBox(width: 8),
                  Text('$bookCnt réservation(s)',
                    style: const TextStyle(color: C.text, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  if ((confirmed as int) > 0)
                    Text('· $confirmed confirmée(s)',
                      style: const TextStyle(color: Colors.green, fontSize: 12)),
                  const Spacer(),
                  const Text('Gérer', style: TextStyle(color: C.blue, fontSize: 12, fontWeight: FontWeight.w700)),
                  const Icon(Icons.chevron_right, color: C.blue, size: 16),
                ]))),
          ],

          // ── Boutons démarrer / terminer ─────────────────────────────
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _startTrip(Map<String, dynamic>.from(t)),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text((confirmed >= total && total > 0)
                  ? '▶ Démarrer le trajet'
                  : '▶ Démarrer ($confirmed/$total places)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (confirmed >= total && total > 0) ? Colors.green : C.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0))),
          ],
          if (status == 'in_progress') ...[
            const SizedBox(height: 12),
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _endTrip(tripId),
                icon: const Icon(Icons.flag_rounded, size: 18),
                label: const Text('🏁 Terminer le trajet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.blue, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0))),
          ],
        ])),
      ]));
  }
}

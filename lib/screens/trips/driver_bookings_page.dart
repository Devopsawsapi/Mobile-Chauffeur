import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/tt_logo.dart';

class DriverBookingsPage extends StatefulWidget {
  final dynamic tripId;
  final int totalSeats;
  final int availableSeats;
  const DriverBookingsPage({super.key, this.tripId, this.totalSeats = 0, this.availableSeats = 0});
  @override State<DriverBookingsPage> createState() => _DriverBookingsPageState();
}

class _DriverBookingsPageState extends State<DriverBookingsPage> {
  List<dynamic> _bookings = [];
  bool _loading = true;
  final Map<dynamic, bool> _actionLoading = {};
  int _confirmedCount = 0;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get(Api.bookings);
    if (mounted) {
      List<dynamic> all = res['data'] is List ? res['data']
          : res['bookings'] is List ? res['bookings']
          : res is List ? res as List : [];
      if (widget.tripId != null) {
        all = all.where((b) => b['trip_id'].toString() == widget.tripId.toString()).toList();
      }
      final confirmed = all.where((b) =>
        ['confirmed','paid'].contains((b['status'] ?? '').toString().toLowerCase())).length;
      setState(() { _bookings = all; _confirmedCount = confirmed; _loading = false; });
    }
  }

  Future<void> _confirm(dynamic bookingId) async {
    setState(() => _actionLoading[bookingId] = true);
    final res = await ApiService.post(Api.bookingConfirm(bookingId), {});
    if (!mounted) return;
    setState(() => _actionLoading.remove(bookingId));
    snack(context,
      res['success'] == true ? '✅ Réservation confirmée !' : res['message'] ?? 'Erreur',
      error: res['success'] != true);
    if (res['success'] == true) _load();
  }

  Future<void> _reject(dynamic bookingId) async {
    final reason = await _reasonDialog();
    if (reason == null) return;
    setState(() => _actionLoading[bookingId] = true);
    final res = await ApiService.post(Api.bookingReject(bookingId), {'reason': reason});
    if (!mounted) return;
    setState(() => _actionLoading.remove(bookingId));
    snack(context,
      res['success'] == true ? '✅ Réservation rejetée' : res['message'] ?? 'Erreur',
      error: res['success'] != true);
    if (res['success'] == true) _load();
  }

  Future<String?> _reasonDialog() => showDialog<String>(
    context: context,
    builder: (_) {
      final ctrl = TextEditingController();
      return AlertDialog(
        backgroundColor: C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Motif du refus', style: TextStyle(color: C.text, fontWeight: FontWeight.w700)),
        content: TextField(controller: ctrl,
          style: const TextStyle(color: C.text),
          decoration: const InputDecoration(hintText: 'Ex: Trajet annulé', hintStyle: TextStyle(color: C.muted))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: C.muted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim().isEmpty ? 'Non précisé' : ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: C.error),
            child: const Text('Confirmer')),
        ]);
    });

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'confirmed': case 'paid': return Colors.green;
      case 'pending':   return C.orange;
      case 'rejected':  case 'cancelled': return C.error;
      default: return C.muted;
    }
  }

  String _statusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'confirmed': return 'Confirmé';
      case 'paid':      return 'Payé';
      case 'pending':   return 'En attente';
      case 'rejected':  return 'Refusé';
      case 'cancelled': return 'Annulé';
      case 'completed': return 'Terminé';
      default:          return s;
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
        const Text('Réservations', style: TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 16)),
      ]),
      actions: [
        // FIX: compteur confirmés / total
        if (widget.totalSeats > 0)
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _confirmedCount >= widget.totalSeats
                ? Colors.green.withOpacity(0.15)
                : C.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20)),
            child: Text('$_confirmedCount/${widget.totalSeats} places',
              style: TextStyle(
                color: _confirmedCount >= widget.totalSeats ? Colors.green : C.orange,
                fontSize: 12, fontWeight: FontWeight.w700))),
        IconButton(icon: const Icon(Icons.refresh_rounded, color: C.muted, size: 20), onPressed: _load),
      ],
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: C.border))),
    body: _loading
      ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(C.orange)))
      : _bookings.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.people_outline_rounded, color: C.muted.withOpacity(0.4), size: 64),
            const SizedBox(height: 14),
            const Text('Aucune réservation', style: TextStyle(color: C.text, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Les réservations des clients\napparaîtront ici',
              style: TextStyle(color: C.muted, fontSize: 13), textAlign: TextAlign.center),
          ]))
        : RefreshIndicator(
            onRefresh: _load, color: C.orange,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _bookings.length,
              itemBuilder: (_, i) {
                final b       = _bookings[i];
                final status  = (b['status'] ?? 'pending').toString();
                final isPending = status.toLowerCase() == 'pending';
                final client  = b['client'] ?? {};
                final name    = client['name'] ?? b['client_name'] ?? b['user_name'] ?? 'Client';
                final phone   = client['phone'] ?? b['client_phone'] ?? '';
                final photo   = client['profile_photo']?.toString() ?? '';
                final seats   = b['seats'] ?? b['passengers'] ?? 1;
                final amount  = double.tryParse((b['amount'] ?? '0').toString()) ?? 0;
                final ini     = name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
                final isLoading = _actionLoading[b['id']] == true;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: C.card, borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isPending ? C.orange.withOpacity(0.5) : C.border,
                      width: isPending ? 1.5 : 1)),
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        // Photo client
                        Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(shape: BoxShape.circle,
                            border: Border.all(color: C.orange, width: 1.5)),
                          child: ClipOval(
                            child: photo.isNotEmpty
                              ? Image.network(photo, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _ini(ini))
                              : _ini(ini))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: const TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 14)),
                          if (phone.isNotEmpty)
                            Text(phone, style: const TextStyle(color: C.muted, fontSize: 12)),
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.people_outline, color: C.muted, size: 14),
                            const SizedBox(width: 4),
                            Text('$seats place${seats > 1 ? "s" : ""}',
                              style: const TextStyle(color: C.muted, fontSize: 12)),
                            const SizedBox(width: 12),
                            if (amount > 0) ...[
                              const Icon(Icons.attach_money, color: C.orange, size: 14),
                              Text('${amount.toStringAsFixed(0)} FCFA',
                                style: const TextStyle(color: C.orange, fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ]),
                        ])),
                        // Badge statut
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20)),
                          child: Text(_statusLabel(status),
                            style: TextStyle(color: _statusColor(status),
                              fontSize: 11, fontWeight: FontWeight.w700))),
                      ])),

                    // FIX: boutons confirmer / rejeter SEULEMENT si en attente
                    if (isPending) ...[
                      const Divider(height: 1, color: C.border),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: isLoading
                          ? const Center(child: SizedBox(width: 24, height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: C.orange)))
                          : Row(children: [
                              Expanded(child: GestureDetector(
                                onTap: () => _reject(b['id']),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: C.error.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: C.error.withOpacity(0.3))),
                                  child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.close_rounded, color: C.error, size: 16),
                                    SizedBox(width: 6),
                                    Text('Refuser', style: TextStyle(color: C.error, fontWeight: FontWeight.w700)),
                                  ]))))),
                              const SizedBox(width: 10),
                              Expanded(child: GestureDetector(
                                onTap: () => _confirm(b['id']),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.green.withOpacity(0.3))),
                                  child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.check_rounded, color: Colors.green, size: 16),
                                    SizedBox(width: 6),
                                    Text('Confirmer', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700)),
                                  ]))))),
                            ])),
                    ],
                  ]));
              })));

  Widget _ini(String ini) => Container(
    color: C.orange.withOpacity(0.15),
    child: Center(child: Text(ini.isNotEmpty ? ini : 'CL',
      style: const TextStyle(color: C.orange, fontWeight: FontWeight.w800, fontSize: 14))));
}

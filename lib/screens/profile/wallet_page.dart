import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_data.dart';
import '../../core/models/country_model.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/tt_logo.dart';
import '../../widgets/app_widgets.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});
  @override
  State<WalletPage> createState() => _WalletState();
}

class _WalletState extends State<WalletPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  // ── Formulaire retrait ────────────────────────────────────────────────────
  final _amCtrl  = TextEditingController();
  final _numCtrl = TextEditingController();
  String? _operator, _cardType;
  Country? _country;

  // ── Données wallet ────────────────────────────────────────────────────────
  double _balance     = 0;
  double _pending     = 0;
  double _earned      = 0;
  double _withdrawn   = 0;
  String _currency    = 'FCFA';

  // ── Historique retraits ───────────────────────────────────────────────────
  List<dynamic> _withdrawals = [];

  // ── États de chargement ───────────────────────────────────────────────────
  bool _loadWallet    = true;
  bool _loadWithdraw  = false;
  bool _loadHistory   = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() {
      // Charge l'historique au premier accès à l'onglet
      if (_tab.index == 2 && _withdrawals.isEmpty) _loadWithdrawals();
    });
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── Chargements ───────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() => _loadWallet = true);
    final res = await ApiService.get(Api.wallet);
    if (mounted) {
      setState(() {
        _loadWallet = false;
        if (res['success'] == true || res['data'] != null || res['wallet'] != null) {
          final w = res['wallet'] ?? res['data'] ?? res;
          _balance   = double.tryParse('${w['balance']          ?? 0}') ?? 0;
          _pending   = double.tryParse('${w['pending_balance']  ?? w['pending']   ?? 0}') ?? 0;
          _earned    = double.tryParse('${w['total_earned']     ?? w['total_earnings']  ?? 0}') ?? 0;
          _withdrawn = double.tryParse('${w['total_withdrawn']  ?? w['total_withdrawals'] ?? 0}') ?? 0;
          _currency  = w['currency'] ?? 'FCFA';
        }
      });
    }
  }

  Future<void> _loadWithdrawals() async {
    setState(() => _loadHistory = true);
    final res = await ApiService.get(Api.withdrawals);
    if (mounted) {
      List<dynamic> list = [];
      if (res['data'] is List)             list = res['data'];
      else if (res['withdrawals'] is List) list = res['withdrawals'];
      else if (res is List)                list = res as List;
      setState(() {
        _withdrawals = list;
        _loadHistory = false;
      });
    }
  }

  // ── Retrait ───────────────────────────────────────────────────────────────

  Future<void> _withdraw(String method, Map<String, dynamic> extra) async {
    final amount = double.tryParse(_amCtrl.text);
    if (amount == null || amount <= 0) {
      snack(context, 'Montant invalide', error: true);
      return;
    }
    final min = method == 'mobile_money' ? 5000.0 : 10000.0;
    if (amount < min) {
      snack(context, 'Minimum ${min.toInt()} FCFA', error: true);
      return;
    }
    if (amount > _balance) {
      snack(context, 'Solde insuffisant', error: true);
      return;
    }

    setState(() => _loadWithdraw = true);
    final res = await ApiService.post(
        Api.withdrawals, {'method': method, 'amount': amount, ...extra});
    setState(() => _loadWithdraw = false);

    if (!mounted) return;
    if (res['success'] == true) {
      snack(context, '✅ Retrait lancé !');
      _amCtrl.clear();
      _numCtrl.clear();
      setState(() => _operator = _cardType = null);
      _load();
      _loadWithdrawals();
    } else {
      snack(context, res['message'] ?? 'Erreur', error: true);
    }
  }

  void _confirm(String method) {
    final extra = method == 'mobile_money'
        ? {
            'operator':    _operator ?? '',
            'phone':       '${_country?.dial ?? ""}${_numCtrl.text.trim()}',
            'country_code': _country?.code ?? '',
            'network':     _operator ?? '',
          }
        : {
            'card_type':   _cardType ?? '',
            'card_number': _numCtrl.text.trim(),
          };

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          TTIconLogo(size: 36, glow: false),
          SizedBox(width: 10),
          Text('Confirmer le retrait',
              style: TextStyle(color: C.text, fontWeight: FontWeight.w700)),
        ]),
        content: Text(
          'Retrait de ${_amCtrl.text} FCFA via '
          '${method == "mobile_money" ? "Mobile Money ($_operator)" : "Carte $_cardType"} ?',
          style: const TextStyle(color: C.muted, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler',
                  style: TextStyle(color: C.muted))),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              _withdraw(method, extra);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [C.orange, Color(0xFFE8921A)]),
                  borderRadius: BorderRadius.circular(10)),
              child: const Text('Confirmer',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers statut ────────────────────────────────────────────────────────

  Color _statusColor(String? s) {
    switch (s) {
      case 'completed': return Colors.green;
      case 'pending':   return C.orange;
      case 'rejected':
      case 'failed':    return C.error;
      default:          return C.muted;
    }
  }

  String _statusLabel(String? s) {
    switch (s) {
      case 'completed': return '✅ Complété';
      case 'pending':   return '⏳ En attente';
      case 'rejected':  return '❌ Rejeté';
      case 'failed':    return '🚫 Échoué';
      default:          return s ?? '—';
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: C.bg,
        appBar: AppBar(
          backgroundColor: C.card,
          elevation: 0,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, color: C.text),
              onPressed: () => Navigator.pop(context)),
          title: Row(children: [
            const TTIconLogo(size: 34, glow: false),
            const SizedBox(width: 10),
            const TTTextLogo(fontSize: 18),
            const SizedBox(width: 8),
            const Text('· Mon Wallet',
                style: TextStyle(color: C.muted, fontSize: 13)),
          ]),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh_rounded, color: C.orange),
                onPressed: () { _load(); _loadWithdrawals(); }),
          ],
          bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: C.border)),
        ),
        body: Column(children: [

          // ── Carte solde ─────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF0E1F32), Color(0xFF091729)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: C.orange.withOpacity(0.35)),
              boxShadow: [
                BoxShadow(
                    color: C.orange.withOpacity(0.2),
                    blurRadius: 28,
                    offset: const Offset(0, 8))
              ],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Logo + icône
              Row(children: [
                const TTTextLogo(fontSize: 20),
                const Spacer(),
                const TTIconLogo(size: 44, glow: false),
              ]),
              const SizedBox(height: 20),

              // Solde principal
              const Text('Solde disponible',
                  style: TextStyle(color: C.muted, fontSize: 12)),
              const SizedBox(height: 6),
              _loadWallet
                  ? const SizedBox(
                      height: 36,
                      child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(C.orange)))
                  : Text(
                      '${_balance.toStringAsFixed(0)} $_currency',
                      style: const TextStyle(
                          color: C.text,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1)),
              const SizedBox(height: 4),
              const Text('Solde en temps réel',
                  style: TextStyle(color: C.muted, fontSize: 11)),

              // ── Stats secondaires ──────────────────────────────────
              if (!_loadWallet) ...[
                const SizedBox(height: 18),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 14),
                Row(children: [
                  _walletStat('⏳ En attente',
                      '${_pending.toStringAsFixed(0)} $_currency'),
                  _walletStat('💰 Total gagné',
                      '${_earned.toStringAsFixed(0)} $_currency'),
                  _walletStat('📤 Retiré',
                      '${_withdrawn.toStringAsFixed(0)} $_currency'),
                ]),
              ],
            ]),
          ),

          const SizedBox(height: 16),

          // ── Onglets ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                  color: C.surface,
                  borderRadius: BorderRadius.circular(14)),
              child: TabBar(
                controller: _tab,
                indicator: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [C.orange, Color(0xFFE8921A)]),
                    borderRadius: BorderRadius.circular(12)),
                dividerColor: Colors.transparent,
                padding: const EdgeInsets.all(4),
                labelColor: Colors.white,
                unselectedLabelColor: C.muted,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 12),
                tabs: const [
                  Tab(text: '📱 Mobile'),
                  Tab(text: '💳 Carte'),
                  Tab(text: '📋 Historique'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),

          // ── Contenu onglets ─────────────────────────────────────────
          Expanded(
            child: TabBarView(controller: _tab, children: [
              _buildMobileMoneyTab(),
              _buildCardTab(),
              _buildHistoryTab(),
            ]),
          ),
        ]),
      );

  // ── Stat mini dans la carte ───────────────────────────────────────────────

  Widget _walletStat(String label, String value) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 9)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ]),
      );

  // ── Onglet Mobile Money ───────────────────────────────────────────────────

  Widget _buildMobileMoneyTab() => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(children: [
          const SLabel('RETRAIT MOBILE MONEY'),

          // Pays
          appDrop<Country>(
              hint: 'Pays *',
              value: _country,
              items: kCountries,
              builder: (c) => Text('${c.flag}  ${c.name}'),
              onChanged: (v) =>
                  setState(() { _country = v; _operator = null; }),
              prefix: const Icon(Icons.public_outlined,
                  color: C.muted, size: 20)),

          // Opérateur
          if (_country != null) ...[
            const SizedBox(height: 14),
            appDrop<String>(
                hint: 'Opérateur Mobile *',
                value: _operator,
                items: _country!.operators,
                builder: (e) => Text(e),
                onChanged: (v) => setState(() => _operator = v),
                prefix: const Icon(Icons.sim_card_outlined,
                    color: C.muted, size: 20)),
          ],

          const SizedBox(height: 14),

          // Indicatif + numéro
          Row(children: [
            if (_country != null)
              Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                    color: C.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: C.border)),
                child: Text('${_country!.flag} ${_country!.dial}',
                    style: const TextStyle(color: C.text, fontSize: 14)),
              ),
            Expanded(
              child: TF(
                hint: '6XX XX XX XX',
                label: 'Numéro Mobile *',
                ctrl: _numCtrl,
                type: TextInputType.phone,
                prefix: const Icon(Icons.phone, color: C.muted, size: 20),
              ),
            ),
          ]),

          const SizedBox(height: 14),

          TF(
            hint: 'Ex: 10000',
            label: 'Montant à retirer (FCFA) *',
            ctrl: _amCtrl,
            type: TextInputType.number,
            prefix: const Icon(Icons.attach_money_rounded,
                color: C.muted, size: 20),
          ),
          const SizedBox(height: 6),
          const Text('Minimum : 5 000 FCFA  ·  Commission : 1%',
              style: TextStyle(color: C.muted, fontSize: 11)),
          const SizedBox(height: 24),

          OBtn(
              text: 'RETIRER VIA MOBILE MONEY',
              icon: Icons.send_to_mobile_rounded,
              loading: _loadWithdraw,
              onTap: () => _confirm('mobile_money')),
          const SizedBox(height: 20),
        ]),
      );

  // ── Onglet Carte Bancaire ─────────────────────────────────────────────────

  Widget _buildCardTab() => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(children: [
          const SLabel('RETRAIT CARTE BANCAIRE'),

          Row(children: [
            Expanded(child: _cBtn('Visa', '💳 Visa')),
            const SizedBox(width: 12),
            Expanded(child: _cBtn('Mastercard', '💳 Mastercard')),
          ]),
          const SizedBox(height: 14),

          TF(
            hint: '1234 5678 9012 3456',
            label: 'Numéro de carte *',
            ctrl: _numCtrl,
            type: TextInputType.number,
            prefix:
                const Icon(Icons.credit_card, color: C.muted, size: 20),
          ),
          const SizedBox(height: 14),

          Row(children: [
            Expanded(child: TF(
                hint: 'MM/AA',
                label: 'Expiration',
                ctrl: TextEditingController())),
            const SizedBox(width: 12),
            Expanded(child: TF(
                hint: '•••',
                label: 'CVV',
                ctrl: TextEditingController(),
                obscure: true)),
          ]),
          const SizedBox(height: 14),

          TF(
            hint: 'Ex: 20000',
            label: 'Montant à retirer (FCFA) *',
            ctrl: _amCtrl,
            type: TextInputType.number,
            prefix: const Icon(Icons.attach_money_rounded,
                color: C.muted, size: 20),
          ),
          const SizedBox(height: 6),
          const Text('Minimum : 10 000 FCFA  ·  Commission : 2.5%',
              style: TextStyle(color: C.muted, fontSize: 11)),
          const SizedBox(height: 24),

          OBtn(
              text: 'RETIRER VIA CARTE',
              icon: Icons.credit_card_rounded,
              loading: _loadWithdraw,
              onTap: () => _confirm('card')),
          const SizedBox(height: 20),
        ]),
      );

  // ── Onglet Historique ─────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    if (_loadHistory) {
      return const Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(C.orange)));
    }

    if (_withdrawals.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.receipt_long_rounded, color: C.muted, size: 60),
          const SizedBox(height: 16),
          const Text('Aucun retrait effectué',
              style: TextStyle(color: C.muted, fontSize: 15)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _loadWithdrawals,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                  color: C.orange,
                  borderRadius: BorderRadius.circular(12)),
              child: const Text('🔄 Actualiser',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadWithdrawals,
      color: C.orange,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _withdrawals.length,
        itemBuilder: (_, i) => _buildWithdrawalCard(_withdrawals[i]),
      ),
    );
  }

  Widget _buildWithdrawalCard(Map<dynamic, dynamic> w) {
    final status    = w['status'] as String?;
    final amount    = w['amount'] ?? '—';
    final currency  = w['currency'] ?? 'FCFA';
    final date      = w['created_at'] ?? '';
    final method    = w['method'] ?? w['payment_method'] ?? '';
    final phone     = w['phone'] ?? w['phone_number'] ?? '';
    final network   = w['network'] ?? w['operator'] ?? '';
    final reference = w['reference'] ?? w['transaction_id'] ?? '';
    final note      = w['rejection_reason'] ?? w['note'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: _statusColor(status).withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: _statusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.arrow_upward_rounded,
                color: _statusColor(status), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$amount $currency',
                style: const TextStyle(
                    color: C.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
            if (date.isNotEmpty)
              Text(date,
                  style: const TextStyle(
                      color: C.muted, fontSize: 11)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: _statusColor(status).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Text(_statusLabel(status),
                style: TextStyle(
                    color: _statusColor(status),
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ]),

        const SizedBox(height: 10),
        const Divider(height: 1, color: C.border),
        const SizedBox(height: 10),

        // Détails
        Wrap(spacing: 16, runSpacing: 6, children: [
          if (method.isNotEmpty)
            _detail(Icons.payment_rounded,
                method == 'mobile_money' ? '📱 Mobile Money' : '💳 Carte'),
          if (phone.isNotEmpty)
            _detail(Icons.phone_rounded, phone),
          if (network.isNotEmpty)
            _detail(Icons.signal_cellular_alt_rounded, network),
          if (reference.isNotEmpty)
            _detail(Icons.tag_rounded, reference),
        ]),

        // Motif de rejet
        if (note.isNotEmpty && status == 'rejected') ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: C.error.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  color: C.error, size: 14),
              const SizedBox(width: 8),
              Expanded(child: Text(note,
                  style: const TextStyle(
                      color: C.error, fontSize: 12))),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _detail(IconData icon, String value) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: C.muted, size: 13),
        const SizedBox(width: 4),
        Text(value,
            style: const TextStyle(color: C.muted, fontSize: 12)),
      ]);

  // ── Bouton sélection carte ────────────────────────────────────────────────

  Widget _cBtn(String v, String label) {
    final sel = _cardType == v;
    return GestureDetector(
      onTap: () => setState(() => _cardType = v),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: sel ? C.orange.withOpacity(0.12) : C.surface,
          border: Border.all(
              color: sel ? C.orange : C.border, width: sel ? 2 : 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
            child: Text(label,
                style: TextStyle(
                    color: sel ? C.orange : C.muted,
                    fontWeight: FontWeight.w600))),
      ),
    );
  }
}

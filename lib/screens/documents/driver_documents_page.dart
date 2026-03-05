import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/tt_logo.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Types de documents requis pour le chauffeur
// ─────────────────────────────────────────────────────────────────────────────
const List<Map<String, dynamic>> kDocumentTypes = [
  {
    'key':   'carte_identite',
    'label': "Carte d'identité",
    'icon':  Icons.badge_rounded,
    'desc':  'Recto/Verso en cours de validité',
  },
  {
    'key':   'permis_conduire',
    'label': 'Permis de conduire',
    'icon':  Icons.drive_eta_rounded,
    'desc':  'Permis valide pour la catégorie du véhicule',
  },
  {
    'key':   'carte_grise',
    'label': 'Carte grise',
    'icon':  Icons.article_rounded,
    'desc':  'Document d\'immatriculation du véhicule',
  },
  {
    'key':   'assurance',
    'label': 'Assurance véhicule',
    'icon':  Icons.shield_rounded,
    'desc':  'Attestation d\'assurance en cours de validité',
  },
  {
    'key':   'visite_technique',
    'label': 'Visite technique',
    'icon':  Icons.construction_rounded,
    'desc':  'Rapport de contrôle technique valide',
  },
  {
    'key':   'photo_profil',
    'label': 'Photo de profil',
    'icon':  Icons.person_rounded,
    'desc':  'Photo récente, fond neutre',
  },
];

// ─────────────────────────────────────────────────────────────────────────────
// Page principale
// ─────────────────────────────────────────────────────────────────────────────
class DriverDocumentsPage extends StatefulWidget {
  const DriverDocumentsPage({super.key});
  @override
  State<DriverDocumentsPage> createState() => _DriverDocumentsPageState();
}

class _DriverDocumentsPageState extends State<DriverDocumentsPage> {
  List<dynamic> _documents = [];
  bool _loading = true;
  final Map<String, bool> _uploading = {};
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Chargement ────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get(Api.documents);
    if (mounted) {
      List<dynamic> docs = [];
      if (res['data'] is List)       docs = res['data'];
      else if (res['documents'] is List) docs = res['documents'];
      else if (res is List)          docs = res as List;
      setState(() {
        _documents = docs;
        _loading   = false;
      });
    }
  }

  // ── Upload ────────────────────────────────────────────────────────────────

  Future<void> _pickAndUpload(String docType, String docLabel) async {
    // Choix : caméra ou galerie
    final source = await _sourceDialog(docLabel);
    if (source == null) return;

    final XFile? file = source == 'camera'
        ? await _picker.pickImage(source: ImageSource.camera, imageQuality: 85)
        : await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);

    if (file == null) return;

    setState(() => _uploading[docType] = true);

    final res = await ApiService.uploadFile(
      Api.documents,
      filePath: file.path,
      fileName: file.name,
      fields: {'type': docType},
    );

    if (!mounted) return;
    setState(() => _uploading.remove(docType));

    snack(context,
      res['success'] == true
          ? '✅ $docLabel uploadé avec succès !'
          : res['message'] ?? 'Erreur lors de l\'upload',
      error: res['success'] != true);

    if (res['success'] == true) _load();
  }

  Future<String?> _sourceDialog(String label) => showModalBottomSheet<String>(
    context: context,
    backgroundColor: C.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(
                color: C.border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text('Uploader : $label',
            style: const TextStyle(
                color: C.text, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        _sourceOption(Icons.camera_alt_rounded, 'Prendre une photo', 'camera'),
        const SizedBox(height: 10),
        _sourceOption(Icons.photo_library_rounded, 'Choisir depuis la galerie', 'gallery'),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
                color: C.surface, borderRadius: BorderRadius.circular(12)),
            child: const Center(child: Text('Annuler',
                style: TextStyle(color: C.muted, fontWeight: FontWeight.w600))),
          ),
        ),
      ]),
    ),
  );

  Widget _sourceOption(IconData icon, String label, String value) =>
      GestureDetector(
        onTap: () => Navigator.pop(context, value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
              color: C.surface, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.border)),
          child: Row(children: [
            Icon(icon, color: C.orange, size: 22),
            const SizedBox(width: 14),
            Text(label, style: const TextStyle(color: C.text, fontSize: 14)),
          ]),
        ),
      );

  // ── Suppression ───────────────────────────────────────────────────────────

  Future<void> _delete(dynamic docId, String docLabel) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer le document',
            style: TextStyle(color: C.text, fontWeight: FontWeight.w700)),
        content: Text('Supprimer "$docLabel" ?',
            style: const TextStyle(color: C.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler', style: TextStyle(color: C.muted))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer',
                  style: TextStyle(color: C.error, fontWeight: FontWeight.w700))),
        ],
      ),
    ) ?? false;

    if (!ok) return;

    final res = await ApiService.delete('${Api.documents}/$docId');
    if (!mounted) return;
    snack(context,
        res['success'] == true ? '🗑 Document supprimé' : res['message'] ?? 'Erreur',
        error: res['success'] != true);
    if (res['success'] == true) _load();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Retrouve le document uploadé pour un type donné
  Map? _findDoc(String type) {
    try {
      return _documents.firstWhere(
          (d) => d['type'] == type || d['document_type'] == type);
    } catch (_) {
      return null;
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'approved':  return Colors.green;
      case 'pending':   return C.orange;
      case 'rejected':  return C.error;
      default:          return C.muted;
    }
  }

  String _statusLabel(String? s) {
    switch (s) {
      case 'approved':  return '✅ Approuvé';
      case 'pending':   return '⏳ En attente';
      case 'rejected':  return '❌ Rejeté';
      default:          return '📤 Non soumis';
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: AppBar(
      backgroundColor: C.card, elevation: 0,
      leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: C.text, size: 18),
          onPressed: () => Navigator.pop(context)),
      title: Row(children: [
        const TTIconLogo(size: 32, glow: false), const SizedBox(width: 10),
        const TTTextLogo(fontSize: 17), const SizedBox(width: 8),
        const Text('· Documents', style: TextStyle(color: C.muted, fontSize: 12)),
      ]),
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: C.border)),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(C.orange)))
        : RefreshIndicator(
            onRefresh: _load,
            color: C.orange,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildProgress(),
                const SizedBox(height: 20),
                ...kDocumentTypes.map((dt) => _buildDocCard(dt)),
                const SizedBox(height: 30),
              ],
            ),
          ),
  );

  // Barre de progression globale
  Widget _buildProgress() {
    final approved = kDocumentTypes
        .where((dt) => _findDoc(dt['key'])?['status'] == 'approved')
        .length;
    final total = kDocumentTypes.length;
    final pct   = approved / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.verified_user_rounded, color: C.orange, size: 18),
          const SizedBox(width: 8),
          const Text('Profil de vérification',
              style: TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 14)),
          const Spacer(),
          Text('$approved / $total',
              style: const TextStyle(color: C.orange, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: C.border,
            valueColor: AlwaysStoppedAnimation(pct == 1.0 ? Colors.green : C.orange),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          pct == 1.0
              ? '🎉 Tous vos documents sont approuvés !'
              : 'Uploadez tous vos documents pour activer votre compte',
          style: TextStyle(
              color: pct == 1.0 ? Colors.green : C.muted, fontSize: 12),
        ),
      ]),
    );
  }

  Widget _buildDocCard(Map<String, dynamic> dt) {
    final key      = dt['key'] as String;
    final label    = dt['label'] as String;
    final icon     = dt['icon'] as IconData;
    final desc     = dt['desc'] as String;
    final doc      = _findDoc(key);
    final isLoading = _uploading[key] == true;
    final status   = doc?['status'] as String?;
    final hasDoc   = doc != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'approved'
              ? Colors.green.withOpacity(0.4)
              : status == 'rejected'
                  ? C.error.withOpacity(0.4)
                  : C.border,
        ),
      ),
      child: Row(children: [

        // Icône document
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (hasDoc ? _statusColor(status) : C.muted).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon,
              color: hasDoc ? _statusColor(status) : C.muted, size: 24),
        ),

        const SizedBox(width: 14),

        // Infos
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  color: C.text, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 3),
          Text(desc, style: const TextStyle(color: C.muted, fontSize: 11)),
          const SizedBox(height: 6),
          // Statut
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(_statusLabel(status),
                  style: TextStyle(
                      color: _statusColor(status),
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
            if (doc?['expires_at'] != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.event_rounded, color: C.muted, size: 11),
              const SizedBox(width: 3),
              Text('Exp: ${doc!['expires_at']}',
                  style: const TextStyle(color: C.muted, fontSize: 10)),
            ],
          ]),
          // Message de rejet
          if (status == 'rejected' && doc?['rejection_reason'] != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                  color: C.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('⚠️ ${doc!['rejection_reason']}',
                  style: const TextStyle(color: C.error, fontSize: 10)),
            ),
          ],
        ])),

        const SizedBox(width: 10),

        // Actions
        Column(mainAxisSize: MainAxisSize.min, children: [
          // Upload / Re-upload
          GestureDetector(
            onTap: isLoading ? null : () => _pickAndUpload(key, label),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: C.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: isLoading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(C.orange)))
                  : Icon(
                      hasDoc ? Icons.refresh_rounded : Icons.upload_rounded,
                      color: C.orange, size: 18),
            ),
          ),
          // Supprimer (si document existant)
          if (hasDoc) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _delete(doc!['id'], label),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: C.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.delete_outline_rounded,
                    color: C.error, size: 18),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

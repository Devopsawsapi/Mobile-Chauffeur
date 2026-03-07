/// ══════════════════════════════════════════════════════════════════
///  ModerationService — Filtrage intelligent des messages TopTopGo
///  Bloque : numéros, liens, emails, menaces, injures, contenu sexuel
///  Identique côté client & chauffeur pour cohérence
/// ══════════════════════════════════════════════════════════════════
class ModerationService {
  static ModerationResult check(String text) {
    if (text.trim().isEmpty) return ModerationResult.ok();
    final t        = text.toLowerCase().trim();
    final collapsed = text.replaceAll(RegExp(r'[\s\-\.\(\)]'), '');

    // ── 1. Numéros de téléphone ──────────────────────────────────────
    final phoneRegex = RegExp(r'(\+?\d[\d\s\-\.\(\)/]{6,}\d)');
    if (phoneRegex.hasMatch(collapsed) && RegExp(r'\d{7,}').hasMatch(collapsed)) {
      return ModerationResult.blocked(
        BlockReason.phone,
        'Les numéros de téléphone sont interdits.\nUtilisez le bouton d\'appel intégré 📞',
      );
    }

    // ── 2. Adresses e-mail ───────────────────────────────────────────
    if (RegExp(r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}').hasMatch(text)) {
      return ModerationResult.blocked(
        BlockReason.email,
        'Les adresses e-mail sont interdites.\nCommuniquez uniquement via l\'application.',
      );
    }

    // ── 3. Liens & URLs ──────────────────────────────────────────────
    if (RegExp(
      r'(https?://|www\.|\.(com|fr|net|org|io|co|me|app|link)|bit\.ly|t\.me|wa\.me|tinyurl|fb\.me)',
      caseSensitive: false,
    ).hasMatch(t)) {
      return ModerationResult.blocked(
        BlockReason.link,
        'Les liens externes sont interdits.\nTous les paiements passent par TopTopGo.',
      );
    }

    // ── 4. Menaces & violence ────────────────────────────────────────
    const threats = [
      'je vais te tuer', 'je te tue', 'mort à', 'je vais te retrouver',
      'tu vas mourir', 'je te retrouve', 'je te fracasse', 'gare à toi',
      'tu vas regretter', 'je vais te buter', 'je te bute', 'crève',
      'je vais te défoncer', 'va te faire', 'va crever', 'je te massacre',
      'on se retrouve', 'fais attention à toi', 'tu vas voir', 'prépare-toi',
    ];
    for (final w in threats) {
      if (t.contains(w)) {
        return ModerationResult.blocked(
          BlockReason.threat,
          'Ce message contient des propos menaçants.\nIl a été bloqué pour votre sécurité.',
        );
      }
    }

    // ── 5. Insultes / Contenu offensant ─────────────────────────────
    const insults = [
      'fils de pute', 'fdp', 'connard', 'connasse', 'salope', 'pute',
      'enculé', 'batard', 'bâtard', 'ta gueule', 'ferme ta gueule',
      'nique ta', 'nique ta mère', 'ntm', 'va te faire foutre',
      'va te faire enculer', 'imbécile', 'idiot', 'crétin', 'abruti',
      'merde', 'putain', 'bordel',
    ];
    for (final w in insults) {
      if (t.contains(w)) {
        return ModerationResult.blocked(
          BlockReason.insult,
          'Ce message contient des insultes et ne peut pas être envoyé.\nRestez respectueux.',
        );
      }
    }

    // ── 6. Contenu romantique / inapproprié ─────────────────────────
    const romantic = [
      'je t\'aime', 'je taime', 'je t aime', 'je vous aime', 'i love you',
      'tu es belle', 'tu es beau', 'tu me plais', 'rendez-vous amoureux',
      'on se voit ce soir', 'tu veux sortir avec moi', 'es-tu libre ce soir',
      'donne-moi ton numéro', 'donne moi ton numero', 'ton whatsapp',
      'viens chez moi', 'viens me voir',
    ];
    for (final w in romantic) {
      if (t.contains(w)) {
        return ModerationResult.blocked(
          BlockReason.inappropriate,
          'Ce message est inapproprié pour une plateforme professionnelle.\nLimitez les échanges au trajet.',
        );
      }
    }

    // ── 7. Paiement hors plateforme ──────────────────────────────────
    const offPlatform = [
      'payer en cash', 'payer en liquide', 'payer directement',
      'paiement direct', 'sans l\'appli', 'sans l appli',
      'mobile money direct', 'orange money direct', 'airtel money direct',
      'envoie moi', 'envoie-moi l\'argent',
    ];
    for (final w in offPlatform) {
      if (t.contains(w)) {
        return ModerationResult.blocked(
          BlockReason.payment,
          'Les paiements hors plateforme sont interdits.\nUtilisez uniquement TopTopGo Pay.',
        );
      }
    }

    return ModerationResult.ok();
  }
}

enum BlockReason { phone, email, link, threat, insult, inappropriate, payment }

class ModerationResult {
  final bool isBlocked;
  final BlockReason? reason;
  final String? message;

  const ModerationResult._({required this.isBlocked, this.reason, this.message});

  factory ModerationResult.ok() => const ModerationResult._(isBlocked: false);
  factory ModerationResult.blocked(BlockReason reason, String message) =>
      ModerationResult._(isBlocked: true, reason: reason, message: message);

  String get icon {
    switch (reason) {
      case BlockReason.phone:          return '📵';
      case BlockReason.email:          return '📧';
      case BlockReason.link:           return '🔗';
      case BlockReason.threat:         return '⚠️';
      case BlockReason.insult:         return '🚫';
      case BlockReason.inappropriate:  return '💬';
      case BlockReason.payment:        return '💳';
      default:                         return '🚫';
    }
  }
}

class Api {
  static const String base = 'https://toptopgo2026-production.up.railway.app/api';

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String register       = '$base/driver/auth/register';
  static const String login          = '$base/driver/auth/login';
  static const String logout         = '$base/driver/auth/logout';
  static const String me             = '$base/driver/auth/me';
  static const String forgotPassword = '$base/driver/auth/forgot-password';
  static const String resetPassword  = '$base/driver/auth/reset-password';

  // ── Profil & Statut ───────────────────────────────────────────────────────
  static const String profile  = '$base/driver/profile';
  static const String password = '$base/driver/password';
  static const String status   = '$base/driver/status';

  // ── Trajets ───────────────────────────────────────────────────────────────
  /// GET  /driver/trips          → liste
  /// POST /driver/trips          → créer
  static const String trips = '$base/driver/trips';

  /// GET  /driver/trips/{id}
  static String tripShow(dynamic id)  => '$base/driver/trips/$id';

  /// PUT  /driver/trips/{id}
  static String tripUpdate(dynamic id) => '$base/driver/trips/$id';

  /// DELETE /driver/trips/{id}
  static String tripDelete(dynamic id) => '$base/driver/trips/$id';

  /// POST /driver/trips/{id}/start
  static String tripStart(dynamic id) => '$base/driver/trips/$id/start';

  /// POST /driver/trips/{id}/end
  static String tripEnd(dynamic id)   => '$base/driver/trips/$id/end';

  // ── Réservations ──────────────────────────────────────────────────────────
  /// GET  /driver/bookings
  static const String bookings = '$base/driver/bookings';

  /// POST /driver/bookings/{id}/confirm
  static String bookingConfirm(dynamic id) => '$base/driver/bookings/$id/confirm';

  /// POST /driver/bookings/{id}/reject
  static String bookingReject(dynamic id)  => '$base/driver/bookings/$id/reject';

  // ── Portefeuille ──────────────────────────────────────────────────────────
  /// GET  /driver/wallet
  static const String wallet = '$base/driver/wallet';

  // ── Retraits ──────────────────────────────────────────────────────────────
  /// GET  /driver/withdrawals
  /// POST /driver/withdrawals
  static const String withdrawals = '$base/driver/withdrawals';

  /// GET  /driver/withdrawals/{id}
  static String withdrawalShow(dynamic id) => '$base/driver/withdrawals/$id';

  // ── Documents ─────────────────────────────────────────────────────────────
  /// GET  /driver/documents
  /// POST /driver/documents      (multipart/form-data)
  static const String documents = '$base/driver/documents';

  /// GET    /driver/documents/{id}
  static String documentShow(dynamic id)    => '$base/driver/documents/$id';

  /// DELETE /driver/documents/{id}
  static String documentDelete(dynamic id)  => '$base/driver/documents/$id';

  // ── SOS ───────────────────────────────────────────────────────────────────
  /// GET  /driver/sos
  /// POST /driver/sos
  static const String sos = '$base/driver/sos';

  // ── Messagerie ────────────────────────────────────────────────────────────
  /// GET  /driver/messages
  static const String messages = '$base/driver/messages';

  /// GET  /driver/messages/{trip_id}
  static String messageThread(dynamic tripId)  => '$base/driver/messages/$tripId';

  /// POST /driver/messages/{trip_id}
  static String messageSend(dynamic tripId)    => '$base/driver/messages/$tripId';

  // ── Support ───────────────────────────────────────────────────────────────
  /// GET  /driver/support
  /// POST /driver/support
  static const String support = '$base/driver/support';
}

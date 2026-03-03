class Api {
  static const String base = 'https://toptopgo2026-production.up.railway.app/api';

  // Auth
  static const String register    = '$base/driver/auth/register';
  static const String login       = '$base/driver/auth/login';
  static const String logout      = '$base/driver/auth/logout';
  static const String me          = '$base/driver/auth/me';

  // Driver
  static const String profile     = '$base/driver/profile';
  static const String password    = '$base/driver/password';
  static const String status      = '$base/driver/status';
  static const String trips       = '$base/driver/trips';
  static const String wallet      = '$base/driver/wallet';
  static const String withdrawals = '$base/driver/withdrawals';
  static const String sos         = '$base/driver/sos';
  static const String messages    = '$base/driver/messages';
  static const String support     = '$base/driver/support';
  static const String documents   = '$base/driver/documents';
}

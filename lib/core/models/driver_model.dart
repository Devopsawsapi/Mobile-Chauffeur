import '../../core/services/api_service.dart';

class DriverModel {
  final int? id;
  final String firstName, lastName, email, phone;
  final String? city, country, vehicleType, vehicleBrand, vehicleModel,
      vehicleColor, vehiclePlate, profilePhoto;
  String status, driverStatus;
  double walletBalance, todayRevenue, commissionRate;
  int todayTrips, todayClients;

  DriverModel({
    this.id,
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phone = '',
    this.city,
    this.country,
    this.status = 'pending',
    this.driverStatus = 'offline',
    this.walletBalance = 0,
    this.todayRevenue = 0,
    this.commissionRate = 0.15,
    this.todayTrips = 0,
    this.todayClients = 0,
    this.vehicleType,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleColor,
    this.vehiclePlate,
    this.profilePhoto,
  });

  factory DriverModel.fromJson(Map<String, dynamic> j) {
    final d = (j['driver'] is Map ? j['driver'] : null) ??
        (j['data'] is Map ? j['data'] : null) ??
        j;
    final w = j['wallet'] ?? (d is Map ? d['wallet'] : null) ?? {};
    return DriverModel(
      id:        d['id'],
      firstName: d['first_name']  ?? d['prenom'] ?? '',
      lastName:  d['last_name']   ?? d['nom']    ?? '',
      email:     d['email']       ?? '',
      phone:     d['phone']       ?? d['telephone'] ?? '',
      city:      d['vehicle_city']    ?? d['city']  ?? d['ville'],
      country:   d['vehicle_country'] ?? d['country'] ?? d['pays'],
      status:       d['status']        ?? 'pending',
      driverStatus: d['driver_status'] ?? 'offline',
      walletBalance:  double.tryParse('${w['balance'] ?? d['wallet_balance'] ?? 0}') ?? 0,
      todayRevenue:   double.tryParse('${j['today_revenue']  ?? 0}') ?? 0,
      commissionRate: double.tryParse('${d['commission_rate'] ?? 0.15}') ?? 0.15,
      todayTrips:   int.tryParse('${j['today_trips']   ?? 0}') ?? 0,
      todayClients: int.tryParse('${j['today_clients'] ?? 0}') ?? 0,
      vehicleType:   d['vehicle_type'],
      vehicleBrand:  d['vehicle_brand'],
      vehicleModel:  d['vehicle_model'],
      vehicleColor:  d['vehicle_color'],
      vehiclePlate:  d['vehicle_plate'],
      // ✅ FIX photo : si chemin relatif → ajouter l'URL de base du serveur
      profilePhoto: _buildPhotoUrl(d['profile_photo']),
    );
  }

  double get commission => todayRevenue * commissionRate;
  double get net        => todayRevenue - commission;

  // ✅ Construit l'URL complète de la photo depuis un chemin relatif ou absolu
  static String? _buildPhotoUrl(dynamic raw) {
    if (raw == null || raw.toString().isEmpty) return null;
    final s = raw.toString();
    // Déjà une URL complète
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    // Chemin relatif → ajouter la base du serveur
    const base = 'https://toptopgo2026-production.up.railway.app/storage/';
    final path = s.startsWith('/') ? s.substring(1) : s;
    return '$base$path';
  }
  String get fullName   => '$firstName $lastName'.trim();
  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty  ? lastName[0]  : '';
    return '$f$l'.toUpperCase().isNotEmpty ? '$f$l'.toUpperCase() : 'CH';
  }
}

// État global du chauffeur connecté
DriverModel currentDriver = DriverModel();
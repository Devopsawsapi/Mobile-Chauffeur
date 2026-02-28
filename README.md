# 🚖 TopTopGo — Applications Flutter

Deux projets Flutter complets connectés à votre backend Laravel.

---

## 📁 Structure des projets

```
toptopgo_flutter/
│
├── client/                     ← Projet Flutter App Client
│   ├── pubspec.yaml
│   └── lib/
│       ├── main.dart           ← TOUT le code client ici
│       └── core/
│           ├── api/
│           │   └── api_service.dart    (helper API réutilisable)
│           ├── models/
│           │   └── models.dart         (tous les modèles Dart)
│           └── theme/
│               └── app_theme.dart      (couleurs & thème)
│
└── driver/                     ← Projet Flutter App Chauffeur
    ├── pubspec.yaml
    └── lib/
        └── main.dart           ← TOUT le code chauffeur ici
```

---

## 🚀 Installation

### 1. Créer les deux projets Flutter

```bash
flutter create toptopgo_client
flutter create toptopgo_driver
```

### 2. Remplacer les fichiers

Copie les fichiers du dossier `client/` dans `toptopgo_client/`
Copie les fichiers du dossier `driver/` dans `toptopgo_driver/`

### 3. Installer les dépendances

```bash
# Dans chaque projet :
flutter pub get
```

---

## 📦 Dépendances utilisées

```yaml
http: ^1.2.0                  # Requêtes HTTP vers le backend
shared_preferences: ^2.2.2    # Stockage token (équivalent AsyncStorage)
google_maps_flutter: ^2.6.0   # Carte (à configurer avec clé API)
geolocator: ^11.0.0            # GPS temps réel
image_picker: ^1.0.7           # Upload photos documents
cached_network_image: ^3.3.1  # Images depuis Backblaze B2
intl: ^0.19.0                  # Formatage dates/nombres
flutter_spinkit: ^5.2.0        # Indicateurs de chargement
```

---

## ⚙️ Configuration Google Maps

### Android — `android/app/src/main/AndroidManifest.xml`
```xml
<manifest>
  <application>
    <meta-data
      android:name="com.google.android.geo.API_KEY"
      android:value="your-google-maps-api-key"/>
  </application>
</manifest>
```

### iOS — `ios/Runner/AppDelegate.swift`
```swift
import GoogleMaps
GMSServices.provideAPIKey("your-google-maps-api-key")
```

### Remplacer le placeholder par la vraie carte dans `main.dart`
```dart
import 'package:google_maps_flutter/google_maps_flutter.dart';

GoogleMap(
  initialCameraPosition: CameraPosition(
    target: LatLng(-4.2660, 11.8633), // Pointe-Noire
    zoom: 13,
  ),
  myLocationEnabled: true,
  myLocationButtonEnabled: true,
)
```

---

## 🔗 Tous les endpoints utilisés

### Auth
| Méthode | Endpoint                  | App       |
|---------|---------------------------|-----------|
| POST    | `/user/auth/register`     | Client    |
| POST    | `/user/auth/login`        | Client    |
| POST    | `/user/auth/logout`       | Client    |
| POST    | `/driver/auth/register`   | Chauffeur |
| POST    | `/driver/auth/login`      | Chauffeur |
| POST    | `/driver/auth/logout`     | Chauffeur |

### Courses
| Méthode | Endpoint                          | App       |
|---------|-----------------------------------|-----------|
| POST    | `/user/courses`                   | Client    |
| GET     | `/user/courses`                   | Client    |
| GET     | `/user/courses/{id}`              | Client    |
| GET     | `/driver/courses/available`       | Chauffeur |
| GET     | `/driver/courses`                 | Chauffeur |
| GET     | `/driver/courses/{id}`            | Chauffeur |
| POST    | `/driver/courses/{id}/accept`     | Chauffeur |
| POST    | `/driver/courses/{id}/reject`     | Chauffeur |
| POST    | `/driver/courses/{id}/start`      | Chauffeur |
| POST    | `/driver/courses/{id}/complete`   | Chauffeur |

### Chat
| Méthode | Endpoint                    | Les deux  |
|---------|-----------------------------|-----------|
| GET     | `/trips/{id}/messages`      | Les deux  |
| POST    | `/trips/{id}/messages`      | Les deux  |

### SOS
| Méthode | Endpoint | Les deux  |
|---------|----------|-----------|
| POST    | `/sos`   | Les deux  |

### Wallet Chauffeur
| Méthode | Endpoint                       |
|---------|--------------------------------|
| GET     | `/driver/wallet`               |
| GET     | `/driver/wallet/transactions`  |
| POST    | `/driver/withdrawals`          |
| GET     | `/driver/withdrawals`          |

### Status / Location
| Méthode | Endpoint            |
|---------|---------------------|
| POST    | `/driver/status`    |
| POST    | `/driver/location`  |

---

## ⚠️ Routes Laravel à ajouter dans `routes/api.php`

```php
// ── CLIENT ──
Route::prefix('user')->middleware('auth:sanctum')->group(function () {
    Route::get('courses',              [UserCourseController::class, 'index']);
    Route::post('courses',             [UserCourseController::class, 'store']);
    Route::get('courses/{id}',         [UserCourseController::class, 'show']);
    Route::post('courses/{id}/cancel', [UserCourseController::class, 'cancel']);
});

// ── CHAUFFEUR ──
Route::prefix('driver')->middleware('auth:sanctum')->group(function () {
    Route::get('courses/available',          [DriverCourseController::class, 'available']);
    Route::get('courses',                    [DriverCourseController::class, 'index']);
    Route::get('courses/{id}',               [DriverCourseController::class, 'show']);
    Route::post('courses/{id}/accept',       [DriverCourseController::class, 'accept']);
    Route::post('courses/{id}/reject',       [DriverCourseController::class, 'reject']);
    Route::post('courses/{id}/start',        [DriverCourseController::class, 'start']);
    Route::post('courses/{id}/complete',     [DriverCourseController::class, 'complete']);
    Route::get('wallet',                     [WalletController::class, 'show']);
    Route::get('wallet/transactions',        [WalletController::class, 'transactions']);
    Route::post('withdrawals',               [WithdrawalController::class, 'store']);
    Route::get('withdrawals',                [WithdrawalController::class, 'index']);
    Route::post('status',                    [DriverStatusController::class, 'update']);
    Route::post('location',                  [DriverLocationController::class, 'update']);
});

// ── COMMUN ──
Route::middleware('auth:sanctum')->group(function () {
    Route::get('trips/{id}/messages',   [TripMessageController::class, 'index']);
    Route::post('trips/{id}/messages',  [TripMessageController::class, 'store']);
    Route::post('sos',                  [SosAlertController::class, 'store']);
});
```

---

## 📲 Notifications Push OneSignal

```bash
flutter pub add onesignal_flutter
```

```dart
// Dans main() :
import 'package:onesignal_flutter/onesignal_flutter.dart';

OneSignal.initialize('97a5378b-a813-45af-9d04-5fc5ea4194eb');
OneSignal.Notifications.requestPermission(true);
```

---

## 🌐 Changer l'URL API (production)

Dans `main.dart` de chaque projet, change :
```dart
// Développement
const kBaseUrl = 'http://localhost:8000/api';

// Production
const kBaseUrl = 'https://api.toptopgo.com/api';
```

---

## ✅ Fonctionnalités implémentées

### App Client 🚕
- ✅ Splash screen animé
- ✅ Inscription / Connexion
- ✅ Réservation de course + estimation de prix
- ✅ Attente chauffeur (polling 8s)
- ✅ Suivi course en temps réel (polling 10s)
- ✅ Chat chauffeur/client
- ✅ Bouton SOS global + SOS en course
- ✅ Historique des courses
- ✅ Profil utilisateur
- ✅ Déconnexion

### App Chauffeur 🚗
- ✅ Splash screen
- ✅ Inscription 2 étapes (perso + véhicule)
- ✅ Connexion
- ✅ Mode En ligne / Hors ligne avec switch
- ✅ Dashboard + courses disponibles (polling 12s)
- ✅ Accepter / Refuser une course
- ✅ Démarrer / Terminer une course
- ✅ Chat avec le client
- ✅ Bouton SOS
- ✅ Wallet complet avec solde dégradé
- ✅ Retrait Mobile Money (MTN, Orange, Airtel, Peex, Moov)
- ✅ Historique transactions et retraits
- ✅ Historique des courses
- ✅ Profil chauffeur
- ✅ Déconnexion
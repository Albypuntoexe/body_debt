import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'preferences_service.dart';

class NotificationService {
  final PreferencesService _prefs;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static const _keyNotificationsEnabled = 'notifications_enabled';

  // Chiave per salvare l'orario dell'ultima notifica inviata
  static const _keyLastNotificationTime = 'last_notification_timestamp';

  // INTERVALLO MINIMO TRA LE NOTIFICHE (Anti-Spam)
  // 30 minuti = Non riceverai più di 1 notifica ogni mezz'ora, anche se il sistema controlla ogni minuto.
  static const int _cooldownMinutes = 60;

  bool _isInitialized = false;

  NotificationService(this._prefs);

  bool get areNotificationsEnabled => _prefs.getBool(_keyNotificationsEnabled) ?? true;

  // Inizializzazione COMPLETA (Foreground)
  Future<void> init() async {
    if (_isInitialized) return;
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await _notificationsPlugin.initialize(initializationSettings);
    await _requestPermissions();
    _isInitialized = true;
  }

  // Inizializzazione LIGHT (Background)
  Future<void> initBackground() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _requestPermissions() async {
    final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  Future<void> toggleNotifications(bool enabled) async {
    await _prefs.setBool(_keyNotificationsEnabled, enabled);
    if (!enabled) {
      await cancelAll();
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // LOGICA ANTI-SPAM
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> showHydrationReminder({String title = 'BodyDebt Alert 💧', String body = 'Energy drain detected! Drink water.'}) async {
    if (!areNotificationsEnabled) return;

    // 1. CONTROLLO COOLDOWN
    // Recuperiamo l'ultimo timestamp salvato (in millisecondi)
    // Usiamo una chiave generica su SharedPreferences perché PreferencesService non ha getInt,
    // quindi dobbiamo usare getDouble o modificare PreferencesService.
    // Per semplicità e robustezza, assumiamo che PreferencesService supporti salvataggio stringhe o double.
    // Qui userò la logica basata su stringa per massima compatibilità con il tuo codice attuale.

    String? lastTimeStr = _prefs.getString(_keyLastNotificationTime);
    if (lastTimeStr != null) {
      DateTime lastTime = DateTime.parse(lastTimeStr);
      final difference = DateTime.now().difference(lastTime).inMinutes;

      if (difference < _cooldownMinutes) {
        print("[NOTIFICATION BLOCKED] Anti-Spam attivo. Ultima notifica inviata $difference min fa.");
        return; // ESCI: Non inviare nulla
      }
    }

    // 2. CONFIGURAZIONE NOTIFICA
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'hydration_channel_id',
      'Hydration Reminders',
      channelDescription: 'Reminds you to drink water based on energy levels',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    // 3. INVIO
    await _notificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
    );

    // 4. SALVATAGGIO TIMESTAMP
    // Salviamo l'ora attuale come "Ultima Notifica Inviata"
    await _prefs.setString(_keyLastNotificationTime, DateTime.now().toIso8601String());

    print("[NOTIFICATION SENT] Popup inviato. Prossima notifica possibile tra $_cooldownMinutes min.");
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
    // Opzionale: Resettare il cooldown quando si disattiva?
    // await _prefs.remove(_keyLastNotificationTime);
  }
}
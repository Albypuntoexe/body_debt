import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'preferences_service.dart';

class NotificationService {
  final PreferencesService _prefs;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static const _keyNotificationsEnabled = 'notifications_enabled';
  bool _isInitialized = false;

  NotificationService(this._prefs);

  bool get areNotificationsEnabled => _prefs.getBool(_keyNotificationsEnabled) ?? true;

  // Inizializzazione COMPLETA (chiamata dalla UI nel main)
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

  // Inizializzazione LIGHT (chiamata dal Background Worker)
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

  // Metodo reso generico per essere usato dal background
  Future<void> showHydrationReminder({String title = 'BodyDebt Alert 💧', String body = 'Energy drain detected! Drink water.'}) async {
    if (!areNotificationsEnabled) return;

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

    await _notificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
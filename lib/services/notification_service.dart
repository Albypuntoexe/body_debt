import 'preferences_service.dart';

class NotificationService {
  final PreferencesService _prefs;

  static const _keyNotificationsEnabled = 'notifications_enabled';

  NotificationService(this._prefs);

  bool get areNotificationsEnabled => _prefs.getBool(_keyNotificationsEnabled) ?? true;

  Future<void> toggleNotifications(bool enabled) async {
    await _prefs.setBool(_keyNotificationsEnabled, enabled);
    if (!enabled) {
      cancelAll();
    } else {
      // In una app reale, qui rischeduleresti i job di background
      print("Notifications enabled: Scheduled background checks.");
    }
  }

  /// Invia una notifica immediata (Simulata per la UI)
  /// In produzione useresti: flutter_local_notifications plugin
  void showHydrationReminder() {
    if (!areNotificationsEnabled) return;
    print("[NOTIFICATION] 💧 È ora di bere un bicchiere d'acqua!");
  }

  void cancelAll() {
    print("[NOTIFICATION] All reminders cancelled.");
  }
}
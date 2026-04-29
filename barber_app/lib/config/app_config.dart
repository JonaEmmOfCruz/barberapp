class AppConfig {

  // ═══════════════════════════════════════════════
  //  SELECCIONA TU ENTORNO — comenta los demás
  // ═══════════════════════════════════════════════

  // ── Jeaustin (iPhone físico, red local) ──
  static const String ipAddress = '192.168.100.19';

  // ── Jonathan (iPhone físico, red local) ──
  // static const String ipAddress = '192.168.100.4';

  // ── Simulador iOS (localhost) ──
  // static const String ipAddress = 'localhost';

  // ── Emulador Android ──
  // static const String ipAddress = '10.0.2.2';

  // ═══════════════════════════════════════════════

  static const int port = 3000;

  static const String baseUrl = 'http://$ipAddress:$port';
  static const String apiUrl  = 'http://$ipAddress:$port/api';
}

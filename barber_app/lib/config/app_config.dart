class AppConfig {
  //static const String ipAddress = '192.168.100.4';
  //static const int port = 3000;


  static const String baseUrl = 'http://$ipAddress:$port';
  static const String apiUrl = 'http://$ipAddress:$port/api';
  
  // Para desarrollo en emulador Android, descomenta esta línea y comenta la de arriba
  // static const String ipAddress = '10.0.2.2';
  // static const int port = 3000;
  
   //Para desarrollo en simulador iOS, usa localhost
   static const String ipAddress = 'localhost';
   static const int port = 3000;
}
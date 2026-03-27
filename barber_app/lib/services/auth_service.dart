import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class AuthService {
  static const String baseUrl = AppConfig.apiUrl;
  
  // Login unificado con detección automática (usa /login/unified)
  static Future<Map<String, dynamic>> loginUnified({
    required String identifier,
    required String password,
  }) async {
    try {
      print('Intentando login unificado con: $identifier');
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login/unified'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': identifier,
          'password': password,
        }),
      );
      
      print('Respuesta código: ${response.statusCode}');
      print('Respuesta body: ${response.body}');
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        bool isBarber = data['isBarber'] ?? false;
        Map<String, dynamic>? userData = data['user']; // Datos completos del usuario
        
        // Extraer nombre (asumiendo campo 'nombre' o 'name')
        String userName = userData?['nombre'] ?? userData?['name'] ?? 'Usuario';
        
        print('✅ Login exitoso como ${isBarber ? 'BARBERO' : 'USUARIO'}');
        
        return {
          'success': true,
          'userId': data['userId'] ?? '',
          'userName': userName,      // <-- Nuevo campo
          'isBarber': isBarber,
          'userType': isBarber ? 'barber' : 'user',
          'message': data['message'] ?? 'Login exitoso',
          'user': userData,
        };
      } else {
        return {
          'success': false,
          'userId': null,
          'userName': null,
          'isBarber': false,
          'userType': null,
          'message': data['message'] ?? 'Usuario o contraseña incorrectos',
        };
      }
    } catch (e) {
      print('❌ Error de conexión: $e');
      return {
        'success': false,
        'userId': null,
        'userName': null,
        'isBarber': false,
        'userType': null,
        'message': 'Error de conexión: $e',
      };
    }
  }
  
  // Método original con isBarber (para compatibilidad)
  static Future<Map<String, dynamic>> loginUser({
    required String identifier,
    required String password,
    required bool isBarber,
  }) async {
    try {
      print('Intentando login: $identifier, isBarber: $isBarber');
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': identifier,
          'password': password,
          'isBarber': isBarber,
        }),
      );
      
      print('Respuesta código: ${response.statusCode}');
      print('Respuesta body: ${response.body}');
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        String userId = data['userId'] ?? '';
        Map<String, dynamic>? userData = data['user'];
        String userName = userData?['nombre'] ?? userData?['name'] ?? 'Usuario';
        
        print('✅ Login exitoso, userId: $userId');
        
        return {
          'success': true,
          'userId': userId,
          'userName': userName,
          'isBarber': isBarber,
          'message': data['message'] ?? 'Login exitoso',
          'user': userData,
        };
      } else {
        return {
          'success': false,
          'userId': null,
          'userName': null,
          'isBarber': false,
          'message': data['message'] ?? 'Error en el login',
        };
      }
    } catch (e) {
      print('❌ Error de conexión: $e');
      return {
        'success': false,
        'userId': null,
        'userName': null,
        'isBarber': false,
        'message': 'Error de conexión: $e',
      };
    }
  }
  
  static Future<bool> isAuthenticated() async {
    return false;
  }
  
  static Future<void> logout() async {
    print('Cerrando sesión');
  }
}
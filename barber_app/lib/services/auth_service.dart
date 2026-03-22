// services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class AuthService {
  // Usa la misma IP que en ApiService
  static const String baseUrl = AppConfig.apiUrl;
  
  // Login unificado - funciona para usuarios y barberos
  static Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
    required bool isBarber,
  }) async {
    try {
      print('Intentando login: $email, isBarber: $isBarber');
      
      // Usar el endpoint unificado /auth/login
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'), // ← Endpoint unificado
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,        // ← Cambiar de 'correo' a 'email'
          'password': password,
          'isBarber': isBarber,  // ← Agregar el parámetro isBarber
        }),
      );
      
      print('Respuesta código: ${response.statusCode}');
      print('Respuesta body: ${response.body}');
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        // Obtener el userId de la respuesta
        String userId = data['userId'] ?? '';
        
        print('✅ Login exitoso, userId: $userId');
        
        return {
          'success': true,
          'userId': userId,
          'message': data['message'] ?? 'Login exitoso',
          'user': data['user'],
        };
      } else {
        return {
          'success': false,
          'userId': null,
          'message': data['message'] ?? 'Error en el login',
        };
      }
    } catch (e) {
      print('❌ Error de conexión: $e');
      return {
        'success': false,
        'userId': null,
        'message': 'Error de conexión: $e',
      };
    }
  }
  
  // Login solo para usuarios (mantener por compatibilidad si es necesario)
  static Future<Map<String, dynamic>> loginUserOnly({
    required String email,
    required String password,
  }) async {
    return loginUser(
      email: email,
      password: password,
      isBarber: false,
    );
  }
  
  // Login solo para barberos (mantener por compatibilidad si es necesario)
  static Future<Map<String, dynamic>> loginBarberOnly({
    required String email,
    required String password,
  }) async {
    return loginUser(
      email: email,
      password: password,
      isBarber: true,
    );
  }
  
  // Verificar si el usuario está autenticado
  static Future<bool> isAuthenticated() async {
    // Aquí puedes verificar si hay un token guardado
    // Por ahora retornamos false
    return false;
  }
  
  // Cerrar sesión
  static Future<void> logout() async {
    // Aquí puedes limpiar el token guardado
    print('Cerrando sesión');
  }
}
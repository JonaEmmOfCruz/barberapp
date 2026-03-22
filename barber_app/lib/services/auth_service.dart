import 'dart:convert';
import 'package:http/http.dart' as http;
import '../main.dart'; // Para AppColors si es necesario
import '../config/app_config.dart';

class AuthService {
  // Usa la misma IP que en ApiService
  static const String baseUrl = AppConfig.apiUrl;
  
  // Login de usuario
  static Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
    required bool isBarber,
  }) async {
    try {
      print('Intentando login: $email, isBarber: $isBarber');
      
      final endpoint = isBarber ? 'auth/login/barber' : 'auth/login/user';
      
      final response = await http.post(
        Uri.parse('$baseUrl/$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'correo': email,
          'password': password,
        }),
      );
      
      print('Respuesta código: ${response.statusCode}');
      print('Respuesta body: ${response.body}');
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        // Obtener el usuario de la respuesta
        final userData = data['user'] ?? data['barber'] ?? data['data'] ?? {};
        
        // Extraer el ID del usuario (diferentes formatos posibles)
        String userId = '';
        if (userData is Map) {
          userId = userData['_id'] ?? userData['id'] ?? userData['uid'] ?? '';
        }
        
        // Guardar token si existe
        if (data['token'] != null) {
          print('Token recibido: ${data['token']}');
        }
        
        return {
          'success': true,
          'userId': userId, // ← IMPORTANTE: Agregamos el userId
          'message': data['message'] ?? 'Login exitoso',
          'user': userData,
          'token': data['token'],
        };
      } else {
        return {
          'success': false,
          'userId': null,
          'message': data['message'] ?? 'Error en el login',
        };
      }
    } catch (e) {
      print('Error de conexión: $e');
      return {
        'success': false,
        'userId': null,
        'message': 'Error de conexión: $e',
      };
    }
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
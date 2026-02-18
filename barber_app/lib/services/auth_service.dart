import 'dart:convert';
import 'package:http/http.dart' as http;
import '../main.dart'; // Para AppColors si es necesario

class AuthService {
  // Usa la misma IP que en ApiService
  static const String baseUrl = 'http://localhost:3000/api';
  
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
        // Guardar token si existe
        if (data['token'] != null) {
          // Aquí puedes guardar el token en SharedPreferences si lo deseas
          print('Token recibido: ${data['token']}');
        }
        
        return {
          'success': true,
          'message': data['message'] ?? 'Login exitoso',
          'user': data['user'] ?? data['barber'] ?? data['data'],
          'token': data['token'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error en el login',
        };
      }
    } catch (e) {
      print('Error de conexión: $e');
      return {
        'success': false,
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
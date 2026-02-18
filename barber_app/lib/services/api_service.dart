import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // PARA iOS SIMULATOR: usa localhost
  static const String baseUrl = 'http://localhost:3000/api';
  
  // PARA EMULADOR ANDROID: usa 10.0.2.2
  // static const String baseUrl = 'http://10.0.2.2:3000/api';
  
  // Registro de usuario
  static Future<Map<String, dynamic>> registerUser({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      print('Enviando registro: $name, $email, $phone');
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register/user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombre': name,
          'correo': email,
          'telefono': phone,
          'password': password,
        }),
      );
      
      print('Respuesta: ${response.statusCode}');
      print('Body: ${response.body}');
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'],
          'user': data['user']
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error en el registro'
        };
      }
    } catch (e) {
      print('Error de conexión: $e');
      return {
        'success': false,
        'message': 'Error de conexión: $e'
      };
    }
  }
  
  // Subir foto de perfil
  static Future<Map<String, dynamic>> uploadProfileImage({
    required String userId,
    required File imageFile,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/profile-image'),
      );
      
      request.fields['userId'] = userId;
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );
      
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var data = jsonDecode(responseData);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'imageUrl': data['imageUrl']
        };
      } else {
        return {
          'success': false,
          'message': data['message']
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al subir imagen: $e'
      };
    }
  }
}
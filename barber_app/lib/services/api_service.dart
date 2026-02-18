// lib/services/api_service.dart
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
        // Asegurarnos de que el id esté disponible
        final userId = data['user']?['_id'] ?? data['user']?['id'];
        
        return {
          'success': true,
          'message': data['message'] ?? 'Registro exitoso',
          'user': {
            'id': userId,
            ...data['user'] ?? {}
          }
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
      print('Subiendo imagen para usuario: $userId');
      print('Archivo: ${imageFile.path}');
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/profile-image'),
      );
      
      request.fields['userId'] = userId;
      request.files.add(
        await http.MultipartFile.fromPath(
          'image', 
          imageFile.path,
          filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );
      
      print('Enviando solicitud multipart...');
      var streamedResponse = await request.send();
      var responseData = await streamedResponse.stream.bytesToString();
      print('Respuesta código: ${streamedResponse.statusCode}');
      print('Respuesta body: $responseData');
      
      var data = jsonDecode(responseData);
      
      if (streamedResponse.statusCode == 200) {
        return {
          'success': true,
          'imageUrl': data['imageUrl']
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al subir imagen'
        };
      }
    } catch (e) {
      print('Error detallado: $e');
      return {
        'success': false,
        'message': 'Error al subir imagen: $e'
      };
    }
  }
  
  // Obtener imagen de perfil
  static Future<Map<String, dynamic>> getProfileImage(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/upload/profile-image/$userId'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'imageUrl': data['imageUrl']
        };
      } else {
        return {
          'success': false,
          'message': 'No se pudo obtener la imagen'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e'
      };
    }
  }
}
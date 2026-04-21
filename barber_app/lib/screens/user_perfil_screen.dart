import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barber_app/screens/landing_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/*String getServerIp() {
  if (Platform.isAndroid) return '10.0.2.2:3000';
  if (Platform.isIOS) return 'localhost:3000';
  return 'localhost:3000';
}*/

class UserPerfilScreen extends StatefulWidget {
  const UserPerfilScreen({super.key});

  @override
  State<UserPerfilScreen> createState() => _UserPerfilScreenState();
}

class _UserPerfilScreenState extends State<UserPerfilScreen> {
  File? _image;
  String? profileImageUrl;

  final ImagePicker _picker = ImagePicker();

  final TextEditingController nombreController = TextEditingController();
  final TextEditingController correoController = TextEditingController();
  final TextEditingController telefonoController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    String userId = prefs.getString('userId') ?? '';
   

    setState(() {
      profileImageUrl = prefs.getString('profileImage'); 
    });

    if (userId.isEmpty) return;

    try {
      // (Verifica si en tu backend la ruta lleva o no el "/auth"):
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/get-user/$userId'),
        headers: {
          "Accept": "application/json",
        }, // Esto obliga a que responda JSON
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = data['user'];

        setState(() {
          nombreController.text = user['nombre'] ?? '';
          correoController.text = user['correo'] ?? '';
          telefonoController.text = user['telefono'] ?? '';
          profileImageUrl = user['profileImage'];
        });
      }
    } catch (e) {
      print("Error cargando usuario: $e");
    }
  }

  Future<void> _pickImage() async {
    final XFile? selectedImage = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (selectedImage != null) {
      setState(() {
        _image = File(selectedImage.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.blue,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Perfil",
          style: TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: ListView(
          children: [
            const SizedBox(height: 10),

            // Avatar
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Column(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue[100]!, width: 2),
                        image: _image != null
                            ? DecorationImage(
                                image: FileImage(_image!),
                                fit: BoxFit.cover,
                              )
                            : (profileImageUrl != null &&
                                  profileImageUrl!.isNotEmpty)
                            ? DecorationImage(
                                image: NetworkImage(
                                  'http://localhost:3000$profileImageUrl',
                                ),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child:
                          (_image == null &&
                              (profileImageUrl == null ||
                                  profileImageUrl!.isEmpty))
                          ? const Icon(
                              Icons.camera_alt,
                              size: 35,
                              color: Colors.blue,
                            )
                          : null,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Toca para cambiar foto",
                      style: TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            _buildInputField(
              "Nombre Completo",
              "Nombre",
              Icons.person,
              controller: nombreController,
            ),
            _buildInputField(
              "Correo Electrónico",
              "ejemplo@email.com",
              Icons.email,
              controller: correoController,
            ),
            _buildInputField(
              "Teléfono",
              "+52 33 1234 5678",
              Icons.phone_iphone,
              controller: telefonoController,
            ),
            _buildInputField(
              "Contraseña",
              "*******",
              Icons.lock,
              isPassword: true,
              controller: passwordController,
            ),
            _buildInputField(
              "Confirmar Contraseña",
              "*******",
              Icons.lock,
              isPassword: true,
              controller: confirmPasswordController,
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: _updateUserInfo,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text("Confirmar Información"),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => LandingScreen()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Cerrar sesión"),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _updateUserInfo() async {
    String nombre = nombreController.text;
    String correo = correoController.text;
    String telefono = telefonoController.text;
    String password = passwordController.text;
    String confirmPassword = confirmPasswordController.text;

    if (password.isNotEmpty && password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Las contraseñas no coinciden")),
      );
      return;
    }

    if (nombre.isEmpty &&
        correo.isEmpty &&
        telefono.isEmpty &&
        password.isEmpty &&
        _image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Debes modificar al menos un campo")),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    String userId = prefs.getString('userId') ?? '';
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: usuario no identificado")),
      );
      return;
    }

    try {
      // Actualizar datos
      final response = await http.put(
        Uri.parse('http://localhost:3000/api/auth/update-user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "userId": userId,
          "nombre": nombre,
          "email": correo,
          "telefono": telefono,
          if (password.isNotEmpty) "password": password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        // Subir imagen si existe
        if (_image != null) {
          var request = http.MultipartRequest(
            'POST',
            Uri.parse('http://localhost:3000/api/upload/profile-image'),
          );
          request.fields['userId'] = userId;
          request.files.add(
            await http.MultipartFile.fromPath('image', _image!.path),
          );

          var res = await request.send();
          var responseBody = await res.stream.bytesToString();

          print("STATUS: ${res.statusCode}");
          print("BODY: $responseBody");

          if (res.statusCode == 200) {
            print("✅ Imagen subida");
            // Actualizar URL directamente desde respuesta del servidor si viene
            final resData = jsonDecode(responseBody);
            if (resData['success'] == true && resData['filePath'] != null) {
              setState(() {
                
                profileImageUrl = resData['filePath'];

                print(profileImageUrl);

              });
            }
          } else {
            print("❌ Error subiendo imagen");
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Información actualizada correctamente"),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Error al actualizar")),
        );
      }
    } catch (e) {
      print("ERROR: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error de conexión con el servidor")),
      );
    }
  }

  Widget _buildInputField(
    String label,
    String hint,
    IconData icon, {
    bool isPassword = false,
    required TextEditingController controller,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: TextField(
              controller: controller,
              obscureText: isPassword,
              decoration: InputDecoration(
                hintText: hint,
                prefixIcon: Icon(icon),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

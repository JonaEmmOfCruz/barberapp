import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barber_app/screens/landing_screen.dart';

class UserPerfilScreen extends StatefulWidget {
  const UserPerfilScreen({super.key});

  @override
  State<UserPerfilScreen> createState() => _UserPerfilScreenState();
}

class _UserPerfilScreenState extends State<UserPerfilScreen> {
  File? _image;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? selectedImage =
        await _picker.pickImage(source: ImageSource.gallery);
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
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.blue, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Perfil",
          style: TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              fontSize: 18),
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
                        border:
                            Border.all(color: Colors.blue[100]!, width: 2),
                        image: _image != null
                            ? DecorationImage(
                                image: FileImage(_image!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _image == null
                          ? const Icon(Icons.camera_alt,
                              size: 35, color: Colors.blue)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Toca para cambiar foto",
                      style: TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            // Inputs
            _buildInputField("Nombre Completo", "Nombre", Icons.person),
            _buildInputField(
                "Correo Electrónico", "ejemplo@email.com", Icons.email),
            _buildInputField(
                "Teléfono", "+00 00 1234 5678", Icons.phone_iphone),
            _buildInputField("Contraseña", "*******", Icons.lock,
                isPassword: true),
            _buildInputField("Confirmar Contraseña", "*******",
                Icons.lock,
                isPassword: true),

            const SizedBox(height: 20),

            // Botón guardar
            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
                child: const Text("Confirmar Información"),
              ),
            ),

            const SizedBox(height: 10),

            // Botón cerrar sesión
            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  final prefs =
                      await SharedPreferences.getInstance();
                  await prefs.clear();

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (_) => LandingScreen()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text("Cerrar sesión"),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, String hint, IconData icon,
      {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey)),
          const SizedBox(height: 8),
          Container(
            height: 60,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: TextField(
              obscureText: isPassword,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                    color: Colors.blue[100], fontSize: 14),
                prefixIcon: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.blue[50],
                    child:
                        Icon(icon, color: Colors.blue, size: 16),
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 20),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.blue[50]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Colors.blueAccent, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
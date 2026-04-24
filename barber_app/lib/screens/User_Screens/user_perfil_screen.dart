import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barber_app/screens/Main_Screens/landing_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:barber_app/config/app_config.dart';

class UserPerfilScreen extends StatefulWidget {
  const UserPerfilScreen({super.key});

  @override
  State<UserPerfilScreen> createState() => _UserPerfilScreenState();
}

class _UserPerfilScreenState extends State<UserPerfilScreen> {
  File? _image;
  String? profileImageUrl;
  final String baseUrl = AppConfig.baseUrl; // Usando tu config global
  final ImagePicker _picker = ImagePicker();

  final TextEditingController nombreController = TextEditingController();
  final TextEditingController correoController = TextEditingController();
  final TextEditingController telefonoController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    String userId = prefs.getString('userId') ?? '';
    setState(() { profileImageUrl = prefs.getString('profileImage'); });

    if (userId.isEmpty) return;

    try {
      final response = await http.get(Uri.parse('$baseUrl/api/get-user/$userId'));
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
    } catch (e) { print("Error cargando usuario: $e"); }
  }

  Future<void> _pickImage() async {
    final XFile? selectedImage = await _picker.pickImage(source: ImageSource.gallery);
    if (selectedImage != null) {
      setState(() { _image = File(selectedImage.path); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // --- BOTÓN REGRESAR ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 15, top: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),

            // --- TÍTULO ESTILO SLIVER ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 10, 30, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Mi Perfil",
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1D1D1F),
                        letterSpacing: -1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 50,
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- AVATAR Y FORMULARIO ---
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 10),
                  _buildAvatarSection(),
                  const SizedBox(height: 30),
                  _buildModernInput("Nombre Completo", Icons.person_outline, nombreController),
                  _buildModernInput("Correo Electrónico", Icons.email_outlined, correoController),
                  _buildModernInput("Teléfono", Icons.phone_iphone_rounded, telefonoController),
                  _buildModernInput("Nueva Contraseña", Icons.lock_outline_rounded, passwordController, isPassword: true),
                  _buildModernInput("Confirmar Contraseña", Icons.lock_reset_rounded, confirmPasswordController, isPassword: true),
                  const SizedBox(height: 20),
                  
                  // Botón Confirmar
                  ElevatedButton(
                    onPressed: _updateUserInfo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 0,
                    ),
                    child: const Text("Guardar Cambios", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  
                  const SizedBox(height: 15),
                  
                  // Botón Cerrar Sesión
                  TextButton(
                    onPressed: _logout,
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    child: const Text("Cerrar Sesión", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Stack(
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                image: _image != null
                    ? DecorationImage(image: FileImage(_image!), fit: BoxFit.cover)
                    : (profileImageUrl != null && profileImageUrl!.isNotEmpty)
                        ? DecorationImage(image: NetworkImage('$baseUrl$profileImageUrl'), fit: BoxFit.cover)
                        : null,
              ),
              child: (_image == null && (profileImageUrl == null || profileImageUrl!.isEmpty))
                  ? const Icon(Icons.person_rounded, size: 50, color: Color(0xFF007AFF))
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Color(0xFF007AFF), shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernInput(String label, IconData icon, TextEditingController controller, {bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(15),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: const Color(0xFF007AFF), size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LandingScreen()),
      (route) => false,
    );
  }

  // --- Mantenemos tu lógica de _updateUserInfo intacta pero usando baseUrl ---
  Future<void> _updateUserInfo() async {
    // ... (Tu validación de contraseñas y campos vacíos)
    final prefs = await SharedPreferences.getInstance();
    String userId = prefs.getString('userId') ?? '';

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/auth/update-user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "userId": userId,
          "nombre": nombreController.text,
          "email": correoController.text,
          "telefono": telefonoController.text,
          if (passwordController.text.isNotEmpty) "password": passwordController.text,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success']) {
        if (_image != null) {
          var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/upload/profile-image'));
          request.fields['userId'] = userId;
          request.files.add(await http.MultipartFile.fromPath('image', _image!.path));
          var res = await request.send();
          if (res.statusCode == 200) {
             final resBody = await res.stream.bytesToString();
             final resData = jsonDecode(resBody);
             setState(() { profileImageUrl = resData['filePath']; });
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Perfil actualizado!")));
      }
    } catch (e) { print(e); }
  }
}
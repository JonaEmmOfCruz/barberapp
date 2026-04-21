import 'dart:io';
import 'package:barber_app/screens/landing_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; 
import 'package:http/http.dart' as http;

class BarberProfileScreen extends StatefulWidget {
  final String barberId;
  final String barberName;

  const BarberProfileScreen({
    super.key,
    required this.barberId,
    required this.barberName,
  });

  @override
  State<BarberProfileScreen> createState() => _BarberProfileScreenState();
}

class _BarberProfileScreenState extends State<BarberProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Archivos locales para subir
  File? _profileImage;
  File? _licenseImage;
  File? _vehiclePhoto;
  File? _platePhoto;

  // URLs para mostrar lo guardado en BD
  String? _profileImageUrl;
  String? _licenseImageUrl;
  String? _vehiclePhotoUrl;
  String? _plateImageUrl;

  // Controladores y variables de estado
  String? _vehicleType;
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();

  final picker = ImagePicker();
  bool _isLoading = false;
  final String baseUrl = "http://localhost:3000"; // Cambiar a 10.0.2.2 si usas Android

  final List<String> _vehicleTypes = ['Auto', 'Motocicleta', 'Bicicleta', 'Patinete'];
  bool get _showVehicleDetails => _vehicleType == 'Auto' || _vehicleType == 'Motocicleta';

  @override
  void initState() {
    super.initState();
    _loadBarberData(); // Carga automática al entrar
  }

  // --- FUNCIÓN PARA CARGAR DATOS CONSISTENTES ---
  Future<void> _loadBarberData() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/upload/barber-documents/${widget.barberId}'),
      );

      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        final data = res['data'];

        setState(() {
          _vehicleType = data['vehicleType'];
          _brandController.text = data['vehicleBrand'] ?? '';
          _plateController.text = data['vehiclePlate'] ?? '';
          _profileImageUrl = data['profileImage'];
          _licenseImageUrl = data['licenseImage'];
          _vehiclePhotoUrl = data['vehiclePhoto'];
          _plateImageUrl = data['platePhoto'];
        });
      }
    } catch (e) {
      print("Error al cargar datos: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(ImageSource source, Function(File?) setImage) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        setImage(File(pickedFile.path));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.blue, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Perfil',
          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildProfileCircle(),
                  const SizedBox(height: 32),

                  _buildSectionLabel('TIPO DE VEHÍCULO'),
                  _buildDropdown(Icons.directions_car_filled_outlined),
                  const SizedBox(height: 20),

                  if (_showVehicleDetails) ...[
                    _buildTextField(
                      label: 'MARCA DEL VEHÍCULO',
                      hint: 'Escribe la marca',
                      icon: Icons.branding_watermark_outlined,
                      controller: _brandController,
                    ),
                    _buildTextField(
                      label: 'PLACA / MATRÍCULA',
                      hint: '00 00 000',
                      icon: Icons.pin_outlined,
                      controller: _plateController,
                    ),
                  ],

                  _buildImagePickerStyled('LICENCIA DE CONDUCIR', _licenseImage, _licenseImageUrl, Icons.badge_outlined, (f) => _licenseImage = f),
                  if (_showVehicleDetails) ...[
                    _buildImagePickerStyled('FOTO DEL VEHÍCULO', _vehiclePhoto, _vehiclePhotoUrl, Icons.directions_car, (f) => _vehiclePhoto = f),
                    _buildImagePickerStyled('FOTO DE LA PLACA', _platePhoto, _plateImageUrl, Icons.camera_alt, (f) => _platePhoto = f),
                  ],

                  const SizedBox(height: 40),

                  // BOTÓN GUARDAR
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Guardar Información',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
                            ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // BOTÓN CERRAR SESIÓN (Mismo tamaño)
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => LandingScreen()),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: const Text(
                        "Cerrar sesión",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildProfileCircle() {
    ImageProvider? image;
    if (_profileImage != null) {
      image = FileImage(_profileImage!);
    } else if (_profileImageUrl != null) {
      image = NetworkImage('$baseUrl$_profileImageUrl');
    }

    return GestureDetector(
      onTap: () => _showImagePickerDialog((f) => setState(() => _profileImage = f)),
      child: Column(
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue.shade100, width: 4),
              color: Colors.blue.shade50,
              image: image != null ? DecorationImage(image: image, fit: BoxFit.cover) : null,
            ),
            child: image == null ? const Icon(Icons.add_a_photo, size: 40, color: Colors.blue) : null,
          ),
          const SizedBox(height: 10),
          const Text('Editar foto de perfil', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
        ),
      ),
    );
  }

  Widget _buildTextField({required String label, required String hint, required IconData icon, required TextEditingController controller}) {
    return Column(
      children: [
        _buildSectionLabel(label),
        TextFormField(
          controller: controller,
          decoration: _inputDecoration(hint, icon),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDropdown(IconData icon) {
    return DropdownButtonFormField<String>(
      value: _vehicleType,
      decoration: _inputDecoration('Selecciona tipo', icon),
      items: _vehicleTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
      onChanged: (value) => setState(() => _vehicleType = value),
    );
  }

  Widget _buildImagePickerStyled(String label, File? localFile, String? networkUrl, IconData icon, Function(File?) onImagePicked) {
    return Column(
      children: [
        _buildSectionLabel(label),
        GestureDetector(
          onTap: () => _showImagePickerDialog((f) => setState(() => onImagePicked(f))),
          child: Container(
            height: 130,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.02),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.blue.shade100, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: localFile != null
                  ? Image.file(localFile, fit: BoxFit.cover)
                  : (networkUrl != null)
                      ? Image.network('$baseUrl$networkUrl', fit: BoxFit.cover)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, color: Colors.blue.shade200, size: 40),
                            const SizedBox(height: 8),
                            Text('Subir imagen', style: TextStyle(color: Colors.blue.shade300, fontSize: 12)),
                          ],
                        ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: Colors.blue.withOpacity(0.03),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      prefixIcon: Icon(icon, color: Colors.blue, size: 22),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.blue.shade50, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
    );
  }

  void _showImagePickerDialog(Function(File?) onImagePicked) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue), 
              title: const Text('Cámara'), 
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera, onImagePicked); }
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue), 
              title: const Text('Galería'), 
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery, onImagePicked); }
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    setState(() => _isLoading = true);

    try {
      var uri = Uri.parse('$baseUrl/api/upload/barber-documents');
      var request = http.MultipartRequest('POST', uri);

      request.fields['barberId'] = widget.barberId;
      request.fields['vehicleType'] = _vehicleType ?? '';
      request.fields['vehicleBrand'] = _brandController.text;
      request.fields['vehiclePlate'] = _plateController.text;

      if (_profileImage != null) request.files.add(await http.MultipartFile.fromPath('profileImage', _profileImage!.path));
      if (_licenseImage != null) request.files.add(await http.MultipartFile.fromPath('licenseImage', _licenseImage!.path));
      if (_vehiclePhoto != null) request.files.add(await http.MultipartFile.fromPath('vehiclePhoto', _vehiclePhoto!.path));
      if (_platePhoto != null) request.files.add(await http.MultipartFile.fromPath('platePhoto', _platePhoto!.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: Colors.green, content: Text('¡Documentación guardada con éxito!'))
          );
          _loadBarberData(); // Recarga para mostrar las URLs recién guardadas
        }
      } else {
        print("Error del servidor: ${response.body}");
      }
    } catch (e) {
      print("Error de conexión: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
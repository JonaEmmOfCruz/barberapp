import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:barber_app/config/app_config.dart';

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

  // Datos del formulario originales
  File? _profileImage;
  File? _licenseImage;
  String? _vehicleType;
  String? _vehicleBrand;
  String? _vehiclePlate;
  File? _vehiclePhoto;
  File? _platePhoto;

  final picker = ImagePicker();
  bool _isLoading = false;

  final List<String> _vehicleTypes = ['Auto', 'Motocicleta', 'Bicicleta', 'Patinete'];
  bool get _showVehicleDetails => _vehicleType == 'Auto' || _vehicleType == 'Motocicleta';

  // --- FUNCIÓN QUE FALTABA ---
  Future<void> _pickImage(ImageSource source, Function(File?) setImage) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        setImage(File(pickedFile.path));
      });
    }
  }

  // --- DISEÑO ---

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
                      onChanged: (v) => _vehicleBrand = v,
                    ),
                    _buildTextField(
                      label: 'PLACA / MATRÍCULA',
                      hint: '00 00 000',
                      icon: Icons.pin_outlined,
                      onChanged: (v) => _vehiclePlate = v,
                    ),
                  ],

                  _buildImagePickerStyled('LICENCIA DE CONDUCIR', _licenseImage, Icons.badge_outlined, (f) => _licenseImage = f),
                  if (_showVehicleDetails) ...[
                    _buildImagePickerStyled('FOTO DEL VEHÍCULO', _vehiclePhoto, Icons.directions_car, (f) => _vehiclePhoto = f),
                    _buildImagePickerStyled('FOTO DE LA PLACA', _platePhoto, Icons.camera_alt, (f) => _platePhoto = f),
                  ],

                  const SizedBox(height: 40),

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
    return GestureDetector(
      onTap: () => _showImagePickerDialog((f) => _profileImage = f),
      child: Column(
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue.shade100, width: 4),
              color: Colors.blue.shade50,
            ),
            child: _profileImage != null
                ? ClipRRect(borderRadius: BorderRadius.circular(60), child: Image.file(_profileImage!, fit: BoxFit.cover))
                : const Icon(Icons.add_a_photo, size: 40, color: Colors.blue),
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

  Widget _buildTextField({required String label, required String hint, required IconData icon, Function(String)? onChanged}) {
    return Column(
      children: [
        _buildSectionLabel(label),
        TextFormField(
          onChanged: onChanged,
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

  Widget _buildImagePickerStyled(String label, File? image, IconData icon, Function(File?) onImagePicked) {
    return Column(
      children: [
        _buildSectionLabel(label),
        GestureDetector(
          onTap: () => _showImagePickerDialog(onImagePicked),
          child: Container(
            height: 130,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.02),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.blue.shade100, width: 2),
            ),
            child: image != null
                ? ClipRRect(borderRadius: BorderRadius.circular(13), child: Image.file(image, fit: BoxFit.cover))
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
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isLoading = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.blue, content: Text('Perfil guardado exitosamente')));
  }
}
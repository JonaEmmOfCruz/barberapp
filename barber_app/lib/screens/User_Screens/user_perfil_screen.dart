import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:barber_app/config/app_config.dart';
import 'package:barber_app/screens/Main_Screens/landing_screen.dart';

// ─────────────────────────────────────────────
//  COLORES
// ─────────────────────────────────────────────
const _kAzul      = Color(0xFF0D3FA6);
const _kAzulMedio = Color(0xFF1A5FD4);
const _kNavy      = Color(0xFF1A1A2E);
const _kBlanco    = Colors.white;
const _kFondo     = Color(0xFFF0F4FF);
const _kRojo      = Color(0xFFE8202A);

class UserPerfilScreen extends StatefulWidget {
    final VoidCallback? onBack;
  const UserPerfilScreen({super.key, this.onBack});

  @override
  State<UserPerfilScreen> createState() => _UserPerfilScreenState();
}

class _UserPerfilScreenState extends State<UserPerfilScreen> {
  final String       baseUrl  = AppConfig.baseUrl;
  final ImagePicker  _picker  = ImagePicker();

  File?   _image;
  String? _profileImageUrl;
  String? _userId;
  bool    _isLoading = false;

  final _nombreCtrl   = TextEditingController();
  final _correoCtrl   = TextEditingController();
  final _telefonoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  // ── CARGAR DATOS ──────────────────────────────────────────────────
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId') ?? '';
    setState(() => _profileImageUrl = prefs.getString('profileImage'));
    if (_userId!.isEmpty) return;
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/auth/get-user/$_userId'));
      if (res.statusCode == 200) {
        final user = jsonDecode(res.body)['user'];
        setState(() {
          _nombreCtrl.text   = user['nombre']   ?? '';
          _correoCtrl.text   = user['correo']   ?? '';
          _telefonoCtrl.text = user['telefono'] ?? '';
          _profileImageUrl   = user['profileImage'];
        });
      }
    } catch (e) {
      debugPrint('Error cargando usuario: $e');
    }
  }

  // ── GUARDAR ───────────────────────────────────────────────────────
  Future<void> _guardar() async {
    if (_userId == null || _userId!.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      // Actualizar datos personales
      final res = await http.put(
        Uri.parse('$baseUrl/api/auth/update-user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId':   _userId,
          'nombre':   _nombreCtrl.text.trim(),
          'telefono': _telefonoCtrl.text.trim(),
        }),
      );

      if (res.statusCode == 200) {
        // Subir foto si hay nueva
        if (_image != null) {
          final request = http.MultipartRequest(
            'POST', Uri.parse('$baseUrl/api/upload/profile-image'));
          request.fields['userId'] = _userId!;
          request.files.add(await http.MultipartFile.fromPath('image', _image!.path));
          final uploadRes = await request.send();
          if (uploadRes.statusCode == 200) {
            final body    = await uploadRes.stream.bytesToString();
            final data    = jsonDecode(body);
            final prefs   = await SharedPreferences.getInstance();
            await prefs.setString('profileImage', data['filePath']);
            setState(() => _profileImageUrl = data['filePath']);
          }
        }
        _mostrarSnack('Perfil actualizado', esExito: true);
      } else {
        _mostrarSnack('Error al actualizar');
      }
    } catch (e) {
      _mostrarSnack('Error de conexión');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── CAMBIAR CONTRASEÑA ────────────────────────────────────────────
  void _mostrarCambiarContrasena() {
    final actualCtrl  = TextEditingController();
    final nuevaCtrl   = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool verActual    = false;
    bool verNueva     = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 24, left: 20, right: 20,
          ),
          decoration: const BoxDecoration(
            color: _kBlanco,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(children: [
                Container(width: 4, height: 20,
                  decoration: BoxDecoration(color: _kAzulMedio,
                    borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                const Text('Cambiar contraseña',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kNavy)),
              ]),
              const SizedBox(height: 20),
              _buildPasswordField('Contraseña actual', actualCtrl, verActual,
                () => setModal(() => verActual = !verActual)),
              const SizedBox(height: 12),
              _buildPasswordField('Nueva contraseña', nuevaCtrl, verNueva,
                () => setModal(() => verNueva = !verNueva)),
              const SizedBox(height: 12),
              _buildPasswordField('Confirmar nueva', confirmCtrl, verNueva, () {}),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kAzulMedio,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    if (nuevaCtrl.text != confirmCtrl.text) {
                      _mostrarSnack('Las contraseñas no coinciden');
                      return;
                    }
                    if (nuevaCtrl.text.length < 6) {
                      _mostrarSnack('Mínimo 6 caracteres');
                      return;
                    }
                    Navigator.pop(context);
                    await _cambiarContrasena(nuevaCtrl.text);
                  },
                  child: const Text('Cambiar contraseña',
                    style: TextStyle(color: _kBlanco, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cambiarContrasena(String nueva) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/api/auth/update-user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': _userId, 'password': nueva}),
      );
      if (res.statusCode == 200) {
        _mostrarSnack('Contraseña actualizada', esExito: true);
      } else {
        _mostrarSnack('Error al cambiar contraseña');
      }
    } catch (_) {
      _mostrarSnack('Error de conexión');
    }
  }

  // ── EDITAR CAMPO ──────────────────────────────────────────────────
  void _editarCampo(String label, TextEditingController ctrl,
      {TextInputType tipo = TextInputType.text}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 24, left: 20, right: 20,
        ),
        decoration: const BoxDecoration(
          color: _kBlanco,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              keyboardType: tipo,
              autofocus: true,
              decoration: InputDecoration(
                labelText: label,
                filled: true,
                fillColor: _kFondo,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kAzulMedio, width: 1.5)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAzulMedio,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                onPressed: () { setState(() {}); Navigator.pop(context); },
                child: const Text('Listo',
                  style: TextStyle(color: _kBlanco, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── CERRAR SESIÓN ─────────────────────────────────────────────────
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
      MaterialPageRoute(builder: (_) => const LandingScreen()),
      (route) => false);
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kFondo,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildSeccion('Información personal')),
          SliverToBoxAdapter(child: _buildCardPersonal()),
          SliverToBoxAdapter(child: _buildSeccion('Seguridad')),
          SliverToBoxAdapter(child: _buildCardSeguridad()),
          SliverToBoxAdapter(child: const SizedBox(height: 16)),
          SliverToBoxAdapter(child: _buildBotonGuardar()),
          SliverToBoxAdapter(child: _buildBotonCerrarSesion()),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: _kAzul,
      width: double.infinity,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () {
  if (widget.onBack != null) {
    widget.onBack!();
  } else {
    Navigator.pop(context);
  }
},
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _kBlanco.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, color: _kBlanco, size: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Avatar
              GestureDetector(
                onTap: () async {
                  final f = await _picker.pickImage(source: ImageSource.gallery);
                  if (f != null) setState(() => _image = File(f.path));
                },
                child: Stack(
                  children: [
                    Container(
                      width: 88, height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _kBlanco.withOpacity(0.4), width: 3),
                        color: _kBlanco.withOpacity(0.2),
                        image: _image != null
                            ? DecorationImage(image: FileImage(_image!), fit: BoxFit.cover)
                            : _profileImageUrl != null
                                ? DecorationImage(
                                    image: NetworkImage('$baseUrl$_profileImageUrl'),
                                    fit: BoxFit.cover)
                                : null,
                      ),
                      child: (_image == null && _profileImageUrl == null)
                          ? const Icon(Icons.person, color: _kBlanco, size: 44)
                          : null,
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 26, height: 26,
                        decoration: const BoxDecoration(color: _kBlanco, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: _kAzul, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(_nombreCtrl.text.isNotEmpty ? _nombreCtrl.text : 'Usuario',
                style: const TextStyle(color: _kBlanco, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text(_correoCtrl.text,
                style: TextStyle(color: _kBlanco.withOpacity(0.6), fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  // ── CARD PERSONAL ─────────────────────────────────────────────────
  Widget _buildCardPersonal() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        Container(
          decoration: BoxDecoration(
            color: _kBlanco,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE0E8FF), width: 0.5),
          ),
          child: Column(children: [
            _buildFila('Nombre', _nombreCtrl.text.isNotEmpty ? _nombreCtrl.text : 'Sin nombre',
              onTap: () => _editarCampo('Nombre', _nombreCtrl)),
            _buildFila('Teléfono', _telefonoCtrl.text.isNotEmpty ? _telefonoCtrl.text : 'Sin teléfono',
              onTap: () => _editarCampo('Teléfono', _telefonoCtrl, tipo: TextInputType.phone)),
            _buildFila('Correo', _correoCtrl.text, muted: true),
          ]),
        ),
        const SizedBox(height: 14),
      ]),
    );
  }

  // ── CARD SEGURIDAD ────────────────────────────────────────────────
  Widget _buildCardSeguridad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        Container(
          decoration: BoxDecoration(
            color: _kBlanco,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE0E8FF), width: 0.5),
          ),
          child: _buildFila('Contraseña', '••••••••',
            onTap: _mostrarCambiarContrasena),
        ),
        const SizedBox(height: 14),
      ]),
    );
  }

  Widget _buildFila(String label, String valor, {VoidCallback? onTap, bool muted = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: const Color(0xFFF0F4FF), width: 0.5))),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: muted ? Colors.grey.shade100 : const Color(0xFFEEF4FF),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(
                onTap != null ? Icons.edit_outlined : Icons.lock_outline,
                color: muted ? Colors.grey.shade400 : _kAzulMedio, size: 15),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(valor,
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: muted ? Colors.grey.shade400 : _kNavy)),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
          ],
        ),
      ),
    );
  }

  // ── SECCIÓN LABEL ─────────────────────────────────────────────────
  Widget _buildSeccion(String titulo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(children: [
        Container(width: 4, height: 14,
          decoration: BoxDecoration(color: _kAzulMedio, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(titulo,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: Colors.grey.shade500, letterSpacing: 0.5)),
      ]),
    );
  }

  // ── BOTONES ───────────────────────────────────────────────────────
  Widget _buildBotonGuardar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _kAzulMedio,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 0,
          ),
          onPressed: _isLoading ? null : _guardar,
          child: _isLoading
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: _kBlanco, strokeWidth: 2))
              : const Text('Guardar cambios',
                  style: TextStyle(color: _kBlanco, fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ),
    );
  }

  Widget _buildBotonCerrarSesion() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFFFCDD2), width: 0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: _logout,
          child: const Text('Cerrar sesión',
            style: TextStyle(color: _kRojo, fontWeight: FontWeight.w600, fontSize: 15)),
        ),
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────
  Widget _buildPasswordField(String label, TextEditingController ctrl,
      bool visible, VoidCallback onToggle) {
    return TextField(
      controller: ctrl,
      obscureText: !visible,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: _kFondo,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kAzulMedio, width: 1.5)),
        suffixIcon: IconButton(
          icon: Icon(visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.grey.shade400, size: 20),
          onPressed: onToggle,
        ),
      ),
    );
  }

  void _mostrarSnack(String msg, {bool esExito = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: esExito ? Colors.green.shade700 : _kNavy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}
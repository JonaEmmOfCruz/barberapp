import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:barber_app/config/app_config.dart';
import 'package:barber_app/screens/Main_Screens/landing_screen.dart';
import 'barber_home_screen.dart';

const _kRojo      = Color(0xFFE8202A);
const _kNegro     = Color(0xFF1A1A1A);
const _kGrisFondo = Color(0xFFF5F5F5);
const _kBlanco    = Colors.white;

class BarberProfileScreen extends StatefulWidget {
  final String barberId;
  final String barberName;
  final VoidCallback onBack;

  const BarberProfileScreen({
    super.key,
    required this.barberId,
    required this.barberName,
    required this.onBack,
  });

  @override
  State<BarberProfileScreen> createState() => _BarberProfileScreenState();
}

class _BarberProfileScreenState extends State<BarberProfileScreen> {
  final String baseUrl = AppConfig.baseUrl;
  final picker         = ImagePicker();
  bool _isLoading      = false;

  String? _nombre;
  String? _email;
  String? _telefono;
  int     _cambiosNombre    = 0;
  DateTime? _ultimoCambioNombre;

  final _nombreController   = TextEditingController();
  final _telefonoController = TextEditingController();
  final _colorController    = TextEditingController();

  String? _vehicleType;
  final _brandController = TextEditingController();
  final _plateController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController  = TextEditingController();

  File? _profileImage;
  File? _licenseImage;
  File? _ineFrente;
  File? _ineReverso;
  File? _vehiclePhoto;
  File? _platePhoto;

  String? _profileImageUrl;
  String? _licenseImageUrl;
  String? _ineFrenteUrl;
  String? _ineReversoUrl;
  String? _vehiclePhotoUrl;
  String? _platePhotoUrl;

  List<String> _camposFaltantes = [];

  // ── Zona de trabajo ──────────────────────
  int          _radioKm        = 10;
  List<String> _zonasFavoritas = [];

  final List<String> _vehicleTypes = ['Auto', 'Motocicleta', 'Bicicleta', 'Patín Eléctrico'];

  bool get _esMotorizado => _vehicleType == 'Auto' || _vehicleType == 'Motocicleta';
  bool get _puedeIrAlHome => _camposFaltantes.isEmpty;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _colorController.dispose();
    _brandController.dispose();
    _plateController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final barberRes = await http.get(Uri.parse('$baseUrl/api/auth/barber/${widget.barberId}'));
      if (barberRes.statusCode == 200) {
        final data = json.decode(barberRes.body)['barber'];
        setState(() {
          _nombre   = data['nombre'];
          _email    = data['email'];
          _telefono = data['telefono'];
          _cambiosNombre = data['cambiosNombre'] ?? 0;
          _nombreController.text   = data['nombre']   ?? '';
          _telefonoController.text = data['telefono'] ?? '';
          if (data['ultimoCambioNombre'] != null) {
            _ultimoCambioNombre = DateTime.tryParse(data['ultimoCambioNombre']);
          }
        });
      }

      final docsRes = await http.get(Uri.parse('$baseUrl/api/upload/barber-documents/${widget.barberId}'));
      if (docsRes.statusCode == 200) {
        final data = json.decode(docsRes.body)['data'];
        setState(() {
          _vehicleType          = data['vehicleType'];
          _brandController.text = data['vehicleBrand'] ?? '';
          _plateController.text = data['vehiclePlate'] ?? '';
          _modelController.text = data['vehicleModel'] ?? '';
          _yearController.text  = data['vehicleYear']  ?? '';
          _colorController.text = data['vehicleColor'] ?? '';
          _profileImageUrl = data['profileImage'];
          _licenseImageUrl = data['licenseImage'];
          _ineFrenteUrl    = data['ineFrente'];
          _ineReversoUrl   = data['ineReverso'];
          _vehiclePhotoUrl = data['vehiclePhoto'];
          _platePhotoUrl   = data['platePhoto'];
        });
      }

      final statusRes = await http.get(Uri.parse('$baseUrl/api/upload/barber-profile-status/${widget.barberId}'));
      if (statusRes.statusCode == 200) {
        final data = json.decode(statusRes.body);
        setState(() => _camposFaltantes = List<String>.from(data['camposFaltantes'] ?? []));
      }

      final zonaRes = await http.get(Uri.parse('$baseUrl/api/barbers/${widget.barberId}/zona-trabajo'));
      if (zonaRes.statusCode == 200) {
        final data = json.decode(zonaRes.body);
        setState(() {
          _radioKm        = data['radioKm']        ?? 10;
          _zonasFavoritas = List<String>.from(data['zonasFavoritas'] ?? []);
        });
      }

    } catch (e) {
      debugPrint('Error cargando datos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _guardar() async {
    setState(() => _isLoading = true);
    try {
      final nuevoNombre   = _nombreController.text.trim();
      final nuevoTelefono = _telefonoController.text.trim();

      if (nuevoNombre != _nombre || nuevoTelefono != _telefono) {
        await http.put(
          Uri.parse('$baseUrl/api/auth/update-barber'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'barberId': widget.barberId, 'nombre': nuevoNombre, 'telefono': nuevoTelefono}));
      }

      final uri     = Uri.parse('$baseUrl/api/upload/barber-documents');
      final request = http.MultipartRequest('POST', uri);
      request.fields['barberId']     = widget.barberId;
      request.fields['vehicleType']  = _vehicleType ?? '';
      request.fields['vehicleBrand'] = _brandController.text;
      request.fields['vehiclePlate'] = _plateController.text;
      request.fields['vehicleModel'] = _modelController.text;
      request.fields['vehicleYear']  = _yearController.text;
      request.fields['vehicleColor'] = _colorController.text;
      if (_profileImage != null) request.files.add(await http.MultipartFile.fromPath('profileImage', _profileImage!.path));
      if (_licenseImage != null) request.files.add(await http.MultipartFile.fromPath('licenseImage', _licenseImage!.path));
      if (_ineFrente    != null) request.files.add(await http.MultipartFile.fromPath('ineFrente',    _ineFrente!.path));
      if (_ineReverso   != null) request.files.add(await http.MultipartFile.fromPath('ineReverso',   _ineReverso!.path));
      if (_vehiclePhoto != null) request.files.add(await http.MultipartFile.fromPath('vehiclePhoto', _vehiclePhoto!.path));
      if (_platePhoto   != null) request.files.add(await http.MultipartFile.fromPath('platePhoto',   _platePhoto!.path));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      await http.put(
        Uri.parse('$baseUrl/api/barbers/${widget.barberId}/zona-trabajo'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'radioKm': _radioKm, 'zonasFavoritas': _zonasFavoritas}));

      if (response.statusCode == 200) {
        await _cargarDatos();
        if (!mounted) return;
        if (_puedeIrAlHome) {
          Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => BarberHomeScreen(barberId: widget.barberId, barberName: _nombreController.text.trim())));
        } else {
          _mostrarSnack('Guardado. Aún faltan campos por completar.', esExito: false);
        }
      }
    } catch (e) {
      _mostrarSnack('Error de conexión');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kGrisFondo,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kRojo))
          : CustomScrollView(
              slivers: [
                _buildSliverHeader(),
                SliverToBoxAdapter(
                  child: Column(children: [
                    if (_camposFaltantes.isNotEmpty) _buildAvisoCampos(),
                    _buildSeccion('Información personal'),
                    _buildCardPersonal(),
                    _buildSeccion('Seguridad'),
                    _buildCardSeguridad(),
                    _buildSeccion('Vehículo'),
                    _buildCardVehiculo(),
                    _buildSeccion('Documentos'),
                    _buildDocumentos(),
                    _buildSeccion('Zona de trabajo'),
                    _buildCardZonaTrabajo(),
                    const SizedBox(height: 16),
                    _buildBotonGuardar(),
                    _buildBotonContrasena(),
                    _buildBotonCerrarSesion(),
                    const SizedBox(height: 40),
                  ]),
                ),
              ],
            ),
    );
  }

  Widget _buildSliverHeader() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: _kRojo,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: _kBlanco, size: 20),
        onPressed: _puedeIrAlHome ? widget.onBack : null),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: _kRojo,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const SizedBox(height: 40),
            GestureDetector(
              onTap: () => _mostrarPickerImagen((f) => setState(() => _profileImage = f)),
              child: Stack(children: [
                Container(
                  width: 88, height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _kBlanco.withOpacity(0.5), width: 3),
                    color: _kBlanco.withOpacity(0.2),
                    image: _profileImage != null
                        ? DecorationImage(image: FileImage(_profileImage!), fit: BoxFit.cover)
                        : _profileImageUrl != null
                            ? DecorationImage(image: NetworkImage('$baseUrl$_profileImageUrl'), fit: BoxFit.cover)
                            : null),
                  child: (_profileImage == null && _profileImageUrl == null)
                      ? const Icon(Icons.person, color: _kBlanco, size: 44) : null),
                Positioned(bottom: 0, right: 0,
                  child: Container(
                    width: 26, height: 26,
                    decoration: const BoxDecoration(color: _kBlanco, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, color: _kRojo, size: 14))),
              ]),
            ),
            const SizedBox(height: 10),
            Text(_nombreController.text.isNotEmpty ? _nombreController.text : widget.barberName,
              style: const TextStyle(color: _kBlanco, fontSize: 18, fontWeight: FontWeight.bold)),
            if (_email != null)
              Text(_email!, style: TextStyle(color: _kBlanco.withOpacity(0.7), fontSize: 12)),
          ]),
        ),
      ),
    );
  }

  Widget _buildAvisoCampos() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCDD2))),
      child: Row(children: [
        const Icon(Icons.info_outline, color: _kRojo, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text('Completa los campos marcados con * para usar la app.',
          style: const TextStyle(fontSize: 12, color: _kRojo))),
      ]),
    );
  }

  Widget _buildCardPersonal() {
    return _buildCard([
      _buildFilaEditable(
        label: 'Nombre', valor: _nombreController.text,
        trailing: _cambiosNombre < 2
            ? _buildBadge('${2 - _cambiosNombre}/2 cambios', Colors.orange)
            : _buildBadge('Sin cambios', Colors.grey),
        onTap: _mostrarEditarNombre),
      _buildFilaEditable(
        label: 'Teléfono',
        valor: _telefonoController.text.isNotEmpty ? _telefonoController.text : 'Sin teléfono',
        onTap: () => _mostrarEditarCampo('Teléfono', _telefonoController, Icons.phone_outlined)),
      _buildFilaInfo(label: 'Correo (solo lectura)', valor: _email ?? '', muted: true),
    ]);
  }

  Widget _buildCardSeguridad() {
    return _buildCard([
      _buildFilaEditable(label: 'Contraseña', valor: '••••••••', onTap: _mostrarCambiarContrasena),
    ]);
  }

  Widget _buildCardVehiculo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        Container(
          decoration: BoxDecoration(
            color: _kBlanco, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 0.5)),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: GridView.count(
                crossAxisCount: 2, shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 2.5,
                children: _vehicleTypes.map((tipo) {
                  final selec = _vehicleType == tipo;
                  return GestureDetector(
                    onTap: () => setState(() => _vehicleType = tipo),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: selec ? _kRojo.withOpacity(0.08) : _kGrisFondo,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selec ? _kRojo : Colors.grey.shade200, width: selec ? 1.5 : 0.5)),
                      child: Center(child: Text(tipo, style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: selec ? _kRojo : Colors.grey.shade600)))),
                  );
                }).toList(),
              ),
            ),
            if (_vehicleType != null) ...[
              Divider(height: 1, color: Colors.grey.shade100),
              _buildFilaEditable(
                label: 'Color *', esFaltante: _camposFaltantes.contains('vehicleColor'),
                valor: _colorController.text.isNotEmpty ? _colorController.text : 'Sin completar',
                onTap: () => _mostrarEditarCampo('Color', _colorController, Icons.color_lens_outlined)),
              _buildFilaEditable(
                label: 'Año',
                valor: _yearController.text.isNotEmpty ? _yearController.text : 'Sin completar',
                onTap: () => _mostrarEditarCampo('Año', _yearController, Icons.calendar_today_outlined, tipo: TextInputType.number)),
              if (_esMotorizado) ...[
                _buildFilaEditable(
                  label: 'Marca *', esFaltante: _camposFaltantes.contains('vehicleBrand'),
                  valor: _brandController.text.isNotEmpty ? _brandController.text : 'Sin completar',
                  onTap: () => _mostrarEditarCampo('Marca del vehículo', _brandController, Icons.branding_watermark_outlined)),
                _buildFilaEditable(
                  label: 'Modelo *', esFaltante: _camposFaltantes.contains('vehicleModel'),
                  valor: _modelController.text.isNotEmpty ? _modelController.text : 'Sin completar',
                  onTap: () => _mostrarEditarCampo('Modelo', _modelController, Icons.directions_car_outlined)),
                _buildFilaEditable(
                  label: 'Placas *', esFaltante: _camposFaltantes.contains('vehiclePlate'),
                  valor: _plateController.text.isNotEmpty ? _plateController.text : 'Sin completar',
                  onTap: () => _mostrarEditarCampo('Placas', _plateController, Icons.pin_outlined)),
              ],
            ],
          ]),
        ),
        const SizedBox(height: 14),
      ]),
    );
  }

  // ── ZONA DE TRABAJO ───────────────────────────────────────────────
  Widget _buildCardZonaTrabajo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kBlanco, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 0.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Radio
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Radio máximo',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kNegro)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _kRojo.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                child: Text('$_radioKm km',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kRojo))),
            ]),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: _kRojo,
                inactiveTrackColor: _kRojo.withOpacity(0.15),
                thumbColor: _kRojo,
                overlayColor: _kRojo.withOpacity(0.1),
                trackHeight: 4),
              child: Slider(
                value: _radioKm.toDouble(),
                min: 5, max: 20, divisions: 3,
                onChanged: (v) => setState(() => _radioKm = v.toInt()),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('5 km', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              Text('20 km', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            ]),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            // Zonas favoritas
            const Text('Zonas favoritas',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kNegro)),
            const SizedBox(height: 4),
            Text('Acepta tus servicios de estas zonas aunque estén fuera de tu radio',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(height: 12),
            _buildZonaHeader('Zapopan'),
            _buildZonaChips(['Andares', 'Ciudad Granja', 'Las Águilas', 'Patria',
              'Vallarta Norte', 'Colomos', 'Santa Fe', 'Jardines de la Cruz',
              'Tesistán', 'Santa Lucía', 'Nextipac']),
            const SizedBox(height: 12),
            _buildZonaHeader('Guadalajara'),
            _buildZonaChips(['Providencia', 'Chapalita', 'Americana', 'Centro',
              'Jardines del Bosque', 'Arcos', 'Oblatos', 'Tetlán']),
            const SizedBox(height: 12),
            _buildZonaHeader('Otras'),
            _buildZonaChips(['Tlaquepaque', 'Tonalá', 'Tlajomulco', 'San Agustín', 'El Palomar']),
          ]),
        ),
        const SizedBox(height: 14),
      ]),
    );
  }

  Widget _buildZonaHeader(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(titulo,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          color: Colors.grey.shade400, letterSpacing: 0.5)),
    );
  }

  Widget _buildZonaChips(List<String> zonas) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: zonas.map((zona) {
        final sel = _zonasFavoritas.contains(zona);
        return GestureDetector(
          onTap: () => setState(() {
            if (sel) {
              _zonasFavoritas.remove(zona);
            } else {
              _zonasFavoritas.add(zona);
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: sel ? _kRojo.withOpacity(0.08) : _kGrisFondo,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sel ? _kRojo : Colors.grey.shade300, width: sel ? 1.5 : 0.5)),
            child: Text(zona, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: sel ? _kRojo : Colors.grey.shade600)),
          ),
        );
      }).toList(),
    );
  }

  // ── DOCUMENTOS ────────────────────────────────────────────────────
  Widget _buildDocumentos() {
    final docs = [
      _DocItem('Foto de perfil *', 'profileImage', _profileImage, _profileImageUrl, (f) => setState(() => _profileImage = f)),
      _DocItem('INE frente *', 'ineFrente', _ineFrente, _ineFrenteUrl, (f) => setState(() => _ineFrente = f)),
      _DocItem('INE reverso', 'ineReverso', _ineReverso, _ineReversoUrl, (f) => setState(() => _ineReverso = f)),
      if (_esMotorizado) ...[
        _DocItem('Licencia *', 'licenseImage', _licenseImage, _licenseImageUrl, (f) => setState(() => _licenseImage = f)),
        _DocItem('Foto vehículo', 'vehiclePhoto', _vehiclePhoto, _vehiclePhotoUrl, (f) => setState(() => _vehiclePhoto = f)),
        _DocItem('Foto placas', 'platePhoto', _platePhoto, _platePhotoUrl, (f) => setState(() => _platePhoto = f)),
      ],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8,
        childAspectRatio: 1.4, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: docs.map((doc) => _buildDocBox(doc)).toList()),
    );
  }

  Widget _buildDocBox(_DocItem doc) {
    final tieneArchivo = doc.localFile != null || doc.networkUrl != null;
    final esFaltante   = _camposFaltantes.contains(doc.campo);
    ImageProvider? image;
    if (doc.localFile != null) {
      image = FileImage(doc.localFile!);
    } else if (doc.networkUrl != null) image = NetworkImage('$baseUrl${doc.networkUrl}');
    return GestureDetector(
      onTap: () => _mostrarPickerImagen(doc.onPicked),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: esFaltante ? const Color(0xFFFFCDD2) : tieneArchivo ? const Color(0xFFC8E6C9) : Colors.grey.shade200,
            width: esFaltante || tieneArchivo ? 1.5 : 0.5),
          color: esFaltante ? const Color(0xFFFFF5F5) : tieneArchivo ? const Color(0xFFF1F8E9) : _kGrisFondo,
          image: image != null ? DecorationImage(image: image, fit: BoxFit.cover) : null),
        child: image == null
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(esFaltante ? Icons.add_photo_alternate : Icons.add_photo_alternate_outlined,
                  color: esFaltante ? _kRojo : Colors.grey.shade400, size: 26),
                const SizedBox(height: 6),
                Text(doc.label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                    color: esFaltante ? _kRojo : Colors.grey.shade500),
                  textAlign: TextAlign.center),
              ])
            : Align(alignment: Alignment.bottomLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12))),
                  child: Text(doc.label, style: const TextStyle(color: _kBlanco, fontSize: 10)))),
      ),
    );
  }

  // ── BOTONES ───────────────────────────────────────────────────────
  Widget _buildBotonGuardar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SizedBox(width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _kRojo,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0),
          onPressed: _isLoading ? null : _guardar,
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _kBlanco, strokeWidth: 2))
              : const Text('Guardar cambios', style: TextStyle(color: _kBlanco, fontWeight: FontWeight.bold, fontSize: 15)))),
    );
  }

  Widget _buildBotonContrasena() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SizedBox(width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.grey.shade300, width: 0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 16)),
          onPressed: _mostrarCambiarContrasena,
          child: const Text('Cambiar contraseña', style: TextStyle(color: _kNegro, fontWeight: FontWeight.w600, fontSize: 15)))),
    );
  }

  Widget _buildBotonCerrarSesion() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: SizedBox(width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFFFCDD2), width: 0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 16)),
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.clear();
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(context,
              MaterialPageRoute(builder: (_) => const LandingScreen()), (route) => false);
          },
          child: const Text('Cerrar sesión', style: TextStyle(color: _kRojo, fontWeight: FontWeight.w600, fontSize: 15)))),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────
  Widget _buildCard(List<Widget> filas) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        Container(
          decoration: BoxDecoration(
            color: _kBlanco, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 0.5)),
          child: Column(children: filas)),
        const SizedBox(height: 14),
      ]),
    );
  }

  Widget _buildFilaEditable({
    required String label, required String valor, required VoidCallback onTap,
    Widget? trailing, bool esFaltante = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 0.5))),
        child: Row(children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(color: _kRojo.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.edit_outlined, color: _kRojo, size: 15)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(valor, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: esFaltante ? _kRojo : _kNegro)),
          ])),
          if (trailing != null) ...[trailing, const SizedBox(width: 6)],
          if (esFaltante) _buildBadge('Requerido', _kRojo)
          else Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
        ]),
      ),
    );
  }

  Widget _buildFilaInfo({required String label, required String valor, bool muted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.lock_outline, color: Colors.grey.shade400, size: 15)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(valor, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: muted ? Colors.grey.shade400 : _kNegro)),
        ])),
      ]),
    );
  }

  Widget _buildBadge(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(texto, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)));
  }

  Widget _buildSeccion(String titulo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(children: [
        Container(width: 4, height: 14,
          decoration: BoxDecoration(color: _kRojo, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(titulo, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          color: Colors.grey.shade500, letterSpacing: 0.5)),
      ]),
    );
  }

  Widget _buildCampoTexto(String label, TextEditingController ctrl, IconData icon,
      {TextInputType tipo = TextInputType.text}) {
    return TextField(
      controller: ctrl, keyboardType: tipo,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _kRojo, size: 20),
        filled: true, fillColor: _kGrisFondo,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kRojo, width: 1.5))));
  }

  Widget _buildPasswordField(String label, TextEditingController ctrl, bool visible, VoidCallback onToggle) {
    return TextField(
      controller: ctrl, obscureText: !visible,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, color: _kRojo, size: 20),
        suffixIcon: IconButton(
          icon: Icon(visible ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey.shade400, size: 20),
          onPressed: onToggle),
        filled: true, fillColor: _kGrisFondo,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kRojo, width: 1.5))));
  }

  void _mostrarEditarCampo(String label, TextEditingController ctrl, IconData icon,
      {TextInputType tipo = TextInputType.text}) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 24, left: 20, right: 20),
        decoration: const BoxDecoration(color: _kBlanco, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          _buildCampoTexto(label, ctrl, icon, tipo: tipo),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _kRojo, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0),
              onPressed: () { setState(() {}); Navigator.pop(context); },
              child: const Text('Listo', style: TextStyle(color: _kBlanco, fontWeight: FontWeight.bold, fontSize: 15)))),
        ]),
      ),
    );
  }

  void _mostrarCambiarContrasena() {
    final actualCtrl  = TextEditingController();
    final nuevaCtrl   = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool verActual    = false;
    bool verNueva     = false;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, top: 24, left: 20, right: 20),
          decoration: const BoxDecoration(color: _kBlanco, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [
              Container(width: 4, height: 20, decoration: BoxDecoration(color: _kRojo, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              const Text('Cambiar contraseña', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kNegro)),
            ]),
            const SizedBox(height: 20),
            _buildPasswordField('Contraseña actual', actualCtrl, verActual, () => setModalState(() => verActual = !verActual)),
            const SizedBox(height: 12),
            _buildPasswordField('Nueva contraseña', nuevaCtrl, verNueva, () => setModalState(() => verNueva = !verNueva)),
            const SizedBox(height: 12),
            _buildPasswordField('Confirmar nueva contraseña', confirmCtrl, verNueva, () {}),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _kRojo, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0),
                onPressed: () async {
                  if (nuevaCtrl.text != confirmCtrl.text) { _mostrarSnack('Las contraseñas no coinciden'); return; }
                  if (nuevaCtrl.text.length < 6) { _mostrarSnack('La contraseña debe tener al menos 6 caracteres'); return; }
                  Navigator.pop(context);
                  await _cambiarContrasena(actualCtrl.text, nuevaCtrl.text);
                },
                child: const Text('Cambiar contraseña', style: TextStyle(color: _kBlanco, fontWeight: FontWeight.bold, fontSize: 15)))),
          ]),
        ),
      ),
    );
  }

  Future<void> _cambiarContrasena(String actual, String nueva) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/api/auth/update-barber'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'barberId': widget.barberId, 'passwordActual': actual, 'passwordNueva': nueva}));
      if (res.statusCode == 200) {
        _mostrarSnack('Contraseña actualizada', esExito: true);
      } else {
        final data = json.decode(res.body);
        _mostrarSnack(data['message'] ?? 'Error al cambiar contraseña');
      }
    } catch (e) { _mostrarSnack('Error de conexión'); }
  }

  void _mostrarEditarNombre() {
    if (_cambiosNombre >= 2 && _ultimoCambioNombre != null) {
      final diasRestantes = 180 - DateTime.now().difference(_ultimoCambioNombre!).inDays;
      if (diasRestantes > 0) { _mostrarSnack('Puedes cambiar tu nombre en $diasRestantes días'); return; }
    }
    final ctrl = TextEditingController(text: _nombreController.text);
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 24, left: 20, right: 20),
        decoration: const BoxDecoration(color: _kBlanco, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            Container(width: 4, height: 20, decoration: BoxDecoration(color: _kRojo, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            const Text('Cambiar nombre', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kNegro)),
          ]),
          const SizedBox(height: 8),
          Text('Puedes cambiar tu nombre ${2 - _cambiosNombre} vez más en los próximos 6 meses.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 16),
          _buildCampoTexto('Nuevo nombre', ctrl, Icons.person_outline),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _kRojo, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0),
              onPressed: () { setState(() => _nombreController.text = ctrl.text.trim()); Navigator.pop(context); },
              child: const Text('Confirmar', style: TextStyle(color: _kBlanco, fontWeight: FontWeight.bold, fontSize: 15)))),
        ]),
      ),
    );
  }

  void _mostrarPickerImagen(Function(File) onPicked) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: _kBlanco, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: _kRojo.withOpacity(0.08), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.camera_alt_outlined, color: _kRojo, size: 20)),
            title: const Text('Cámara', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () async { Navigator.pop(context); final f = await picker.pickImage(source: ImageSource.camera); if (f != null) onPicked(File(f.path)); }),
          ListTile(
            leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: _kRojo.withOpacity(0.08), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.photo_library_outlined, color: _kRojo, size: 20)),
            title: const Text('Galería', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () async { Navigator.pop(context); final f = await picker.pickImage(source: ImageSource.gallery); if (f != null) onPicked(File(f.path)); }),
        ])),
      ),
    );
  }

  void _mostrarSnack(String msg, {bool esExito = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: esExito ? Colors.green.shade700 : _kNegro,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }
}

class _DocItem {
  final String label;
  final String campo;
  final File?  localFile;
  final String? networkUrl;
  final Function(File) onPicked;
  _DocItem(this.label, this.campo, this.localFile, this.networkUrl, this.onPicked);
}

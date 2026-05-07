import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:barber_app/config/app_config.dart';
import 'package:barber_app/screens/User_Screens/change_location_screen.dart';

const _kAzul      = Color(0xFF0D3FA6);
const _kAzulMedio = Color(0xFF1A5FD4);
const _kNavy      = Color(0xFF1A1A2E);
const _kBlanco    = Colors.white;
const _kFondo     = Color(0xFFF0F4FF);

class SlotDisponible {
  final String hora;
  final int horaMinutos;
  SlotDisponible({required this.hora, required this.horaMinutos});
  factory SlotDisponible.fromJson(Map<String, dynamic> json) =>
      SlotDisponible(hora: json['hora'], horaMinutos: json['horaMinutos']);
}

class PersonaCita {
  String nombre;
  Set<String> servicios;
  PersonaCita({required this.nombre, Set<String>? servicios})
      : servicios = servicios ?? {};
}

class BookingScreen extends StatefulWidget {
  final dynamic barber;
  final String  userId;
  const BookingScreen({super.key, required this.barber, required this.userId});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final String baseUrl = AppConfig.baseUrl;

  String?         _fechaSeleccionada;
  SlotDisponible? _slotSeleccionado;
  int             _duracionTotalMin = 0;

  String  _domicilio = '';
  double? _lat;
  double? _lng;

  List<String>         _diasDisponibles = [];
  List<String>         _servicios       = [];
  List<SlotDisponible> _slotsDelDia     = [];
  List<PersonaCita>    _personas        = [];

  bool _isLoadingSlots = false;
  bool _isSaving       = false;

  String get _barberId =>
      widget.barber['barberId']?.toString() ??
      widget.barber['_id']?.toString()      ??
      widget.barber['id']?.toString()       ?? '';

  String? get _profileImage => widget.barber['profileImage'];

  List<String> get _todosLosServiciosConDuplicados =>
      _personas.expand((p) => p.servicios).toList();

  bool get _hayServicios => _personas.any((p) => p.servicios.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _generarDiasDisponibles();
    _cargarServicios();
    _obtenerUbicacion();
    _initPersonas();
  }

  Future<void> _initPersonas() async {
    final prefs  = await SharedPreferences.getInstance();
    final nombre = prefs.getString('userName') ?? 'Yo';
    setState(() => _personas = [PersonaCita(nombre: nombre)]);
  }

  void _generarDiasDisponibles() {
    final diasConfig     = widget.barber['diasDisponibles'] as List? ?? [];
    final diasBloqueados = (widget.barber['diasBloqueados'] as List? ?? [])
        .map((d) => d['fecha'].toString()).toSet();
    final diasActivos = diasConfig.map((d) => d['dia'] as int).toSet();
    final hoy   = DateTime.now();
    final lista = <String>[];
    for (int i = 0; i < 30; i++) {
      final dia       = hoy.add(Duration(days: i));
      final diaSemana = dia.weekday % 7;
      final fecha     = _formatFecha(dia);
      if (diasActivos.contains(diaSemana) && !diasBloqueados.contains(fecha)) {
        lista.add(fecha);
      }
    }
    setState(() => _diasDisponibles = lista);
  }

  Future<void> _cargarServicios() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/barbers/$_barberId/servicios'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => _servicios = List<String>.from(data['servicios'] ?? []));
      }
    } catch (_) {}
  }

  Future<void> _obtenerUbicacion() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 10));
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, position.longitude);
      setState(() {
        _lat       = position.latitude;
        _lng       = position.longitude;
        _domicilio = placemarks.isNotEmpty
            ? "${placemarks[0].street}, ${placemarks[0].locality}"
            : "Ubicación obtenida";
      });
    } catch (_) {}
  }

  Future<void> _cambiarUbicacion() async {
    final result = await Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChangeLocationScreen(
        initialAddress:  _domicilio,
        initialLocation: _lat != null && _lng != null
            ? LatLng(_lat!, _lng!) : null,
      )));
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _domicilio = result['direccion'];
        _lat       = result['lat'];
        _lng       = result['lng'];
      });
    }
  }

  Future<void> _cargarSlotsDeFecha(String fecha) async {
    setState(() {
      _isLoadingSlots   = true;
      _slotSeleccionado = null;
      _slotsDelDia      = [];
    });
    try {
      final serviciosParam = _todosLosServiciosConDuplicados.join(',');
      final res = await http.get(Uri.parse(
        '$baseUrl/api/disponibilidad/$_barberId/slots-nuevo?fecha=$fecha&servicios=$serviciosParam'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _slotsDelDia      = (data['slots'] as List)
              .map((s) => SlotDisponible.fromJson(s)).toList();
          _duracionTotalMin = data['duracionTotal'] ?? 0;
          _isLoadingSlots   = false;
        });
      } else {
        setState(() => _isLoadingSlots = false);
      }
    } catch (_) {
      setState(() => _isLoadingSlots = false);
    }
  }

  void _agregarPersona() {
    setState(() => _personas.add(
      PersonaCita(nombre: 'Persona ${_personas.length + 1}')));
  }

  void _eliminarPersona(int idx) {
    setState(() => _personas.removeAt(idx));
    if (_fechaSeleccionada != null) _cargarSlotsDeFecha(_fechaSeleccionada!);
  }

  void _editarNombre(int idx) {
    final ctrl = TextEditingController(text: _personas[idx].nombre);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 24, left: 20, right: 20),
        decoration: const BoxDecoration(
          color: _kBlanco,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nombre',
                filled: true, fillColor: _kFondo,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kAzulMedio, width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _personas[idx].nombre = ctrl.text.trim().isEmpty
                      ? _personas[idx].nombre : ctrl.text.trim());
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNavy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0),
                child: const Text('Listo',
                  style: TextStyle(color: _kBlanco, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarReserva() async {
    if (_fechaSeleccionada == null || _slotSeleccionado == null) return;
    if (!_hayServicios) {
      _mostrarSnack('Selecciona al menos un servicio');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/reservas/create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId':    widget.userId,
          'barberId':  _barberId,
          'fecha':     _fechaSeleccionada,
          'hora':      _slotSeleccionado!.hora,
          'servicios': _todosLosServiciosConDuplicados,
          'personas':  _personas.map((p) => {
            'nombre':    p.nombre,
            'servicios': p.servicios.toList(),
          }).toList(),
          'domicilio': _domicilio,
          'lat':       _lat,
          'lng':       _lng,
        }),
      );
      if (res.statusCode == 201) {
        _mostrarExito();
      } else {
        final data = json.decode(res.body);
        _mostrarSnack(data['error'] ?? 'Error al crear la cita');
      }
    } catch (_) {
      _mostrarSnack('Error de conexión');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _mostrarExito() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.check_rounded, color: _kAzulMedio, size: 40)),
              const SizedBox(height: 16),
              const Text('¡Cita enviada!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kNavy)),
              const SizedBox(height: 8),
              Text('Tu solicitud fue enviada al barbero.\nTe confirmará en breve.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () { Navigator.pop(context); Navigator.pop(context); },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kNavy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0),
                  child: const Text('ENTENDIDO',
                    style: TextStyle(color: _kBlanco, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _kNavy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final String nombre     = widget.barber['nombre'] ?? 'Barbero';
    final bool   canConfirm = _fechaSeleccionada != null &&
        _slotSeleccionado != null && _hayServicios && !_isSaving;

    return Scaffold(
      backgroundColor: _kFondo,
      body: Column(
        children: [
          // ── HEADER ────────────────────────────────────────────────
          Container(
            color: _kAzul,
            width: double.infinity,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: _kBlanco.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.arrow_back_ios_new, color: _kBlanco, size: 16)),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _kBlanco.withOpacity(0.3), width: 2),
                          color: _kBlanco.withOpacity(0.15),
                          image: _profileImage != null
                              ? DecorationImage(
                                  image: NetworkImage('$baseUrl$_profileImage'),
                                  fit: BoxFit.cover)
                              : null),
                        child: _profileImage == null
                            ? const Icon(Icons.person_rounded, color: _kBlanco, size: 28)
                            : null),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nombre,
                            style: const TextStyle(color: _kBlanco, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Agendar cita',
                            style: TextStyle(color: _kBlanco.withOpacity(0.6), fontSize: 12)),
                        ],
                      ),
                    ]),
                    if (_domicilio.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Container(width: 6, height: 6,
                          decoration: const BoxDecoration(color: Color(0xFF7ECFFF), shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(_domicilio,
                          style: TextStyle(color: _kBlanco.withOpacity(0.7), fontSize: 12),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _cambiarUbicacion,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _kBlanco.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8)),
                            child: const Text('Cambiar',
                              style: TextStyle(color: _kBlanco, fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ── CONTENIDO ─────────────────────────────────────────────
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [

                SliverToBoxAdapter(child: _buildStepLabel('PASO 1', '¿Para quiénes es la cita?')),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _servicios.isEmpty
                        ? Text('Cargando servicios...',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 13))
                        : Column(children: [
                            ..._personas.asMap().entries.map((e) =>
                              _buildPersonaCard(e.key, e.value)),
                            GestureDetector(
                              onTap: _agregarPersona,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _kBlanco,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFC8D6FF), width: 0.5)),
                                child: Row(children: [
                                  Container(
                                    width: 32, height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF4FF),
                                      borderRadius: BorderRadius.circular(10)),
                                    child: const Icon(Icons.add, color: _kAzulMedio, size: 18)),
                                  const SizedBox(width: 12),
                                  const Text('Agregar otra persona',
                                    style: TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w600, color: _kAzulMedio)),
                                ]),
                              ),
                            ),
                            if (_hayServicios) _buildResumenTotal(),
                          ]),
                  ),
                ),

                SliverToBoxAdapter(child: _buildStepLabel('PASO 2', 'Selecciona el día')),
                SliverToBoxAdapter(
                  child: _diasDisponibles.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('Este barbero no tiene días disponibles.',
                            style: TextStyle(color: Colors.grey)))
                      : SizedBox(
                          height: 90,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _diasDisponibles.length,
                            itemBuilder: (_, i) {
                              final fecha     = _diasDisponibles[i];
                              final sel       = _fechaSeleccionada == fecha;
                              final parts     = fecha.split('-');
                              final dia       = parts[2];
                              final mes       = _nombreMes(int.parse(parts[1]));
                              final dateObj   = DateTime.parse(fecha);
                              const diasSem   = ['Dom','Lun','Mar','Mié','Jue','Vie','Sáb'];
                              final diaSemana = diasSem[dateObj.weekday % 7];
                              return GestureDetector(
                                onTap: () {
                                  setState(() => _fechaSeleccionada = fecha);
                                  _cargarSlotsDeFecha(fecha);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 70,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    color: sel ? _kNavy : _kBlanco,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: sel ? _kNavy : const Color(0xFFE0E8FF),
                                      width: 0.5)),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(diaSemana,
                                        style: TextStyle(
                                          color: sel ? _kBlanco.withOpacity(0.6) : Colors.grey.shade500,
                                          fontWeight: FontWeight.bold, fontSize: 11)),
                                      const SizedBox(height: 4),
                                      Text(dia,
                                        style: TextStyle(
                                          color: sel ? _kBlanco : _kNavy,
                                          fontWeight: FontWeight.bold, fontSize: 22)),
                                      const SizedBox(height: 2),
                                      Text(mes,
                                        style: TextStyle(
                                          color: sel ? _kBlanco.withOpacity(0.5) : Colors.grey.shade400,
                                          fontSize: 10)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),

                if (_fechaSeleccionada != null) ...[
                  SliverToBoxAdapter(child: _buildStepLabel('PASO 3', 'Selecciona el horario')),
                  SliverToBoxAdapter(
                    child: !_hayServicios
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                            child: Text('Selecciona servicios para ver horarios',
                              style: TextStyle(color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic, fontSize: 13)))
                        : _isLoadingSlots
                            ? const Center(child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(color: _kAzulMedio)))
                            : _slotsDelDia.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16),
                                    child: Text('No hay horarios disponibles.',
                                      style: TextStyle(color: Colors.grey)))
                                : Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                                    child: Wrap(
                                      spacing: 8, runSpacing: 8,
                                      children: _slotsDelDia.map((slot) {
                                        final sel = _slotSeleccionado?.hora == slot.hora;
                                        return GestureDetector(
                                          onTap: () => setState(() => _slotSeleccionado = slot),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 150),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: sel ? _kNavy : _kBlanco,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: sel ? _kNavy : const Color(0xFFE0E8FF),
                                                width: 0.5)),
                                            child: Text(_formatHora24a12(slot.hora),
                                              style: TextStyle(
                                                color: sel ? _kBlanco : _kNavy,
                                                fontWeight: FontWeight.bold, fontSize: 13)),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                  ),
                ] else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      child: Text('Selecciona un día para ver horarios',
                        style: TextStyle(color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic, fontSize: 13)),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ),
          ),

          // ── BOTÓN CONFIRMAR ───────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16,
              MediaQuery.of(context).padding.bottom + 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canConfirm ? _confirmarReserva : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNavy,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 0),
                child: _isSaving
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: _kBlanco, strokeWidth: 2))
                    : const Text('CONFIRMAR CITA',
                        style: TextStyle(color: _kBlanco,
                          fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonaCard(int idx, PersonaCita persona) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kBlanco,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E8FF), width: 0.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF4FF),
                borderRadius: BorderRadius.circular(10)),
              child: Center(
                child: Text(
                  persona.nombre.isNotEmpty ? persona.nombre[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kAzulMedio)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => _editarNombre(idx),
                child: Row(children: [
                  Text(persona.nombre,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kNavy)),
                  const SizedBox(width: 6),
                  Icon(Icons.edit_outlined, size: 13, color: Colors.grey.shade400),
                ]),
              ),
            ),
            if (_personas.length > 1)
              GestureDetector(
                onTap: () => _eliminarPersona(idx),
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEB),
                    borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.close, color: Color(0xFFE8202A), size: 14)),
              ),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: _servicios.map((svc) {
              final sel = persona.servicios.contains(svc);
              return GestureDetector(
                onTap: () async {
                  setState(() {
                    if (sel) {
                      persona.servicios.remove(svc);
                    } else {
                      persona.servicios.add(svc);
                    }
                  });
                  await Future.microtask(() {});
                  if (_fechaSeleccionada != null) _cargarSlotsDeFecha(_fechaSeleccionada!);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? _kNavy : const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: sel ? _kNavy : const Color(0xFFE0E8FF),
                      width: 0.5)),
                  child: Text(svc,
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: sel ? _kBlanco : _kNavy)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenTotal() {
    final resumen = _personas
        .where((p) => p.servicios.isNotEmpty)
        .map((p) => '${p.nombre}: ${p.servicios.join("+")}')
        .join(' · ');
    final horas   = _duracionTotalMin ~/ 60;
    final minutos = _duracionTotalMin % 60;
    final durStr  = horas > 0 ? '~${horas}h ${minutos}min' : '~${minutos}min';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kNavy, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        const Icon(Icons.people_outline, color: _kBlanco, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Duración total estimada',
              style: TextStyle(color: Colors.white70, fontSize: 11)),
            const SizedBox(height: 2),
            Text(resumen,
              style: TextStyle(fontSize: 11, color: _kBlanco.withOpacity(0.5)),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        )),
        if (_duracionTotalMin > 0) Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$_duracionTotalMin min',
              style: const TextStyle(color: _kBlanco, fontSize: 15, fontWeight: FontWeight.bold)),
            Text(durStr,
              style: TextStyle(color: _kBlanco.withOpacity(0.4), fontSize: 10)),
          ],
        ),
      ]),
    );
  }

  Widget _buildStepLabel(String num, String titulo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(num, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: Color(0xFF8892B0), letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(titulo, style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: _kNavy)),
        ],
      ),
    );
  }

  String _formatHora24a12(String hora24) {
    final parts = hora24.split(':');
    int h = int.parse(parts[0]);
    final m = parts[1];
    final period = h >= 12 ? 'PM' : 'AM';
    if (h == 0) {
      h = 12;
    } else if (h > 12) h -= 12;
    return '$h:$m $period';
  }

  String _nombreMes(int mes) {
    const meses = ['','Ene','Feb','Mar','Abr','May','Jun',
                   'Jul','Ago','Sep','Oct','Nov','Dic'];
    return meses[mes];
  }

  String _formatFecha(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
}

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:barber_app/config/app_config.dart';

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
  final Set<String>     _serviciosSeleccionados = {};

  String  _domicilio = '';
  double? _lat;
  double? _lng;

  List<Map<String, dynamic>> _diasConSlots = [];
  List<SlotDisponible>       _slotsDelDia  = [];
  bool _isLoadingDias  = true;
  bool _isLoadingSlots = false;
  bool _isSaving       = false;

  final List<Map<String, dynamic>> _servicios = [
    {'nombre': 'Corte', 'icono': Icons.content_cut},
    {'nombre': 'Barba', 'icono': Icons.face},
    {'nombre': 'Ceja',  'icono': Icons.remove_red_eye},
    {'nombre': 'Greka', 'icono': Icons.design_services},
  ];

  String get _barberId =>
      widget.barber['barberId']?.toString() ??
      widget.barber['_id']?.toString()      ??
      widget.barber['id']?.toString()       ?? '';

  String? get _profileImage => widget.barber['profileImage'];

  @override
  void initState() {
    super.initState();
    _cargarDiasDisponibles();
    _obtenerUbicacion();
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

  Future<void> _cargarDiasDisponibles() async {
    setState(() => _isLoadingDias = true);
    try {
      final List   slots = widget.barber['slots'] ?? [];
      final String fecha = widget.barber['fecha'] ?? '';
      if (fecha.isNotEmpty && slots.isNotEmpty) {
        setState(() {
          _diasConSlots = [{
            'fecha': fecha,
            'slots': slots.map((s) => SlotDisponible(
              hora: s['hora'], horaMinutos: s['horaMinutos'])).toList()
          }];
          _isLoadingDias = false;
        });
      } else {
        setState(() => _isLoadingDias = false);
      }
    } catch (_) {
      setState(() => _isLoadingDias = false);
    }
  }

  Future<void> _cargarSlotsDeFecha(String fecha) async {
    setState(() {
      _isLoadingSlots   = true;
      _slotSeleccionado = null;
      _slotsDelDia      = [];
    });
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/barbers/$_barberId/slots?fecha=$fecha'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _slotsDelDia    = (data['slots'] as List)
              .map((s) => SlotDisponible.fromJson(s)).toList();
          _isLoadingSlots = false;
        });
      } else {
        setState(() => _isLoadingSlots = false);
      }
    } catch (_) {
      setState(() => _isLoadingSlots = false);
    }
  }

  Future<void> _confirmarReserva() async {
    if (_fechaSeleccionada == null || _slotSeleccionado == null) return;
    if (_serviciosSeleccionados.isEmpty) {
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
          'servicios': _serviciosSeleccionados.toList(),
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
                decoration: BoxDecoration(color: const Color(0xFFEEF4FF), borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.check_rounded, color: _kAzulMedio, size: 40),
              ),
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
                    elevation: 0,
                  ),
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
    final String nombre = widget.barber['nombre'] ?? 'Barbero';
    final bool canConfirm = _fechaSeleccionada != null &&
        _slotSeleccionado != null &&
        _serviciosSeleccionados.isNotEmpty &&
        !_isSaving;

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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new, color: _kBlanco, size: 16),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // Foto del barbero
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
                                : null,
                          ),
                          child: _profileImage == null
                              ? const Icon(Icons.person_rounded, color: _kBlanco, size: 28)
                              : null,
                        ),
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
                      ],
                    ),
                    if (_domicilio.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(width: 6, height: 6,
                            decoration: const BoxDecoration(color: Color(0xFF7ECFFF), shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(_domicilio,
                              style: TextStyle(color: _kBlanco.withOpacity(0.7), fontSize: 12),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
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
                // Paso 1: Servicios
                SliverToBoxAdapter(child: _buildStepLabel('PASO 1', '¿Qué servicio necesitas?')),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _servicios.map((s) {
                        final sel = _serviciosSeleccionados.contains(s['nombre']);
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (sel) {
                              _serviciosSeleccionados.remove(s['nombre']);
                            } else {
                              _serviciosSeleccionados.add(s['nombre'] as String);
                            }
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: sel ? _kNavy : _kBlanco,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: sel ? _kNavy : const Color(0xFFE0E8FF),
                                width: 0.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(s['icono'] as IconData, size: 15,
                                  color: sel ? _kBlanco : Colors.grey.shade600),
                                const SizedBox(width: 6),
                                Text(s['nombre'] as String,
                                  style: TextStyle(
                                    color: sel ? _kBlanco : _kNavy,
                                    fontWeight: FontWeight.w700, fontSize: 13)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Paso 2: Fecha
                SliverToBoxAdapter(child: _buildStepLabel('PASO 2', 'Selecciona el día')),
                SliverToBoxAdapter(
                  child: _isLoadingDias
                      ? const Center(child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(color: _kAzulMedio)))
                      : _diasConSlots.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text('No hay fechas disponibles.',
                                style: TextStyle(color: Colors.grey)))
                          : SizedBox(
                              height: 90,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _diasConSlots.length,
                                itemBuilder: (_, i) {
                                  final dia   = _diasConSlots[i];
                                  final fecha = dia['fecha'] as String;
                                  final sel   = _fechaSeleccionada == fecha;
                                  final parts = fecha.split('-');
                                  final dia2  = parts[2];
                                  final mes   = _nombreMes(int.parse(parts[1]));
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
                                          width: 0.5),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(mes.toUpperCase(),
                                            style: TextStyle(
                                              color: sel ? _kBlanco.withOpacity(0.6) : Colors.grey.shade500,
                                              fontWeight: FontWeight.bold, fontSize: 11)),
                                          const SizedBox(height: 4),
                                          Text(dia2,
                                            style: TextStyle(
                                              color: sel ? _kBlanco : _kNavy,
                                              fontWeight: FontWeight.bold, fontSize: 22)),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                ),

                // Paso 3: Horario
                if (_fechaSeleccionada != null) ...[
                  SliverToBoxAdapter(child: _buildStepLabel('PASO 3', 'Selecciona el horario')),
                  SliverToBoxAdapter(
                    child: _isLoadingSlots
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
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: sel ? _kNavy : _kBlanco,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: sel ? _kNavy : const Color(0xFFE0E8FF),
                                            width: 0.5),
                                        ),
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
                        style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic, fontSize: 13)),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ),
          ),

          // ── BOTÓN CONFIRMAR ────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canConfirm ? _confirmarReserva : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNavy,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: _kBlanco, strokeWidth: 2))
                    : const Text('CONFIRMAR CITA',
                        style: TextStyle(color: _kBlanco, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLabel(String num, String titulo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(num,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: Color(0xFF8892B0), letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(titulo,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kNavy)),
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
}

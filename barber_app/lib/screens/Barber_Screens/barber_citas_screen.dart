import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:barber_app/config/app_config.dart';
import 'package:barber_app/screens/Barber_Screens/barber_disponibilidad_screen.dart';
import 'barber_state.dart';
import 'package:geolocator/geolocator.dart';

// ─────────────────────────────────────────────
//  MODELOS
// ─────────────────────────────────────────────

class DiaAgenda {
  final String fecha;
  final String diaSemana;
  final bool tieneJornada;

  DiaAgenda({required this.fecha, required this.diaSemana, required this.tieneJornada});
}

class CitaCard {
  final String id;
  final String clienteNombre;
  final String? clienteFoto;
  final String domicilio;
  final double? distanciaKm;
  final String servicios;
  final String hora;
  final String fecha;
  final double precioTotal;
  final String status;
  final double? lat;
  final double? lng;

  CitaCard({required this.id, required this.clienteNombre, this.clienteFoto,
    required this.domicilio, this.distanciaKm, required this.servicios,
    required this.hora, required this.fecha, required this.precioTotal,
    required this.status, this.lat, this.lng});

  factory CitaCard.fromJson(Map<String, dynamic> json) => CitaCard(
    id:            json['_id'] ?? '',
    clienteNombre: json['clienteNombre'] ?? 'Cliente',
    clienteFoto:   json['clienteFoto'],
    domicilio:     json['domicilio'] ?? '',
    distanciaKm:   (json['distanciaKm'] ?? 0).toDouble(),
    servicios:     json['servicios'] ?? '',
    hora:          json['hora'] ?? '',
    fecha:         json['fecha'] ?? '',
    precioTotal:   (json['precioTotal'] ?? 0).toDouble(),
    status:        json['status'] ?? 'aceptada',
    lat:           json['lat']?.toDouble(),
    lng:           json['lng']?.toDouble(),
  );
}

// ─────────────────────────────────────────────
//  COLORES
// ─────────────────────────────────────────────
const _kRojo      = Color(0xFFE8202A);
const _kNegro     = Color(0xFF1A1A1A);
const _kNavy      = Color(0xFF1A1A2E);
const _kGrisFondo = Color(0xFFF5F5F5);
const _kBlanco    = Colors.white;

// ─────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────

class BarberAppointmentsScreen extends StatefulWidget {
  final String? barberId;
  final String? barberName;
  final BarberState barberState;

  const BarberAppointmentsScreen({
    super.key,
    this.barberId,
    this.barberName,
    required this.barberState,
  });

  @override
  State<BarberAppointmentsScreen> createState() => _BarberAppointmentsScreenState();
}

class _BarberAppointmentsScreenState extends State<BarberAppointmentsScreen> {
  final String baseUrl = AppConfig.baseUrl;

  bool _isLoading      = true;
  bool _tieneHorario   = false;
  List<Map<String, dynamic>> _diasDisponibles = [];
  final Map<String, double> _distanciasCapturadasIr = {}; // citaId → distanciaKm
  List<DiaAgenda> _semana   = [];
  int  _diaSeleccionado     = 0;
  List<CitaCard> _citas     = [];
  bool _loadingCitas        = false;

  Timer? _pollingTimer;
  bool   _mostrandoDialog = false;

  BarberState get _state => widget.barberState;

  @override
  void initState() {
    super.initState();
    _cargarSemana();
    _iniciarPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  // ── POLLING ───────────────────────────────────────────────────────
  void _iniciarPolling() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _verificarPendientes();
        _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
          _verificarPendientes();
        });
      }
    });
  }

  Future<void> _verificarPendientes() async {
    if (_mostrandoDialog || !mounted) return;
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/citas/barbero/${widget.barberId}/pendientes'));
      if (res.statusCode == 200) {
        final data      = json.decode(res.body);
        final List pend = data['pendientes'] ?? [];
        if (pend.isNotEmpty && mounted && !_mostrandoDialog) {
          _mostrarDialogPendiente(pend[0]);
        }
      }
    } catch (e) {
      debugPrint('Error polling: $e');
    }
  }

  // ── DIALOG SOLICITUD ──────────────────────────────────────────────
  void _mostrarDialogPendiente(dynamic cita) {
  _mostrandoDialog = true;
  final String nombre        = cita['clienteNombre'] ?? 'Cliente';
  final List   svcs          = cita['servicios']     ?? [];
  final String hora          = cita['hora']          ?? '';
  final String fecha         = cita['fecha']         ?? '';
  final String citaId        = cita['_id'].toString();
  final bool   excedeHorario = cita['excedeHorario'] ?? false;
  final int    duracion      = cita['duracionTotal']  ?? 0;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: const BoxDecoration(
              color: _kNegro,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Row(children: [
              Container(width: 44, height: 44,
                decoration: const BoxDecoration(color: Color(0xFFFFEBEB), shape: BoxShape.circle),
                child: const Icon(Icons.person, color: _kRojo, size: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nueva solicitud',
                    style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500)),
                  Text(nombre,
                    style: const TextStyle(color: _kBlanco, fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              )),
            ]),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info servicios
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.content_cut, size: 14, color: _kRojo),
                        const SizedBox(width: 6),
                        Expanded(child: Text(svcs.join(', '),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kNegro))),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 6),
                        Text('$fecha a las $hora',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        if (duracion > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kRojo.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8)),
                            child: Text('$duracion min',
                              style: const TextStyle(fontSize: 11, color: _kRojo, fontWeight: FontWeight.bold))),
                        ],
                      ]),
                    ],
                  ),
                ),
                // Aviso si excede horario
                if (excedeHorario) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3), width: 0.5)),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        'Esta cita excede tu horario de trabajo. ¿Deseas aceptarla de todas formas?',
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade800))),
                    ]),
                  ),
                ],
                const SizedBox(height: 16),
                // Botones
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () { Navigator.pop(context); _responderCita(citaId, 'rechazar'); },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red, width: 0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: const Text('Rechazar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () { Navigator.pop(context); _mostrarDialogReagendar(citaId); },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.orange.shade300, width: 0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: Text('Reagendar', style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kRojo,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0),
                      onPressed: () { Navigator.pop(context); _responderCita(citaId, 'aceptar'); },
                      child: const Text('Aceptar', style: TextStyle(color: _kBlanco, fontWeight: FontWeight.bold))),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    ),
  ).then((_) => _mostrandoDialog = false);
}

  Future<void> _responderCita(String citaId, String accion) async {
  try {
    final res = await http.put(
      Uri.parse('$baseUrl/api/citas/$citaId/responder'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'accion': accion}),
    );
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      debugPrint('Respuesta finalizar: ${res.body}'); // ← debug temporal

      if (accion == 'finalizar') {
        _mostrarSnack('Servicio finalizado', esExito: true);
        _cargarCitasDia(_semana.isNotEmpty ? _semana[_diaSeleccionado].fecha : _fechaHoy());
        // Pequeño delay para que el setState termine antes de abrir el sheet
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted && data['desglosePrecio'] != null) {
          _mostrarDesglosePrecio(data['desglosePrecio'], data['costoTotal']);
        }
        return;
      }

      String mensaje;
      bool esExito = true;
      switch (accion) {
        case 'aceptar':   mensaje = 'Cita aceptada';            break;
        case 'rechazar':  mensaje = 'Cita rechazada'; esExito = false; break;
        case 'llegar':    mensaje = 'Llegada registrada';        break;
        default:          mensaje = 'Acción completada';
      }
      _mostrarSnack(mensaje, esExito: esExito);
      _cargarCitasDia(_semana.isNotEmpty ? _semana[_diaSeleccionado].fecha : _fechaHoy());
    } else {
      _mostrarSnack('Error al responder la cita');
    }
  } catch (_) {
    _mostrarSnack('Error de conexión');
  }
}
  void _mostrarDialogReagendar(String citaId) {
    TimeOfDay nuevaHora = const TimeOfDay(hour: 10, minute: 0);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 24, left: 20, right: 20),
          decoration: const BoxDecoration(
            color: _kBlanco,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('Proponer nueva hora',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  final t = await showTimePicker(
                    context: context, initialTime: nuevaHora,
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: _kRojo, onPrimary: _kBlanco, surface: _kBlanco)),
                      child: child!));
                  if (t != null) setModalState(() => nuevaHora = t);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _kGrisFondo, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.access_time, color: _kRojo),
                    const SizedBox(width: 10),
                    Text(
                      '${nuevaHora.hour.toString().padLeft(2,'0')}:${nuevaHora.minute.toString().padLeft(2,'0')}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kRojo,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0),
                  onPressed: () async {
                    Navigator.pop(context);
                    final hora  = '${nuevaHora.hour.toString().padLeft(2,'0')}:${nuevaHora.minute.toString().padLeft(2,'0')}';
                    final fecha = _fechaHoy();
                    try {
                      final res = await http.put(
                        Uri.parse('$baseUrl/api/citas/$citaId/responder'),
                        headers: {'Content-Type': 'application/json'},
                        body: json.encode({
                          'accion': 'reagendar', 'nuevaHora': hora, 'nuevaFecha': fecha}));
                      if (res.statusCode == 200) {
                        _mostrarSnack('Reagendado correctamente', esExito: true);
                        _cargarSemana();
                      } else {
                        _mostrarSnack('No se pudo reagendar');
                      }
                    } catch (_) { _mostrarSnack('Error de conexión'); }
                  },
                  child: const Text('Confirmar nueva hora',
                    style: TextStyle(color: _kBlanco, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── CARGAR DATOS ──────────────────────────────────────────────────
  Future<void> _cargarSemana() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/disponibilidad/${widget.barberId}/horario'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final dias = data['diasDisponibles'] as List? ?? [];
        setState(() {
          _tieneHorario    = dias.isNotEmpty;
          _diasDisponibles = List<Map<String, dynamic>>.from(dias);
          _isLoading       = false;
        });
        if (_tieneHorario) _generarProximos7Dias();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error cargando horario: $e');
      setState(() => _isLoading = false);
    }
  }
void _generarProximos7Dias() {
  final hoy         = DateTime.now();
  final lista       = <DiaAgenda>[];
  final diasActivos = _diasDisponibles.map((d) => d['dia'] as int).toSet();
  const nombresDias = ['Domingo','Lunes','Martes','Miércoles','Jueves','Viernes','Sábado'];

  for (int i = 0; i < 60 && lista.length < 30; i++) {
    final dia       = hoy.add(Duration(days: i));
    final diaSemana = dia.weekday % 7;
    if (diasActivos.contains(diaSemana)) {
      final fecha = '${dia.year}-${dia.month.toString().padLeft(2,'0')}-${dia.day.toString().padLeft(2,'0')}';
      lista.add(DiaAgenda(
        fecha:        fecha,
        diaSemana:    nombresDias[diaSemana],
        tieneJornada: true,
      ));
    }
  }

  setState(() { _semana = lista; _diaSeleccionado = 0; });
  if (lista.isNotEmpty) _cargarCitasDia(lista[0].fecha);
}

  Future<void> _cargarCitasDia(String fecha) async {
    setState(() => _loadingCitas = true);
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/citas/barbero/${widget.barberId}?fecha=$fecha'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _citas        = (data['citas'] as List? ?? []).map((c) => CitaCard.fromJson(c)).toList();
          _loadingCitas = false;
        });
      } else {
        setState(() => _loadingCitas = false);
      }
    } catch (e) {
      debugPrint('Error cargando citas: $e');
      setState(() => _loadingCitas = false);
    }
  }

 Future<void> _irAlMapa(CitaCard cita) async {
  if (cita.lat == null || cita.lng == null) return;

  // ── Verificar fecha/hora ──────────────────────────────────────
  final ahora      = DateTime.now();
  final fechaParts = cita.fecha.split('-');
  final horaParts  = cita.hora.split(':');
  final fechaCita  = DateTime(
    int.parse(fechaParts[0]),
    int.parse(fechaParts[1]),
    int.parse(fechaParts[2]),
    int.parse(horaParts[0]),
    int.parse(horaParts[1]),
  );

  final esMismoDia = ahora.year == fechaCita.year &&
      ahora.month == fechaCita.month &&
      ahora.day == fechaCita.day;
  final esAntesDeFecha = ahora.isBefore(
      DateTime(fechaCita.year, fechaCita.month, fechaCita.day));
  final esAntesDeHora  = esMismoDia && ahora.isBefore(fechaCita);

  String? mensajeAdvertencia;
  if (esAntesDeFecha) {
    mensajeAdvertencia =
        'La fecha de esta cita es el ${cita.fecha}. ¿Estás seguro de que quieres iniciar el traslado ahora?';
  } else if (esAntesDeHora) {
    mensajeAdvertencia =
        'La hora de la cita aún no ha llegado (${cita.hora}). ¿Estás seguro de que quieres iniciar el traslado ahora?';
  }

  if (mensajeAdvertencia != null) {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
          const SizedBox(width: 8),
          const Text('Atención', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ]),
        content: Text(mensajeAdvertencia!, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRojo,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, continuar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
  }

  // ── Capturar ubicación del barbero ────────────────────────────
  try {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      await Geolocator.requestPermission();
    }
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    final distancia = Geolocator.distanceBetween(
      pos.latitude, pos.longitude,
      cita.lat!, cita.lng!,
    ) / 1000; // metros → km

    setState(() => _distanciasCapturadasIr[cita.id] = distancia);

    // Actualizar distancia en backend
    await http.put(
      Uri.parse('$baseUrl/api/citas/${cita.id}/distancia'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'distanciaKm': distancia}),
    );
  } catch (e) {
    debugPrint('Error obteniendo ubicación: $e');
  }

  // ── Abrir mapa ────────────────────────────────────────────────
  final Uri url = Uri.parse(
    'maps://maps.apple.com/?daddr=${cita.lat},${cita.lng}&dirflg=d');
  if (await canLaunchUrl(url)) await launchUrl(url);
}

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kGrisFondo,
      child: Column(
        children: [
          ListenableBuilder(
            listenable: _state,
            builder: (context, _) => _buildHeader(),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _kRojo))
                : RefreshIndicator(
                    color: _kRojo,
                    onRefresh: _cargarSemana,
                    child: _buildContenido(),
                  ),
          ),
        ],
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: _kRojo,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mi Agenda',
                    style: TextStyle(color: _kBlanco, fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_fechaFormateado(),
                    style: TextStyle(color: _kBlanco.withOpacity(0.75), fontSize: 13)),
                ],
              ),
              Row(children: [
                GestureDetector(
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => BarberDisponibilidadScreen(barberId: widget.barberId ?? '')));
                    _cargarSemana();
                  },
                  child: Container(
                    width: 36, height: 36,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: _kBlanco.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.tune_rounded, color: _kBlanco, size: 18),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8,
                        decoration: BoxDecoration(color: _state.modoDotColor, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(_state.modoTexto,
                        style: const TextStyle(color: _kBlanco, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ── CONTENIDO ─────────────────────────────────────────────────────
  Widget _buildContenido() {
    if (!_tieneHorario) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => BarberDisponibilidadScreen(barberId: widget.barberId ?? '')));
              _cargarSemana();
            },
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _kBlanco, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      color: _kRojo.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(18)),
                    child: const Icon(Icons.tune_rounded, color: _kRojo, size: 28)),
                  const SizedBox(height: 16),
                  const Text('Configura tu disponibilidad',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kNegro)),
                  const SizedBox(height: 8),
                  Text('Define qué días y horarios trabajas para que los usuarios puedan agendar contigo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _kNavy, borderRadius: BorderRadius.circular(14)),
                    child: const Center(child: Text('Configurar ahora',
                      style: TextStyle(color: _kBlanco, fontWeight: FontWeight.bold, fontSize: 14))),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      children: [
        _buildSelectorSemana(),
        const SizedBox(height: 20),
        _buildSeccionLabel('Citas del día'),
        const SizedBox(height: 12),
        _buildListaCitas(),
        const SizedBox(height: 110),
      ],
    );
  }

  // ── SELECTOR SEMANA ───────────────────────────────────────────────
  Widget _buildSelectorSemana() {
    if (_semana.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _semana.length,
        itemBuilder: (context, i) {
          final dia   = _semana[i];
          final esHoy = dia.fecha == _fechaHoy();
          final selec = i == _diaSeleccionado;
          return GestureDetector(
            onTap: () { setState(() => _diaSeleccionado = i); _cargarCitasDia(dia.fecha); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              width: 58,
              decoration: BoxDecoration(
                color: selec ? _kRojo : _kBlanco,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selec ? _kRojo : (esHoy ? _kRojo.withOpacity(0.4) : Colors.grey.shade200),
                  width: esHoy && !selec ? 1.5 : 1)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(dia.diaSemana.substring(0, 3),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: selec ? _kBlanco.withOpacity(0.8) : Colors.grey.shade500)),
                  const SizedBox(height: 4),
                  Text(dia.fecha.split('-')[2],
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                      color: selec ? _kBlanco : _kNegro)),
                  const SizedBox(height: 4),
                  Container(width: 6, height: 6,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      color: selec ? _kBlanco.withOpacity(0.5) : Colors.transparent)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── LISTA CITAS ───────────────────────────────────────────────────
  Widget _buildListaCitas() {
    if (_loadingCitas) {
      return const Center(child: Padding(padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(color: _kRojo)));
    }
    if (_citas.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: _kBlanco, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200)),
        child: Center(child: Column(children: [
          Icon(Icons.calendar_today_outlined, size: 36, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text('Sin citas por ahora', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
        ])),
      );
    }
    return Column(children: _citas.map((c) => _buildCitaCard(c)).toList());
  }

  Widget _buildCitaCard(CitaCard cita) {
    Color statusColor;
    String statusLabel;
    switch (cita.status) {
      case 'en_camino':  statusColor = Colors.orange; statusLabel = 'En camino';  break;
      case 'en_proceso': statusColor = Colors.green;  statusLabel = 'En proceso'; break;
      case 'finalizada': statusColor = Colors.grey;   statusLabel = 'Finalizada'; break;
      case 'completada': statusColor = Colors.grey;   statusLabel = 'Completada'; break;
      case 'aceptada':   statusColor = Colors.green;  statusLabel = 'Aceptada';   break;
      default:           statusColor = _kRojo;        statusLabel = 'Confirmada';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kBlanco, borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cita.status == 'en_proceso'
              ? Colors.green.withOpacity(0.4) : Colors.grey.shade200,
          width: cita.status == 'en_proceso' ? 1.5 : 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: const Color(0xFFFFEBEB), shape: BoxShape.circle,
              image: cita.clienteFoto != null
                  ? DecorationImage(image: NetworkImage('$baseUrl${cita.clienteFoto}'), fit: BoxFit.cover)
                  : null),
            child: cita.clienteFoto == null
                ? const Icon(Icons.person, color: _kRojo, size: 24) : null),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cita.clienteNombre,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kNegro)),
            Text(cita.servicios, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(statusLabel,
              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 14),
        Row(children: [
          _buildCitaInfo(Icons.access_time, cita.hora),
          const SizedBox(width: 16),
          _buildCitaInfo(Icons.payments_outlined, '\$${cita.precioTotal.toStringAsFixed(0)}'),
          if (cita.distanciaKm != null) ...[
            const SizedBox(width: 16),
            _buildCitaInfo(Icons.directions_car_outlined,
              '${cita.distanciaKm!.toStringAsFixed(1)} km'),
          ],
        ]),
        if (cita.domicilio.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.location_on_outlined, size: 16, color: _kRojo),
            const SizedBox(width: 6),
            Expanded(child: Text(cita.domicilio,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ],
        const SizedBox(height: 16),
        if (cita.status == 'aceptada') ...[
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kRojo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0),
                onPressed: () => _irAlMapa(cita),
                icon: const Icon(Icons.navigation_outlined, color: _kBlanco, size: 18),
                label: const Text('IR',
                  style: TextStyle(color: _kBlanco, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0),
                onPressed: () => _responderCita(cita.id, 'llegar'),
                icon: const Icon(Icons.home_outlined, color: _kBlanco, size: 18),
                label: const Text('LLEGUÉ',
                  style: TextStyle(color: _kBlanco, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ]),
        ] else if (cita.status == 'en_proceso') ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0),
              onPressed: () => _responderCita(cita.id, 'finalizar'),
              icon: const Icon(Icons.check_circle_outline, color: _kBlanco, size: 18),
              label: const Text('FINALIZAR SERVICIO',
                style: TextStyle(color: _kBlanco, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildCitaInfo(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15, color: _kRojo),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _kNegro)),
    ]);
  }

  Widget _buildSeccionLabel(String titulo) {
    return Row(children: [
      Container(width: 4, height: 16,
        decoration: BoxDecoration(color: _kRojo, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kNegro)),
    ]);
  }

  String _fechaHoy() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
  }

  String _fechaFormateado() {
    const dias  = ['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'];
    const meses = ['enero','febrero','marzo','abril','mayo','junio',
                   'julio','agosto','septiembre','octubre','noviembre','diciembre'];
    final now = DateTime.now();
    return '${dias[now.weekday - 1]}, ${now.day} de ${meses[now.month - 1]}';
  }

  void _mostrarSnack(String msg, {bool esExito = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: esExito ? Colors.green.shade700 : _kNegro,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _mostrarDesglosePrecio(dynamic desglose, dynamic costoTotal) {
  final double total      = (costoTotal ?? 0).toDouble();
  final double base       = (desglose['precioBase']  ?? 0).toDouble();
  final double traslado   = (desglose['traslado']    ?? 0).toDouble();
  final double comision   = (desglose['comision']    ?? 0).toDouble();
  final double iva        = (total - (desglose['subtotal'] ?? 0)).toDouble();
  final String nivel      = desglose['nivel']        ?? 'bajo';

  Color nivelColor;
  String nivelLabel;
  switch (nivel) {
    case 'alto':  nivelColor = const Color(0xFFF59E0B); nivelLabel = 'Premium ★★★'; break;
    case 'medio': nivelColor = _kRojo;                  nivelLabel = 'Estándar ★★';  break;
    default:      nivelColor = Colors.grey;             nivelLabel = 'Básico ★';
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),

          // Ícono y título
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded,
              color: Colors.green, size: 30)),
          const SizedBox(height: 12),
          const Text('Servicio completado',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kNegro)),
          const SizedBox(height: 4),
          Text('Resumen del cobro',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          const SizedBox(height: 20),

          // Badge nivel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: nivelColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: nivelColor.withOpacity(0.3))),
            child: Text('Tarifa $nivelLabel',
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: nivelColor))),
          const SizedBox(height: 20),

          // Desglose
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                _buildFilaDesglose('Servicios',  '\$${base.toStringAsFixed(0)}',     false),
                const SizedBox(height: 10),
                _buildFilaDesglose('Traslado',   '\$${traslado.toStringAsFixed(0)}', false),
                const SizedBox(height: 10),
                _buildFilaDesglose('Comisión app (15%)', '\$${comision.toStringAsFixed(0)}', false),
                const SizedBox(height: 10),
                _buildFilaDesglose('IVA (16%)',  '\$${iva.toStringAsFixed(0)}',      false),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1)),
                _buildFilaDesglose('Total',      '\$${total.toStringAsFixed(0)}',    true),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Botón cerrar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kNegro,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0),
              child: const Text('Listo',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildFilaDesglose(String label, String valor, bool esTotal) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label,
        style: TextStyle(
          fontSize: esTotal ? 15 : 13,
          fontWeight: esTotal ? FontWeight.bold : FontWeight.normal,
          color: esTotal ? _kNegro : Colors.grey.shade600)),
      Text(valor,
        style: TextStyle(
          fontSize: esTotal ? 16 : 13,
          fontWeight: FontWeight.bold,
          color: esTotal ? _kRojo : _kNegro)),
    ],
  );
}
}
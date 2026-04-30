import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:barber_app/config/app_config.dart';
import 'barber_state.dart';

// ─────────────────────────────────────────────
//  MODELOS
// ─────────────────────────────────────────────

class DiaAgenda {
  final String fecha;
  final String diaSemana;
  final bool tieneJornada;
  final JornadaInfo? jornada;

  DiaAgenda({required this.fecha, required this.diaSemana, required this.tieneJornada, this.jornada});

  factory DiaAgenda.fromJson(Map<String, dynamic> json) => DiaAgenda(
    fecha:        json['fecha'],
    diaSemana:    json['diaSemana'],
    tieneJornada: json['tieneJornada'] ?? false,
    jornada:      json['jornada'] != null ? JornadaInfo.fromJson(json['jornada']) : null,
  );
}

class JornadaInfo {
  final String id;
  final String inicioHora;
  final String finHora;
  final int totalSlots;
  final DescansoInfo? descanso;

  JornadaInfo({required this.id, required this.inicioHora, required this.finHora, required this.totalSlots, this.descanso});

  factory JornadaInfo.fromJson(Map<String, dynamic> json) => JornadaInfo(
    id:         json['id'] ?? '',
    inicioHora: json['inicioHora'] ?? '',
    finHora:    json['finHora'] ?? '',
    totalSlots: json['totalSlots'] ?? 0,
    descanso:   json['descanso'] != null ? DescansoInfo.fromJson(json['descanso']) : null,
  );
}

class DescansoInfo {
  final String inicioHora;
  final String finHora;
  DescansoInfo({required this.inicioHora, required this.finHora});
  factory DescansoInfo.fromJson(Map<String, dynamic> json) =>
      DescansoInfo(inicioHora: json['inicioHora'] ?? '', finHora: json['finHora'] ?? '');
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
  List<DiaAgenda> _semana   = [];
  int _diaSeleccionado      = 0;
  List<CitaCard> _citas     = [];
  bool _loadingCitas        = false;

  // Polling
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
  // Esperamos 2 segundos para que el widget esté completamente montado
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
    debugPrint('🔔 Verificando pendientes... dialog: $_mostrandoDialog mounted: $mounted');
    if (_mostrandoDialog || !mounted) return;
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/citas/barbero/${widget.barberId}/pendientes'),
      );
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
    final String nombre    = cita['clienteNombre'] ?? 'Cliente';
    final List   servicios = cita['servicios']     ?? [];
    final String hora      = cita['hora']          ?? '';
    final String fecha     = cita['fecha']         ?? '';
    final String citaId    = cita['_id'].toString();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEBEB), shape: BoxShape.circle),
              child: const Icon(Icons.person, color: _kRojo, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('Nueva solicitud',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nombre,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Servicios: ${servicios.join(', ')}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(height: 4),
            Text('$fecha a las $hora',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _responderCita(citaId, 'rechazar');
            },
            child: const Text('Rechazar', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _mostrarDialogReagendar(citaId);
            },
            child: const Text('Reagendar', style: TextStyle(color: Colors.orange)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRojo,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context);
              _responderCita(citaId, 'aceptar');
            },
            child: const Text('Aceptar', style: TextStyle(color: _kBlanco)),
          ),
        ],
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
       String mensaje;
bool esExito = true;
switch (accion) {
  case 'aceptar':   mensaje = 'Cita aceptada';        break;
  case 'rechazar':  mensaje = 'Cita rechazada';  esExito = false; break;
  case 'llegar':    mensaje = 'Llegada registrada';    break;
  case 'finalizar': mensaje = 'Servicio finalizado';   break;
  default:          mensaje = 'Acción completada';
}
_mostrarSnack(mensaje, esExito: esExito);
        _cargarSemana();
        _cargarCitasDia(_semana.isNotEmpty ? _semana[_diaSeleccionado].fecha : _fechaHoy());
      } else {
        _mostrarSnack('Error al responder la cita');
      }
    } catch (e) {
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
                      child: child!,
                    ),
                  );
                  if (t != null) setModalState(() => nuevaHora = t);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _kGrisFondo,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, color: _kRojo),
                      const SizedBox(width: 10),
                      Text(
                        '${nuevaHora.hour.toString().padLeft(2,'0')}:${nuevaHora.minute.toString().padLeft(2,'0')}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kRojo,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    final hora  = '${nuevaHora.hour.toString().padLeft(2,'0')}:${nuevaHora.minute.toString().padLeft(2,'0')}';
                    final fecha = _fechaHoy();
                    try {
                      final res = await http.put(
                        Uri.parse('$baseUrl/api/citas/$citaId/responder'),
                        headers: {'Content-Type': 'application/json'},
                        body: json.encode({
                          'accion':     'reagendar',
                          'nuevaHora':  hora,
                          'nuevaFecha': fecha,
                        }),
                      );
                      if (res.statusCode == 200) {
                        _mostrarSnack('Reagendado correctamente', esExito: true);
                        _cargarSemana();
                      } else {
                        _mostrarSnack('No se pudo reagendar');
                      }
                    } catch (e) {
                      _mostrarSnack('Error de conexión');
                    }
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
      final hoy = _fechaHoy();
      final res = await http.get(
        Uri.parse('$baseUrl/api/disponibilidad/${widget.barberId}/jornadas?fechaInicio=$hoy'),
      );
      if (res.statusCode == 200) {
        final data  = json.decode(res.body);
        final lista = (data['semana'] as List).map((d) => DiaAgenda.fromJson(d)).toList();
        setState(() { _semana = lista; _isLoading = false; });
        if (lista.isNotEmpty) _cargarCitasDia(lista[0].fecha);
      }
    } catch (e) {
      debugPrint('Error cargando semana: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarCitasDia(String fecha) async {
    setState(() => _loadingCitas = true);
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/citas/barbero/${widget.barberId}?fecha=$fecha'),
      );
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

  // ── ABRIR JORNADA ─────────────────────────────────────────────────

  void _mostrarDialogoAbrirJornada(DiaAgenda dia) {
    TimeOfDay inicioHora     = const TimeOfDay(hour: 9,  minute: 0);
    TimeOfDay finHora        = const TimeOfDay(hour: 14, minute: 0);
    bool tieneDescanso       = false;
    TimeOfDay descansoInicio = const TimeOfDay(hour: 12, minute: 0);
    TimeOfDay descansoFin    = const TimeOfDay(hour: 13, minute: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
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
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(children: [
                Container(width: 4, height: 20,
                  decoration: BoxDecoration(color: _kRojo, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                Text('Abrir jornada — ${dia.diaSemana}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kNegro)),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _buildTimePicker(label: 'Inicio', hora: inicioHora,
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: inicioHora,
                      builder: (ctx, child) => _timePickerTheme(ctx, child));
                    if (t != null) setModalState(() => inicioHora = t);
                  })),
                const SizedBox(width: 12),
                Expanded(child: _buildTimePicker(label: 'Fin', hora: finHora,
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: finHora,
                      builder: (ctx, child) => _timePickerTheme(ctx, child));
                    if (t != null) setModalState(() => finHora = t);
                  })),
              ]),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => setModalState(() => tieneDescanso = !tieneDescanso),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: tieneDescanso ? _kRojo.withOpacity(0.08) : _kGrisFondo,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: tieneDescanso ? _kRojo.withOpacity(0.3) : Colors.grey.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.free_breakfast_outlined, size: 18,
                      color: tieneDescanso ? _kRojo : Colors.grey.shade500),
                    const SizedBox(width: 10),
                    Text('Agregar descanso', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: tieneDescanso ? _kRojo : Colors.grey.shade600)),
                    const Spacer(),
                    Icon(tieneDescanso ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: tieneDescanso ? _kRojo : Colors.grey.shade400),
                  ]),
                ),
              ),
              if (tieneDescanso) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _buildTimePicker(label: 'Descanso inicio', hora: descansoInicio,
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: descansoInicio,
                        builder: (ctx, child) => _timePickerTheme(ctx, child));
                      if (t != null) setModalState(() => descansoInicio = t);
                    })),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTimePicker(label: 'Descanso fin', hora: descansoFin,
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: descansoFin,
                        builder: (ctx, child) => _timePickerTheme(ctx, child));
                      if (t != null) setModalState(() => descansoFin = t);
                    })),
                ]),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kRojo,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _abrirJornada(dia: dia, inicioHora: inicioHora, finHora: finHora,
                      descanso: tieneDescanso
                          ? {'inicioHora': _formatHora(descansoInicio), 'finHora': _formatHora(descansoFin)}
                          : null);
                  },
                  child: const Text('Abrir jornada',
                    style: TextStyle(color: _kBlanco, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrirJornada({
    required DiaAgenda dia,
    required TimeOfDay inicioHora,
    required TimeOfDay finHora,
    Map<String, String>? descanso,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/disponibilidad/${widget.barberId}/jornada'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'fecha': dia.fecha, 'inicioHora': _formatHora(inicioHora), 'finHora': _formatHora(finHora),
          'descanso': ?descanso,
        }),
      );
      if (res.statusCode == 201) {
        final data = json.decode(res.body);
        await _state.cargarEstado();
        _mostrarSnack('Jornada abierta — ${data['jornada']['totalSlots']} slots generados', esExito: true);
        _cargarSemana();
      } else {
        final data = json.decode(res.body);
        _mostrarSnack(data['msg'] ?? 'Error al abrir jornada');
      }
    } catch (e) { _mostrarSnack('Error de conexión'); }
  }

  void _confirmarCerrarJornada(DiaAgenda dia) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Cerrar jornada?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Se cancelarán todos los slots disponibles del ${dia.diaSemana}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kRojo, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () { Navigator.pop(context); _cerrarJornada(dia); },
            child: const Text('Cerrar', style: TextStyle(color: _kBlanco)),
          ),
        ],
      ),
    );
  }

  Future<void> _cerrarJornada(DiaAgenda dia) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/api/disponibilidad/${widget.barberId}/jornada/${dia.jornada!.id}'),
      );
      if (res.statusCode == 200) {
        await _state.cargarEstado();
        _mostrarSnack('Jornada cerrada', esExito: true);
        _cargarSemana();
      } else {
        final data = json.decode(res.body);
        _mostrarSnack(data['msg'] ?? 'No se pudo cerrar');
      }
    } catch (e) { _mostrarSnack('Error de conexión'); }
  }

  Future<void> _irAlMapa(CitaCard cita) async {
    if (cita.lat == null || cita.lng == null) return;
    final Uri url = Uri.parse('maps://maps.apple.com/?daddr=${cita.lat},${cita.lng}&dirflg=d');
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContenido() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      children: [
        _buildSelectorSemana(),
        const SizedBox(height: 20),
        if (_semana.isNotEmpty) _buildInfoJornada(_semana[_diaSeleccionado]),
        const SizedBox(height: 20),
        if (_semana.isNotEmpty && _semana[_diaSeleccionado].tieneJornada) ...[
          _buildSeccionLabel('Citas del día'),
          const SizedBox(height: 12),
          _buildListaCitas(),
        ],
        const SizedBox(height: 110),
      ],
    );
  }

  Widget _buildSelectorSemana() {
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
                  width: esHoy && !selec ? 1.5 : 1,
                ),
              ),
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
                      color: dia.tieneJornada ? (selec ? _kBlanco : _kRojo) : Colors.transparent)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoJornada(DiaAgenda dia) {
    if (!dia.tieneJornada) {
      return GestureDetector(
        onTap: () => _mostrarDialogoAbrirJornada(dia),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _kBlanco, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200)),
          child: Row(
            children: [
              Container(width: 44, height: 44,
                decoration: BoxDecoration(color: _kRojo.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.add, color: _kRojo, size: 22)),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Abrir jornada',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kNegro)),
                Text('Toca para definir tu horario de trabajo',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ]),
              const Spacer(),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      );
    }

    final j = dia.jornada!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _kNegro, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.work_outline, color: _kBlanco, size: 18),
              const SizedBox(width: 8),
              Text('${j.inicioHora} — ${j.finHora}',
                style: const TextStyle(color: _kBlanco, fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              GestureDetector(
                onTap: () => _confirmarCerrarJornada(dia),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: _kRojo, borderRadius: BorderRadius.circular(8)),
                  child: const Text('Cerrar',
                    style: TextStyle(color: _kBlanco, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            _buildJornadaStat('${j.totalSlots}', 'slots'),
            if (j.descanso != null) ...[
              const SizedBox(width: 12),
              _buildJornadaStat('${j.descanso!.inicioHora}–${j.descanso!.finHora}', 'descanso'),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _buildJornadaStat(String valor, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: _kBlanco.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(valor, style: const TextStyle(color: _kBlanco, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: _kBlanco.withOpacity(0.6), fontSize: 12)),
      ]),
    );
  }

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
              ? Colors.green.withOpacity(0.4)
              : Colors.grey.shade200,
          width: cita.status == 'en_proceso' ? 1.5 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: const Color(0xFFFFEBEB), shape: BoxShape.circle,
              image: cita.clienteFoto != null
                  ? DecorationImage(image: NetworkImage('$baseUrl${cita.clienteFoto}'), fit: BoxFit.cover)
                  : null),
            child: cita.clienteFoto == null
                ? const Icon(Icons.person, color: _kRojo, size: 24)
                : null),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cita.clienteNombre,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kNegro)),
            Text(cita.servicios,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
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

        // ── Botones según status ───────────────────────────────────
        if (cita.status == 'aceptada') ...[
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kRojo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0,
                ),
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
                  padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0,
                ),
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
                padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0,
              ),
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

  Widget _buildTimePicker({required String label, required TimeOfDay hora, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: _kGrisFondo, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.access_time, size: 16, color: _kRojo),
            const SizedBox(width: 6),
            Text(_formatHora(hora),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kNegro)),
          ]),
        ]),
      ),
    );
  }

  Widget _timePickerTheme(BuildContext ctx, Widget? child) {
    return Theme(
      data: Theme.of(ctx).copyWith(
        colorScheme: const ColorScheme.light(primary: _kRojo, onPrimary: _kBlanco, surface: _kBlanco)),
      child: child!,
    );
  }

  String _formatHora(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

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
}

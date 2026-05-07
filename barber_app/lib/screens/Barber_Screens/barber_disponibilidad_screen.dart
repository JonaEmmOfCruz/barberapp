import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:barber_app/config/app_config.dart';

const _kRojo   = Color(0xFFE8202A);
const _kNegro  = Color(0xFF1A1A1A);
const _kNavy   = Color(0xFF1A1A2E);
const _kBlanco = Colors.white;
const _kGris   = Color(0xFFF5F5F5);

class BarberDisponibilidadScreen extends StatefulWidget {
  final String barberId;
  const BarberDisponibilidadScreen({super.key, required this.barberId});

  @override
  State<BarberDisponibilidadScreen> createState() => _BarberDisponibilidadScreenState();
}

class _BarberDisponibilidadScreenState extends State<BarberDisponibilidadScreen> {
  final String baseUrl = AppConfig.baseUrl;
  bool _isLoading = true;
  bool _isSaving  = false;

  // Días de la semana
  final List<bool>      _diasActivos  = [false, true, true, true, true, true, true];
  final List<TimeOfDay> _horasInicio  = List.generate(7, (_) => const TimeOfDay(hour: 9,  minute: 0));
  final List<TimeOfDay> _horasFin     = List.generate(7, (_) => const TimeOfDay(hour: 18, minute: 0));

  // Días bloqueados
  final Set<String> _diasBloqueados = {};

  // Servicios con duración
  List<Map<String, dynamic>> _servicios = [];
  bool _usarPromedioReal = false;

  final List<String> _nombresDias        = ['D', 'L', 'M', 'X', 'J', 'V', 'S'];
  final List<String> _nombresDiasCompletos = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];

  // Duraciones por defecto según servicio
  int _duracionDefault(String nombre) {
    switch (nombre.toLowerCase()) {
      case 'corte':     return 45;
      case 'barba':     return 25;
      case 'ceja':      return 10;
      case 'greka':     return 15;
      case 'tinte':     return 40;
      case 'mascarilla': return 20;
      default:          return 30;
    }
  }

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    await Future.wait([_cargarHorario(), _cargarServicios()]);
    setState(() => _isLoading = false);
  }

  Future<void> _cargarServicios() async {
    try {
      // Cargar servicios del barbero
      final resServ = await http.get(
        Uri.parse('$baseUrl/api/barbers/${widget.barberId}/servicios'));
      
      // Cargar duraciones guardadas
      final resDisp = await http.get(
        Uri.parse('$baseUrl/api/disponibilidad/${widget.barberId}/horario'));

      List<String> nombresServicios = [];
      Map<String, int> duracionesGuardadas = {};

      if (resServ.statusCode == 200) {
        final data = jsonDecode(resServ.body);
        nombresServicios = List<String>.from(data['servicios'] ?? []);
      }

      if (resDisp.statusCode == 200) {
        final data = jsonDecode(resDisp.body);
        if (data['duracionPorServicio'] != null) {
          for (var d in data['duracionPorServicio']) {
            duracionesGuardadas[d['nombre'].toString().toLowerCase()] = d['duracionMin'] as int;
          }
        }
        _usarPromedioReal = data['usarPromedioReal'] ?? false;
      }

      setState(() {
        _servicios = nombresServicios.map((nombre) {
          final key = nombre.toLowerCase();
          return {
            'nombre':      nombre,
            'duracionMin': duracionesGuardadas[key] ?? _duracionDefault(nombre),
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Error cargando servicios: $e');
    }
  }

  Future<void> _cargarHorario() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/disponibilidad/${widget.barberId}/horario'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['diasDisponibles'] != null) {
          final dias = data['diasDisponibles'] as List;
          final diasEnLista = dias.map((d) => d['dia'] as int).toSet();
          for (int i = 0; i < 7; i++) {
            _diasActivos[i] = diasEnLista.contains(i);
          }
          for (var d in dias) {
            final idx       = d['dia'] as int;
            final inicioStr = d['inicioHora'] as String;
            final finStr    = d['finHora']    as String;
            _horasInicio[idx] = TimeOfDay(
              hour:   int.parse(inicioStr.split(':')[0]),
              minute: int.parse(inicioStr.split(':')[1]));
            _horasFin[idx] = TimeOfDay(
              hour:   int.parse(finStr.split(':')[0]),
              minute: int.parse(finStr.split(':')[1]));
          }
        }
        if (data['diasBloqueados'] != null) {
          for (var b in data['diasBloqueados']) {
            _diasBloqueados.add(b['fecha'] as String);
          }
        }
      }
    } catch (e) {
      debugPrint('Error cargando horario: $e');
    }
  }

  Future<void> _guardar() async {
    setState(() => _isSaving = true);
    try {
      final diasDisponibles = <Map<String, dynamic>>[];
      for (int i = 0; i < 7; i++) {
        if (_diasActivos[i]) {
          diasDisponibles.add({
            'dia':        i,
            'inicioHora': _formatHora(_horasInicio[i]),
            'finHora':    _formatHora(_horasFin[i]),
          });
        }
      }

      final res = await http.post(
        Uri.parse('$baseUrl/api/disponibilidad/${widget.barberId}/horario'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'diasDisponibles':    diasDisponibles,
          'duracionPorServicio': _servicios,
        }),
      );

      if (res.statusCode == 200) {
        _mostrarSnack('Disponibilidad guardada', esExito: true);
        Navigator.pop(context);
      } else {
        _mostrarSnack('Error al guardar');
      }
    } catch (_) {
      _mostrarSnack('Error de conexión');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _toggleDiaBloqueado(String fecha) async {
    final estaBloqueado = _diasBloqueados.contains(fecha);
    try {
      if (estaBloqueado) {
        await http.delete(
          Uri.parse('$baseUrl/api/disponibilidad/${widget.barberId}/bloquear'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'fecha': fecha}),
        );
        setState(() => _diasBloqueados.remove(fecha));
      } else {
        await http.post(
          Uri.parse('$baseUrl/api/disponibilidad/${widget.barberId}/bloquear'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'fecha': fecha}),
        );
        setState(() => _diasBloqueados.add(fecha));
      }
    } catch (_) {
      _mostrarSnack('Error de conexión');
    }
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kGris,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kRojo))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildSeccionDias()),
                SliverToBoxAdapter(child: _buildSeccionHorarios()),
                SliverToBoxAdapter(child: _buildSeccionDuracion()),
                SliverToBoxAdapter(child: _buildSeccionCalendario()),
                SliverToBoxAdapter(child: _buildBotonGuardar()),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: _kRojo,
      width: double.infinity,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _kBlanco.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.arrow_back_ios_new, color: _kBlanco, size: 16),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Mi disponibilidad',
                style: TextStyle(color: _kBlanco, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Configura tu horario de trabajo',
                style: TextStyle(color: _kBlanco.withOpacity(0.65), fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  // ── DÍAS DE LA SEMANA ─────────────────────────────────────────────
  Widget _buildSeccionDias() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSeccionLabel('DÍAS DE LA SEMANA'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kBlanco,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200, width: 0.5)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final activo = _diasActivos[i];
                return GestureDetector(
                  onTap: () => setState(() => _diasActivos[i] = !activo),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: activo ? _kNavy : _kGris,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: activo ? _kNavy : Colors.grey.shade200, width: 0.5)),
                    child: Center(
                      child: Text(_nombresDias[i],
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold,
                          color: activo ? _kBlanco : Colors.grey.shade500)),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── HORARIOS ──────────────────────────────────────────────────────
  Widget _buildSeccionHorarios() {
    final diasActivos = List.generate(7, (i) => i).where((i) => _diasActivos[i]).toList();
    if (diasActivos.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSeccionLabel('HORARIO POR DÍA'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: _kBlanco,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200, width: 0.5)),
            child: Column(
              children: diasActivos.asMap().entries.map((entry) {
                final idx    = entry.value;
                final isLast = entry.key == diasActivos.length - 1;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: isLast ? null : Border(
                      bottom: BorderSide(color: Colors.grey.shade100, width: 0.5))),
                  child: Row(
                    children: [
                      SizedBox(width: 80,
                        child: Text(_nombresDiasCompletos[idx],
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kNegro))),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final t = await showTimePicker(
                              context: context, initialTime: _horasInicio[idx],
                              builder: (ctx, child) => _timeTheme(ctx, child));
                            if (t != null) setState(() => _horasInicio[idx] = t);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: _kGris, borderRadius: BorderRadius.circular(8)),
                            child: Text(_formatHora(_horasInicio[idx]),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kNegro))),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text('—', style: TextStyle(color: Colors.grey.shade400, fontSize: 13))),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final t = await showTimePicker(
                              context: context, initialTime: _horasFin[idx],
                              builder: (ctx, child) => _timeTheme(ctx, child));
                            if (t != null) setState(() => _horasFin[idx] = t);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: _kGris, borderRadius: BorderRadius.circular(8)),
                            child: Text(_formatHora(_horasFin[idx]),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kNegro))),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── DURACIÓN POR SERVICIO ─────────────────────────────────────────
  Widget _buildSeccionDuracion() {
    if (_servicios.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSeccionLabel('DURACIÓN POR SERVICIO'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: _kBlanco,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200, width: 0.5)),
            child: Column(
              children: _servicios.asMap().entries.map((entry) {
                final idx     = entry.key;
                final svc     = entry.value;
                final nombre  = svc['nombre'] as String;
                final duracion = svc['duracionMin'] as int;
                final isLast  = idx == _servicios.length - 1;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: isLast ? null : Border(
                      bottom: BorderSide(color: Colors.grey.shade100, width: 0.5))),
                  child: Row(
                    children: [
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEB),
                          borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.content_cut, color: _kRojo, size: 16)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(nombre,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kNegro))),
                      // Botón menos
                      GestureDetector(
                        onTap: _usarPromedioReal ? null : () {
                          if (duracion > 5) {
                            setState(() => _servicios[idx]['duracionMin'] = duracion - 5);
                          }
                        },
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: _usarPromedioReal ? Colors.grey.shade100 : _kGris,
                            borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.remove, size: 16,
                            color: _usarPromedioReal ? Colors.grey.shade300 : Colors.grey.shade600)),
                      ),
                      // Valor
                      SizedBox(
                        width: 54,
                        child: Text('$duracion min',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold,
                            color: _usarPromedioReal ? Colors.grey.shade400 : _kNegro))),
                      // Botón más
                      GestureDetector(
                        onTap: _usarPromedioReal ? null : () {
                          setState(() => _servicios[idx]['duracionMin'] = duracion + 5);
                        },
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: _usarPromedioReal ? Colors.grey.shade100 : _kNavy,
                            borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.add, size: 16,
                            color: _usarPromedioReal ? Colors.grey.shade300 : _kBlanco)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          // Aviso promedio real
          if (_usarPromedioReal)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.auto_graph, color: Color(0xFFF59E0B), size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Usando promedio real basado en tus servicios completados.',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade800))),
              ]),
            )
          else
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(Icons.info_outline, color: Colors.blue.shade400, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Después de 10 servicios completados, se calculará el promedio real automáticamente.',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade700))),
              ]),
            ),
        ],
      ),
    );
  }

  // ── CALENDARIO ────────────────────────────────────────────────────
  Widget _buildSeccionCalendario() {
    final hoy  = DateTime.now();
    final dias = List.generate(30, (i) => hoy.add(Duration(days: i)));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSeccionLabel('DÍAS BLOQUEADOS — PRÓXIMOS 30 DÍAS'),
          const SizedBox(height: 4),
          Text('Toca un día disponible para bloquearlo',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kBlanco,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200, width: 0.5)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['D','L','M','X','J','V','S'].map((d) =>
                    SizedBox(width: 36,
                      child: Text(d, textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: Colors.grey.shade400)))).toList(),
                ),
                const SizedBox(height: 8),
                _buildCalendarioGrid(dias),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            _buildLeyenda(_kGris, Colors.grey.shade500, 'Disponible'),
            const SizedBox(width: 14),
            _buildLeyenda(const Color(0xFFFFEBEB), _kRojo, 'Bloqueado'),
            const SizedBox(width: 14),
            _buildLeyenda(_kNavy, _kBlanco, 'Hoy'),
            const SizedBox(width: 14),
            _buildLeyenda(Colors.transparent, Colors.grey.shade300, 'No laboral'),
          ]),
        ],
      ),
    );
  }

  Widget _buildCalendarioGrid(List<DateTime> dias) {
    final hoy          = DateTime.now();
    final offsetInicio = dias.first.weekday % 7;
    final celdas       = <Widget>[];

    for (int i = 0; i < offsetInicio; i++) {
      celdas.add(const SizedBox(width: 36, height: 36));
    }

    for (final dia in dias) {
      final fechaStr   = _formatFecha(dia);
      final bloqueado  = _diasBloqueados.contains(fechaStr);
      final esHoy      = dia.year == hoy.year && dia.month == hoy.month && dia.day == hoy.day;
      final diaSemana  = dia.weekday % 7;
      final esLaboral  = _diasActivos[diaSemana];

      Color bgColor;
      Color textColor;
      if (esHoy) {
        bgColor   = _kNavy;
        textColor = _kBlanco;
      } else if (bloqueado) {
        bgColor   = const Color(0xFFFFEBEB);
        textColor = _kRojo;
      } else if (esLaboral) {
        bgColor   = _kGris;
        textColor = _kNegro;
      } else {
        bgColor   = Colors.transparent;
        textColor = Colors.grey.shade300;
      }

      celdas.add(GestureDetector(
        onTap: esLaboral && !esHoy ? () => _toggleDiaBloqueado(fechaStr) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text('${dia.day}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor))),
        ),
      ));
    }

    return Wrap(spacing: 4, runSpacing: 4, children: celdas);
  }

  Widget _buildLeyenda(Color bg, Color textColor, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 14, height: 14,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade200, width: 0.5))),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
    ]);
  }

  // ── BOTÓN GUARDAR ─────────────────────────────────────────────────
  Widget _buildBotonGuardar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _guardar,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kNavy,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: _kBlanco, strokeWidth: 2))
              : const Text('Guardar cambios',
                  style: TextStyle(color: _kBlanco, fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────
  Widget _buildSeccionLabel(String titulo) {
    return Row(children: [
      Container(width: 4, height: 14,
        decoration: BoxDecoration(color: _kRojo, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(titulo,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          color: Colors.grey.shade500, letterSpacing: 0.4)),
    ]);
  }

  Widget _timeTheme(BuildContext ctx, Widget? child) => Theme(
    data: Theme.of(ctx).copyWith(
      colorScheme: const ColorScheme.light(
        primary: _kRojo, onPrimary: _kBlanco, surface: _kBlanco)),
    child: child!);

  String _formatHora(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

  String _formatFecha(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  void _mostrarSnack(String msg, {bool esExito = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: esExito ? Colors.green.shade700 : _kNavy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}
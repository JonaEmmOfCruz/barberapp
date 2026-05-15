import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:barber_app/screens/User_Screens/user_map_screen.dart';
import 'package:barber_app/screens/User_Screens/user_agenda_screen.dart';
import 'package:barber_app/screens/User_Screens/user_perfil_screen.dart';
import 'package:barber_app/screens/User_Screens/user_reservations_screen.dart';
import 'package:barber_app/screens/User_Screens/user_services_screen.dart';
import 'package:barber_app/config/app_config.dart';

const _kAzul      = Color(0xFF0D3FA6);
const _kAzulMedio = Color(0xFF1A5FD4);
const _kNavy      = Color(0xFF1A1A2E);
const _kBlanco    = Colors.white;
const _kFondo     = Color(0xFFF0F4FF);

class UserHomeScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const UserHomeScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final String baseUrl = AppConfig.baseUrl;
  int _selectedIndex = 0;

  String? _profileImageUrl;
  String  _realAddress     = "Obteniendo ubicación...";
  List<dynamic> _favoritos = [];
  List<dynamic> _reservas  = [];
  bool _isLoadingFavs      = true;
  bool _isLoadingReservas  = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  // Esta es la función que llama RefreshIndicator
  Future<void> _initData() async {
    setState(() {
      _isLoadingFavs = true;
      _isLoadingReservas = true;
    });
    
    await Future.wait([
      _loadUserPhoto(),
      _handleLocationLogic(),
      _fetchFavoritos(),
      _fetchReservasRecientes(),
    ]);
  }

  Future<void> _handleLocationLogic() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    bool isSimulator = false;
    try {
      if (Platform.isIOS) {
        var info = await deviceInfo.iosInfo;
        isSimulator = !info.isPhysicalDevice;
      } else if (Platform.isAndroid) {
        var info = await deviceInfo.androidInfo;
        isSimulator = !info.isPhysicalDevice;
      }
    } catch (_) {}
    if (isSimulator) {
      setState(() => _realAddress = "C. Falsa #123, Zapopan (Simulador)");
    } else {
      await _determineRealPosition();
    }
  }

  Future<void> _determineRealPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) { setState(() => _realAddress = "Activa tu GPS"); return; }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) { setState(() => _realAddress = "Permiso denegado"); return; }
      }
      if (permission == LocationPermission.deniedForever) { setState(() => _realAddress = "Habilita la ubicación en Ajustes"); return; }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium).timeout(const Duration(seconds: 10));
      List<Placemark> p = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (p.isNotEmpty) setState(() => _realAddress = "${p[0].street}, ${p[0].locality}");
    } catch (_) {
      setState(() => _realAddress = "Ubicación no disponible");
    }
  }

  Future<void> _loadUserPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _profileImageUrl = prefs.getString('profileImage'));
  }

  Future<void> _fetchFavoritos() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/barbers/favorites/${widget.userId}'));
     
      if (res.statusCode == 200) {
        setState(() { _favoritos = jsonDecode(res.body); _isLoadingFavs = false; });
      } else {
        setState(() => _isLoadingFavs = false);
      }
    } catch (_) { setState(() => _isLoadingFavs = false); }
  }

  Future<void> _fetchReservasRecientes() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/reservas/user/${widget.userId}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _reservas = data
              .where((r) => ['pendiente', 'aceptada', 'reagendada'].contains(r['status']))
              .take(3).toList();
          _isLoadingReservas = false;
        });
      } else {
        setState(() => _isLoadingReservas = false);
      }
    } catch (_) { setState(() => _isLoadingReservas = false); }
  }

  Future<void> _removeFavorite(String barberId) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/api/barbers/favorite'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': widget.userId, 'barberId': barberId}),
      );
      if (res.statusCode == 200) _fetchFavoritos();
    } catch (_) {}
  }

  void _goToServicio() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => UserMapScreen(userId: widget.userId, userName: widget.userName)));
  }

  Future<void> _goToAgenda() async {
  // Esperamos a que la pantalla de agenda se cierre
  final debeRefrescar = await Navigator.push(
    context, 
    MaterialPageRoute(builder: (_) => UserAgendaScreen(userId: widget.userId))
  );

  // Si recibimos el 'true' que enviamos arriba, recargamos los datos
  if (debeRefrescar == true) {
    _initData(); // Esto recarga la lista de favoritos en el Home
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kFondo,
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeContent(),
          const UserServicesScreen(),
          UserReservationsScreen(userId: widget.userId),
          UserPerfilScreen(
            onBack: () => setState(() => _selectedIndex = 0),
          ),
        ],
      ),
      bottomNavigationBar: _buildLiquidBar(),
    );
  }

  // ── HOME CONTENT CON REFRESH INDICATOR ────────────────────────────
  Widget _buildHomeContent() {
    return RefreshIndicator(
      onRefresh: _initData, // Llama a la carga completa de datos
      color: _kAzul,
      backgroundColor: _kBlanco,
      edgeOffset: 20, // Ajuste para que baje un poco el indicador
      child: CustomScrollView(
        // AlwaysScrollable permite que el Refresh funcione aunque no haya mucho contenido
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildActionCards()),
          SliverToBoxAdapter(child: _buildDosColumnas()),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: _kAzul,
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 24, right: 24, bottom: 28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bienvenido,',
                    style: TextStyle(color: _kBlanco.withOpacity(0.65), fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(widget.userName,
                    style: const TextStyle(color: _kBlanco, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedIndex = 3),
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _kBlanco.withOpacity(0.4), width: 2),
                    color: _kBlanco.withOpacity(0.15),
                    image: _profileImageUrl != null
                        ? DecorationImage(
                            image: NetworkImage('$baseUrl$_profileImageUrl'),
                            fit: BoxFit.cover)
                        : null,
                  ),
                  child: _profileImageUrl == null
                      ? Icon(Icons.person, color: _kBlanco.withOpacity(0.8), size: 22)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(width: 6, height: 6,
                decoration: const BoxDecoration(color: Color(0xFF7ECFFF), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_realAddress,
                  style: TextStyle(color: _kBlanco.withOpacity(0.7), fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── CARDS DE ACCIÓN ───────────────────────────────────────────────
  Widget _buildActionCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        children: [
          Expanded(child: _buildActionCard(
            titulo: 'Servicio ahora', subtitulo: 'Barbero a domicilio',
            icon: _iconServicio(), onTap: _goToServicio)),
          const SizedBox(width: 12),
          Expanded(child: _buildActionCard(
            titulo: 'Reservar cita', subtitulo: 'Elige día y hora',
            icon: _iconCalendario(), onTap: _goToAgenda)),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String titulo, required String subtitulo,
    required Widget icon, required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150,
        decoration: BoxDecoration(color: _kNavy, borderRadius: BorderRadius.circular(22)),
        child: Stack(
          children: [
            Positioned(
              bottom: -20, right: -20,
              child: Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kAzulMedio.withOpacity(0.3)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: _kBlanco.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14)),
                    child: Center(child: icon),
                  ),
                  const Spacer(),
                  Text(titulo,
                    style: const TextStyle(color: _kBlanco, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(subtitulo,
                    style: TextStyle(color: _kBlanco.withOpacity(0.5), fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconServicio() => SizedBox(
    width: 26, height: 26,
    child: CustomPaint(painter: _PinTijerasPainter()));

  Widget _iconCalendario() =>
    const Icon(Icons.calendar_month_rounded, color: _kBlanco, size: 22);

  // ── DOS COLUMNAS ──────────────────────────────────────────────────
  Widget _buildDosColumnas() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildColReservas()),
          const SizedBox(width: 12),
          Expanded(child: _buildColFavoritos()),
        ],
      ),
    );
  }

  Widget _buildColReservas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Mis reservas',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kNavy)),
            GestureDetector(
              onTap: () => setState(() => _selectedIndex = 2),
              child: const Text('Ver más',
                style: TextStyle(fontSize: 11, color: _kAzulMedio, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_isLoadingReservas)
          const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kAzulMedio)),
          ))
        else if (_reservas.isEmpty)
          _buildEmptyCard('Sin reservas\naún')
        else
          ..._reservas.map((r) => _buildMiniReservaCard(r)),
      ],
    );
  }

 Widget _buildMiniReservaCard(dynamic r) {
  final String? foto  = r['barberoFoto'];          // ← corregido
  final String nombre = r['barberoNombre'] ?? 'Barbero';
  final String fecha  = r['fecha']?.toString().split('T')[0] ?? '';
  final String hora   = r['hora'] ?? '';
  final String status = r['status'] ?? 'pendiente';

  Color statusColor;
  String statusLabel;
  switch (status) {
    case 'aceptada':   statusColor = const Color(0xFF1565C0); statusLabel = 'Aceptada';   break;
    case 'reagendada': statusColor = Colors.orange;           statusLabel = 'Reagendada'; break;
    default:           statusColor = const Color(0xFF1565C0); statusLabel = 'Pendiente';
  }

  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _kBlanco, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE0E8FF), width: 0.5)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF4FF),
              borderRadius: BorderRadius.circular(10),
              image: foto != null
                  ? DecorationImage(
                      image: NetworkImage('$baseUrl$foto'),
                      fit: BoxFit.cover)
                  : null),
            child: foto == null
                ? const Icon(Icons.person_rounded, color: _kAzulMedio, size: 18)
                : null),
          const SizedBox(width: 8),
          Expanded(child: Text(nombre,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _kNavy),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 6),
        Text('$fecha · $hora',
          style: const TextStyle(fontSize: 10, color: Color(0xFF8892B0))),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20)),
          child: Text(statusLabel,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor)),
        ),
      ],
    ),
  );
}

  Widget _buildColFavoritos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Favoritos',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kNavy)),
            GestureDetector(
              onTap: _goToAgenda,
              child: const Text('Explorar',
                style: TextStyle(fontSize: 11, color: _kAzulMedio, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_isLoadingFavs)
          const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kAzulMedio)),
          ))
        else if (_favoritos.isEmpty)
          _buildEmptyCard('Agrega\nfavoritos')
        else
          ..._favoritos.take(3).map((b) => _buildMiniFavCard(b)),
      ],
    );
  }

Widget _buildMiniFavCard(dynamic b) {
  final String nombre   = b['nombre'] ?? b['name'] ?? 'Barbero';
  final String barberId = b['_id']?.toString() ?? b['id']?.toString() ?? '';
  final String? foto    = b['profileImage'];

  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _kBlanco, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE0E8FF), width: 0.5)),
    child: Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFEEF4FF),
            image: foto != null
                ? DecorationImage(
                    image: NetworkImage('$baseUrl$foto'),
                    fit: BoxFit.cover)
                : null),
          child: foto == null
              ? const Icon(Icons.person_rounded, color: _kAzulMedio, size: 18)
              : null),
        const SizedBox(width: 8),
        Expanded(child: Text(nombre,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _kNavy),
          maxLines: 1, overflow: TextOverflow.ellipsis)),
        GestureDetector(
          onTap: _goToAgenda,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF4FF),
              borderRadius: BorderRadius.circular(8)),
            child: const Text('Agendar',
              style: TextStyle(fontSize: 10, color: _kAzulMedio, fontWeight: FontWeight.bold)))),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => _removeFavorite(barberId),
          child: const Icon(Icons.favorite, color: Colors.red, size: 16)),
      ],
    ),
  );
}

  Widget _buildEmptyCard(String texto) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kBlanco, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC8D6FF), width: 0.5)),
      child: Text(texto, textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: Color(0xFF8892B0))),
    );
  }

  // ── LIQUID GLASS BAR ──────────────────────────────────────────────
  Widget _buildLiquidBar() {
     if (_selectedIndex == 3) return const SizedBox.shrink(); 
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      height: 80,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: _kBlanco.withOpacity(0.25),
              border: Border.all(color: _kBlanco.withOpacity(0.4), width: 1.5)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTabItem(Icons.home_filled,    'Inicio',    0),
                _buildTabItem(Icons.description,    'Servicios', 1),
                _buildTabItem(Icons.calendar_month, 'Reservas',  2),
                _buildTabItem(Icons.person,         'Perfil',    3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(IconData icon, String label, int index) {
    final selected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22,
              color: selected ? Colors.grey.shade500 : _kAzulMedio),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? Colors.grey.shade500 : _kAzulMedio)),
          ],
        ),
      ),
    );
  }
}

// ── CUSTOM PAINTER ──────────────────────────────────────────────
class _PinTijerasPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke ..strokeCap = StrokeCap.round;
    final paintFill = Paint()
      ..color = Colors.white.withOpacity(0.8) ..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final pinPath = Path();
    pinPath.moveTo(cx, size.height * 0.95);
    pinPath.cubicTo(cx - 2, size.height * 0.7, cx - size.width * 0.45, size.height * 0.55,
        cx - size.width * 0.45, size.height * 0.35);
    pinPath.arcToPoint(Offset(cx + size.width * 0.45, size.height * 0.35),
        radius: Radius.circular(size.width * 0.45), clockwise: false);
    pinPath.cubicTo(cx + size.width * 0.45, size.height * 0.55, cx + 2, size.height * 0.7,
        cx, size.height * 0.95);
    pinPath.close();
    canvas.drawPath(pinPath, paint);
    final ty = size.height * 0.3;
    final tr = size.width * 0.1;
    canvas.drawCircle(Offset(cx - size.width * 0.15, ty), tr, paintFill);
    canvas.drawCircle(Offset(cx + size.width * 0.15, ty), tr, paintFill);
    canvas.drawLine(Offset(cx - size.width * 0.22, ty - tr),
        Offset(cx + size.width * 0.22, ty + tr), paint);
    canvas.drawLine(Offset(cx + size.width * 0.22, ty - tr),
        Offset(cx - size.width * 0.22, ty + tr), paint);
  }
  @override
  bool shouldRepaint(_) => false;
}
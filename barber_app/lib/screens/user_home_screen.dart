import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../main.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _selectedIndex = 0;
  
  final List<Widget> _screens = [
    const HomeServiceTab(),
    const MyServicesTab(),
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppColors.primary.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary.withOpacity(0.5),
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'INICIO',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'MIS SERVICIOS',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'PERFIL',
            ),
          ],
        ),
      ),
    );
  }
}

// =============== HOME / SERVICIOS CON APPLE MAPS ===============
class HomeServiceTab extends StatefulWidget {
  const HomeServiceTab({super.key});

  @override
  State<HomeServiceTab> createState() => _HomeServiceTabState();
}

class _HomeServiceTabState extends State<HomeServiceTab> {
  AppleMapController? _mapController;
  Position? _currentPosition;
  String _selectedServiceType = 'propio';
  String _selectedServiceCategory = 'corte';
  bool _showRouteDetails = false;
  
  // Ubicaciones de ejemplo (CDMX)
  final LatLng _barberLocation = const LatLng(19.4326, -99.1332);
  LatLng? _userLocation;
  
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationDialog('Por favor activa tu ubicación');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationDialog('Necesitamos permisos de ubicación');
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _showLocationDialog('Los permisos de ubicación están denegados permanentemente');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _currentPosition = position;
        _userLocation = LatLng(position.latitude, position.longitude);
      });
      
      if (_mapController != null && _userLocation != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _userLocation!,
              zoom: 15,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error obteniendo ubicación: $e');
      _showLocationDialog('Error al obtener ubicación: $e');
    }
  }

  void _showLocationDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubicación requerida'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // App Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'BarberApp',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1.5,
                    color: AppColors.text,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.notifications_outlined, color: AppColors.text),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          
          // Apple Maps - VERSIÓN CORREGIDA
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _userLocation == null
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Obteniendo ubicación...'),
                          ],
                        ),
                      )
                    : AppleMap(
  initialCameraPosition: CameraPosition(
    target: _userLocation!,
    zoom: 14,
  ),
  onMapCreated: (controller) {
    _mapController = controller;
  },
  myLocationEnabled: true,
  myLocationButtonEnabled: true,
  compassEnabled: true,
),
              ),
            ),
          ),
          
          // Detalles de ruta
          if (_showRouteDetails)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detalles del viaje',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.timer_outlined, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text('15 min', style: TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(width: 16),
                            Icon(Icons.route_outlined, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text('3.5 km', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'EN VIVO',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          
          // Sección de selección de servicio
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    
                    // Tipo de servicio
                    Text(
                      'TIPO DE SERVICIO',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildServiceTypeCard(
                            title: 'Servicio Propio',
                            icon: Icons.person,
                            isSelected: _selectedServiceType == 'propio',
                            onTap: () => setState(() => _selectedServiceType = 'propio'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildServiceTypeCard(
                            title: 'Servicio a segundo',
                            icon: Icons.group,
                            isSelected: _selectedServiceType == 'segundo',
                            onTap: () => setState(() => _selectedServiceType = 'segundo'),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Categorías de servicio
                    Text(
                      'TIPO DE SERVICIO',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildServiceChip('Corte', 'corte'),
                        _buildServiceChip('Barba', 'barba'),
                        _buildServiceChip('Corte + Barba', 'completo'),
                        _buildServiceChip('Tinte', 'tinte'),
                        _buildServiceChip('Tratamiento', 'tratamiento'),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTypeCard({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.primary.withOpacity(0.1),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceChip(String label, String value) {
    bool isSelected = _selectedServiceCategory == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedServiceCategory = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          border: Border.all(
            color: isSelected ? Colors.transparent : AppColors.primary.withOpacity(0.1),
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _showConfirmationDialog(BuildContext context) {
    String serviceTypeText = _selectedServiceType == 'propio' 
        ? 'Servicio Propio' 
        : 'Servicio a segundo';
    
    String categoryText = '';
    switch (_selectedServiceCategory) {
      case 'corte':
        categoryText = 'Corte de cabello';
        break;
      case 'barba':
        categoryText = 'Arreglo de barba';
        break;
      case 'completo':
        categoryText = 'Corte + Barba';
        break;
      default:
        categoryText = _selectedServiceCategory;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar servicio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Tipo:', serviceTypeText),
            const SizedBox(height: 8),
            _buildDetailRow('Servicio:', categoryText),
            const SizedBox(height: 8),
            _buildDetailRow('Precio:', '\$300'),
            const SizedBox(height: 8),
            _buildDetailRow('Distancia:', '3.5 km'),
            const SizedBox(height: 8),
            _buildDetailRow('Tiempo:', '15 min'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCELAR', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Servicio confirmado'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// =============== MIS SERVICIOS ===============
class MyServicesTab extends StatelessWidget {
  const MyServicesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            title: Text(
              'Mis Servicios',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w300,
                letterSpacing: 1.5,
                color: AppColors.text,
              ),
            ),
          ),
          
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),
                
                // Filtros
                Row(
                  children: [
                    _buildFilterChip('Activos', true, context),
                    const SizedBox(width: 8),
                    _buildFilterChip('Historial', false, context),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Lista de servicios
                _buildServiceCard(
                  serviceType: 'Corte',
                  price: '\$250',
                  date: '20 Feb 2026',
                  status: 'completado',
                ),
                
                const SizedBox(height: 16),
                
                _buildServiceCard(
                  serviceType: 'Corte + Barba',
                  price: '\$400',
                  date: '18 Feb 2026',
                  status: 'completado',
                ),
                
                const SizedBox(height: 16),
                
                _buildServiceCard(
                  serviceType: 'Servicio a segundo',
                  price: '\$350',
                  date: '15 Feb 2026',
                  status: 'pendiente',
                ),
                
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(String label, bool isSelected, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: isSelected ? Colors.transparent : AppColors.primary.withOpacity(0.1),
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.textSecondary,
          fontWeight: FontWeight.w400,
          fontSize: 13,
        ),
      ),
    );
  }
  
  Widget _buildServiceCard({
    required String serviceType,
    required String price,
    required String date,
    required String status,
  }) {
    Color statusColor = status == 'completado' ? Colors.green : 
                       status == 'pendiente' ? Colors.orange : Colors.red;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.content_cut, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(serviceType, style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(date, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(price, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }
}

// =============== PERFIL ===============
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            title: Text(
              'Mi Perfil',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w300,
                letterSpacing: 1.5,
                color: AppColors.text,
              ),
            ),
          ),
          
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),
                
                // Avatar
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: const Icon(Icons.person, size: 50, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Text('Usuario Ejemplo', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('usuario@ejemplo.com', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Estadísticas
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      AppColors.primary.withOpacity(0.1),
                      AppColors.secondary.withOpacity(0.1),
                    ]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('15', 'Servicios'),
                      _buildStatItem('12', 'Completados'),
                      _buildStatItem('3', 'Pendientes'),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Opciones
                _buildProfileOption(Icons.person_outline, 'Información personal', () {}),
                _buildProfileOption(Icons.location_on_outlined, 'Mis direcciones', () {}),
                _buildProfileOption(Icons.notifications_outlined, 'Notificaciones', () {}),
                
                const SizedBox(height: 24),
                
                // Cerrar sesión
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _showLogoutDialog(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('CERRAR SESIÓN'),
                  ),
                ),
                
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w300)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
  
  Widget _buildProfileOption(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.text),
      title: Text(title),
      trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
  
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCELAR', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('SALIR', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';

// Modelo de datos del usuario
class UserModel {
  final String id;
  final String name;
  final String? email;
  final String? profileImageUrl;
  final String? phone;
  
  UserModel({
    required this.id,
    required this.name,
    this.email,
    this.profileImageUrl,
    this.phone,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? json['nombre'] ?? 'Usuario',
      email: json['email'],
      profileImageUrl: json['profileImage'] ?? json['fotoPerfil'],
      phone: json['phone'] ?? json['telefono'],
    );
  }
}

// Servicio de base de datos MongoDB
class MongoDBService {
  static final MongoDBService _instance = MongoDBService._internal();
  factory MongoDBService() => _instance;
  MongoDBService._internal();

  final String baseUrl = 'http://192.168.100.4:3000/api';

  Future<UserModel> getCurrentUser(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserModel.fromJson(data);
      } else {
        throw Exception('Error al cargar usuario: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en MongoDBService: $e');
      rethrow;
    }
  }
}

// Clase para manejar la sesión del usuario
class UserSession {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  String? _userId;
  UserModel? _currentUser;

  String? get userId => _userId;
  UserModel? get currentUser => _currentUser;

  void setUser(String userId, UserModel user) {
    _userId = userId;
    _currentUser = user;
  }

  void clear() {
    _userId = null;
    _currentUser = null;
  }
}

class UserHomeScreen extends StatefulWidget {
  final String userId;
  
  const UserHomeScreen({super.key, required this.userId});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  AppleMapController? _mapController;
  LatLng? _userLocation;
  bool _isMapReady = false;
  bool _isLoadingLocation = true;
  
  // Variables para datos del usuario
  String _userName = "User";
  String? _userProfileImageUrl;
  
  // Control para expandir/contraer la card
  bool _isExpanded = false;
  
  // Variables para las opciones de la card
  String _selectedServiceType = 'Servicio propio';
  int _quantity = 1;
  List<bool> _selectedServices = [false, false, false, false];
  List<String> _serviceNames = [
    'Corte de cabello',
    'Arreglo de barba',
    'Corte + Barba',
    'Tinte'
  ];
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
    _getCurrentLocation();
  }

  Future<void> _loadUserData() async {
    try {
      final mongoService = MongoDBService();
      final userData = await mongoService.getCurrentUser(widget.userId);
      
      UserSession().setUser(widget.userId, userData);
      
      if (mounted) {
        setState(() {
          _userName = userData.name;
          _userProfileImageUrl = userData.profileImageUrl;
        });
      }
    } catch (e) {
      print('Error cargando datos de usuario: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });
    
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      print('Error obteniendo ubicación: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _userLocation = const LatLng(20.7219, -103.3911);
        });
      }
    }
  }

  void _centerMapOnUser() {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // MAPA DE FONDO
          if (_userLocation != null)
            AppleMap(
              key: const ValueKey('apple_map'),
              initialCameraPosition: CameraPosition(
                target: _userLocation!,
                zoom: 14,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                setState(() => _isMapReady = true);
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              compassEnabled: true,
            )
          else
            Container(
              color: Colors.grey[300],
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Cargando mapa...'),
                  ],
                ),
              ),
            ),
          
          // CONTENIDO SOBRE EL MAPA
          SafeArea(
            child: Column(
              children: [
                // Header con saludo y avatar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bienvenido',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _userName,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      // Botón de perfil
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/profile');
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.person, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Título
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Selecciona el tipo de servicio',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // CARD QUE SE EXPANDE - CORREGIDA CON ALTURA MÁXIMA
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  constraints: BoxConstraints(
                    maxHeight: _isExpanded ? 500 : 56, // Altura máxima cuando está expandido
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: _isExpanded ? _buildExpandedCard() : _buildCollapsedCard(),
                  ),
                ),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
          
          // Botón para centrar mapa
          if (_isMapReady && _userLocation != null && !_isExpanded)
            Positioned(
              bottom: 140,
              right: 24,
              child: GestureDetector(
                onTap: _centerMapOnUser,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(Icons.my_location, color: Colors.blue),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _getProfileImage() {
    if (_userProfileImageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          _userProfileImageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(Icons.person, color: Colors.blue),
        ),
      );
    }
    return Icon(Icons.person, color: Colors.blue);
  }
  
  // Card colapsada (solo el botón)
  Widget _buildCollapsedCard() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _isExpanded = true;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Text(
          'SOLICITAR SERVICIO',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
  
  // Card expandida con SingleChildScrollView para que sea desplazable
  Widget _buildExpandedCard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Título de la card y botón cerrar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Selecciona el tipo de servicio',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  setState(() {
                    _isExpanded = false;
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Tipo de servicio
          const Text(
            'Tipo de servicio:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildServiceTypeOption(
                  title: 'Servicio propio',
                  isSelected: _selectedServiceType == 'Servicio propio',
                  onTap: () => setState(() => _selectedServiceType = 'Servicio propio'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildServiceTypeOption(
                  title: 'Servicio a segundo',
                  isSelected: _selectedServiceType == 'Servicio a segundo',
                  onTap: () => setState(() => _selectedServiceType = 'Servicio a segundo'),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Servicio a solicitar
          const Text(
            'Servicio a solicitar:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Zapopan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 12),
          
          // Lista de servicios
          ...List.generate(4, (index) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedServices[index] = !_selectedServices[index];
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedServices[index] 
                        ? Colors.blue 
                        : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedServices[index] 
                          ? Icons.check_box 
                          : Icons.check_box_outline_blank,
                      color: _selectedServices[index] ? Colors.blue : Colors.grey,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _serviceNames[index],
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            );
          }),
          
          const SizedBox(height: 20),
          
          // Cantidad de servicios
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Cantidad de servicios:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18),
                      onPressed: () {
                        if (_quantity > 1) {
                          setState(() => _quantity--);
                        }
                      },
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '$_quantity',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: () {
                        setState(() => _quantity++);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Ubicación
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ubicación:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        _isLoadingLocation 
                            ? 'Obteniendo ubicación...' 
                            : 'C. Calle #1, Zapopan, Jalisco',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Botón confirmar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Aquí va la lógica para confirmar el servicio
                setState(() {
                  _isExpanded = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Servicio confirmado'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('CONFIRMAR SERVICIO'),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildServiceTypeOption({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? Colors.blue : Colors.grey.shade600,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
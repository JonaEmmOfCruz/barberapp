import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import '../../config/app_config.dart';
import '../User_Screens/user_home_screen.dart';
import '../Barber_Screens/barber_home_screen.dart';
import '../Barber_Screens/Barber_Profile_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey                = GlobalKey<FormState>();
  final _identifierController   = TextEditingController();
  final _passwordController     = TextEditingController();
  bool _isPasswordVisible       = false;
  bool _isLoading               = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final identifier = _identifierController.text.trim();

    final result = await AuthService.loginUnified(
      identifier: identifier,
      password:   _passwordController.text,
    );

    if (!context.mounted) return;
    Navigator.pop(context); // cierra el loading

    if (result['success']) {
      final String userId   = result['userId'] ?? '';
      final String userName = result['userName'] ?? 'Usuario';
      final bool isBarber   = result['isBarber'] ?? false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', userId);

      if (result['user'] != null && result['user']['profileImage'] != null) {
        await prefs.setString('profileImage', result['user']['profileImage']);
      }

      if (!context.mounted) return;

      if (isBarber) {
        // ── Verificar si el perfil del barbero está completo ──────────
        bool perfilCompleto = false;
        List<String> camposFaltantes = [];

        try {
          final statusRes = await http.get(
            Uri.parse('${AppConfig.baseUrl}/api/upload/barber-profile-status/$userId'),
          );
          if (statusRes.statusCode == 200) {
            final statusData = json.decode(statusRes.body);
            perfilCompleto   = statusData['perfilCompleto'] ?? false;
            camposFaltantes  = List<String>.from(statusData['camposFaltantes'] ?? []);
          }
        } catch (e) {
          debugPrint('Error verificando perfil: $e');
          // Si falla la verificación, dejamos pasar al Home
          perfilCompleto = true;
        }

        if (!context.mounted) return;

        if (perfilCompleto) {
          // Perfil completo → Home
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => BarberHomeScreen(
                barberId:   userId,
                barberName: userName,
              ),
            ),
          );
        } else {
          // Perfil incompleto → Pantalla de perfil con mensaje
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Completa tu perfil para continuar. Faltan: ${_traducirCampos(camposFaltantes)}',
              ),
              backgroundColor: const Color(0xFFE8202A),
              behavior:        SnackBarBehavior.floating,
              duration:        const Duration(seconds: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => BarberProfileScreen(
                barberId:   userId,
                barberName: userName,
                onBack:     () {},
              ),
            ),
          );
        }

      } else {
        // Usuario normal → Home de usuario
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => UserHomeScreen(
              userId:   userId,
              userName: userName,
            ),
          ),
        );
      }

    } else {
      // Login fallido
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:         Text(result['message'] ?? 'Error al iniciar sesión'),
          backgroundColor: Colors.red,
          behavior:        SnackBarBehavior.floating,
          duration:        const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  // Traduce los nombres de campos técnicos a texto legible
  String _traducirCampos(List<String> campos) {
    const Map<String, String> traducciones = {
      'profileImage': 'foto de perfil',
      'vehicleType':  'tipo de vehículo',
      'vehicleBrand': 'marca del vehículo',
      'vehiclePlate': 'placas',
      'licenseImage': 'licencia de conducir',
    };
    return campos
        .map((c) => traducciones[c] ?? c)
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        elevation:       0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.text,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                Text(
                  'Bienvenido',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight:    FontWeight.w300,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Ingresa tu nombre de usuario o correo',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:         AppColors.textSecondary.withOpacity(0.8),
                    fontWeight:    FontWeight.w300,
                  ),
                ),

                const SizedBox(height: 48),

                // ── Campo usuario/email ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'NOMBRE DE USUARIO O CORREO',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight:    FontWeight.w500,
                      letterSpacing: 1.2,
                      color:         AppColors.textSecondary,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.1), width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextFormField(
                    controller:   _identifierController,
                    keyboardType: TextInputType.text,
                    style: TextStyle(
                      color: AppColors.text, fontWeight: FontWeight.w400),
                    decoration: const InputDecoration(
                      hintText: 'Ingresa tu usuario o correo registrado',
                      hintStyle: TextStyle(fontWeight: FontWeight.w300),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                      prefixIcon: Icon(Icons.person_outline, size: 20),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa tu nombre de usuario o correo';
                      }
                      return null;
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // ── Campo contraseña ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'CONTRASEÑA',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight:    FontWeight.w500,
                      letterSpacing: 1.2,
                      color:         AppColors.textSecondary,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.1), width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextFormField(
                    controller:  _passwordController,
                    obscureText: !_isPasswordVisible,
                    style: TextStyle(
                      color: AppColors.text, fontWeight: FontWeight.w400),
                    decoration: InputDecoration(
                      hintText:  '••••••••',
                      hintStyle: const TextStyle(fontWeight: FontWeight.w300),
                      border:    InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                      prefixIcon: const Icon(Icons.lock_outlined, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa tu contraseña';
                      }
                      if (value.length < 6) {
                        return 'La contraseña debe tener al menos 6 caracteres';
                      }
                      return null;
                    },
                  ),
                ),

                const SizedBox(height: 40),

                // ── Botón iniciar sesión ─────────────────────────────
                SizedBox(
                  width:  double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      elevation:       0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                      textStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(
                            fontWeight:    FontWeight.w500,
                            letterSpacing: 1.2,
                          ),
                    ),
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white),
                            ),
                          )
                        : const Text('INICIAR SESIÓN'),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
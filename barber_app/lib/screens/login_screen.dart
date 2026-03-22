import 'package:flutter/material.dart';
import '../main.dart';
import '../services/auth_service.dart';
import 'user_home_screen.dart';
import 'barber_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isBarber = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Validar formulario
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    // Mostrar diálogo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    // Llamar al servicio de login
    final result = await AuthService.loginUser(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      isBarber: _isBarber,
    );
    
    if (context.mounted) {
      Navigator.pop(context); // Cerrar diálogo de carga
      
      if (result['success']) {
        // Obtener el userId del resultado
        String userId = result['userId'] ?? '';
        
        print('Login exitoso - UserId: $userId, isBarber: $_isBarber');
        
        // Navegar a la pantalla correspondiente según el tipo de usuario
        if (_isBarber) {
          // Redirigir a pantalla de barbero
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => BarberHomeScreen(barberId: userId),
            ),
          );
        } else {
          // Redirigir a pantalla de usuario normal
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => UserHomeScreen(userId: userId),
            ),
          );
        }
      } else {
        // Mostrar mensaje de error
        String errorMessage = result['message'] ?? 'Error al iniciar sesión';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
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
                
                // Título
                Text(
                  'Bienvenido',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1.5,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Subtítulo
                Text(
                  'Ingresa tus credenciales para continuar',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary.withOpacity(0.8),
                    fontWeight: FontWeight.w300,
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Selector de tipo (Usuario / Barbero)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.1),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isBarber = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: !_isBarber 
                                ? AppColors.primary.withOpacity(0.1) 
                                : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'USUARIO',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: !_isBarber 
                                  ? AppColors.primary 
                                  : AppColors.textSecondary.withOpacity(0.5),
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.2,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isBarber = true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: _isBarber 
                                ? AppColors.secondary.withOpacity(0.1) 
                                : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'BARBERO',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _isBarber 
                                  ? AppColors.secondary 
                                  : AppColors.textSecondary.withOpacity(0.5),
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.2,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Campo de Email
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'CORREO ELECTRÓNICO',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.1),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'ejemplo@correo.com',
                      hintStyle: TextStyle(fontWeight: FontWeight.w300),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      prefixIcon: Icon(Icons.email_outlined, size: 20),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa tu correo';
                      }
                      // Validar formato de email
                      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                      if (!emailRegex.hasMatch(value)) {
                        return 'Ingresa un correo válido';
                      }
                      return null;
                    },
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Campo de Contraseña
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'CONTRASEÑA',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.1),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      hintStyle: const TextStyle(fontWeight: FontWeight.w300),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      prefixIcon: const Icon(Icons.lock_outlined, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible 
                            ? Icons.visibility_off_outlined 
                            : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
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
                
                // Botón de inicio de sesión
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isBarber 
                        ? AppColors.secondary 
                        : AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                      ),
                    ),
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
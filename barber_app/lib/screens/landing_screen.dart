import 'package:flutter/material.dart';
import '../main.dart';
import 'login_screen.dart';
import 'register_choice_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),
              
              // Logo Minimalista
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(
                    color: Colors.transparent,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(23),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
        
              const SizedBox(height: 40),
              
              // Título
              Text(
                'BarberApp',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1.5,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Línea decorativa
              Container(
                width: 60,
                height: 1,
                color: AppColors.secondary.withOpacity(0.3),
              ),
              
              const SizedBox(height: 24),
              
              // Subtítulo
              Text(
                'Barbería a domicilio',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.2,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Tu corte perfecto, donde tú elijas',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary.withOpacity(0.8),
                  fontWeight: FontWeight.w300,
                ),
                textAlign: TextAlign.center,
              ),
              
              const Spacer(flex: 4),
              
              // Características con diseño limpio
              _buildFeatureRow(
                context,
                Icons.pin_drop_outlined,
                'Servicio en tu ubicación',
              ),
              const SizedBox(height: 20),
              _buildFeatureRow(
                context,
                Icons.verified_outlined,
                'Barberos profesionales',
              ),
              
              const Spacer(flex: 3),
              
              // Botones premium
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
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
                  child: const Text('INICIAR SESIÓN'),
                ),
              ),
              
              const SizedBox(height: 16),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterChoiceScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppColors.secondary.withOpacity(0.3),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                  ),
                  child: Text(
                    'CREAR CUENTA',
                    style: TextStyle(
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ),
              
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(BuildContext context, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.1),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.secondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
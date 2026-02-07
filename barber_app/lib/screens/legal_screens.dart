import 'package:flutter/material.dart';
import '../main.dart';

class LegalScreen extends StatelessWidget {
  final String type; // 'terms' o 'privacy'
  final bool isForBarber;

  const LegalScreen({
    super.key,
    required this.type,
    required this.isForBarber,
  });

  @override
  Widget build(BuildContext context) {
    final title = type == 'terms' 
      ? 'Términos y Condiciones' 
      : 'Política de Privacidad';
    
    final content = type == 'terms'
      ? _buildTermsContent()
      : _buildPrivacyContent();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w300,
            letterSpacing: 1.2,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
      ),
      body: SafeArea(
        child: Container(
          color: Colors.white,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildTermsContent() {
    final userType = isForBarber ? 'Barbero' : 'Usuario';
    final serviceType = isForBarber ? 'ofrecer servicios' : 'solicitar servicios';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Términos y Condiciones de Uso',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w300,
            color: AppColors.primary,
            height: 1.3,
          ),
        ),
        
        const SizedBox(height: 24),
        
        Text(
          'Última actualización: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
          style: TextStyle(
            color: AppColors.textSecondary.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w300,
          ),
        ),
        
        const SizedBox(height: 32),
        
        // 1. Aceptación
        _buildSection(
          title: '1. Aceptación de los Términos',
          content: 'Al crear una cuenta como $userType en BarberApp, aceptas estos términos y condiciones en su totalidad.',
        ),
        
        // 2. Descripción del servicio
        _buildSection(
          title: '2. Descripción del Servicio',
          content: 'BarberApp es una plataforma que conecta clientes con barberos profesionales para servicios a domicilio. Como $userType, puedes $serviceType de barbería en la ubicación que elijas.',
        ),
        
        // 3. Responsabilidades
        _buildSection(
          title: '3. Responsabilidades del $userType',
          content: isForBarber
            ? '''
• Debes contar con las herramientas y equipo necesarios para realizar los servicios.
• Eres responsable de llegar puntualmente a las citas.
• Debes mantener un comportamiento profesional en todo momento.
• Eres responsable de tu transporte y costos asociados.
'''
            : '''
• Debes proporcionar una dirección precisa para el servicio.
• Debes estar presente en la ubicación acordada.
• Debes respetar el tiempo y profesionalismo del barbero.
• Debes proporcionar un espacio adecuado para el servicio.
''',
        ),
        
        // 4. Pagos
        _buildSection(
          title: '4. Sistema de Pagos',
          content: 'Todos los pagos se realizan a través de la plataforma. BarberApp retiene una comisión por cada transacción exitosa.',
        ),
        
        // 5. Cancelaciones
        _buildSection(
          title: '5. Política de Cancelaciones',
          content: isForBarber
            ? 'Debes notificar con al menos 2 horas de anticipación. Cancelaciones frecuentes pueden resultar en suspensión de tu cuenta.'
            : 'Puedes cancelar con hasta 1 hora de anticipación sin cargo. Cancelaciones tardías pueden incurrir en cargos.',
        ),
        
        // 6. Calificaciones
        _buildSection(
          title: '6. Sistema de Calificaciones',
          content: 'Ambas partes pueden calificarse mutuamente después de cada servicio. Las calificaciones son públicas y afectan tu reputación en la plataforma.',
        ),
        
        // 7. Responsabilidad
        _buildSection(
          title: '7. Limitación de Responsabilidad',
          content: 'BarberApp actúa como intermediario. No nos hacemos responsables por daños durante el servicio, salvo los causados por fallas de la plataforma.',
        ),
        
        // 8. Modificaciones
        _buildSection(
          title: '8. Modificaciones de los Términos',
          content: 'Nos reservamos el derecho de modificar estos términos. Notificaremos cambios importantes a través de la aplicación o correo electrónico.',
        ),
        
        const SizedBox(height: 40),
        
        // Contacto
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contacto',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Para preguntas sobre estos términos:\n\n'
                'Email: legal@barberapp.com\n'
                'Teléfono: +52 800 123 4567\n'
                'Horario: Lunes a Viernes, 9:00 - 18:00',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildPrivacyContent() {
    final userType = isForBarber ? 'Barbero' : 'Usuario';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Política de Privacidad',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w300,
            color: AppColors.primary,
            height: 1.3,
          ),
        ),
        
        const SizedBox(height: 24),
        
        Text(
          'Última actualización: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
          style: TextStyle(
            color: AppColors.textSecondary.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w300,
          ),
        ),
        
        const SizedBox(height: 32),
        
        // 1. Información que recopilamos
        _buildSection(
          title: '1. Información que Recopilamos',
          content: '''
• Datos personales (nombre, email, teléfono)
• Información de ubicación para servicios
• Fotos de perfil (opcional)
• Métodos de pago
• Historial de servicios
• Comentarios y calificaciones
''',
        ),
        
        // 2. Uso de la información
        _buildSection(
          title: '2. Cómo Usamos tu Información',
          content: '''
• Para proporcionar y mejorar nuestros servicios
• Para procesar pagos de manera segura
• Para conectar clientes y barberos
• Para enviar notificaciones importantes
• Para análisis y mejoras de la plataforma
''',
        ),
        
        // 3. Compartir información
        _buildSection(
          title: '3. Compartir Información',
          content: isForBarber
            ? 'Compartimos tu nombre, foto y calificaciones con clientes potenciales. No compartimos datos de contacto directamente.'
            : 'Compartimos tu nombre y ubicación con el barbero asignado. Tu información de contacto no se comparte directamente.',
        ),
        
        // 4. Seguridad
        _buildSection(
          title: '4. Seguridad de Datos',
          content: 'Implementamos medidas de seguridad estándar de la industria para proteger tu información. Los pagos se procesan a través de gateways certificados.',
        ),
        
        // 5. Retención de datos
        _buildSection(
          title: '5. Retención de Datos',
          content: 'Mantenemos tu información mientras tu cuenta esté activa. Puedes solicitar la eliminación de tu cuenta en cualquier momento.',
        ),
        
        // 6. Tus derechos
        _buildSection(
          title: '6. Tus Derechos',
          content: '''
• Acceder a tu información personal
• Corregir datos inexactos
• Solicitar eliminación de datos
• Oponerte al procesamiento
• Portabilidad de datos
''',
        ),
        
        // 7. Cookies
        _buildSection(
          title: '7. Uso de Cookies',
          content: 'Utilizamos cookies para mejorar la experiencia en nuestra aplicación. Puedes gestionar las preferencias de cookies en la configuración de tu dispositivo.',
        ),
        
        // 8. Cambios
        _buildSection(
          title: '8. Cambios en la Política',
          content: 'Notificaremos cambios importantes en esta política. El uso continuado de la aplicación constituye aceptación de los cambios.',
        ),
        
        const SizedBox(height: 40),
        
        // Derechos del usuario
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ejercer tus Derechos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Para ejercer cualquier derecho de protección de datos:\n\n'
                'Email: privacy@barberapp.com\n'
                'Dirección: Av. Reforma 123, CDMX\n'
                'Tiempo de respuesta: 30 días hábiles',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w300,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
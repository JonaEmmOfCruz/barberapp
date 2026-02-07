import 'package:flutter/material.dart';
import '../main.dart';
import 'legal_screens.dart';

class BarberRegisterScreen extends StatefulWidget {
  const BarberRegisterScreen({super.key});

  @override
  State<BarberRegisterScreen> createState() => _BarberRegisterScreenState();
}

class _BarberRegisterScreenState extends State<BarberRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _experienceController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _licensePlateController = TextEditingController();
  
  bool _isPasswordVisible = false;
  bool _acceptTerms = false;
  String _selectedVehicleType = 'Motocicleta';
  
  final List<String> _vehicleTypes = ['Motocicleta', 'Automóvil'];
  final List<String> _selectedServices = [];
  final List<String> _availableServices = [
    'Corte',
    'Diseño',
    'Barba',
    'Afeitado',
    'Cejas',
    'Tinte',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _experienceController.dispose();
    _vehicleController.dispose();
    _licensePlateController.dispose();
    super.dispose();
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
        title: Text(
          'Registro de Barbero',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w300,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.secondary,
            secondary: AppColors.secondary.withOpacity(0.1),
          ),
        ),
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 2) {
              setState(() => _currentStep++);
            } else {
              _submitForm();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            }
          },
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Row(
                children: [
                  if (_currentStep > 0) ...[
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.secondary,
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
                              fontSize: 11,
                            ),
                          ),
                          onPressed: details.onStepCancel,
                          child: const Text('ATRÁS'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
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
                            fontSize: 11,
                          ),
                        ),
                        onPressed: details.onStepContinue,
                        child: Text(_currentStep == 2 ? 'ENVIAR SOLICITUD' : 'CONTINUAR'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          steps: [
            _buildStep(
              title: 'Datos Personales',
              content: _buildPersonalInfoStep(),
            ),
            _buildStep(
              title: 'Experiencia',
              content: _buildExperienceStep(),
            ),
            _buildStep(
              title: 'Vehículo',
              content: _buildVehicleStep(),
            ),
          ],
        ),
      ),
    );
  }

  Step _buildStep({required String title, required Widget content}) {
    return Step(
      state: _currentStep > _availableServices.indexOf(title) 
        ? StepState.complete 
        : StepState.indexed,
      isActive: _currentStep >= _availableServices.indexOf(title),
      title: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.2,
          color: _currentStep >= _availableServices.indexOf(title)
            ? AppColors.secondary
            : AppColors.textSecondary.withOpacity(0.5),
        ),
      ),
      content: content,
    );
  }

  Widget _buildPersonalInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.secondary.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.content_cut,
              size: 48,
              color: AppColors.secondary.withOpacity(0.5),
            ),
          ),
        ),
        
        const SizedBox(height: 40),
        
        _buildLabel('NOMBRE COMPLETO'),
        _buildTextField(
          controller: _nameController,
          hintText: 'Juan Pérez',
          icon: Icons.person_outlined,
        ),
        
        const SizedBox(height: 24),
        
        _buildLabel('CORREO ELECTRÓNICO'),
        _buildTextField(
          controller: _emailController,
          hintText: 'ejemplo@correo.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        
        const SizedBox(height: 24),
        
        _buildLabel('TELÉFONO'),
        _buildTextField(
          controller: _phoneController,
          hintText: '+52 55 1234 5678',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        
        const SizedBox(height: 24),
        
        _buildLabel('CONTRASEÑA'),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.secondary.withOpacity(0.1),
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
          ),
        ),
      ],
    );
  }

  Widget _buildExperienceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('AÑOS DE EXPERIENCIA'),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.secondary.withOpacity(0.1),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: _experienceController,
            keyboardType: TextInputType.number,
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w400,
            ),
            decoration: const InputDecoration(
              hintText: '5',
              hintStyle: TextStyle(fontWeight: FontWeight.w300),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              prefixIcon: Icon(Icons.work_outline, size: 20),
              suffixText: 'años',
              suffixStyle: TextStyle(
                fontWeight: FontWeight.w300,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 32),
        
        _buildLabel('SERVICIOS QUE OFRECES'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _availableServices.map((service) {
            final isSelected = _selectedServices.contains(service);
            return ChoiceChip(
              label: Text(
                service.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1,
                  color: isSelected ? AppColors.secondary : AppColors.textSecondary.withOpacity(0.7),
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedServices.add(service);
                  } else {
                    _selectedServices.remove(service);
                  }
                });
              },
              backgroundColor: Colors.transparent,
              selectedColor: AppColors.secondary.withOpacity(0.1),
              side: BorderSide(
                color: isSelected 
                  ? AppColors.secondary 
                  : AppColors.secondary.withOpacity(0.1),
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }).toList(),
        ),
        
        const SizedBox(height: 32),
        
        _buildLabel('CERTIFICACIONES'),
        GestureDetector(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.secondary.withOpacity(0.1),
                width: 1,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.upload_outlined,
                  size: 32,
                  color: AppColors.secondary.withOpacity(0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'Subir certificados',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'PDF, JPG o PNG (máx. 5MB)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w300,
                    color: AppColors.textSecondary.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('TIPO DE VEHÍCULO'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _vehicleTypes.map((type) {
            final isSelected = _selectedVehicleType == type;
            return ChoiceChip(
              label: Text(
                type.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1,
                  color: isSelected ? AppColors.secondary : AppColors.textSecondary.withOpacity(0.7),
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedVehicleType = type;
                });
              },
              backgroundColor: Colors.transparent,
              selectedColor: AppColors.secondary.withOpacity(0.1),
              side: BorderSide(
                color: isSelected 
                  ? AppColors.secondary 
                  : AppColors.secondary.withOpacity(0.1),
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }).toList(),
        ),
        
        const SizedBox(height: 32),
        
        if (_selectedVehicleType != 'A pie') ...[
          _buildLabel('MARCA Y MODELO'),
          _buildTextField(
            controller: _vehicleController,
            hintText: 'Honda CRF 250',
            icon: Icons.directions_car_outlined,
          ),
          
          const SizedBox(height: 24),
          
          _buildLabel('PLACA'),
          _buildTextField(
            controller: _licensePlateController,
            hintText: 'ABC-123',
            icon: Icons.confirmation_number_outlined,
          ),
          
          const SizedBox(height: 32),
        ],
        
        _buildLabel('DOCUMENTACIÓN'),
        const SizedBox(height: 12),
        
        _buildDocumentUploader('INE / Pasaporte'),
        
        const SizedBox(height: 16),
        
        _buildDocumentUploader('Comprobante de domicilio'),
        
        const SizedBox(height: 32),
        
        // Términos y condiciones
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(
              color: AppColors.secondary.withOpacity(0.1),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _acceptTerms,
                onChanged: (value) {
                  setState(() {
                    _acceptTerms = value ?? false;
                  });
                },
                activeColor: AppColors.secondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'Acepto los ',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w300,
                      color: AppColors.textSecondary,
                    ),
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LegalScreen(
                                    type: 'terms',
                                    isForBarber: true,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                'Términos y Condiciones',
                                style: TextStyle(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.8,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.secondary.withOpacity(0.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(text: ' y la '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LegalScreen(
                                    type: 'privacy',
                                    isForBarber: true,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                'Política de Privacidad',
                                style: TextStyle(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.8,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.secondary.withOpacity(0.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentUploader(String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.attach_file_outlined,
            size: 20,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              hint,
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.8),
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              foregroundColor: AppColors.secondary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              'SUBIR',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: 1.2,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.1),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(fontWeight: FontWeight.w300),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          prefixIcon: Icon(icon, size: 20),
        ),
      ),
    );
  }

  void _submitForm() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  size: 48,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '¡Solicitud Enviada!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tu solicitud está siendo revisada. Te notificaremos cuando sea aprobada.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary.withOpacity(0.8),
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
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
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  child: const Text('ENTENDIDO'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
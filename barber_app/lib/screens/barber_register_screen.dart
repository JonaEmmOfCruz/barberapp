import 'package:flutter/material.dart';
import '../main.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class BarberRegisterScreen extends StatefulWidget {
  const BarberRegisterScreen({super.key});

  @override
  State<BarberRegisterScreen> createState() => _BarberRegisterScreenState();
}

class _BarberRegisterScreenState extends State<BarberRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  
  // Controllers
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
  // Variable para almacenar la imagen seleccionada
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  // Método para seleccionar imagen desde la galería
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      print("Error al seleccionar imagen: $e");
      // Puedes mostrar un snackbar o diálogo de error aquí
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar imagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Registro de Barbero'),
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.secondary,
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
              padding: const EdgeInsets.only(top: 20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                      ),
                      onPressed: details.onStepContinue,
                      child: Text(_currentStep == 2 ? 'Enviar Solicitud' : 'Continuar'),
                    ),
                  ),
                  if (_currentStep > 0) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.secondary,
                          side: const BorderSide(color: AppColors.secondary),
                        ),
                        onPressed: details.onStepCancel,
                        child: const Text('Atrás'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
          steps: [
            // Paso 1: Información personal
            Step(
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              isActive: _currentStep >= 0,
              title: const Text('Datos Personales'),
              content: _buildPersonalInfoStep(),
            ),
            // Paso 2: Experiencia y servicios
            Step(
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              isActive: _currentStep >= 1,
              title: const Text('Experiencia'),
              content: _buildExperienceStep(),
            ),
            // Paso 3: Vehículo y documentos
            Step(
              state: _currentStep > 2 ? StepState.complete : StepState.indexed,
              isActive: _currentStep >= 2,
              title: const Text('Vehículo'),
              content: _buildVehicleStep(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        // Contenedor del avatar con imagen o icono por defecto
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: _selectedImage != null
                              ? ClipOval(
                                  child: Image.file(
                                    _selectedImage!,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Icon(
                                  Icons.content_cut,
                                  size: 50,
                                  color: AppColors.secondary,
                                ),
                        ),
                        // Ícono de cámara (ahora es parte del GestureDetector)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Texto indicativo opcional
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Toca para agregar foto',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
        
        const SizedBox(height: 24),
        
        _buildLabel('Nombre completo'),
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            hintText: 'Juan Pérez',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        
        const SizedBox(height: 16),
        
        _buildLabel('Correo electrónico'),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'ejemplo@correo.com',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        
        const SizedBox(height: 16),
        
        _buildLabel('Teléfono'),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: '+52 55 1234 5678',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        
        const SizedBox(height: 16),
        
        _buildLabel('Contraseña'),
        TextFormField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outlined),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible 
                  ? Icons.visibility_off_outlined 
                  : Icons.visibility_outlined,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
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
        _buildLabel('Años de experiencia'),
        TextFormField(
          controller: _experienceController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '5',
            prefixIcon: Icon(Icons.work_outline),
            suffixText: 'años',
          ),
        ),
        
        const SizedBox(height: 24),
        
        _buildLabel('Servicios que ofreces'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableServices.map((service) {
            final isSelected = _selectedServices.contains(service);
            return FilterChip(
              label: Text(service),
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
              selectedColor: AppColors.secondary.withOpacity(0.2),
              checkmarkColor: AppColors.secondary,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.secondary : AppColors.text,
              ),
            );
          }).toList(),
        ),
        
        const SizedBox(height: 24),
        
        _buildLabel('Certificaciones'),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4F8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.secondary.withOpacity(0.3),
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.upload_file,
                size: 40,
                color: AppColors.secondary,
              ),
              const SizedBox(height: 8),
              Text(
                'Subir certificados',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'PDF, JPG o PNG (máx. 5MB)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Tipo de vehículo'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _vehicleTypes.map((type) {
            final isSelected = _selectedVehicleType == type;
            return ChoiceChip(
              label: Text(type),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedVehicleType = type;
                });
              },
              selectedColor: AppColors.secondary.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.secondary : AppColors.text,
              ),
            );
          }).toList(),
        ),
        
        const SizedBox(height: 24),
        
        if (_selectedVehicleType != 'A pie') ...[
          _buildLabel('Marca y modelo'),
          TextFormField(
            controller: _vehicleController,
            decoration: const InputDecoration(
              hintText: 'Honda CRF 250',
              prefixIcon: Icon(Icons.directions_car_outlined),
            ),
          ),
          
          const SizedBox(height: 16),
          
          _buildLabel('Placa'),
          TextFormField(
            controller: _licensePlateController,
            decoration: const InputDecoration(
              hintText: 'ABC-123',
              prefixIcon: Icon(Icons.confirmation_number_outlined),
            ),
          ),
          
          const SizedBox(height: 24),
        ],
        
        _buildLabel('Identificación oficial'),
        _buildDocumentUploader('INE / Pasaporte'),
        
        const SizedBox(height: 16),
        
        _buildLabel('Comprobante de domicilio'),
        _buildDocumentUploader('Recibo de luz o agua'),
        
        const SizedBox(height: 24),
        
        // Términos
        Row(
          children: [
            Checkbox(
              value: _acceptTerms,
              onChanged: (value) {
                setState(() {
                  _acceptTerms = value ?? false;
                });
              },
              activeColor: AppColors.secondary,
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'Acepto los ',
                  style: Theme.of(context).textTheme.bodyMedium,
                  children: [
                    TextSpan(
                      text: 'Términos y Condiciones',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDocumentUploader(String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.attach_file, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hint,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {},
            child: Text(
              'Subir',
              style: TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
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
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }

  void _submitForm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 60,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '¡Solicitud Enviada!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Tu solicitud está siendo revisada. Te notificaremos cuando sea aprobada.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                ),
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text('Entendido'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

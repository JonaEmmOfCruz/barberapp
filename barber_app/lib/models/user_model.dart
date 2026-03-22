class UserModel {
  final String id;
  final String nombre;
  final String? profileImage;

  UserModel({required this.id, required this.nombre, this.profileImage});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? '',
      nombre: json['nombre'] ?? 'Usuario',
      profileImage: json['profileImage'],
    );
  }
}
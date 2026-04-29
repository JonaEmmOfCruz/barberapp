class CartItem {
  final String id;
  final String name;
  final double price;
  int quantity;
  String status;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.status = "Pedido",
  });
}

List<CartItem> globalCart = [];

// Función para obtener el conteo total de productos (cantidades sumadas)
int get cartCount => globalCart.fold(0, (sum, item) => sum + item.quantity);

// Función para obtener el precio total
double get cartTotal => globalCart.fold(0, (sum, item) => sum + (item.price * item.quantity));
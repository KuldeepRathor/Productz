
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';

class ApiService {
  final String _apiUrl = "https://fakestoreapi.com/products";//TODO:later add in app_url.dart file
  final bool simulateError;
  final Duration simulatedLatency;

  ApiService({
    this.simulateError = false,
    this.simulatedLatency = const Duration(seconds: 2),
  });

  Future<List<Product>> fetchProducts() async {
    await Future.delayed(simulatedLatency);

    if (simulateError) {
      throw Exception('Simulated network error');
    }

    final response = await http.get(Uri.parse(_apiUrl));

    if (response.statusCode == 200) {
      final List<dynamic> productJson = json.decode(response.body);
      return productJson.map((json) => Product.fromJson(json)).toList();
    } else {
      throw Exception(
        'Failed to load products from API (status ${response.statusCode})',
      );
    }
  }
}

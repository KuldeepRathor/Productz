

import 'dart:developer';

import '../models/product.dart';

class CacheService {
  // In-memory storage (non-persistent)
  List<Product> _cachedProducts = [];
  DateTime? _lastFetchTime;

  // Read all products from memory
  List<Product> get products => List.unmodifiable(_cachedProducts);

  // Read the last fetch time
  DateTime? get lastFetchTime => _lastFetchTime;

  // Check if cache has any data
  bool get hasData => _cachedProducts.isNotEmpty;

  // Staleness logic - cache is stale if 5 minutes or more have passed
  bool get isCacheStale {
    if (_lastFetchTime == null) {
      return true;
    }
    final difference = DateTime.now().difference(_lastFetchTime!);
    // Used this to ensure refresh happens at exactly 5 minutes
    return difference.inMinutes >= 5 || difference.inSeconds >= 300;
  }

  // Get exact seconds until cache becomes stale
  int get secondsUntilStale {
    if (_lastFetchTime == null) return 0;
    final elapsed = DateTime.now().difference(_lastFetchTime!).inSeconds;
    final remaining = 300 - elapsed; 
    return remaining > 0 ? remaining : 0;
  }

  // Update the cache with new products
  Future<void> setProducts(List<Product> products) async {
    _cachedProducts = List.from(products);
    _lastFetchTime = DateTime.now();
    log('Cache updated at $_lastFetchTime');
  }

  void clearCache() {
    _cachedProducts = [];
    _lastFetchTime = null;
  }
}

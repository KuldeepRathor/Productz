// lib/repository/product_repository.dart
import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:productz/models/product.dart';
import 'package:productz/services/api_services.dart';
import 'package:productz/services/cache_services.dart';

enum DataSource { cache, network }

class ProductLoadState {
  final List<Product> products;
  final DataSource? dataSource;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final DateTime? lastFetchTime;
  final bool isOffline;

  ProductLoadState({
    required this.products,
    this.dataSource,
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.lastFetchTime,
    this.isOffline = false,
  });

  bool get hasData => products.isNotEmpty;
  bool get isStale =>
      lastFetchTime != null &&
      DateTime.now().difference(lastFetchTime!).inMinutes >= 5;

  ProductLoadState copyWith({
    List<Product>? products,
    DataSource? dataSource,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    DateTime? lastFetchTime,
    bool? isOffline,
  }) {
    return ProductLoadState(
      products: products ?? this.products,
      dataSource: dataSource ?? this.dataSource,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error ?? this.error,
      lastFetchTime: lastFetchTime ?? this.lastFetchTime,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

class ProductRepository {
  final ApiService _apiService;
  final CacheService _cacheService;
  final StreamController<ProductLoadState> _controller =
      StreamController<ProductLoadState>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _staleCheckTimer;
  Timer? _preciseRefreshTimer;
  bool _isOnline = true;
  ProductLoadState? _currentState;

  ProductRepository(this._apiService, this._cacheService) {
    _initConnectivity();
    _initStaleChecker();
  }

  void _initConnectivity() {
    // Listen to connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) {
      final wasOffline = !_isOnline;
      _isOnline =
          result.contains(ConnectivityResult.mobile) ||
          result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.ethernet);

      log('Connectivity changed: Online = $_isOnline');

      // If we just came back online and have stale data, refresh
      if (wasOffline && _isOnline && _cacheService.isCacheStale) {
        log('Back online with stale data - refreshing...');
        refresh();
      }
    });
  }

  void _initStaleChecker() {
    _staleCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkAndScheduleRefresh();
    });
  }

  void _checkAndScheduleRefresh() {
    if (_currentState == null ||
        !_currentState!.hasData ||
        _currentState!.isRefreshing ||
        _currentState!.isLoading ||
        !_isOnline ||
        _currentState!.lastFetchTime == null) {
      return;
    }

    final now = DateTime.now();
    final timeSinceLastFetch = now.difference(_currentState!.lastFetchTime!);
    final timeUntilStale = const Duration(minutes: 5) - timeSinceLastFetch;

    // Cancel any existing precise timer
    _preciseRefreshTimer?.cancel();

    if (timeUntilStale.isNegative || timeUntilStale == Duration.zero) {
      // Already stale, refresh immediately
      log('Cache is stale (>=5 minutes old) - triggering auto-refresh');
      refresh();
    } else if (timeUntilStale.inSeconds <= 60) {
      // Less than 60 seconds until stale - schedule precise refresh
      log(
        'Scheduling precise refresh in ${timeUntilStale.inSeconds} seconds',
      );
      _preciseRefreshTimer = Timer(timeUntilStale, () {
        if (_isOnline &&
            !(_currentState?.isRefreshing ?? false) &&
            !(_currentState?.isLoading ?? false)) {
          log('Precise timer triggered - refreshing at exactly 5 minutes');
          refresh();
        }
      });
    }
  }

  Stream<ProductLoadState> getProductsWithState() {
    _loadProducts();
    return _controller.stream;
  }

  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<void> _loadProducts() async {
    // 1. Always yield cached data first if available
    if (_cacheService.hasData) {
      _currentState = ProductLoadState(
        products: _cacheService.products,
        dataSource: DataSource.cache,
        lastFetchTime: _cacheService.lastFetchTime,
        isRefreshing: true,
        isOffline: !_isOnline,
      );
      _controller.add(_currentState!);
    } else {
      // No cache, show loading state
      _currentState = ProductLoadState(
        products: [],
        isLoading: true,
        isOffline: !_isOnline,
      );
      _controller.add(_currentState!);
    }

    // 2. Check connectivity before attempting network fetch
    final isConnected = await _checkConnectivity();

    if (!isConnected) {
      log('No internet connection - using cache only');
      _currentState = ProductLoadState(
        products: _cacheService.products,
        dataSource: DataSource.cache,
        lastFetchTime: _cacheService.lastFetchTime,
        isOffline: true,
        error: _cacheService.hasData ? null : 'No internet connection',
      );
      _controller.add(_currentState!);
      return;
    }

    // 3. If online, check if cache is stale and fetch from network if needed
    if (!_cacheService.hasData || _cacheService.isCacheStale) {
      try {
        log('Fetching fresh data from network...');
        final freshProducts = await _apiService.fetchProducts();
        await _cacheService.setProducts(freshProducts);

        _currentState = ProductLoadState(
          products: freshProducts,
          dataSource: DataSource.network,
          lastFetchTime: DateTime.now(),
          isOffline: false,
        );
        _controller.add(_currentState!);

        // Schedule next refresh check
        _checkAndScheduleRefresh();
      } catch (e) {
        log('Network fetch failed: $e');
        // Network error - use cache if available
        if (_cacheService.hasData) {
          _currentState = ProductLoadState(
            products: _cacheService.products,
            dataSource: DataSource.cache,
            error: 'Network error: Using cached data',
            lastFetchTime: _cacheService.lastFetchTime,
            isOffline: false,
          );
          _controller.add(_currentState!);
        } else {
          // No cache and network failed
          _currentState = ProductLoadState(
            products: [],
            error: 'Failed to load products: ${e.toString()}',
            isOffline: false,
          );
          _controller.add(_currentState!);
        }
      }
    } else {
      // Cache is fresh, just update to remove refreshing state
      _currentState = ProductLoadState(
        products: _cacheService.products,
        dataSource: DataSource.cache,
        lastFetchTime: _cacheService.lastFetchTime,
        isOffline: false,
      );
      _controller.add(_currentState!);
    }
  }

  Future<void> refresh() async {
    log('Refresh requested at ${DateTime.now()}');

    // Prevent multiple simultaneous refreshes
    if (_currentState != null &&
        (_currentState!.isRefreshing || _currentState!.isLoading)) {
      log('Already refreshing - skipping duplicate request');
      return;
    }

    // Check connectivity first
    final isConnected = await _checkConnectivity();

    if (!isConnected) {
      log('Cannot refresh - no internet connection');
      _currentState = ProductLoadState(
        products: _cacheService.products,
        dataSource: DataSource.cache,
        error: 'Cannot refresh: No internet connection',
        lastFetchTime: _cacheService.lastFetchTime,
        isOffline: true,
      );
      _controller.add(_currentState!);
      return;
    }

    // Show refreshing state with current cache
    if (_cacheService.hasData) {
      _currentState = ProductLoadState(
        products: _cacheService.products,
        dataSource: DataSource.cache,
        isRefreshing: true,
        lastFetchTime: _cacheService.lastFetchTime,
        isOffline: false,
      );
      _controller.add(_currentState!);
    }

    try {
      final freshProducts = await _apiService.fetchProducts();
      await _cacheService.setProducts(freshProducts);

      _currentState = ProductLoadState(
        products: freshProducts,
        dataSource: DataSource.network,
        lastFetchTime: DateTime.now(),
        isOffline: false,
      );
      _controller.add(_currentState!);

      log('Refresh successful - data updated at ${DateTime.now()}');

      // Schedule next refresh check
      _checkAndScheduleRefresh();
    } catch (e) {
      log('Refresh failed: $e');
      _currentState = ProductLoadState(
        products: _cacheService.products,
        dataSource: DataSource.cache,
        error: 'Refresh failed: ${e.toString()}',
        lastFetchTime: _cacheService.lastFetchTime,
        isOffline: false,
      );
      _controller.add(_currentState!);
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _staleCheckTimer?.cancel();
    _preciseRefreshTimer?.cancel();
    _controller.close();
  }
}

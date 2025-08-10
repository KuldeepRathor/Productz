// lib/providers/providers.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:productz/repository/product_repository.dart';
import 'package:productz/services/api_services.dart';
import 'package:productz/services/cache_services.dart';

// Service Providers
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
final cacheServiceProvider = Provider<CacheService>((ref) => CacheService());

// Repository Provider
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final repo = ProductRepository(
    ref.read(apiServiceProvider),
    ref.read(cacheServiceProvider),
  );
  ref.onDispose(() => repo.dispose());
  return repo;
});

// Stream Provider for ProductLoadState
final productStateStreamProvider = StreamProvider<ProductLoadState>((ref) {
  return ref.read(productRepositoryProvider).getProductsWithState();
});

// Provider that emits current time every 30 seconds
final currentTimeProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});

// Helper provider to format time ago
final timeAgoProvider = Provider.family<String, DateTime?>((ref, time) {
  if (time == null) return '';

  // Watch the current time to trigger rebuilds
  final now = ref.watch(currentTimeProvider).value ?? DateTime.now();
  final difference = now.difference(time);

  if (difference.inSeconds < 60) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  return '${difference.inDays}d ago';
});

// Provider to calculate time until next auto-refresh
final timeUntilRefreshProvider = Provider.family<Duration?, DateTime?>((
  ref,
  lastFetchTime,
) {
  if (lastFetchTime == null) return null;

  // Watch current time for updates
  final now = ref.watch(currentTimeProvider).value ?? DateTime.now();
  final timeSinceLastFetch = now.difference(lastFetchTime);
  final timeUntilStale = const Duration(minutes: 5) - timeSinceLastFetch;

  return timeUntilStale.isNegative ? Duration.zero : timeUntilStale;
});

// Provider to format countdown
final refreshCountdownProvider = Provider.family<String, DateTime?>((
  ref,
  lastFetchTime,
) {
  final timeUntilRefresh = ref.watch(timeUntilRefreshProvider(lastFetchTime));

  if (timeUntilRefresh == null) return '';
  if (timeUntilRefresh == Duration.zero) return 'Refreshing soon...';

  final minutes = timeUntilRefresh.inMinutes;
  final seconds = timeUntilRefresh.inSeconds % 60;

  if (minutes > 0) {
    return 'Auto-refresh in ${minutes}m ${seconds}s';
  } else {
    return 'Auto-refresh in ${seconds}s';
  }
});

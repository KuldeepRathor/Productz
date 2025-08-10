import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import '../providers/providers.dart';
import '../repository/product_repository.dart';

class ProductListScreen extends ConsumerWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productStateAsync = ref.watch(productStateStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ProductZ'),
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        // actions: [
        //   // Show countdown in app bar when close to refresh
        //   productStateAsync.whenData((state) {
        //         if (state.lastFetchTime != null) {
        //           final timeUntilRefresh = ref.watch(
        //             timeUntilRefreshProvider(state.lastFetchTime),
        //           );
        //           if (timeUntilRefresh != null &&
        //               timeUntilRefresh.inMinutes < 1) {
        //             return Center(
        //               child: Padding(
        //                 padding: const EdgeInsets.only(right: 8.0),
        //                 child: Text(
        //                   '${timeUntilRefresh.inSeconds}s',
        //                   style: const TextStyle(
        //                     fontSize: 12,
        //                     color: Colors.orange,
        //                   ),
        //                 ),
        //               ),
        //             );
        //           }
        //         }
        //         return const SizedBox.shrink();
        //       }).value ??
        //       const SizedBox.shrink(),
        //   IconButton(
        //     icon: const Icon(Icons.refresh),
        //     onPressed: () {
        //       ref.read(productRepositoryProvider).refresh();
        //     },
        //   ),
        // ],
      ),
      body: productStateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: ${error.toString()}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.read(productRepositoryProvider).refresh();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (state) {
          return Column(
            children: [
              _buildStatusBar(state, ref),
              if (state.hasData && state.lastFetchTime != null)
                _buildAutoRefreshIndicator(state, ref),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.read(productRepositoryProvider).refresh();
                  },
                  child: state.hasData
                      ? _ProductGridView(products: state.products)
                      : const Center(child: Text('No products available')),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAutoRefreshIndicator(ProductLoadState state, WidgetRef ref) {
    // final countdown = ref.watch(refreshCountdownProvider(state.lastFetchTime));
    final timeUntilRefresh = ref.watch(
      timeUntilRefreshProvider(state.lastFetchTime),
    );

    if (timeUntilRefresh == null || timeUntilRefresh.inMinutes >= 5) {
      return const SizedBox.shrink();
    }

    return const SizedBox.shrink();
  }

  Widget _buildStatusBar(ProductLoadState state, WidgetRef ref) {
    Color backgroundColor;
    IconData icon;
    String message;

    if (state.isOffline && !state.hasData) {
      backgroundColor = Colors.grey;
      icon = Icons.wifi_off;
      message = 'No internet connection';
    } else if (state.isOffline && state.hasData) {
      backgroundColor = Colors.orange;
      icon = Icons.offline_bolt;
      message = 'Offline mode - showing saved data';
    } else if (state.isLoading) {
      backgroundColor = Colors.blue;
      icon = Icons.cloud_download;
      message = 'Loading products...';
    } else if (state.isRefreshing) {
      backgroundColor = Colors.orange;
      icon = Icons.refresh;
      message = 'Refreshing from network...';
    } else if (state.error != null && state.hasData) {
      backgroundColor = Colors.amber;
      icon = Icons.warning;
      message = 'Using cached data';
    } else if (state.error != null && !state.hasData) {
      backgroundColor = Colors.red;
      icon = Icons.error_outline;
      message = state.error!;
    } else if (state.dataSource == DataSource.cache) {
      final isStale = state.isStale;
      backgroundColor = isStale ? Colors.amber : Colors.green;
      icon = isStale ? Icons.access_time : Icons.storage;
      message = isStale ? 'Cached data (needs refresh)' : 'Cached data (fresh)';
    } else {
      backgroundColor = Colors.green;
      icon = Icons.check_circle;
      message = 'Products are up-to-date';
    }

    // Use the timeAgoProvider to get auto-updating time
    final timeAgo = ref.watch(timeAgoProvider(state.lastFetchTime));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: backgroundColor,
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // Show time until refresh if not stale yet
                if (state.lastFetchTime != null &&
                    !state.isStale &&
                    !state.isOffline)
                  Text(
                    ref.watch(refreshCountdownProvider(state.lastFetchTime)),
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
              ],
            ),
          ),
          if (state.lastFetchTime != null)
            Text(
              timeAgo,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

// Updated _ProductGridView with cached images
class _ProductGridView extends StatelessWidget {
  final List<Product> products;
  const _ProductGridView({required this.products});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.0,
        mainAxisSpacing: 12.0,
        childAspectRatio: 0.75,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Use CachedNetworkImage instead of Image.network
              SizedBox(
                height: 140,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: product.image,
                  fit: BoxFit.cover,
                  // Placeholder while loading
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  // Error widget if image fails to load
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                  // Cache configuration
                  cacheKey: product.image, // Use URL as cache key
                  fadeInDuration: const Duration(milliseconds: 300),
                  fadeOutDuration: const Duration(milliseconds: 300),
                  // Memory cache configuration
                  memCacheWidth: 400, // Optimize memory usage
                  memCacheHeight: 400,
                  // This ensures images are cached to disk
                  useOldImageOnUrlChange: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[300],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

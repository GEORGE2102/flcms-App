import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/foundation.dart';

/// Image cache configuration for different image types
class ImageCacheConfig {
  final String cacheKey;
  final Duration maxAge;
  final int maxNrOfCacheObjects;
  final int maxFileSize;
  final String description;

  const ImageCacheConfig({
    required this.cacheKey,
    required this.maxAge,
    required this.maxNrOfCacheObjects,
    required this.maxFileSize,
    required this.description,
  });
}

/// Cache statistics for monitoring
class CacheStats {
  final String cacheType;
  final int totalFiles;
  final int totalSizeBytes;
  final DateTime lastAccessed;
  final Duration averageAge;

  CacheStats({
    required this.cacheType,
    required this.totalFiles,
    required this.totalSizeBytes,
    required this.lastAccessed,
    required this.averageAge,
  });

  double get totalSizeMB => totalSizeBytes / (1024 * 1024);
}

/// Image caching service with advanced management capabilities
class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  // Cache configurations for different image types
  static const _fellowshipCacheConfig = ImageCacheConfig(
    cacheKey: 'fellowship_images',
    maxAge: Duration(days: 30), // Fellowship photos cached for 30 days
    maxNrOfCacheObjects: 500, // Up to 500 fellowship images
    maxFileSize: 10 * 1024 * 1024, // 10MB per file
    description: 'Fellowship report images',
  );

  static const _receiptCacheConfig = ImageCacheConfig(
    cacheKey: 'receipt_images',
    maxAge: Duration(days: 90), // Receipts cached longer for record keeping
    maxNrOfCacheObjects: 1000, // More receipts expected
    maxFileSize: 15 * 1024 * 1024, // 15MB per file (higher quality)
    description: 'Financial receipt images',
  );

  static const _busCacheConfig = ImageCacheConfig(
    cacheKey: 'bus_images',
    maxAge: Duration(days: 14), // Bus photos cached for 2 weeks
    maxNrOfCacheObjects: 200, // Fewer bus images expected
    maxFileSize: 8 * 1024 * 1024, // 8MB per file
    description: 'Bus mobilization images',
  );

  static const _profileCacheConfig = ImageCacheConfig(
    cacheKey: 'profile_images',
    maxAge: Duration(days: 60), // Profile pictures cached for 2 months
    maxNrOfCacheObjects: 300, // Member profile pictures
    maxFileSize: 5 * 1024 * 1024, // 5MB per file
    description: 'User profile pictures',
  );

  // Cache managers for different image types
  late final CacheManager _fellowshipCacheManager;
  late final CacheManager _receiptCacheManager;
  late final CacheManager _busCacheManager;
  late final CacheManager _profileCacheManager;
  late final CacheManager _generalCacheManager;

  bool _initialized = false;

  /// Initialize cache managers with configurations
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize fellowship images cache
      _fellowshipCacheManager = CacheManager(
        Config(
          _fellowshipCacheConfig.cacheKey,
          stalePeriod: _fellowshipCacheConfig.maxAge,
          maxNrOfCacheObjects: _fellowshipCacheConfig.maxNrOfCacheObjects,
          fileService: HttpFileService(),
        ),
      );

      // Initialize receipt images cache
      _receiptCacheManager = CacheManager(
        Config(
          _receiptCacheConfig.cacheKey,
          stalePeriod: _receiptCacheConfig.maxAge,
          maxNrOfCacheObjects: _receiptCacheConfig.maxNrOfCacheObjects,
          fileService: HttpFileService(),
        ),
      );

      // Initialize bus images cache
      _busCacheManager = CacheManager(
        Config(
          _busCacheConfig.cacheKey,
          stalePeriod: _busCacheConfig.maxAge,
          maxNrOfCacheObjects: _busCacheConfig.maxNrOfCacheObjects,
          fileService: HttpFileService(),
        ),
      );

      // Initialize profile images cache
      _profileCacheManager = CacheManager(
        Config(
          _profileCacheConfig.cacheKey,
          stalePeriod: _profileCacheConfig.maxAge,
          maxNrOfCacheObjects: _profileCacheConfig.maxNrOfCacheObjects,
          fileService: HttpFileService(),
        ),
      );

      // Initialize general cache for other images
      _generalCacheManager = CacheManager(
        Config(
          'general_images',
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: 100,
          fileService: HttpFileService(),
        ),
      );

      _initialized = true;
      if (kDebugMode) {
        print('ImageCacheService initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize ImageCacheService: $e');
      }
      rethrow;
    }
  }

  /// Get appropriate cache manager for image type
  CacheManager _getCacheManager(String imageType) {
    _ensureInitialized();

    switch (imageType.toLowerCase()) {
      case 'fellowship':
        return _fellowshipCacheManager;
      case 'receipt':
        return _receiptCacheManager;
      case 'bus':
        return _busCacheManager;
      case 'profile':
        return _profileCacheManager;
      default:
        return _generalCacheManager;
    }
  }

  /// Ensure service is initialized
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'ImageCacheService not initialized. Call initialize() first.',
      );
    }
  }

  /// Get cached network image widget with smart caching
  Widget getCachedNetworkImage({
    required String imageUrl,
    required String imageType,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
    Duration fadeInDuration = const Duration(milliseconds: 500),
    Duration placeholderFadeInDuration = const Duration(milliseconds: 500),
  }) {
    _ensureInitialized();

    final cacheManager = _getCacheManager(imageType);

    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: cacheManager,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: fadeInDuration,
      placeholderFadeInDuration: placeholderFadeInDuration,
      placeholder:
          placeholder != null
              ? (context, url) => placeholder
              : (context, url) => _buildDefaultPlaceholder(imageType),
      errorWidget:
          errorWidget != null
              ? (context, url, error) => errorWidget
              : (context, url, error) => _buildDefaultErrorWidget(imageType),
      memCacheWidth: width?.round(),
      memCacheHeight: height?.round(),
    );
  }

  /// Pre-cache an image for offline access
  Future<void> precacheImage({
    required String imageUrl,
    required String imageType,
  }) async {
    _ensureInitialized();

    try {
      final cacheManager = _getCacheManager(imageType);
      await cacheManager.downloadFile(imageUrl);

      if (kDebugMode) {
        print('Pre-cached $imageType image: $imageUrl');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to pre-cache $imageType image: $e');
      }
    }
  }

  /// Pre-cache multiple images for offline access
  Future<void> precacheImages({
    required List<String> imageUrls,
    required String imageType,
    Function(int completed, int total)? onProgress,
  }) async {
    _ensureInitialized();

    final total = imageUrls.length;
    var completed = 0;

    for (final imageUrl in imageUrls) {
      try {
        await precacheImage(imageUrl: imageUrl, imageType: imageType);
        completed++;
        onProgress?.call(completed, total);
      } catch (e) {
        if (kDebugMode) {
          print('Failed to pre-cache image $imageUrl: $e');
        }
        completed++; // Count failed attempts too
        onProgress?.call(completed, total);
      }
    }
  }

  /// Check if image is cached
  Future<bool> isImageCached({
    required String imageUrl,
    required String imageType,
  }) async {
    _ensureInitialized();

    try {
      final cacheManager = _getCacheManager(imageType);
      final fileInfo = await cacheManager.getFileFromCache(imageUrl);
      return fileInfo != null && fileInfo.validTill.isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  /// Get cached file for offline access
  Future<File?> getCachedFile({
    required String imageUrl,
    required String imageType,
  }) async {
    _ensureInitialized();

    try {
      final cacheManager = _getCacheManager(imageType);
      final fileInfo = await cacheManager.getFileFromCache(imageUrl);

      if (fileInfo != null && fileInfo.validTill.isAfter(DateTime.now())) {
        return fileInfo.file;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to get cached file: $e');
      }
      return null;
    }
  }

  /// Clear cache for specific image type
  Future<void> clearCache(String imageType) async {
    _ensureInitialized();

    try {
      final cacheManager = _getCacheManager(imageType);
      await cacheManager.emptyCache();

      if (kDebugMode) {
        print('Cleared $imageType cache');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to clear $imageType cache: $e');
      }
    }
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    _ensureInitialized();

    final cacheTypes = ['fellowship', 'receipt', 'bus', 'profile', 'general'];

    for (final type in cacheTypes) {
      await clearCache(type);
    }

    if (kDebugMode) {
      print('Cleared all image caches');
    }
  }

  /// Remove specific image from cache
  Future<void> removeFromCache({
    required String imageUrl,
    required String imageType,
  }) async {
    _ensureInitialized();

    try {
      final cacheManager = _getCacheManager(imageType);
      await cacheManager.removeFile(imageUrl);

      if (kDebugMode) {
        print('Removed image from $imageType cache: $imageUrl');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to remove image from cache: $e');
      }
    }
  }

  /// Get cache statistics for monitoring
  Future<List<CacheStats>> getCacheStatistics() async {
    _ensureInitialized();

    final stats = <CacheStats>[];
    final cacheManagers = {
      'fellowship': _fellowshipCacheManager,
      'receipt': _receiptCacheManager,
      'bus': _busCacheManager,
      'profile': _profileCacheManager,
      'general': _generalCacheManager,
    };

    for (final entry in cacheManagers.entries) {
      try {
        // Note: This is a simplified implementation
        // Real implementation would require accessing cache internals
        stats.add(
          CacheStats(
            cacheType: entry.key,
            totalFiles: 0, // Would need cache manager internals
            totalSizeBytes: 0, // Would need cache manager internals
            lastAccessed: DateTime.now(),
            averageAge: Duration.zero,
          ),
        );
      } catch (e) {
        if (kDebugMode) {
          print('Failed to get stats for ${entry.key} cache: $e');
        }
      }
    }

    return stats;
  }

  /// Get cache configuration for image type
  ImageCacheConfig getCacheConfig(String imageType) {
    switch (imageType.toLowerCase()) {
      case 'fellowship':
        return _fellowshipCacheConfig;
      case 'receipt':
        return _receiptCacheConfig;
      case 'bus':
        return _busCacheConfig;
      case 'profile':
        return _profileCacheConfig;
      default:
        return const ImageCacheConfig(
          cacheKey: 'general_images',
          maxAge: Duration(days: 7),
          maxNrOfCacheObjects: 100,
          maxFileSize: 5 * 1024 * 1024,
          description: 'General cached images',
        );
    }
  }

  /// Build default placeholder widget
  Widget _buildDefaultPlaceholder(String imageType) {
    IconData icon;
    switch (imageType.toLowerCase()) {
      case 'fellowship':
        icon = Icons.groups;
        break;
      case 'receipt':
        icon = Icons.receipt;
        break;
      case 'bus':
        icon = Icons.bus_alert;
        break;
      case 'profile':
        icon = Icons.person;
        break;
      default:
        icon = Icons.image;
    }

    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.grey[400], size: 48),
            const SizedBox(height: 8),
            const CircularProgressIndicator(strokeWidth: 2),
          ],
        ),
      ),
    );
  }

  /// Build default error widget
  Widget _buildDefaultErrorWidget(String imageType) {
    IconData icon;
    switch (imageType.toLowerCase()) {
      case 'fellowship':
        icon = Icons.groups;
        break;
      case 'receipt':
        icon = Icons.receipt;
        break;
      case 'bus':
        icon = Icons.bus_alert;
        break;
      case 'profile':
        icon = Icons.person;
        break;
      default:
        icon = Icons.image;
    }

    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.grey[400], size: 48),
            const SizedBox(height: 8),
            Text(
              'Image not available',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  /// Dispose resources
  void dispose() {
    // Cache managers are automatically disposed by the framework
    _initialized = false;
  }
}

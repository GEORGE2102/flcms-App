import 'package:flutter/material.dart';
import '../services/image_cache_service.dart';

/// A reusable widget for displaying cached images with consistent styling
class CachedImageWidget extends StatelessWidget {
  final String? imageUrl;
  final String imageType;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Widget? customPlaceholder;
  final Widget? customErrorWidget;
  final bool showLoadingIndicator;
  final Duration fadeInDuration;

  const CachedImageWidget({
    super.key,
    this.imageUrl,
    required this.imageType,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.backgroundColor,
    this.customPlaceholder,
    this.customErrorWidget,
    this.showLoadingIndicator = true,
    this.fadeInDuration = const Duration(milliseconds: 500),
  });

  /// Factory constructor for fellowship images
  factory CachedImageWidget.fellowship({
    String? imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return CachedImageWidget(
      imageUrl: imageUrl,
      imageType: 'fellowship',
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      customPlaceholder: placeholder,
      customErrorWidget: errorWidget,
    );
  }

  /// Factory constructor for receipt images
  factory CachedImageWidget.receipt({
    String? imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return CachedImageWidget(
      imageUrl: imageUrl,
      imageType: 'receipt',
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      customPlaceholder: placeholder,
      customErrorWidget: errorWidget,
    );
  }

  /// Factory constructor for bus images
  factory CachedImageWidget.bus({
    String? imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return CachedImageWidget(
      imageUrl: imageUrl,
      imageType: 'bus',
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      customPlaceholder: placeholder,
      customErrorWidget: errorWidget,
    );
  }

  /// Factory constructor for profile images
  factory CachedImageWidget.profile({
    String? imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return CachedImageWidget(
      imageUrl: imageUrl,
      imageType: 'profile',
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      customPlaceholder: placeholder,
      customErrorWidget: errorWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Handle null or empty image URL
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildEmptyState();
    }

    Widget imageWidget = ImageCacheService().getCachedNetworkImage(
      imageUrl: imageUrl!,
      imageType: imageType,
      width: width,
      height: height,
      fit: fit,
      placeholder: customPlaceholder,
      errorWidget: customErrorWidget,
      fadeInDuration: fadeInDuration,
    );

    // Apply border radius if specified
    if (borderRadius != null) {
      imageWidget = ClipRRect(borderRadius: borderRadius!, child: imageWidget);
    }

    // Apply background color if specified
    if (backgroundColor != null) {
      imageWidget = Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius,
        ),
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  /// Build empty state when no image URL is provided
  Widget _buildEmptyState() {
    IconData icon;
    String text;

    switch (imageType.toLowerCase()) {
      case 'fellowship':
        icon = Icons.groups_outlined;
        text = 'No fellowship photo';
        break;
      case 'receipt':
        icon = Icons.receipt_long_outlined;
        text = 'No receipt image';
        break;
      case 'bus':
        icon = Icons.directions_bus_outlined;
        text = 'No bus photo';
        break;
      case 'profile':
        icon = Icons.person_outline;
        text = 'No profile picture';
        break;
      default:
        icon = Icons.image_outlined;
        text = 'No image available';
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey[100],
        borderRadius: borderRadius,
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Colors.grey[400],
            size: (height != null && height! < 100) ? 32 : 48,
          ),
          if (height == null || height! > 60)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                text,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

/// A widget for displaying image thumbnails in lists
class CachedImageThumbnail extends StatelessWidget {
  final String? imageUrl;
  final String imageType;
  final double size;
  final VoidCallback? onTap;

  const CachedImageThumbnail({
    super.key,
    this.imageUrl,
    required this.imageType,
    this.size = 60,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: CachedImageWidget(
            imageUrl: imageUrl,
            imageType: imageType,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

/// A widget for displaying images in a fullscreen overlay
class CachedImageViewer extends StatelessWidget {
  final String imageUrl;
  final String imageType;
  final String? title;

  const CachedImageViewer({
    super.key,
    required this.imageUrl,
    required this.imageType,
    this.title,
  });

  /// Show image in fullscreen overlay
  static void show(
    BuildContext context, {
    required String imageUrl,
    required String imageType,
    String? title,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder:
          (context) => CachedImageViewer(
            imageUrl: imageUrl,
            imageType: imageType,
            title: title,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          title:
              title != null
                  ? Text(title!, style: const TextStyle(color: Colors.white))
                  : null,
          actions: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 3.0,
            child: CachedImageWidget(
              imageUrl: imageUrl,
              imageType: imageType,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

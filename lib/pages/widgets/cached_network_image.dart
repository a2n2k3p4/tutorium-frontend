import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tutorium_frontend/util/image_cache_manager.dart';

/// Cached network image widget with automatic caching
class CachedNetworkImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const CachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  State<CachedNetworkImage> createState() => _CachedNetworkImageState();
}

class _CachedNetworkImageState extends State<CachedNetworkImage> {
  final _imageCache = ImageCacheManager();
  Uint8List? _imageBytes;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(CachedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final bytes = await _imageCache.getImage(widget.imageUrl);
      if (mounted) {
        setState(() {
          _imageBytes = bytes;
          _isLoading = false;
          _hasError = bytes == null;
        });
      }
    } catch (e) {
      debugPrint('⚠️ [CachedNetworkImage] Load error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (_isLoading) {
      child =
          widget.placeholder ??
          Container(
            color: Colors.grey[300],
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
    } else if (_hasError || _imageBytes == null) {
      child =
          widget.errorWidget ??
          Container(
            color: Colors.grey[300],
            child: Icon(Icons.broken_image, color: Colors.grey[600], size: 48),
          );
    } else {
      child = Image.memory(
        _imageBytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
      );
    }

    if (widget.borderRadius != null) {
      child = ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }

    return SizedBox(width: widget.width, height: widget.height, child: child);
  }
}

/// Cached circular avatar with automatic caching
class CachedCircularAvatar extends StatelessWidget {
  final String imageUrl;
  final double radius;
  final Color? backgroundColor;

  const CachedCircularAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 40,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty || !imageUrl.startsWith('http')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? Colors.grey[300],
        child: Icon(Icons.person, size: radius * 1.2, color: Colors.grey[600]),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor ?? Colors.grey[300],
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
        errorWidget: CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor ?? Colors.grey[300],
          child: Icon(
            Icons.person,
            size: radius * 1.2,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }
}

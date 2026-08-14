import 'package:flutter/material.dart';
import '../config.dart';

class LandmarkImage extends StatelessWidget {
  final String? imagePath;
  final double size;
  final BorderRadius? borderRadius;

  const LandmarkImage({
    super.key,
    required this.imagePath,
    this.size = 56,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(8);
    final url = resolveImageUrl(imagePath);

    Widget child;
    if (url.isEmpty) {
      child = _placeholder();
    } else {
      child = Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, widget, progress) {
          if (progress == null) return widget;
          return SizedBox(
            width: size,
            height: size,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => _placeholder(icon: Icons.broken_image),
      );
    }

    return ClipRRect(borderRadius: radius, child: child);
  }

  Widget _placeholder({IconData icon = Icons.photo_camera_back}) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey.shade300,
      child: Icon(icon, color: Colors.grey.shade600, size: size * 0.5),
    );
  }
}

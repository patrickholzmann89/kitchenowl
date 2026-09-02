import 'package:material_ui/material_ui.dart';
import 'package:kitchenowl/models/store.dart';
import 'package:kitchenowl/widgets/image_provider.dart';

class StoreCircleAvatar extends StatelessWidget {
  final Store store;
  final double? radius;
  final TextScaler? textScaler;

  const StoreCircleAvatar({
    super.key,
    required this.store,
    this.radius,
    this.textScaler,
  });

  @override
  Widget build(BuildContext context) {
    // Isolates the avatar's own texture from the scroll-driven repaints of
    // its ancestors - a clipped image can otherwise render solid black on
    // Impeller (iOS's mandatory renderer since Flutter 3.29, no Skia
    // fallback anymore).
    return RepaintBoundary(
      child: CircleAvatar(
        foregroundImage: store.photo?.isEmpty ?? true
            ? null
            : getImageProvider(
                context,
                store.photo!,
              ),
        child: store.name.isNotEmpty
            ? Text(
                store.name.substring(0, 1),
                textScaler: textScaler,
              )
            : null,
        radius: radius,
      ),
    );
  }
}

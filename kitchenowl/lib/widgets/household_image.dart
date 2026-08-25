import 'package:material_ui/material_ui.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/pages/household_member_page.dart';
import 'package:kitchenowl/widgets/avatar_list.dart';
import 'package:kitchenowl/widgets/image_provider.dart';
import 'package:transparent_image/transparent_image.dart';

class HouseholdImage extends StatelessWidget {
  final Household household;
  final bool enableMembersTap;

  const HouseholdImage({
    super.key,
    required this.household,
    this.enableMembersTap = true,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 150,
        child: Stack(
          alignment: Alignment.bottomLeft,
          fit: StackFit.loose,
          children: [
            SizedBox.expand(
              // Isolates the image's own texture from the clip/scroll-driven
              // repaints of its ancestors - a ClipRRect'd image can otherwise
              // render solid black on Impeller (iOS's mandatory renderer
              // since Flutter 3.29, no Skia fallback anymore).
              child: RepaintBoundary(
                child: FadeInImage(
                  fit: BoxFit.cover,
                  placeholder: household.imageHash != null
                      ? BlurHashImage(household.imageHash!)
                      : MemoryImage(kTransparentImage) as ImageProvider,
                  image: getImageProvider(
                    context,
                    household.image!,
                  ),
                ),
              ),
            ),
            if (household.member != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: AvatarList(
                  users: household.member!,
                  onTap: enableMembersTap
                      ? () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => HouseholdMemberPage(
                                household: household,
                              ),
                            ),
                          )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

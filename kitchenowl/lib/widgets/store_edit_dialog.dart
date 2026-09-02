import 'package:material_ui/material_ui.dart';
import 'package:kitchenowl/helpers/named_bytearray.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/services/api/api_service.dart';

class StoreEditResult {
  final String name;
  // Uploaded photo filename, empty string to remove the current photo, or
  // null if the photo wasn't touched.
  final String? photo;

  const StoreEditResult({required this.name, this.photo});
}

class StoreEditDialog extends StatefulWidget {
  final String title;
  final String doneText;
  final String? initialName;
  final String? initialPhoto;

  const StoreEditDialog({
    super.key,
    required this.title,
    required this.doneText,
    this.initialName,
    this.initialPhoto,
  });

  @override
  State<StoreEditDialog> createState() => _StoreEditDialogState();
}

class _StoreEditDialogState extends State<StoreEditDialog> {
  late final TextEditingController controller;
  NamedByteArray? pickedImage;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  bool get validText => controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ImageSelector(
              padding: EdgeInsets.zero,
              image: pickedImage,
              originalImage: widget.initialPhoto,
              setImage: (image) => setState(() => pickedImage = image),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              onChanged: (value) => setState(() {}),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.name,
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: !validText || loading
              ? null
              : () async {
                  setState(() => loading = true);
                  String? photo;
                  if (pickedImage != null) {
                    photo = pickedImage!.isEmpty
                        ? ''
                        : await ApiService.getInstance()
                                .uploadBytes(pickedImage!) ??
                            '';
                  }
                  if (!context.mounted) return;
                  Navigator.of(context).pop(StoreEditResult(
                    name: controller.text.trim(),
                    photo: photo,
                  ));
                },
          child: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.doneText),
        ),
      ],
    );
  }
}

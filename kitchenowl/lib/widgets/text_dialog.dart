import 'package:material_ui/material_ui.dart';

class TextDialog extends StatefulWidget {
  final String title;
  final String hintText;
  final String doneText;
  final TextInputType? textInputType;
  final bool Function(String)? isInputValid;
  final void Function(String)? onDone;
  final String? initialText;
  final List<Widget>? actions;
  final int minLines;
  final int? maxLines;

  const TextDialog({
    super.key,
    this.title = "",
    this.doneText = "",
    this.hintText = "",
    this.initialText,
    this.textInputType,
    this.isInputValid,
    this.actions,
    this.onDone,
    this.minLines = 1,
    this.maxLines = 1,
  });

  @override
  State<TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<TextDialog> {
  bool validText = true;
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialText);
    if (widget.isInputValid != null) {
      validText = widget.isInputValid!(widget.initialText ?? '');
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              onChanged: (value) {
                if (widget.isInputValid != null) {
                  setState(() {
                    validText = widget.isInputValid!(value);
                  });
                }
              },
              onSubmitted: widget.maxLines == 1
                  ? (t) {
                      if (validText) Navigator.of(context).pop(t);
                    }
                  : null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: widget.hintText),
              keyboardType: widget.textInputType,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
            ),
          ],
        ),
      ),
      actions: [
        if (widget.actions != null) ...widget.actions!,
        FilledButton(
          onPressed: validText
              ? () {
                  if (widget.onDone != null) widget.onDone!(controller.text);
                  Navigator.of(context).pop(controller.text);
                }
              : null,
          child: Text(widget.doneText),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../l10n/loc_extensions.dart';

/// Collect intent first; the caller performs the authoritative server action.
Future<String?> managementReason(
    BuildContext context, String title, String help,
    {bool requireReason = true}) async {
  final controller = TextEditingController();
  final form = GlobalKey<FormState>();
  final l = context.l10n;
  final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
              scrollable: true,
              title: Text(title),
              content: Form(
                  key: form,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(help),
                    const SizedBox(height: 20),
                    if (requireReason)
                      TextFormField(
                          controller: controller,
                          minLines: 2,
                          maxLines: 5,
                          maxLength: 500,
                          decoration:
                              InputDecoration(labelText: l.managementReason),
                          validator: (v) => (v?.trim().length ?? 0) < 3
                              ? l.managementReason
                              : null),
                  ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: Text(l.commonCancel)),
                FilledButton(
                    onPressed: () {
                      if (form.currentState!.validate()) {
                        Navigator.pop(c, controller.text.trim());
                      }
                    },
                    child: Text(l.managementConfirm))
              ]));
  // The dialog may still be animating when its route returns.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  controller.dispose();
  return result;
}

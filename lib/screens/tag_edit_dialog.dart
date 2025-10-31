import 'package:flutter/material.dart';
import '../utils/input_security.dart';

class TagEditDialog extends StatefulWidget {
  final List<String> initialTags;
  const TagEditDialog({super.key, required this.initialTags});
  @override
  State<TagEditDialog> createState() => _TagEditDialogState();
}

class _TagEditDialogState extends State<TagEditDialog> {
  late List<String> tags;
  late final SecureTextEditingController controller;
  
  @override
  void initState() {
    super.initState();
    tags = List.from(widget.initialTags);
    controller = SecureTextEditingController(
      validator: (text) => InputSecurity.validateInput(text, maxLength: 50),
      sanitizer: InputSecurity.sanitizeInput,
    );
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Tags'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          Wrap(
            spacing: 8,
            children: tags.map((t) => Chip(
              label: Text(t),
              onDeleted: () => setState(() => tags.remove(t)),
            )).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(hintText: 'Add tag'),
                  onSubmitted: (val) {
                    final trimmedVal = val.trim();
                    
                    // Validate input
                    final validation = InputSecurity.validateInput(trimmedVal, maxLength: 50);
                    if (!validation.isValid) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Tag hatası: ${validation.errorMessage}')),
                      );
                      return;
                    }
                    
                    final sanitizedVal = InputSecurity.sanitizeInput(trimmedVal);
                    if (sanitizedVal.isNotEmpty && !tags.contains(sanitizedVal)) {
                      setState(() => tags.add(sanitizedVal));
                      controller.clear();
                    }
                  },
                ),
              ),
              IconButton(
                icon: Icon(Icons.add),
                onPressed: () {
                  final val = controller.text.trim();
                  if (val.isNotEmpty && !tags.contains(val)) {
                    setState(() => tags.add(val));
                    controller.clear();
                  }
                },
              )
            ],
          ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(widget.initialTags),
        ),
        TextButton(
          child: const Text('Save'),
          onPressed: () => Navigator.of(context).pop(tags),
        ),
      ],
    );
  }
}

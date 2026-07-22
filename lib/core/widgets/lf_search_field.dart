import 'package:flutter/material.dart';

import '../theme/lf_colors.dart';

/// Rounded search input used on dashboard, leads and search.
class LfSearchField extends StatelessWidget {
  const LfSearchField({
    super.key,
    this.controller,
    this.hint = 'Search leads, companies…',
    this.onChanged,
    this.autofocus = false,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: autofocus,
      readOnly: readOnly,
      onTap: onTap,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.search_rounded, color: context.lf.inkTertiary, size: 22),
      ),
    );
  }
}

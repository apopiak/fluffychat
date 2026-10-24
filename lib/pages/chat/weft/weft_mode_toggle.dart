// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:material_ui/material_ui.dart';

class WeftModeToggle extends StatelessWidget {
  final bool weft;
  final ValueChanged<bool> onChanged;
  final String threadsLabel;
  final String weftLabel;

  static const double height = 32;

  const WeftModeToggle({
    required this.weft,
    required this.onChanged,
    required this.threadsLabel,
    required this.weftLabel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      widthFactor: 1,
      child: SegmentedButton<bool>(
        segments: [
          ButtonSegment(value: false, label: Text(threadsLabel)),
          ButtonSegment(value: true, label: Text(weftLabel)),
        ],
        selected: {weft},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => onChanged(selection.first),
        style: const ButtonStyle(
          visualDensity: VisualDensity(horizontal: -3, vertical: -3),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: WidgetStatePropertyAll(Size(0, height)),
          maximumSize: WidgetStatePropertyAll(Size(double.infinity, height)),
          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
          textStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

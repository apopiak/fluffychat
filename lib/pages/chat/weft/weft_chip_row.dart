// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/pages/chat/weft/weft_colors.dart';
import 'package:fluffychat/pages/chat/weft/weft_types.dart';
import 'package:material_ui/material_ui.dart';

class WeftChipRow extends StatelessWidget {
  final List<WeftThreadSummary> threads;
  final String? selectedRootId;
  final ValueChanged<String?> onSelected;
  final String allLabel;

  static const double fixedHeight = 44;

  const WeftChipRow({
    required this.threads,
    required this.selectedRootId,
    required this.onSelected,
    required this.allLabel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: fixedHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: threads.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) => i == 0
            ? _WeftChip(
                label: allLabel,
                selected: selectedRootId == null,
                onSelected: (_) => onSelected(null),
              )
            : _WeftChip(
                label: threads[i - 1].title,
                rootId: threads[i - 1].rootId,
                selected: selectedRootId == threads[i - 1].rootId,
                onSelected: (selected) =>
                    onSelected(selected ? threads[i - 1].rootId : null),
              ),
      ),
    );
  }
}

class _WeftChip extends StatelessWidget {
  final String label;
  final String? rootId;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _WeftChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.rootId,
  });

  @override
  Widget build(BuildContext context) {
    final rootId = this.rootId;
    final color = rootId == null ? null : weftColorFor(context, rootId);
    return FilterChip(
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      labelStyle: const TextStyle(fontSize: 13),
      avatar: color == null ? null : _WeftChipDot(color: color),
      selected: selected,
      showCheckmark: false,
      selectedColor: color?.withValues(alpha: 0.24),
      side: selected && color != null ? BorderSide(color: color) : null,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      onSelected: onSelected,
    );
  }
}

class _WeftChipDot extends StatelessWidget {
  final Color color;

  const _WeftChipDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.square(
        dimension: 8,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

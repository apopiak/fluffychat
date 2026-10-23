// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/pages/chat/weft/weft_braid.dart';
import 'package:fluffychat/pages/chat/weft/weft_types.dart';
import 'package:material_ui/material_ui.dart';

WeftRowState weftPassThroughAbove(WeftRowState state) => WeftRowState(
  lanes: [
    for (final lane in state.lanes)
      if (lane.lineAbove)
        WeftLane(index: lane.index, rootId: lane.rootId, stage: lane.stage),
  ],
);

class WeftBraidFrame extends StatelessWidget {
  final WeftRowState? weftRow;
  final Widget child;

  const WeftBraidFrame({required this.weftRow, required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final weftRow = this.weftRow;
    if (weftRow == null) return child;
    final lanes = math.max(
      WeftGutter.lanesOf(context),
      weftEffectiveLaneCount(weftRow),
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: FluffyThemes.maxTimelineWidth,
        ),
        child: SizedBox(
          width: double.infinity,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(left: weftBraidWidth(lanes)),
                child: child,
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: WeftBraid(state: weftRow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WeftGutter extends InheritedWidget {
  const WeftGutter({required this.lanes, required super.child, super.key});

  final int lanes;

  static int lanesOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WeftGutter>()?.lanes ?? 0;

  @override
  bool updateShouldNotify(WeftGutter oldWidget) => oldWidget.lanes != lanes;
}

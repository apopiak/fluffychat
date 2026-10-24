// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

import 'package:fluffychat/pages/chat/weft/weft_colors.dart';
import 'package:fluffychat/pages/chat/weft/weft_types.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

const double weftLaneOffset = 8;
const double weftLaneSpacing = 9;

double weftBraidWidth(int laneCount) =>
    laneCount <= 0 ? 0 : weftLaneOffset + weftLaneSpacing * laneCount;

double weftLaneX(int index) => weftLaneOffset + weftLaneSpacing * index;

int weftEffectiveLaneCount(WeftRowState state) {
  final dotLane = state.dotLane;
  if (dotLane == null) return state.laneCount;
  return math.max(state.laneCount, dotLane + 1);
}

class WeftBraid extends StatelessWidget {
  final WeftRowState state;

  const WeftBraid({required this.state, super.key});

  @override
  Widget build(BuildContext context) {
    if (state.isEmpty) return const SizedBox.shrink();
    final width = weftBraidWidth(weftEffectiveLaneCount(state));
    return SizedBox(
      width: width,
      child: LimitedBox(
        maxHeight: 0,
        child: CustomPaint(
          size: Size(width, double.infinity),
          painter: _WeftBraidPainter(
            state: state,
            colors: {
              for (final rootId in [
                for (final lane in state.lanes) lane.rootId,
                ?state.rootId,
              ])
                rootId: weftColorFor(context, rootId),
            },
          ),
        ),
      ),
    );
  }
}

class _WeftBraidPainter extends CustomPainter {
  final WeftRowState state;
  final Map<String, Color> colors;

  static const double _strokeWidth = 2;
  static const double _lineOpacity = 0.55;
  static const double _dotRadius = 4;
  static const double _dotGap = 2;
  static const double _dashOn = 4;
  static const double _dashOff = 3;

  const _WeftBraidPainter({required this.state, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final dotLane = state.dotLane;
    const gapRadius = _dotRadius + _dotGap;

    for (final lane in state.lanes) {
      final hasDot = lane.index == dotLane;
      final paint = Paint()
        ..color = (colors[lane.rootId] ?? Colors.grey).withValues(
          alpha: _lineOpacity,
        )
        ..strokeWidth = _strokeWidth
        ..style = PaintingStyle.stroke;
      final x = weftLaneX(lane.index);
      final dashed = lane.stage == WeftStage.proto;

      if (!hasDot) {
        if (lane.lineAbove || lane.lineBelow) {
          _drawLine(canvas, x, 0, size.height, paint, dashed);
        }
        continue;
      }
      if (lane.lineAbove) {
        _drawLine(canvas, x, 0, centerY - gapRadius, paint, dashed);
      }
      if (lane.lineBelow) {
        _drawLine(canvas, x, centerY + gapRadius, size.height, paint, dashed);
      }
    }

    if (dotLane == null) return;
    final rootId = state.rootId ?? _laneRootId(dotLane);
    if (rootId == null) return;
    final color = colors[rootId] ?? Colors.grey;
    final center = Offset(weftLaneX(dotLane), centerY);
    final isProto = state.stage == WeftStage.proto;
    canvas.drawCircle(
      center,
      isProto ? _dotRadius - _strokeWidth / 2 : _dotRadius,
      Paint()
        ..color = color
        ..strokeWidth = _strokeWidth
        ..style = isProto ? PaintingStyle.stroke : PaintingStyle.fill,
    );
  }

  String? _laneRootId(int index) {
    for (final lane in state.lanes) {
      if (lane.index == index) return lane.rootId;
    }
    return null;
  }

  void _drawLine(
    Canvas canvas,
    double x,
    double top,
    double bottom,
    Paint paint,
    bool dashed,
  ) {
    if (bottom <= top) return;
    if (!dashed) {
      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
      return;
    }
    for (var y = top; y < bottom; y += _dashOn + _dashOff) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, math.min(y + _dashOn, bottom)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WeftBraidPainter oldDelegate) =>
      !mapEquals(oldDelegate.colors, colors) ||
      !_sameRowState(oldDelegate.state, state);
}

bool _sameRowState(WeftRowState a, WeftRowState b) {
  if (identical(a, b)) return true;
  if (a.dotLane != b.dotLane ||
      a.rootId != b.rootId ||
      a.stage != b.stage ||
      a.lanes.length != b.lanes.length) {
    return false;
  }
  for (var i = 0; i < a.lanes.length; i++) {
    final laneA = a.lanes[i];
    final laneB = b.lanes[i];
    if (laneA.index != laneB.index ||
        laneA.rootId != laneB.rootId ||
        laneA.stage != laneB.stage ||
        laneA.lineAbove != laneB.lineAbove ||
        laneA.lineBelow != laneB.lineBelow) {
      return false;
    }
  }
  return true;
}

// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

enum WeftStage { none, proto, materialized }

class WeftLane {
  const WeftLane({
    required this.index,
    required this.rootId,
    required this.stage,
    this.lineAbove = true,
    this.lineBelow = true,
  });

  final int index;
  final String rootId;
  final WeftStage stage;
  final bool lineAbove;
  final bool lineBelow;
}

class WeftRowState {
  const WeftRowState({
    this.lanes = const [],
    this.dotLane,
    this.rootId,
    this.stage = WeftStage.none,
    this.isRoot = false,
    this.title,
  });

  static const empty = WeftRowState();

  final List<WeftLane> lanes;
  final int? dotLane;
  final String? rootId;
  final WeftStage stage;
  final bool isRoot;
  final String? title;

  int get laneCount => lanes.fold(
    0,
    (count, lane) => lane.index + 1 > count ? lane.index + 1 : count,
  );

  bool get isEmpty => lanes.isEmpty && dotLane == null;
}

class WeftThreadSummary {
  const WeftThreadSummary({
    required this.rootId,
    required this.title,
    required this.size,
  });

  final String rootId;
  final String title;
  final int size;
}

// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';

import 'weft_types.dart';

const int weftMaxLanes = 4;
const int weftTitleWordCount = 5;
const String weftFallbackTitle = 'Thread';

const Set<String> _discourseStarters = {
  'so',
  'hey',
  'ok',
  'okay',
  'btw',
  'well',
  'hi',
  'hello',
  'yeah',
  'um',
};

final RegExp _edgePunctuation = RegExp(
  r'^[\p{P}\s]+|[\p{P}\s]+$',
  unicode: true,
);
final RegExp _trailingPunctuation = RegExp(r'[\p{P}\s]+$', unicode: true);
final RegExp _whitespace = RegExp(r'\s+');
final RegExp _sentenceEnd = RegExp(r'[?!.:]+$');
const Set<String> _trailingFillers = {
  'a',
  'an',
  'the',
  'for',
  'to',
  'of',
  'at',
  'in',
  'on',
  'with',
  'and',
  'or',
  'but',
  'about',
};

class WeftEventView {
  const WeftEventView({required this.eventId, this.threadRootId, this.body});

  final String eventId;
  final String? threadRootId;
  final String? body;
}

String? weftThreadRootOf(Event event, Timeline timeline) {
  if (event.relationshipType == RelationshipTypes.thread) {
    return event.relationshipEventId;
  }
  if (event.hasAggregatedEvents(timeline, RelationshipTypes.thread)) {
    return event.eventId;
  }
  return null;
}

int weftThreadSize(String rootId, Timeline timeline) =>
    1 +
    (timeline.aggregatedEvents[rootId]?[RelationshipTypes.thread]?.length ?? 0);

WeftStage weftStageFor(int size) {
  if (size < 2) return WeftStage.none;
  if (size == 2) return WeftStage.proto;
  return WeftStage.materialized;
}

String weftTitleFromBody(String body) {
  final words = body
      .split(_whitespace)
      .where((word) => word.isNotEmpty)
      .skipWhile((word) => _discourseStarters.contains(_bare(word)))
      .toList();
  final sentenceEnd = words.indexWhere(_sentenceEnd.hasMatch);
  final kept = words
      .take(
        sentenceEnd < 0 || sentenceEnd >= weftTitleWordCount
            ? weftTitleWordCount
            : sentenceEnd + 1,
      )
      .toList();
  while (kept.length > 1 && _trailingFillers.contains(_bare(kept.last))) {
    kept.removeLast();
  }
  final title = kept
      .map(_capitalize)
      .join(' ')
      .replaceAll(_trailingPunctuation, '');
  return title.isEmpty ? weftFallbackTitle : title;
}

String _bare(String word) =>
    word.replaceAll(_edgePunctuation, '').toLowerCase();

String _capitalize(String word) => word[0].toUpperCase() + word.substring(1);

String weftTitleFor(Event root) => weftTitleFromBody(_bodyOf(root));

String _bodyOf(Event event) {
  if (event.redacted) return '';
  return event.calcUnlocalizedBody(hideReply: true, plaintextBody: true);
}

List<WeftRowState> weftRowStatesFromViews(
  List<WeftEventView> views,
  Map<String, int> sizes,
) {
  final count = views.length;
  final stages = <String, WeftStage>{};
  WeftStage stageOf(String rootId) =>
      stages[rootId] ??= weftStageFor(sizes[rootId] ?? 0);

  final roots = List<String?>.filled(count, null);
  final oldest = <String, int>{};
  final newest = <String, int>{};
  for (var i = 0; i < count; i++) {
    final rootId = views[i].threadRootId;
    if (rootId == null || stageOf(rootId) == WeftStage.none) continue;
    roots[i] = rootId;
    newest.putIfAbsent(rootId, () => i);
    oldest[rootId] = i;
  }

  final result = List<WeftRowState>.filled(count, WeftRowState.empty);
  final laneLoad = List<int>.filled(weftMaxLanes, 0);
  final active = <String, int>{};
  for (var i = count - 1; i >= 0; i--) {
    final rootId = roots[i];
    if (rootId != null && oldest[rootId] == i) {
      final free = laneLoad.indexOf(0);
      final lane = free < 0 ? weftMaxLanes - 1 : free;
      laneLoad[lane]++;
      active[rootId] = lane;
    }
    if (active.isEmpty) continue;
    final lanes = [
      for (final entry in active.entries)
        WeftLane(
          index: entry.value,
          rootId: entry.key,
          stage: stageOf(entry.key),
          lineAbove: oldest[entry.key] != i,
          lineBelow: newest[entry.key] != i,
        ),
    ]..sort((a, b) => a.index.compareTo(b.index));
    if (rootId == null) {
      result[i] = WeftRowState(lanes: lanes);
      continue;
    }
    final stage = stageOf(rootId);
    final isRoot = views[i].eventId == rootId;
    result[i] = WeftRowState(
      lanes: lanes,
      dotLane: active[rootId],
      rootId: rootId,
      stage: stage,
      isRoot: isRoot,
      title: isRoot && stage == WeftStage.materialized
          ? weftTitleFromBody(views[i].body ?? '')
          : null,
    );
    if (newest[rootId] == i) {
      final released = active.remove(rootId);
      if (released != null) laneLoad[released]--;
    }
  }
  return result;
}

List<WeftThreadSummary> weftAliveThreadsFromViews(
  List<WeftEventView> views,
  Map<String, int> sizes, {
  int window = 30,
}) {
  final rootViews = {
    for (final view in views)
      if (view.threadRootId == view.eventId) view.eventId: view,
  };
  final seen = <String>{};
  final result = <WeftThreadSummary>[];
  for (final view in views.take(window)) {
    final rootId = view.threadRootId;
    if (rootId == null || !seen.add(rootId)) continue;
    final size = sizes[rootId] ?? 0;
    if (weftStageFor(size) != WeftStage.materialized) continue;
    result.add(
      WeftThreadSummary(
        rootId: rootId,
        title: weftTitleFromBody(rootViews[rootId]?.body ?? ''),
        size: size,
      ),
    );
  }
  return result;
}

List<WeftEventView> _viewsOf(
  List<Event> events,
  Timeline timeline,
  Map<String, int> sizes,
) => [for (final event in events) _viewOf(event, timeline, sizes)];

WeftEventView _viewOf(Event event, Timeline timeline, Map<String, int> sizes) {
  final rootId = weftThreadRootOf(event, timeline);
  if (rootId == null) return WeftEventView(eventId: event.eventId);
  final size = sizes.putIfAbsent(
    rootId,
    () => weftThreadSize(rootId, timeline),
  );
  final needsBody =
      rootId == event.eventId && weftStageFor(size) == WeftStage.materialized;
  return WeftEventView(
    eventId: event.eventId,
    threadRootId: rootId,
    body: needsBody ? _bodyOf(event.getDisplayEvent(timeline)) : null,
  );
}

List<WeftRowState> weftRowStates(List<Event> events, Timeline timeline) {
  final sizes = <String, int>{};
  return weftRowStatesFromViews(_viewsOf(events, timeline, sizes), sizes);
}

List<WeftThreadSummary> weftAliveThreads(
  List<Event> events,
  Timeline timeline, {
  int window = 30,
}) {
  final sizes = <String, int>{};
  return weftAliveThreadsFromViews(
    _viewsOf(events, timeline, sizes),
    sizes,
    window: window,
  );
}

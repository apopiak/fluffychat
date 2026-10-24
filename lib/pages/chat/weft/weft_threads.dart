// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';

import 'weft_types.dart';

const int weftMaxLanes = 4;
const int weftTitleWordCount = 5;
const int weftAliveWindow = 30;
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
  'also',
  'anyway',
  'quick',
  'question',
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

class WeftEventLink {
  const WeftEventLink({
    required this.eventId,
    this.threadRootId,
    this.replyToId,
  });

  final String eventId;
  final String? threadRootId;
  final String? replyToId;
}

class WeftThreadIndex {
  const WeftThreadIndex({
    required this.roots,
    required this.sizes,
    required this.explicitRoots,
  });

  static const empty = WeftThreadIndex(roots: {}, sizes: {}, explicitRoots: {});

  final Map<String, String> roots;
  final Map<String, int> sizes;
  final Set<String> explicitRoots;

  String? rootOf(String eventId) {
    final rootId = roots[eventId];
    if (rootId == null || (sizes[rootId] ?? 0) < 2) return null;
    return rootId;
  }

  bool isReplyChain(String rootId) =>
      !explicitRoots.contains(rootId) && (sizes[rootId] ?? 0) >= 2;
}

WeftThreadIndex weftThreadIndexFromLinks(List<WeftEventLink> links) {
  final byId = {for (final link in links) link.eventId: link};
  final explicitRoots = {for (final link in links) ?link.threadRootId};
  final roots = <String, String>{};

  String resolve(String eventId) {
    final chain = <String>[];
    var current = eventId;
    var rootId = current;
    while (true) {
      final cached = roots[current];
      if (cached != null) {
        rootId = cached;
        break;
      }
      final link = byId[current];
      final explicit = link?.threadRootId;
      final replyTo = link?.replyToId;
      if (link == null || explicitRoots.contains(current)) {
        rootId = current;
        break;
      }
      chain.add(current);
      if (explicit != null) {
        rootId = explicit;
        break;
      }
      if (replyTo == null || chain.contains(replyTo)) {
        rootId = current;
        break;
      }
      current = replyTo;
    }
    for (final id in chain) {
      roots[id] = rootId;
    }
    return rootId;
  }

  final sizes = <String, int>{};
  for (final link in links) {
    final rootId = resolve(link.eventId);
    roots[link.eventId] = rootId;
    sizes[rootId] = (sizes[rootId] ?? 0) + 1;
  }
  for (final rootId in sizes.keys.toList()) {
    if (!byId.containsKey(rootId)) sizes[rootId] = sizes[rootId]! + 1;
  }
  return WeftThreadIndex(
    roots: roots,
    sizes: sizes,
    explicitRoots: explicitRoots,
  );
}

WeftEventLink weftLinkOf(Event event) => WeftEventLink(
  eventId: event.eventId,
  threadRootId: event.relationshipType == RelationshipTypes.thread
      ? event.relationshipEventId
      : null,
  replyToId: event.inReplyToEventId(includingFallback: false),
);

WeftThreadIndex weftThreadIndex(Iterable<Event> events) =>
    weftThreadIndexFromLinks([for (final event in events) weftLinkOf(event)]);

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
  int window = weftAliveWindow,
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
  WeftThreadIndex index,
) => [
  for (final event in events)
    WeftEventView(
      eventId: event.eventId,
      threadRootId: index.rootOf(event.eventId),
      body:
          index.rootOf(event.eventId) == event.eventId &&
              weftStageFor(index.sizes[event.eventId] ?? 0) ==
                  WeftStage.materialized
          ? _bodyOf(event.getDisplayEvent(timeline))
          : null,
    ),
];

List<WeftRowState> weftRowStates(List<Event> events, Timeline timeline) {
  final index = weftThreadIndex(events);
  return weftRowStatesFromViews(_viewsOf(events, timeline, index), index.sizes);
}

List<WeftThreadSummary> weftAliveThreads(
  List<Event> events,
  Timeline timeline, {
  int window = weftAliveWindow,
}) {
  final index = weftThreadIndex(events);
  return weftAliveThreadsFromViews(
    _viewsOf(events, timeline, index),
    index.sizes,
    window: window,
  );
}

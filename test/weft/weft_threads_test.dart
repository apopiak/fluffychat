// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/pages/chat/weft/weft_threads.dart';
import 'package:fluffychat/pages/chat/weft/weft_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/models/timeline_chunk.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

WeftEventView view(String id, {String? root, String? body}) =>
    WeftEventView(eventId: id, threadRootId: root, body: body);

Map<String, int> sizesOf(Iterable<WeftEventView> views) {
  final sizes = <String, int>{};
  for (final v in views) {
    final root = v.threadRootId;
    if (root == null) continue;
    sizes[root] = (sizes[root] ?? 0) + 1;
  }
  return sizes;
}

List<WeftRowState> rowsOldestFirst(
  List<WeftEventView> oldestFirst, {
  Map<String, int>? sizes,
}) {
  final newestFirst = oldestFirst.reversed.toList();
  return weftRowStatesFromViews(
    newestFirst,
    sizes ?? sizesOf(newestFirst),
  ).reversed.toList();
}

void main() {
  group('weftStageFor', () {
    test('thresholds', () {
      expect(weftStageFor(0), WeftStage.none);
      expect(weftStageFor(1), WeftStage.none);
      expect(weftStageFor(2), WeftStage.proto);
      expect(weftStageFor(3), WeftStage.materialized);
      expect(weftStageFor(9), WeftStage.materialized);
    });
  });

  group('weftTitleFromBody', () {
    test('first words in title case', () {
      expect(
        weftTitleFromBody('shall we meet tomorrow at the usual place'),
        'Shall We Meet Tomorrow',
      );
    });

    test('strips discourse starters and trailing punctuation', () {
      expect(
        weftTitleFromBody('Hey, ok so are we meeting tomorrow?'),
        'Are We Meeting Tomorrow',
      );
      expect(weftTitleFromBody('btw dinner at 7?!'), 'Dinner At 7');
    });

    test('falls back to Thread', () {
      expect(weftTitleFromBody(''), 'Thread');
      expect(weftTitleFromBody('   '), 'Thread');
      expect(weftTitleFromBody('hey!'), 'Thread');
      expect(weftTitleFromBody('ok so well'), 'Thread');
      expect(weftTitleFromBody('...'), 'Thread');
    });

    test('stops at the first sentence and trims trailing fillers', () {
      expect(
        weftTitleFromBody('Dinner Friday? Thinking Thai 🍜'),
        'Dinner Friday',
      );
      expect(
        weftTitleFromBody('Anyone up for a run tomorrow morning?'),
        'Anyone Up For A Run',
      );
      expect(weftTitleFromBody('Who is up for the'), 'Who Is Up');
    });

    test('keeps starters that are not leading', () {
      expect(weftTitleFromBody('did you say so'), 'Did You Say So');
    });
  });

  group('weftRowStatesFromViews', () {
    final scenario = [
      view('A1', root: 'A1', body: 'hey are we shipping friday'),
      view('B1', root: 'A1'),
      view('C1', root: 'C1', body: 'lunch plans'),
      view('me1', root: 'A1'),
      view('B2'),
      view('me2', root: 'C1'),
      view('A2', root: 'A1'),
      view('A3'),
    ];

    test('interleaved teal and violet threads', () {
      final rows = rowsOldestFirst(scenario);
      expect(rows, hasLength(8));

      final a1 = rows.first;
      expect(a1.rootId, 'A1');
      expect(a1.isRoot, isTrue);
      expect(a1.stage, WeftStage.materialized);
      expect(a1.title, 'Are We Shipping Friday');
      expect(a1.dotLane, 0);
      expect(a1.lanes, hasLength(1));
      expect(a1.lanes.single.lineAbove, isFalse);
      expect(a1.lanes.single.lineBelow, isTrue);

      final b1 = rows[1];
      expect(b1.isRoot, isFalse);
      expect(b1.title, isNull);
      expect(b1.dotLane, 0);
      expect(b1.lanes.map((l) => l.index), [0]);
      expect(b1.lanes.single.lineAbove, isTrue);
      expect(b1.lanes.single.lineBelow, isTrue);

      final c1 = rows[2];
      expect(c1.rootId, 'C1');
      expect(c1.isRoot, isTrue);
      expect(c1.stage, WeftStage.proto);
      expect(c1.title, isNull);
      expect(c1.dotLane, 1);
      expect(c1.lanes.map((l) => l.index), [0, 1]);
      expect(c1.lanes.map((l) => l.stage), [
        WeftStage.materialized,
        WeftStage.proto,
      ]);
      expect(c1.lanes[1].lineAbove, isFalse);
      expect(c1.lanes[1].lineBelow, isTrue);
      expect(c1.lanes.first.lineAbove, isTrue);

      final me1 = rows[3];
      expect(me1.dotLane, 0);
      expect(me1.lanes.map((l) => l.index), [0, 1]);

      final b2 = rows[4];
      expect(b2.dotLane, isNull);
      expect(b2.rootId, isNull);
      expect(b2.stage, WeftStage.none);
      expect(b2.isRoot, isFalse);
      expect(b2.lanes.map((l) => l.index), [0, 1]);
      expect(b2.lanes.every((l) => l.lineAbove && l.lineBelow), isTrue);
      expect(b2.isEmpty, isFalse);

      final me2 = rows[5];
      expect(me2.dotLane, 1);
      expect(me2.rootId, 'C1');
      expect(me2.lanes.map((l) => l.index), [0, 1]);
      expect(me2.lanes[1].lineBelow, isFalse);
      expect(me2.lanes[1].lineAbove, isTrue);
      expect(me2.lanes.first.lineBelow, isTrue);

      final a2 = rows[6];
      expect(a2.dotLane, 0);
      expect(a2.lanes.map((l) => l.index), [0]);
      expect(a2.lanes.single.lineAbove, isTrue);
      expect(a2.lanes.single.lineBelow, isFalse);

      expect(rows[7], same(WeftRowState.empty));
    });

    test('lane freed after a thread ends is reused', () {
      final rows = rowsOldestFirst([
        view('A1', root: 'A1'),
        view('A2', root: 'A1'),
        view('x'),
        view('B1', root: 'B1'),
        view('B2', root: 'B1'),
      ]);
      expect(rows.first.dotLane, 0);
      expect(rows[1].dotLane, 0);
      expect(rows[1].lanes.single.lineBelow, isFalse);
      expect(rows[2], same(WeftRowState.empty));
      expect(rows[3].dotLane, 0);
      expect(rows[3].lanes.map((l) => l.index), [0]);
      expect(rows[4].dotLane, 0);
    });

    test('earlier lane is reused by later thread while another persists', () {
      final rows = rowsOldestFirst([
        view('A1', root: 'A1'),
        view('B1', root: 'B1'),
        view('A2', root: 'A1'),
        view('C1', root: 'C1'),
        view('B2', root: 'B1'),
        view('C2', root: 'C1'),
      ]);
      expect(rows.first.dotLane, 0);
      expect(rows[1].dotLane, 1);
      expect(rows[2].dotLane, 0);
      expect(rows[3].dotLane, 0);
      expect(rows[3].lanes.map((l) => l.index), [0, 1]);
      expect(rows[4].dotLane, 1);
      expect(rows[5].dotLane, 0);
      expect(rows[5].lanes.map((l) => l.index), [0]);
    });

    test('overflow: five overlapping threads share lane 3', () {
      final rows = rowsOldestFirst([
        view('T1', root: 'T1'),
        view('T2', root: 'T2'),
        view('T3', root: 'T3'),
        view('T4', root: 'T4'),
        view('T5', root: 'T5'),
        view('T1b', root: 'T1'),
        view('T2b', root: 'T2'),
        view('T3b', root: 'T3'),
        view('T4b', root: 'T4'),
        view('T5b', root: 'T5'),
      ]);
      expect(rows.take(5).map((r) => r.dotLane), [0, 1, 2, 3, 3]);
      expect(rows[4].lanes.map((l) => l.index), [0, 1, 2, 3, 3]);
      expect(rows[4].laneCount, 4);
      expect(rows.skip(5).map((r) => r.dotLane), [0, 1, 2, 3, 3]);
      expect(rows[9].lanes.map((l) => l.index), [3]);
      expect(rows[9].lanes.single.rootId, 'T5');
    });

    test('thread with unloaded root still gets lane, no title', () {
      final rows = rowsOldestFirst(
        [
          view('R1', root: 'ROOT'),
          view('R2', root: 'ROOT'),
          view('R3', root: 'ROOT'),
        ],
        sizes: {'ROOT': 4},
      );
      expect(rows.map((r) => r.dotLane), [0, 0, 0]);
      expect(rows.map((r) => r.isRoot), [false, false, false]);
      expect(rows.map((r) => r.title), [null, null, null]);
      expect(rows.map((r) => r.stage), everyElement(WeftStage.materialized));
      expect(rows.first.lanes.single.lineAbove, isFalse);
      expect(rows.last.lanes.single.lineBelow, isFalse);
    });

    test('would-be root without children and unrelated rows are empty', () {
      final rows = rowsOldestFirst(
        [view('lonely', root: 'lonely'), view('x')],
        sizes: {'lonely': 1},
      );
      expect(rows.first, same(WeftRowState.empty));
      expect(rows[1], same(WeftRowState.empty));
    });

    test('empty input', () {
      expect(weftRowStatesFromViews([], {}), isEmpty);
    });

    test('result is aligned with newest-first input', () {
      final newestFirst = [
        view('A2', root: 'A1'),
        view('x'),
        view('A1', root: 'A1'),
      ];
      final rows = weftRowStatesFromViews(newestFirst, {'A1': 2});
      expect(rows.first.lanes.single.lineBelow, isFalse);
      expect(rows.first.lanes.single.lineAbove, isTrue);
      expect(rows[1].dotLane, isNull);
      expect(rows[1].lanes, hasLength(1));
      expect(rows[2].isRoot, isTrue);
      expect(rows[2].lanes.single.lineAbove, isFalse);
      expect(rows[2].stage, WeftStage.proto);
    });
  });

  group('weftAliveThreadsFromViews', () {
    test('materialized only, newest activity first, within window', () {
      final newestFirst = [
        view('B3', root: 'B1'),
        view('A3', root: 'A1'),
        view('P2', root: 'P1'),
        view('B2', root: 'B1'),
        view('P1', root: 'P1', body: 'proto thing'),
        view('B1', root: 'B1', body: 'second topic here'),
        view('A2', root: 'A1'),
        view('A1', root: 'A1', body: 'okay first topic'),
        view('old3', root: 'O1'),
        view('old2', root: 'O1'),
        view('O1', root: 'O1', body: 'ancient'),
      ];
      final sizes = {'A1': 3, 'B1': 3, 'P1': 2, 'O1': 3};
      final alive = weftAliveThreadsFromViews(newestFirst, sizes, window: 8);
      expect(alive.map((t) => t.rootId), ['B1', 'A1']);
      expect(alive.map((t) => t.title), ['Second Topic Here', 'First Topic']);
      expect(alive.map((t) => t.size), [3, 3]);

      final wide = weftAliveThreadsFromViews(newestFirst, sizes);
      expect(wide.map((t) => t.rootId), ['B1', 'A1', 'O1']);
    });

    test('thread active in window but root outside gets fallback title', () {
      final alive = weftAliveThreadsFromViews(
        [view('c3', root: 'R'), view('c2', root: 'R'), view('x')],
        {'R': 3},
      );
      expect(alive.single.title, 'Thread');
      expect(alive.single.rootId, 'R');
    });
  });

  group('Event based', () {
    late Client client;
    late Room room;
    late Timeline timeline;

    Event event(
      String id, {
      String? root,
      String body = 'body',
      String sender = '@other:example.org',
    }) => Event(
      content: {
        'msgtype': 'm.text',
        'body': body,
        if (root != null)
          'm.relates_to': {'rel_type': 'm.thread', 'event_id': root},
      },
      type: EventTypes.Message,
      eventId: id,
      senderId: sender,
      originServerTs: DateTime(2026, 10, 23),
      room: room,
    );

    setUp(() async {
      sqfliteFfiInit();
      client = Client(
        'weft test',
        httpClient: FakeMatrixApi(),
        database: await MatrixSdkDatabase.init(
          'weft-test',
          database: await databaseFactoryFfi.openDatabase(':memory:'),
          sqfliteFactory: databaseFactoryFfi,
        ),
      );
      room = Room(id: '!weft:example.org', client: client);
    });

    Timeline timelineOf(List<Event> newestFirst) {
      timeline = Timeline(
        room: room,
        chunk: TimelineChunk(events: newestFirst),
      );
      return timeline;
    }

    tearDown(() async {
      timeline.cancelSubscriptions();
      await client.dispose(closeDatabase: true);
    });

    test('root detection, size and stage', () {
      final a1 = event('A1', body: 'hey are we shipping friday');
      final b1 = event('B1', root: 'A1');
      final c = event('C', root: 'A1');
      final plain = event('P');
      final t = timelineOf([c, plain, b1, a1]);

      expect(weftThreadRootOf(a1, t), 'A1');
      expect(weftThreadRootOf(b1, t), 'A1');
      expect(weftThreadRootOf(c, t), 'A1');
      expect(weftThreadRootOf(plain, t), isNull);
      expect(weftThreadSize('A1', t), 3);
      expect(weftThreadSize('P', t), 1);
      expect(weftStageFor(weftThreadSize('A1', t)), WeftStage.materialized);
      expect(weftTitleFor(a1), 'Are We Shipping Friday');
    });

    test('row states and alive threads from real events', () {
      final oldestFirst = [
        event('A1', body: 'so are we shipping friday?'),
        event('B1', root: 'A1'),
        event('C1', body: 'lunch'),
        event('me1', root: 'A1', sender: '@me:example.org'),
        event('C2', root: 'C1'),
        event('B2'),
        event('A2', root: 'A1'),
      ];
      final newestFirst = oldestFirst.reversed.toList();
      final t = timelineOf(newestFirst);

      final rows = weftRowStates(newestFirst, t).reversed.toList();
      expect(rows.first.title, 'Are We Shipping Friday');
      expect(rows.first.dotLane, 0);
      expect(rows[2].rootId, 'C1');
      expect(rows[2].stage, WeftStage.proto);
      expect(rows[2].dotLane, 1);
      expect(rows[2].lanes.map((l) => l.index), [0, 1]);
      expect(rows[4].dotLane, 1);
      expect(rows[5].dotLane, isNull);
      expect(rows[5].lanes.map((l) => l.index), [0]);
      expect(rows[6].dotLane, 0);
      expect(rows[6].lanes.single.lineBelow, isFalse);

      final alive = weftAliveThreads(newestFirst, t);
      expect(alive, hasLength(1));
      expect(alive.single.rootId, 'A1');
      expect(alive.single.title, 'Are We Shipping Friday');
      expect(alive.single.size, 4);
    });
  });
}

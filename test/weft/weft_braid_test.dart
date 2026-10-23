// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/pages/chat/weft/weft_braid.dart';
import 'package:fluffychat/pages/chat/weft/weft_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const rowHeight = 60.0;

  Future<Size> pumpBraid(
    WidgetTester tester,
    WeftRowState state, {
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              height: rowHeight,
              child: Align(
                alignment: Alignment.topLeft,
                child: WeftBraid(state: state),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    return tester.getSize(find.byType(WeftBraid));
  }

  test('braid width', () {
    expect(weftBraidWidth(0), 0);
    expect(weftBraidWidth(1), 17);
    expect(weftBraidWidth(2), 26);
    expect(weftBraidWidth(4), 44);
  });

  testWidgets('empty state takes no space', (tester) async {
    final size = await pumpBraid(tester, WeftRowState.empty);
    expect(size.width, 0);
    expect(
      find.descendant(
        of: find.byType(WeftBraid),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });

  testWidgets('single materialized lane with dot', (tester) async {
    const state = WeftRowState(
      lanes: [
        WeftLane(index: 0, rootId: r'$teal', stage: WeftStage.materialized),
      ],
      dotLane: 0,
      rootId: r'$teal',
      stage: WeftStage.materialized,
      isRoot: true,
      title: 'Teal',
    );
    final size = await pumpBraid(tester, state);
    expect(size, const Size(17, rowHeight));
  });

  testWidgets('proto lane with ring in dark mode', (tester) async {
    const state = WeftRowState(
      lanes: [
        WeftLane(
          index: 0,
          rootId: r'$violet',
          stage: WeftStage.proto,
          lineAbove: false,
        ),
      ],
      dotLane: 0,
      rootId: r'$violet',
      stage: WeftStage.proto,
    );
    final size = await pumpBraid(tester, state, brightness: Brightness.dark);
    expect(size, const Size(17, rowHeight));
  });

  testWidgets('two lanes, one passing through without a dot', (tester) async {
    const state = WeftRowState(
      lanes: [
        WeftLane(index: 0, rootId: r'$teal', stage: WeftStage.materialized),
        WeftLane(
          index: 1,
          rootId: r'$violet',
          stage: WeftStage.proto,
          lineBelow: false,
        ),
      ],
      dotLane: 1,
      rootId: r'$violet',
      stage: WeftStage.proto,
    );
    final size = await pumpBraid(tester, state);
    expect(size, const Size(26, rowHeight));
  });

  testWidgets('repaints only when the row state changes', (tester) async {
    const lane = WeftLane(
      index: 0,
      rootId: r'$teal',
      stage: WeftStage.materialized,
    );
    await pumpBraid(
      tester,
      const WeftRowState(lanes: [lane], dotLane: 0, rootId: r'$teal'),
    );
    final first = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(WeftBraid),
        matching: find.byType(CustomPaint),
      ),
    );
    await pumpBraid(
      tester,
      const WeftRowState(lanes: [lane], dotLane: 0, rootId: r'$teal'),
    );
    final same = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(WeftBraid),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(same.painter!.shouldRepaint(first.painter!), isFalse);
    await pumpBraid(tester, const WeftRowState(lanes: [lane]));
    final changed = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(WeftBraid),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(changed.painter!.shouldRepaint(first.painter!), isTrue);
  });
}

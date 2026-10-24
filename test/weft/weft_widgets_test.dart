// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/pages/chat/weft/weft_chip_row.dart';
import 'package:fluffychat/pages/chat/weft/weft_colors.dart';
import 'package:fluffychat/pages/chat/weft/weft_mode_toggle.dart';
import 'package:fluffychat/pages/chat/weft/weft_title_pill.dart';
import 'package:fluffychat/pages/chat/weft/weft_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('fnv-1a hash matches the reference values', () {
    expect(weftHash(''), 0x811c9dc5);
    expect(weftHash('a'), 0xe40c292c);
    expect(weftHash('foobar'), 0xbf9cf968);
  });

  test('weft colours are stable and theme dependent', () {
    const rootId = r'$abc:example.org';
    expect(
      weftColor(rootId, Brightness.light),
      weftColor(rootId, Brightness.light),
    );
    expect(
      weftColor(rootId, Brightness.light),
      isNot(weftColor(rootId, Brightness.dark)),
    );
    final indices = {
      for (var i = 0; i < 200; i++) weftPaletteIndex('\$event$i:example.org'),
    };
    expect(indices.length, weftPalette.length);
  });

  test('on colour picks the higher contrast', () {
    expect(weftOnColor(const Color(0xFF202020)), const Color(0xFFFFFFFF));
    expect(weftOnColor(const Color(0xFFF0E060)), const Color(0xFF1B1B1F));
  });

  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(appBar: AppBar(actions: [child])),
  );

  testWidgets('mode toggle fits the app bar', (tester) async {
    bool? changed;
    await tester.pumpWidget(
      wrap(
        WeftModeToggle(
          weft: false,
          onChanged: (value) => changed = value,
          threadsLabel: 'Threads',
          weftLabel: 'Weft',
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(SegmentedButton<bool>)).height,
      lessThanOrEqualTo(36),
    );
    await tester.tap(find.text('Weft'));
    expect(changed, isTrue);
  });

  testWidgets('chip row selects and deselects threads', (tester) async {
    final selections = <String?>[];
    Future<void> pump(String? selected) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(WeftChipRow.fixedHeight),
              child: WeftChipRow(
                threads: const [
                  WeftThreadSummary(rootId: r'$a', title: 'Lunch', size: 3),
                  WeftThreadSummary(rootId: r'$b', title: 'Deploy', size: 4),
                ],
                selectedRootId: selected,
                onSelected: selections.add,
                allLabel: 'All',
              ),
            ),
          ),
        ),
      ),
    );
    await pump(null);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Lunch'));
    await pump(r'$a');
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Lunch'));
    await tester.tap(find.text('All'));
    expect(selections, [r'$a', null, null]);
  });

  testWidgets('title pill renders and taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WeftTitlePill(
                rootId: r'$a',
                title: 'A rather long thread title that should be ellipsized',
                onTap: () => taps++,
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(WeftTitlePill)).height, 20);
    await tester.tap(find.byType(WeftTitlePill));
    expect(taps, 1);
  });

  group('weftAssignColorIndices', () {
    test('keeps the hashed colour when free', () {
      final indices = weftAssignColorIndices(['root-a']);
      expect(indices['root-a'], weftPaletteIndex('root-a'));
    });

    test('moves a colliding thread to a distant free colour', () {
      const first = 'root-a';
      final target = weftPaletteIndex(first);
      final second = [
        for (var i = 0; i < 2000; i++) 'root-$i',
      ].firstWhere((id) => id != first && weftPaletteIndex(id) == target);
      final indices = weftAssignColorIndices([first, second, first]);
      expect(indices[first], target);
      expect(
        indices[second],
        (target + weftColorProbeStep) % weftPalette.length,
      );
      expect(indices.length, 2);
    });

    test('never repeats a colour while the palette has room', () {
      final ids = [for (var i = 0; i < 12; i++) '!thread$i:example.org'];
      final indices = weftAssignColorIndices(ids);
      expect(indices.values.toSet().length, 12);
    });
  });
}

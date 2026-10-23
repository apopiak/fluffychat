// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

const weftPalette = <Color>[
  Color(0xFFE05565),
  Color(0xFFD94E8A),
  Color(0xFFA855C4),
  Color(0xFF7C5FD4),
  Color(0xFF5470E0),
  Color(0xFF3B9DD4),
  Color(0xFF28A5A0),
  Color(0xFF2DB07A),
  Color(0xFF50B855),
  Color(0xFF8FB83D),
  Color(0xFFC4A822),
  Color(0xFFC47830),
];

int weftHash(String input) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(input)) {
    hash = (hash ^ byte) & 0xFFFFFFFF;
    hash = ((hash << 24) + hash * 403) & 0xFFFFFFFF;
  }
  return hash;
}

int weftPaletteIndex(String rootId) => weftHash(rootId) % weftPalette.length;

Color weftColor(String rootId, Brightness brightness) =>
    weftColorAt(weftPaletteIndex(rootId), brightness);

Color weftColorAt(int index, Brightness brightness) {
  final hsl = HSLColor.fromColor(weftPalette[index % weftPalette.length]);
  if (brightness == Brightness.dark) {
    return hsl
        .withSaturation((hsl.saturation + 0.08).clamp(0.0, 1.0))
        .withLightness((hsl.lightness * 1.1 + 0.04).clamp(0.6, 0.72))
        .toColor();
  }
  return hsl.withLightness((hsl.lightness * 0.9).clamp(0.38, 0.5)).toColor();
}

const _weftOnDark = Color(0xFF1B1B1F);
const _weftOnLight = Color(0xFFFFFFFF);

Color weftOnColor(Color color) {
  final luminance = color.computeLuminance();
  final darkLuminance = _weftOnDark.computeLuminance();
  final contrastWithLight = 1.05 / (luminance + 0.05);
  final contrastWithDark = (luminance + 0.05) / (darkLuminance + 0.05);
  return contrastWithDark > contrastWithLight ? _weftOnDark : _weftOnLight;
}

const weftColorProbeStep = 5;

Map<String, int> weftAssignColorIndices(Iterable<String> rootIdsOldestFirst) {
  final indices = <String, int>{};
  final used = <int>{};
  for (final rootId in rootIdsOldestFirst) {
    if (indices.containsKey(rootId)) continue;
    var index = weftPaletteIndex(rootId);
    for (
      var probe = 0;
      probe < weftPalette.length && used.contains(index);
      probe++
    ) {
      index = (index + weftColorProbeStep) % weftPalette.length;
    }
    used.add(index);
    indices[rootId] = index;
  }
  return indices;
}

class WeftColorScope extends InheritedWidget {
  const WeftColorScope({
    required this.indices,
    required super.child,
    super.key,
  });

  final Map<String, int> indices;

  static Map<String, int> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WeftColorScope>()?.indices ??
      const {};

  @override
  bool updateShouldNotify(WeftColorScope oldWidget) =>
      !mapEquals(oldWidget.indices, indices);
}

Color weftColorFor(BuildContext context, String rootId) => weftColorAt(
  WeftColorScope.of(context)[rootId] ?? weftPaletteIndex(rootId),
  Theme.of(context).brightness,
);

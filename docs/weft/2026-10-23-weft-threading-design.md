# Weft threading view for FluffyChat — design

Date: 2026-10-23. Context: Matrix hackathon. Author: Alexander Popiak with Claude.
Origin: the Weft prototype at https://github.com/apopiak/threaded-voices (Flutter + Supabase, Feb 2026), re-thought for Matrix inside FluffyChat.

## Intent

Threading in personal messaging usually fails: chat is mostly synchronous, nobody wants to decide "thread or not?" per message, and threads only work if everyone uses them. Weft's answer is that threading stays invisible until a conversation actually splits, and then shows itself additively, without moving anything.

FluffyChat today hides threaded replies from the room timeline and shows a "N replies" button under the root; the thread itself lives on a separate screen. That is Slack-style threading. This fork adds a second mode, **Weft**, where every message stays inline in its real order and threads are made visible by colour: a **braid** of lanes at the left edge of the timeline, one lane per live thread, with a dot on the lane for each message in that thread.

Everything rides on standard `m.thread` relations (MSC3440) that FluffyChat already sends, so the view works in any room, with any other client in the mix, and needs no protocol change.

## Goals

1. A per-room **Threads / Weft** toggle in the chat app bar. Threads mode is FluffyChat unchanged. Weft mode is the new view.
2. In Weft mode, threaded replies are **inline** in timeline order.
3. The **braid**: a lane column at the left edge; one lane per live thread; a dot per message on its thread's lane; own messages keep their bubble on the right but their dot on the left (the lane is about the thread, not the sender).
4. **Three stages**, additive only:
   - standalone message: no lane, no dot;
   - proto-thread (2 messages incl. root): dashed lane, hollow rings, nothing else;
   - materialized thread (3+ messages): solid lane, filled dots, a **title pill** above the root, and a **chip** in a chip row under the app bar.
5. **Chip filter**: tapping a chip shows only that thread; "All" (or tapping again) returns to the full timeline. This is the one allowed layout change.
6. Stable, theme-aware **thread colours**: hash of the thread root event ID into a 12-hue palette, adjusted for light and dark.
7. Looks good. Prettier than the prototype, not a copy of it.

## Non-goals (hackathon)

- Voice notes with transcript-as-edit (the Weft "send early, refine after" flow). Stretch only, after everything above works.
- Auto-thread suggestions, thread titles from an LLM, "move to thread", quote-preview weight heuristic.
- Per-thread unread state or notifications.
- Upstreaming. A fork is fine; keep the diff surgical anyway.

## Anti-goals

- Anything that moves or removes a message when a thread changes stage. Visual changes are additive; the chip filter is the only exception.
- A new timeline implementation. Hook into the existing `ChatEventList` / `Message` widgets.
- Nested threads. A reply to a reply inherits the root (Matrix `m.thread` already does this).

## Constraints

- FluffyChat `main` @ bf18e3b, Flutter 3.47.7 via fvm (`.fvm/flutter_sdk/bin/flutter`), Dart ≥ 3.11, `matrix` SDK 14.1.0, AGPL-3.0.
- Repo style: no comments, no `else`, `dart format`, `flutter analyze`, dart_code_linter (`avoid-returning-widgets`: helpers are widget classes, not methods). New files need the SPDX header used by the existing files (REUSE). User-visible strings go through `lib/l10n/intl_en.arb`.
- `lib/pages/chat/chat.dart` (controller, ~1750 lines) and `lib/pages/chat/events/message.dart` (~1030 lines) are large; edit surgically, add new widgets in new files under `lib/pages/chat/weft/`.
- This Mac has no Xcode and no Android SDK, so the first build target is **web** (`flutter run -d chrome` after `scripts/prepare-web.sh`), with macOS once Xcode is installed.

## How it is built (decided)

The shared contract between the pieces is `lib/pages/chat/weft/weft_types.dart` (already written): `WeftStage`, `WeftLane`, `WeftRowState`, `WeftThreadSummary`.

### Mode and settings

- `AppSettings.weftThreads<bool>` in `lib/config/setting_keys.dart` (default false) holds the global default; the chat controller holds a per-room `weftMode` so the app-bar toggle is instant. The builder decides whether the per-room value persists.
- The toggle is a two-segment control in the chat `AppBar` actions: **Threads | Weft**. In Weft mode the "N replies" button under roots is hidden and the timeline never enters FluffyChat's thread screen from a tap on a root.

### Inline filter

- `filterByVisibleInGui` in `lib/utils/matrix_sdk_extensions/filtered_timeline_extension.dart` currently drops every event whose relation is `m.thread` in the main timeline. In Weft mode, keep them. With a chip filter active (`weftThreadFilter == rootId`), keep only the root and events whose thread root is `rootId`, plus reactions/edits as today.

### Thread model (`lib/pages/chat/weft/weft_threads.dart`)

Pure Dart over the SDK's `Event`/`Timeline`, unit-tested:

- `threadRootOf(event, timeline)`: `relationshipEventId` when `relationshipType == m.thread`; `eventId` when the event has aggregated `m.thread` children; else null.
- `threadSize(rootId)`: 1 + number of aggregated `m.thread` children in the timeline (local timeline only; good enough for a hackathon).
- `stage(size)`: `none` (<2), `proto` (2), `materialized` (≥3).
- `title(root)`: the root's body with leading discourse starters stripped ("so", "hey", "ok", "btw"), cut at the first sentence end, at most 5 words, trailing filler words ("a", "the", "for", …) dropped, Title Case; fallback "Thread". Derived, never sent.
- **Lane assignment**: over the visible events list (newest first, as `ChatEventList` holds it; assign oldest→newest, then map back). A thread occupies a lane from its oldest visible message to its newest; lowest free lane wins; at most 4 lanes, further threads share lane 3.
- `rowStates(events, timeline)` → `List<WeftRowState>` aligned with `events`: for each row, which lanes carry a line through it, which start or end here, where the dot sits, the stage, and the title for a materialized root.
- **Alive threads** for the chip row: materialized threads with a message among the newest 30 visible events, as `List<WeftThreadSummary>`.

### Colours (`lib/pages/chat/weft/weft_colors.dart`)

Each thread's preferred colour is a stable FNV-1a hash of the root event ID into 12 hues (Weft palette: rose, magenta, purple, violet, indigo, sky, teal, emerald, green, lime, gold, copper), with lightness tuned per brightness. Not `String.hashCode` (not stable across platforms).

Built in: with 12 colours, two visible threads collide often (the seeded test room hit it immediately). `weftAssignColorIndices` walks the visible threads oldest first and moves a thread whose preferred colour is taken forward in steps of 5 slots (coprime with 12, so it visits every colour and jumps across the hue wheel rather than to the neighbouring hue). The result is published through a `WeftColorScope` inherited widget over the chat page, so braid, title pills and chips agree. Colours are therefore stable per device for a given set of loaded threads, and identical across devices whenever there is no collision.

### Painter and widgets (`lib/pages/chat/weft/`)

- `WeftBraid`: a `CustomPaint` at the left of each `Message` row (built in: the gutter is one width for the whole visible timeline, published by a `WeftGutter` inherited widget, so avatars and bubbles don't jitter between rows with different lane counts), full row height including vertical padding so lines join across rows. Draws pass-through lines, start/end stubs that stop at the dot, the dot (filled for materialized, ring for proto), dashed lines for proto. Width = `8 + 9 * laneCount` logical px; a row with no lanes costs nothing.
- `WeftTitlePill`: small rounded label in the thread colour, above the root's bubble when materialized.
- `WeftChipRow`: horizontally scrolling `FilterChip`s ("All" + one per alive materialized thread, colour dot + title), in `ChatView`'s `AppBar.bottom` next to `PinnedEvents`; adjust `appbarBottomHeight`.
- `WeftModeToggle`: the segmented control for the app bar.

### Hooks into existing code (surgical)

- `chat_event_list.dart`: compute `rowStates` once per build from `events` and pass each row its `WeftRowState`.
- `message.dart`: accept an optional `WeftRowState`; when present, draw `WeftBraid` at the left and `WeftTitlePill` above the bubble for roots; hide the thread-summary button.
- `chat.dart`: `weftMode`, `weftThreadFilter`, setters that call `setState`; pass through to the view and to the timeline filter.
- `chat_view.dart`: toggle in `AppBar.actions`, chip row in `AppBar.bottom`.

### Tests

- Unit tests for `weft_threads.dart` with a fake timeline: root detection, stage thresholds, lane assignment on an interleaved scenario (teal 3 messages, violet 2, standalone in between), colour stability.
- A widget smoke test that `WeftBraid` paints without throwing for each `WeftRowState` shape.

## Built in beyond the first draft

- Sending while a chip filter is active sends into that thread: the controller's `sendThreadRootId` is the open FluffyChat thread, else the Weft filter, and all send paths (text, files, stickers, voice) use it.
- Lanes continue through date separators, state events and the read marker.
- Tapping a title pill toggles the chip filter for that thread.

## Left to the builder

- Exact pixel values, dash pattern, dot radius; keep lines ~2px at ~55% opacity, dots ~8px.
- Whether the per-room mode persists across restarts.
- Where the "All" chip sits when the row scrolls.
- Behaviour when the thread root is not loaded in the timeline: colour the children, no title.

## Stretch (only after the above is done and built)

- Voice note transcript: on send, run `speech_to_text` on the recording and send an `m.replace` whose `m.new_content` copies the full audio content and adds `body` = transcript plus `io.weft.transcript: true`; render transcript as the audio caption; suppress the "edited" marker when the flag is present.

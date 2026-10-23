<!--
SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Weft local dev rig (macOS, no Docker, no Xcode)

How the Weft branch was built, tested and clicked through on a Mac with only the Command Line Tools.

## Flutter

```sh
brew install fvm yq cmake
fvm install            # Flutter 3.47.7 from .fvmrc, lands in .fvm/flutter_sdk
export PATH="$PWD/.fvm/flutter_sdk/bin:$PATH"
```

`flutter test` needs full Xcode because the webcrypto native-asset hook calls `xcodebuild`. Without Xcode, put the shim first on PATH:

```sh
mkdir -p /tmp/weft-bin && cp docs/weft/dev/xcodebuild-shim /tmp/weft-bin/xcodebuild
PATH="/tmp/weft-bin:$PATH" flutter test
```

The chat-list golden test fails on macOS on clean `main` too (about 1.3 % and 1.7 % pixel diff), so ignore it locally.

## Web build without the Rust/wasm toolchain

`scripts/prepare-web.sh` builds vodozemac to wasm. The prebuilt files from FluffyChat's nightly deployment work instead (version from `pubspec.lock`):

```sh
V=0.8.1
curl -sSLo assets/vodozemac/$V/vodozemac_bindings_dart.js https://fluffychat.im/nightly/assets/assets/vodozemac/$V/vodozemac_bindings_dart.js
curl -sSLo assets/vodozemac/$V/vodozemac_bindings_dart_bg.wasm https://fluffychat.im/nightly/assets/assets/vodozemac/$V/vodozemac_bindings_dart_bg.wasm
curl -sSLo web/e2ee.worker.dart.js https://fluffychat.im/nightly/e2ee.worker.dart.js
curl -sSLo /tmp/native_imaging.zip https://github.com/famedly/dart_native_imaging/releases/download/v1.0.0/native_imaging.zip
unzip -o /tmp/native_imaging.zip -d /tmp/ni && cp /tmp/ni/js/* web/
dart compile js ./web/native_executor.dart -o ./web/native_executor.js -m
flutter build web --profile
```

All of these paths are git-ignored.

## Test homeserver with threads

```sh
SYN=$(nix build nixpkgs#matrix-synapse --no-link --print-out-paths | head -1)/bin/synapse_homeserver
mkdir -p /tmp/weft-synapse && "$SYN" --server-name localhost --config-path /tmp/weft-synapse/homeserver.yaml \
  --generate-config --report-stats=no --data-directory /tmp/weft-synapse
printf '\nenable_registration: true\nenable_registration_without_verification: true\n' >> /tmp/weft-synapse/homeserver.yaml
"$SYN" --config-path /tmp/weft-synapse/homeserver.yaml &
python3 -I docs/weft/dev/seed_threads.py http://localhost:8008
```

Note the leading newline in the `printf`: the generated config ends without one.

The seed script creates alice, bob, carol and dave (password `weft-test-pw`) and a room "Hackathon crew" with a 4-message thread, a 2-message thread, a 4-message thread and standalone messages in between.

## Run it

```sh
printf '{"defaultHomeserver":"http://localhost:8008","presetHomeserver":"http://localhost:8008"}' > build/web/config.json
python3 -m http.server 8093 --directory build/web --bind 127.0.0.1
```

Open http://localhost:8093, press "Sign in", log in as `dave`, open the room, flip the app-bar toggle to Weft.

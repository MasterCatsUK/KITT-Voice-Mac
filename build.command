#!/bin/zsh
set -eu
cd "$(dirname "$0")"
mkdir -p 'KITT Voice.app/Contents/MacOS' 'KITT Voice.app/Contents/Resources' "${TMPDIR:-/tmp}/KITTVoice-SwiftCache"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 \
  -module-cache-path "${TMPDIR:-/tmp}/KITTVoice-SwiftCache" \
  Source/ConversationTurn.swift Source/Audio.swift Source/LocalAI.swift Source/Voices.swift Source/Controller.swift Source/Interface.swift Source/main.swift \
  -o 'KITT Voice.app/Contents/MacOS/KITTVoice'
cp Info.plist 'KITT Voice.app/Contents/Info.plist'
if [ -f AppIcon.icns ]; then cp AppIcon.icns 'KITT Voice.app/Contents/Resources/'; fi
codesign --force --sign - 'KITT Voice.app'
echo 'Built KITT Voice.app. Double-click it to open.'

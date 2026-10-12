#!/bin/sh
# Runs the unit tests. With only the Command Line Tools installed, Swift Testing lives outside the
# default search paths, and SwiftPM's generated test runner must also see it (otherwise it silently
# runs zero tests), so the flags have to be global rather than per-target.
set -eu
cd "$(dirname "$0")/.."

DEV="$(xcode-select -p)"
if [ -d "$DEV/Library/Developer/Frameworks/Testing.framework" ]; then
    FRAMEWORKS="$DEV/Library/Developer/Frameworks"
    LIBS="$DEV/Library/Developer/usr/lib"
    exec swift test \
        -Xswiftc -F -Xswiftc "$FRAMEWORKS" \
        -Xlinker -rpath -Xlinker "$FRAMEWORKS" \
        -Xlinker -rpath -Xlinker "$LIBS" \
        "$@"
fi
exec swift test "$@"

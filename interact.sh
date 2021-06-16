export TOOLCHAINS="Swift Development Snapshot"
DYLD_LIBRARY_PATH=$(dirname $(xcrun --find swift))/../lib/swift/macosx swift build -v && DYLD_LIBRARY_PATH=$(dirname $(xcrun --find swift))/../lib/swift/macosx ./.build/debug/shitheaden

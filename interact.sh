export TOOLCHAINS="Swift Development Snapshot"
DYLD_LIBRARY_PATH=$(dirname $(xcrun --find swift))/../lib/swift/macosx swift build -v -c release && DYLD_LIBRARY_PATH=$(dirname $(xcrun --find swift))/../lib/swift/macosx ./.build/release/ShitheadenCLI

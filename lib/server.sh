export TOOLCHAINS="Swift Development Snapshot"
export DYLD_LIBRARY_PATH=$(dirname $(xcrun --find swift))/../lib/swift/macosx

# swift build -v -c release && ./.build/release/shitheaden --server
swift build -v --product ShitheadenServer && ./.build/debug/ShitheadenServer

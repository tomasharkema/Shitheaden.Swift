export TOOLCHAINS="Swift Development Snapshot"
export DYLD_LIBRARY_PATH=$(dirname $(xcrun --find swift))/../lib/swift/macosx

# swift build -v -c release && ./.build/release/shitheaden --server
swift build --product ShitheadenServer -Xswiftc -g && ./.build/debug/ShitheadenServer 

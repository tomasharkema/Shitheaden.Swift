export TOOLCHAINS="Swift Development Snapshot"
export DYLD_LIBRARY_PATH=$(dirname $(xcrun --find swift))/../lib/swift/macosx

swift test -v -Xswiftc -g

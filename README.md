# godot-builds

Build the pinned Godot source from the repository root:

```bash
./scripts/build-linux.sh
./scripts/build-windows.sh
./scripts/build-macos.sh
```

Linux and Windows builds can run in a Linux container with the appropriate
toolchain available on `PATH`. The macOS script runs natively with Xcode command
line tools. Additional arguments are forwarded to every SCons invocation.

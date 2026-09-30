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

The build name defaults to `custom`. Pass `--status` to override the version
status from the Godot source:

```bash
./scripts/build-linux.sh --build-name sentry --status sentry.0
```

By default, each script builds the editor and both export templates. Pass
`--target` one or more times to build only the targets needed:

```bash
./scripts/build-linux.sh --target editor
./scripts/build-linux.sh --target template_debug --target template_release
```

The available targets are `editor`, `template_debug`, and `template_release`.

Successful builds move their binaries and debug symbols out of `godot/bin` and
into `artifacts/<version>/<platform>/<target>/<architecture>/`. This layout lets
CI jobs build targets independently and merge their artifacts afterward.

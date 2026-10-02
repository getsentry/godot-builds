# godot-builds

Build the pinned Godot source from the repository root:

```bash
./scripts/build-linux.sh
./scripts/build-windows.sh
./scripts/build-macos.sh
```

Additional arguments are forwarded to every SCons invocation.

The build name defaults to `custom`. Pass `--build-name` to identify the build
in the engine's full version string:

```bash
./scripts/build-linux.sh --build-name sentry.1
```

By default, each script builds the editor and both export templates. Pass
`--target` one or more times to build only the targets needed:

```bash
./scripts/build-linux.sh --target editor
./scripts/build-linux.sh --target template_debug --target template_release
```

The available targets are `editor`, `template_debug`, and `template_release`.

Successful builds place binaries, debug symbols, and source bundles into
`artifacts/<version>/<platform>/<target>/<architecture>/`. This layout lets CI
jobs build targets independently and merge their artifacts afterward.

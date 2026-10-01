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

Package the staged artifacts from the repository root:

```bash
./scripts/package-linux.sh
./scripts/package-windows.sh
./scripts/package-macos.sh
```

Package names include the pinned Godot tag and build name, such as
`Godot_v4.5.2-stable_sentry.1_editor.macos.universal.zip`. The build name
defaults to `custom`; pass the same name used for the build:

```bash
./scripts/package-linux.sh --build-name sentry.1
```

Each platform produces an editor archive and its template archives under
`packages/<version>/`. Every archive has a matching `.debug-symbols.zip` archive
containing its debug files and source bundles.

To build the Linux container locally:

```bash
docker build --platform linux/amd64 --file containers/Dockerfile.linux --tag godot-build-linux:latest containers
```

Use the [build-containers.yml](.github/workflows/build-containers.yml) workflow to
publish the Linux toolchain image to
`ghcr.io/<owner>/godot-builds-linux`. Use the `main` ref when dispatching
the workflow to also update the `4.5-latest` tag.

Use the [build.yml](.github/workflows/build.yml) workflow to build and package
all desktop targets. Supply `status` and optionally choose a published
`container_tag` for Linux. The workflow produces binary and debug-symbol
packages as artifacts for each platform.

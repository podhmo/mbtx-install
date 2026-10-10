# mbtx-install

tiny install command for one .mbtx file

`mbtx-install` builds a single-file MoonBit script (`.mbtx`) into a native
binary and installs it as a command — the `deno install -g script.ts`
experience for MoonBit scripts.

## Install

Requires the `moon` toolchain on `PATH`.

From a checkout of this repository:

```console
$ moon install ./cmd/mbtx-install
```

Directly from git:

```console
$ moon install https://github.com/podhmo/mbtx-install cmd/mbtx-install
```

Once the module is published on [mooncakes](https://mooncakes.io), the
registry form works too:

```console
$ moon install podhmo/mbtx-install/cmd/mbtx-install
```

## Usage

```console
$ mbtx-install <path.mbtx> [-o|--name <cmd>] [--bin <dir>] [--release] [-v|--verbose]
$ mbtx-install --list
hello -> /home/u/tools/hello.mbtx
```

```console
$ mbtx-install tools/mygrep.mbtx
Installed 'mygrep' to '/home/u/.moon/bin/mygrep'
$ mygrep -n TODO src/*.mbt
```

| option | effect |
|---|---|
| `-o`, `--name <cmd>` | installed command name (default: file basename without `.mbtx`) |
| `--bin <dir>` | install directory (default: `~/.moon/bin`) |
| `--release` | build the release profile (default: debug build) |
| `-v`, `--verbose` | show moon's build logs (default: quiet, errors still shown) |
| `--list` | list installed commands recorded in the manifest (takes no path) |

## How it works

Route A of [docs/ja/design.md](docs/ja/design.md) (Japanese):

1. The `.mbtx` path is resolved to a per-file work directory under
   `~/.mbtx-install/` — the absolute path with `/` replaced by `-`.
2. `moon build --target native --target-dir <workdir> <file>.mbtx` builds
   there; the same directory is reused so moon's incremental build kicks in
   on reinstall. `import` blocks (`@version`, `@alias`, `*`) are interpreted
   by moon itself — no rewriting layer.
3. The produced `single.exe` is located by parsing the
   `moon build --dry-run` link line (`-o <path>`), falling back to a `*.exe`
   search under the work directory.
4. It is copied to `~/.moon/bin/<name>`, overwriting unconditionally.

Platforms: Linux and macOS. Windows is a known limitation
([issue #3](https://github.com/podhmo/mbtx-install/issues/3)).

## Errors

- missing / non-`.mbtx` file, invalid options → usage text, exit code 2
- `moon` not on `PATH` → a clear error message, exit code 1
- `moon build` failure → moon's diagnostics are passed through as-is
- `~/.moon/bin` not on `PATH` → warning only; the install still succeeds

## Development

```console
$ moon check   # typecheck
$ moon test    # unit tests
$ moon fmt     # format
```

Design doc and investigation log (Japanese): [docs/ja/](docs/ja).

///|
/// Parsed command-line configuration for `mbtx-install`.
pub struct Config {
  /// Path to the `.mbtx` script, as given on the command line.
  path : String
  /// Installed command name override (`-o` / `--name`).
  name : String?
  /// Install directory override (`--bin`).
  bin_dir : String?
  /// Build in release mode (`--release`); default is debug.
  release : Bool
}

///|
/// The `mbtx-install` command-line specification.
pub fn command() -> @argparse.Command {
  @argparse.Command(
    "mbtx-install",
    about="Install a single .mbtx script as a native binary.",
    positionals=[
      @argparse.PositionArg(
        "path",
        about="path to a .mbtx file",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
    options=[
      @argparse.OptionArg(
        "name",
        short='o',
        long="name",
        about="installed command name (default: file basename without .mbtx)",
      ),
      @argparse.OptionArg(
        "bin",
        long="bin",
        about="install directory (default: ~/.moon/bin)",
      ),
    ],
    flags=[
      @argparse.FlagArg(
        "release",
        long="release",
        about="build with --release (default: debug build)",
      ),
    ],
  )
}

///|
/// Parse `argv` (without the program name) into a `Config`.
/// Raises the parser's error (message already contains usage text) on failure.
pub fn parse_args(argv : ArrayView[String]) -> Config raise {
  let matches = command().parse(argv~)
  guard matches.values is { "path": [path], .. } else {
    fail("missing required argument: <path>")
  }
  let name = match matches.values {
    { "name": [n], .. } => Some(n)
    _ => None
  }
  let bin_dir = match matches.values {
    { "bin": [dir], .. } => Some(dir)
    _ => None
  }
  let release = matches.flags.get("release") is Some(true)
  { path, name, bin_dir, release, }
}

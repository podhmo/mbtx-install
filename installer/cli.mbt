///|
/// Parsed command-line configuration for `mbtx-install`.
pub struct Config {
  /// Path to the `.mbtx` script, as given on the command line
  /// (`None` when `--list` is used without a path).
  path : String?
  /// Installed command name override (`-o` / `--name`).
  name : String?
  /// Install directory override (`--bin`).
  bin_dir : String?
  /// Build in release mode (`--release`); default is debug.
  release : Bool
  /// Pass moon's logs through (`-v` / `--verbose`); default is quiet.
  verbose : Bool
  /// List installs recorded in the manifest (`--list`); takes no path.
  list : Bool
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
        num_args=@argparse.ValueRange(lower=0, upper=1),
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
      @argparse.FlagArg(
        "verbose",
        short='v',
        long="verbose",
        about="show moon's build logs (default: quiet, errors still shown)",
      ),
      @argparse.FlagArg(
        "list",
        long="list",
        about="list installed commands recorded in the manifest",
      ),
    ],
  )
}

///|
/// Parse `argv` (without the program name) into a `Config`.
/// Raises the parser's error (message already contains usage text) on failure.
pub fn parse_args(argv : ArrayView[String]) -> Config raise {
  let matches = command().parse(argv~)
  let first = fn(key : String) -> String? {
    matches.values.get(key).bind(fn(v) { v.get(0) })
  }
  let path = first("path")
  let name = first("name")
  let bin_dir = first("bin")
  let release = matches.flags.get("release") is Some(true)
  let verbose = matches.flags.get("verbose") is Some(true)
  let list = matches.flags.get("list") is Some(true)
  { path, name, bin_dir, release, verbose, list, }
}

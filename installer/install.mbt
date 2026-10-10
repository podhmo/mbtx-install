///|
/// Entry point: parse `argv` (arguments without the program name), run the
/// install pipeline, and return the process exit code.
///
/// Exit codes: 0 success, 1 runtime failure, 2 usage error.
pub async fn run(argv : ArrayView[String]) -> Int {
  let config = Config::parse(argv) catch {
    err => {
      // argparse errors already render as `error: <msg>` + usage text.
      eprintln(err)
      return 2
    }
  }
  match (config.list, config.path) {
    (true, Some(_)) => usage_error("--list cannot be combined with <path>")
    (true, None) => {
      guard @env.get_env_var("HOME") is Some(home) else {
        eprintln("error: HOME is not set; cannot resolve the manifest")
        return 1
      }
      list_installs(manifest_path(home))
      0
    }
    (false, None) => usage_error("missing required argument: <path>")
    (false, Some(_)) => config.install()
  }
}

///|
fn usage_error(msg : String) -> Int {
  eprintln("error: \{msg}\n")
  eprintln(command().render_help())
  2
}

///|
async fn Config::install(self : Config) -> Int {
  // ---- validate the .mbtx argument (usage errors) ----
  guard self.path is Some(path) else {
    return usage_error("missing required argument: <path>")
  }
  if !path.has_suffix(".mbtx") {
    return usage_error("not a .mbtx file: '\{path}'")
  }
  let abs = @fs.realpath(path) catch {
    _ => return usage_error("file not found: '\{path}'")
  }
  if !(@fs.kind(abs) is Regular) {
    return usage_error("not a regular file: '\{abs}'")
  }
  // the default command name comes from the path the user typed, not the
  // realpath — a symlink should install under its own basename
  guard command_name(basename(path)) is Some(derived_name) else {
    return usage_error("cannot derive a command name from '\{path}'")
  }
  let name = match self.name {
    Some(n) =>
      if is_valid_name(n) {
        n
      } else {
        return usage_error("invalid command name: '\{n}'")
      }
    None => derived_name
  }

  // ---- resolve directories ----
  guard @env.get_env_var("HOME") is Some(home) else {
    eprintln("error: HOME is not set; cannot resolve the cache directory")
    return 1
  }
  let workdir = home + "/.mbtx-install/" + cache_key(abs)
  let bin_dir = match self.bin_dir {
    Some(dir) => trim_trailing_slashes(dir)
    None => home + "/.moon/bin"
  }
  let profile = if self.release { "release" } else { "debug" }
  let dest = bin_dir + "/" + name
  let manifest = manifest_path(home)

  // ---- overwrite guard: never clobber a binary we did not install ----
  if @fs.exists(dest) {
    let installs = load_manifest(manifest)
    guard overwrite_allowed(name, installs, true) else {
      eprintln(
        "error: '\{dest}' already exists and was not installed by mbtx-install",
      )
      eprintln(
        "hint: choose a different name with -o, or remove '\{dest}' manually",
      )
      return 1
    }
  }

  // ---- moon must be on PATH ----
  if !program_on_path("moon") {
    eprintln(
      "error: `moon` not found on PATH (required to build .mbtx scripts)",
    )
    return 1
  }
  @fs.mkdir(workdir, recursive=true, allow_exist=true) catch {
    err => {
      eprintln("error: cannot create cache directory '\{workdir}': \{err}")
      return 1
    }
  }

  // ---- locate the artifact ahead of time via --dry-run ----
  let flags = ["build", "--target", "native", "--target-dir", workdir]
  if self.release {
    flags.push("--release")
  }
  let build_args = [..flags, abs]
  let dry_args = [..flags, "--dry-run", abs]
  let artifact_hint = locate_artifact_hint(dirname(abs), dry_args)

  // ---- real build: -v passes moon's logs through, otherwise they are
  // captured and only replayed on failure ----
  let status = if self.verbose {
    @shell.Cmd("moon", build_args, stdout=Inherit, stderr=Inherit).status() catch {
      err => {
        eprintln("error: failed to run `moon`: \{err}")
        return 1
      }
    }
  } else {
    let out = @shell.Cmd("moon", build_args, stdout=Capture, stderr=Capture).output() catch {
      err => {
        eprintln("error: failed to run `moon`: \{err}")
        return 1
      }
    }
    let code = out.exit_code()
    if code != 0 {
      eprintln(out.stdout() + out.stderr())
    }
    code
  }
  if status != 0 {
    eprintln("error: `moon build` failed with exit code \{status}")
    eprintln("hint: if dependency resolution failed, `moon update` may fix it")
    return status
  }

  // ---- find the produced binary ----
  let artifact = match artifact_hint {
    Some(path) if @fs.exists(path) => path
    _ =>
      match find_artifact(workdir, profile) {
        Some(path) => path
        None => {
          eprintln(
            "error: build succeeded but no artifact was found under '\{workdir}'",
          )
          return 1
        }
      }
  }

  // ---- install ----
  @fs.mkdir(bin_dir, recursive=true, allow_exist=true) catch {
    err => {
      eprintln("error: cannot create install directory '\{bin_dir}': \{err}")
      return 1
    }
  }
  let data = @fs.read_file(artifact) catch {
    err => {
      eprintln("error: cannot read artifact '\{artifact}': \{err}")
      return 1
    }
  }
  @fs.write_file(dest, data, create_mode=CreateOrTruncate, permission=0o755) catch {
    err => {
      eprintln("error: cannot write '\{dest}': \{err}")
      return 1
    }
  }
  @fs.chmod(dest, 0o755) catch {
    _ => ()
  }
  record_install(manifest, name, abs, bin_dir)
  if !dir_on_path(bin_dir) {
    eprintln(
      "warning: '\{bin_dir}' is not on PATH; '\{name}' will not run as a command",
    )
  }
  println("Installed '\{name}' to '\{dest}'")
  0
}

///|
/// Predict the build artifact path from `moon build --dry-run` output.
/// Returns `None` when the dry-run fails or no link line is found.
async fn locate_artifact_hint(
  script_dir : String,
  dry_args : Array[String],
) -> String? {
  let out = @shell.Cmd("moon", dry_args, stdout=Capture, stderr=Capture).output() catch {
    _ => return None
  }
  let text = out.stdout() + "\n" + out.stderr()
  match find_link_target(text) {
    Some(candidate) => Some(resolve_link_target(candidate, script_dir))
    None => None
  }
}

///|
/// Fallback artifact search: collect every `*.exe` under `workdir`,
/// preferring the one under `native/<profile>/`.
async fn find_artifact(workdir : String, profile : String) -> String? {
  let found : Array[String] = []
  @fs.walk(workdir, (dir, entries) => {
    for entry in entries {
      if entry.has_suffix(".exe") {
        found.push(dir + "/" + entry)
      }
    }
  }) catch {
    _ => ()
  }
  found.sort()
  let preferred = "/native/" + profile + "/"
  for path in found {
    if path.contains(preferred) {
      return Some(path)
    }
  }
  if found.length() > 0 {
    Some(found[0])
  } else {
    None
  }
}

///|
/// Does an executable `name` exist in one of the PATH directories?
async fn program_on_path(name : String) -> Bool {
  guard @env.get_env_var("PATH") is Some(path_env) else { return false }
  for dir in path_env.split(":") {
    if dir.is_empty() {
      continue
    }
    let candidate = dir.to_owned() + "/" + name
    if @fs.exists(candidate) && @fs.can_execute(candidate) {
      return true
    }
  }
  false
}

///|
/// Is `dir` one of the PATH directories? Compares both literal entries and
/// canonical paths so `~/.moon/bin` matches e.g. a symlinked entry.
async fn dir_on_path(dir : String) -> Bool {
  guard @env.get_env_var("PATH") is Some(path_env) else { return false }
  let target = realpath_or_self(dir)
  for entry in path_env.split(":") {
    if entry.is_empty() {
      continue
    }
    let entry = entry.to_owned()
    if entry == dir {
      return true
    }
    if @fs.exists(entry) && realpath_or_self(entry) == target {
      return true
    }
  }
  false
}

///|
async fn realpath_or_self(path : String) -> String {
  @fs.realpath(path) catch {
    _ => path
  }
}

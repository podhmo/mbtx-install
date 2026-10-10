///|
/// Last path component of `path` (the part after the final '/').
pub fn basename(path : String) -> String {
  match path.rev_find("/") {
    Some(i) => path[i + 1:].to_owned()
    None => path
  }
}

///|
/// Directory component of `path` (everything before the final '/').
/// Returns "." for a bare relative file name.
pub fn dirname(path : String) -> String {
  match path.rev_find("/") {
    Some(0) => "/"
    Some(i) => path[:i].to_owned()
    None => "."
  }
}

///|
/// Cache directory key for an absolute `.mbtx` path: every '/' is replaced
/// with '-' (same convention as Claude Code's `~/.claude/projects/`).
/// `/home/u/foo/bar.mbtx` becomes `-home-u-foo-bar.mbtx`.
pub fn cache_key(abs_path : String) -> String {
  abs_path.replace_all(old="/", new="-")
}

///|
/// Derive the installed command name from a file basename:
/// `mytool.mbtx` -> `mytool`. Returns `None` when the name does not end
/// with `.mbtx` or the remaining stem is empty.
pub fn command_name(base : String) -> String? {
  guard base.has_suffix(".mbtx") else { None }
  let stem = base[:base.length() - 5].to_owned()
  if stem.is_empty() || stem.contains("/") {
    None
  } else {
    Some(stem)
  }
}

///|
/// A user-supplied command name (`-o` / `--name`) is usable when it is
/// non-empty and contains no path separator.
pub fn is_valid_name(name : String) -> Bool {
  !name.is_empty() && !name.contains("/")
}

///|
/// Strip trailing '/' characters (keeping a lone "/" root) so the install
/// directory can be joined with '/' without producing double slashes.
pub fn trim_trailing_slashes(s : String) -> String {
  let mut view : StringView = s
  while view.length() > 1 && view.has_suffix("/") {
    view = view[:view.length() - 1]
  }
  view.to_owned()
}

///|
/// Extract the final binary path from `moon build --dry-run` output: the
/// `-o <path>` argument whose value ends in `.exe` (the `cc` link line).
/// Returns the last such candidate, or `None` when none is found.
pub fn find_link_target(output : String) -> String? {
  let mut found : String? = None
  for line in output.split("\n") {
    if !line.contains(".exe") {
      continue
    }
    let tokens = line.split(" ").to_array()
    for i, tok in tokens {
      if tok == "-o" && i + 1 < tokens.length() {
        let candidate = tokens[i + 1]
        if candidate.has_suffix(".exe") {
          found = Some(candidate.to_owned())
        }
      }
    }
  }
  found
}

///|
/// Resolve a path reported by `moon build --dry-run` to an absolute path.
/// Dry-run prints paths relative to the moon workspace directory (the
/// directory containing the `.mbtx` when outside a project), so relative
/// candidates are anchored at `script_dir`.
pub fn resolve_link_target(candidate : String, script_dir : String) -> String {
  if candidate.has_prefix("/") {
    candidate
  } else {
    script_dir + "/" + candidate
  }
}

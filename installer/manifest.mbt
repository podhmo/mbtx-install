///|
/// Location of the install manifest: `~/.mbtx-install/config.json`
/// records which command names mbtx-install installed, so overwrite
/// protection can tell them apart from unrelated binaries (e.g. `-o moon`
/// must never clobber the real moon binary).
pub fn manifest_path(home : String) -> String {
  home + "/.mbtx-install/config.json"
}

///|
/// May `dest` be overwritten? Only when nothing exists there yet, or
/// when `name` is recorded in the manifest (mbtx-install installed it).
pub fn overwrite_allowed(
  name : String,
  installs~ : Map[String, Json],
  dest_exists~ : Bool,
) -> Bool {
  !dest_exists || installs.contains(name)
}

///|
/// Read the manifest's `installs` map (name -> record). A missing file
/// yields an empty map; a malformed file warns and also yields an empty
/// map — fail closed, so an unreadable manifest still blocks overwrites
/// of unknown binaries.
pub async fn load_manifest(path : String) -> Map[String, Json] {
  let data = @fs.read_file(path) catch { _ => return Map([]) }
  let json = data.json() catch {
    _ => {
      eprintln("warning: ignoring malformed manifest '\{path}'")
      return Map([])
    }
  }
  match json {
    Object(obj) =>
      match obj.get("installs") {
        Some(Object(entries)) => entries
        _ => Map([])
      }
    _ => Map([])
  }
}

///|
/// Format the installs map as sorted `name -> source` lines for `--list`.
/// Entries without a readable `source` render as the bare name.
pub fn format_installs(installs : Map[String, Json]) -> Array[String] {
  let names = installs.keys().to_array()
  names.sort()
  [
    for name in names => match installs.get(name) {
      Some(Object(entry)) =>
        match entry.get("source") {
          Some(String(s)) if !s.is_empty() => "\{name} -> \{s}"
          _ => name
        }
      _ => name
    }
  ]
}

///|
/// Print every recorded install for `mbtx-install --list`.
pub async fn list_installs(path : String) -> Unit {
  let lines = format_installs(load_manifest(path))
  if lines.is_empty() {
    println("(no installs recorded)")
  } else {
    lines.each(println)
  }
}

///|
/// Record `name -> {source, bin}` in the manifest, creating
/// `~/.mbtx-install/` when needed. Warns but does not fail when the
/// write fails: a missing record would later block overwrites of that
/// name, so the warning keeps the inconsistency visible.
pub async fn record_install(
  path : String,
  name~ : String,
  source~ : String,
  bin_dir~ : String,
) -> Unit {
  let installs = load_manifest(path)
  let entry : Map[String, Json] = Map([])
  entry["source"] = source.to_json()
  entry["bin"] = bin_dir.to_json()
  installs[name] = Json::object(entry)
  let root : Map[String, Json] = Map([])
  root["installs"] = Json::object(installs)
  let out = Json::object(root).stringify() + "\n"
  @fs.mkdir(dirname(path), recursive=true, allow_exist=true) catch {
    err => {
      eprintln("warning: cannot create manifest directory: \{err}")
      return
    }
  }
  @fs.write_file(path, out, create_mode=CreateOrTruncate, permission=0o644) catch {
    err => eprintln("warning: cannot write manifest '\{path}': \{err}")
  }
}

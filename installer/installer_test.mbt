///|
test "basename and dirname" {
  assert_eq(@installer.basename("/a/b/c.mbtx"), "c.mbtx")
  assert_eq(@installer.basename("c.mbtx"), "c.mbtx")
  assert_eq(@installer.dirname("/a/b/c.mbtx"), "/a/b")
  assert_eq(@installer.dirname("/c.mbtx"), "/")
  assert_eq(@installer.dirname("c.mbtx"), ".")
}

///|
test "cache_key replaces slashes with dashes" {
  assert_eq(
    @installer.cache_key("/home/u/ghq/github.com/podhmo/foo/scripts/bar.mbtx"),
    "-home-u-ghq-github.com-podhmo-foo-scripts-bar.mbtx",
  )
}

///|
test "command_name strips the .mbtx suffix" {
  assert_eq(@installer.command_name("mytool.mbtx"), Some("mytool"))
  assert_eq(@installer.command_name("a.b.mbtx"), Some("a.b"))
  assert_eq(@installer.command_name("x.txt"), None)
  assert_eq(@installer.command_name(".mbtx"), None)
  assert_eq(@installer.command_name("noext"), None)
}

///|
test "is_valid_name rejects empty and pathed names" {
  assert_eq(@installer.is_valid_name("mytool"), true)
  assert_eq(@installer.is_valid_name(""), false)
  assert_eq(@installer.is_valid_name("a/b"), false)
}

///|
test "trim_trailing_slashes" {
  assert_eq(@installer.trim_trailing_slashes("/a/b/"), "/a/b")
  assert_eq(@installer.trim_trailing_slashes("/a/b//"), "/a/b")
  assert_eq(@installer.trim_trailing_slashes("/a/b"), "/a/b")
  assert_eq(@installer.trim_trailing_slashes("/"), "/")
}

///|
test "find_link_target picks the cc -o .exe line" {
  let dry =
    #|moonc link-core 'core.core' ./cache/t.mbtx/native/debug/build/single/single.core -main moon/test/single -o ./cache/t.mbtx/native/debug/build/single/__moonbit_link_core__/single.o -target x86_64-unknown-linux-gnu
    #|/usr/bin/cc -o ./cache/t.mbtx/native/debug/build/runtime-env.o '-I/include' -c runtime/env.c
    #|/usr/bin/cc -o ./cache/t.mbtx/native/debug/build/single/single.exe 'libmoonbitrun.o' ./cache/t.mbtx/native/debug/build/single/__moonbit_link_core__/single.o -lm 'libbacktrace.a'
  assert_eq(
    @installer.find_link_target(dry),
    Some("./cache/t.mbtx/native/debug/build/single/single.exe"),
  )
}

///|
test "find_link_target with absolute target dir" {
  let dry =
    #|/usr/bin/cc -o /home/u/.mbtx-install/-tmp-t.mbtx/t.mbtx/native/release/build/single/single.exe 'libmoonbitrun.o' single.o -lm
  assert_eq(
    @installer.find_link_target(dry),
    Some(
      "/home/u/.mbtx-install/-tmp-t.mbtx/t.mbtx/native/release/build/single/single.exe",
    ),
  )
}

///|
test "find_link_target returns None without a link line" {
  assert_eq(
    @installer.find_link_target("moonc build-package x -o y.core"),
    None,
  )
  assert_eq(@installer.find_link_target(""), None)
}

///|
test "resolve_link_target anchors relative paths at the script dir" {
  assert_eq(
    @installer.resolve_link_target("/abs/x.exe", "/scripts"),
    "/abs/x.exe",
  )
  assert_eq(
    @installer.resolve_link_target("./cache/x.exe", "/scripts"),
    "/scripts/./cache/x.exe",
  )
}

///|
test "manifest_path joins home and config.json" {
  assert_eq(
    @installer.manifest_path("/home/u"),
    "/home/u/.mbtx-install/config.json",
  )
}

///|
test "overwrite_allowed requires a manifest record when dest exists" {
  let installs : Map[String, Json] = Map([])
  installs["hello"] = Json::object(Map([]))
  assert_eq(@installer.overwrite_allowed("fresh", installs, false), true)
  assert_eq(@installer.overwrite_allowed("fresh", installs, true), false)
  assert_eq(@installer.overwrite_allowed("hello", installs, true), true)
}

///|
test "format_installs renders sorted 'name -> source' lines" {
  let installs : Map[String, Json] = Map([])
  assert_eq(@installer.format_installs(installs), [])
  let hello : Map[String, Json] = Map([])
  hello["source"] = "/abs/hello.mbtx".to_json()
  installs["hello"] = Json::object(hello)
  let argv : Map[String, Json] = Map([])
  argv["source"] = "/abs/argv.mbtx".to_json()
  installs["argv"] = Json::object(argv)
  assert_eq(@installer.format_installs(installs), [
    "argv -> /abs/argv.mbtx", "hello -> /abs/hello.mbtx",
  ])
}

///|
async test "record_install then load_manifest round-trips" {
  let path = "/tmp/mbtx-install-manifest-test/config.json"
  @installer.record_install(path, "hello", "/abs/hello.mbtx", "/tmp/bin")
  @installer.record_install(path, "argv", "/abs/argv.mbtx", "/tmp/bin")
  let installs = @installer.load_manifest(path)
  assert_eq(installs.contains("hello"), true)
  assert_eq(installs.contains("argv"), true)
  match installs.get("hello") {
    Some(Object(entry)) => {
      assert_true(entry.get("source") is Some(String("/abs/hello.mbtx")))
      assert_true(entry.get("bin") is Some(String("/tmp/bin")))
    }
    _ => fail("manifest entry for 'hello' is missing or not an object")
  }
}

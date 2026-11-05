///|
extern "c" fn native_exit(code : Int32) -> Unit = "exit"

///|
async fn main {
  let code = @installer.run(@env.args()[1:])
  if code != 0 {
    native_exit(code)
  }
}

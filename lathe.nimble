version       = "0.1.0"
author        = "Provokke"
description   = "Logic-less templates for Nim in the Mustache style"
license       = "MIT"
srcDir        = "src"
bin           = @["lathe"]
installExt    = @["nim"]

requires "nim >= 2.0.0"

task test, "Run the test suite":
  exec "nim c -r --hints:off tests/test_lathe.nim"

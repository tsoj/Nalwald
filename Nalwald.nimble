# Package

version       = "19"
author        = "Jost Triller"
description   = "UCI chess engine written in Nim"
license       = "CC-BY-NC-SA-4.0"
srcDir        = "src"
bin           = @["Nalwald"]


# Dependencies

requires "nim >= 2.2.4"

# task test, "Runs the project's tests":
#   echo "hi"
#   exec "nim r tests/test.nim"
#   echo "hi2"


task test1, "Runs the project's tests":
  echo "hi"
  exec "nim r tests/test.nim"
  echo "hi2"


task test2, "Runs the project's tests":
  # echo "hi"
  # exec "nim r tests/test.nim"
  # echo "hi2"
  setCommand "c", "tests/test.nim"

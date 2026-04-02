import std/strutils
# import src/Nalwald/version

# Package

version = "20"
author = "Jost Triller"
description = "UCI chess engine written in Nim"
license = "LGPL-3.0-linking-exception"
srcDir = "src"
bin = @["Nalwald"]

# Dependencies

requires "nim >= 2.2.8"
requires "nimchess >= 0.3.2"

when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"

# Tasks

const commonFlags =
  "--cc:clang --mm:arc --define:useMalloc --skipProjCfg --skipParentCfg"

proc versionOrId(): string =
  let gitTag = gorge("git tag --points-at HEAD").strip()
  let gitShortHash = gorge("git rev-parse --short HEAD").strip()
  let unstaged = gorge("git status -suno").strip()
  if gitTag.len > 0 and unstaged.len == 0:
    result = gitTag
  else:
    result = gitShortHash
    if unstaged.len > 0:
      let d = CompileDate.split('-')
      let t = CompileTime.split(':')
      result &= "-" & d[0] & d[1] & d[2] & t[0] & t[1] & t[2]

task debug, "Build debug version":
  exec "nim c " & commonFlags & " --define:release" & " --debugger:native" &
    " --passC:\"-fno-omit-frame-pointer -g\"" & " -o:Nalwald-debug src/Nalwald.nim"

task release, "Build release versions":
  let ver = versionOrId()
  var releaseFlags =
    commonFlags & " --passL:\"-static\" --panics:on --define:danger --passC:\"-flto\" --passL:\"-flto\""

  if defined(windows):
    releaseFlags &= " --passL:\"-fuse-ld=lld\""

  exec "nim c " & releaseFlags & " -o:Nalwald-" & ver & " src/Nalwald.nim"
  exec "nim c " & releaseFlags & " --passC:\"-mbmi2\" --passC:\"-mpopcnt\" -o:Nalwald-" &
    ver & "-modern src/Nalwald.nim"

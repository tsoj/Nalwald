# Package

version = "20"
author = "Jost Triller"
description = "UCI chess engine written in Nim"
license = "LGPL-3.0-linking-exception"
srcDir = "src"
bin = @["Nalwald"]
binDir = "bin"

# Dependencies

requires "nim >= 2.2.8"
requires "nimchess >= 0.10.0"
requires "https://github.com/tsoj/nim_zstd#2510a0b" #"zstd == 0.10"

# Tasks

task debug, "Build debug version":
  exec "nim c -d:buildDebug src/Nalwald.nim"

task release, "Build release versions":
  exec "nim c -d:buildRelease -d:buildGeneric src/Nalwald.nim"
  exec "nim c -d:buildRelease -d:buildModern src/Nalwald.nim"

func collectParams(): tuple[compilerParam: string, programArgs: string] =
  result.programArgs = ""
  result.compilerParam = ""
  for param in commandLineParams:
    if "--" notin param:
      result.programArgs.add " " & param
    if param == "--allowDirtyGit":
      result.compilerParam = "-d:allowDirtyGit"

task evaltrain, "Optimize evaluation parameters using datagen games":
  let (compilerParam, args) = collectParams()
  exec "nim r " & compilerParam & " src/Nalwald/evaltraining/optimization.nim" & args

task datagen, "Play chess games and write them to PGNs":
  let (compilerParam, args) = collectParams()
  exec "nim r " & compilerParam & " src/Nalwald/datagen/datagen.nim " & args

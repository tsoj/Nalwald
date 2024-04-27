import ../positionUtils

import std/[osproc, os, strutils, strformat, json]

const
  mainBranch = "master"
  workDir = "src/testing/workdir/"
  cuteChessBinary = "/usr/games/cutechess-cli"
  nalwaldBinaryFile = "bin/Nalwald-native"
  openingBook = "res/openings/Pohl.epd"
  pgnOutFile = "res/pgns/sprtGames.pgn"
  timeControlSeconds = 10.0
  maxNumGames = 100_000
  hashSizeMB = 6

let gitStatus = execProcess("git status")

doAssert "git version" in execProcess("git --version")
doAssert execProcess("git rev-parse --is-inside-work-tree").strip == "true"

doAssert "git version" in execProcess("git --version")
doAssert "not a git repository" notin gitStatus

let
  gitHasUnstagedChanges = execProcess("git status -suno").strip != ""
  currentBranch = execProcess("git rev-parse --abbrev-ref HEAD").strip

doAssert not gitHasUnstagedChanges, "Shouldn't do SPRT with unstaged changes"

if currentBranch == mainBranch:
  while true:
    stdout.write "You are about to test the main branch against itself. Are you sure you want to do this? [y/n] "
    stdout.flushFile
    let answer = readLine(stdin).strip.toLowerAscii
    if answer == "y":
      break
    if answer == "n":
      quit(QuitFailure)

discard existsOrCreateDir workDir

proc nalwaldBinary(branch: string): string =
  fmt"{workDir}Nalwald-{branch}"

try:
  for branch in [mainBranch, currentBranch]:
    discard tryRemoveFile nalwaldBinaryFile
    if execCmd("git switch " & branch) != 0:
      raise newException(CatchableError, "Failed to switch to branch " & branch)
    if execCmd("nim native -f Nalwald") != 0:
      raise newException(
        CatchableError, "Failed to compile Nalwald binary for branch " & branch
      )
    copyFileWithPermissions nalwaldBinaryFile, nalwaldBinary(branch)
finally:
  doAssert execCmd("git switch " & currentBranch) == 0

let cuteChessArguments =
  fmt""" \
-recover \
-concurrency {max(1, countProcessors() - 2)} \
-ratinginterval 50 \
-games 2 -rounds {maxNumGames} \
-pgnout {pgnOutFile} min \
-openings file={openingBook} format=epd order=random -repeat 2 \
-each restart=on tc={timeControlSeconds}+{timeControlSeconds / 100.0} option.Hash={hashSizeMB} proto=uci dir=./ \
-engine cmd=./{nalwaldBinary(currentBranch)} \
-engine cmd=./{nalwaldBinary(mainBranch)}
"""

doAssert execCmd(cuteChessBinary & " " & cuteChessArguments) == 0

echo "Finished SPRT test"

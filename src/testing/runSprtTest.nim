import ../utils

import std/[osproc, os, strutils, strformat]

const
  mainBranch = "master"
  workDir = "src/testing/sprtWorkdir/"
  cuteChessBinary = "/usr/games/cutechess-cli"
  nalwaldBinaryFile = "bin/Nalwald-native"
  openingBook = "res/openings/Pohl.epd"
  pgnOutDir = "res/pgns/"
  pgnOutFile = pgnOutDir & "sprtGames.pgn"
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
  if not askYesNo(question = "You are about to test the main branch against itself. Are you sure you want to do this?"):
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

createDir pgnOutDir

let cuteChessArguments =
  fmt""" \
-recover \
-concurrency {max(1, countProcessors() - 2)} \
-ratinginterval 50 \
-games 2 -rounds {maxNumGames} \
-pgnout {pgnOutFile} min \
-openings file={openingBook} format=epd order=random -repeat 2 \
-sprt elo0=0 elo1=5 alpha=0.05 beta=0.05 \
-each restart=on tc={timeControlSeconds}+{timeControlSeconds / 100.0} option.Hash={hashSizeMB} proto=uci dir=./ \
-engine name={currentBranch} cmd=./{nalwaldBinary(currentBranch)} \
-engine name={mainBranch} cmd=./{nalwaldBinary(mainBranch)}
"""

doAssert execCmd(cuteChessBinary & " " & cuteChessArguments) == 0

echo "\nFinished SPRT test\n"

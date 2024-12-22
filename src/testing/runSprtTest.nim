import ../utils

import std/[osproc, os, strutils, strformat]

const
  mainBranch = "master"
  workDir = "src/testing/sprtWorkdir/"
  engineTournamentBinary = "fastchess"
  nalwaldBinaryFile = "bin/Nalwald-native"
  openingBook = "res/openings/Pohl.epd"
  pgnOutDir = "res/pgns/"
  pgnOutFile = pgnOutDir & "sprtGames.pgn"
  timeControlSeconds = 10.0
  maxNumGames = 100_000
  hashSizeMB = 8

let gitStatus = execProcess("git status")

doAssert "git version" in execProcess("git --version")
doAssert execProcess("git rev-parse --is-inside-work-tree").strip == "true"

doAssert "git version" in execProcess("git --version")
doAssert "not a git repository" notin gitStatus

let
  gitHasUnstagedChanges = execProcess("git status -suno").strip != ""
  currentBranch = execProcess("git rev-parse --abbrev-ref HEAD").strip
  otherBranch =
    if commandLineParams().len >= 1:
      commandLineParams()[0].strip
    else:
      mainBranch

echo "Testing against ", otherBranch

if currentBranch == otherBranch:
  if not askYesNo(
    question =
      "You are about to test the main branch against itself. Are you sure you want to do this?"
  ):
    quit(QuitFailure)

doAssert not gitHasUnstagedChanges, "Shouldn't do SPRT with unstaged changes"

discard existsOrCreateDir workDir

proc nalwaldBinary(branch: string): string =
  fmt"{workDir}Nalwald-{branch}"

try:
  for branch in [otherBranch, currentBranch]:
    discard tryRemoveFile nalwaldBinaryFile
    if execCmd("git checkout " & branch) != 0:
      raise newException(CatchableError, "Failed to checkout to branch " & branch)
    if execCmd("nim native -f Nalwald") != 0:
      raise newException(
        CatchableError, "Failed to compile Nalwald binary for branch " & branch
      )
    copyFileWithPermissions nalwaldBinaryFile, nalwaldBinary(branch)
finally:
  doAssert execCmd("git checkout " & currentBranch) == 0

createDir pgnOutDir

let cuteChessArguments =
  fmt""" \
-concurrency {max(1, countProcessors() - 2)} \
-ratinginterval 50 \
-games 2 -rounds {maxNumGames} \
-pgnout {pgnOutFile} min \
-openings file={openingBook} format=epd order=random -repeat 2 \
-sprt elo0=0 elo1=5 alpha=0.05 beta=0.05 \
-resign movecount=3 score=400 \
-draw movenumber=40 movecount=8 score=10 \
-engine name={currentBranch} cmd=./{nalwaldBinary(currentBranch)} \
-engine name={otherBranch} cmd=./{nalwaldBinary(otherBranch)} \
-each tc={timeControlSeconds}+{timeControlSeconds / 100.0} option.Hash={hashSizeMB} proto=uci dir={workDir}
"""

let command = engineTournamentBinary & " " & cuteChessArguments
doAssert execCmd(command) == 0, "Command:\n" & command

echo "\nFinished SPRT test\n"

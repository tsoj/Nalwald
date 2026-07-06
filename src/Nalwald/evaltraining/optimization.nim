import ../evalparams, ../eval, ../version, datautils, piecevaluecalc

import std/[times, strformat, strutils, random, math, os]

proc optimize(
    start: EvalParameters,
    data: var seq[Entry],
    maxNumEpochs = 30,
    startLr = 0.1,
    finalLr = 0.0002,
): (EvalParameters, float) =
  var solution = start

  echo "starting error: ", fmt"{solution.error(data):>9.7f}", ", starting lr: ", startLr

  let lrDecay = pow(finalLr / startLr, 1.0 / float(maxNumEpochs * data.len))
  doAssert startLr > finalLr,
    "Starting learning rate must be strictly bigger than the final learning rate"
  doAssert finalLr == startLr or lrDecay < 1.0,
    "lrDecay should be smaller than one if the learning rate should decrease"

  var lr = startLr

  for epoch in 1 .. maxNumEpochs:
    let startTime = now()
    data.shuffle

    for entry in data:
      solution.addGradient(lr, entry.position, entry.outcome)
      lr *= lrDecay

    let
      error = solution.error(data[0 ..< min(data.len, 1_000_000)])
      passedTime = now() - startTime
    echo fmt"Epoch {epoch}, error: {error:>9.7f}, lr: {lr:.3f}, time: {passedTime.inSeconds} s"

  let finalError = solution.error(data)
  echo fmt"Final error: {finalError:>9.7f}"

  (solution, finalError)

when isMainModule:
  static:
    doAssert not gitHasUnstagedChanges or defined(allowDirtyGit),
      "optimization must be compiled without unstaged git changes"

  let startTime = now()

  # Datasets are given as "dir" or "dir=scoreTargetWeight" command line
  # params. Without params, all datasets in res/data/ are used.
  var data: seq[Entry]
  var dataDirs = commandLineParams()
  if dataDirs.len == 0:
    for dir in walkDirs("res/data/datagen_*"):
      dataDirs.add dir
  for param in dataDirs:
    let parts = param.split('=')
    case parts.len
    of 1:
      data.loadDataDir parts[0]
    of 2:
      data.loadDataDir(parts[0], scoreTargetWeight = parts[1].parseFloat)
    else:
      quit "Invalid dataset param: " & param

  doAssert data.len > 0, "No training data found"
  data.shuffle

  echo "Total number of entries: ", data.len

  let (ep, finalError) = newEvalParameters().optimize(data)

  const epDir = "res/params/"
  let
    epFileName =
      &"""default_{startTime.format("yyyy-MM-dd-HH-mm-ss")}_{versionOrId()}.zst"""
    epFilePath = epDir & epFileName

  createDir epDir
  writeFile epFilePath, ep.toString
  echo "Wrote to: ", epFilePath

  const settingsFileName = epDir & "settings.txt"
  let settingsContent = &"""
file: {epFileName}
date: {startTime}
commit: {commitHash()}
final error: {finalError}
datasets:
{dataDirs.join("\n").indent(2)}
"""
  writeFile settingsFileName, settingsContent
  echo "Wrote to: ", settingsFileName

  const pieceValueFileName = "src/Nalwald/piecevalues.nim"
  let
    pieceValueString = ep.pieceValuesAsString(data[0 ..< min(data.len, 10_000_000)])
    pieceValueFileContent = &"""
import nimchess

import types

#!fmt: off
func value*(piece: Piece): Value =
  const table = [{pieceValueString}king: valueCheckmate, noPiece: 0.Value]
  table[piece]
#!fmt: on
"""

  writeFile pieceValueFileName, pieceValueFileContent
  echo "Wrote to: ", pieceValueFileName

  echo "Total time: ", now() - startTime

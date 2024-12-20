import
  ../position,
  ../positionUtils,
  ../evalParameters,
  ../evaluation,
  ../utils

import std/[os, strutils, streams]

type Entry* = object
  position*: Position
  outcome*: float

func validTrainingPosition*(position: Position): bool =
  position[king, white].countSetBits == 1 and position[king, black].countSetBits == 1

proc loadDataEpd*(
    data: var seq[Entry], fileName: string, maxLen = int.high, suppressOutput = false
) =
  doAssert fileExists fileName, "File should exist"

  let f = open(fileName)
  var
    line: string
    numEntries = 0

  while f.readLine(line):
    let words = line.splitWhitespace()
    if words.len == 0 or words[0] == "LICENSE:":
      continue
    doAssert words.len >= 7
    let position = line.toPosition(suppressWarnings = true)

    doAssert position.validTrainingPosition

    numEntries += 1
    data.add(Entry(position: position, outcome: words[6].parseFloat))
    if numEntries >= maxLen:
      break
  f.close()
  if not suppressOutput:
    debugEcho fileName & ": ", numEntries, " entries"

proc loadDataBin*(
    data: var seq[Entry], fileName: string, maxLen = int.high, suppressOutput = false
) =
  doAssert fileExists fileName, "File should exist"

  var
    inFileStream = newFileStream(fileName, fmRead)
    numEntries = 0

  while not inFileStream.atEnd:
    let
      position = inFileStream.readPosition
      value = inFileStream.readFloat64

    doAssert position.validTrainingPosition

    data.add Entry(position: position, outcome: value)
    numEntries += 1

    if numEntries >= maxLen:
      break

  if not suppressOutput:
    debugEcho fileName & ": ", numEntries, " entries"

func error*(evalParameters: EvalParameters, entry: Entry): float =
  let estimate = entry.position.absoluteEvaluate(evalParameters).winningProbability
  error(entry.outcome, estimate)

func errorTuple*(
    evalParameters: EvalParameters, data: openArray[Entry]
): tuple[error, summedWeight: float] =
  result.error = 0.0
  result.summedWeight = 0.0
  for entry in data:
    result.error += evalParameters.error(entry)
    result.summedWeight += 1.0

func error*(evalParameters: EvalParameters, data: openArray[Entry]): float =
  let (error, summedWeight) = evalParameters.errorTuple(data)
  error / summedWeight

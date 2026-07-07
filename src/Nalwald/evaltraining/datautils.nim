import std/[os, math, streams, strutils, strformat]

import nimchess
import zstd/decompress

import ../evalparams, ../eval, ../piecevalues

type
  Entry* = object
    position*: Position # always white to move (mirrored during loading if necessary)
    outcome*: float # target winning probability from the side to move's perspective

  RawEntry = object
    position: Position
    score: float # search score in pawns from the side to move's perspective
    outcome: float # game result from the side to move's perspective

func stmRelative(x: float, us: Color): float =
  if us == white:
    x
  else:
    1.0 - x

proc addGame(raw: var seq[RawEntry], game: Game) =
  let whiteResult =
    case game.result
    of "1-0":
      1.0
    of "0-1":
      0.0
    of "1/2-1/2":
      0.5
    else:
      return

  let positions = game.positions
  for i in 0 ..< game.annotatedMoves.len:
    let
      position = positions[i]
      (move, annotation) = game.annotatedMoves[i]

    # Skip noisy positions where the played move is a capture or promotion.
    if move.isTactical:
      continue

    # The annotation is the UCI-style search score ("cp 59" or "mate 3") from
    # the perspective of the side to move (see datagen).
    let parts = annotation.splitWhitespace
    doAssert parts.len == 2 or parts[0] notin ["cp", "mate"],
      "Unknown annotation format: " & annotation
    var score: float = parts[1].parseFloat

    if parts[0] == "mate":
      doAssert score != 0
      score =
        if score > 0:
          Inf
        else:
          -Inf
    else:
      # roughly undo the centipawn scaling
      score = pawn.value * score / 100.0

    raw.add RawEntry(
      position: if position.us == black: position.mirrorVertically else: position,
      score: score,
      outcome: whiteResult.stmRelative(position.us),
    )

proc loadRaw(pgnZstFileName: string): seq[RawEntry] =
  # Datagen writes with a streaming compressor, so the frame content size is
  # unknown and we have to use streaming decompression too.
  let fileStream = newFileStream(pgnZstFileName, fmRead)
  doAssert fileStream != nil, "Failed to open " & pgnZstFileName
  var
    zstStream = newDecompressStream(fileStream)
    content = ""
  while not zstStream.atEnd:
    content.add zstStream.readStr(1_000_000)
  zstStream.close()
  fileStream.close()

  for game in content.readPgnFromString(suppressWarnings = true):
    result.addGame(game)
  echo fmt"Loaded {result.len} entries from {pgnZstFileName}"

type LoadRawThreadParams = object
  pgnZstFileName: string
  target: ptr seq[RawEntry]

proc loadRawThread(params: LoadRawThreadParams) {.thread.} =
  params.target[] = loadRaw(params.pgnZstFileName)

func scorePredictionError(raw: openArray[RawEntry], k: float): float =
  for entry in raw:
    result += error(entry.outcome, entry.score.winningProbability(k))
  result /= raw.len.float

func optimalK(raw: openArray[RawEntry]): float =
  # Golden section search for the k that makes the search scores predict the
  # game outcomes best.
  const invPhi = (sqrt(5.0) - 1.0) / 2.0
  var
    lo = 0.001
    hi = 10.0
  while hi - lo > 0.0001:
    let
      a = hi - (hi - lo) * invPhi
      b = lo + (hi - lo) * invPhi
    if raw.scorePredictionError(a) < raw.scorePredictionError(b):
      hi = b
    else:
      lo = a
  (lo + hi) / 2.0

proc loadDataDir*(data: var seq[Entry], dir: string, scoreTargetWeight = 0.5) =
  ## Loads all datagen PGNs of the dataset `dir`. The training target is a
  ## linear combination of the game outcome and the search score converted to
  ## a winning probability, with the sigmoid scale k fitted on this dataset.
  doAssert scoreTargetWeight in 0.0 .. 1.0

  var fileNames: seq[string]
  for file in walkFiles(dir / "*.pgn.zst"):
    fileNames.add file

  var
    perFile = newSeq[seq[RawEntry]](fileNames.len)
    threads = newSeq[Thread[LoadRawThreadParams]](fileNames.len)
  for i, fileName in fileNames:
    createThread(
      threads[i],
      loadRawThread,
      LoadRawThreadParams(pgnZstFileName: fileName, target: addr perFile[i]),
    )
  joinThreads threads

  var raw: seq[RawEntry]
  for entries in perFile.mitems:
    raw.add entries
  doAssert raw.len > 0, "No entries found in dataset " & dir

  let k = raw.optimalK
  echo fmt"Dataset {dir}: {raw.len} entries, " &
    fmt"k = {k:.4f} (score prediction error: {raw.scorePredictionError(k):.5f}), " &
    fmt"score target weight = {scoreTargetWeight}"

  for entry in raw:
    data.add Entry(
      position: entry.position,
      outcome:
        (1.0 - scoreTargetWeight) * entry.outcome +
        scoreTargetWeight * entry.score.winningProbability(k),
    )

proc error*(params: EvalParameters, data: openArray[Entry]): float =
  doAssert data.len > 0
  for entry in data:
    result += error(entry.outcome, entry.position.eval(params).winningProbability)
  result /= data.len.float

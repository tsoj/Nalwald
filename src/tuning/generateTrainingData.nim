import
  ../position,
  ../hashTable,
  ../evaluation,
  ../search,
  ../positionUtils,
  ../version,
  winningProbability,
  game

import malebolgia

import std/[random, locks, atomics, streams, strformat, times, cpuinfo, strutils, os]

doAssert commandLineParams().len == 3,
  "Need the following parameters in that order (int, int, bool): sampleGameSearchNodes targetTrainingSamples useOnlyHalfCPU"

let
  sampleGameSearchNodes = commandLineParams()[0].parseInt
  targetTrainingSamples = commandLineParams()[1].parseInt
  useOnlyHalfCPU = commandLineParams()[2].parseBool

doAssert not useOnlyHalfCPU or ThreadPoolSize <= max(1, countProcessors() div 2),
  "To use only half half of the CPU, the program must be compiled with the switch \"--define:halfCPU\""

const
  openingFilename = "res/openings/Pohl.epd"
  randRatio = 0.0005
  ratioGameResultSearchValue = 0.5
  sampleGameMinLenPly = 5
  sampleFrequencyInGamePly = 30 .. 40
  earlyResignMargin = 500.cp

doAssert not gitHasUnstagedChanges,
  "Shouldn't do training data generation with unstaged changes"

let
  startDate = now().format("yyyy-MM-dd-HH-mm-ss")
  outDir = "res/data/"
  outputFilename =
    fmt"{outDir}trainingSet_{startDate}_{sampleGameSearchNodes}_{versionOrId()}.bin"

createDir outDir
doAssert not fileExists outputFilename,
  "Can't overwrite existing file: " & outputFilename

func isValidSamplePosition(position: Position): bool =
  position.material == position.materialQuiesce and position.legalMoves.len > 0 and
    position.halfmoveClock < 20 # otherwise the position is probably just shuffling

proc playGameAndCollectTrainingSamples(
    startPos: Position, hashTable: ref HashTable
): seq[(Position, float)] =
  const
    earlyAdjudicationMinConsistentPly = 6
    minAdjudicationGameLenPly = 0

  var game = newGame(
    startingPosition = startPos,
    maxNodes = sampleGameSearchNodes,
    earlyResignMargin = earlyResignMargin,
    earlyAdjudicationMinConsistentPly = earlyAdjudicationMinConsistentPly,
    minAdjudicationGameLenPly = minAdjudicationGameLenPly,
    hashTable = hashTable,
  )
  let
    gameResult = game.playGame
    positionHistory = game.getPositionHistory

  var
    rg = initRand()
    index = 0

  while index < positionHistory.len - sampleGameMinLenPly:
    let
      (position, value) = positionHistory[index]
      searchWinningProb = value.winningProbability

    if position.isValidSamplePosition:
      let label =
        ratioGameResultSearchValue * gameResult +
        (1.0 - ratioGameResultSearchValue) * searchWinningProb

      result.add (position, label)
      index += rg.rand(sampleFrequencyInGamePly)
    else:
      index += 1

let
  openingPositions = block:
    let f = open(openingFilename)
    var
      lines: seq[string]
      line: string
    while f.readLine(line):
      lines.add line
    var rg = initRand()
    rg.shuffle(lines)
    lines
  expectedNumberSamplesPerOpening = targetTrainingSamples div openingPositions.len

var
  outFileStream = newFileStream(outputFilename, fmWrite)
  outFileMutex = Lock()
  openingSearchNodes: Atomic[float]
initLock outFileMutex

doAssert not outFileStream.isNil, "Filename: " & outputFilename

const expectedNumPliesPerGame = 120
# This is just a first very rough guess:
openingSearchNodes.store(
  targetTrainingSamples.float /
    (expectedNumPliesPerGame.float * randRatio * openingPositions.len.float)
)

echo fmt"{targetTrainingSamples = }"
echo fmt"{sampleGameSearchNodes = }"
echo fmt"{openingSearchNodes.load = }"
echo fmt"{openingPositions.len = }"
echo fmt"{expectedNumberSamplesPerOpening = }"

proc findStartPositionsAndPlay(startPos: Position, stringIndex: string) =
  try:
    var
      rg = initRand()
      numSamples = 0

    {.warning[ProveInit]: off.}:
      var sampleGameHashTable = new HashTable
    sampleGameHashTable[] = newHashTable(len = sampleGameSearchNodes * 2)

    func specialEval(position: Position): Value =
      result = position.evaluate
      {.cast(noSideEffect).}:
        if rg.rand(1.0) <= randRatio and position.isValidSamplePosition:
          let samples = position.playGameAndCollectTrainingSamples(sampleGameHashTable)
          numSamples += samples.len

          withLock outFileMutex:
            for (position, value) in samples:
              outFileStream.writePosition position
              outFileStream.write value
              outFileStream.flush

    var game = newGame(
      startingPosition = startPos,
      maxNodes = openingSearchNodes.load.int,
      earlyResignMargin = 400.cp,
      earlyAdjudicationMinConsistentPly = 8,
      minAdjudicationGameLenPly = 20,
      hashTable = nil,
      evaluation = specialEval,
    )
    discard game.playGame

    echo fmt"Finished opening {stringIndex}, {numSamples = }"

    openingSearchNodes.store openingSearchNodes.load *
      clamp(expectedNumberSamplesPerOpening.float / numSamples.float, 0.99, 1.01)
  except Exception:
    echo "ERROR: EXCEPTION: ", getCurrentExceptionMsg()
    quit(QuitFailure)

let startTime = now()

var threadpool = createMaster()

threadpool.awaitAll:
  for i, fen in openingPositions:
    let
      position = fen.toPosition
      stringIndex = fmt"{i+1}/{openingPositions.len}"
    threadpool.spawn position.findStartPositionsAndPlay(stringIndex)

echo "Total time: ", now() - startTime

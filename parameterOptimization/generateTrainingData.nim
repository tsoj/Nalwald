

import
    ../position,
    ../hashTable,
    ../evaluation,
    ../search,
    ../positionUtils,
    winningProbability,
    game

import malebolgia

import std/[
    os,
    random,
    locks,
    atomics,
    streams,
    strformat,
    times,
    cpuinfo
]



const
    openingFilename = "10ply-openings.epd"
    targetTrainingSamples = 100_000_000
    openingSearchNodes = 50_000
    sampleGameSearchNodes = 10_000
    sampleGameMinLenPly = 20 # shorter games are probably from trivial positions
    sampleFrequencyInGamePly = 30..40

let
    startDate = now().format("yyyy-MM-dd-HH-mm-ss")
    outputFilename = fmt"trainingSet_{startDate}.bin"

func isValidSamplePosition(position: Position): bool =
    position.material == position.materialQuiesce and
    position.legalMoves.len > 0 and
    position.halfmoveClock < 20 # otherwise the position is probably just shuffling

proc playGameAndCollectTrainingSamples(startPos: Position, hashTable: ref HashTable): seq[(Position, float)] =
    const
        earlyAdjudicationMinConsistentPly = 6
        minAdjudicationGameLenPly = 0
    static: doAssert earlyAdjudicationMinConsistentPly <= sampleGameMinLenPly - 2, "This is necessary to avoid including trivial positions in the training set"
    static: doAssert minAdjudicationGameLenPly <= earlyAdjudicationMinConsistentPly - 2, "This is necessary to avoid including trivial positions in the training set"

    var game = newGame(
        startingPosition = startPos,
        maxNodes = sampleGameSearchNodes,
        earlyResignMargin = 500.cp,
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
            searchWinningProb = value.winningProbability(k = 1.0)

        if position.isValidSamplePosition:
            result.add (position, (searchWinningProb + gameResult)/2.0)
            index += rg.rand(sampleFrequencyInGamePly)
        else:
            index += 1

let
    openingLines = block:
        let f = open(openingFilename)
        var
            lines: seq[string]
            line: string
        while f.readLine(line):
            lines.add line
        var rg = initRand()
        rg.shuffle(lines)
        lines
    expectedNumberSamplesPerOpening = targetTrainingSamples div openingLines.len

var
    outFileStream = newFileStream(outputFilename, fmWrite)
    outFileMutex = Lock()
initLock outFileMutex

var randRatio: Atomic[float]
const expectedNumPliesPerGame = 120
# This is just a first very rough guess:
randRatio.store(targetTrainingSamples.float / (expectedNumPliesPerGame.float * openingSearchNodes.float * openingLines.len.float))

echo fmt"{openingLines.len = }"
echo fmt"{expectedNumberSamplesPerOpening = }"


proc findStartPositionsAndPlay(startPos: Position, stringIndex: string) =
    var
        rg = initRand()
        numSamples = 0

    
    {.warning[ProveInit]:off.}:
        var sampleGameHashTable = new HashTable
    sampleGameHashTable[] = newHashTable(len = sampleGameSearchNodes*2)


    func specialEval(position: Position): Value =
        result = position.evaluate
        {.cast(noSideEffect).}:
            if rg.rand(1.0) <= randRatio.load and position.isValidSamplePosition:
                let samples = position.playGameAndCollectTrainingSamples(sampleGameHashTable)
                numSamples += samples.len

                withLock outFileMutex:
                    for (position, value) in samples:
                        outFileStream.writePosition position
                        outFileStream.write value
                        outFileStream.flush


    var game = newGame(
        startingPosition = startPos,
        maxNodes = openingSearchNodes,
        earlyResignMargin = 400.cp,
        earlyAdjudicationMinConsistentPly = 8,
        minAdjudicationGameLenPly = 20,
        hashTable = nil,
        evaluation = specialEval
    )
    discard game.playGame

    echo fmt"Finished opening {stringIndex}, {numSamples = }"

    randRatio.store randRatio.load*clamp(expectedNumberSamplesPerOpening.float/numSamples.float, 0.99, 1.01)

let startTime = now()

var threadpool = createMaster()

threadpool.awaitAll:
    for i, fen in openingLines:
        let
            position = fen.toPosition
            stringIndex = fmt"{i+1}/{openingLines.len}"
        threadpool.spawn position.findStartPositionsAndPlay(stringIndex)

echo "Total time: ", now() - startTime



import
    ../position,
    ../hashTable,
    ../evaluation,
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
    times
]



const
    openingFilename = "10ply-openings.epd"
    outputFilename = "trainingSet.bin"
    targetTrainingSamples = 100_000_000
    openingSearchNodes = 50_000
    sampleGameSearchNodes = 10_000
    sampleGameMinLenPly = 10
    sampleFrequencyInGamePly = 25..35

if fileExists outputFilename:
    var backupFileName = outputFilename
    while fileExists backupFileName:
        backupFileName &= "_backup"
    moveFile outputFilename, backupFileName

doAssert not fileExists outputFilename

proc playGameAndCollectTrainingSamples(startPos: Position, hashTable: ref HashTable): seq[(Position, float)] =
    var game = newGame(
        startingPosition = startPos,
        maxNodes = sampleGameSearchNodes,
        earlyResignMargin = 600.Value,
        earlyAdjudicationMinConsistentPly = 8,
        minAdjudicationGameLenPly = 20,
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
        result.add (position, (searchWinningProb + gameResult)/2.0)
        index += rg.rand(sampleFrequencyInGamePly)

let
    openingLines = block:
        let f = open(openingFilename)
        var
            lines: seq[string]
            line: string
        while f.readLine(line):
            lines.add line
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


proc findStartPositionsAndPlay(startPos: Position) =
    var
        rg = initRand()
        numSamples = 0

    echo fmt"{randRatio.load = }"

    
    {.warning[ProveInit]:off.}:
        var sampleGameHashTable = new HashTable
    sampleGameHashTable[] = newHashTable(len = sampleGameSearchNodes*2)


    func specialEval(position: Position): Value =
        result = position.evaluate
        {.cast(noSideEffect).}:
            if rg.rand(1.0) <= randRatio.load:
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
        earlyResignMargin = 600.Value,
        earlyAdjudicationMinConsistentPly = 8,
        minAdjudicationGameLenPly = 20,
        hashTable = nil,
        evaluation = specialEval
    )
    discard game.playGame

    echo fmt"{numSamples = }"

    randRatio.store randRatio.load*(expectedNumberSamplesPerOpening.float/numSamples.float)

# var threadpool = createMaster()


# let g = open(writeFilename, fmWrite)

# proc playGame

let startTime = now()

for fen in openingLines[0..1]:
    let position = fen.toPosition
    position.findStartPositionsAndPlay    

echo "Total time: ", now() - startTime

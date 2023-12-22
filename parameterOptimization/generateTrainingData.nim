

import
    ../position,
    ../hashTable,
    ../evaluation,
    ../search,
    ../positionUtils,
    winningProbability,
    game

import taskpools

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
    openingSearchNodes = 20_000
    sampleGameSearchNodes = 8_000
    sampleGameMinLenPly = 20 # shorter games are probably from trivial positions
    sampleFrequencyInGamePly = 30..40
    earlyResignMargin = 500.cp
    addSearchEvalToLabel = false
    numConsideredMovesPerPosition = 1 # TODO use
    consideredMovesDecay = 0.9

let
    startDate = now().format("yyyy-MM-dd-HH-mm-ss")
    outputFilename = fmt"trainingSet_{startDate}.bin"

func isValidSamplePosition(position: Position): bool =
    position.material == position.materialQuiesce and
    position.legalMoves.len > 0 and
    position.halfmoveClock < 20 # otherwise the position is probably just shuffling

proc playGameAndCollectTrainingSamplesMultipleMoves(startPos: Position, hashTable: ref HashTable): seq[(Position, float)] =
    doAssert numConsideredMovesPerPosition > 1
    const
        earlyAdjudicationMinConsistentPly = 6
        minAdjudicationGameLenPly = 0
    static: doAssert earlyAdjudicationMinConsistentPly <= sampleGameMinLenPly - 2, "This is necessary to avoid including trivial positions in the training set"
    static: doAssert minAdjudicationGameLenPly <= earlyAdjudicationMinConsistentPly - 2, "This is necessary to avoid including trivial positions in the training set"

    var
        moves = startPos.legalMoves
        weightSum = 0.0
        sum = 0.0

    for i in 1..numConsideredMovesPerPosition:
        pvSeq = position.timeManagedSearch(
            hashTable = hashTable,
            maxNodes = sampleGameSearchNodes
            searchMoves = moves
        )
        doAssert pvSeq.len >= 1
        let pv = pvSeq[0].pv
        doAssert pv.len >= 1
        doAssert pv[0] != noMove
        
        let move = pv[0]
        

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
            searchWinningProb = value.winningProbability(k = 1.0)

        if position.isValidSamplePosition:
            let label = when addSearchEvalToLabel:
                (gameResult + searchWinningProb) / 2.0
            else:
                gameResult
            
            result.add (position, label)
            index += rg.rand(sampleFrequencyInGamePly)
        else:
            index += 1

proc playGameAndCollectTrainingSamples(startPos: Position, hashTable: ref HashTable): seq[(Position, float)] =
    const
        earlyAdjudicationMinConsistentPly = 6
        minAdjudicationGameLenPly = 0
    static: doAssert earlyAdjudicationMinConsistentPly <= sampleGameMinLenPly - 2, "This is necessary to avoid including trivial positions in the training set"
    static: doAssert minAdjudicationGameLenPly <= earlyAdjudicationMinConsistentPly - 2, "This is necessary to avoid including trivial positions in the training set"

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
            searchWinningProb = value.winningProbability(k = 1.0)

        if position.isValidSamplePosition:
            let label = when addSearchEvalToLabel:
                (gameResult + searchWinningProb) / 2.0
            else:
                gameResult
            
            result.add (position, label)
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
    try:
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
    
    except Exception:
        echo "ERROR: EXCEPTION: ", getCurrentExceptionMsg()

let startTime = now()


var threadpool = Taskpool.new(numThreads = 30)

for i, fen in openingLines:
    let
        position = fen.toPosition
        stringIndex = fmt"{i+1}/{openingLines.len}"
    threadpool.spawn position.findStartPositionsAndPlay(stringIndex)

threadpool.syncAll()

echo "Total time: ", now() - startTime

import
    ../evalParameters,
    gradient,
    dataUtils,
    calculatePieceValue

import std/[
    times,
    strformat,
    threadpool,
    random
]

type ThreadResult = tuple[weight: float, gradient: EvalParametersFloat]

proc calculateGradient(data: openArray[Entry], currentSolution: EvalParameters, k: float, suppressOutput = false): ThreadResult =
    result.gradient = newEvalParametersFloat();
    for entry in data:        
        result.weight += 1.0
        result.gradient.addGradient(currentSolution, entry.position, entry.outcome, k = k)

proc optimize(
    start: EvalParametersFloat,
    data: var seq[Entry],
    k: float,
    lr = 500_000.0,
    lrDecay = 0.8,
    maxNumEpochs = 20,
    gradientDecay = 0.9,
    numThreads = 8,
    batchSize = 60_000
): EvalParametersFloat =

    var
        solution = start
        lr = lr

    echo "starting error: ", fmt"{solution.convert.error(data, k):>9.7f}", ", starting lr: ", lr

    var previousGradient = newEvalParametersFloat()

    for epoch in 1..maxNumEpochs:
        let startTime = now()
        data.shuffle
        for batchId in 0..<data.len div batchSize:
            let data = data[batchId*batchSize..<min(data.len, (batchId+1)*batchSize)]

            func batchSlize(data: openArray[Entry], i: int, numThreads: int): auto =
                let
                    batchSlizeSize = data.len div numThreads
                    b = data.len mod numThreads + (i+1)*batchSlizeSize
                    a = if i == 0: 0 else: b - batchSlizeSize
                doAssert b > a
                doAssert i < numThreads - 1 or b == data.len
                doAssert i == 0 or b - a == batchSlizeSize
                doAssert i > 0 or b - a == batchSlizeSize + data.len mod numThreads
                doAssert b <= data.len
                data[a..<b]

            var threadSeq = newSeq[FlowVar[ThreadResult]](numThreads)
            
            let solutionConverted = solution.convert
            for i, flowVar in threadSeq.mpairs:
                flowVar = spawn calculateGradient(
                    data.batchSlize(i, numThreads),
                    solutionConverted,
                    k, i > 0
                )

            var gradient = newEvalParametersFloat()
            var totalWeight: float = 0.0
            for flowVar in threadSeq.mitems:
                let (threadWeight, threadGradient) = ^flowVar
                totalWeight += threadWeight
                gradient += threadGradient
            # smooth the gradient out over previous gradientDecayed gradients. Seems to help in optimization speed and the final
            # result is better
            gradient *= (1.0/totalWeight)
            gradient *= 1.0 - gradientDecay
            previousGradient *= gradientDecay
            gradient += previousGradient
            previousGradient = gradient

            gradient *= lr

            solution += gradient

        let
            error = solution.convert.error(data[0..<min(data.len, 1_000_000)], k)
            passedTime = now() - startTime
        echo fmt"Epoch {epoch}, error: {error:>9.7f}, lr: {lr:.1f}, batch size: {batchSize}, time: {passedTime.inSeconds} s"
        lr *= lrDecay
    
    let finalError = solution.convert.error(data, k)
    echo fmt"Final error: {finalError:>9.7f}"
        
    return solution

let startTime = now()

var data: seq[Entry]
data.loadDataEpd "quietSetNalwald.epd"
data.loadDataEpd "quietSetCombinedCCRL4040.epd"
data.loadDataEpd "quietSmallPoolGamesNalwald.epd"
data.loadDataEpd "quietSetNalwald2.epd"
data.loadDataEpd "quietLeavesSmallPoolGamesNalwaldSearchLabeled.epd"
data.loadDataEpd "quietSmallPoolGamesNalwald2Labeled.epd"
data.loadDataEpd "quietSmallPoolGamesNalwald3.epd"
data.loadDataEpd "quietSmallPoolGamesNalwald4.epd"
data.loadDataEpd "quietSmallPoolGamesNalwald5.epd"
data.loadDataEpd "quietSmallPoolGamesNalwald6.epd"
data.loadDataEpd "quietSmallPoolGamesNalwald7.epd"

data.loadDataBin "trainingSet_2023-10-03-18-29-44.bin"
data.loadDataBin "trainingSet_2023-10-03-18-30-48.bin"
data.loadDataBin "trainingSet_2023-10-03-23-14-51.bin"
data.loadDataBin "trainingSet_2023-10-03-23-35-01.bin"
data.loadDataBin "trainingSet_2023-10-04-00-47-53.bin"
data.loadDataBin "trainingSet_2023-10-06-17-43-01.bin"
data.shuffle

echo "Total number of entries: ", data.len

const k = 1.0

let ep = newEvalParametersFloat().optimize(data, k)

let fileName = "optimizationResult_" & now().format("yyyy-MM-dd-HH-mm-ss") & ".txt"
let fileContent = &"""
import evalParameters

const defaultEvalParameters* = {ep.convert.toSeq}.toEvalParameters

func value*(piece: Piece): Value =
    const table = [{ep.convert.pieceValuesAsString(data[0..<min(data.len, 10_000_000)])}king: valueCheckmate, noPiece: 0.Value]
    table[piece]
"""

writeFile(fileName, fileContent)
echo "filename: ", fileName

echo "Total time: ", now() - startTime


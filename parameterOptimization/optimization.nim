import
    ../evalParameters,
    gradient,
    dataUtils,
    calculatePieceValue

import std/[
    times,
    strformat,
    threadpool,
    random,
    math
]

type ThreadResult = tuple[weight: float, gradient: EvalParametersFloat]

proc calculateGradient(data: openArray[Entry], currentSolution: EvalParameters, suppressOutput = false): ThreadResult =
    result.gradient = newEvalParametersFloat();
    for entry in data:        
        result.weight += 1.0
        result.gradient.addGradient(currentSolution, entry.position, entry.outcome)

proc updateParams(params, momentum, secondMomentum: var EvalParametersFloat, timeStep: var int, gradient: EvalParametersFloat, beta1, beta2, alpha: float32) =
    
    # Adam optimizer

    doAssert timeStep >= 1
    doForAll(momentum, gradient, proc(m: var float32, g: float32) =
        m = m*beta1 + (1.0 - beta1)*g
    )
    doForAll(secondMomentum, gradient, proc(v: var float32, g: float32) =
        v = v*beta2 + (1.0 - beta2)*g*g
    )
    var update = newEvalParametersFloat()
    let t = timeStep.float32
    doForAll(update, momentum, proc(u: var float32, m: float32) =
        u = alpha * m / (1.0 - pow(beta1, t))
    )
    doForAll(update, secondMomentum, proc(u: var float32, v: float32) =
        u /= float32(sqrt(v/(1.0 - pow(beta2, t))) + 1e-8)
    )

    params += update

    timeStep += 1

proc optimize(
    start: EvalParametersFloat,
    data: var seq[Entry],
    beta1 = 0.9,
    beta2 = 0.999,
    alpha = 0.1,
    lrDecay = 0.98,
    maxNumEpochs = 40,
    numThreads = 8,
    batchSize = 100_000
): EvalParametersFloat =

    var solution = start

    echo "starting error: ", fmt"{solution.convert.error(data):>9.7f}", ", starting lr: ", alpha

    var
        momentum = newEvalParametersFloat()
        secondMomentum = newEvalParametersFloat()
        timeStep = 1
        alpha = alpha

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
                    solutionConverted, i > 0
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
            
            solution.updateParams(momentum, secondMomentum, timeStep, gradient, beta1, beta2, alpha)

            # gradient *= 1.0 - gradientDecay
            # previousGradient *= gradientDecay
            # gradient += previousGradient
            # previousGradient = gradient

            # gradient *= lr

            # solution += gradient

        let
            error = solution.convert.error(data[0..<min(data.len, 1_000_000)])
            passedTime = now() - startTime
        echo fmt"Epoch {epoch}, error: {error:>9.7f}, lr: {alpha:.3f}, batch size: {batchSize}, time: {passedTime.inSeconds} s"
        alpha *= lrDecay
    
    let finalError = solution.convert.error(data)
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
data.loadDataEpd "selected2.epd"

data.loadDataBin "trainingSet_2023-10-03-18-29-44.bin"
data.loadDataBin "trainingSet_2023-10-03-18-30-48.bin"
data.loadDataBin "trainingSet_2023-10-03-23-14-51.bin"
data.loadDataBin "trainingSet_2023-10-03-23-35-01.bin"
data.loadDataBin "trainingSet_2023-10-04-00-47-53.bin"
data.loadDataBin "trainingSet_2023-10-06-17-43-01.bin"
data.loadDataBin "trainingSet_2023-12-22-16-08-28.bin"
data.loadDataBin "trainingSet_2023-12-22-16-15-24.bin"
data.loadDataBin "trainingSet_2023-12-22-16-16-28.bin"
data.loadDataBin "trainingSet_2023-12-22-19-19-13.bin"
data.loadDataBin "trainingSet_2023-12-24-02-31-35.bin"
data.loadDataBin "trainingSet_2023-12-28-11-23-21.bin"
data.shuffle

echo "Total number of entries: ", data.len

let ep = newEvalParametersFloat().optimize(data)

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


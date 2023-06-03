import
    ../evalParameters,
    winningProbability,
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
    result.gradient.init()
    for entry in data:        
        result.weight += entry.weight
        result.gradient.addGradient(currentSolution, entry.position, entry.outcome, k = k, weight = entry.weight)

proc optimize(
    start: EvalParametersFloat,
    data: seq[Entry],
    k: float,
    lr = 51200.0,
    lrDecay = 0.98,
    minLearningRate = 500.0,
    maxNumEpochs = 300,
    discount = 0.9,
    numThreads = 30,
    batchSize = 50_000
): EvalParametersFloat =

    var
        solution = start
        lr = lr
        data = data

    echo "starting error: ", fmt"{solution.convert.error(data, k):>9.7f}", ", starting lr: ", lr

    var previousGradient: EvalParametersFloat
    previousGradient.init()

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

            var gradient: EvalParametersFloat
            gradient.init()
            var totalWeight: float = 0.0
            for flowVar in threadSeq.mitems:
                let (threadWeight, threadGradient) = ^flowVar
                totalWeight += threadWeight
                gradient += threadGradient
            # smooth the gradient out over previous discounted gradients. Seems to help in optimization speed and the final
            # result is better
            gradient *= (1.0/totalWeight)
            gradient *= 1.0 - discount
            previousGradient *= discount
            gradient += previousGradient
            previousGradient = gradient

            gradient *= lr

            solution += gradient

        let passedTime = now() - startTime
        echo fmt"Epoch {epoch}, error: {solution.convert.error(data, k):>9.7f}, lr: {lr:.1f}, time: {passedTime.inSeconds} s"
        lr *= lrDecay

        if lr < minLearningRate:
            break
        
    return solution

let startTime = now()

var data: seq[Entry]
data.loadData("quietSetZuri.epd")
data.loadData("quietSetNalwald.epd")
data.loadData("quietSetCombinedCCRL4040.epd")
data.loadData("quietSmallPoolGamesNalwald.epd")
data.loadData("quietSetNalwald2.epd")
data.loadData("quietLeavesSmallPoolGamesNalwaldSearchLabeled.epd")

echo "Total number of entries: ", data.len


echo "-------------------"
let k = 0.75#optimizeK(getError = proc(k: float): float = startingEvalParameters.convert.error(data, k))
echo "-------------------"

var emptyStartParams: EvalParametersFloat
emptyStartParams.init()

let ep = emptyStartParams.optimize(data, k)

let filename = "optimizationResult_" & now().format("yyyy-MM-dd-HH-mm-ss") & ".txt"
echo "filename: ", filename
writeFile(
    filename,
    &"import evalParameters\n\nconst defaultEvalParameters* = {ep.convert}.convert(EvalParameters)\n"
)
printPieceValues(ep.convert)

echo "Total time: ", now() - startTime


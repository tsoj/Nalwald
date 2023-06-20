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
    result.gradient = newEvalParamatersFloat();
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
    numThreads = 10,
    batchSize = 50_000
): EvalParametersFloat =

    var
        solution = start
        lr = lr
        data = data

    echo "starting error: ", fmt"{solution.convert.error(data, k):>9.7f}", ", starting lr: ", lr

    var previousGradient = newEvalParamatersFloat()

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

            var gradient = newEvalParamatersFloat()
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

        let
            errorString = if (epoch mod 20) == 0: fmt"{solution.convert.error(data, k):>9.7f}" else: "        ?"
            passedTime = now() - startTime
        echo fmt"Epoch {epoch}, error: {errorString}, lr: {lr:.1f}, time: {passedTime.inSeconds} s"
        lr *= lrDecay

        if lr < minLearningRate:
            break
        
    return solution

let startTime = now()

var data: seq[Entry]
data.loadData("quietSetNalwald.epd")
data.loadData("quietSetCombinedCCRL4040.epd")
data.loadData("quietSmallPoolGamesNalwald.epd")
data.loadData("quietSetNalwald2.epd")
data.loadData("quietLeavesSmallPoolGamesNalwaldSearchLabeled.epd")
data.loadData("quietSmallPoolGamesNalwald2Labeled.epd", weight = 2.0)

echo "Total number of entries: ", data.len


const k = 1.0

let ep = newEvalParamatersFloat().optimize(data, k)

let filename = "optimizationResult_" & now().format("yyyy-MM-dd-HH-mm-ss") & ".txt"
echo "filename: ", filename
writeFile(
    filename,
    &"import evalParameters\n\nconst defaultEvalParameters* = {ep.convert}.convert(EvalParameters)\n"
)
printPieceValues(ep.convert, data)

echo "Total time: ", now() - startTime


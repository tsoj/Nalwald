import
    ../evalParameters,
    startingParameters,
    winningProbability,
    gradient,
    dataUtils,
    calculatePieceValue

import std/[
    times,
    strformat,
    terminal,
    threadpool
]

type ThreadResult = tuple[weight: float, gradient: EvalParametersFloat]

proc calculateGradient(data: openArray[Entry], currentSolution: ptr EvalParameters, k: float, suppressOutput = false): ThreadResult =
    const numProgressBarPoints = 100
    if not suppressOutput:
        eraseLine()
        stdout.write("[")
        for p in 1..numProgressBarPoints:
            stdout.write("-")
        stdout.write("]")
        setCursorXPos(1)
        stdout.flushFile
    var p = 0
    for entry in data:
        p += 1
        if p mod (data.len div numProgressBarPoints) == 0 and not suppressOutput:
            stdout.write("#")
            stdout.flushFile
        
        result.weight += entry.weight
        result.gradient.addGradient(currentSolution[], entry.position, entry.outcome, k = k, weight = entry.weight)

proc optimize(
    start: EvalParametersFloat,
    data: seq[Entry],
    k: float,
    lr = 25600.0,
    minLearningRate = 500.0,
    maxIterations = int.high,
    minTries = 2,
    discount = 0.9,
    numThreads = 30
): (EvalParametersFloat, float) =

    var
        bestSolution = start
        lr = lr
        decreaseLr = true
        bestError = bestSolution.convert[].error(data, k)

    echo "starting error: ", fmt"{bestError:>9.7f}", ", starting lr: ", lr

    var previousGradient: EvalParametersFloat 
    for j in 0..<maxIterations:
        let startTime = now()
        var currentSolution = bestSolution

        func batchSlize(i: int, data: openArray[Entry]): auto =
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
        
        let bestSolutionConverted = bestSolution.convert
        for i, flowVar in threadSeq.mpairs:
            flowVar = spawn calculateGradient(
                i.batchSlize(data),
                bestSolutionConverted[].addr,
                k, i > 0
            )    

        var gradient: EvalParametersFloat
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

        let oldBestError = bestError
        
        eraseLine()
        stdout.write("iteration: " & fmt"{j:>3}")
        stdout.flushFile

        var leftTries = minTries
        var successes = 0
        var tries = 0
        while leftTries > 0:

            currentSolution += gradient

            let currentSolutionConverted = currentSolution.convert
            var errors = newSeq[FlowVar[tuple[error, summedWeight: float]]](numThreads)
            for i, error in errors.mpairs:
                error = spawn errorTuple(currentSolutionConverted[], i.batchSlize(data), k)
            var
                error: float = 0.0
                summedWeight: float = 0.0
            for e in errors.mitems:
                let r = ^e
                error += r.error
                summedWeight += r.summedWeight
            error /= summedWeight

            tries += 1                    
            if error < bestError:
                if leftTries <= 10:
                    leftTries += 1
                successes += 1

                bestError = error
                bestSolution = currentSolution
            else:
                leftTries -= 1
            
            # print info
            eraseLine()
            let s = $successes & "/" & $tries
            let passedTime = now() - startTime
            stdout.write(
                "iteration: ", fmt"{j:>3}", ", successes: ", fmt"{s:>9}",
                ", error: ", fmt"{bestError:>9.7f}", ", lr: ", lr, ", time: ", $passedTime.inSeconds, " s"
            )
            stdout.flushFile
        
        stdout.write("\n")
        stdout.flushFile

        if oldBestError <= bestError and lr >= minLearningRate:
            previousGradient *= 0.5
            if decreaseLr:
                lr /= 2.0
            else:
                decreaseLr = true
        else:
            decreaseLr = false

        if lr < minLearningRate:
            break
        
    return (bestSolution, bestError)

var data: seq[Entry]
data.loadData("quietSetZuri.epd")
data.loadData("quietSetNalwald.epd")
data.loadData("quietSetCombinedCCRL4040.epd")
data.loadData("quietSmallPoolGamesNalwald.epd")
data.loadData("quietSetNalwald2.epd")
data.loadData("quietLeavesSmallPoolGamesNalwaldSearchLabeled.epd")

echo "Total number of entries: ", data.len


echo "-------------------"
let k = optimizeK(getError = proc(k: float): float = startingEvalParameters.convert[].error(data, k))
echo "-------------------"

let (ep, _) = startingEvalParameters.optimize(data, k)

let filename = "optimizationResult_" & now().format("yyyy-MM-dd-HH-mm-ss") & ".txt"
echo "filename: ", filename
writeFile(
    filename,
    &"import evalParameters\n\nconst defaultEvalParameters* = {ep.convert[]}.convert(EvalParameters)\n"
)
printPieceValues(ep.convert[])


import position
import evalParameters
import strutils
import types
import evaluation
import utils
import gradient
import random
import defaultParameters
import times
import strformat

type Entry = object
    position: Position
    outcome: float32

proc loadData(filename: string): seq[Entry] =
    let f = open(filename)
    var line: string
    while f.readLine(line):
        let words = line.splitWhitespace()
        doAssert words.len >= 7
        result.add(Entry(position: line.toPosition(suppressWarnings = true), outcome: words[6].parseFloat))
    f.close()

    debugEcho "data.len: ", result.len


func error(evalParameters: EvalParameters, data: openArray[Entry]): float32 =
    result = 0.0
    
    for entry in data:
        let estimate = entry.position.absoluteEvaluate(evalParameters).winningProbability
        result += (entry.outcome - estimate)*(entry.outcome - estimate)
    result /= data.len.float32

proc optimize(
    start: EvalParametersFloat,
    data: seq[Entry],
    lr = 1000.0,
    minLearningRate = 10.0,
    maxIterations = int.high,
    batchSize = 750000,
    numReIterations = 100,
    randomAdditions = 15.0
): EvalParameters =
    let batchSize = min(batchSize, data.len)


    var finalSolution: EvalParametersFloat
    var finalError = float32.high

    var bestSolution: EvalParametersFloat = start
    for reIteration in 0..<numReIterations:

        debugEcho "-------------------"
        debugEcho "batchsize: ", batchSize

        var lr = lr
        var bestError = bestSolution.convert.error(data)
        debugEcho "starting error: ", fmt"{bestError:>9.7f}", ", starting lr: ", lr

        for j in 0..maxIterations:
            var shuffledData = data
            shuffledData.shuffle()
            var numBatches = shuffledData.len div batchSize
            if shuffledData.len mod batchSize != 0:
                numBatches += 1

            for i in 0..<numBatches:
                var gradient: EvalParametersFloat
                var currentSolution = bestSolution
                let bestSolutionConverted = bestSolution.convert
                for entry in shuffledData.toOpenArray(
                    first = i*batchSize,
                    last = min((i+1)*batchSize - 1, shuffledData.len - 1)
                ):
                    gradient.addGradient(bestSolutionConverted, entry.position, entry.outcome)
                gradient *= (lr/batchSize.float32)
                currentSolution += gradient

                var error = currentSolution.convert.error(data)
                
                debugEcho(
                    "iteration: ", fmt"{j:>3}", ", batch: ", i, "/", numBatches - 1,
                    ", error: ", fmt"{error:>9.7f}", ", lr: ", lr
                )

                if error >= bestError and lr >= minLearningRate:
                    lr /= 2.0

                gradient *= 0.5
                while error < bestError:
                    bestError = error
                    bestSolution = currentSolution

                    currentSolution += gradient
                    error = currentSolution.convert.error(data)

                    if error < bestError:
                        debugEcho(
                            "iteration:   ↺, batch: ", i, "/", numBatches - 1,
                            ", error: ", fmt"{error:>9.7f}", ", lr: ", lr*0.5
                        )


            if lr < minLearningRate:
                break;
        
        if bestError <= finalError:
            finalSolution = bestSolution
            finalError = bestError
            let filename = now().format("yyyy-MM-dd-HH-mm-ss") & "_optimizationResult.txt"
            debugEcho "filename: ", filename
            writeFile(filename, $finalSolution.convert)

        bestSolution = finalSolution
        bestSolution.randomEvalParametersFloat(randomAdditions)
        
    return finalSolution.convert

#echo defaultEvalParametersFloat.convert

let data = "zuri_quiet.epd".loadData

discard defaultEvalParametersFloat.optimize(data)


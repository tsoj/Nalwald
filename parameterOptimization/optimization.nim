import ../position
import ../evalParameters
import evalParametersUtils
import strutils
import ../evaluation
import ../utils
import gradient
import random
import times
import strformat
import ../defaultParameters
import startingParameters
import dataUtils

proc optimize(
    start: EvalParametersFloat,
    data: seq[Entry],
    lr = 1000.0,
    minLearningRate = 10.0,
    maxIterations = int.high,
    batchSize = int.high,
    # Only one optimization run to omit over specialization.
    numReIterations = 1,
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
                var batchWeight: float32 = 0.0
                for entry in shuffledData.toOpenArray(
                    first = i*batchSize,
                    last = min((i+1)*batchSize - 1, shuffledData.len - 1)
                ):
                    batchWeight += entry.weight
                    gradient.addGradient(bestSolutionConverted, entry.position, entry.outcome, weight = entry.weight)
                gradient *= (lr/batchWeight)
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
                            "             ↺, batch: ", i, "/", numBatches - 1,
                            ", error: ", fmt"{error:>9.7f}", ", lr: ", lr*0.5
                        )

                if lr < minLearningRate:
                    break

            if lr < minLearningRate:
                break
        
        if bestError <= finalError:
            finalSolution = bestSolution
            finalError = bestError
            let filename = "optimizationResult_" & now().format("yyyy-MM-dd-HH-mm-ss") & ".txt"
            debugEcho "filename: ", filename
            writeFile(filename, $finalSolution.convert)

        bestSolution = finalSolution
        bestSolution.randomEvalParametersFloat(randomAdditions)
        
    return finalSolution.convert


var data: seq[Entry]
data.loadData("quietSetZuri.epd", weight = 1.0)
data.loadData("quietSetNalwald.epd", weight = 0.6)

#let startingEvalParametersFloat = defaultEvalParameters.convert
let startingEvalParametersFloat = startingEvalParameters.convert
#let startingEvalParametersFloat = randomEvalParametersFloat(50.0)

discard startingEvalParametersFloat.optimize(data)

    



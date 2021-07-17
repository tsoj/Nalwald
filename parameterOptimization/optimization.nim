import ../evalParameters
import evalParametersUtils
import gradient
import random
import times
import strformat
import startingParameters
import dataUtils
import winningProbability
import terminal

proc optimize(
    start: EvalParametersFloat,
    data: seq[Entry],
    lr = 1000.0,
    minLearningRate = 10.0,
    maxIterations = int.high,
    batchSize = int.high,
    # Only one optimization run to omit over specialization and because more don't work anyway
    numReIterations = 1,
    randomAdditions = 15.0,
    discount = 0.9
): EvalParameters =
    var batchSize = batchSize

    var finalSolution: EvalParametersFloat
    var finalError = float.high


    proc getError(): float = start.convert.error(data)
    optimizeK(getError = getError)

    var bestSolution: EvalParametersFloat = start
    for reIteration in 0..<numReIterations:
        batchSize = min(batchSize, data.len)

        echo "-------------------"
        echo "batchsize: ", batchSize

        var lr = lr
        var bestError = bestSolution.convert.error(data)
        echo "starting error: ", fmt"{bestError:>9.7f}", ", starting lr: ", lr

        var previousGradient: EvalParametersFloat 
        for j in 0..maxIterations:
            optimizeK(getError = getError, suppressOutput = true)

            var shuffledData = data
            shuffledData.shuffle()
            var numBatches = shuffledData.len div batchSize
            if shuffledData.len mod batchSize != 0:
                numBatches += 1

            for i in 0..<numBatches:
                var gradient: EvalParametersFloat
                var currentSolution = bestSolution
                let bestSolutionConverted = bestSolution.convert
                var batchWeight: float = 0.0
                
                let currentBatchSize = min((i+1)*batchSize - 1, shuffledData.len - 1) - (i*batchSize)

                const numProgressBarPoints = 100

                eraseLine()
                stdout.write("[")
                for p in 1..numProgressBarPoints:
                    stdout.write("-")
                stdout.write("]")
                setCursorXPos(1)
                stdout.flushFile

                var p = 0
                for entry in shuffledData.toOpenArray(
                    first = i*batchSize,
                    last = i*batchSize + currentBatchSize
                ):
                    p += 1
                    if p mod (currentBatchSize div numProgressBarPoints) == 0:
                        stdout.write("#")
                        stdout.flushFile
                    
                    batchWeight += entry.weight
                    gradient.addGradient(bestSolutionConverted, entry.position, entry.outcome, weight = entry.weight)
                # smooth the gradient out over previous discounted gradients. Seems to help in optimizatin speed and the final
                # result is better
                gradient *= (1.0/batchWeight)
                gradient *= 1.0 - discount
                previousGradient *= discount
                gradient += previousGradient
                previousGradient = gradient

                gradient *= lr
                currentSolution += gradient

                var error = currentSolution.convert.error(data)
                
                eraseLine()
                echo(
                    "iteration: ", fmt"{j:>3}", ", batch: ", i, "/", numBatches - 1,
                    ", error: ", fmt"{error:>9.7f}", ", lr: ", lr, ", k: ", fmt"{getK():.7f}"
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
                        echo(
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
            echo "filename: ", filename
            writeFile(filename, $finalSolution.convert)

        bestSolution = finalSolution
        bestSolution.randomEvalParametersFloat(randomAdditions)

        batchSize = (15*batchSize) div 10
        
    return finalSolution.convert


var data: seq[Entry]
data.loadData("quietSetZuri.epd", weight = 1.0)
# Elements in quietSetNalwald are weighed less, because it brings better results.
# quietSetZuri is probably of higher quality
data.loadData("quietSetNalwald.epd", weight = 0.6)

#let startingEvalParametersFloat = defaultEvalParameters.convert
let startingEvalParametersFloat = startingEvalParameters
#let startingEvalParametersFloat = randomEvalParametersFloat(100.0)

discard startingEvalParametersFloat.optimize(data)

    



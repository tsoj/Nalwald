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

type Entry = object
    position: Position
    outcome: float32

proc loadData(filename: string): seq[Entry] =
    let f = open(filename)
    var line: string
    while f.readLine(line):
        line = line.replace('"', ' ')
        line = line.replace(';', ' ')
        let words = line.splitWhitespace()
        doAssert words.len == 6
        doAssert words[4] == "c2"
        let fen = words[0] & " " & words[1] & " " & words[2] & " " & words[3] & " 0 0"
        result.add(Entry(position: fen.toPosition, outcome: words[5].parseFloat))
    f.close()

    debugEcho result.len


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
    batchSize = int.high,
    numReIterations = 100,
    randomAdditions = 20.0
): ref EvalParameters =

    let batchSize = min(batchSize, data.len)

    var finalSolution: EvalParametersFloat
    var finalError = float32.high

    var bestSolution: EvalParametersFloat = start
    for reIteration in 0..<numReIterations:

        debugEcho "-------------------"

        var lr = lr
        var bestError = bestSolution.convert[].error(data) # TODO: need .error(data)
        debugEcho "starting error: ", bestError, ", starting lr: ", lr

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
                for entry in shuffledData.toOpenArray(first = i*batchSize, last = min((i+1)*batchSize - 1, shuffledData.len - 1)):
                    gradient.addGradient(bestSolutionConverted[], entry.position, entry.outcome)
                gradient *= (lr/batchSize.float32)
                currentSolution += gradient

                var error = currentSolution.convert[].error(data)
                
                debugEcho "iteration: ", j, ", batch: ", i, ", error: ", error, ", lr: ", lr


                if error >= bestError and lr >= minLearningRate:
                    lr /= 2.0

                while error < bestError:
                    bestError = error
                    bestSolution = currentSolution

                    currentSolution += gradient
                    error = currentSolution.convert[].error(data)

                    if error < bestError:
                        debugEcho "iteration: ", j, ", batch: ", i, ", error: ", error, ", lr: ", lr


            if lr < minLearningRate:
                break;
        
        if bestError <= finalError:
            finalSolution = bestSolution
            finalError = bestError
            let filename = now().format("yyyy-MM-dd-HH-mm-ss") & "_optimizationResult.txt"
            debugEcho "filename: ", filename
            writeFile(filename, $finalSolution.convert[])

        bestSolution = finalSolution
        bestSolution.randomEvalParametersFloat(randomAdditions)
        
    return finalSolution.convert


let data = "quiet-set.epd".loadData
#let data = "texel-set-clean.epd".loadData
echo data.len


#echo randomEvalParametersFloat().optimize(data, lr = 1000.0, minLearningRate = 1.0)
discard defaultEvalParametersFloat.optimize(data)
#writeFile("optimizationResult.txt", $randomEvalParametersFloat().optimize(data)[])
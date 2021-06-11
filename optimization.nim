import position
import evalParameters
import strutils
import types
import evaluation
import utils
import gradient
import random
import pieceSquareTable

type Entry = object
    position: Position
    outcome: float

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


func error(evalParameters: EvalParameters, data: openArray[Entry]): float =
    result = 0.0
    
    for entry in data:
        let estimate = entry.position.absoluteEvaluate(evalParameters).winningProbability
        result += (entry.outcome - estimate)*(entry.outcome - estimate)
    result /= data.len.float

proc optimize(
    start: EvalParametersFloat,
    data: seq[Entry],
    lr = 10000.0,
    minLearningRate = 100.0,
    maxIterations = int.high,
    batchSize = 100000
): ref EvalParameters =

    var lr = lr
    var bestSolution: EvalParametersFloat = start
    var bestError = bestSolution.convert[].error(data) # TODO: need .error(data)
    debugEcho "starting error: ", bestError, ", starting lr: ", lr

    for j in 0..maxIterations:
        var shuffledData = data
        shuffledData.shuffle()
        let numBatches = shuffledData.len div batchSize

        for i in 0..numBatches:
            var gradient: EvalParametersFloat
            var currentSolution = bestSolution
            let bestSolutionConverted = bestSolution.convert
            for entry in shuffledData.toOpenArray(first = i*batchSize, last = min((i+1)*batchSize - 1, shuffledData.len - 1)):
                gradient.addGradient(bestSolutionConverted[], entry.position, entry.outcome)
            gradient *= (lr/batchSize.float)
            currentSolution += gradient

            let error = currentSolution.convert[].error(data)
            
            debugEcho "iteration: ", j, ", batch: ", i, ", error: ", error, ", lr: ", lr

            if error <= bestError:
                bestError = error
                bestSolution = currentSolution
                if lr < minLearningRate:
                    lr = minLearningRate*2.0
            elif lr >= minLearningRate:
                lr /= 2.0

        if lr < minLearningRate:
            break;
    
    return bestSolution.convert


let data = "quiet-set.epd".loadData
#let data = "texel-set-clean.epd".loadData
echo data.len


#echo randomEvalParametersFloat().optimize(data, lr = 1000.0, minLearningRate = 1.0)
writeFile("optimizationResult.txt", $defaultEvalParametersFloat.optimize(data, lr = 1000.0, minLearningRate = 10.0)[])
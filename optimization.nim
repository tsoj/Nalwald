import position
import evalParameters
import strutils
import types
import evaluation
import utils
import gradient

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

func optimize(
    start: EvalParameters,
    data: seq[Entry],
    lr = 10000.0,
    minLearningRate = 100.0,
    maxIterations = int.high
): EvalParameters =

    var lr = lr
    var bestSolution: EvalParameters = start
    var bestError = bestSolution.error(data) # TODO: need .error(data)
    debugEcho "starting error: ", bestError, ", starting lr: ", lr

    for i in 0..maxIterations:
        var gradient: EvalParameters
        var currentSolution = bestSolution
        for entry in data:
            gradient.addGradient(bestSolution, entry.position, entry.outcome) # TODO: need .addGradient(currentSolution, entry)
        gradient *= (lr/data.len.float)
        currentSolution += gradient

        let error = currentSolution.error(data)
        
        debugEcho "i: ", i, ", error: ", error, ", lr: ", lr

        if error <= bestError:
            bestError = error
            bestSolution = currentSolution
        else:
            lr /= 2.0

        if lr < minLearningRate:
            break;
    
    return bestSolution


var data = "quiet-set.epd".loadData
echo data.len

#echo defaultEvalParameters

echo randomEvalParameters().optimize(data, lr = 1000.0, minLearningRate = 1.0)
import position
import evalParameters

type Entry = object
    position: Position
    outcome: float32

func loadData(filename: string): seq[Entry] =
    let f = open("CCRL4040_material.fen")
    var line: string
    while f.readLine(line):

func optimize(
    start: EvalParameters,
    data: seq[Entry],
    lr = 10000.0,
    minLearningRate = 100.0,
    maxIterations = int.high
): EvalParameters =

    var lr = lr
    var bestSolution: EvalParametersFloat32 = start.convert[:Value, float32]
    var bestError = bestSolution.error(data) # TODO: need .error(data)

    for i in 0..maxIterations:
        var gradient: EvalParametersFloat32
        var currentSolution = bestSolution
        for entry in data:
            gradient.addGradient(bestSolution, entry) # TODO: need .addGradient(currentSolution, entry)
        gradient *= (lr/data.len.float)
        currentSolution += gradient

        let error = currentSolution.error(data)
        
        echo "i: ", i, ", error: ", error, ", lr: ", lr

        if error <= bestError:
            bestError = error
            bestSolution = currentSolution
        else:
            lr /= 2.0

        if lr < minLearningRate:
            break;
    
    return bestSolution.convert[:float32, Value]
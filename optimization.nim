


func optimize[Parameter, Data]*(
    start: Parameter,
    data: seq[Data],
    lr = 10000.0,
    minLearningRate = 100.0,
    maxIterations = int.high
): Parameter =

    var lr = lr
    result = start
    var bestError = result.error(data) # TODO: need .error(data)

    for i in 0..maxIterations:
        var gradient: Parameter
        var currentSolution = result
        for entry in data:
            gradient.addGradient(currentSolution, entry) # TODO: need .addGradient(currentSolution, entry)
        gradient *= (lr/data.len.float)
        currentSolution += gradient

        let error = currentSolution.error(data)
        echo error
        if error <= bestError:
            bestError = error
            result = currentSolution
        else:
            lr /= 2.0

        if lr < minLearningRate:
            break;
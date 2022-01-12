import
    ../evalParameters,
    ../evaluation,
    ../position,
    ../types,
    winningProbability,
    error,
    ../bitboard


func addGradient*(
    gradient: var EvalParametersFloat,
    currentSolution: EvalParameters,
    position: Position, outcome: float32,
    k: float32,
    weight: float32
) =
    var currentGradient: EvalParametersFloat
    let currentValue = position.absoluteEvaluate(currentSolution, currentGradient)
    var g: float32 = weight * errorDerivative(outcome, currentValue.winningProbability(k)) * currentValue.winningProbabilityDerivative(k)
    currentGradient *= g
    gradient += currentGradient



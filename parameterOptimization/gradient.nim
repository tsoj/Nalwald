import
    ../evalParameters,
    ../evaluation,
    ../position,
    ../types,
    evalParametersUtils,
    winningProbability,
    error,
    ../bitboard#TODO fix ???

func addGradient*(
    gradient: var EvalParametersFloat,
    currentSolution: EvalParameters,
    position: Position, outcome: float,
    weight: float
) =
    var currentGradient: EvalParametersFloat
    let currentValue = position.absoluteEvaluate(currentSolution, currentGradient)
    var g: float = weight * errorDerivative(outcome, currentValue.winningProbability) * currentValue.winningProbabilityDerivative
    currentGradient *= g
    gradient += currentGradient



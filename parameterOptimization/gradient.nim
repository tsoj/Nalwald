import
    ../evalParameters,
    ../evaluation,
    ../position,
    ../types,
    evalParametersUtils,
    winningProbability,
    error,
    ../bitboard

func addGradient*(
    gradient: var EvalParametersFloat,
    currentSolution: EvalParameters,
    position: Position, outcome: float,
    k: float,
    weight: float
) =
    var currentGradient: EvalParametersFloat
    let currentValue = position.absoluteEvaluate(currentSolution, currentGradient)
    var g: float = weight * errorDerivative(outcome, currentValue.winningProbability(k)) * currentValue.winningProbabilityDerivative(k)
    currentGradient *= g
    gradient += currentGradient



import
    ../evalParameters,
    ../evaluation,
    ../position,
    ../types,
    winningProbability,
    error,
    ../bitboard,
    ../utils


func addGradient*(
    gradient: var EvalParametersFloat,
    currentSolution: EvalParameters,
    position: Position, outcome: float,
    k: float,
    weight: float
) =
    var currentGradient: Gradient
    currentGradient.gamePhaseFactor = position.gamePhase.interpolate(forOpening = 1.0, forEndgame = 0.0)
    let currentValue = position.absoluteEvaluate(currentSolution)
    currentGradient.g = weight * errorDerivative(outcome, currentValue.winningProbability(k)) * currentValue.winningProbabilityDerivative(k)
    currentGradient.evalParams = addr gradient
    discard position.absoluteEvaluate(currentSolution, currentGradient)



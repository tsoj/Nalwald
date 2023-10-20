import
    ../evalParameters,
    ../evaluation,
    ../position,
    ../types,
    ../defaultParameters,
    winningProbability,
    error,
    ../bitboard,
    ../utils
    
func addGradient*(
    gradient: var EvalParametersFloat,
    currentSolution: EvalParameters,
    position: Position, outcome: float,
    k: float
) =
    let currentValue = position.absoluteEvaluate(currentSolution)
    var currentGradient = Gradient(
        gamePhaseFactor: position.gamePhase.interpolate(forOpening = 1.0, forEndgame = 0.0),
        g: errorDerivative(outcome, currentValue.winningProbability(k)) * currentValue.winningProbabilityDerivative(k),
        evalParams: addr gradient
    )
    discard position.absoluteEvaluate(currentSolution, currentGradient)





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
    params: var EvalParameters, lr: float, position: Position, outcome: float
) =

  let currentValue = position.absoluteEvaluate(params)
  var currentGradient = Gradient(
    gamePhaseFactor: position.gamePhase.interpolate(forOpening = 1.0, forEndgame = 0.0),
    g:
      errorDerivative(outcome, currentValue.winningProbability) *
      currentValue.winningProbabilityDerivative * lr,
    gradient: addr params,
  )
  position.absoluteEvaluate(currentGradient)

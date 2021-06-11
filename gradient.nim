import evalParameters
import evaluation
import utils
import position
import types

func addGradient*(
    gradient: var EvalParametersFloat,
    currentSolution: EvalParameters,
    position: Position, outcome: float32
) =
    var currentGradient: EvalParametersFloat
    let currentValue = position.absoluteEvaluate(currentSolution, currentGradient)
    # debugEcho "-----------------"
    # debugEcho "outcome: ", outcome
    # debugEcho position
    # debugEcho currentGradient
    let g: float32 = 2.0*(outcome - currentValue.winningProbability) * currentValue.winningProbabilityDerivative
    currentGradient *= g
    gradient += currentGradient



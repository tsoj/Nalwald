import ../evalParameters
import evalParametersUtils
import ../evaluation
import ../utils
import ../position
import ../types

func addGradient*(
    gradient: var EvalParametersFloat,
    currentSolution: EvalParameters,
    position: Position, outcome: float32,
    weight: float32
) =
    var currentGradient: EvalParametersFloat
    let currentValue = position.absoluteEvaluate(currentSolution, currentGradient)
    let g: float32 = weight*2.0*(outcome - currentValue.winningProbability) * currentValue.winningProbabilityDerivative
    currentGradient *= g
    gradient += currentGradient



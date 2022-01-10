import
    math,
    ../types

func error*(outcome, estimate: Float): Float =
    (outcome - estimate)^2

func errorDerivative*(outcome, estimate: Float): Float =
    2.0 * (outcome - estimate)
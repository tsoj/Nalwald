import math

func error*(outcome, estimate: float32): float32 =
    (outcome - estimate)^2

func errorDerivative*(outcome, estimate: float32): float32 =
    2.0 * (outcome - estimate)
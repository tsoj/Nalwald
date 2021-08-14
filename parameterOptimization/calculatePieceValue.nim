import
    ../types,
    ../position,
    ../evaluation,
    dataUtils

func getPieceValue(piece: Piece, evalParameters: EvalParameters, positions: seq[Position]): Value =
    result = 0.Value
    
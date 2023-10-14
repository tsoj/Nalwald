import
    ../types,
    ../position,
    ../evaluation,
    ../bitboard,
    ../evalParameters,
    dataUtils

when isMainModule:
    import ../defaultParameters

func getPieceValue(piece: Piece, evalParameters: EvalParameters, data: openArray[Entry]): Value =
    var sum: int64 = 0
    var numPieceEvals: int64 = 0
    for entry in data:
        let position = entry.position
        let startEval = position.absoluteEvaluate(evalParameters)
        for square in position[piece]:
            let us = position.coloredPiece(square).color
            assert position.coloredPiece(square).piece == piece
            var newPosition = position
            newPosition.removePiece(us, piece, square.toBitboard)
            var diff = startEval - newPosition.absoluteEvaluate(evalParameters)
            if us == black:
                diff *= -1
            sum += diff.int
            numPieceEvals += 1
    (sum div numPieceEvals).Value

proc pieceValuesAsString*(evalParameters: EvalParameters, data: openArray[Entry]): string =
    for piece in pawn..queen:
        result &= $piece & ": " & $getPieceValue(piece, evalParameters, data) & ".Value, "

when isMainModule:
    var data: seq[Entry]
    data.loadDataEpd "quietSetNalwald.epd"
    data.loadDataEpd "quietSetCombinedCCRL4040.epd"
    data.loadDataEpd "quietSmallPoolGamesNalwald.epd"
    data.loadDataEpd "quietSetNalwald2.epd"
    data.loadDataEpd "quietLeavesSmallPoolGamesNalwaldSearchLabeled.epd"
    data.loadDataEpd "quietSmallPoolGamesNalwald2Labeled.epd"
    echo pieceValuesAsString(defaultEvalParameters, data)
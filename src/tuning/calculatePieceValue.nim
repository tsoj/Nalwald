import
    ../types,
    ../position,
    ../evaluation,
    ../bitboard,
    ../evalParameters,
    dataUtils

func getPieceValue(piece: Piece, evalParameters: EvalParametersTemplate, data: openArray[Entry]): Value =
    var sum: int64 = 0
    var numPieceEvals: int64 = 0
    for entry in data:
        let position = entry.position
        let startEval = position.absoluteEvaluate(evalParameters)
        for square in position[piece]:
            let us = position.coloredPiece(square).color
            assert position.coloredPiece(square).piece == piece
            var newPosition = position
            newPosition.removePiece(us, piece, square)
            var diff = startEval - newPosition.absoluteEvaluate(evalParameters)
            if us == black:
                diff *= -1
            sum += diff.int
            numPieceEvals += 1
    (sum div numPieceEvals).Value

proc pieceValuesAsString*(evalParameters: EvalParametersTemplate, data: openArray[Entry]): string =
    for piece in pawn..queen:
        result &= $piece & ": " & $getPieceValue(piece, evalParameters, data) & ".Value, "

when isMainModule:
    var data: seq[Entry]
    # data.loadDataEpd "rtainingSets/quietSetNalwald.epd"
    # data.loadDataEpd "rtainingSets/quietSetCombinedCCRL4040.epd"
    # data.loadDataEpd "rtainingSets/quietSmallPoolGamesNalwald.epd"
    # data.loadDataEpd "rtainingSets/quietSetNalwald2.epd"
    # data.loadDataEpd "rtainingSets/quietLeavesSmallPoolGamesNalwaldSearchLabeled.epd"
    # data.loadDataEpd "rtainingSets/quietSmallPoolGamesNalwald2Labeled.epd"
    data.loadDataBin "trainingSets/trainingSet_2023-12-28-11-23-21.bin"
    echo pieceValuesAsString(defaultEvalParameters, data)
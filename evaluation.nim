import
    position,
    types,
    bitboard,
    bitops,
    evalParameters,
    utils,
    defaultParameters,
    algorithm,
    macros

func value*(piece: Piece): Value =
    const table = [
        pawn: 134.Value,
        knight: 434.Value,
        bishop: 469.Value,
        rook: 663.Value,
        queen: 1406.Value,
        king: 1000000.Value,
        noPiece: 0.Value
    ]
    table[piece]

func cp*(cp: int): Value {.inline.} =
    (pawn.value * cp.Value) div 100.Value

func toCp*(value: Value): int {.inline.} =
    (100 * value.int) div pawn.value.int

func material*(position: Position): Value =
    result = 0
    for piece in pawn..king:
        result += (position[piece] and position[position.us]).countSetBits.Value * piece.value
        result -= (position[piece] and position[position.enemy]).countSetBits.Value * piece.value

func absoluteMaterial*(position: Position): Value =
    result = position.material
    if position.us == black:
        result = -result

func `+=`[T: Value or float32](a: var array[Phase, T], b: array[Phase, T]) =
    for phase in Phase:
        a[phase] += b[phase]

func `-=`[T: Value or float32](a: var array[Phase, T], b: array[Phase, T]) =
    for phase in Phase:
        a[phase] -= b[phase]

func `*=`[T: Value or float32](a: var array[Phase, T], b: T) =
    for phase in Phase:
        a[phase] *= b

func colorConditionalMirror(x: Square or Bitboard, color: Color): auto =
    if color == black:
        x.mirror
    else:
        x

type Nothing = enum nothing
type Gradient* = object
    gamePhaseFactor*: float32
    g*: float32
    evalParams*: ptr EvalParametersFloat
type GradientOrNothing = Gradient or Nothing

macro getParameter(phase, structName, parameter: untyped): untyped =
    parseExpr($toStrLit(quote do: `structName`[`phase`]) & "." & $toStrLit(quote do: `parameter`))

template addValue(
    value: var array[Phase, Value],
    evalParameters: EvalParameters,
    gradient: GradientOrNothing,
    us: Color,
    parameter: untyped
) =
    for phase {.inject.} in Phase:
        value[phase] += getParameter(phase, evalParameters[0], parameter)

    when gradient isnot Nothing:
        let f = (if us == black: -1.0 else: 1.0) * gradient.g
        getParameter(opening, gradient.evalParams[][0], parameter) += f * gradient.gamePhaseFactor
        getParameter(endgame, gradient.evalParams[][0], parameter) += f * (1.0 - gradient.gamePhaseFactor)

func kingRelativePst(
    evalParameters: EvalParameters,
    square: Square,
    piece: static Piece,
    us: static Color,
    kingSquares: array[white..black, Square],
    gradient: var GradientOrNothing
): array[Phase, Value] {.inline.} =

    let
        enemy = us.opposite
        square = square.colorConditionalMirror(us)
        kingSquares = [
            relativeToUs: kingSquares[us].colorConditionalMirror(us),
            relativeToEnemy: kingSquares[enemy].colorConditionalMirror(enemy)
        ]

    for phase in Phase:
        result[phase] =
            evalParameters[0][phase].kingRelativePst[relativeToEnemy][kingSquares[relativeToEnemy]][piece][square] +
            evalParameters[0][phase].kingRelativePst[relativeToUs][kingSquares[relativeToUs]][piece][square]

    when gradient isnot Nothing:

        for whoseKing in relativeToUs..relativeToEnemy:
            let kingSquare = kingSquares[whoseKing]
            for (kingSquaresBitboard, multiplier) in [
                (kingSquare.toBitboard, 1.5),
                (mask3x3[kingSquare], 0.4),
                (mask5x5[kingSquare], 0.1)
            ]:
                for kingSquare in kingSquaresBitboard:

                    for (kingSquare, pieceSquare) in [
                        (kingSquare, square),
                        (kingSquare.mirrorVertically, square.mirrorVertically)
                    ]:
                        let f = gradient.g * multiplier * (if us == black: -1.0 else: 1.0)
                        gradient.evalParams[][0][opening].kingRelativePst[whoseKing][kingSquare][piece][pieceSquare] += f * gradient.gamePhaseFactor
                        gradient.evalParams[][0][endgame].kingRelativePst[whoseKing][kingSquare][piece][pieceSquare] += f * (1.0 - gradient.gamePhaseFactor)

func pawnMaskIndex*(
    position: Position,
    square: static Square,
    us: Color,
    doChecks: static bool = false
): int =

    let square = square.colorConditionalMirror(us)

    assert not square.isEdge
    assert square >= b2

    when doChecks:
        if square.isEdge: # includes cases when square < b2
            raise newException(ValueError, "Can't calculate pawn mask index of edge square")

    let
        ourPawns = (position[us] and position[pawn]).colorConditionalMirror(us) shr (square.int8 - b2.int8)
        enemyPawns = (position[us.opposite] and position[pawn]).colorConditionalMirror(us) shr (square.int8 - b2.int8)

    var counter = 1
    for bit in [
        a3.toBitboard, b3.toBitboard, c3.toBitboard,
        a2.toBitboard, b2.toBitboard, c2.toBitboard,
        a1.toBitboard, b1.toBitboard, c1.toBitboard
    ]:
        if (ourPawns and bit) != 0:
            result += counter * 2
        elif (enemyPawns and bit) != 0:
            result += counter * 1
        counter *= 3

func evaluate3x3PawnStructureFromWhitesPerspective(
    position: Position,
    evalParameters: EvalParameters,
    gradient: var GradientOrNothing
): array[Phase, Value] =

    for rankAndSquareList in (
        (0, (b3, c3, d3, e3, f3, g3)),
        (1, (b4, c4, d4, e4, f4, g4)),
        (2, (b5, c5, d5, e5, f5, g5)),
        (3, (b6, c6, d6, e6, f6, g6))
    ).fields:
        const (rank, squareList) = rankAndSquareList
        for square in squareList.fields:
            if (mask3x3[square] and position[pawn]).countSetBits >= 2:
                
                let index = position.pawnMaskIndex(square, white)
                result.addValue(evalParameters, gradient, white, pawnStructureBonus[rank][index])

func pieceRelativePst(
    evalParameters: EvalParameters,
    position: Position,
    ourPiece: static Piece,
    ourSquare: Square,
    us: static Color,
    gradient: var GradientOrNothing
): array[Phase, Value] =

    let
        ourSquare = ourSquare.colorConditionalMirror(us)
        otherPieces = [
            relativeToUs: position[us],
            relativeToEnemy: position[us.opposite]
        ]
    
    for otherPiece in pawn..queen:
        for relativity in relativeToUs..relativeToEnemy:
            for otherSquare in otherPieces[relativity] and position[otherPiece]:
                let otherSquare = otherSquare.colorConditionalMirror(us)
                result.addValue(evalParameters, gradient, us, pieceRelativePst[relativity][ourPiece][ourSquare][otherPiece][otherSquare])

func evaluatePieceFromPieceColorPerspective(
    position: Position,
    piece: static Piece,
    square: Square,
    pieceColor: static Color,
    kingSquares: array[white..black, Square],
    evalParameters: EvalParameters,
    gradient: var GradientOrNothing
): array[Phase, Value] {.inline.} =
    static: doAssert piece != noPiece

    result.addValue(evalParameters, gradient, pieceColor, pieceValues[piece])

    # king-relative piece square table
    result += evalParameters.kingRelativePst(
        square, piece, pieceColor,
        kingSquares,
        gradient
    )
    when piece == pawn:
        if position.isPassedPawn(pieceColor, square):
            result += evalParameters.kingRelativePst(
                square, noPiece, # noPiece stands for passed pawn
                pieceColor,
                kingSquares,
                gradient
            )

    # piece-relative piece square table
    when piece notin [king, pawn]:
        result += evalParameters.pieceRelativePst(position, piece, square, pieceColor, gradient)

    
func evaluatePieceTypeFromWhitesPerspective(
    position: Position,
    piece: static Piece,
    kingSquares: array[white..black, Square],
    evalParameters: EvalParameters,
    gradient: var GradientOrNothing
): array[Phase, Value] {.inline.}  =
    
    for pieceColor in (white, black).fields:
        for square in (position[piece] and position[pieceColor]):
            var pieceValue = position.evaluatePieceFromPieceColorPerspective(
                piece, square,
                pieceColor,
                kingSquares,
                evalParameters, gradient
            )

            when pieceColor == black:
                pieceValue *= -1

            result += pieceValue


func evaluate*(position: Position, evalParameters: EvalParameters, gradient: var GradientOrNothing): Value {.inline.} =
    if position.halfmoveClock >= 100:
        return 0.Value

    var value = [opening: 0.Value, endgame: 0.Value]

    let kingSquares = [
        white: position.kingSquare(white),
        black: position.kingSquare(black)
    ]
    
    # evaluating pieces
    for piece in (pawn, knight, bishop, rook, queen, king).fields:
        value += position.evaluatePieceTypeFromWhitesPerspective(piece, kingSquares, evalParameters, gradient)

    # evaluating 3x3 pawn patters
    value += position.evaluate3x3PawnStructureFromWhitesPerspective(evalParameters, gradient)

    # interpolating between opening and endgame values
    result = position.gamePhase.interpolate(forOpening = value[opening], forEndgame = value[endgame])
    if position.us == black:
        result *= -1
    doAssert result.abs < valueCheckmate

#-------------- sugar functions --------------#

func evaluate*(position: Position): Value =
    var gradient: Nothing = nothing
    position.evaluate(defaultEvalParameters, gradient)

func absoluteEvaluate*(position: Position, evalParameters: EvalParameters, gradient: var GradientOrNothing): Value =
    result = position.evaluate(evalParameters, gradient)
    if position.us == black:
        result = -result

func absoluteEvaluate*(position: Position, evalParameters: EvalParameters): Value =
    var gradient: Nothing = nothing
    position.absoluteEvaluate(evalParameters, gradient)

func absoluteEvaluate*(position: Position): Value =
    var gradient: Nothing = nothing
    position.absoluteEvaluate(defaultEvalParameters, gradient)
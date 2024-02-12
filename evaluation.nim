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

export defaultParameters

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

func colorConditionalMirrorVertically(x: Square or Bitboard, color: Color): auto =
    if color == black:
        x.mirrorVertically
    else:
        x

type Nothing = enum nothing
type Gradient* = object
    gamePhaseFactor*: float32
    g*: float32
    evalParams*: ptr EvalParametersFloat
type Params = EvalParametersTemplate or Gradient

macro getParameter(phase, structName, parameter: untyped): untyped =
    parseExpr($toStrLit(quote do: `structName`[`phase`.int]) & "." & $toStrLit(quote do: `parameter`))

template addValue(
    value: var array[Phase, Value],
    params: Params,
    us: Color,
    parameter: untyped
) =
    when params is Gradient:
        let f = (if us == black: -1.0 else: 1.0) * params.g
        getParameter(opening, params.evalParams[], parameter) += f * params.gamePhaseFactor
        getParameter(endgame, params.evalParams[], parameter) += f * (1.0 - params.gamePhaseFactor)
    else:
        for phase {.inject.} in Phase:
            value[phase] += getParameter(phase, params, parameter).Value

func pieceRelativePst(
    params: Params,
    position: Position,
    ourPiece: static Piece,
    ourSquare: Square,
    us: static Color
): array[Phase, Value] =

    let
        ourSquare = ourSquare.colorConditionalMirrorVertically(us)
        otherPieces = [
            relativeToUs: position[us],
            relativeToEnemy: position[us.opposite]
        ]
        # we do it just relative to the enemy king, as that's faster
        enemyKingSquare = position[us.opposite, king].toSquare.colorConditionalMirrorVertically(us)
        roughEnemyKingFile = (enemyKingSquare.int mod 8) div 2
        roughEnemyKingRank = (enemyKingSquare.int div 8) div 4

    const pieceRange = when ourPiece in [pawn, king, queen]:
        pawn..queen
    elif ourPiece == knight:
        [pawn, knight, bishop, rook]
    elif ourPiece == bishop:
        [pawn, bishop, rook]
    elif ourPiece == rook:
        [pawn, rook]
    
    for relativity in relativeToUs..relativeToEnemy:
        for otherPiece in pieceRange:
            for otherSquare in otherPieces[relativity] and position[otherPiece]:
                let otherSquare = otherSquare.colorConditionalMirrorVertically(us)
                result.addValue(
                    params, us,
                    pieceRelativePst[roughEnemyKingRank][roughEnemyKingFile][relativity][ourPiece][ourSquare][otherPiece][otherSquare]
                )

                when params is Gradient:
                    var dummy: array[Phase, Value]
                    let
                        flippedOurSquare = ourSquare.mirrorHorizontally
                        flippedOtherSquare = otherSquare.mirrorHorizontally
                        flippedKingFile = 3 - roughEnemyKingFile
                    dummy.addValue(
                        params, us,
                        pieceRelativePst[roughEnemyKingRank][flippedKingFile][relativity][ourPiece][flippedOurSquare][otherPiece][flippedOtherSquare]
                    )

func evaluatePieceFromPieceColorPerspective(
    position: Position,
    piece: static Piece,
    square: Square,
    pieceColor: static Color,
    params: Params
): array[Phase, Value] {.inline.} =
    static: doAssert piece != noPiece

    when piece == pawn:
        if position.isPassedPawn(pieceColor, square):
            result += params.pieceRelativePst(position, pawn, square, pieceColor)

    else:
        result += params.pieceRelativePst(position, piece, square, pieceColor)

    
func evaluatePieceTypeFromWhitesPerspective(
    position: Position,
    piece: static Piece,
    params: Params
): array[Phase, Value] {.inline.}  =
    
    for pieceColor in (white, black).fields:
        for square in (position[piece] and position[pieceColor]):
            var pieceValue = position.evaluatePieceFromPieceColorPerspective(
                piece, square,
                pieceColor,
                params
            )

            when pieceColor == black:
                pieceValue *= -1

            result += pieceValue



func pawnMaskIndex*(
    position: Position,
    square: static Square
): int =

    assert not square.isEdge
    assert square >= b2

    let
        whitePawns = position[white, pawn] shr (square.int8 - b2.int8)
        blackPawns = position[black, pawn] shr (square.int8 - b2.int8)

    var counter = 1

    for bit in [
        a3.toBitboard, b3.toBitboard, c3.toBitboard,
        a2.toBitboard, b2.toBitboard, c2.toBitboard,
        a1.toBitboard, b1.toBitboard, c1.toBitboard
    ]:
        if (whitePawns and bit) != 0:
            result += counter * 2
        elif (blackPawns and bit) != 0:
            result += counter * 1
        counter *= 3

func evaluate3x3PawnStructureFromWhitesPerspective(
    position: Position,
    params: Params
): array[Phase, Value] =

    when params is Gradient:
        let flippedPosition = position.mirrorVertically

    for square in (
        b3, c3, d3, e3, f3, g3,
        b4, c4, d4, e4, f4, g4,
        b5, c5, d5, e5, f5, g5,
        b6, c6, d6, e6, f6, g6
    ).fields:
        if (mask3x3[square] and position[pawn]).countSetBits >= 2:
            
            let index = position.pawnMaskIndex(square)
            result.addValue(params, white, pawnStructureBonus[square][index])

            when params is Gradient:
                const flippedSquare = square.mirrorVertically
                let flippedIndex = flippedPosition.pawnMaskIndex(flippedSquare)

                var dummy: array[Phase, Value]
                dummy.addValue(params, black, pawnStructureBonus[flippedSquare][flippedIndex])


func evaluate*(position: Position, params: Params): Value {.inline.} =
    if position.halfmoveClock >= 100:
        return 0.Value

    var value = [opening: 0.Value, endgame: 0.Value]
    
    # evaluating pieces
    for piece in (pawn, knight, bishop, rook, queen, king).fields:
        value += position.evaluatePieceTypeFromWhitesPerspective(piece, params)

    # evaluating 3x3 pawn patters
    value += position.evaluate3x3PawnStructureFromWhitesPerspective(params)

    # interpolating between opening and endgame values
    result = position.gamePhase.interpolate(forOpening = value[opening], forEndgame = value[endgame])
    if position.us == black:
        result *= -1
    doAssert result.abs < valueCheckmate

#-------------- sugar functions --------------#

func evaluate*(position: Position): Value =
    position.evaluate(defaultEvalParameters)

func absoluteEvaluate*(position: Position, params: Params): Value =
    result = position.evaluate(params)
    if position.us == black:
        result = -result

func absoluteEvaluate*(position: Position): Value =
    position.absoluteEvaluate(defaultEvalParameters)

# import positionUtils

# let sp = "1rbqk1nr/ppp2ppp/2nb4/4p3/4N3/3B1N2/PPP1QPPP/R1B2RK1 w k - 8 9".toPosition
# echo sp
# echo sp.absoluteEvaluate
# echo sp.mirrorHorizontally
# echo sp.mirrorHorizontally.absoluteEvaluate
# echo sp.mirrorVertically
# echo sp.mirrorVertically.absoluteEvaluate
# echo sp.rotate
# echo sp.rotate.absoluteEvaluate
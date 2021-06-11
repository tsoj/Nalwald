import position
import types
import bitboard
import bitops
import evalParameters
import utils

func numReachableSquares(position: Position, piece: Piece, square: Square, us: Color): int8 =
    (piece.attackMask(square, position.occupancy) and not position[us]).countSetBits.int8

type Nothing = enum nothing
type GradientOrNothing = EvalParameters or Nothing

func getPstValue(
    evalParameters: EvalParameters,
    gamePhase: GamePhase,
    square: Square,
    piece: Piece,
    us: Color,
    kingSquare: array[white..black, Square],
    gradient: var GradientOrNothing
): Value =
    let square = if us == black: square else: square.mirror
    let enemyKingSquare = if us == white: kingSquare[black] else: kingSquare[white].mirror
    let ourKingSquare = if us == black: kingSquare[black] else: kingSquare[white].mirror

    when not (gradient is Nothing):
        var openingGradient = gamePhase.interpolate(forOpening = 1.0, forEndgame = 0.0)
        var endgameGradient = 1.0 - openingGradient
        if us == black:
            openingGradient *= -1.0
            endgameGradient *= -1.0
        gradient.pstOpeningOwnKing[ourKingSquare][piece][square] += openingGradient
        gradient.pstOpeningEnemeyKing[enemyKingSquare][piece][square] += openingGradient

        gradient.pstpstEndgameOwnKing[ourKingSquare][piece][square] += endgameGradient
        gradient.pstpstEndgameEnemeyKing[enemyKingSquare][piece][square] += endgameGradient

    (gamePhase.interpolate(
        forOpening = evalParameters.pstOpeningOwnKing[ourKingSquare][piece][square].Value,
        forEndgame = evalParameters.pstEndgameOwnKing[ourKingSquare][piece][square].Value
    ) + gamePhase.interpolate(
        forOpening = evalParameters.pstOpeningEnemyKing[enemyKingSquare][piece][square].Value,
        forEndgame = evalParameters.pstEndgameEnemyKing[enemyKingSquare][piece][square].Value
    )) div 2 #TODO remove 2 for gradient descent

func bonusPassedPawn(
    evalParameters: EvalParameters,
    gamePhase: GamePhase,
    square: Square,
    us: Color,
    gradient: var GradientOrNothing
): Value =
    var index = square.int8 div 8
    if us == black:
        index = 7 - index

    when not (gradient is Nothing):
        let openingGradient = gamePhase.interpolate(forOpening = 1.0, forEndgame = 0.0)
        let endgameGradient = 1.0 - openingGradient
        gradient.openingPassedPawnTable[index] += (if us == black: -openingGradient else: openingGradient)
        gradient.endgamePassedPawnTable[index] += (if us == black: -endgameGradient else: endgameGradient)

    gamePhase.interpolate(
        forOpening = evalParameters.openingPassedPawnTable[index].Value,
        forEndgame = evalParameters.endgamePassedPawnTable[index].Value
    )

func evaluatePawn(
    position: Position,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    evalParameters: EvalParameters,
    gradient: var GradientOrNothing
): Value =
    result = 0
    
    # passed pawn
    if position.isPassedPawn(us, enemy, square):
        result += evalParameters.bonusPassedPawn(gamePhase, square, us, gradient)

    # isolated pawn
    if (square.isLeftEdge or (position[pawn] and position[us] and files[square.left]) == 0) and
    (square.isRightEdge or (position[pawn] and position[us] and files[square.right]) == 0):
        result += evalParameters.bonusIsolatedPawn.Value

        when not (gradient is Nothing):
            gradient.bonusIsolatedPawn += (if us == black: -1.0 else: 1.0)

func evaluateKnight(
    position: Position,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    evalParameters: EvalParameters,
    gradient: var GradientOrNothing
): Value =
    let reachableSquares = position.numReachableSquares(knight, square, us).float
    when not (gradient is Nothing):
        gradient.mobilityMultiplierKnight += (if us == black: -reachableSquares else: reachableSquares)/8.0
    (reachableSquares * evalParameters.mobilityMultiplierKnight).Value

func evaluateBishop(
    position: Position,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    evalParameters: EvalParameters,
    gradient: var GradientOrNothing
): Value =
    let reachableSquares = position.numReachableSquares(bishop, square, us).float
    when not (gradient is Nothing):
        gradient.mobilityMultiplierBishop += (if us == black: -reachableSquares else: reachableSquares)/8.0
    result = (reachableSquares * evalParameters.mobilityMultiplierBishop).Value
    
    if (position[us] and position[bishop] and (not bitAt[square])) != 0:
        result += evalParameters.bonusBothBishops.Value

        when not (gradient is Nothing):
            gradient.bonusBothBishops += (if us == black: -1.0 else: 1.0)

func evaluateRook(
    position: Position,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    evalParameters: EvalParameters,
    gradient: var GradientOrNothing
): Value =
    let reachableSquares = position.numReachableSquares(rook, square, us).float
    when not (gradient is Nothing):
        gradient.mobilityMultiplierRook += (if us == black: -reachableSquares else: reachableSquares)/8.0
    result = (reachableSquares * evalParameters.mobilityMultiplierRook).Value
    
    # rook on open file
    if (files[square] and position[pawn]) == 0:
        result += evalParameters.bonusRookOnOpenFile.Value

        when not (gradient is Nothing):
            gradient.bonusRookOnOpenFile += (if us == black: -1.0 else: 1.0)

func evaluateQueen(
    position: Position,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    evalParameters: EvalParameters,
    gradient: var GradientOrNothing
): Value =
    let reachableSquares = position.numReachableSquares(queen, square, us).float
    when not (gradient is Nothing):
        gradient.mobilityMultiplierQueen += (if us == black: -reachableSquares else: reachableSquares)/8.0
    (reachableSquares * evalParameters.mobilityMultiplierQueen).Value

func evaluateKing(
    position: Position,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    evalParameters: EvalParameters,
    gradient: var GradientOrNothing
): Value =
    result = 0
    
    # rook on second rank/file is bad
    let enemyRooks = position[rook] and position[enemy];
    for (kingFile, rookFile) in [(a1,a2), (a8, a7), (a1, b1), (h1, g1)]:
        if (ranks[square] and ranks[kingFile]) != 0 and (enemyRooks and ranks[rookFile]) != 0:
            result += evalParameters.bonusRookSecondRankFromKing.Value

            when not (gradient is Nothing):
                gradient.bonusRookSecondRankFromKing += (if us == black: -1.0 else: 1.0)

            break

    # kingsafety by pawn shielding
    let numPossibleQueenAttack = queen.attackMask(square, position[pawn] and position[us]).countSetBits
    result -= gamePhase.interpolate(
        forOpening = (evalParameters.kingSafetyMultiplier*numPossibleQueenAttack.float).Value,
        forEndgame = 0.Value
    )

    when not (gradient is Nothing):
        let openingGradient = gamePhase.interpolate(forOpening = 1.0, forEndgame = 0.0)
        gradient.kingSafetyMultiplier += -openingGradient*numPossibleQueenAttack.float * (if us == black: -1.0 else: 1.0)

func evaluatePiece(
    position: Position,
    piece: Piece,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    evalParameters: EvalParameters,
    gradient: var GradientOrNothing
): Value =
    case piece:
    of pawn:
        return evaluatePawn(position, square, us, enemy, gamePhase, evalParameters, gradient)
    of knight:
        return evaluateKnight(position, square, us, enemy, gamePhase, evalParameters, gradient)
    of bishop:
        return evaluateBishop(position, square, us, enemy, gamePhase, evalParameters, gradient)
    of rook:
        return evaluateRook(position, square, us, enemy, gamePhase, evalParameters, gradient)
    of queen:
        return evaluateQueen(position, square, us, enemy, gamePhase, evalParameters, gradient)
    of king:
        return evaluateKing(position, square, us, enemy, gamePhase, evalParameters, gradient)
    else:
        assert false
    
func evaluatePieceType(
    position: Position,
    piece: Piece,
    gamePhase: GamePhase,
    evalParameters: EvalParameters,
    kingSquare: array[white..black, Square],
    gradient: var GradientOrNothing
): Value  =
    let
        us = position.us
        enemy = position.enemy
    
    result = 0

    var tmpOccupancy = position[piece]
    while tmpOccupancy != 0:
        let square = tmpOccupancy.removeTrailingOneBit.Square
        let currentUs = if (bitAt[square] and position[us]) != 0: us else: enemy
        let currentEnemy = currentUs.opposite

        let currentResult = 
            values[piece] +
            evalParameters.getPstValue(gamePhase, square, piece, currentUs, kingSquare, gradient) + #TODO improve NPS
            # defaultPieceSquareTable[gamePhase][currentUs][piece][square] +
            position.evaluatePiece(piece, square, currentUs, currentEnemy, gamePhase, evalParameters, gradient)
        
        if currentUs == us:
            result += currentResult
        else:
            result -= currentResult

func evaluate*(position: Position, evalParameters: EvalParameters, gradient: var GradientOrNothing): Value =
    if position.halfmoveClock >= 100:
        return 0

    result = 0
    let gamePhase = position.gamePhase

    let kingSquare = [white: position.kingSquare(white), black: position.kingSquare(black)]
    for piece in pawn..king:
        result += position.evaluatePieceType(piece, gamePhase, evalParameters, kingSquare, gradient)



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

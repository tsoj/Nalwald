import position
import types
import bitboard
import bitops
import pieceSquareTable
import utils

template numReachableSquares(position: Position, piece: Piece, square: Square, us: Color): int8 =
    (piece.attackMask(square, position.occupancy) and not position[us]).countSetBits.int8

type EvalPropertiesTemplate[ValueType] = object
    pst: array[GamePhase, array[pawn..king, array[a1..h8, ValueType]]]
    openingPassedPawnTable: array[8, ValueType]
    endgamePassedPawnTable: array[8, ValueType]
    bonusIsolatedPawn: ValueType
    bonusBothBishops: ValueType
    bonusRookOnOpenFile: ValueType
    mobilityMultiplierKnight: float32
    mobilityMultiplierBishop: float32
    mobilityMultiplierRook: float32
    mobilityMultiplierQueen: float32
    bonusRookSecondRankFromKing: ValueType
    kingSafetyMultiplier: float32

type EvalProperties = EvalPropertiesTemplate[Value]
type EvalPropertiesFloat32 = EvalPropertiesTemplate[float32]

func convertEvalProperties[InValueType, OutValueType](
    evalProperties: EvalPropertiesTemplate[InValueType]
): EvalPropertiesTemplate[OutValueType] =
    for piece in pawn..king:
        for square in a1..h8:
            for gamePhase in GamePhase.low..GamePhase.high:
                result.pst[gamePhase][piece][square] = evalProperties.pst[gamePhase][piece][square].OutValueType
    for i in 0..7:
        result.openingPassedPawnTable[i] = evalProperties.openingPassedPawnTable[i].OutValueType
        result.endgamePassedPawnTable[i] = evalProperties.endgamePassedPawnTable[i].OutValueType
    result.bonusIsolatedPawn = evalProperties.bonusIsolatedPawn.OutValueType
    result.bonusBothBishops = evalProperties.bonusBothBishops.OutValueType
    result.bonusRookOnOpenFile = evalProperties.bonusRookOnOpenFile.OutValueType
    result.mobilityMultiplierKnight = evalProperties.mobilityMultiplierKnight
    result.mobilityMultiplierBishop = evalProperties.mobilityMultiplierBishop
    result.mobilityMultiplierRook = evalProperties.mobilityMultiplierRook
    result.mobilityMultiplierQueen = evalProperties.mobilityMultiplierQueen
    result.bonusRookSecondRankFromKing = evalProperties.bonusRookSecondRankFromKing.OutValueType
    result.kingSafetyMultiplier = evalProperties.kingSafetyMultiplier


const defaultEvalProperties = block:
    var defaultEvalProperties = EvalProperties(
        openingPassedPawnTable: [0.Value, 0.Value, 0.Value, 10.Value, 15.Value, 20.Value, 45.Value, 0.Value],
        endgamePassedPawnTable: [0.Value, 20.Value, 30.Value, 40.Value, 60.Value, 100.Value, 120.Value, 0.Value],
        bonusIsolatedPawn: -10.Value,
        bonusBothBishops: 10.Value,
        bonusRookOnOpenFile: 5.Value,
        mobilityMultiplierKnight: 2.0,
        mobilityMultiplierBishop: 3.0,
        mobilityMultiplierRook: 4.0,
        mobilityMultiplierQueen: 2.0,
        bonusRookSecondRankFromKing: -10.Value,
        kingSafetyMultiplier: 2.5
    )
    for piece in pawn..king:
        for square in a1..h8:
            for gamePhase in GamePhase.low..GamePhase.high:
                defaultEvalProperties.pst[gamePhase][piece][square] =
                    gamePhase.interpolate(openingPst[piece][square].Value, endgamePst[piece][square].Value)
    defaultEvalProperties

type Nothing = enum nothing
type GradientOrNothing = EvalPropertiesFloat32 or Nothing

func getPstValue(
    evalProperties: EvalProperties,
    gamePhase: GamePhase,
    square: Square,
    piece: Piece,
    us: Color,
    gradient: var GradientOrNothing
): Value =
    let square = if us == black: square else: square.mirror

    when not (gradient is Nothing):
        let openingGradient = gamePhase.interpolate(forOpening: 1.0, forEndgame: 0.0)
        let endgameGradient = 1.0 - openingGradient
        for phase in GamePhase.low..GamePhase.high:
            gradient.pst[phase][piece][square] = 
                phase.interpolate(forOpening: openingGradient, forEndgame: endgameGradient)
            if us == black:
                gradient.pst[phase][piece][square] *= -1.0

    evalProperties.pst[gamePhase][piece][square]

func bonusPassedPawn(
    evalProperties: EvalProperties,
    gamePhase: GamePhase,
    square: Square,
    us: Color,
    gradient: var GradientOrNothing
): Value =
    var index = square.int8 div 8
    if us == black:
        index = 7 - index

    when not (gradient is Nothing):
        let openingGradient = gamePhase.interpolate(forOpening: 1.0, forEndgame: 0.0)
        let endgameGradient = 1.0 - openingGradient
        gradient.openingPassedPawnTable[index] = if us == black: -openingGradient else: openingGradient
        gradient.endgamePassedPawnTable[index] = if us == black: -endgameGradient else: endgameGradient

    gamePhase.interpolate(evalProperties.openingPassedPawnTable[index], evalProperties.endgamePassedPawnTable[index])

func evaluatePawn(
    position: Position,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    evalProperties: EvalProperties,
    gradient: var GradientOrNothing
): Value =
    result = 0
    
    # passed pawn
    if position.isPassedPawn(us, enemy, square):
        result += evalProperties.bonusPassedPawn(gamePhase, square, us, gradient)

    # isolated pawn
    if (square.isLeftEdge or (position[pawn] and position[us] and files[square.left]) == 0) and
    (square.isRightEdge or (position[pawn] and position[us] and files[square.right]) == 0):
        result += evalProperties.bonusIsolatedPawn

        when not (gradient is Nothing):
            gradient.bonusIsolatedPawn = if us == black: -1.0 else: 1.0

func evaluateKnight(
    position: Position,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    evalProperties: EvalProperties,
    gradient: var GradientOrNothing
): Value =
    let reachableSquares = position.numReachableSquares(knight, square, us).float32
    when not (gradient is Nothing):
        gradient.mobilityMultiplierKnight = if us == black: -reachableSquares else: reachableSquares
    (reachableSquares * evalProperties.mobilityMultiplierKnight).Value

func evaluateBishop(
    position: Position,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    evalProperties: EvalProperties,
    gradient: var GradientOrNothing
): Value =
    let reachableSquares = position.numReachableSquares(bishop, square, us).float32
    when not (gradient is Nothing):
        gradient.mobilityMultiplierBishop = if us == black: -reachableSquares else: reachableSquares
    result = (reachableSquares * evalProperties.mobilityMultiplierBishop).Value
    
    if (position[us] and position[bishop] and (not bitAt[square])) != 0:
        result += evalProperties.bonusBothBishops

        when not (gradient is Nothing):
            gradient.bonusBothBishops = if us == black: -1.0 else: 1.0

func evaluateRook(
    position: Position,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    evalProperties: EvalProperties,
    gradient: var GradientOrNothing
): Value =
    let reachableSquares = position.numReachableSquares(rook, square, us).float32
    when not (gradient is Nothing):
        gradient.mobilityMultiplierRook = if us == black: -reachableSquares else: reachableSquares
    result = (reachableSquares * evalProperties.mobilityMultiplierRook).Value
    
    # rook on open file
    if (files[square] and position[pawn]) == 0:
        result += evalProperties.bonusRookOnOpenFile

        when not (gradient is Nothing):
            gradient.bonusRookOnOpenFile = if us == black: -1.0 else: 1.0

func evaluateQueen(
    position: Position,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    evalProperties: EvalProperties,
    gradient: var GradientOrNothing
): Value =
    let reachableSquares = position.numReachableSquares(queen, square, us).float32
    when not (gradient is Nothing):
        gradient.mobilityMultiplierQueen = if us == black: -reachableSquares else: reachableSquares
    (reachableSquares * evalProperties.mobilityMultiplierQueen).Value

func evaluateKing(
    position: Position,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    evalProperties: EvalProperties,
    gradient: var GradientOrNothing
): Value =
    result = 0
    
    # rook on second rank/file is bad
    let enemyRooks = position[rook] and position[enemy];
    for (kingFile, rookFile) in [(a1,a2), (a8, a7), (a1, b1), (h1, g1)]:
        if (ranks[square] and ranks[kingFile]) != 0 and (enemyRooks and ranks[rookFile]) != 0:
            result += evalProperties.bonusRookSecondRankFromKing

            when not (gradient is Nothing):
                gradient.bonusRookSecondRankFromKing = if us == black: -1.0 else: 1.0            

            break

    # kingsafety by pawn shielding
    let numPossibleQueenAttack = queen.attackMask(square, position[pawn] and position[us]).countSetBits
    result -= gamePhase.interpolate(
        forOpening = (evalProperties.kingSafetyMultiplier*numPossibleQueenAttack.float32).Value,
        forEndgame = 0.Value
    )

    when not (gradient is Nothing):
        let openingGradient = gamePhase.interpolate(forOpening: 1.0, forEndgame: 0.0)
        gradient.kingSafetyMultiplier = -openingGradient*numPossibleQueenAttack.float32
        gradient.kingSafetyMultiplier *= (if us == black: -1.0 else: 1.0)

func evaluatePiece(
    position: Position,
    piece: Piece,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    evalProperties: EvalProperties,
    gradient: var GradientOrNothing
): Value =
    case piece:
    of pawn:
        return evaluatePawn(position, square, us, enemy, gamePhase, evalProperties, gradient)
    of knight:
        return evaluateKnight(position, square, us, enemy, gamePhase, evalProperties, gradient)
    of bishop:
        return evaluateBishop(position, square, us, enemy, gamePhase, evalProperties, gradient)
    of rook:
        return evaluateRook(position, square, us, enemy, gamePhase, evalProperties, gradient)
    of queen:
        return evaluateQueen(position, square, us, enemy, gamePhase, evalProperties, gradient)
    of king:
        return evaluateKing(position, square, us, enemy, gamePhase, evalProperties, gradient)
    else:
        assert false
    
func evaluatePieceType(
    position: Position,
    piece: Piece,
    gamePhase: GamePhase,
    evalProperties: EvalProperties,
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
            evalProperties.getPstValue(gamePhase, square, piece, currentUs, gradient) + #TODO improve NPS
            # defaultPieceSquareTable[gamePhase][currentUs][piece][square] +
            position.evaluatePiece(piece, square, currentUs, currentEnemy, gamePhase, evalProperties, gradient)
        
        if currentUs == us:
            result += currentResult
        else:
            result -= currentResult

func evaluate*(position: Position, evalProperties: EvalProperties, gradient: var GradientOrNothing): Value =
    if position.halfmoveClock >= 100:
        return 0

    result = 0
    let gamePhase = position.gamePhase
    for piece in pawn..king:
        result += position.evaluatePieceType(piece, gamePhase, evalProperties, gradient)



func evaluate*(position: Position): Value =
    var gradient: Nothing = nothing
    position.evaluate(defaultEvalProperties, gradient)
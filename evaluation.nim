import position
import types
import bitboard
import bitops
import pieceSquareTable
import utils

template numReachableSquares(position: Position, piece: Piece, square: Square, us: Color): int8 =
    (piece.attackMask(square, position.occupancy) and not position[us]).countSetBits.int8

# const penaltyIsolatedPawn = 10.Value
# const bonusBothBishops = 10.Value
# const bonusRookOnOpenFile = 5.Value
# const mobilityMultiplierKnight: float32 = 2.0
# const mobilityMultiplierBishop: float32 = 3.0
# const mobilityMultiplierRook: float32 = 4.0
# const mobilityMultiplierQueen: float32 = 2.0
# const penaltyRookSecondRankFromKing = 10.Value
# const kingSafetyMultiplier: float32 = 2.5

type EvalPropertiesTemplate[ValueType] = object
    openingPst: array[pawn..king, array[a1..h8, ValueType]]
    endgamePst: array[pawn..king, array[a1..h8, ValueType]]
    openingPassedPawnTable: array[8, ValueType]
    endgamePassedPawnTable: array[8, ValueType]
    penaltyIsolatedPawn: ValueType
    bonusBothBishops: ValueType
    bonusRookOnOpenFile: ValueType
    mobilityMultiplierKnight: float32
    mobilityMultiplierBishop: float32
    mobilityMultiplierRook: float32
    mobilityMultiplierQueen: float32
    penaltyRookSecondRankFromKing: ValueType
    kingSafetyMultiplier: float32

type EvalProperties = EvalPropertiesTemplate[Value]
type EvalPropertiesGradient = EvalPropertiesTemplate[float32]

const defaultEvalProperties = EvalProperties(
    openingPst: [
        pawn:
        [
            0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value,
            45.Value, 45.Value, 45.Value, 45.Value, 45.Value, 45.Value, 45.Value, 45.Value,
            10.Value, 10.Value, 20.Value, 30.Value, 30.Value, 20.Value, 10.Value, 10.Value,
            5.Value, 5.Value, 10.Value, 25.Value, 25.Value, 10.Value, 5.Value, 5.Value,
            0.Value, 0.Value, 0.Value, 20.Value, 20.Value, 0.Value, 0.Value, 0.Value,
            5.Value, -5.Value, -10.Value, 0.Value, 0.Value, -10.Value, -5.Value, 5.Value,
            5.Value, 10.Value, 10.Value, -20.Value, -20.Value, 10.Value, 10.Value, 5.Value,
            0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value
        ],
        knight:
        [
            -50.Value, -40.Value, -30.Value, -30.Value, -30.Value, -30.Value, -40.Value, -50,
            -40.Value, -20.Value, 0.Value, 0.Value, 0.Value, 0.Value, -20.Value, -40,
            -30.Value, 0.Value, 10.Value, 15.Value, 15.Value, 10.Value, 0.Value, -30,
            -30.Value, 5.Value, 15.Value, 20.Value, 20.Value, 15.Value, 5.Value, -30,
            -30.Value, 0.Value, 15.Value, 20.Value, 20.Value, 15.Value, 0.Value, -30,
            -30.Value, 5.Value, 10.Value, 15.Value, 15.Value, 10.Value, 5.Value, -30,
            -40.Value, -20.Value, 0.Value, 5.Value, 5.Value, 0.Value, -20.Value, -40,
            -50.Value, -40.Value, -30.Value, -30.Value, -30.Value, -30.Value, -40.Value, -50.Value
        ],
        bishop:
        [
            -20.Value, -10.Value, -10.Value, -10.Value, -10.Value, -10.Value, -10.Value, -20.Value,
            -10.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, -10.Value,
            -10.Value, 0.Value, 5.Value, 10.Value, 10.Value, 5.Value, 0.Value, -10.Value,
            -10.Value, 5.Value, 5.Value, 10.Value, 10.Value, 5.Value, 5.Value, -10.Value,
            -10.Value, 0.Value, 10.Value, 10.Value, 10.Value, 10.Value, 0.Value, -10.Value,
            -10.Value, 10.Value, 10.Value, 10.Value, 10.Value, 10.Value, 10.Value, -10.Value,
            -10.Value, 5.Value, 0.Value, 0.Value, 0.Value, 0.Value, 5.Value, -10.Value,
            -20.Value, -10.Value, -10.Value, -10.Value, -10.Value, -10.Value, -10.Value, -20.Value
        ],
        rook:
        [
            0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value,
            5.Value, 10.Value, 10.Value, 10.Value, 10.Value, 10.Value, 10.Value, 5.Value,
            -5.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, -5.Value,
            -5.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, -5.Value,
            -5.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, -5.Value,
            -5.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, -5.Value,
            -5.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, -5.Value,
            0.Value, 0.Value, 0.Value, 5.Value, 5.Value, 0.Value, 0.Value, 0.Value
        ],
        queen:
        [
            -20.Value, -10.Value, -10.Value, -5.Value, -5.Value, -10.Value, -10.Value, -20.Value,
            -10.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, -10.Value,
            -10.Value, 0.Value, 5.Value, 5.Value, 5.Value, 5.Value, 0.Value, -10.Value,
            -5.Value, 0.Value, 5.Value, 5.Value, 5.Value, 5.Value, 0.Value, -5.Value,
            0.Value, 0.Value, 5.Value, 5.Value, 5.Value, 5.Value, 0.Value, -5.Value,
            -10.Value, 5.Value, 5.Value, 5.Value, 5.Value, 5.Value, 0.Value, -10.Value,
            -10.Value, 0.Value, 5.Value, 0.Value, 0.Value, 0.Value, 0.Value, -10.Value,
            -20.Value, -10.Value, -10.Value, -5.Value, -5.Value, -10.Value, -10.Value, -20.Value
        ],
        king:
        [
            -30.Value, -40.Value, -40.Value, -50.Value, -50.Value, -40.Value, -40.Value, -30.Value,
            -30.Value, -40.Value, -40.Value, -50.Value, -50.Value, -40.Value, -40.Value, -30.Value,
            -30.Value, -40.Value, -40.Value, -50.Value, -50.Value, -40.Value, -40.Value, -30.Value,
            -30.Value, -40.Value, -40.Value, -50.Value, -50.Value, -40.Value, -40.Value, -30.Value,
            -20.Value, -30.Value, -30.Value, -40.Value, -40.Value, -30.Value, -30.Value, -20.Value,
            -10.Value, -20.Value, -20.Value, -20.Value, -20.Value, -20.Value, -20.Value, -10.Value,
            20.Value, 20.Value, 0.Value, 0.Value, 0.Value, 0.Value, 20.Value, 20.Value,
            20.Value, 30.Value, 10.Value, 0.Value, 0.Value, 10.Value, 30.Value, 20.Value
        ],
    ],
    endgamePst: [
        pawn:
        [
            0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value,
            90.Value, 90.Value, 90.Value, 90.Value, 90.Value, 90.Value, 90.Value, 90.Value,
            30.Value, 30.Value, 40.Value, 45.Value, 45.Value, 40.Value, 40.Value, 30.Value,
            20.Value, 20.Value, 20.Value, 25.Value, 25.Value, 20.Value, 20.Value, 20.Value,
            0.Value, 0.Value, 0.Value, 20.Value, 20.Value, 0.Value, 0.Value, 0.Value,
            -5.Value, -5.Value, -10.Value, -10.Value, -10.Value, -10.Value, -5.Value, -5.Value,
            -15.Value, -15.Value, -15.Value, -20.Value, -20.Value, -15.Value, -15.Value, -15.Value,
            0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value
        ],
        knight:
        [
            -50.Value, -40.Value, -30.Value, -30.Value, -30.Value, -30.Value, -40.Value, -50.Value,
            -40.Value, -20.Value, 0.Value, 0.Value, 0.Value, 0.Value, -20.Value, -40.Value,
            -30.Value, 0.Value, 10.Value, 15.Value, 15.Value, 10.Value, 0.Value, -30.Value,
            -30.Value, 5.Value, 15.Value, 20.Value, 20.Value, 15.Value, 5.Value, -30.Value,
            -30.Value, 0.Value, 15.Value, 20.Value, 20.Value, 15.Value, 0.Value, -30.Value,
            -30.Value, 5.Value, 10.Value, 15.Value, 15.Value, 10.Value, 5.Value, -30.Value,
            -40.Value, -20.Value, 0.Value, 5.Value, 5.Value, 0.Value, -20.Value, -40.Value,
            -50.Value, -40.Value, -30.Value, -30.Value, -30.Value, -30.Value, -40.Value, -50.Value
        ],
        bishop:
        [
            -20.Value, -10.Value, -10.Value, -10.Value, -10.Value, -10.Value, -10.Value, -20.Value,
            -10.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, -10.Value,
            -10.Value, 0.Value, 5.Value, 10.Value, 10.Value, 5.Value, 0.Value, -10.Value,
            -10.Value, 5.Value, 5.Value, 10.Value, 10.Value, 5.Value, 5.Value, -10.Value,
            -10.Value, 0.Value, 10.Value, 10.Value, 10.Value, 10.Value, 0.Value, -10.Value,
            -10.Value, 10.Value, 10.Value, 10.Value, 10.Value, 10.Value, 10.Value, -10.Value,
            -10.Value, 5.Value, 0.Value, 0.Value, 0.Value, 0.Value, 5.Value, -10.Value,
            -20.Value, -10.Value, -10.Value, -10.Value, -10.Value, -10.Value, -10.Value, -20.Value
        ],
        rook:
        [
            0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value,
            0.Value, 5.Value, 5.Value, 5.Value, 5.Value, 5.Value, 5.Value, 0.Value,
            -5.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, -5.Value,
            -5.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, -5.Value,
            -5.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, -5.Value,
            -5.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, -5.Value,
            -5.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, -5.Value,
            0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value
        ],
        queen:
        [
            -20.Value, -10.Value, -10.Value, -5.Value, -5.Value, -10.Value, -10.Value, -20.Value,
            -10.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, -10.Value,
            -10.Value, 0.Value, 5.Value, 5.Value, 5.Value, 5.Value, 0.Value, -10.Value,
            -5.Value, 0.Value, 5.Value, 5.Value, 5.Value, 5.Value, 0.Value, -5.Value,
            0.Value, 0.Value, 5.Value, 5.Value, 5.Value, 5.Value, 0.Value, -5.Value,
            -10.Value, 0.Value, 5.Value, 5.Value, 5.Value, 5.Value, 0.Value, -10.Value,
            -10.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, 0.Value, -10.Value,
            -20.Value, -10.Value, -10.Value, -5.Value, -5.Value, -10.Value, -10.Value, -20.Value
        ],
        king:
        [
            -50.Value, -40.Value, -30.Value, -20.Value, -20.Value, -30.Value, -40.Value, -50.Value,
            -30.Value, -20.Value, -10.Value, 0.Value, 0.Value, -10.Value, -20.Value, -30.Value,
            -30.Value, -10.Value, 20.Value, 30.Value, 30.Value, 20.Value, -10.Value, -30.Value,
            -30.Value, -10.Value, 30.Value, 40.Value, 40.Value, 30.Value, -10.Value, -30.Value,
            -30.Value, -10.Value, 30.Value, 40.Value, 40.Value, 30.Value, -10.Value, -30.Value,
            -30.Value, -10.Value, 20.Value, 30.Value, 30.Value, 20.Value, -10.Value, -30.Value,
            -30.Value, -30.Value, 0.Value, 0.Value, 0.Value, 0.Value, -30.Value, -30.Value,
            -50.Value, -30.Value, -30.Value, -30.Value, -30.Value, -30.Value, -30.Value, -50.Value
        ],
    ],
    openingPassedPawnTable: [0.Value, 0.Value, 0.Value, 10.Value, 15.Value, 20.Value, 45.Value, 0.Value],
    endgamePassedPawnTable: [0.Value, 20.Value, 30.Value, 40.Value, 60.Value, 100.Value, 120.Value, 0.Value],
    penaltyIsolatedPawn: 10.Value,
    bonusBothBishops: 10.Value,
    bonusRookOnOpenFile: 5.Value,
    mobilityMultiplierKnight: 2.0,
    mobilityMultiplierBishop: 3.0,
    mobilityMultiplierRook: 4.0,
    mobilityMultiplierQueen: 2.0,
    penaltyRookSecondRankFromKing: 10.Value,
    kingSafetyMultiplier: 2.5
)

func getPstValue(evalProperties: EvalProperties, gamePhase: GamePhase, square: Square, piece: Piece, us: Color): Value =
    let square = if us == black: square else: square.mirror
    gamePhase.interpolate(
        forOpening = evalProperties.openingPst[piece][square],
        forEndgame = evalProperties.endgamePst[piece][square]
    )

func bonusPassedPawn(evalProperties: EvalProperties, gamePhase: GamePhase, square: Square, us: Color): Value =
    var index = square.int8 div 8
    if us == black:
        index = 7 - index
    gamePhase.interpolate(evalProperties.openingPassedPawnTable[index], evalProperties.endgamePassedPawnTable[index])

func evaluatePawn(
    position: Position,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    evalProperties: EvalProperties
): Value =
    result = 0
    
    # passed pawn
    if position.isPassedPawn(us, enemy, square):
        result += evalProperties.bonusPassedPawn(gamePhase, square, us)

    # isolated pawn
    if (square.isLeftEdge or (position[pawn] and position[us] and files[square.left]) == 0) and
    (square.isRightEdge or (position[pawn] and position[us] and files[square.right]) == 0):
        result -= evalProperties.penaltyIsolatedPawn

func evaluateKnight(
    position: Position,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    evalProperties: EvalProperties
): Value =
    (position.numReachableSquares(knight, square, us).float32 * evalProperties.mobilityMultiplierKnight).Value

func evaluateBishop(
    position: Position,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    evalProperties: EvalProperties
): Value =
    result = (position.numReachableSquares(bishop, square, us).float32 * evalProperties.mobilityMultiplierBishop).Value
    if (position[us] and position[bishop] and (not bitAt[square])) != 0:
        result += evalProperties.bonusBothBishops

func evaluateRook(
    position: Position,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    evalProperties: EvalProperties
): Value =
    result = (position.numReachableSquares(rook, square, us).float32 * evalProperties.mobilityMultiplierRook).Value
    # rook on open file
    if (files[square] and position[pawn]) == 0:
        result += evalProperties.bonusRookOnOpenFile

func evaluateQueen(
    position: Position,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    evalProperties: EvalProperties
): Value =
    (position.numReachableSquares(queen, square, us).float32 * evalProperties.mobilityMultiplierQueen).Value

func evaluateKing(
    position: Position,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    evalProperties: EvalProperties
): Value =
    result = 0
    
    # rook on second rank/file is bad
    let enemyRooks = position[rook] and position[enemy];
    for (kingFile, rookFile) in [(a1,a2), (a8, a7), (a1, b1), (h1, g1)]:
        if (ranks[square] and ranks[kingFile]) != 0 and (enemyRooks and ranks[rookFile]) != 0:
            result -= evalProperties.penaltyRookSecondRankFromKing
            break

    # kingsafety by pawn shielding
    let numPossibleQueenAttack = queen.attackMask(square, position[pawn] and position[us]).countSetBits
    result -= gamePhase.interpolate(
        forOpening = (evalProperties.kingSafetyMultiplier*numPossibleQueenAttack.float32).Value,
        forEndgame = 0.Value
    )

func evaluatePiece(
    position: Position,
    piece: Piece,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    evalProperties: EvalProperties
): Value =
    const evaluationFunctions = [
        pawn: evaluatePawn,
        knight: evaluateKnight,
        bishop: evaluateBishop,
        rook: evaluateRook,
        queen: evaluateQueen,
        king: evaluateKing
    ]
    assert piece != noPiece
    evaluationFunctions[piece](position, square, us, enemy, gamePhase, evalProperties)
    
func evaluatePieceType(
    position: Position,
    piece: Piece,
    gamePhase: GamePhase,
    evalProperties: EvalProperties
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
            evalProperties.getPstValue(gamePhase, square, piece, currentUs) + #TODO improve NPS
            # defaultPieceSquareTable[gamePhase][currentUs][piece][square] +
            position.evaluatePiece(piece, square, currentUs, currentEnemy, gamePhase, evalProperties)
        
        if currentUs == us:
            result += currentResult
        else:
            result -= currentResult

func evaluate*(position: Position, evalProperties: EvalProperties): Value =
    if position.halfmoveClock >= 100:
        return 0

    result = 0
    let gamePhase = position.gamePhase
    for piece in pawn..king:
        result += position.evaluatePieceType(piece, gamePhase, evalProperties)

func evaluate*(position: Position): Value =
    position.evaluate(defaultEvalProperties)
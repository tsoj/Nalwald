import position
import types
import bitboard
import bitops
import pieceSquareTable
import utils

template numReachableSquares(position: Position, piece: Piece, square: Square, us: Color): int8 =
    (piece.attackMask(square, position.occupancy) and not position[us]).countSetBits.int8


const openingPassedPawnTable = [0.Value, 0.Value, 0.Value, 10.Value, 15.Value, 20.Value, 45.Value, 0.Value]
const endgamePassedPawnTable = [0.Value, 20.Value, 30.Value, 40.Value, 60.Value, 100.Value, 120.Value, 0.Value]

const penaltyIsolatedPawn = 10.Value
const bonusBothBishops = 10.Value
const bonusRookOnOpenFile = 5.Value
const mobilityMultiplierKnight: float32 = 2.0
const mobilityMultiplierBishop: float32 = 3.0
const mobilityMultiplierRook: float32 = 4.0
const mobilityMultiplierQueen: float32 = 2.0
const penaltyRookSecondRankFromKing = 10.Value
const kingSafetyMultiplier: float32 = 2.5

type EvalProperties = object
    openingPst: array[pawn..king, array[a1..h8, Value]]
    endgamePst: array[pawn..king, array[a1..h8, Value]]
    openingPassedPawnTable: array[8, Value]
    endgamePassedPawnTable: array[8, Value]
    penaltyIsolatedPawn: Value
    bonusBothBishops: Value
    bonusRookOnOpenFile: Value
    mobilityMultiplierKnight: float32
    mobilityMultiplierBishop: float32
    mobilityMultiplierRook: float32
    mobilityMultiplierQueen: float32
    penaltyRookSecondRankFromKing: Value
    kingSafetyMultiplier: float32

func getPstValue(evalProperties: EvalProperties, square: Square, piece: Piece, us: Color): Value =
    let square = if us == black: square else: square.mirror
    gamePhase.interpolate(
        forOpening: evalProperties.openingPst[piece][square],
        forEndgame: evalProperties.endgamePst[piece][square]
    )


func bonusPassedPawn(gamePhase: GamePhase, square: Square, us: Color): Value =
    var index = square.int8 div 8
    if us == black:
        index = 7 - index
    gamePhase.interpolate(openingPassedPawnTable[index], endgamePassedPawnTable[index])

func evaluatePawn(position: Position, square: Square, us, enemy: Color, gamePhase: GamePhase): Value =
    result = 0
    
    # passed pawn
    if position.isPassedPawn(us, enemy, square):
        result += bonusPassedPawn(gamePhase, square, us)

    # isolated pawn
    if (square.isLeftEdge or (position[pawn] and position[us] and files[square.left]) == 0) and
    (square.isRightEdge or (position[pawn] and position[us] and files[square.right]) == 0):
        result -= penaltyIsolatedPawn

func evaluateKnight(position: Position, square: Square, us, enemy: Color, gamePhase: GamePhase): Value =
    (position.numReachableSquares(knight, square, us).float32 * mobilityMultiplierKnight).Value

func evaluateBishop(position: Position, square: Square, us, enemy: Color, gamePhase: GamePhase): Value =
    result = (position.numReachableSquares(bishop, square, us).float32 * mobilityMultiplierBishop).Value
    if (position[us] and position[bishop] and (not bitAt[square])) != 0:
        result += bonusBothBishops

func evaluateRook(position: Position, square: Square, us, enemy: Color, gamePhase: GamePhase): Value =
    result = (position.numReachableSquares(rook, square, us).float32 * mobilityMultiplierRook).Value
    # rook on open file
    if (files[square] and position[pawn]) == 0:
        result += bonusRookOnOpenFile

func evaluateQueen(position: Position, square: Square, us, enemy: Color, gamePhase: GamePhase): Value =
    (position.numReachableSquares(queen, square, us).float32 * mobilityMultiplierQueen).Value

func evaluateKing(position: Position, square: Square, us, enemy: Color, gamePhase: GamePhase): Value =
    result = 0
    
    # rook on second rank/file is bad
    let enemyRooks = position[rook] and position[enemy];
    for (kingFile, rookFile) in [(a1,a2), (a8, a7), (a1, b1), (h1, g1)]:
        if (ranks[square] and ranks[kingFile]) != 0 and (enemyRooks and ranks[rookFile]) != 0:
            result -= penaltyRookSecondRankFromKing
            break

    # kingsafety by pawn shielding
    let numPossibleQueenAttack = queen.attackMask(square, position[pawn] and position[us]).countSetBits
    result -= gamePhase.interpolate(
        forOpening = (kingSafetyMultiplier*numPossibleQueenAttack.float32).Value,
        forEndgame = 0.Value
    )

func evaluatePiece(position: Position, piece: Piece, square: Square, us, enemy: Color, gamePhase: GamePhase): Value =
    const evaluationFunctions = [
        pawn: evaluatePawn,
        knight: evaluateKnight,
        bishop: evaluateBishop,
        rook: evaluateRook,
        queen: evaluateQueen,
        king: evaluateKing
    ]
    assert piece != noPiece
    evaluationFunctions[piece](position, square, us, enemy, gamePhase)
    
func evaluatePieceType(position: Position, piece: Piece, gamePhase: GamePhase): Value  =
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
            defaultPieceSquareTable[gamePhase][currentUs][piece][square] +
            position.evaluatePiece(piece, square, currentUs, currentEnemy, gamePhase)
        
        if currentUs == us:
            result += currentResult
        else:
            result -= currentResult

func evaluate*(position: Position): Value =
    if position.halfmoveClock >= 100:
        return 0

    result = 0
    let gamePhase = position.gamePhase
    for piece in pawn..king:
        result += position.evaluatePieceType(piece, gamePhase)

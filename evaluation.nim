import position
import types
import bitboard
import bitops
import pieceSquareTable
import utils

template numReachableSquares(position: Position, piece: Piece, square: Square, us: Color): int8 =
    (piece.attackMask(square, position.occupancy) and not position[us]).countSetBits.int8

const penaltyIsolatedPawn = 10.float32
const bonusBothBishops = 10.float32
const bonusRookOnOpenFile = 5.float32
const mobilityMultiplierKnight = 2.0.float32
const mobilityMultiplierBishop = 3.0.float32
const mobilityMultiplierRook = 4.0.float32
const mobilityMultiplierQueen = 2.0.float32
const penaltyRookSecondRankFromKing = 10.float32
const kingSafetyMultiplier = 2.5.float32

const passedPawnOpeningTable = [0.float32, 0.float32, 0.float32, 10.float32, 15.float32, 20.float32, 45.float32, 0.float32]
const passedPawnEndgameTable = [0.float32, 20.float32, 30.float32, 40.float32, 60.float32, 100.float32, 120.float32, 0.float32]

func bonusPassedPawn(gamePhase: GamePhase, square: Square, us: Color): auto =
    var index = square.int8 div 8
    if us == black:
        index = 7 - index
    gamePhase.interpolate(passedPawnOpeningTable[index], passedPawnEndgameTable[index])

func evaluatePawn(position: Position, square: Square, us, enemy: Color, gamePhase: GamePhase): Value =
    result = 0
    
    # passed pawn
    if position.isPassedPawn(us, enemy, square):
        result += bonusPassedPawn(gamePhase, square, us).Value

    # isolated pawn
    if (square.isLeftEdge or (position[pawn] and position[us] and files[square.left]) == 0) and
    (square.isRightEdge or (position[pawn] and position[us] and files[square.right]) == 0):
        result -= penaltyIsolatedPawn.Value

func evaluateKnight(position: Position, square: Square, us, enemy: Color, gamePhase: GamePhase): Value =
    (position.numReachableSquares(knight, square, us).float32 * mobilityMultiplierKnight).Value

func evaluateBishop(position: Position, square: Square, us, enemy: Color, gamePhase: GamePhase): Value =
    result = (position.numReachableSquares(bishop, square, us).float32 * mobilityMultiplierBishop).Value
    if (position[us] and position[bishop] and (not bitAt[square])) != 0:
        result += bonusBothBishops.Value

func evaluateRook(position: Position, square: Square, us, enemy: Color, gamePhase: GamePhase): Value =
    result = (position.numReachableSquares(rook, square, us).float32 * mobilityMultiplierRook).Value
    # rook on open file
    if (files[square] and position[pawn]) == 0:
        result += bonusRookOnOpenFile.Value

func evaluateQueen(position: Position, square: Square, us, enemy: Color, gamePhase: GamePhase): Value =
    (position.numReachableSquares(queen, square, us).float32 * mobilityMultiplierQueen).Value

func evaluateKing(position: Position, square: Square, us, enemy: Color, gamePhase: GamePhase): Value =
    result = 0
    
    # rook on second rank/file is bad
    let enemyRooks = position[rook] and position[enemy];
    for (kingFile, rookFile) in [(a1,a2), (a8, a7), (a1, b1), (h1, g1)]:
        if (ranks[square] and ranks[kingFile]) != 0 and (enemyRooks and ranks[rookFile]) != 0:
            result -= penaltyRookSecondRankFromKing.Value
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

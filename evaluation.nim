import position
import types
import bitboard
import bitops
import evalParameters
import utils
import defaultParameters

func numReachableSquares(position: Position, us: Color, attackMask: Bitboard): int8 =
    (attackMask and not position[us]).countSetBits.int8

type Nothing = enum nothing
type GradientOrNothing = EvalParametersFloat or Nothing

func getPstValue(
    evalParameters: EvalParameters,
    gamePhase: GamePhase,
    square: Square,
    piece: Piece,
    us: Color,
    kingSquare: array[ourKing..enemyKing, Square], # already mirrored accordingly
    gradient: var GradientOrNothing
): Value =
    let square = if us == black: square else: square.mirror

    when not (gradient is Nothing):

        var phaseGradient = [
            opening: gamePhase.interpolate(forOpening = 1.0, forEndgame = 0.0),
            endgame:  gamePhase.interpolate(forOpening = 0.0, forEndgame = 1.0)
        ]
        
        if us == black:
            phaseGradient[opening] *= -1.0
            phaseGradient[endgame]  *= -1.0

        for whoseKing in ourKing..enemyKing:
            for currentKingSquare in a1..h8:
                let multiplier = if currentKingSquare == kingSquare[whoseKing]: 10.0 else: 0.2

                for (kingSquare, pieceSquare) in [
                    (currentKingSquare, square),
                    (currentKingSquare.mirrorVertically, square.mirrorVertically)
                ]:
                    for phase in opening..endgame:
                        gradient.pst[phase][whoseKing][kingSquare][piece][pieceSquare] += phaseGradient[phase]*multiplier

    gamePhase.interpolate(
        forOpening =
            evalParameters.pst[opening][enemyKing][kingSquare[enemyKing]][piece][square] +
            evalParameters.pst[opening][ourKing][kingSquare[ourKing]][piece][square],
        forEndgame =
            evalParameters.pst[endgame][enemyKing][kingSquare[enemyKing]][piece][square] +
            evalParameters.pst[endgame][ourKing][kingSquare[ourKing]][piece][square]
    )

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
        forOpening = evalParameters.openingPassedPawnTable[index],
        forEndgame = evalParameters.endgamePassedPawnTable[index]
    )

#-------------- pawn evaluation --------------#

func evaluatePawn(
    position: Position,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    kingSquare: array[white..black, Square],
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
        result += evalParameters.bonusIsolatedPawn

        when not (gradient is Nothing):
            gradient.bonusIsolatedPawn += (if us == black: -1.0 else: 1.0)

    # has two neighbors
    if (not square.isLeftEdge) and (not square.isRightEdge) and
    (position[us] and position[pawn] and files[square.left]) != 0 and
    (position[us] and position[pawn] and files[square.right]) != 0:
        result += evalParameters.bonusPawnHasTwoNeighbors

        when not (gradient is Nothing):
            gradient.bonusPawnHasTwoNeighbors += (if us == black: -1.0 else: 1.0)

#-------------- knight evaluation --------------#

func evaluateKnight(
    position: Position,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    kingSquare: array[white..black, Square],
    evalParameters: EvalParameters,
    gradient: var GradientOrNothing
): Value =
    result = 0

    let attackMask = knight.attackMask(square, position.occupancy)
    
    # mobility
    let reachableSquares = position.numReachableSquares(us, attackMask).float32
    result += (reachableSquares * evalParameters.mobilityMultiplierKnight).Value

    when not (gradient is Nothing):
        gradient.mobilityMultiplierKnight += (if us == black: -reachableSquares else: reachableSquares)/8.0

#-------------- bishop evaluation --------------#

func evaluateBishop(
    position: Position,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    kingSquare: array[white..black, Square],
    evalParameters: EvalParameters,
    gradient: var GradientOrNothing
): Value =
    result = 0

    let attackMask = bishop.attackMask(square, position.occupancy)

    # mobility
    let reachableSquares = position.numReachableSquares(us, attackMask).float32
    result += (reachableSquares * evalParameters.mobilityMultiplierBishop).Value

    when not (gradient is Nothing):
        gradient.mobilityMultiplierBishop += (if us == black: -reachableSquares else: reachableSquares)/8.0
    
    # targeting enemy king area
    if (attackMask and king.attackMask(kingSquare[enemy], 0)) != 0:
        result += evalParameters.bonusBishopTargetingKingArea

        when not (gradient is Nothing):
            gradient.bonusBishopTargetingKingArea += (if us == black: -1.0 else: 1.0)
    
    # both bishops
    if (position[us] and position[bishop] and (not bitAt[square])) != 0:
        result += evalParameters.bonusBothBishops

        when not (gradient is Nothing):
            gradient.bonusBothBishops += (if us == black: -1.0 else: 1.0)


#-------------- rook evaluation --------------#

func evaluateRook(
    position: Position,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    kingSquare: array[white..black, Square],
    evalParameters: EvalParameters,
    gradient: var GradientOrNothing
): Value =
    result = 0

    let attackMask = rook.attackMask(square, position.occupancy)

    # mobility
    let reachableSquares = position.numReachableSquares(us, attackMask).float32
    result += (reachableSquares * evalParameters.mobilityMultiplierRook).Value

    when not (gradient is Nothing):
        gradient.mobilityMultiplierRook += (if us == black: -reachableSquares else: reachableSquares)/8.0
    
    # targeting enemy king area
    if (attackMask and king.attackMask(kingSquare[enemy], 0)) != 0:
        result += evalParameters.bonusRookTargetingKingArea

        when not (gradient is Nothing):
            gradient.bonusRookTargetingKingArea += (if us == black: -1.0 else: 1.0)
    
    # rook on open file
    if (files[square] and position[pawn]) == 0:
        result += evalParameters.bonusRookOnOpenFile

        when not (gradient is Nothing):
            gradient.bonusRookOnOpenFile += (if us == black: -1.0 else: 1.0)

#-------------- queen evaluation --------------#

func evaluateQueen(
    position: Position,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    kingSquare: array[white..black, Square],
    evalParameters: EvalParameters,
    gradient: var GradientOrNothing
): Value =
    result = 0

    let attackMask = queen.attackMask(square, position.occupancy)

    # mobility
    let reachableSquares = position.numReachableSquares(us, attackMask).float32
    result += (reachableSquares * evalParameters.mobilityMultiplierQueen).Value
    
    # targeting enemy king area
    if (attackMask and king.attackMask(kingSquare[enemy], 0)) != 0:
        result += evalParameters.bonusQueenTargetingKingArea

        when not (gradient is Nothing):
            gradient.bonusQueenTargetingKingArea += (if us == black: -1.0 else: 1.0)

    when not (gradient is Nothing):
        gradient.mobilityMultiplierQueen += (if us == black: -reachableSquares else: reachableSquares)/8.0

#-------------- king evaluation --------------#

func evaluateKing(
    position: Position,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    kingSquare: array[white..black, Square],
    evalParameters: EvalParameters,
    gradient: var GradientOrNothing
): Value =
    result = 0
    
    # rook on second rank is bad
    let enemyRooks = position[rook] and position[enemy];
    for (kingRank, rookRank) in [(a1,a2), (a8, a7)]:
        if (ranks[square] and ranks[kingRank]) != 0 and (enemyRooks and ranks[rookRank]) != 0:
            result += evalParameters.bonusRookSecondRankFromKing

            when not (gradient is Nothing):
                gradient.bonusRookSecondRankFromKing += (if us == black: -1.0 else: 1.0)

            break

    # kingsafety by pawn shielding
    let numPossibleQueenAttack = queen.attackMask(square, position[pawn] and position[us]).countSetBits
    result -= gamePhase.interpolate(
        forOpening = (evalParameters.kingSafetyMultiplier*numPossibleQueenAttack.float32).Value,
        forEndgame = 0.Value
    )

    when not (gradient is Nothing):
        let openingGradient = gamePhase.interpolate(forOpening = 1.0, forEndgame = 0.0)
        gradient.kingSafetyMultiplier += -openingGradient*numPossibleQueenAttack.float32 * (if us == black: -1.0 else: 1.0)

func evaluatePiece(
    position: Position,
    piece: Piece,
    square: Square,
    us, enemy: Color,
    gamePhase: GamePhase,
    kingSquare: array[white..black, Square],
    evalParameters: EvalParameters,
    gradient: var GradientOrNothing
): Value =
    const evaluationFunctions = [
        pawn: evaluatePawn[GradientOrNothing],
        knight: evaluateKnight[GradientOrNothing],
        bishop: evaluateBishop[GradientOrNothing],
        rook: evaluateRook[GradientOrNothing],
        queen: evaluateQueen[GradientOrNothing],
        king: evaluateKing[GradientOrNothing]
    ]
    assert piece != noPiece
    evaluationFunctions[piece](position, square, us, enemy, gamePhase, kingSquare, evalParameters, gradient)
    
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

    let kingSquareMirrored = [
        white: kingSquare[white].mirror,
        black: kingSquare[black]
    ]

    var tmpOccupancy = position[piece]
    while tmpOccupancy != 0:
        let square = tmpOccupancy.removeTrailingOneBit.Square
        let currentUs = if (bitAt[square] and position[us]) != 0: us else: enemy
        let currentEnemy = currentUs.opposite

        let currentResult = 
            values[piece] +
            evalParameters.getPstValue(
                gamePhase, square, piece, currentUs,
                [ourKing: kingSquareMirrored[currentUs], enemyKing: kingSquareMirrored[currentEnemy]],
                gradient
            ) +
            position.evaluatePiece(piece, square, currentUs, currentEnemy, gamePhase, kingSquare, evalParameters, gradient)
        
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

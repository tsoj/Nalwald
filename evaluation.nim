import
    position,
    types,
    bitboard,
    bitops,
    evalParameters,
    utils,
    defaultParameters

func `+=`[T](a: var array[Phase, T], b: array[Phase, T]) =
    for phase in Phase:
        a[phase] += b[phase]

type Nothing = enum nothing
type GradientOrNothing = EvalParametersFloat or Nothing

func getPstValue(
    evalParameters: EvalParameters,
    square: Square,
    piece: Piece,
    us: Color,
    kingSquare: array[ourKing..enemyKing, Square], # already mirrored accordingly
    gradient: var GradientOrNothing
): array[Phase, Value] =
    let square = if us == black: square else: square.mirror

    for phase in Phase:
        result[phase] =
            evalParameters[phase].pst[enemyKing][kingSquare[enemyKing]][piece][square] +
            evalParameters[phase].pst[ourKing][kingSquare[ourKing]][piece][square]

    when not (gradient is Nothing):

        for whoseKing in ourKing..enemyKing:
            for currentKingSquare in a1..h8:
                let multiplier = if currentKingSquare == kingSquare[whoseKing]: 10.0 else: 0.2

                for (kingSquare, pieceSquare) in [
                    (currentKingSquare, square),
                    (currentKingSquare.mirrorVertically, square.mirrorVertically)
                ]:
                    for phase in Phase:
                        gradient[phase].pst[whoseKing][kingSquare][piece][pieceSquare] +=
                            (if us == black: -1.0 else: 1.0)*multiplier

func bonusPassedPawn(
    evalParameters: EvalParameters,
    square: Square,
    us: Color,
    gradient: var GradientOrNothing
): array[Phase, Value] =
    var index = square.int8 div 8
    if us == black:
        index = 7 - index

    for phase in Phase: result[phase] = evalParameters[phase].passedPawnTable[index]

    when not (gradient is Nothing):
        for phase in Phase: gradient[phase].passedPawnTable[index] += (if us == black: -1.0 else: 1.0)

func mobility(
    evalParameters: EvalParameters,
    position: Position,
    piece: Piece,
    us, enemy: Color,
    attackMask: Bitboard,
    gradient: var GradientOrNothing
): array[Phase, Value] =
    let reachableSquares = (attackMask and not position[us]).countSetBits.float

    for phase in Phase: result[phase] += (reachableSquares * evalParameters[phase].mobilityMultiplier[piece]).Value

    when not (gradient is Nothing):
        for phase in Phase:
            gradient[phase].mobilityMultiplier[piece] += (if us == black: -reachableSquares else: reachableSquares)/8.0

func targetingKingArea(
    evalParameters: EvalParameters,
    position: Position,
    piece: Piece,
    us, enemy: Color,
    kingSquare: array[white..black, Square],
    attackMask: Bitboard,
    gradient: var GradientOrNothing
): array[Phase, Value] =
    # knight and pawn are not included, as the king contextual piece square tables are enough in this case
    assert piece in bishop..queen
    if (attackMask and king.attackMask(kingSquare[enemy], 0)) != 0:
        for phase in Phase: result[phase] += evalParameters[phase].bonusTargetingKingArea[piece]

        when not (gradient is Nothing):
            for phase in Phase: gradient[phase].bonusTargetingKingArea[piece] += (if us == black: -1.0 else: 1.0)
    
    if (attackMask and bitAt[kingSquare[enemy]]) != 0:
        for phase in Phase: result[phase] += evalParameters[phase].bonusAttackingKing[piece]

        when not (gradient is Nothing):
            for phase in Phase: gradient[phase].bonusAttackingKing[piece] += (if us == black: -1.0 else: 1.0)

#-------------- pawn evaluation --------------#

func evaluatePawn(
    position: Position,
    square: Square,
    us, enemy: Color,
    kingSquare: array[white..black, Square],
    evalParameters: EvalParameters,
    gradient: var GradientOrNothing
): array[Phase, Value] =
    result = [opening: 0.Value, endgame: 0.Value]
    
    # passed pawn
    if position.isPassedPawn(us, enemy, square):
        result += evalParameters.bonusPassedPawn(square, us, gradient)

    # isolated pawn
    if (position[pawn] and position[us] and adjacentFiles[square]) == 0:
        for phase in Phase: result[phase] += evalParameters[phase].bonusIsolatedPawn

        when not (gradient is Nothing):
            for phase in Phase: gradient[phase].bonusIsolatedPawn += (if us == black: -1.0 else: 1.0)

    # has two neighbors
    elif (position[us] and position[pawn] and rightFiles[square]) != 0 and
    (position[us] and position[pawn] and leftFiles[square]) != 0:
        for phase in Phase: result[phase] += evalParameters[phase].bonusPawnHasTwoNeighbors

        when not (gradient is Nothing):
            for phase in Phase: gradient[phase].bonusPawnHasTwoNeighbors += (if us == black: -1.0 else: 1.0)

#-------------- knight evaluation --------------#

func evaluateKnight(
    position: Position,
    square: Square,
    us, enemy: Color,
    kingSquare: array[white..black, Square],
    evalParameters: EvalParameters,
    gradient: var GradientOrNothing
): array[Phase, Value] {.locks: 0.} =
    result = [opening: 0.Value, endgame: 0.Value]

    let attackMask = knight.attackMask(square, position.occupancy)
    
    # mobility
    result += evalParameters.mobility(position, knight, us, enemy, attackMask, gradient)

    # attacking bishop, rook, or queen
    if (attackMask and position[enemy] and (position[bishop] or position[rook] or position[queen])) != 0:
        for phase in Phase: result[phase] += evalParameters[phase].bonusKnightAttackingPiece

        when not (gradient is Nothing):
            for phase in Phase: gradient[phase].bonusKnightAttackingPiece += (if us == black: -1.0 else: 1.0)

#-------------- bishop evaluation --------------#

func evaluateBishop(
    position: Position,
    square: Square,
    us, enemy: Color,
    kingSquare: array[white..black, Square],
    evalParameters: EvalParameters,
    gradient: var GradientOrNothing
): array[Phase, Value] {.locks: 0.} =
    result = [opening: 0.Value, endgame: 0.Value]

    let attackMask = bishop.attackMask(square, position.occupancy)

    # mobility
    result += evalParameters.mobility(position, bishop, us, enemy, attackMask, gradient)
    
    # targeting enemy king area
    result += evalParameters.targetingKingArea(position, bishop, us, enemy, kingSquare, attackMask, gradient)
    
    # both bishops
    if (position[us] and position[bishop] and (not bitAt[square])) != 0:
        for phase in Phase: result[phase] += evalParameters[phase].bonusBothBishops

        when not (gradient is Nothing):
            for phase in Phase: gradient[phase].bonusBothBishops += (if us == black: -1.0 else: 1.0)


#-------------- rook evaluation --------------#

func evaluateRook(
    position: Position,
    square: Square,
    us, enemy: Color,
    kingSquare: array[white..black, Square],
    evalParameters: EvalParameters,
    gradient: var GradientOrNothing
): array[Phase, Value] {.locks: 0.} =
    result = [opening: 0.Value, endgame: 0.Value]

    let attackMask = rook.attackMask(square, position.occupancy)

    # mobility
    result += evalParameters.mobility(position, rook, us, enemy, attackMask, gradient)
    
    # targeting enemy king area
    result += evalParameters.targetingKingArea(position, rook, us, enemy, kingSquare, attackMask, gradient)
    
    # rook on open file
    if (files[square] and position[pawn]) == 0:
        for phase in Phase: result[phase] += evalParameters[phase].bonusRookOnOpenFile

        when not (gradient is Nothing):
            for phase in Phase: gradient[phase].bonusRookOnOpenFile += (if us == black: -1.0 else: 1.0)

#-------------- queen evaluation --------------#

func evaluateQueen(
    position: Position,
    square: Square,
    us, enemy: Color,
    kingSquare: array[white..black, Square],
    evalParameters: EvalParameters,
    gradient: var GradientOrNothing
): array[Phase, Value] {.locks: 0.} =
    result = [opening: 0.Value, endgame: 0.Value]

    let attackMask = queen.attackMask(square, position.occupancy)

    # mobility
    result += evalParameters.mobility(position, queen, us, enemy, attackMask, gradient)
    
    # targeting enemy king area
    result += evalParameters.targetingKingArea(position, queen, us, enemy, kingSquare, attackMask, gradient)

#-------------- king evaluation --------------#

func evaluateKing(
    position: Position,
    square: Square,
    us, enemy: Color,
    kingSquare: array[white..black, Square],
    evalParameters: EvalParameters,
    gradient: var GradientOrNothing
): array[Phase, Value] {.locks: 0.} =
    result = [opening: 0.Value, endgame: 0.Value]

    # kingsafety by pawn shielding
    let numPossibleQueenAttack = queen.attackMask(square, position[pawn] and position[us]).countSetBits.float
    for phase in Phase: result[phase] += (evalParameters[phase].kingSafetyMultiplier*numPossibleQueenAttack).Value

    when not (gradient is Nothing):
        for phase in Phase:
            gradient[phase].kingSafetyMultiplier += numPossibleQueenAttack * (if us == black: -1.0 else: 1.0)

func evaluatePiece(
    position: Position,
    piece: Piece,
    square: Square,
    us, enemy: Color,
    kingSquare: array[white..black, Square],
    evalParameters: EvalParameters,
    gradient: var GradientOrNothing
): array[Phase, Value] =
    const evaluationFunctions = [
        pawn: evaluatePawn[GradientOrNothing],
        knight: evaluateKnight[GradientOrNothing],
        bishop: evaluateBishop[GradientOrNothing],
        rook: evaluateRook[GradientOrNothing],
        queen: evaluateQueen[GradientOrNothing],
        king: evaluateKing[GradientOrNothing]
    ]
    assert piece != noPiece
    evaluationFunctions[piece](position, square, us, enemy, kingSquare, evalParameters, gradient)
    
func evaluatePieceType(
    position: Position,
    piece: Piece,
    evalParameters: EvalParameters,
    kingSquare: array[white..black, Square],
    gradient: var GradientOrNothing
): array[Phase, Value]  =
    result = [opening: 0.Value, endgame: 0.Value]
    let
        us = position.us
        enemy = position.enemy
    
    let kingSquareMirrored = [
        white: kingSquare[white].mirror,
        black: kingSquare[black]
    ]

    var tmpOccupancy = position[piece]
    while tmpOccupancy != 0:
        let square = tmpOccupancy.removeTrailingOneBit
        let currentUs = if (bitAt[square] and position[us]) != 0: us else: enemy
        let currentEnemy = currentUs.opposite

        var currentResult: array[Phase, Value] = [values[piece], values[piece]]
        currentResult += evalParameters.getPstValue(
            square, piece, currentUs,
            [ourKing: kingSquareMirrored[currentUs], enemyKing: kingSquareMirrored[currentEnemy]],
            gradient
        )
        currentResult +=
            position.evaluatePiece(piece, square, currentUs, currentEnemy, kingSquare, evalParameters, gradient)
        
        if currentUs == enemy:
            for phase in Phase: currentResult[phase] = -currentResult[phase]
        result += currentResult

func evaluate*(position: Position, evalParameters: EvalParameters, gradient: var GradientOrNothing): Value =
    if position.halfmoveClock >= 100:
        return 0.Value

    var value = [opening: 0.Value, endgame: 0.Value]

    let kingSquare = [white: position.kingSquare(white), black: position.kingSquare(black)]
    for piece in pawn..king:
        value += position.evaluatePieceType(piece, evalParameters, kingSquare, gradient)
    
    let gamePhase = position.gamePhase

    result = gamePhase.interpolate(forOpening = value[opening], forEndgame = value[endgame])

    when not (gradient is Nothing):
        gradient[opening] *= gamePhase.interpolate(forOpening = 1.0, forEndgame = 0.0)
        gradient[endgame] *= gamePhase.interpolate(forOpening = 0.0, forEndgame = 1.0)

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
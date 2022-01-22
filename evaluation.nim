import
    position,
    types,
    bitboard,
    bitops,
    evalParameters,
    utils,
    defaultParameters,
    algorithm

func `+=`[T](a: var array[Phase, T], b: array[Phase, T]) {.inline.} =
    for phase in Phase:
        a[phase] += b[phase]

type Nothing = enum nothing
type GradientOrNothing = EvalParametersFloat or Nothing

template whiteBlackGradient(): auto =
    (if us == black: -1.0 else: 1.0)

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

    when gradient isnot Nothing:

        for whoseKing in ourKing..enemyKing:
            for currentKingSquare in a1..h8:
                let multiplier = whiteBlackGradient() * (if currentKingSquare == kingSquare[whoseKing]:
                    2.0
                elif (currentKingSquare.toBitboard and mask3x3[kingSquare[whoseKing]]) != 0:
                    0.3
                elif (currentKingSquare.toBitboard and mask5x5[kingSquare[whoseKing]]) != 0:
                    0.2
                else:
                    0.1)

                for (kingSquare, pieceSquare) in [
                    (currentKingSquare, square),
                    (currentKingSquare.mirrorVertically, square.mirrorVertically)
                ]:
                    for phase in Phase: gradient[phase].pst[whoseKing][kingSquare][piece][pieceSquare] += multiplier

func pawnMaskIndex(
    position: Position,
    square: Square,
    us, enemy: Color
): int =
    template pmirror(x: auto): auto = (if us == black: x.mirror else: x)

    let square = square.pmirror

    assert not square.isEdge
    assert square >= b2

    let
        ourPawns = (position[us] and position[pawn]).pmirror shr (square.int8 - b2.int8)
        enemyPawns = (position[enemy] and position[pawn]).pmirror shr (square.int8 - b2.int8)

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

func pawnMaskBonus(
    evalParameters: EvalParameters,
    position: Position,
    square: Square,
    us, enemy: Color,
    gradient: var GradientOrNothing
): array[Phase, Value] =
    
    let index = position.pawnMaskIndex(square, us, enemy)
    for phase in Phase: result[phase] = evalParameters[phase].pawnMaskBonus[index]

    when gradient isnot Nothing:
        for phase in Phase:
            gradient[phase].pawnMaskBonus[index] += whiteBlackGradient()

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

    when gradient isnot Nothing:
        for phase in Phase: gradient[phase].passedPawnTable[index] += whiteBlackGradient()

func addSmooth(g: var openArray[float32], index: int, a: float32) =
    for (offset, f) in [(2, 0.1), (1, 0.2), (0, 1.0), (-1, 0.2), (-2, 0.1)]:
        if index + offset in g.low..g.high:
            g[index + offset] += a*f

func mobility(
    evalParameters: EvalParameters,
    position: Position,
    piece: Piece,
    us, enemy: Color,
    attackMask: Bitboard,
    gradient: var GradientOrNothing
): array[Phase, Value] =
    let reachableSquares = (attackMask and not position[us]).countSetBits

    for phase in Phase: result[phase] += evalParameters[phase].bonusMobility[piece][reachableSquares]

    when gradient isnot Nothing:
        for phase in Phase:
            gradient[phase].bonusMobility[piece].addSmooth(reachableSquares, whiteBlackGradient())

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

        when gradient isnot Nothing:
            for phase in Phase: gradient[phase].bonusTargetingKingArea[piece] += whiteBlackGradient()
    
    if (attackMask and kingSquare[enemy].toBitboard) != 0:
        for phase in Phase: result[phase] += evalParameters[phase].bonusAttackingKing[piece]

        when gradient isnot Nothing:
            for phase in Phase: gradient[phase].bonusAttackingKing[piece] += whiteBlackGradient()

func forkingMajorPieces(
    evalParameters: EvalParameters,
    position: Position,
    us, enemy: Color,
    attackMask: Bitboard,
    gradient: var GradientOrNothing
): array[Phase, Value] =
    if (attackMask and position[enemy] and (position[queen] or position[rook])).countSetBits >= 2:
        for phase in Phase: result[phase] = evalParameters[phase].bonusPieceForkedMajorPieces

        when gradient isnot Nothing:
            for phase in Phase: gradient[phase].bonusPieceForkedMajorPieces += whiteBlackGradient()

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

        when gradient isnot Nothing:
            for phase in Phase: gradient[phase].bonusIsolatedPawn += whiteBlackGradient()

    # has two neighbors
    elif (position[us] and position[pawn] and rightFiles[square]) != 0 and
    (position[us] and position[pawn] and leftFiles[square]) != 0:
        for phase in Phase: result[phase] += evalParameters[phase].bonusPawnHasTwoNeighbors

        when gradient isnot Nothing:
            for phase in Phase: gradient[phase].bonusPawnHasTwoNeighbors += whiteBlackGradient()


    # attacks enemy piece
    let pieces = position[knight] or position[bishop] or position[rook] or position[queen]
    if (position[enemy] and attackTablePawnCapture[us][square] and pieces) != 0:
        for phase in Phase: result[phase] += evalParameters[phase].bonusPawnAttacksPiece

        when gradient isnot Nothing: # TODO: reduce code duplication: "for phase in Phase: ... when gradient isnot ..."
            for phase in Phase: gradient[phase].bonusPawnAttacksPiece += whiteBlackGradient()


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

    # forks
    result += evalParameters.forkingMajorPieces(position, us, enemy, attackMask, gradient)

    # attacking bishop, rook, or queen
    if (attackMask and position[enemy] and (position[bishop] or position[rook] or position[queen])) != 0:
        for phase in Phase: result[phase] += evalParameters[phase].bonusKnightAttackingPiece

        when gradient isnot Nothing:
            for phase in Phase: gradient[phase].bonusKnightAttackingPiece += whiteBlackGradient()

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

    # forks
    result += evalParameters.forkingMajorPieces(position, us, enemy, attackMask, gradient)
    
    # targeting enemy king area
    result += evalParameters.targetingKingArea(
        position, bishop, us, enemy, kingSquare, attackMask, gradient
    )
    
    # both bishops
    if (position[us] and position[bishop] and (not square.toBitboard)) != 0:
        for phase in Phase: result[phase] += evalParameters[phase].bonusBothBishops

        when gradient isnot Nothing:
            for phase in Phase: gradient[phase].bonusBothBishops += whiteBlackGradient()


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
    result += evalParameters.targetingKingArea(
        position, rook, us, enemy, kingSquare, attackMask, gradient
    )
    
    # rook on open file
    if (files[square] and position[pawn]) == 0:
        for phase in Phase: result[phase] += evalParameters[phase].bonusRookOnOpenFile

        when gradient isnot Nothing:
            for phase in Phase: gradient[phase].bonusRookOnOpenFile += whiteBlackGradient()


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
    result += evalParameters.targetingKingArea(
        position, queen, us, enemy, kingSquare, attackMask, gradient
    )

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
    let numPossibleQueenAttack = queen.attackMask(square, position[pawn] and position[us]).countSetBits
    for phase in Phase: result[phase] += evalParameters[phase].bonusKingSafety[numPossibleQueenAttack]

    when gradient isnot Nothing:
        for phase in Phase:
            gradient[phase].bonusKingSafety.addSmooth(numPossibleQueenAttack, whiteBlackGradient())


func evaluatePiece(
    position: Position,
    piece: Piece,
    square: Square,
    us, enemy: Color,
    kingSquare: array[white..black, Square],
    kingSquareMirrored: array[white..black, Square],
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
        
    for phase in Phase: result[phase] = evalParameters[phase].pieceValues[piece]
    when gradient isnot Nothing:
        for phase in Phase:
            gradient[phase].pieceValues[piece] += whiteBlackGradient()

    result += evaluationFunctions[piece](position, square, us, enemy, kingSquare, evalParameters, gradient)
    result += evalParameters.getPstValue(
        square, piece, us,
        [ourKing: kingSquareMirrored[us], enemyKing: kingSquareMirrored[enemy]],
        gradient
    )
    
func evaluatePieceType(
    position: Position,
    piece: Piece,
    kingSquare: array[white..black, Square],
    kingSquareMirrored: array[white..black, Square],
    evalParameters: EvalParameters,
    gradient: var GradientOrNothing
): array[Phase, Value]  =
    result = [opening: 0.Value, endgame: 0.Value]
    let
        us = position.us
        enemy = position.enemy

    for square in position[piece]:
        let currentUs = if (square.toBitboard and position[us]) != 0: us else: enemy
        let currentEnemy = currentUs.opposite

        var currentResult: array[Phase, Value] = position.evaluatePiece(
            piece, square,
            currentUs, currentEnemy,
            kingSquare, kingSquareMirrored,
            evalParameters, gradient
        )
        
        if currentUs == enemy:
            for phase in Phase: currentResult[phase] = -currentResult[phase]
        result += currentResult

func evaluate*(position: Position, evalParameters: EvalParameters, gradient: var GradientOrNothing): Value =
    if position.halfmoveClock >= 100:
        return 0.Value

    var value = [opening: 0.Value, endgame: 0.Value]

    let kingSquare = [
        white: position.kingSquare(white),
        black: position.kingSquare(black)
    ]    
    let kingSquareMirrored = [
        white: kingSquare[white].mirror,
        black: kingSquare[black]
    ]
    
    for piece in pawn..king:
        value += position.evaluatePieceType(piece, kingSquare, kingSquareMirrored, evalParameters, gradient)

    for square in [
        b3, c3, d3, e3, f3, g3,
        b4, c4, d4, e4, f4, g4,
        b5, c5, d5, e5, f5, g5,
        b6, c6, d6, e6, f6, g6
    ]: # TODO maybe include king relative position
        if (mask3x3[square] and position[pawn]).countSetBits >= 2:
            value += evalParameters.pawnMaskBonus(
                position,
                square,
                position.us, position.enemy,
                gradient
            )

    let gamePhase = position.gamePhase

    result = gamePhase.interpolate(forOpening = value[opening], forEndgame = value[endgame])
    doAssert valueCheckmate > result.abs

    when gradient isnot Nothing:
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

func value*(piece: Piece): Value =
    const table = [
        pawn: 157.Value,
        knight: 600.Value,
        bishop: 601.Value,
        rook: 814.Value,
        queen: 1667.Value,
        king: 1000000.Value,
        noPiece: 0.Value
    ]
    table[piece]

func cp*(cp: int): Value =
    (pawn.value * cp.Value) div 100.Value

func toCp*(value: Value): int =
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
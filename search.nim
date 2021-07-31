import
    types,
    position,
    positionUtils,
    move,
    searchUtils,
    moveIterator,
    hashTable,
    evaluation,
    see,
    atomics,
    bitops

static: doAssert values[pawn] == 100

func futilityReduction(value: Value): Ply =
    if value < 150: return 0.Ply
    if value < 200: return 1.Ply
    if value < 300: return 2.Ply
    if value < 500: return 3.Ply
    if value < 750: return 4.Ply
    if value < 1050: return 5.Ply
    if value < 1400: return 6.Ply
    7.Ply

func hashResultFutilityMargin(depthDifference: Ply): Value =
    if depthDifference >= 5.Ply: return values[king]
    depthDifference.Value * 200.Value

func lmrDepth(depth: Ply, lmrMoveCounter: int): Ply =
    const halfLife = 35
    ((depth.int * halfLife) div (halfLife + lmrMoveCounter)).Ply

const
    deltaMargin = 150
    failHighDeltaMargin = 50

type SearchState = object
    stop: ptr Atomic[bool]
    hashTable: ptr HashTable
    killerTable: KillerTable
    historyTable: HistoryTable
    gameHistory: GameHistory
    countedNodes: uint64
    numMovesAtRoot: int
    evaluation: proc(position: Position): Value {.noSideEffect.}

func update(state: var SearchState, position: Position, bestMove: Move, depth, height: Ply, nodeType: NodeType, value: Value) =
    if not state.stop[].load:
        state.hashTable[].add(position.zobristKey, nodeType, value, depth, bestMove)
        if bestMove != noMove:
            if nodeType != allNode:
                state.historyTable.update(bestMove, position.us, depth)
            if nodeType == cutNode:
                state.killerTable.update(height, bestMove)                

func quiesce(
    position: Position,
    state: var SearchState,
    alpha, beta: Value, 
    height: Ply,
    doPruning: static bool = true
): Value =
    assert alpha < beta

    state.countedNodes += 1

    if height == Ply.high:
        return 0.Value

    if position.insufficientMaterial and height > 0:
        return 0.Value

    let standPat = state.evaluation(position)

    var
        alpha = alpha
        moveCounter = 0
        bestValue = standPat

    if standPat >= beta:
        return standPat
    if standPat > alpha:
        alpha = standPat

    for move in position.moveIterator(doQuiets = false):
        var newPosition = position
        newPosition.doMove(move)

        if newPosition.inCheck(position.us, position.enemy):
            continue
        moveCounter += 1
        
        let seeEval = standPat + position.see(move)
        
        # delta pruning
        if seeEval + deltaMargin < alpha and doPruning:
            continue
        
        # fail-high delta pruning
        if seeEval - failHighDeltaMargin >= beta and doPruning:
            return seeEval - failHighDeltaMargin

        let value = -newPosition.quiesce(state, alpha = -beta, beta = -alpha, height + 1.Ply, doPruning = doPruning)

        if value > bestValue:
            bestValue = value
        if value >= beta:
            return bestValue
        if value > alpha:
            alpha = value

    if moveCounter == 0 and position.inCheck(position.us, position.enemy):
        bestValue = -values[king]
    bestValue

func materialQuiesce*(position: Position): Value =
    var state = SearchState(
        stop: nil,
        hashTable: nil,
        gameHistory: newGameHistory(@[]),
        evaluation: material
    )
    position.quiesce(state = state, alpha = -valueInfinity, beta = valueInfinity, height = 0.Ply, doPruning = false)

func search(
    position: Position,
    state: var SearchState,
    alpha, beta: Value,
    depth: Ply, height = 0.Ply
): Value =
    assert alpha < beta

    state.countedNodes += 1

    if height == Ply.high:
        return 0.Value

    if position.insufficientMaterial and height > 0:
        return 0.Value

    if position.halfmoveClock >= 100:
        return 0.Value

    if state.gameHistory.checkForRepetition(position, height) and height > 0:
        return 0.Value
    state.gameHistory.update(position, height)

    let
        inCheck = position.inCheck(position.us, position.enemy)
        depth = if inCheck: depth + 1.Ply else: depth
        hashResult = state.hashTable[].get(position.zobristKey)

    var
        alpha = alpha
        beta = beta
        nodeType = allNode
        bestMove = noMove
        bestValue = -valueInfinity
        moveCounter = 0
        lmrMoveCounter = 0

    # update alpha, beta or value based on hash table result
    if (not hashResult.isEmpty) and height > 0 and (alpha > -valueInfinity or beta < valueInfinity):
        if hashResult.depth >= depth:
            case hashResult.nodeType:
            of exact:
                return hashResult.value
            of lowerBound:
                alpha = max(alpha, hashResult.value)
            of upperBound:
                beta = min(beta, hashResult.value)
            else:
                assert false
            if alpha >= beta:
                return alpha
        else:
            # hash result futility pruning
            let margin = hashResultFutilityMargin(depth - hashResult.depth)
            var
                noisyAlpha = alpha
                noisyBeta = beta
            if hashResult.nodeType != upperBound:
                noisyAlpha = max(noisyAlpha, hashResult.value - margin)
            if hashResult.nodeType == upperBound:
                noisyBeta = min(noisyBeta, hashResult.value + margin)
            if noisyAlpha >= noisyBeta:
                return noisyAlpha    

    if depth <= 0:
        return position.quiesce(state, alpha = alpha, beta = beta, height)

    # null move reduction
    if height > 0 and (not inCheck) and alpha > -valueInfinity and beta < valueInfinity and
    ((position[knight] or position[bishop] or position[rook] or position[queen]) and position[position.us]).countSetBits >= 1:
        var newPosition = position
        newPosition.doNullMove
        let value = -newPosition.search(
            state,
            alpha = -beta, beta = -beta + 1.Value,
            depth = depth - 2.Ply - depth div 3.Ply, height = height + 3.Ply
            # height + 3 is not a bug, it somehow improves the performance by ~20 Elo
        )
        if value >= beta:
            return value

    # determine amount of futility reduction
    let doFutilityReduction = alpha > -valueInfinity and beta - alpha <= 10.Value and not inCheck
    let futilityMargin = alpha - state.evaluation(position)

    for move in position.moveIterator(hashResult.bestMove, state.historyTable, state.killerTable.get(height)):

        var newPosition = position
        newPosition.doMove(move)
        if newPosition.inCheck(position.us, position.enemy):
            continue
        moveCounter += 1

        let givingCheck = newPosition.inCheck(newPosition.us, newPosition.enemy)

        var
            newDepth = depth
            newBeta = beta

        # futility reduction
        if doFutilityReduction and (not givingCheck) and bestValue > -valueInfinity:
            newDepth -= futilityReduction(futilityMargin - position.see(move))
            if newDepth <= 0:
                continue

        # first explore with null window
        if alpha > -valueInfinity:
            newBeta = alpha + 1.Value

        # late move reduction
        if newDepth > 1.Ply and moveCounter > 3 and
        (not (move.isTactical or inCheck or givingCheck)) and
        (not (move.moved == pawn and newPosition.isPassedPawn(position.us, position.enemy, move.target))):
            newDepth = lmrDepth(newDepth, lmrMoveCounter)
            lmrMoveCounter += 1

        if state.stop[].load:
            return 0.Value
        
        var value = -newPosition.search(
            state,
            alpha = -newBeta, beta = -alpha,
            depth = newDepth - 1.Ply, height = height + 1.Ply
        )

        # first re-search with full window and reduced depth
        if value > alpha and newBeta < beta:
            value = -newPosition.search(
                state,
                alpha = -beta, beta = -alpha,
                depth = newDepth - 1.Ply, height = height + 1.Ply
            )

        # re-search with full window and full depth
        if value > alpha and newDepth < depth:
            newDepth = depth
            value = -newPosition.search(
                state,
                alpha = -beta, beta = -alpha,
                depth = depth - 1.Ply, height = height + 1.Ply
            )

        if value > bestValue:
            bestValue = value
            bestMove = move

        if value >= beta:
            state.update(position, bestMove, depth = depth, height = height, cutNode, value)
            return bestValue

        if value > alpha:
            nodeType = pvNode
            alpha = value
        else:
            state.historyTable.update(move, position.us, newDepth, weakMove = true)

    if moveCounter == 0:
        # checkmate
        if inCheck:
            bestValue = -(height.checkmateValue)
        # stalemate
        else:
            bestValue = 0.Value
    if height == 0:
        state.numMovesAtRoot = moveCounter
    
    state.update(position, bestMove, depth = depth, height = height, nodeType, bestValue)
    bestValue

iterator iterativeDeepeningSearch*(
    position: Position,
    hashTable: var HashTable,
    positionHistory: seq[Position],
    targetDepth: Ply,
    stop: ptr Atomic[bool],
    evaluation: proc(position: Position): Value {.noSideEffect.} = evaluate
): (Value, seq[Move], uint64) {.noSideEffect.} =

    var state = SearchState(
        stop: stop,
        hashTable: addr hashTable,
        gameHistory: newGameHistory(positionHistory),
        evaluation: evaluation
    )

    hashTable.age()

    for depth in 1.Ply..targetDepth:
        state.countedNodes = 0
        let value = position.search(
            state,
            alpha = -valueInfinity, beta = valueInfinity,
            depth = depth, height = 0
        )

        if stop[].load:
            break

        let hashResult = hashTable.get(position.zobristKey)

        doAssert not hashResult.isEmpty
        let pv = if state.numMovesAtRoot >= 1: hashTable.getPv(position) else: @[noMove]
        doAssert pv.len >= 1

        yield (value, pv, state.countedNodes)

        if state.numMovesAtRoot == 1:
            break

        if abs(value) >= valueCheckmate:
            break

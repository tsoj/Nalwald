import
    types,
    bitboard,
    position,
    positionUtils,
    move,
    searchUtils,
    moveIterator,
    hashTable,
    evaluation,
    see,
    utils,
    searchParameters

import std/[
    atomics,
    bitops
]


func futilityReduction(gamePhase: GamePhase, value: Value): Ply =
    if value < defaultSearchParams.futilityMargins[0.Ply].get(gamePhase): return 0.Ply
    if value < defaultSearchParams.futilityMargins[1.Ply].get(gamePhase): return 1.Ply
    if value < defaultSearchParams.futilityMargins[2.Ply].get(gamePhase): return 2.Ply
    if value < defaultSearchParams.futilityMargins[3.Ply].get(gamePhase): return 3.Ply
    if value < defaultSearchParams.futilityMargins[4.Ply].get(gamePhase): return 4.Ply
    if value < defaultSearchParams.futilityMargins[5.Ply].get(gamePhase): return 5.Ply
    if value < defaultSearchParams.futilityMargins[6.Ply].get(gamePhase): return 6.Ply
    Ply.high

func hashResultFutilityMargin(gamePhase: GamePhase, depthDifference: Ply): Value =
    if depthDifference >= 5.Ply: return valueInfinity
    depthDifference.Value * defaultSearchParams.hashResultFutilityMargin.get(gamePhase)

func nullMoveDepth(gamePhase: GamePhase, depth: Ply): Ply =
    depth - defaultSearchParams.nullMoveSubtractor.get(gamePhase) - depth div defaultSearchParams.nullMoveDivider.get(gamePhase)

func lmrDepth(gamePhase: GamePhase, depth: Ply, lmrMoveCounter: int): Ply =
    let halfLife = defaultSearchParams.lmrHalfLife.get(gamePhase)
    ((depth.int * halfLife) div (halfLife + lmrMoveCounter)).Ply

func increaseBeta(newBeta: var Value, alpha, beta: Value) =
    newBeta = min(beta, newBeta + 10.cp + (newBeta - alpha)*2)

func deltaMargin(gamePhase: GamePhase): Value =
    defaultSearchParams.deltaMargin.get(gamePhase)

func failHighDeltaMargin(gamePhase: GamePhase): Value =
    defaultSearchParams.failHighDeltaMargin.get(gamePhase)

type SearchState* = object
    stop*: ptr Atomic[bool]
    threadStop*: ptr Atomic[bool]
    hashTable*: ptr HashTable
    killerTable*: KillerTable
    historyTable*: ptr HistoryTable
    gameHistory*: GameHistory
    countedNodes*: uint64
    maxNodes*: uint64
    evaluation*: proc(position: Position): Value {.noSideEffect.}

func update(
    state: var SearchState,
    position: Position,
    bestMove, previous: Move,
    depth, height: Ply,
    nodeType: NodeType,
    value: Value
) =
    if bestMove != noMove and not (state.stop[].load or state.threadStop[].load):
        state.hashTable[].add(position.zobristKey, nodeType, value, depth, bestMove)
        if nodeType != allNode:
            state.historyTable[].update(bestMove, previous, position.us, depth)
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

    if height == Ply.high or
    position.insufficientMaterial:
        return 0.Value

    let standPat = state.evaluation(position)

    var
        alpha = alpha
        bestValue = standPat

    if standPat >= beta:
        return standPat
    if standPat > alpha:
        alpha = standPat

    let gamePhase = position.gamePhase

    for move in position.moveIterator(doQuiets = false):
        let newPosition = position.doMove(move)
        
        let seeEval = standPat + position.see(move)
        
        # delta pruning
        if seeEval + gamePhase.deltaMargin < alpha and doPruning:
            # return instead of just continue, as later captures must have lower SEE value
            return bestValue

        if newPosition.inCheck(position.us, position.enemy):
            continue
        
        # fail-high delta pruning
        if seeEval - gamePhase.failHighDeltaMargin >= beta and doPruning:
            return seeEval - gamePhase.failHighDeltaMargin

        let value = -newPosition.quiesce(state, alpha = -beta, beta = -alpha, height + 1.Ply, doPruning = doPruning)

        if value > bestValue:
            bestValue = value
        if value >= beta:
            return bestValue
        if value > alpha:
            alpha = value
            
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
    depth, height: Ply,
    previous: Move
): Value =
    assert alpha < beta

    state.countedNodes += 1

    if height > 0 and (
        height == Ply.high or
        position.insufficientMaterial or
        position.halfmoveClock >= 100 or
        state.gameHistory.checkForRepetition(position, height)
    ):
        return 0.Value
    
    state.gameHistory.update(position, height)

    let
        inCheck = position.inCheck(position.us, position.enemy)
        depth = if inCheck or previous.isPawnMoveToSecondRank: depth + 1.Ply else: depth
        hashResult = state.hashTable[].get(position.zobristKey)
        originalAlpha = alpha
        gamePhase = position.gamePhase

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
            if alpha >= beta:
                return alpha
        else:
            # hash result futility pruning
            let margin = gamePhase.hashResultFutilityMargin(depth - hashResult.depth)
            if hashResult.nodeType == lowerBound and hashResult.value - margin >= beta:
                return hashResult.value - margin
            if hashResult.nodeType == upperBound and hashResult.value + margin <= alpha:
                return hashResult.value + margin

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
            depth = gamePhase.nullMoveDepth(depth), height = height + 1.Ply,
            previous = noMove
        )
        
        if value >= beta:
            return value

    var valueStaticEval = valueInfinity # will be calculated on demand
    template staticEval(): auto =
        if valueStaticEval == valueInfinity:
            valueStaticEval = state.evaluation(position)
        valueStaticEval
        
    for move in position.moveIterator(hashResult.bestMove, state.historyTable[], state.killerTable.get(height), previous):

        let newPosition = position.doMove(move)
        if newPosition.inCheck(position.us, position.enemy):
            continue
        moveCounter += 1

        let givingCheck = newPosition.inCheck(newPosition.us, newPosition.enemy)

        var
            newDepth = depth
            newBeta = beta

        if not (givingCheck or inCheck):

            # late move reduction
            if (not move.isTactical) and
            (moveCounter > 3 or (moveCounter > 2 and hashResult.isEmpty)) and
            not newPosition.isPassedPawnMove(move):
                newDepth = gamePhase.lmrDepth(newDepth, lmrMoveCounter)
                lmrMoveCounter += 1
                if lmrMoveCounter >= 5:
                    if depth <= 2.Ply:
                        continue
                    if depth <= 5.Ply:
                        newDepth -= 1.Ply

            # futility reduction
            if beta - originalAlpha <= 1 and moveCounter > 1:
                newDepth -= gamePhase.futilityReduction(originalAlpha - staticEval - position.see(move))
                if newDepth <= 0:
                    continue

        # first explore with null window
        if alpha > -valueInfinity and (hashResult.isEmpty or hashResult.bestMove != move or hashResult.nodeType == allNode):
            newBeta = alpha + 1

        if state.stop[].load or state.threadStop[].load or state.countedNodes >= state.maxNodes:
            if state.hashTable[].get(position.zobristKey).isEmpty:
                break
            else:
                return 0.Value
        
        var value = -newPosition.search(
            state,
            alpha = -newBeta, beta = -alpha,
            depth = newDepth - 1.Ply, height = height + 1.Ply,
            previous = move
        )

        # first re-search with increasing window and reduced depth
        while value >= newBeta and newBeta < beta:
            newBeta.increaseBeta(alpha, beta)
            value = -newPosition.search(
                state,
                alpha = -newBeta, beta = -alpha,
                depth = newDepth - 1.Ply, height = height + 1.Ply,
                previous = move
            )

        # re-search with full window and full depth
        if value > alpha and newDepth < depth:
            newDepth = depth
            value = -newPosition.search(
                state,
                alpha = -beta, beta = -alpha,
                depth = depth - 1.Ply, height = height + 1.Ply,
                previous = move
            )

        if value > bestValue:
            bestValue = value
            bestMove = move

        if value >= beta:
            state.update(position, bestMove, previous, depth = depth, height = height, cutNode, value)
            return bestValue

        if value > alpha:
            nodeType = pvNode
            alpha = value
        else:
            state.historyTable[].update(move, previous, position.us, newDepth, weakMove = true)

    if moveCounter == 0:
        # checkmate
        if inCheck:
            bestValue = -(height.checkmateValue)
        # stalemate
        else:
            bestValue = 0.Value
    
    state.update(position, bestMove, previous, depth = depth, height = height, nodeType, bestValue)

    bestValue

func search*(
    position: Position,
    state: var SearchState,
    depth: Ply
): Value =
    position.search(
        state,
        alpha = -valueInfinity, beta = valueInfinity,
        depth = depth, height = 0,
        previous = noMove
    )

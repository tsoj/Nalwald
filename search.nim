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
    bitops,
    times,
    threadpool,
    os

static: doAssert pawn.value == 100.cp

func futilityReduction(value: Value): Ply =
    if value < 150.cp: return 0.Ply
    if value < 200.cp: return 1.Ply
    if value < 300.cp: return 2.Ply
    if value < 500.cp: return 3.Ply
    if value < 750.cp: return 4.Ply
    if value < 1050.cp: return 5.Ply
    if value < 1400.cp: return 6.Ply
    Ply.high

func hashResultFutilityMargin(depthDifference: Ply): Value =
    if depthDifference >= 5.Ply: return valueInfinity
    depthDifference.Value * 200.cp

func lmrDepth(depth: Ply, lmrMoveCounter: int): Ply =
    const halfLife = 35
    ((depth.int * halfLife) div (halfLife + lmrMoveCounter)).Ply

const
    deltaMargin = 150.cp
    failHighDeltaMargin = 50.cp

type SearchState = object
    stop: ptr Atomic[bool]
    hashTable: ptr HashTable
    killerTable: KillerTable
    historyTable: ptr HistoryTable
    gameHistory: GameHistory
    countedNodes: uint64
    numMovesAtRoot: int
    evaluation: proc(position: Position): Value {.noSideEffect.}

func update(state: var SearchState, position: Position, bestMove, previous: Move, depth, height: Ply, nodeType: NodeType, value: Value) =
    if not state.stop[].load:
        state.hashTable[].add(position.zobristKey, nodeType, value, depth, bestMove)
        if bestMove != noMove:
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

    if height == Ply.high:
        return 0.Value

    if position.insufficientMaterial and height > 0:
        return 0.Value

    let standPat = state.evaluation(position)

    var
        alpha = alpha
        bestValue = standPat

    if standPat >= beta:
        return standPat
    if standPat > alpha:
        alpha = standPat

    for move in position.moveIterator(doQuiets = false):
        var newPosition = position
        newPosition.doMove(move)
        
        let seeEval = standPat + position.see(move)
        
        # delta pruning
        if seeEval + deltaMargin < alpha and doPruning:
            # return instead of just continue, as later captures must have lower SEE value
            return bestValue

        if newPosition.inCheck(position.us, position.enemy):
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
    depth: Ply, height = 0.Ply,
    previous: Move
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
            if hashResult.nodeType != upperBound and hashResult.value - margin >= beta:
                return hashResult.value - margin
            if hashResult.nodeType == upperBound and alpha >= hashResult.value + margin:
                return alpha   

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
            depth = depth - 2.Ply - depth div 3.Ply, height = height + 3.Ply,
            # height + 3 is not a bug, it somehow improves the performance by ~15 Elo
            previous = noMove
        )
        if value >= beta:
            return value

    let
        staticEval = state.evaluation(position)
        doFutilityReduction = alpha > -valueInfinity and beta - alpha <= 10.cp and not inCheck
        futilityMargin = alpha - staticEval

    for move in position.moveIterator(hashResult.bestMove, state.historyTable[], state.killerTable.get(height), previous):

        var newPosition = position
        newPosition.doMove(move)
        if newPosition.inCheck(position.us, position.enemy):
            continue
        moveCounter += 1

        let givingCheck = newPosition.inCheck(newPosition.us, newPosition.enemy)

        var
            newDepth = depth
            newBeta = beta

        # late move reduction
        if newDepth > 1.Ply and
        (moveCounter > 3 or (moveCounter > 2 and hashResult.isEmpty)) and
        (not (move.isTactical or inCheck or givingCheck)) and
        (not (move.moved == pawn and newPosition.isPassedPawn(position.us, position.enemy, move.target))):
            newDepth = lmrDepth(newDepth, lmrMoveCounter)
            lmrMoveCounter += 1

        # futility reduction
        if doFutilityReduction and (not givingCheck) and bestValue > -valueInfinity:
            newDepth -= futilityReduction(futilityMargin - position.see(move))
            if newDepth <= 0:
                continue

        # first explore with null window
        if alpha > -valueInfinity and (hashResult.isEmpty or hashResult.nodeType == allNode or move != hashResult.bestMove):
            newBeta = alpha + 1.Value

        if state.stop[].load:
            return 0.Value
        
        var value = -newPosition.search(
            state,
            alpha = -newBeta, beta = -alpha,
            depth = newDepth - 1.Ply, height = height + 1.Ply,
            previous = move
        )

        # first re-search with full window and reduced depth
        if value > alpha and newBeta < beta:
            value = -newPosition.search(
                state,
                alpha = -beta, beta = -alpha,
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
    if height == 0:
        state.numMovesAtRoot = moveCounter
    
    state.update(position, bestMove, previous, depth = depth, height = height, nodeType, bestValue)
    bestValue

type SearchThreadResult = object
    value: Value
    depth: Ply
    nodes: uint64
    numMovesAtRoot: int

func launchSearchThread(
    position: Position,
    hashTable: ptr HashTable,
    stop: ptr Atomic[bool],
    historyTable: ptr HistoryTable,
    gameHistory: GameHistory,
    depth: Ply,
    evaluation: proc(position: Position): Value {.noSideEffect.}
): SearchThreadResult =
    var state = SearchState(
        stop: stop,
        hashTable: hashTable,
        historyTable: historyTable,
        gameHistory: gameHistory,
        evaluation: evaluation
    )
    let value = position.search(
        state,
        alpha = -valueInfinity, beta = valueInfinity,
        depth = depth, height = 0,
        previous = noMove
    )
    SearchThreadResult(value: value, depth: depth, nodes: state.countedNodes, numMovesAtRoot: state.numMovesAtRoot)

type ThreadSeq = object
    flowVars: seq[FlowVar[SearchThreadResult]]

proc `=destroy`(threadSeq: var ThreadSeq) =
  for flowVar in threadSeq.flowVars.mitems:
      if flowVar != nil:
        discard ^flowVar

iterator iterativeDeepeningSearch*(
    position: Position,
    hashTable: var HashTable,
    positionHistory: seq[Position],
    targetDepth: Ply,
    stop: ptr Atomic[bool],
    numThreads = 1,
    evaluation: proc(position: Position): Value {.noSideEffect.} = evaluate
): tuple[value: Value, pv: seq[Move], nodes: uint64] {.noSideEffect.} =
    {.cast(noSideEffect).}:
        let numThreads = max(1, numThreads)
        let gameHistory = newGameHistory(positionHistory)
        var historyTable: seq[HistoryTable]
        for _ in 0..<numThreads:
            historyTable.add newHistoryTable()

        hashTable.age()        

        var threadSeq = ThreadSeq(flowVars: newSeq[FlowVar[SearchThreadResult]](numThreads))    
        
        let start = now()
        for depth in 1.Ply..targetDepth:
            var
                nodes = 0'u64
                value: Value
                numMovesAtRoot: int

            # don't use multithreading too early
            let noMultithreading = (now() - start).inMilliseconds < 100

            for i, flowVar in threadSeq.flowVars.mpairs:
                if i > 0:
                    if noMultithreading: break
                    sleep(1)
                flowVar = spawn launchSearchThread(
                    position,
                    addr hashTable,
                    stop,
                    addr historyTable[i],
                    gameHistory,
                    depth,
                    evaluation
                )    

            for i, flowVar in threadSeq.flowVars.mpairs:
                if i > 0 and noMultithreading: break
                let r = ^flowVar
                nodes += r.nodes
                value = r.value
                numMovesAtRoot = r.numMovesAtRoot

            if stop[].load:
                break

            let hashResult = hashTable.get(position.zobristKey)

            doAssert not hashResult.isEmpty
            let pv = if numMovesAtRoot >= 1: hashTable.getPv(position) else: @[noMove]

            yield (value: value, pv: pv, nodes: nodes)

            if numMovesAtRoot == 1:
                break

            if abs(value) >= valueCheckmate:
                break

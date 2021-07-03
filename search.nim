import searchUtils
import position
import move
import moveIterator
import atomics
import hashTable
import types
import evaluation
import see
import bitops
import times
import threadpool
import utils

static: doAssert values[pawn] == 100

const nullMoveDepthReduction = 4.Ply
func futilityReduction(value: Value): Ply =
    if value < 150: return 0.Ply
    if value < 300: return 1.Ply
    if value < 500: return 2.Ply
    if value < 750: return 3.Ply
    if value < 1050: return 4.Ply
    if value < 1400: return 5.Ply
    6.Ply
const deltaMargin = 150
const failHighDeltaMargin = 100

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

    template isInNullWindow(): bool = beta == alpha + 1

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
    if (not hashResult.isEmpty) and hashResult.depth >= depth and height > 0 and alpha > -valueInfinity:
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
            depth = depth - nullMoveDepthReduction, height = height + 3.Ply
            # height + 3 is not a bug, it somehow improves the performance by ~20 Elo
        )
        if value >= beta:
            return value

    # determine amount of futility reduction
    let futilityReduction = if alpha == -valueInfinity or (not isInNullWindow) or inCheck:
        0.Ply
    else:
        futilityReduction(alpha - state.evaluation(position))

    for move in position.moveIterator(
        tryFirstMove = hashResult.bestMove,
        state.historyTable,
        killers = state.killerTable.get(height)
    ):
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
        if (not move.isTactical) and (not givingCheck) and bestValue > -valueInfinity:
            newDepth -= futilityReduction
            if newDepth <= 1:
                continue

        # first explore with null window
        if alpha > -valueInfinity:
            newBeta = alpha + 1.Value

        # late move reduction
        if newDepth >= 2.Ply and moveCounter >= 4 and alpha > -valueInfinity and
        (not (move.isTactical or inCheck or givingCheck)) and
        (not (move.moved == pawn and newPosition.isPassedPawn(position.us, position.enemy, move.target))):
            const depthDivider =
                [60, 30, 25, 20, 15, 10, 9, 8, 7, 6, 6, 5, 5, 5, 4]
            newDepth -= 1.Ply + newDepth div depthDivider[min(lmrMoveCounter, depthDivider.len - 1)].Ply
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

type MoveTime = object
    maxTime, approxTime: Duration
func calculateMoveTime(moveTime, timeLeft, incPerMove: Duration, movesToGo, halfmovesPlayed: int16): MoveTime = 

    doAssert movesToGo >= 0
    let estimatedGameLength = 70
    let estimatedMovesToGo = max(10, estimatedGameLength - halfmovesPlayed div 2)
    var newMovesToGo = max(2, min(movesToGo, estimatedMovesToGo))

    result.maxTime = min(initDuration(milliseconds = timeLeft.inMilliseconds div 2), moveTime)
    result.approxTime = initDuration(milliseconds = clamp(
        timeLeft.inMilliseconds div newMovesToGo, 0, int.high div 2) +
        clamp(incPerMove.inMilliseconds, 0, int.high div 2))

    if incPerMove.inSeconds >= 2 or timeLeft > initDuration(minutes = 2):
        result.approxTime = (12 * result.approxTime) div 10
    elif incPerMove.inMilliseconds < 200 and timeLeft < initDuration(seconds = 30):
        result.approxTime = (8 * result.approxTime) div 10
        if movesToGo > 2:
            result.maxTime = min(initDuration(milliseconds = timeLeft.inMilliseconds div 4), moveTime)

iterator iterativeTimeManagedSearch*(
    position: Position,
    hashTable: var HashTable,
    positionHistory: seq[Position] = newSeq[Position](0),
    targetDepth: Ply = Ply.high,
    stop: ptr Atomic[bool] = nil,
    movesToGo: int16 = int16.high,
    increment = [white: DurationZero, black: DurationZero],
    timeLeft = [white: initDuration(milliseconds = int64.high), black: initDuration(milliseconds = int64.high)],
    moveTime = initDuration(milliseconds = int64.high),
    evaluation: proc(position: Position): Value {.noSideEffect.} = evaluate
): (Value, seq[Move], uint64, Duration) =

    var stopFlag: Atomic[bool]
    var stop = if stop == nil: addr stopFlag else: stop

    stop[].store(false)

    let calculatedMoveTime = calculateMoveTime(
        moveTime, timeLeft[position.us], increment[position.us], movesToGo, position.halfmovesPlayed)
    var stopwatchResult = spawn stopwatch(stop, calculatedMoveTime.maxTime)

    let start = now()
    var
        startLastIteration = now()
        branchingFactors = newSeq[float](targetDepth.int)
        lastNumNodes = uint64.high

    var iteration = -1
    for (value, pv, nodes) in iterativeDeepeningSearch(
        position, hashtable, positionHistory, targetDepth, stop, evaluation
    ):
        iteration += 1
        let totalPassedTime = now() - start
        let iterationPassedTime = (now() - startLastIteration)
        startLastIteration = now()

        yield (value, pv, nodes, iterationPassedTime)

        assert calculatedMoveTime.approxTime >= DurationZero
        branchingFactors[iteration] = nodes.float / lastNumNodes.float;
        lastNumNodes = if nodes <= 100_000: uint64.high else: nodes
        var averageBranchingFactor = branchingFactors[iteration]
        if iteration >= 4:
            averageBranchingFactor =
                (branchingFactors[iteration] +
                branchingFactors[iteration - 1] +
                branchingFactors[iteration - 2] +
                branchingFactors[iteration - 3])/4.0

        let estimatedTimeNextIteration =
            initDuration(milliseconds = (iterationPassedTime.inMilliseconds.float * averageBranchingFactor).int64)
        if estimatedTimeNextIteration + totalPassedTime > calculatedMoveTime.approxTime and iteration >= 4:
            break;

    stop[].store(true)
    discard ^stopwatchResult

proc timeManagedSearch*(
    position: Position,
    hashTable: var HashTable,
    positionHistory: seq[Position] = newSeq[Position](0),
    targetDepth: Ply = Ply.high,
    stop: ptr Atomic[bool] = nil,
    movesToGo: int16 = int16.high,
    increment = [white: DurationZero, black: DurationZero],
    timeLeft = [white: initDuration(milliseconds = int64.high), black: initDuration(milliseconds = int64.high)],
    moveTime = initDuration(milliseconds = int64.high),
    evaluation: proc(position: Position): Value {.noSideEffect.} = evaluate
): (Value, seq[Move]) =
    for (value, pv, nodes, passedTime) in iterativeTimeManagedSearch(
        position,
        hashTable,
        positionHistory,
        targetDepth,
        stop,
        movesToGo,
        increment, timeLeft,
        moveTime,
        evaluation
    ):
        result = (value, pv)

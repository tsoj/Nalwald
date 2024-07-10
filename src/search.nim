import
  types, bitboard, position, positionUtils, move, searchUtils, moveIterator, hashTable,
  evaluation, utils, see, searchParams

import std/[atomics, options]

static:
  doAssert pawn.value == 100.cp

func futilityReduction(value: Value): Ply =
  clampToType(value.toCp div futilityReductionDiv(), Ply)

func hashResultFutilityMargin(depthDifference: Ply): Value =
  depthDifference.Value * hashResultFutilityMarginMul().cp

func nullMoveDepth(depth: Ply): Ply =
  depth - nullMoveDepthSub() - depth div nullMoveDepthDiv().Ply

func lmrDepth(depth: Ply, lmrMoveCounter: int): Ply =
  let halfLife = lmrDepthHalfLife()
  result = ((depth.int * halfLife) div (halfLife + lmrMoveCounter)).Ply - lmrDepthSub()

type SearchState* = object
  externalStopFlag*: ptr Atomic[bool]
  threadStop*: ptr Atomic[bool]
  hashTable*: ptr HashTable
  killerTable*: KillerTable
  historyTable*: HistoryTable
  gameHistory*: GameHistory
  countedNodes*: int
  maxNodes*: int
  stopTime*: Seconds
  skipMovesAtRoot*: seq[Move]
  evaluation*: proc(position: Position): Value {.noSideEffect.}

func shouldStop(state: SearchState): bool =
  if state.countedNodes >= state.maxNodes or
      ((state.countedNodes mod 2048) == 1107 and secondsSince1970() >= state.stopTime):
    state.externalStopFlag[].store(true)
  state.externalStopFlag[].load or state.threadStop[].load

func update(
    state: var SearchState,
    position: Position,
    bestMove, previous: Move,
    depth, height: Ply,
    nodeType: NodeType,
    bestValue: Value,
) =
  if bestMove != noMove and bestValue.abs < valueInfinity and not state.threadStop[].load:
    state.hashTable[].add(position.zobristKey, nodeType, bestValue, depth, bestMove)
    if nodeType != allNode:
      state.historyTable.update(
        bestMove, previous, position.us, depth, raisedAlpha = true
      )
    if nodeType == cutNode:
      state.killerTable.update(height, bestMove)

func quiesce(
    position: Position,
    state: var SearchState,
    alpha, beta: Value,
    height: Ply,
    doPruning: static bool = true,
): Value =
  assert alpha < beta

  state.countedNodes += 1

  if height == Ply.high or position.insufficientMaterial:
    return 0.Value

  let standPat = state.evaluation(position)

  var
    alpha = alpha
    bestValue = standPat

  if standPat >= beta:
    return standPat
  if standPat > alpha:
    alpha = standPat

  for move in position.treeSearchMoveIterator(doQuiets = false):
    let newPosition = position.doMove(move)

    let seeEval = standPat + position.see(move)

    # delta pruning
    if seeEval + deltaMargin().cp < alpha and doPruning:
      # return instead of just continue, as later captures must have lower SEE value
      return bestValue

    if newPosition.inCheck(position.us):
      continue

    # fail-high delta pruning
    if seeEval - failHighDeltaMargin().cp >= beta and doPruning:
      return seeEval - failHighDeltaMargin().cp

    let value =
      -newPosition.quiesce(
        state, alpha = -beta, beta = -alpha, height + 1.Ply, doPruning = doPruning
      )

    if value > bestValue:
      bestValue = value
    if value >= beta:
      return bestValue
    if value > alpha:
      alpha = value

  bestValue

func materialQuiesce*(position: Position): Value =
  var state = SearchState(
    externalStopFlag: nil,
    hashTable: nil,
    gameHistory: newGameHistory(@[]),
    evaluation: material,
  )
  position.quiesce(
    state = state,
    alpha = -valueInfinity,
    beta = valueInfinity,
    height = 0.Ply,
    doPruning = false,
  )

func search(
    position: Position,
    state: var SearchState,
    alpha, beta: Value,
    depth, height: Ply,
    previous: Move,
): Value =
  assert alpha < beta

  state.countedNodes += 1

  if height > 0 and (
    height == Ply.high or position.insufficientMaterial or position.halfmoveClock >= 100 or
    state.gameHistory.checkForRepetitionAndAdd(position, height)
  ):
    return 0.Value

  let
    us = position.us
    inCheck = position.inCheck(us)
    hashResult = state.hashTable[].get(position.zobristKey)

  var
    alpha = alpha
    nodeType = allNode
    bestMove = noMove
    bestValue = -valueInfinity
    moveCounter = 0
    lmrMoveCounter = 0

  let depth = block:
    var depth = depth

    # check and passed pawn extension
    if (inCheck and depth <= 0) or previous.isPawnMoveToSecondRank:
      depth += 1.Ply

    # internal iterative reduction
    if hashResult.isEmpty and depth >= iirMinDepth():
      depth -= 1.Ply

    depth

  let beta = block:
    # update alpha, beta or return immediatly based on hash table result
    var beta = beta
    if height > 0 and not hashResult.isEmpty:
      if hashResult.nodeType == exact and hashResult.depth >= depth:
        return hashResult.value

      let margin = hashResultFutilityMargin(depth - hashResult.depth)
      if hashResult.nodeType != upperBound:
        alpha = max(alpha, hashResult.value - margin)
      if hashResult.nodeType != lowerBound:
        beta = min(beta, hashResult.value + margin)

      if alpha >= beta:
        return alpha
    beta

  if depth <= 0:
    return position.quiesce(state, alpha = alpha, beta = beta, height)

  # null move reduction
  if height > 0 and (hashResult.isEmpty or hashResult.nodeType == cutNode) and
      not inCheck and
      ((position[king] or position[pawn]) and position[us]) != position[us]:
    let newPosition = position.doNullMove
    let value =
      -newPosition.search(
        state,
        alpha = -beta,
        beta = -beta + 1.Value,
        depth = nullMoveDepth(depth),
        height = height + 1.Ply,
        previous = noMove,
      )

    if value >= beta:
      return value

  # get static eval of current position, but only when necessary
  var detailStaticEval = none Value
  template staticEval(): auto =
    if detailStaticEval.isNone:
      detailStaticEval = some state.evaluation(position)
    detailStaticEval.get

  # iterate over all moves and recursively search the new positions
  for move in position.treeSearchMoveIterator(
    hashResult.bestMove, state.historyTable, state.killerTable.get(height), previous
  ):
    if height == 0.Ply and move in state.skipMovesAtRoot:
      continue

    let newPosition = position.doMove(move)

    if newPosition.inCheck(us):
      continue
    moveCounter += 1

    let givingCheck = newPosition.inCheck(newPosition.us)

    var
      newDepth = depth
      newBeta = beta

    if not givingCheck:
      # late move reduction
      if moveCounter >= minMoveCounterLmr() and not move.isTactical:
        newDepth = lmrDepth(newDepth, lmrMoveCounter)
        lmrMoveCounter += 1

        if newDepth <= 0:
          break

      # futility reduction
      if moveCounter >= minMoveCounterFutility() and newDepth > 0:
        newDepth -= futilityReduction(alpha - staticEval - position.see(move))

        if newDepth <= 0:
          continue

    # first explore with null window
    if hashResult.isEmpty or hashResult.bestMove != move or
        hashResult.nodeType == allNode:
      newBeta = alpha + 1

    # stop search if we exceeded maximum nodes or we got a stop signal from outside
    if state.shouldStop:
      break

    # search new position
    var value =
      -newPosition.search(
        state,
        alpha = -newBeta,
        beta = -alpha,
        depth = newDepth - 1.Ply,
        height = height + 1.Ply,
        previous = move,
      )

    # re-search with full window and full depth
    if value > alpha and (newDepth < depth or newBeta < beta):
      newDepth = depth
      value =
        -newPosition.search(
          state,
          alpha = -beta,
          beta = -alpha,
          depth = depth - 1.Ply,
          height = height + 1.Ply,
          previous = move,
        )

    if value > bestValue:
      bestValue = value
      bestMove = move

    if value >= beta:
      nodeType = cutNode
      break

    if value > alpha:
      nodeType = pvNode
      alpha = value
    else:
      state.historyTable.update(
        move, previous = previous, us, newDepth, raisedAlpha = false
      )

  if moveCounter == 0:
    # checkmate
    if inCheck:
      bestValue = -(height.checkmateValue)
    # stalemate
    else:
      bestValue = 0.Value

  state.update(
    position,
    bestMove,
    previous = previous,
    depth = depth,
    height = height,
    nodeType,
    bestValue,
  )

  bestValue

func search*(position: Position, state: var SearchState, depth: Ply): Value =
  let hashResult = state.hashTable[].get(position.zobristKey)

  var
    estimatedValue = (if hashResult.isEmpty: 0.Value else: hashResult.value).float
    alphaOffset = aspirationWindowStartingOffset().cp.float
    betaOffset = aspirationWindowStartingOffset().cp.float

  # growing alpha beta window
  while not state.shouldStop:
    let
      alpha = max(estimatedValue - alphaOffset, -valueInfinity.float).Value
      beta = min(estimatedValue + betaOffset, valueInfinity.float).Value

    result = position.search(
      state, alpha = alpha, beta = beta, depth = depth, height = 0, previous = noMove
    )
    doAssert result.abs <= valueInfinity

    estimatedValue = result.float
    if result <= alpha:
      alphaOffset *= aspirationWindowMultiplier()
    elif result >= beta:
      betaOffset *= aspirationWindowMultiplier()
    else:
      break

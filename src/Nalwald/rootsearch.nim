import std/[atomics, options, sequtils]
import nimchess

import eval, utils, moveiterator, searchpos, types, hashtable, searchutils

export searchpos

type SearchState = object
  externalStopFlag: ptr Atomic[bool]
  hashTable: ptr HashTable
  gameHistory: GameHistory
  stopTime: Seconds
  countedNodes: int
  maxNodes: int
  bestRootMove: Move = noMove

func shouldStop(state: SearchState): bool =
  if state.countedNodes >= state.maxNodes or
      ((state.countedNodes mod 2048) == 1107 and secondsSince1970() >= state.stopTime):
    state.externalStopFlag[].store(true)
  state.externalStopFlag[].load

func allocatedTime(params: GoParams): tuple[softLimit: Seconds, hardLimit: Seconds] =
  if params.limit.movetimeSeconds.isSome:
    return (Seconds.high, params.limit.movetimeSeconds.get.Seconds)

  let
    us = params.game.currentPosition.us
    estimatedMovesToGo = max(2, min(params.limit.movesToGo, 20))
    remainingTime =
      params.limit.timeSeconds[us].Seconds +
      params.limit.incSeconds[us].Seconds * estimatedMovesToGo
  result.softLimit = remainingTime / estimatedMovesToGo
  result.hardLimit = remainingTime / 4

func quiesce(
    position: SearchPos, state: var SearchState, alpha, beta: Value, height: Ply
): Value =
  assert alpha < beta

  state.countedNodes += 1

  if state.shouldStop:
    return -Inf

  if height >= maxPly:
    return 0.Value

  let standPat = position.eval

  var
    alpha = alpha
    bestValue = standPat

  if standPat >= beta:
    return standPat
  if standPat > alpha:
    alpha = standPat

  for newPosition, move in position.treeSearchMoveIterator(doQuiets = false):
    let value = -newPosition.quiesce(state, alpha = -beta, beta = -alpha, height + 1)

    if value > bestValue:
      bestValue = value
    if value >= beta:
      return bestValue
    if value > alpha:
      alpha = value

  bestValue

func alphabeta(
    position: SearchPos,
    state: var SearchState,
    alpha, beta: Value,
    depth: Effort,
    height: Ply,
): Value =
  assert alpha < beta

  state.countedNodes += 1

  if state.shouldStop:
    return -Inf

  if height > 0 and (
    height > maxPly or position.insufficientMaterial or position.halfmoveClock >= 100 or
    state.gameHistory.checkForRepetitionAndAdd(position, height)
  ):
    return 0.Value

  if depth <= 0.Effort:
    return position.quiesce(state, alpha = alpha, beta = beta, height = height)

  let
    us = position.us
    entry = state.hashTable[].get(position.zobristKey)

  var
    alpha = alpha
    bestValue = -Inf
    bestMove = noMove
    moveCounter = 0

  for newPosition, move in position.treeSearchMoveIterator(hashMove = entry.bestMove):
    moveCounter += 1

    let value = -newPosition.alphabeta(
      state, alpha = -beta, beta = -alpha, depth = depth - 1.Effort, height = height + 1
    )

    if value > bestValue:
      bestValue = value
      bestMove = move

      if height == 0 and not state.shouldStop:
        state.bestRootMove = move

    if value > alpha:
      alpha = value

    if value >= beta:
      break

  if moveCounter == 0:
    # checkmate
    if position.inCheck(us):
      bestValue = -(height.checkmateValue)
    # stalemate
    else:
      bestValue = 0.Value

  if not state.shouldStop:
    state.hashTable[].add(position.zobristKey, bestMove = bestMove)

  return bestValue

proc search*(
    params: GoParams,
    hashTable: var HashTable,
    softNodes: int = int.high,
    printUciInfo: bool = true,
): tuple[bestMove: Move, value: Value, nodes: int, depth: int] =
  let
    position = params.game.currentPosition.searchPos
    legalMoves = position.legalMoves
    startTime = secondsSince1970()
    (softTime, hardTime) = allocatedTime(params)

  doAssert params.searchMoves.allIt(it in legalMoves)
  if params.searchMoves.len == 0:
    return (noMove, 0.Value, 0, 0)

  var state = SearchState(
    externalStopFlag: params.stopFlag,
    hashTable: addr hashTable,
    gameHistory: newGameHistory(params.game),
    stopTime: startTime + hardTime,
    countedNodes: 0,
    maxNodes: params.limit.nodes,
  )

  var
    finalBestMove = params.searchMoves[0]
    finalValue = 0.Value
    finalDepth = 0

  for intDepth in 1 .. params.limit.depth:
    let depth = intDepth.Effort

    let prevNodes = state.countedNodes.float

    let bestValue =
      position.alphabeta(state, alpha = -Inf, beta = Inf, depth = depth, height = 0)

    let
      currNodes = state.countedNodes.float
      nps = currNodes / (secondsSince1970() - startTime).float

    if state.shouldStop:
      break

    finalBestMove = state.bestRootMove
    finalValue = bestValue
    finalDepth = intDepth

    if printUciInfo:
      sendUciInfo(
        UciInfo(
          depth: some depth.int,
          score: some bestValue.toScore,
          pv: some @[finalBestMove],
          nps: some nps.int,
          nodes: some currNodes.int,
        ),
        position,
      )

    let
      perIterMultiplier = currNodes / prevNodes
      estimatedTotalNodesByNextIter = currNodes * perIterMultiplier

    if currNodes >= softNodes.float:
      break

    if prevNodes > 0 and (
      softTime <= (estimatedTotalNodesByNextIter / nps).Seconds or
      estimatedTotalNodesByNextIter >= softNodes.float
    ):
      break

  (finalBestMove, finalValue, state.countedNodes, finalDepth)

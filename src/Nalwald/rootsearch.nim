import std/[atomics, options, sequtils]
import nimchess/[uciserver, movegen, position, types]

import eval, utils, moveiterator, searchpos, types, hashtable

export searchpos

type SearchState = object
  externalStopFlag: ptr Atomic[bool]
  hashTable: ptr HashTable
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
    position: SearchPos, state: var SearchState, alpha, beta: Value, height: int
): Value =
  assert alpha < beta

  state.countedNodes += 1

  if state.shouldStop:
    return -Inf

  if height >= 100:
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
    depth: Ply,
    height: int,
): Value =
  assert alpha < beta

  state.countedNodes += 1

  if state.shouldStop:
    return -Inf

  if depth <= 0.Ply:
    return position.quiesce(state, alpha = alpha, beta = beta, height = height)

  if height > 0:
    let entry = state.hashTable[].get(position.key)
    if not entry.isEmpty and entry.depth >= depth:
      case entry.nodeType
      of exact:
        return entry.value
      of lowerBound:
        if entry.value >= beta:
          return entry.value
      of upperBound:
        if entry.value <= alpha:
          return entry.value

  var
    alpha = alpha
    bestValue = -Inf
    bestMove = noMove
    nodeType = allNode

  for newPosition, move in position.treeSearchMoveIterator:
    let value = -newPosition.alphabeta(
      state, alpha = -beta, beta = -alpha, depth = depth - 1.Ply, height = height + 1
    )

    if value > bestValue:
      bestValue = value
      bestMove = move

      if height == 0 and not state.shouldStop:
        state.bestRootMove = move

    if value > alpha:
      alpha = value
      nodeType = pvNode

    if value >= beta:
      nodeType = cutNode
      break

  if not state.shouldStop:
    state.hashTable[].add(
      position.key,
      nodeType = nodeType,
      value = bestValue,
      depth = depth,
      bestMove = bestMove,
    )

  return bestValue

proc search*(params: GoParams, hashTable: var HashTable): (Move, int) =
  let
    position = params.game.currentPosition.searchPos
    legalMoves = position.legalMoves
    startTime = secondsSince1970()
    (softTime, hardTime) = allocatedTime(params)

  doAssert params.searchMoves.allIt(it in legalMoves)
  if params.searchMoves.len == 0:
    return (noMove, 0)

  var state = SearchState(
    externalStopFlag: params.stopFlag,
    hashTable: addr hashTable,
    stopTime: startTime + hardTime,
    countedNodes: 0,
    maxNodes: params.limit.nodes,
  )

  var finalBestMove = params.searchMoves[0]

  for intDepth in 1 .. params.limit.depth:
    let depth = intDepth.Ply

    let prevNodes = state.countedNodes.float

    let bestValue = position.alphabeta(
      state, alpha = -Inf, beta = Inf, depth = depth, height = 0
    )

    let
      currNodes = state.countedNodes.float
      nps = currNodes / (secondsSince1970() - startTime).float

    if state.shouldStop:
      break

    finalBestMove = state.bestRootMove

    sendUciInfo(
      UciInfo(
        depth: some depth.int,
        score: some Score(kind: skCp, cp: (bestValue * 100.0).int),
        pv: some @[finalBestMove],
        nps: some nps.int,
        nodes: some currNodes.int,
      ),
      position,
    )

    let
      perIterMultiplier = currNodes / prevNodes
      estimatedTotalNodesByNextIter = currNodes * perIterMultiplier

    if softTime <= (estimatedTotalNodesByNextIter / nps).Seconds and prevNodes > 0:
      break

  (finalBestMove, state.countedNodes)

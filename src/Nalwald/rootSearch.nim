import std/[random, os, atomics, options]
import nimchess/[uciserver, movegen, position, types]

import eval, utils, moveIterator, types

type SearchState = object
  externalStopFlag: ptr Atomic[bool]
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
    position: Position, state: var SearchState, alpha, beta: Value, height: int
): Value =
  assert alpha < beta

  state.countedNodes += 1

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
    position: Position,
    state: var SearchState,
    alpha, beta: Value,
    depth: Ply,
    height: int,
): Value =
  assert alpha < beta

  state.countedNodes += 1

  if state.shouldStop:
    return

  var
    alpha = alpha
    bestValue = -Inf

  if depth <= 0.Ply:
    return position.quiesce(state, alpha = alpha, beta = beta, height = height)

  for newPosition, move in position.treeSearchMoveIterator:
    let value = -newPosition.alphabeta(
      state, alpha = -beta, beta = -alpha, depth = depth - 1.Ply, height = height + 1
    )

    if value > bestValue:
      bestValue = value

      if height == 0 and not state.shouldStop:
        state.bestRootMove = move

    if value > alpha:
      alpha = value
    if value >= beta:
      break

  return bestValue

proc search*(params: GoParams): int =
  let position = params.game.currentPosition

  if params.searchMoves.len == 0:
    sendBestMove(noMove, position)
    return 0

  let
    startTime = secondsSince1970()
    (softTime, hardTime) = allocatedTime(params)

  var state = SearchState(
    externalStopFlag: params.stopFlag,
    stopTime: startTime + hardTime,
    countedNodes: 0,
    maxNodes: int.high,
  )

  var finalBestMove = noMove

  for intDepth in 1 .. params.limit.depth:
    let depth = intDepth.Ply

    let prevNodes = state.countedNodes.float

    let bestValue =
      position.alphabeta(state, alpha = -Inf, beta = Inf, depth = depth, height = 0)

    let
      currNodes = state.countedNodes.float
      nps = currNodes / (secondsSince1970() - startTime).float

    if not state.shouldStop:
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
      #   debugEcho softTime, " <= ", (estimatedTotalNodesByNextIter / nps).Seconds
      #   debugEcho "prevNodes: ", prevNodes
      #   debugEcho "currNodes: ", currNodes
      #   debugEcho "nps: ", nps
      #   debugEcho "perIterMultiplier: ", perIterMultiplier
      #   debugEcho "estimatedTotalNodesByNextIter: ", estimatedTotalNodesByNextIter
      break

  sendBestMove(finalBestMove, position)
  state.countedNodes

proc searchHandler*(params: GoParams) {.nimcall, gcsafe.} =
  discard search(params)

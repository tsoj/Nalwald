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

func alphabeta(
    position: Position,
    searchState: var SearchState,
    depth: Ply,
    height: int,
    alpha, beta: Value,
): Value =
  searchState.countedNodes += 1

  if searchState.shouldStop:
    return

  var
    alpha = alpha
    bestValue = -Inf

  if depth <= 0.Ply:
    return position.eval

  for newPosition, move in position.treeSearchMoveIterator:
    let value = -newPosition.alphabeta(
      searchState,
      depth = depth - 1.Ply,
      height = height + 1,
      alpha = -beta,
      beta = -alpha,
    )

    if value > bestValue:
      bestValue = value

      if height == 0 and not searchState.shouldStop:
        searchState.bestRootMove = move

    if value > alpha:
      alpha = value
    if value >= beta:
      break

  return bestValue

proc search*(params: GoParams) {.nimcall, gcsafe.} =
  let position = params.game.currentPosition

  if params.searchMoves.len == 0:
    sendBestMove(noMove, position)
    return

  let
    startTime = secondsSince1970()
    (softTime, hardTime) = allocatedTime(params)

  var searchState = SearchState(
    externalStopFlag: params.stopFlag,
    stopTime: startTime + hardTime,
    countedNodes: 0,
    maxNodes: int.high,
  )

  var finalBestMove = noMove

  for intDepth in 1 .. 100:
    let depth = intDepth.Ply

    let prevNodes = searchState.countedNodes.float

    let bestValue = position.alphabeta(
      searchState, depth = depth, height = 0, alpha = -Inf, beta = Inf
    )

    let
      currNodes = searchState.countedNodes.float
      nps = currNodes / (secondsSince1970() - startTime).float

    if not searchState.shouldStop:
      finalBestMove = searchState.bestRootMove

      sendUciInfo(
        UciInfo(
          depth: some(depth.int),
          score: some(Score(kind: skCp, cp: (bestValue * 100.0).int)),
          pv: some(@[finalBestMove]),
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

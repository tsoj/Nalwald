import std/[random, os, atomics, options]
import nimchess/[uciserver, movegen, position, types]

import eval

proc search*(params: GoParams) {.nimcall, gcsafe.} =
  let position = params.game.currentPosition

  if params.searchMoves.len == 0:
    sendBestMove(noMove, position)
    return

  var
    bestMove = noMove
    bestValue = -Inf
  for move in position.legalMoves:
    let newPos = position.doMove move
    if newPos.isMate:
      bestMove = move
      break

    let value = -newPos.eval

    if value > bestValue:
      bestMove = move
      bestValue = value

  sendBestMove(bestMove, position)

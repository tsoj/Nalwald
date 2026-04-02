import std/[random, os, atomics, options]
import nimchess/[uciserver, movegen, position, types]

proc search*(params: GoParams) {.nimcall, gcsafe.} =
  let position = params.game.currentPosition

  if params.searchMoves.len == 0:
    sendBestMove(noMove, position)
    return

  let bestMove = params.searchMoves[rand(params.searchMoves.len - 1)]

  # Determine how long to "think"
  var thinkTimeSeconds = 0.0

  if params.limit.movetimeSeconds < float.high:
    thinkTimeSeconds = params.limit.movetimeSeconds
  else:
    # Use time control: assume 30 moves remaining
    const assumedMovesRemaining = 30
    let movesToGo =
      if params.limit.movesToGo < int.high:
        params.limit.movesToGo
      else:
        assumedMovesRemaining

    let (timeLeft, inc) =
      if position.us == white:
        (params.limit.whiteTimeSeconds, params.limit.whiteIncSeconds)
      else:
        (params.limit.blackTimeSeconds, params.limit.blackIncSeconds)

    if timeLeft < float.high:
      thinkTimeSeconds = timeLeft / movesToGo.float + inc

  # "Think" by sleeping in small intervals, checking stop flag
  let thinkTimeMs = int(thinkTimeSeconds * 1000)
  var elapsed = 0
  while elapsed < thinkTimeMs:
    if params.stopFlag[].load:
      break
    sleep(10)
    elapsed += 10

  sendUciInfo(
    UciInfo(
      depth: some(1), score: some(Score(kind: skCp, cp: 0)), pv: some(@[bestMove])
    ),
    position,
  )
  sendBestMove(bestMove, position)

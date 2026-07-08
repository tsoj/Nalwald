import std/[atomics, locks, strformat, strutils]
import nimchess
import ../utils, ../types
import openings

type Dashboard* = object
  ## Shared, thread-safe progress/statistics tracker for a datagen run.
  ## It is owned by the main thread and accessed by workers via pointer, so it
  ## must never be copied (it holds `Atomic` fields and a `Lock`).
  targetGames: int
  startTime: Seconds
  claimedGames: Atomic[int]
  finishedGames: Atomic[int]
  totalPositions: Atomic[int]
  totalNodes: Atomic[int]
  # Effort is a float, but atomics only support integer fetchAdd, so the
  # accumulated depth is stored in thousandths.
  totalMilliDepth: Atomic[int]
  totalGamePlies: Atomic[int]
  whiteWins: Atomic[int]
  blackWins: Atomic[int]
  draws: Atomic[int]
  liveLock: Lock
  liveBoard: string
  liveWhiteScore: Score

proc `=copy`*(dest: var Dashboard, source: Dashboard) {.error.}

proc initDashboard*(dashboard: var Dashboard, targetGames: int, startTime: Seconds) =
  dashboard.targetGames = targetGames
  dashboard.startTime = startTime
  initLock dashboard.liveLock

proc claimGameIndex*(dashboard: var Dashboard): int =
  ## Atomically hands out the next game index to a worker thread.
  dashboard.claimedGames.fetchAdd(1)

proc numFinishedGames*(dashboard: var Dashboard): int =
  dashboard.finishedGames.load

proc recordSearchedPosition*(dashboard: var Dashboard, nodes: int, depth: Effort) =
  dashboard.totalPositions.atomicInc
  discard dashboard.totalNodes.fetchAdd(nodes)
  discard dashboard.totalMilliDepth.fetchAdd((depth * 1000.0).int)

proc recordFinishedGame*(dashboard: var Dashboard, gameResult: string, plies: int) =
  case gameResult
  of "1-0": dashboard.whiteWins.atomicInc
  of "0-1": dashboard.blackWins.atomicInc
  else: dashboard.draws.atomicInc
  discard dashboard.totalGamePlies.fetchAdd(plies)
  dashboard.finishedGames.atomicInc

proc updateLiveView*(dashboard: var Dashboard, board: string, whiteValue: Value) =
  withLock dashboard.liveLock:
    dashboard.liveBoard = board
    dashboard.liveWhiteScore = whiteValue.toScore

func progressBar(fraction: float, width: int): string =
  let filled = (fraction.clamp(0.0, 1.0) * width.float).int
  "█".repeat(filled) & "░".repeat(width - filled)

proc frame*(dashboard: var Dashboard): string =
  ## Renders the current progress dashboard as a multi-line string.
  let
    elapsedSeconds = secondsSince1970() - dashboard.startTime
    targetGames = dashboard.targetGames
    finished = dashboard.finishedGames.load
    positions = dashboard.totalPositions.load
    nodes = dashboard.totalNodes.load
    numDraws = dashboard.draws.load
    numWhiteWins = dashboard.whiteWins.load
    numBlackWins = dashboard.blackWins.load
    fraction = finished / targetGames
    eta =
      if finished > 0:
        stringForHuman((targetGames - finished).float * elapsedSeconds / finished.float)
      else:
        "-"
    positionsPerSecond = positions.float / elapsedSeconds.float
    nps = nodes.float / elapsedSeconds.float
    avgGameLength =
      if finished > 0:
        (dashboard.totalGamePlies.load / finished).formatFloat(ffDecimal, 1)
      else:
        "-"
    avgSearchDepth =
      if positions > 0:
        (dashboard.totalMilliDepth.load.float / 1000.0 / positions.float).formatFloat(
          ffDecimal, 1
        )
      else:
        "-"

  func percent(part: int): string =
    if finished > 0:
      $(100 * part div finished) & "%"
    else:
      "-"

  result =
    fmt"{progressBar(fraction, 40)} {finished}/{targetGames} ({100.0 * fraction:.1f}%)" &
    "\n"
  result &=
    fmt"elapsed {elapsedSeconds.stringForHuman} | ETA {eta} | {positionsPerSecond.stringForHuman} positions/s | {nps.stringForHuman} nps | {positions.stringForHuman} positions"
  result &= "\n"
  result &=
    fmt"white/draw/black: {percent(numWhiteWins)}/{percent(numDraws)}/{percent(numBlackWins)} | avg game length: {avgGameLength} plies | avg search depth: {avgSearchDepth}"
  result &= "\n\n"

  withLock dashboard.liveLock:
    if dashboard.liveBoard.len > 0:
      let whiteScore = $dashboard.liveWhiteScore
      # Drop the trailing FEN-like state line of `$position`, keep only the board
      result &=
        dashboard.liveBoard.strip(leading = false).splitLines[0 ..^ 2].join("\n") & "\n"
      result &= fmt"white score: {whiteScore}"
    else:
      result &= "waiting for first move ..."

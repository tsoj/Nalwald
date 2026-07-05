import std/[locks, options, random, sets, strformat]

import nimchess

const
  openingRandomPlies* = 8
  maxConsecutiveOpeningSkips = 100

type Openings* = object
  ## Thread-safe registry of openings already handed out, shared by all datagen
  ## workers via pointer. It holds a `Lock`, so it must never be copied.
  lock: Lock
  knownOpenings: HashSet[string]
  consecutiveSkips: int

proc `=copy`*(dest: var Openings, source: Openings) {.error.}

proc initOpenings*(openings: var Openings) =
  initLock openings.lock

proc randomOpening(
    rng: var Rand, rootPosition: Position, plies: int
): Option[Position] =
  var position = rootPosition
  for _ in 1 .. plies:
    let moves = position.legalMoves
    if moves.len == 0:
      return none Position
    position = position.doMove(rng.sample(moves))

  if position.legalMoves.len == 0 or position.insufficientMaterial:
    return none Position

  position.halfmovesPlayed = 0
  position.halfmoveClock = 0
  some position

proc nextOpening*(
    openings: var Openings, rng: var Rand, rootPosition: Position
): Position =
  ## Generates a fresh opening position by playing random moves from the root
  ## position. Positions already handed out before are skipped; if positions
  ## have to be skipped too many times in a row, the opening pool is considered
  ## exhausted and an error is raised.
  while true:
    let opening = rng.randomOpening(rootPosition, openingRandomPlies)
    if opening.isNone:
      continue

    let position = opening.get

    var isNew = false
    withLock openings.lock:
      if position.fen in openings.knownOpenings:
        openings.consecutiveSkips += 1
        if openings.consecutiveSkips > maxConsecutiveOpeningSkips:
          raise newException(
            CatchableError,
            fmt"Failed to find a new opening after {maxConsecutiveOpeningSkips} " &
              fmt"consecutive skips ({openingRandomPlies} random plies). " &
              "The opening pool seems exhausted.",
          )
      else:
        openings.knownOpenings.incl position.fen
        openings.consecutiveSkips = 0
        isNew = true

    if isNew:
      return position

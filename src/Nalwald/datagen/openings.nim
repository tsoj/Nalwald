import std/[locks, options, random, sets]

import nimchess

const initialOpeningRandomPlies* = 8

var
  openingsLock: Lock
  knownOpenings: HashSet[string]
  consecutiveOpeningSkips = 0
  openingRandomPlies = initialOpeningRandomPlies

proc initOpenings*() =
  initLock openingsLock

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

proc nextOpening*(rng: var Rand, rootPosition: Position): Position =
  ## Generates a fresh opening position by playing random moves from the root
  ## position. Positions already handed out before are skipped; if positions
  ## have to be skipped repeatedly, the number of random plies is increased.
  while true:
    var plies: int
    withLock openingsLock:
      plies = openingRandomPlies

    let opening = rng.randomOpening(rootPosition, plies)
    if opening.isNone:
      continue

    let position = opening.get

    var isNew = false
    withLock openingsLock:
      if position.fen in knownOpenings:
        consecutiveOpeningSkips += 1
        if consecutiveOpeningSkips >= 2:
          openingRandomPlies += 1
          consecutiveOpeningSkips = 0
      else:
        knownOpenings.incl position.fen
        consecutiveOpeningSkips = 0
        isNew = true

    if isNew:
      return position

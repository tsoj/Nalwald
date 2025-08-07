import movegen, position, move
export position

import std/tables

type
  Game* = object
    headers*: Table[string, string]
    moves*: seq[Move]
    startPosition*: Position
    result*: string

func newGame(): Game =
  discard

func positions(game: Game): seq[Position] =
  result = @[game.startPosition]
  for move in game.moves:
    result.add result[^1].doMove(move)

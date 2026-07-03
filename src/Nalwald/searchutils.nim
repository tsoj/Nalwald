import types, searchpos, zobristkey
import nimchess

#-------------- repetition detection --------------#

type GameHistory* = object
  staticHistory: seq[ZobristKey]
  dynamicHistory: array[maxPly, ZobristKey]

func newGameHistory*(game: Game): GameHistory =
  result = default(GameHistory)
  for position in game.positions:
    result.staticHistory.add(position.zobristKey)

func checkForRepetitionAndAdd*(
    gameHistory: var GameHistory, position: SearchPos, height: Ply
): bool =
  gameHistory.dynamicHistory[height] = position.zobristKey

  var count = position.halfmoveClock

  template scan(history, a, b: untyped) =
    for i in countdown(a, b):
      if count <= 0:
        return false
      if position.zobristKey == gameHistory.history[i]:
        return true
      count -= 1

  scan dynamicHistory, height - 1.Ply, 1.Ply
  scan staticHistory, gameHistory.staticHistory.len - 1, 0

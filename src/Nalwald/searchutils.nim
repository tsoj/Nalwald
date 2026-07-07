import std/math
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

#-------------- history heuristic --------------#

type
  HistoryArray = array[white .. black, array[pawn .. king, array[a1 .. h8, float]]]
  HistoryTable* = object
    table: HistoryArray

const maxHistoryTableValue = 135000.0

func newHistoryTable*(): HistoryTable =
  result = default(HistoryTable)

func halve(table: var HistoryArray, color: Color) =
  for piece in pawn .. king:
    for square in a1 .. h8:
      table[color][piece][square] /= 2.0

func update*(historyTable: var HistoryTable, pos: Position, move: Move, depth: Effort) =
  if move.isTactical:
    return

  let
    moved = move.moved(pos)
    color = pos.us

  doAssert moved in pawn .. king, "Is move a noMove? " & $(move == noMove)

  func add(table: var HistoryArray, addition: float) =
    template entry(): auto =
      table[color][moved][move.target]

    entry = clamp(entry + addition, -maxHistoryTableValue, maxHistoryTableValue)

    if entry.abs >= maxHistoryTableValue:
      table.halve(color)

  let addition = depth ^ 2

  historyTable.table.add(addition)

func get*(historyTable: HistoryTable, pos: Position, move: Move): -1.0 .. 1.0 =
  let moved = move.moved(pos)
  historyTable.table[pos.us][moved][move.target] / maxHistoryTableValue

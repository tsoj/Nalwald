import move
import types
import position

type HistoryTable* = array[white..black, array[pawn..king, array[a1..h8, Value]]]
const maxHistoryTableValue = 20000.Value

func halve(historyTable: var HistoryTable) =
    for color in white..black:
        for piece in pawn..king:
            for square in a1..h8:
                historyTable[color][piece][square] = historyTable[color][piece][square] div 2

func update*(historyTable: var HistoryTable, move: Move, color: Color, depth: Ply) =
    if move.isTactical:
        return

    historyTable[color][move.moved][move.target] = 
        min(
            historyTable[color][move.moved][move.target].int32 + depth.int32 * depth.int32,
            maxHistoryTableValue.int32
        ).Value
    
    if historyTable[color][move.moved][move.target] >= maxHistoryTableValue:
        historyTable.halve

func get*(historyTable: HistoryTable, move: Move, color: Color): Value =
    historyTable[color][move.moved][move.target]

const numKillers* = 2

type KillerTable* = array[Ply, array[numKillers, Move]]

func update*(killerTable: var KillerTable, height: Ply, move: Move) =
    if move.isTactical:
        return
    if move == killerTable[height][0]:
        return

    for i in countdown(numKillers - 1, 1):
        killerTable[height][i] = killerTable[height][i-1]
    killerTable[height][0] = move

func get*(killerTable: KillerTable, height: Ply): array[numKillers, Move] =
    killerTable[height]

func isKillerMove*(move: Move, killerTable: KillerTable, height: Ply): bool =
    for i in 0..<numKillers:
        if killerTable[height][i] == move:
            return true
    false


type GameHistory* = object
    staticHistory: seq[uint64]
    dynamicHistory: array[Ply, uint64]

func newGameHistory*(staticHistory: seq[Position]): GameHistory =
    for position in staticHistory:
        doAssert position.zobristKey == position.calculateZobristKey
        result.staticHistory.add(position.zobristKey)

func update*(gameHistory: var GameHistory, position: Position, height: Ply) =
    gameHistory.dynamicHistory[height] = position.zobristKey

func checkForRepetition*(gameHistory: GameHistory, position: Position, height: Ply): bool =

    var count: int16 = position.halfmoveClock
    for i in countdown(height-1.Ply, 0.Ply):
        if count < 0:
            return false
        if position.zobristKey == gameHistory.dynamicHistory[i]:
            return true
        count -= 1
    
    for i in countdown(gameHistory.staticHistory.len - 1, 0):
        if count < 0:
            return false
        if position.zobristKey == gameHistory.staticHistory[i]:
            return true
        count -= 1
    false

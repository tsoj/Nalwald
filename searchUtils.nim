import
    types,
    move,
    position,
    math

type HistoryTable* = array[white..black, array[pawn..king, array[a1..h8, float]]]
const maxHistoryTableValue = 20000.0
static: doAssert maxHistoryTableValue < valueInfinity.float

func halve(historyTable: var HistoryTable) =
    for color in white..black:
        for piece in pawn..king:
            for square in a1..h8:
                historyTable[color][piece][square] = historyTable[color][piece][square] / 2.0

func update*(historyTable: var HistoryTable, move: Move, color: Color, depth: Ply, weakMove = false) =
    if move.isTactical:
        return

    var addition: float = depth.float^2
    addition *= (if weakMove: -1.0/25.0 else: 1.0)

    historyTable[color][move.moved][move.target] =  clamp(
        historyTable[color][move.moved][move.target] + addition,
        -maxHistoryTableValue, maxHistoryTableValue
    )
    
    if historyTable[color][move.moved][move.target].abs >= maxHistoryTableValue:
        historyTable.halve

func get*(historyTable: HistoryTable, move: Move, color: Color): Value =
    historyTable[color][move.moved][move.target].Value

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

import
    types,
    move,
    position,
    math

type HistoryTable* = object
    table: array[white..black, array[pawn..king, array[a1..h8, float]]]
    counterTable: seq[array[pawn..king, array[a1..h8, array[white..black, array[pawn..king, array[a1..h8, float]]]]]]

func newHistoryTable*(): HistoryTable =
    # allocating this on the heap, as it is too big for the stack
    result.counterTable.setLen(1)

const maxHistoryTableValue = 20000.0
static: doAssert maxHistoryTableValue < valueInfinity.float

func halve(table: var array[white..black, array[pawn..king, array[a1..h8, float]]]) =
    for color in white..black:
        for piece in pawn..king:
            for square in a1..h8:
                table[color][piece][square] = table[color][piece][square] / 2.0

func update*(historyTable: var HistoryTable, move, previous: Move, color: Color, depth: Ply, weakMove = false) =
    if move.isTactical:
        return

    func add(
        table: var array[white..black, array[pawn..king, array[a1..h8, float]]],
        color: Color, piece: Piece, target: Square, addition: float
    ) =
        table[color][piece][target] = clamp(
            table[color][piece][target] + addition,
            -maxHistoryTableValue, maxHistoryTableValue
        )    
        if table[color][piece][target].abs >= maxHistoryTableValue:
            table.halve

    let addition = (if weakMove: -1.0/25.0 else: 1.0) * depth.float^2

    historyTable.table.add(color, move.moved, move.target, addition)

    if previous.moved in pawn..king and previous.target in a1..h8:
        historyTable.counterTable[0][previous.moved][previous.target].add(color, move.moved, move.target, addition * 50.0)        

func get*(historyTable: HistoryTable, move, previous: Move, color: Color): Value =
    result = historyTable.table[color][move.moved][move.target].Value
    if previous.moved in pawn..king and previous.target in a1..h8:
        result += historyTable.counterTable[0][previous.moved][previous.target][color][move.moved][move.target].Value

type KillerTable* = object
    table: array[Ply, array[2, Move]]
    counterTable: array[white..black, array[pawn..king, array[a1..h8, array[2, Move]]]]

func update*(killerTable: var KillerTable, height: Ply, move: Move) =
    if move.isTactical:
        return
    
    func add(list: var array[2, Move], move: Move) =
        if list[0] != move:
            list[1] = list[0]
            list[0] = move
            
    killerTable.table[height].add(move)

func get*(killerTable: KillerTable, height: Ply): array[2, Move] =
    killerTable.table[height]

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

import
    types,
    move,
    position,
    bitboard

import std/[
    math
]

#-------------- history heuristic --------------#

type
    HistoryArray = array[white..black, array[pawn..king, array[a1..h8, float]]]
    PositionContextualHistoryArray = array[white..black, array[knight..king, array[a1..h8, HistoryArray]]]
    HistoryTable* = object
        table: HistoryArray
        pcTable: ref PositionContextualHistoryArray
        counterTable: ref array[pawn..king, array[a1..h8, HistoryArray]]

func newHistoryTable*(): HistoryTable =
    # allocating this on the heap, as it is too big for the stack
    result.counterTable = new array[pawn..king, array[a1..h8, HistoryArray]]
    result.pcTable = new PositionContextualHistoryArray

const maxHistoryTableValue = 100000.0

func halve(table: var HistoryArray, color: Color) =
    for piece in pawn..king:
        for square in a1..h8:
            table[color][piece][square] /= 2.0

func update*(historyTable: var HistoryTable, position: Position, move, previous: Move, color: Color, depth: Ply, raisedAlpha: bool) =
    if move.isTactical:
        return

    doAssert historyTable.pcTable != nil
    doAssert historyTable.counterTable != nil

    func add(
        table: var HistoryArray,
        color: Color, move: Move, addition: float
    ) =
        template entry(): auto = table[color][move.moved][move.target]
        entry = clamp(
            entry + addition,
            -maxHistoryTableValue, maxHistoryTableValue
        )    
        if entry.abs >= maxHistoryTableValue:
            table.halve(color)

    func add(
        pcTable: var PositionContextualHistoryArray,
        position: Position,
        color: Color, move: Move, addition: float
    ) =
        let addition = addition / position.occupancy.countSetBits.float
        for pieceColor in white..black:
            for piece in knight..king:
                for pieceSquare in position[pieceColor] and position[piece]:
                    pcTable[pieceColor][piece][pieceSquare].add(color, move, addition)

    let addition = (if raisedAlpha: 1.0 else: -1.0/15.0) * depth.float^2

    historyTable.table.add(color, move, addition)
    historyTable.pcTable[].add(position, color, move, addition * 2.5)

    if previous.moved in pawn..king and previous.target in a1..h8:
        historyTable.counterTable[][previous.moved][previous.target].add(color, move, addition * 50.0)

var f: float = 1.0
var i = 1.0

func get*(historyTable: HistoryTable, position: Position, move, previous: Move, color: Color): -1.0..1.0 =
    var sum = historyTable.table[color][move.moved][move.target]

    var pcTableSum = 0.0
    for pieceColor in [position.enemy]:
        for piece in knight..king:
            for pieceSquare in position[pieceColor] and position[piece]:
                pcTableSum += historyTable.pcTable[pieceColor][piece][pieceSquare][color][move.moved][move.target]

    # {.cast(noSideEffect).}:
    #     if pcTableSum.abs > 0.0:
    #         f += sum/pcTableSum
    #         i += 1.0
    #         debugEcho "f/i: ", f/i
    sum += pcTableSum
    if previous.moved in pawn..king and previous.target in a1..h8:
        sum += historyTable.counterTable[][previous.moved][previous.target][color][move.moved][move.target]

    sum / (3*maxHistoryTableValue)


#-------------- killer heuristic --------------#

type KillerTable* = object
    table: array[Ply, array[2, Move]]

func update*(killerTable: var KillerTable, height: Ply, move: Move) =
    if move.isTactical:
        return
    
    func add(list: var array[2, Move], move: Move) =
        if list[0] != move:
            list[1] = list[0]
            list[0] = move
            
    killerTable.table[height].add(move)

func get*(killerTable: KillerTable, height: Ply): array[2, Move] =

    result[0] = killerTable.table[height][0]
    result[1] = killerTable.table[height][1]

#-------------- repetition detection --------------#

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
        if count <= 0:
            return false
        if position.zobristKey == gameHistory.dynamicHistory[i]:
            return true
        count -= 1
    
    for i in countdown(gameHistory.staticHistory.len - 1, 0):
        if count <= 0:
            return false
        if position.zobristKey == gameHistory.staticHistory[i]:
            return true
        count -= 1
    false

import
    types,
    move,
    position

import std/[
    math
]

#-------------- history heuristic --------------#

type
    HistoryArray = array[white..black, array[pawn..king, array[a1..h8, float]]]
    HistoryTable* = object
        table: HistoryArray
        counterTable: ref array[pawn..king, array[a1..h8, HistoryArray]]

func newHistoryTable*(): HistoryTable =
    # allocating this on the heap, as it is too big for the stack
    result.counterTable = new array[pawn..king, array[a1..h8, HistoryArray]]

const maxHistoryTableValue = 100000.0

func halve(table: var HistoryArray, color: Color) =
    for piece in pawn..king:
        for square in a1..h8:
            table[color][piece][square] /= 2.0

func update*(historyTable: var HistoryTable, move, previous: Move, color: Color, depth: Ply, raisedAlpha: bool) =
    if move.isTactical:
        return

    doAssert move.moved in pawn..king, "Is move a noMove? " & $(move == noMove)
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


    let addition = (if raisedAlpha: 1.0 else: -1.0/15.0) * depth.float^2

    historyTable.table.add(color, move, addition)

    if previous.moved in pawn..king and previous.target in a1..h8:
        historyTable.counterTable[][previous.moved][previous.target].add(color, move, addition * 50.0)

func get*(historyTable: HistoryTable, move, previous: Move, color: Color): -1.0..1.0 =
    var sum = historyTable.table[color][move.moved][move.target]

    if previous.moved in pawn..king and previous.target in a1..h8:
        sum += historyTable.counterTable[][previous.moved][previous.target][color][move.moved][move.target]

    sum / (2*maxHistoryTableValue)


#-------------- killer heuristic --------------#

type KillerTable* = object
    table: array[Ply, array[2, Move]]

func update*(killerTable: var KillerTable, height: Ply, move: Move) =
    if move.isTactical:
        return
    
    template list(): auto = killerTable.table[height]

    if list[0] != move:
        list[1] = list[0]
        list[0] = move

func get*(killerTable: KillerTable, height: Ply): array[2, Move] =
    killerTable.table[height]

#-------------- repetition detection --------------#

type GameHistory* = object
    staticHistory: seq[ZobristKey]
    dynamicHistory: array[Ply, ZobristKey]

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

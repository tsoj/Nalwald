import ../position
import ../types
import ../search
import ../hashTable
import times
import ../movegen
import ../move
import ../evaluation

type
    Game* = object
        hashTable: array[white..black, HashTable]
        positionHistory: seq[Position]
        moveTime: Duration
        earlyResignMargin: Value
        earlyAdjudicationPly: Ply
        evaluation: proc(position: Position): Value {.noSideEffect.}
    GameStatus = enum
        running, fiftyMoveRule, threefoldRepetition, stalemate, checkmateWhite, checkmateBlack

func gameStatus(positionHistory: openArray[Position]): GameStatus =
    doAssert positionHistory.len >= 1
    let position = positionHistory[^1]
    if position.legalMoves.len == 0:
        if position.inCheck(position.us, position.enemy):
            return (if position.enemy == black: checkmateBlack else: checkmateWhite)
        else:
            return stalemate
    if position.halfmoveClock >= 100:
            return fiftyMoveRule
    var repetitions = 0
    for p in positionHistory:
        if p.zobristKey == position.zobristKey:
            repetitions += 1
    doAssert repetitions >= 1
    doAssert repetitions <= 3
    if repetitions == 3:
        return threefoldRepetition
    running

proc makeNextMove(game: var Game): (GameStatus, Value, Move) =
    doAssert game.positionHistory.len >= 1
    let position = game.positionHistory[^1]
    let us = position.us
    let (value, pv) = position.timeManagedSearch(
        hashTable = game.hashTable[us],
        positionHistory = game.positionHistory,
        evaluation = game.evaluation,
        moveTime = game.moveTime
    )
    doAssert pv.len >= 1 and pv[0] != noMove
    game.positionHistory.add(position)
    game.positionHistory[^1].doMove(pv[0])
    (game.positionHistory.gameStatus, value * (if position.us == white: 1 else: -1), pv[0])

func newGame*(
    startingPosition: Position,
    moveTime = initDuration(milliseconds = 10),
    earlyResignMargin = 500.Value,
    earlyAdjudicationPly = 8.Ply,
    hashSize = 4_000_000,
    evaluation: proc(position: Position): Value {.noSideEffect.} = evaluate
): Game =
    result = Game(
        positionHistory: @[startingPosition],
        moveTime: moveTime,
        earlyResignMargin: earlyResignMargin,
        earlyAdjudicationPly: earlyAdjudicationPly,
        evaluation: evaluation
    )
    result.hashTable[white].setSize(hashSize)
    result.hashTable[black].setSize(hashSize)

proc playGame*(game: var Game, suppressOutput = false): float =
    doAssert game.positionHistory.len >= 1
    if not suppressOutput:
        echo "-----------------------------"
        echo "starting position:"
        echo game.positionHistory[0]

    var drawPlies = 0.Ply
    var whiteResignPlies = 0.Ply
    var blackResignPlies = 0.Ply

    while true:
        var (gameStatus, value, move) = game.makeNextMove()
        if value == 0.Value:
            drawPlies += 1.Ply
        else:
            drawPlies = 0.Ply

        if value >= game.earlyResignMargin:
            blackResignPlies += 1.Ply
        else:
            blackResignPlies = 0.Ply
        if -value >= game.earlyResignMargin:
            whiteResignPlies += 1.Ply
        else:
            whiteResignPlies = 0.Ply

        if not suppressOutput:
            echo "Move: ", move
            echo game.positionHistory[^1]
            echo "Value: ", value
            if gameStatus != running:
                echo gameStatus

        if gameStatus != running:
            case gameStatus:
            of stalemate, fiftyMoveRule, threefoldRepetition:
                return 0.5
            of checkmateWhite:
                return 1.0
            of checkmateBlack:
                return 0.0
            else:
                doAssert false

        if drawPlies >= game.earlyAdjudicationPly:
            return 0.5
        if whiteResignPlies >= game.earlyAdjudicationPly:
            return 0.0
        if blackResignPlies >= game.earlyAdjudicationPly:
            return 1.0



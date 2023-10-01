import
    ../position,
    ../positionUtils,
    ../types,
    ../timeManagedSearch,
    ../hashTable,
    ../move,
    ../evaluation

import std/[
    options
]

type
    Game* = object
        hashTable: HashTable
        positionHistory: seq[Position]
        maxNodes: int64
        earlyResignMargin: Value
        earlyAdjudicationMinConsistentPly: Ply
        evaluation: proc(position: Position): Value {.noSideEffect.}
    GameStatus* = enum
        running, fiftyMoveRule, threefoldRepetition, stalemate, checkmateWhite, checkmateBlack

func gameStatus*(positionHistory: openArray[Position]): GameStatus =
    doAssert positionHistory.len >= 1
    let position = positionHistory[^1]
    if position.legalMoves.len == 0:
        if position.inCheck(position.us):
            return (if position.enemy == black: checkmateBlack else: checkmateWhite)
        else:
            return stalemate
    if position.halfmoveClock >= 100:
            return fiftyMoveRule
    var repetitions = 0
    for p in positionHistory:
        if p.zobristKey == position.zobristKey:
            repetitions += 1
    doAssert repetitions in 1..3
    if repetitions == 3:
        return threefoldRepetition
    running

proc makeNextMove*(game: var Game): (GameStatus, Value, Move) =
    doAssert game.positionHistory.len >= 1
    doAssert game.positionHistory.gameStatus == running, $game.positionHistory.gameStatus
    let position = game.positionHistory[^1]
    let pvSeq = position.timeManagedSearch(
        hashTable = game.hashTable,
        positionHistory = game.positionHistory,
        evaluation = game.evaluation,
        maxNodes = game.maxNodes
    )
    doAssert pvSeq.len >= 1
    let
        pv = pvSeq[0].pv
        value = pvSeq[0].value
    doAssert pv.len >= 1
    doAssert pv[0] != noMove

    game.positionHistory.add position.doMove(pv[0])
    return (game.positionHistory.gameStatus, value * (if position.us == white: 1 else: -1), pv[0])
    



func newGame*(
    startingPosition: Position,
    maxNodes = 20_000,
    earlyResignMargin = 800.Value,
    earlyAdjudicationMinConsistentPly = 8.Ply,
    hashLen = none(int),
    evaluation: proc(position: Position): Value {.noSideEffect.} = evaluate
): Game =
    result = Game(
        hashTable: newHashTable(len = hashLen.get(otherwise = maxNodes*2)),
        positionHistory: @[startingPosition],
        maxNodes: maxNodes,
        earlyResignMargin: earlyResignMargin,
        earlyAdjudicationMinConsistentPly: earlyAdjudicationMinConsistentPly,
        evaluation: evaluation
    )

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

        if drawPlies >= game.earlyAdjudicationMinConsistentPly:
            return 0.5
        if whiteResignPlies >= game.earlyAdjudicationMinConsistentPly:
            return 0.0
        if blackResignPlies >= game.earlyAdjudicationMinConsistentPly:
            return 1.0




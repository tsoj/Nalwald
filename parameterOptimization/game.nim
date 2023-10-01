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
    Game* {.requiresInit.} = object
        hashTable: HashTable
        positionHistory: seq[Position]
        maxNodes: int64
        earlyResignMargin: Value
        earlyAdjudicationMinConsistentPly: int
        minAdjudicationGameLenPly: int
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

proc makeNextMove(game: var Game): (GameStatus, Value, Move) =
    doAssert game.positionHistory.len >= 1
    doAssert game.positionHistory.gameStatus == running, $game.positionHistory.gameStatus
    let
        position = game.positionHistory[^1]
        pvSeq = position.timeManagedSearch(
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

    game.positionHistory.add position.doMove pv[0]

    (game.positionHistory.gameStatus, if position.us == white: value else: -value, pv[0])
    
func newGame*(
    startingPosition: Position,
    maxNodes = 20_000,
    earlyResignMargin = 800.Value,
    earlyAdjudicationMinConsistentPly = 8,
    minAdjudicationGameLenPly = 30,
    hashLen = none(int),
    evaluation: proc(position: Position): Value {.noSideEffect.} = evaluate
): Game =
    Game(
        hashTable: newHashTable(len = hashLen.get(otherwise = maxNodes*2)),
        positionHistory: @[startingPosition],
        maxNodes: maxNodes,
        earlyResignMargin: earlyResignMargin,
        earlyAdjudicationMinConsistentPly: earlyAdjudicationMinConsistentPly,
        minAdjudicationGameLenPly: minAdjudicationGameLenPly,
        evaluation: evaluation
    )

proc playGame*(game: var Game, suppressOutput = false): float =
    doAssert game.positionHistory.len >= 1, "Need a starting position"

    template echoSuppressed(x: typed) =
        if not suppressOutput:
            echo $x

    echoSuppressed "-----------------------------"
    echoSuppressed "starting position:"
    echoSuppressed game.positionHistory[0]

    var
        drawPlies = 0
        whiteResignPlies = 0
        blackResignPlies = 0

    while true:
        var (gameStatus, value, move) = game.makeNextMove()
        if value == 0.Value:
            drawPlies += 1
        else:
            drawPlies = 0

        if value >= game.earlyResignMargin:
            blackResignPlies += 1
        else:
            blackResignPlies = 0
        if -value >= game.earlyResignMargin:
            whiteResignPlies += 1
        else:
            whiteResignPlies = 0

        echoSuppressed "Move: " & $move
        echoSuppressed game.positionHistory[^1]
        echoSuppressed "Value: " & $value
        if gameStatus != running:
            echoSuppressed gameStatus

        if gameStatus != running:
            case gameStatus:
            of stalemate, fiftyMoveRule, threefoldRepetition:
                return 0.5
            of checkmateWhite:
                return 1.0
            of checkmateBlack:
                return 0.0
            else:
                doAssert false, $gameStatus

        if game.positionHistory.len >= game.minAdjudicationGameLenPly:
            if drawPlies >= game.earlyAdjudicationMinConsistentPly:
                echoSuppressed "Adjudicated draw"
                return 0.5
            if whiteResignPlies >= game.earlyAdjudicationMinConsistentPly:
                echoSuppressed "White resigned"
                return 0.0
            if blackResignPlies >= game.earlyAdjudicationMinConsistentPly:
                echoSuppressed "Black resigned"
                return 1.0




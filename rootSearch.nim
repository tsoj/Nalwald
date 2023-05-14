import
    types,
    position,
    positionUtils,
    move,
    search,
    hashTable,
    searchUtils,
    evaluation,
    times

import std/[
    threadpool,
    os,
    atomics,
    strformat
]

# TODO: create one big search info object

func launchSearch(
    position: Position,
    hashTable: ptr HashTable,
    stop: ptr Atomic[bool],
    threadStop: ptr Atomic[bool],
    historyTable: ptr HistoryTable,
    gameHistory: GameHistory,
    depth: Ply,
    maxNodes: uint64,
    skipMoves: seq[Move],
    evaluation: proc(position: Position): Value {.noSideEffect.}
): uint64 =
    var state = SearchState(
        stop: stop,
        threadStop: threadStop,
        hashTable: hashTable,
        historyTable: historyTable,
        gameHistory: gameHistory,
        maxNodes: maxNodes,
        skipMovesAtRoot: skipMoves,
        evaluation: evaluation
    )
    discard position.search(state, depth = depth)
    state.countedNodes

type Pv* = object
    value*: Value
    pv*: seq[Move]

iterator iterativeDeepeningSearch*(
    position: Position,
    hashTable: var HashTable,
    stop: ptr Atomic[bool],
    positionHistory: seq[Position] = @[],
    targetDepth: Ply = Ply.high,
    numThreads = 1,
    maxNodes = uint64.high,
    multiPv = 1,
    searchMoves: seq[Move] = @[],
    evaluation: proc(position: Position): Value {.noSideEffect.} = evaluate
): tuple[pvList: seq[Pv], nodes: uint64, canStop: bool] {.noSideEffect.} =
    {.cast(noSideEffect).}:

        let legalMoves = position.legalMoves

        if legalMoves.len == 0:
            yield (pvList: @[], nodes: 0'u64, canStop: true)
        else:

            let
                numThreads = max(1, numThreads)
                gameHistory = newGameHistory(positionHistory)
            var
                totalNodes = 0'u64
                historyTable: seq[HistoryTable]
            for _ in 0..<numThreads:
                historyTable.add newHistoryTable()

            hashTable.age()        

            let start = now()
            for depth in 1.Ply..targetDepth:

                var
                    foundCheckmate = false
                    pvList: seq[Pv]
                    skipMoves: seq[Move]
                    multiPvNodes = 0'u64

                for move in position.legalMoves:
                    if move notin searchMoves and searchMoves.len > 0:
                        skipMoves.add move

                for multiPvNumber in 1..multiPv:

                    for move in skipMoves:
                        doAssert move in position.legalMoves
                    
                    if skipMoves.len == position.legalMoves.len:
                        break

                    var
                        currentPvNodes = 0'u64
                        threadStop: Atomic[bool]
                    
                    threadStop.store(false)
                    
                    template launchSearch(i: auto): auto = launchSearch(
                        position,
                        addr hashTable,
                        stop,
                        addr threadStop,
                        addr historyTable[i],
                        gameHistory,
                        depth,
                        (maxNodes - totalNodes) div numThreads.uint64,
                        skipMoves,
                        evaluation
                    )

                    if numThreads == 1 or (now() - start).inMilliseconds < 100:
                        # don't use multithreading too early or when only one thread allowed
                        currentPvNodes = launchSearch(0)
                    else:
                        var threadSeq: seq[FlowVar[uint64]]
                        for i in 0..<numThreads:
                            if i > 0: sleep(1)
                            threadSeq.add spawn launchSearch(i)

                        while threadSeq.len == numThreads:
                            sleep(1)
                            for i, flowVar in threadSeq.mpairs:
                                if flowVar.isReady:
                                    currentPvNodes = ^flowVar
                                    threadSeq.del i
                                    break

                        threadStop.store(true)                
                        for flowVar in threadSeq.mitems:
                            currentPvNodes += ^flowVar

                    totalNodes += currentPvNodes
                    multiPvNodes += currentPvNodes

                    let
                        pv = hashTable.getPv(position)
                        value = hashTable.get(position.zobristKey).value
                    doAssert pv.len >= 1, &"\n{position.fen = }\n{positionHistory = }\n{depth = }"

                    skipMoves.add pv[0]

                    pvList.add Pv(value: value, pv: pv)

                    foundCheckmate = abs(value) >= valueCheckmate
                
                    if stop[].load or totalNodes >= maxNodes:
                        break
                

                yield (
                    pvList: pvList,
                    nodes: multiPvNodes,
                    canStop: legalMoves.len == 1 or foundCheckmate
                )

                if stop[].load or totalNodes >= maxNodes:
                    break

import
    types,
    position,
    positionUtils,
    move,
    search,
    hashTable,
    searchUtils,
    evaluation,
    times,
    threadpool,
    os,
    atomics

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
    evaluation: proc(position: Position): Value {.noSideEffect.}
): uint64 =
    var state = SearchState(
        stop: stop,
        threadStop: threadStop,
        hashTable: hashTable,
        historyTable: historyTable,
        gameHistory: gameHistory,
        evaluation: evaluation,
        maxNodes: maxNodes
    )
    discard position.search(
        state,
        alpha = -valueInfinity, beta = valueInfinity,
        depth = depth, height = 0,
        previous = noMove
    )
    state.countedNodes

iterator iterativeDeepeningSearch*(
    position: Position,
    hashTable: var HashTable,
    positionHistory: seq[Position],
    targetDepth: Ply,
    stop: ptr Atomic[bool],
    numThreads = 1,
    maxNodes = uint64.high,
    evaluation: proc(position: Position): Value {.noSideEffect.} = evaluate
): tuple[value: Value, pv: seq[Move], nodes: uint64, canStop: bool] {.noSideEffect.} =
    {.cast(noSideEffect).}:

        let legalMoves = position.legalMoves

        if legalMoves.len == 0:
            yield (value: 0.Value, pv: @[noMove], nodes: 0'u64, canStop: true)
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
                    nodes = 0'u64
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
                    evaluation
                )

                if numThreads == 1 or (now() - start).inMilliseconds < 100:
                    # don't use multithreading too early or when only one thread allowed
                    nodes = launchSearch(0)
                else:
                    var threadSeq: seq[FlowVar[uint64]]
                    for i in 0..<numThreads:
                        if i > 0: sleep(1)
                        threadSeq.add spawn launchSearch(i)

                    while threadSeq.len == numThreads:
                        sleep(1)
                        for i, flowVar in threadSeq.mpairs:
                            if flowVar.isReady:
                                nodes = ^flowVar
                                threadSeq.del i
                                break

                    threadStop.store(true)                
                    for flowVar in threadSeq.mitems:
                        nodes += ^flowVar

                totalNodes += nodes

                let
                    pv = hashTable.getPv(position)
                    value = hashTable.get(position.zobristKey).value
                doAssert pv.len >= 1

                yield (
                    value: value,
                    pv: pv,
                    nodes: nodes,
                    canStop: legalMoves.len == 1 or abs(value) >= valueCheckmate
                )

                if stop[].load or totalNodes >= maxNodes:
                    break

import
    types,
    position,
    move,
    search,
    hashTable,
    searchUtils,
    evaluation,
    times,
    threadpool,
    os,
    atomics


type SearchThreadResult = tuple
    value: Value
    nodes: uint64
    numMovesAtRoot: int

func launchSearch(
    position: Position,
    hashTable: ptr HashTable,
    stop: ptr Atomic[bool],
    historyTable: ptr HistoryTable,
    gameHistory: GameHistory,
    depth: Ply,
    evaluation: proc(position: Position): Value {.noSideEffect.}
): SearchThreadResult =
    var state = SearchState(
        stop: stop,
        hashTable: hashTable,
        historyTable: historyTable,
        gameHistory: gameHistory,
        evaluation: evaluation
    )
    let value = position.search(
        state,
        alpha = -valueInfinity, beta = valueInfinity,
        depth = depth, height = 0,
        previous = noMove
    )
    (value: value, nodes: state.countedNodes, numMovesAtRoot: state.numMovesAtRoot)

iterator iterativeDeepeningSearch*(
    position: Position,
    hashTable: var HashTable,
    positionHistory: seq[Position],
    targetDepth: Ply,
    stop: ptr Atomic[bool],
    numThreads = 1,
    evaluation: proc(position: Position): Value {.noSideEffect.} = evaluate
): tuple[value: Value, pv: seq[Move], nodes: uint64] {.noSideEffect.} =
    {.cast(noSideEffect).}:
        let numThreads = max(1, numThreads)
        let gameHistory = newGameHistory(positionHistory)
        var historyTable: seq[HistoryTable]
        for _ in 0..<numThreads:
            historyTable.add newHistoryTable()

        hashTable.age()        

        let start = now()
        for depth in 1.Ply..targetDepth:
            var
                nodes = 0'u64
                value: Value
                numMovesAtRoot: int
            
            template launchSearch(i: auto): auto = launchSearch(
                position,
                addr hashTable,
                stop,
                addr historyTable[i],
                gameHistory,
                depth,
                evaluation
            )

            if numThreads == 1 or (now() - start).inMilliseconds < 100:
                # don't use multithreading too early or when only one thread allowed
                (value, nodes, numMovesAtRoot) = launchSearch(0)
            else:
                var threadSeq: seq[FlowVar[SearchThreadResult]]
                for i in 0..<numThreads:
                    if i > 0: sleep(1)
                    threadSeq.add spawn launchSearch(i)

                while threadSeq.len == numThreads:
                    sleep(1)
                    for i, flowVar in threadSeq.mpairs:
                        if flowVar.isReady:
                            (value, nodes, numMovesAtRoot) = ^flowVar
                            threadSeq.del i
                            break

                let oldStop = stop[].load
                stop[].store(true)                
                for flowVar in threadSeq.mitems:
                    let r = ^flowVar
                    nodes += r.nodes
                stop[].store(oldStop)


            if stop[].load:
                break

            let hashResult = hashTable.get(position.zobristKey)

            doAssert not hashResult.isEmpty
            let pv = if numMovesAtRoot >= 1: hashTable.getPv(position) else: @[noMove]

            yield (value: value, pv: pv, nodes: nodes)

            if numMovesAtRoot == 1:
                break

            if abs(value) >= valueCheckmate:
                break

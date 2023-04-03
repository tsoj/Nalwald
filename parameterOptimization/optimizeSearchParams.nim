import
    ../searchParameters,
    ../types,
    ../position,
    ../positionUtils,
    game

import std/[
    threadpool,
    random,
    times,
    tables,
    os
]

proc playGame(spA, spB: SearchParameters, startingPosition: Position, nodesPerMove: int): float =
    ## return the result

    doAssert nodesPerMove > 0
    result = 0.0
    var numGames = 0
    for colorA in white..black:
        var sp: array[white..black, SearchParameters]
        sp[colorA] = spA
        sp[colorA.opposite] = spB
        var game = newGame(
            startingPosition = startingPosition,
            maxNodes = nodesPerMove.uint64,
            searchParams = sp
        )

        let outcome = game.playGame(suppressOutput = true)
        numGames += 1
        if colorA == white:
            result += outcome
        else:
            result += 1.0 - outcome

    result /= numGames.float

const
    numNodesPerMove = 100_000
    maxNumThreads = 20
    maxRunningTime = initDuration(hours = 24)

# setMaxPoolSize maxNumThreads

proc findNextSearchParams(startParams: SearchParameters, openings: openArray[Position]): SearchParameters =
    let candidateSearchParams = startParams.getChanges

    var scores = newSeq[float](candidateSearchParams.len)

    var gameThreads: Table[tuple[indexPlayerA: int, indexPlayerB: int], FlowVar[float]]

    proc collectThreadResults() =
        while gameThreads.len >= maxNumThreads:
            sleep 50
            var finishedIndices: seq[tuple[indexPlayerA: int, indexPlayerB: int]]
            for indices, thread in gameThreads:
                if thread.isReady:

                    finishedIndices.add indices

                    let outcome = ^thread
                    let (indexPlayerA, indexPlayerB) = indices

                    doAssert indexPlayerA < scores.len
                    doAssert indexPlayerB < scores.len

                    scores[indexPlayerA] += outcome
                    scores[indexPlayerB] += 1.0 - outcome

            for indices in finishedIndices:
                gameThreads.del indices

    for a in 0 ..< candidateSearchParams.len-1:
        for b in a+1 ..< candidateSearchParams.len:
            echo "ab, ", a, ", ", b
            collectThreadResults()
            gameThreads[(a,b)] = spawn playGame(candidateSearchParams[a], candidateSearchParams[b], openings[rand(0..<openings.len)], numNodesPerMove)
    collectThreadResults()

    var bestIndex = 0
    for i in 0..<scores.len:
        if scores[bestIndex] < scores[i]:
            bestIndex = i
    doAssert bestIndex < candidateSearchParams.len
    candidateSearchParams[bestIndex]



var
    currentSearchParams = defaultSearchParams
    iteration = 0

let openings = positionsFromFile "blitzTesting-4moves-openings.epd"

let start = now()
while now() - start < maxRunningTime:
    iteration += 1
    echo "Starting ", iteration
    currentSearchParams = currentSearchParams.findNextSearchParams(openings)

    if (iteration mod 1) == 0:
        echo "Finished ", iteration, " iterations"

echo currentSearchParams


    
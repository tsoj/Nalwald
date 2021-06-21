import types
import move
import position
import movegen
import see
import searchUtils



iterator moveIterator*(
    position: Position,
    tryFirstMove = noMove,
    historyTable: ptr HistoryTable = nil,
    killers = [noMove, noMove],
    doQuiets = true
): Move =

    var
        moves {.noInit.}: array[maxNumMoves, Move]
        movePriorities {.noInit.}: array[maxNumMoves, Value]
        numMoves: int

    template findBestMoves(minValue = -valueInfinity, m = moves, mp = movePriorities, nm = numMoves) =
        while true:
            var bestIndex = nm
            var bestValue = minValue
            for i in 0..<nm:
                if mp[i] > bestValue:
                    bestValue = mp[i]
                    bestIndex = i
            if bestIndex != nm:
                mp[bestIndex] = -valueInfinity
                if m[bestIndex] != tryFirstMove and m[bestIndex] != killers[0] and m[bestIndex] != killers[1]:
                    yield m[bestIndex]
            else:
                break

    # hash move
    if position.isPseudoLegal(tryFirstMove):
        yield tryFirstMove

    # init capture moves
    numMoves = position.generateCaptures(moves)
    for i in 0..<numMoves:
        movePriorities[i] = position.see(moves[i])    

    # winning captures
    const minWinningValue = -2*values[pawn]
    findBestMoves(minWinningValue)

    # killers
    if doQuiets:
        for i in 0..1:
            if i != 0 and killers[i-1] == killers[i]:
                break
            if position.isPseudoLegal(killers[i]) and killers[i] != tryFirstMove:
                yield killers[i]


    var
        movesQ {.noInit.}: array[maxNumMoves, Move]
        movePrioritiesQ {.noInit.}: array[maxNumMoves, Value]
        numMovesQ: int

    # quiet moves
    if doQuiets:
        numMovesQ = position.generateQuiets(movesQ)
        for i in 0..<numMovesQ:
            movePrioritiesQ[i] =
                (if historyTable != nil: historyTable[].get(movesQ[i], position.us) else: 0.Value)
                
        findBestMoves(m = movesQ, mp = movePrioritiesQ, nm = numMovesQ)
    

    # losing captures
    findBestMoves()

    #TODO make this all cleaner
        

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

    template findBestMoves(minValue = -valueInfinity) =
        while true:
            var bestIndex = numMoves
            var bestValue = minValue
            for i in 0..<numMoves:
                if movePriorities[i] > bestValue:
                    bestValue = movePriorities[i]
                    bestIndex = i
            if bestIndex != numMoves:
                movePriorities[bestIndex] = -valueInfinity
                if moves[bestIndex] != tryFirstMove and moves[bestIndex] != killers[0] and moves[bestIndex] != killers[1]:
                    yield moves[bestIndex]
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

    # losing captures
    findBestMoves()   

    # quiet moves
    if doQuiets:
        numMoves = position.generateQuiets(moves)
        for i in 0..<numMoves:
            movePriorities[i] =
                (if historyTable != nil: historyTable[].get(moves[i], position.us) else: 0.Value)
                
        findBestMoves()
        

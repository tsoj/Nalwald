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
    type OrderedMoveList = object
        moves: array[maxNumMoves, Move]
        movePriorities: array[maxNumMoves, Value]
        numMoves: int

    template findBestMoves(moveList: var OrderedMoveList, minValue = -valueInfinity) =
        while true:
            var bestIndex = moveList.numMoves
            var bestValue = minValue
            for i in 0..<moveList.numMoves:
                if moveList.movePriorities[i] > bestValue:
                    bestValue = moveList.movePriorities[i]
                    bestIndex = i
            if bestIndex != moveList.numMoves:
                moveList.movePriorities[bestIndex] = -valueInfinity
                
                if moveList.moves[bestIndex] != tryFirstMove and
                moveList.moves[bestIndex] != killers[0] and
                moveList.moves[bestIndex] != killers[1]:
                    yield moveList.moves[bestIndex]
            else:
                break

    # hash move
    if position.isPseudoLegal(tryFirstMove):
        yield tryFirstMove

    # init capture moves
    var captureList {.noInit.}: OrderedMoveList
    captureList.numMoves = position.generateCaptures(captureList.moves)
    for i in 0..<captureList.numMoves:
        captureList.movePriorities[i] = position.see(captureList.moves[i])

    # winning captures
    captureList.findBestMoves(minValue = -2*values[pawn])

    # killers
    if doQuiets:
        for i in 0..1:
            if i != 0 and killers[i-1] == killers[i]:
                break
            if position.isPseudoLegal(killers[i]) and killers[i] != tryFirstMove:
                yield killers[i]

    # quiet moves
    if doQuiets:
        var quietList {.noInit.}: OrderedMoveList
        quietList.numMoves = position.generateQuiets(quietList.moves)
        for i in 0..<quietList.numMoves:
            quietList.movePriorities[i] =
                (if historyTable != nil: historyTable[].get(quietList.moves[i], position.us) else: 0.Value)
                
        quietList.findBestMoves()
    
    # losing captures
    captureList.findBestMoves()
        

import types
import move
import position
import movegen
import see
import searchUtils

const zeroHistoryTable = block:
    var h: HistoryTable
    h

iterator moveIterator*(
    position: Position,
    tryFirstMove = noMove,
    historyTable: HistoryTable = zeroHistoryTable,
    killers: array[numKillers, Move] = [noMove, noMove],
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
                
                var isDuplicate = false
                for j in 0..<numKillers:
                    if moveList.moves[bestIndex] == killers[j]:
                        isDuplicate = true
                        break

                if moveList.moves[bestIndex] != tryFirstMove and not isDuplicate:
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
        for i in 0..<numKillers:
            var isDuplicate = false
            for j in 0..<i:
                if killers[j] == killers[i]:
                    isDuplicate = true
                    break
            if position.isPseudoLegal(killers[i]) and killers[i] != tryFirstMove and not isDuplicate:
                yield killers[i]

    # quiet moves
    if doQuiets:
        var quietList {.noInit.}: OrderedMoveList
        quietList.numMoves = position.generateQuiets(quietList.moves)
        for i in 0..<quietList.numMoves:
            quietList.movePriorities[i] = historyTable.get(quietList.moves[i], position.us)
                
        quietList.findBestMoves()
    
    # losing captures
    captureList.findBestMoves()
        

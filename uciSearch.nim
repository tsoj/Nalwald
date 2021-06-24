import position
import types
import hashTable
import atomics
import times
import search
import move
import strformat
import strutils
import math

proc uciSearch*(
    position: Position,
    hashTable: ptr HashTable,
    positionHistory: seq[Position],
    targetDepth: Ply,
    stop: ptr Atomic[bool],
    movesToGo: int16,
    increment, timeLeft: array[white..black, Duration],
    movetime: Duration
): bool =
    try:
        var bestMove = noMove    
        var iteration = 0
        for (value, pv, nodes, passedTime) in timeManagedSearch(
            position,
            hashTable[],
            positionHistory,
            targetDepth,
            stop,
            movesToGo,
            increment, timeLeft,
            movetime
        ):
            doAssert pv.len >= 1
            bestMove = pv[0]

            # uci info
            var scoreString = " score cp " & fmt"{(100*value.int) div values[pawn].int:>4}"
            if abs(value) >= valueCheckmate:
                if value < 0:
                    scoreString = " score mate -"
                else:
                    scoreString = " score mate "
                scoreString &= $(value.plysUntilCheckmate.float32 / 2.0).ceil.int

            let nps: uint64 = 1000*(nodes div (passedTime.inMilliseconds.uint64 + 1))
            echo "info depth ", fmt"{iteration+1:>2}", " time ",fmt"{passedTime.inMilliseconds:>6}", " nodes ", fmt"{nodes:>9}",
                " nps ", fmt"{nps:>7}", " hashfull ", fmt"{hashTable[].hashFull:>5}", scoreString, " pv ", pv

            iteration += 1

        echo "bestmove ", bestMove
    except:
        var errorMessage = "info string " & getCurrentExceptionMsg() & "\n" & getCurrentException().getStackTrace()
        if errorMessage[^1] == '\n':
            errorMessage.delete(errorMessage.len - 1, errorMessage.len - 1)
        errorMessage = errorMessage.replace("\n", "\ninfo string ")
        echo errorMessage
        echo "bestmove ", noMove
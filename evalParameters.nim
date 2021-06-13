import types
import utils
import random
import strformat

type KingPieceSquareTable*[T] = object
    ownKing*: array[a1..h8, array[pawn..king, array[a1..h8, T]]]
    enemyKing*: array[a1..h8, array[pawn..king, array[a1..h8, T]]]

type EvalParametersFloat* = object
    openingKpst*: KingPieceSquareTable[float32]
    endgameKpst*: KingPieceSquareTable[float32]
    openingPassedPawnTable*: array[8, float32]
    endgamePassedPawnTable*: array[8, float32]
    bonusIsolatedPawn*: float32
    bonusBothBishops*: float32
    bonusRookOnOpenFile*: float32
    mobilityMultiplierKnight*: float32
    mobilityMultiplierBishop*: float32
    mobilityMultiplierRook*: float32
    mobilityMultiplierQueen*: float32
    bonusRookSecondRankFromKing*: float32
    kingSafetyMultiplier*: float32

type EvalParameters* = object
    kpst*: array[GamePhase, KingPieceSquareTable[Value]]
    openingPassedPawnTable*: array[8, Value]
    endgamePassedPawnTable*: array[8, Value]
    bonusIsolatedPawn*: Value
    bonusBothBishops*: Value
    bonusRookOnOpenFile*: Value
    mobilityMultiplierKnight*: float32
    mobilityMultiplierBishop*: float32
    mobilityMultiplierRook*: float32
    mobilityMultiplierQueen*: float32
    bonusRookSecondRankFromKing*: Value
    kingSafetyMultiplier*: float32
    

func convert*(a: EvalParametersFloat): ref EvalParameters =
    result = new EvalParameters
    for gamePhase in GamePhase.low..GamePhase.high:
        for kingSquare in a1..h8:
            for piece in pawn..king:
                for square in a1..h8:
                    result.kpst[gamePhase].ownKing[kingSquare][piece][square] =
                        gamePhase.interpolate(
                            forOpening = a.openingKpst.ownKing[kingSquare][piece][square],
                            forEndgame = a.endgameKpst.ownKing[kingSquare][piece][square]
                        ).Value                    
                    result.kpst[gamePhase].enemyKing[kingSquare][piece][square] =
                        gamePhase.interpolate(
                            forOpening = a.openingKpst.enemyKing[kingSquare][piece][square],
                            forEndgame = a.endgameKpst.enemyKing[kingSquare][piece][square]
                        ).Value
    for i in 0..7:
        result.openingPassedPawnTable[i] = a.openingPassedPawnTable[i].Value
        result.endgamePassedPawnTable[i] = a.endgamePassedPawnTable[i].Value
    result.bonusIsolatedPawn = a.bonusIsolatedPawn.Value
    result.bonusBothBishops = a.bonusBothBishops.Value
    result.bonusRookOnOpenFile = a.bonusRookOnOpenFile.Value
    result.mobilityMultiplierKnight = a.mobilityMultiplierKnight
    result.mobilityMultiplierBishop = a.mobilityMultiplierBishop
    result.mobilityMultiplierRook = a.mobilityMultiplierRook
    result.mobilityMultiplierQueen = a.mobilityMultiplierQueen
    result.bonusRookSecondRankFromKing = a.bonusRookSecondRankFromKing.Value
    result.kingSafetyMultiplier = a.kingSafetyMultiplier


func `$`*(evalParameters: EvalParameters): string =
    result = "(\n"
    result &= "  kpst: [\n"
    
    for gamePhase in GamePhase.low..GamePhase.high:
        result &= "    " & $gamePhase & ": KingPieceSquareTable[Value](\n"

        for c in [
            (evalParameters.kpst[gamePhase].ownKing, "ownKing"),
            (evalParameters.kpst[gamePhase].enemyKing, "enemyKing"),
        ]:
            result &= "      " & c[1] & ": [\n"
            
            for kingSquare in a1..h8:
                result &= "        " & $kingSquare & ": [\n"

                for piece in pawn..king:
                    result &= "          " & $piece & ": ["

                    for square in a1..h8:
                        if square.int8 mod 8 == 0:
                            result &= "\n            "
                        result &= fmt"{c[0][kingSquare][piece][square]:>3}" & ".Value"
                        if square != h8:
                            result &= ", "

                    result &= "\n          ],\n"

                result &= "        ],\n"

            result &= "      ],\n"

        result &= "    ),\n"
    
    result &= "  ],\n"


    for c in [
        (evalParameters.openingPassedPawnTable, "openingPassedPawnTable"),
        (evalParameters.endgamePassedPawnTable, "endgamePassedPawnTable")
    ]:
        result &= c[1] & ": ["
        for i in 0..7:
            result &= fmt"{c[0][i]:>3}" & ".Value"
            if i != 7:
                result &= ", "
        result &= "],\n"
    
    result &= "bonusIsolatedPawn: " & fmt"{evalParameters.bonusIsolatedPawn:>3}" & ".Value"
    result &= ",\nbonusBothBishops: " & fmt"{evalParameters.bonusBothBishops:>3}" & ".Value"
    result &= ",\nbonusRookOnOpenFile: " & fmt"{evalParameters.bonusRookOnOpenFile:>3}" & ".Value"
    result &= ",\nmobilityMultiplierKnight: " & fmt"{evalParameters.mobilityMultiplierKnight:>5.2f}"
    result &= ",\nmobilityMultiplierBishop: " & fmt"{evalParameters.mobilityMultiplierBishop:>5.2f}"
    result &= ",\nmobilityMultiplierRook: " & fmt"{evalParameters.mobilityMultiplierRook:>5.2f}"
    result &= ",\nmobilityMultiplierQueen: " & fmt"{evalParameters.mobilityMultiplierQueen:>5.2f}"
    result &= ",\nbonusRookSecondRankFromKing: " & fmt"{evalParameters.bonusRookSecondRankFromKing:>3}" & ".Value"
    result &= ",\nkingSafetyMultiplier: " & fmt"{evalParameters.kingSafetyMultiplier:>5.2f}"

    result &= ")"


func `+=`*(a: var EvalParametersFloat, b: EvalParametersFloat) =
    for kingSquare in a1..h8:
        for piece in pawn..king:
            for square in a1..h8:
                a.openingKpst.ownKing[kingSquare][piece][square] += b.openingKpst.ownKing[kingSquare][piece][square]
                a.openingKpst.enemyKing[kingSquare][piece][square] += b.openingKpst.enemyKing[kingSquare][piece][square]
                a.endgameKpst.ownKing[kingSquare][piece][square] += b.endgameKpst.ownKing[kingSquare][piece][square]
                a.endgameKpst.enemyKing[kingSquare][piece][square] += b.endgameKpst.enemyKing[kingSquare][piece][square]
    for i in 0..7:
        a.openingPassedPawnTable[i] += b.openingPassedPawnTable[i]
        a.endgamePassedPawnTable[i] += b.endgamePassedPawnTable[i]
    a.bonusIsolatedPawn += b.bonusIsolatedPawn
    a.bonusBothBishops += b.bonusBothBishops
    a.bonusRookOnOpenFile += b.bonusRookOnOpenFile
    a.mobilityMultiplierKnight += b.mobilityMultiplierKnight
    a.mobilityMultiplierBishop += b.mobilityMultiplierBishop
    a.mobilityMultiplierRook += b.mobilityMultiplierRook
    a.mobilityMultiplierQueen += b.mobilityMultiplierQueen
    a.bonusRookSecondRankFromKing += b.bonusRookSecondRankFromKing
    a.kingSafetyMultiplier += b.kingSafetyMultiplier

func `*=`*(a: var EvalParametersFloat, b: float32) =
    for kingSquare in a1..h8:
        for piece in pawn..king:
            for square in a1..h8:
                a.openingKpst.ownKing[kingSquare][piece][square] *= b
                a.openingKpst.enemyKing[kingSquare][piece][square] *= b
                a.endgameKpst.ownKing[kingSquare][piece][square] *= b
                a.endgameKpst.enemyKing[kingSquare][piece][square] *= b
    for i in 0..7:
        a.openingPassedPawnTable[i] *= b
        a.endgamePassedPawnTable[i] *= b
    a.bonusIsolatedPawn *= b
    a.bonusBothBishops *= b
    a.bonusRookOnOpenFile *= b
    a.mobilityMultiplierKnight *= b
    a.mobilityMultiplierBishop *= b
    a.mobilityMultiplierRook *= b
    a.mobilityMultiplierQueen *= b
    a.bonusRookSecondRankFromKing *= b
    a.kingSafetyMultiplier *= b

func `-`*(a: EvalParametersFloat): EvalParametersFloat =
    for kingSquare in a1..h8:
        for piece in pawn..king:
            for square in a1..h8:
                result.openingKpst.ownKing[kingSquare][piece][square] = -a.openingKpst.ownKing[kingSquare][piece][square]
                result.openingKpst.enemyKing[kingSquare][piece][square] = -a.openingKpst.enemyKing[kingSquare][piece][square]
                result.endgameKpst.ownKing[kingSquare][piece][square] = -a.endgameKpst.ownKing[kingSquare][piece][square]
                result.endgameKpst.enemyKing[kingSquare][piece][square] = -a.endgameKpst.enemyKing[kingSquare][piece][square]
    for i in 0..7:
        result.openingPassedPawnTable[i] = -a.openingPassedPawnTable[i]
        result.endgamePassedPawnTable[i] = -a.endgamePassedPawnTable[i]
    result.bonusIsolatedPawn = -a.bonusIsolatedPawn
    result.bonusBothBishops = -a.bonusBothBishops
    result.bonusRookOnOpenFile = -a.bonusRookOnOpenFile
    result.mobilityMultiplierKnight = -a.mobilityMultiplierKnight
    result.mobilityMultiplierBishop = -a.mobilityMultiplierBishop
    result.mobilityMultiplierRook = -a.mobilityMultiplierRook
    result.mobilityMultiplierQueen = -a.mobilityMultiplierQueen
    result.bonusRookSecondRankFromKing = -a.bonusRookSecondRankFromKing
    result.kingSafetyMultiplier = -a.kingSafetyMultiplier

proc randomEvalParametersFloat*(evalParameters: var EvalParametersFloat, max = 5.0) =

    template r: float32 = rand(max) - max/2.0

    for kingSquare in a1..h8:
        for piece in pawn..king:
            for square in a1..h8:
                evalParameters.openingKpst.ownKing[kingSquare][piece][square] += r
                evalParameters.openingKpst.enemyKing[kingSquare][piece][square] += r
                evalParameters.endgameKpst.ownKing[kingSquare][piece][square] += r
                evalParameters.endgameKpst.enemyKing[kingSquare][piece][square] += r
    for i in 0..7:
        evalParameters.openingPassedPawnTable[i] += r
        evalParameters.endgamePassedPawnTable[i] += r
    evalParameters.bonusIsolatedPawn += r
    evalParameters.bonusBothBishops += r
    evalParameters.bonusRookOnOpenFile += r
    evalParameters.mobilityMultiplierKnight += r
    evalParameters.mobilityMultiplierBishop += r
    evalParameters.mobilityMultiplierRook += r
    evalParameters.mobilityMultiplierQueen += r
    evalParameters.bonusRookSecondRankFromKing += r
    evalParameters.kingSafetyMultiplier += r

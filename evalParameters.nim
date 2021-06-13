import types
import random
import strformat

type KingPieceSquareTable*[T] = object
    ownKing*: array[a1..h8, array[pawn..king, array[a1..h8, T]]]
    enemyKing*: array[a1..h8, array[pawn..king, array[a1..h8, T]]]


type EvalParametersTemplate[ValueType] = object
    openingKpst*: KingPieceSquareTable[ValueType]
    endgameKpst*: KingPieceSquareTable[ValueType]
    openingPassedPawnTable*: array[8, ValueType]
    endgamePassedPawnTable*: array[8, ValueType]
    bonusIsolatedPawn*: ValueType
    bonusBothBishops*: ValueType
    bonusRookOnOpenFile*: ValueType
    mobilityMultiplierKnight*: float32
    mobilityMultiplierBishop*: float32
    mobilityMultiplierRook*: float32
    mobilityMultiplierQueen*: float32
    bonusRookSecondRankFromKing*: ValueType
    kingSafetyMultiplier*: float32

type EvalParametersFloat* = EvalParametersTemplate[float32]

type EvalParameters* = EvalParametersTemplate[Value]
    

func convert*(a: EvalParametersFloat): EvalParameters =
    for kingSquare in a1..h8:
        for piece in pawn..king:
            for square in a1..h8:
                result.openingKpst.ownKing[kingSquare][piece][square] =
                    a.openingKpst.ownKing[kingSquare][piece][square].Value
                result.openingKpst.enemyKing[kingSquare][piece][square] =
                    a.openingKpst.enemyKing[kingSquare][piece][square].Value
                result.endgameKpst.ownKing[kingSquare][piece][square] =
                    a.endgameKpst.ownKing[kingSquare][piece][square].Value
                result.endgameKpst.enemyKing[kingSquare][piece][square] =
                    a.endgameKpst.enemyKing[kingSquare][piece][square].Value
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

    for (kpstName, kpst) in [("openingKpst", evalParameters.openingKpst), ("endgameKpst", evalParameters.endgameKpst)]:
        result &= "  " & kpstName & ": KingPieceSquareTable[Value](\n"
        
        for (kingName, pst) in [("ownKing", kpst.ownKing), ("enemyKing", kpst.enemyKing)]:
            result &= "    " & kingName & ": [\n"

            for kingSquare in a1..h8:
                result &= "      " & $kingSquare & ": [\n"

                for piece in pawn..king:
                    result &= "        " & $piece & ": ["

                    for square in a1..h8:
                        if square.int8 mod 8 == 0:
                            result &= "\n          "
                        result &= fmt"{pst[kingSquare][piece][square]:>3}" & ".Value"
                        if square != h8:
                            result &= ", "

                    result &= "\n        ],\n"

                result &= "      ],\n"

            result &= "    ],\n"
        
        result &= "  ),\n"


    for (passedPawnTable, name) in [
        (evalParameters.openingPassedPawnTable, "openingPassedPawnTable"),
        (evalParameters.endgamePassedPawnTable, "endgamePassedPawnTable")
    ]:
        result &= "  " & name & ": ["
        for i in 0..7:
            result &= fmt"{passedPawnTable[i]:>3}" & ".Value"
            if i != 7:
                result &= ", "
        result &= "],\n"
    
    result &= "  bonusIsolatedPawn: " & fmt"{evalParameters.bonusIsolatedPawn:>3}" & ".Value"
    result &= ",\n  bonusBothBishops: " & fmt"{evalParameters.bonusBothBishops:>3}" & ".Value"
    result &= ",\n  bonusRookOnOpenFile: " & fmt"{evalParameters.bonusRookOnOpenFile:>3}" & ".Value"
    result &= ",\n  mobilityMultiplierKnight: " & fmt"{evalParameters.mobilityMultiplierKnight:>5.2f}"
    result &= ",\n  mobilityMultiplierBishop: " & fmt"{evalParameters.mobilityMultiplierBishop:>5.2f}"
    result &= ",\n  mobilityMultiplierRook: " & fmt"{evalParameters.mobilityMultiplierRook:>5.2f}"
    result &= ",\n  mobilityMultiplierQueen: " & fmt"{evalParameters.mobilityMultiplierQueen:>5.2f}"
    result &= ",\n  bonusRookSecondRankFromKing: " & fmt"{evalParameters.bonusRookSecondRankFromKing:>3}" & ".Value"
    result &= ",\n  kingSafetyMultiplier: " & fmt"{evalParameters.kingSafetyMultiplier:>5.2f}"

    result &= "\n)"


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

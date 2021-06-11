import types
import pieceSquareTable
import utils
import random
import strformat

type EvalParameters* = object
# TODO: make it simple and have only an opning and engame table and not all gamephases
    pstOpeningOwnKing*: array[a1..h8, array[pawn..king, array[a1..h8, float]]]
    pstOpeningEnemyKing*: array[a1..h8, array[pawn..king, array[a1..h8, float]]]
    pstEndgameOwnKing*: array[a1..h8, array[pawn..king, array[a1..h8, float]]]
    pstEndgameEnemyKing*: array[a1..h8, array[pawn..king, array[a1..h8, float]]]
    openingPassedPawnTable*: array[8, float]
    endgamePassedPawnTable*: array[8, float]
    bonusIsolatedPawn*: float
    bonusBothBishops*: float
    bonusRookOnOpenFile*: float
    mobilityMultiplierKnight*: float
    mobilityMultiplierBishop*: float
    mobilityMultiplierRook*: float
    mobilityMultiplierQueen*: float
    bonusRookSecondRankFromKing*: float
    kingSafetyMultiplier*: float


func `$`*(evalParameters: EvalParameters): string =
    result = "(\n"
    for c in [
        (evalParameters.pstOpeningOwnKing, "pstOpeningOwnKing"),
        (evalParameters.pstEndgameOwnKing, "pstEndgameOwnKing"),
        (evalParameters.pstOpeningEnemyKing, "pstOpeningEnemyKing"),
        (evalParameters.pstEndgameEnemyKing, "pstEndgameEnemyKing")
    ]:
        result &= c[1] & ": ["
        for kingSquare in a1..h8:
            result &= $kingSquare & ": ["
            for piece in pawn..king:
                result &= "\n  " & $piece & ": ["
                for square in a1..h8:
                    if square.int8 mod 8 == 0:
                        result &= "\n      "
                    result &= fmt"{c[0][kingSquare][piece][square]:>5.2f}"
                    if square != h8:
                        result &= ", "
                result &= "\n  ], "
            result &= "\n],\n"
        result &= "\n], "


    for c in [
        (evalParameters.openingPassedPawnTable, "openingPassedPawnTable"),
        (evalParameters.endgamePassedPawnTable, "endgamePassedPawnTable")
    ]:
        result &= c[1] & ": ["
        for i in 0..7:
            result &= fmt"{c[0][i]:>5.2f}"
            if i != 7:
                result &= ", "
        result &= "],\n"
    
    result &= "bonusIsolatedPawn: " & fmt"{evalParameters.bonusIsolatedPawn:>5.2f}"
    result &= ",\nbonusBothBishops: " & fmt"{evalParameters.bonusBothBishops:>5.2f}"
    result &= ",\nbonusRookOnOpenFile: " & fmt"{evalParameters.bonusRookOnOpenFile:>5.2f}"
    result &= ",\nmobilityMultiplierKnight: " & fmt"{evalParameters.mobilityMultiplierKnight:>5.2f}"
    result &= ",\nmobilityMultiplierBishop: " & fmt"{evalParameters.mobilityMultiplierBishop:>5.2f}"
    result &= ",\nmobilityMultiplierRook: " & fmt"{evalParameters.mobilityMultiplierRook:>5.2f}"
    result &= ",\nmobilityMultiplierQueen: " & fmt"{evalParameters.mobilityMultiplierQueen:>5.2f}"
    result &= ",\nbonusRookSecondRankFromKing: " & fmt"{evalParameters.bonusRookSecondRankFromKing:>5.2f}"
    result &= ",\nkingSafetyMultiplier: " & fmt"{evalParameters.kingSafetyMultiplier:>5.2f}"

    result &= ")"


func `+=`*(a: var EvalParameters, b: EvalParameters) =
    for kingSquare in a1..h8:
        for piece in pawn..king:
            for square in a1..h8:
                a.pstOpeningOwnKing[kingSquare][piece][square] += b.pstOpeningOwnKing[kingSquare][piece][square]
                a.pstOpeningEnemyKing[kingSquare][piece][square] += b.pstOpeningEnemyKing[kingSquare][piece][square]
                a.pstEndgameOwnKing[kingSquare][piece][square] += b.pstEndgameOwnKing[kingSquare][piece][square]
                a.pstEndgameEnemyKing[kingSquare][piece][square] += b.pstEndgameEnemyKing[kingSquare][piece][square]
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

func `*=`*(a: var EvalParameters, b: float) =
    for kingSquare in a1..h8:
        for piece in pawn..king:
            for square in a1..h8:
                a.pstOpeningOwnKing[kingSquare][piece][square] *= b
                a.pstOpeningEnemyKing[kingSquare][piece][square] *= b
                a.pstEndgameOwnKing[kingSquare][piece][square] *= b
                a.pstEndgameEnemyKing[kingSquare][piece][square] *= b
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

func `-`*(a: EvalParameters): EvalParameters =
    for kingSquare in a1..h8:
        for piece in pawn..king:
            for square in a1..h8:
                result.pstOpeningOwnKing[kingSquare][piece][square] = -a.pstOpeningOwnKing[kingSquare][piece][square]
                result.pstOpeningEnemyKing[kingSquare][piece][square] = -a.pstOpeningEnemyKing[kingSquare][piece][square]
                result.pstEndgameOwnKing[kingSquare][piece][square] = -a.pstEndgameOwnKing[kingSquare][piece][square]
                result.pstEndgameEnemyKing[kingSquare][piece][square] = -a.pstEndgameEnemyKing[kingSquare][piece][square]
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

const defaultEvalParameters* = block:
    var defaultEvalParameters = EvalParameters(
        openingPassedPawnTable: [0.0, 0.0, 0.0, 10.0, 15.0, 20.0, 45.0, 0.0],
        endgamePassedPawnTable: [0.0, 20.0, 30.0, 40.0, 60.0, 100.0, 120.0, 0.0],
        bonusIsolatedPawn: -10.0,
        bonusBothBishops: 10.0,
        bonusRookOnOpenFile: 5.0,
        mobilityMultiplierKnight: 2.0,
        mobilityMultiplierBishop: 3.0,
        mobilityMultiplierRook: 4.0,
        mobilityMultiplierQueen: 2.0,
        bonusRookSecondRankFromKing: -10.0,
        kingSafetyMultiplier: 2.5
    )
    for kingSquare in a1..h8:
        for piece in pawn..king:
            for square in a1..h8:
                defaultEvalParameters.pstOpeningOwnKing[kingSquare][piece][square] = openingPst[piece][square].float
                defaultEvalParameters.pstOpeningEnemyKing[kingSquare][piece][square] = openingPst[piece][square].float
                defaultEvalParameters.pstEndgameOwnKing[kingSquare][piece][square] = endgamePst[piece][square].float
                defaultEvalParameters.pstEndgameEnemyKing[kingSquare][piece][square] = endgamePst[piece][square].float
    defaultEvalParameters

proc randomEvalParameters*(max = 10.0): EvalParameters =

    template r: float = rand(max) - max/2.0
    for i in 0..7:
        result.openingPassedPawnTable[i] = r
        result.endgamePassedPawnTable[i] = r
    result.bonusIsolatedPawn = r
    result.bonusBothBishops = r
    result.bonusRookOnOpenFile = r
    result.mobilityMultiplierKnight = r
    result.mobilityMultiplierBishop = r
    result.mobilityMultiplierRook = r
    result.mobilityMultiplierQueen = r
    result.bonusRookSecondRankFromKing = r
    result.kingSafetyMultiplier = r

    for kingSquare in a1..h8:
        for piece in pawn..king:
            for square in a1..h8:
                result.pstOpeningOwnKing[kingSquare][piece][square] = r
                result.pstOpeningEnemyKing[kingSquare][piece][square] = r
                result.pstEndgameOwnKing[kingSquare][piece][square] = r
                result.pstEndgameEnemyKing[kingSquare][piece][square] = r


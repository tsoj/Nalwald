import types
import random
import strformat

type OpeningOrEndGame* = enum
    opening, endgame

type OurKingOrEnemyKing* = enum
    ourKing, enemyKing

type EvalParametersTemplate[ValueType] = object
    pst*: array[opening..endgame, array[ourKing..enemyKing, array[a1..h8, array[pawn..king, array[a1..h8, ValueType]]]]]
    openingPassedPawnTable*: array[8, ValueType]
    endgamePassedPawnTable*: array[8, ValueType]
    bonusIsolatedPawn*: ValueType
    bonusPawnHasTwoNeighbors*: ValueType
    bonusBothBishops*: ValueType
    bonusRookOnOpenFile*: ValueType
    mobilityMultiplierKnight*: float32
    mobilityMultiplierBishop*: float32
    mobilityMultiplierRook*: float32
    mobilityMultiplierQueen*: float32
    bonusBishopTargetingKingArea*: ValueType
    bonusRookTargetingKingArea*: ValueType
    bonusQueenTargetingKingArea*: ValueType
    bonusRookSecondRankFromKing*: ValueType
    kingSafetyMultiplier*: float32

type EvalParametersFloat* = EvalParametersTemplate[float32]

type EvalParameters* = EvalParametersTemplate[Value]
    
func convert*(a: EvalParametersFloat): EvalParameters =
    for phase in opening..endgame:
        for whoseKing in ourKing..enemyKing:
            for kingSquare in a1..h8:
                for piece in pawn..king:
                    for square in a1..h8:
                        result.pst[phase][whoseKing][kingSquare][piece][square] =
                            a.pst[phase][whoseKing][kingSquare][piece][square].Value
    for i in 0..7:
        result.openingPassedPawnTable[i] = a.openingPassedPawnTable[i].Value
        result.endgamePassedPawnTable[i] = a.endgamePassedPawnTable[i].Value
    result.bonusIsolatedPawn = a.bonusIsolatedPawn.Value
    result.bonusPawnHasTwoNeighbors = a.bonusPawnHasTwoNeighbors.Value
    result.bonusBothBishops = a.bonusBothBishops.Value
    result.bonusRookOnOpenFile = a.bonusRookOnOpenFile.Value
    result.mobilityMultiplierKnight = a.mobilityMultiplierKnight
    result.mobilityMultiplierBishop = a.mobilityMultiplierBishop
    result.mobilityMultiplierRook = a.mobilityMultiplierRook
    result.mobilityMultiplierQueen = a.mobilityMultiplierQueen
    result.bonusBishopTargetingKingArea = a.bonusBishopTargetingKingArea.Value
    result.bonusRookTargetingKingArea = a.bonusRookTargetingKingArea.Value
    result.bonusQueenTargetingKingArea = a.bonusQueenTargetingKingArea.Value
    result.bonusRookSecondRankFromKing = a.bonusRookSecondRankFromKing.Value
    result.kingSafetyMultiplier = a.kingSafetyMultiplier


func `$`*(a: EvalParameters): string =
    result = "(\n"

    result &= "    pst: [\n"
    
    for phase in opening..endgame:
        result &= "        " & $phase & ": [\n"

        for whoseKing in ourKing..enemyKing: 
            result &= "            " & $whoseKing & ": [\n"

            for kingSquare in a1..h8:
                result &= "                " & $kingSquare & ": [\n"

                for piece in pawn..king:
                    result &= "                    " & $piece & ": ["

                    for square in a1..h8:
                        if square.int8 mod 8 == 0:
                            result &= "\n                        "
                        result &= fmt"{a.pst[phase][whoseKing][kingSquare][piece][square]:>3}" & ".Value"
                        if square != h8:
                            result &= ", "

                    result &= "\n                    ],\n"

                result &= "                ],\n"
        
            result &= "            ],\n"

        result &= "        ],\n"

    result &= "    ],\n"

    for (passedPawnTable, name) in [
        (a.openingPassedPawnTable, "openingPassedPawnTable"),
        (a.endgamePassedPawnTable, "endgamePassedPawnTable")
    ]:
        result &= "    " & name & ": ["
        for i in 0..7:
            result &= fmt"{passedPawnTable[i]:>3}" & ".Value"
            if i != 7:
                result &= ", "
        result &= "],\n"
    
    result &= "    bonusIsolatedPawn: " & fmt"{a.bonusIsolatedPawn:>3}" & ".Value"
    result &= ",\n    bonusPawnHasTwoNeighbors: " & fmt"{a.bonusPawnHasTwoNeighbors:>3}" & ".Value"
    result &= ",\n    bonusBothBishops: " & fmt"{a.bonusBothBishops:>3}" & ".Value"
    result &= ",\n    bonusRookOnOpenFile: " & fmt"{a.bonusRookOnOpenFile:>3}" & ".Value"
    result &= ",\n    mobilityMultiplierKnight: " & fmt"{a.mobilityMultiplierKnight:>5.2f}"
    result &= ",\n    mobilityMultiplierBishop: " & fmt"{a.mobilityMultiplierBishop:>5.2f}"
    result &= ",\n    mobilityMultiplierRook: " & fmt"{a.mobilityMultiplierRook:>5.2f}"
    result &= ",\n    mobilityMultiplierQueen: " & fmt"{a.mobilityMultiplierQueen:>5.2f}"
    result &= ",\n    bonusBishopTargetingKingArea: " & fmt"{a.bonusBishopTargetingKingArea:>3}" & ".Value"
    result &= ",\n    bonusRookTargetingKingArea: " & fmt"{a.bonusRookTargetingKingArea:>3}" & ".Value"
    result &= ",\n    bonusQueenTargetingKingArea: " & fmt"{a.bonusQueenTargetingKingArea:>3}" & ".Value"
    result &= ",\n    bonusRookSecondRankFromKing: " & fmt"{a.bonusRookSecondRankFromKing:>3}" & ".Value"
    result &= ",\n    kingSafetyMultiplier: " & fmt"{a.kingSafetyMultiplier:>5.2f}"

    result &= "\n)"


func `+=`*(a: var EvalParametersFloat, b: EvalParametersFloat) =
    for phase in opening..endgame:
        for whoseKing in ourKing..enemyKing:
            for kingSquare in a1..h8:
                for piece in pawn..king:
                    for square in a1..h8:
                        a.pst[phase][whoseKing][kingSquare][piece][square] +=
                            b.pst[phase][whoseKing][kingSquare][piece][square]
    for i in 0..7:
        a.openingPassedPawnTable[i] += b.openingPassedPawnTable[i]
        a.endgamePassedPawnTable[i] += b.endgamePassedPawnTable[i]
    a.bonusIsolatedPawn += b.bonusIsolatedPawn
    a.bonusPawnHasTwoNeighbors += b.bonusPawnHasTwoNeighbors
    a.bonusBothBishops += b.bonusBothBishops
    a.bonusRookOnOpenFile += b.bonusRookOnOpenFile
    a.mobilityMultiplierKnight += b.mobilityMultiplierKnight
    a.mobilityMultiplierBishop += b.mobilityMultiplierBishop
    a.mobilityMultiplierRook += b.mobilityMultiplierRook
    a.mobilityMultiplierQueen += b.mobilityMultiplierQueen
    a.bonusBishopTargetingKingArea += b.bonusBishopTargetingKingArea
    a.bonusRookTargetingKingArea += b.bonusRookTargetingKingArea
    a.bonusQueenTargetingKingArea += b.bonusQueenTargetingKingArea
    a.bonusRookSecondRankFromKing += b.bonusRookSecondRankFromKing
    a.kingSafetyMultiplier += b.kingSafetyMultiplier

func `*=`*(a: var EvalParametersFloat, b: float32) =
    for phase in opening..endgame:
        for whoseKing in ourKing..enemyKing:
            for kingSquare in a1..h8:
                for piece in pawn..king:
                    for square in a1..h8:
                        a.pst[phase][whoseKing][kingSquare][piece][square] *= b
    for i in 0..7:
        a.openingPassedPawnTable[i] *= b
        a.endgamePassedPawnTable[i] *= b
    a.bonusIsolatedPawn *= b
    a.bonusPawnHasTwoNeighbors *= b
    a.bonusBothBishops *= b
    a.bonusRookOnOpenFile *= b
    a.mobilityMultiplierKnight *= b
    a.mobilityMultiplierBishop *= b
    a.mobilityMultiplierRook *= b
    a.mobilityMultiplierQueen *= b
    a.bonusBishopTargetingKingArea *= b
    a.bonusRookTargetingKingArea *= b
    a.bonusQueenTargetingKingArea *= b
    a.bonusRookSecondRankFromKing *= b
    a.kingSafetyMultiplier *= b

proc randomEvalParametersFloat*(a: var EvalParametersFloat, max = 5.0) =

    template r: float32 = rand(max) - max/2.0

    for phase in opening..endgame:
        for whoseKing in ourKing..enemyKing:
            for kingSquare in a1..h8:
                for piece in pawn..king:
                    for square in a1..h8:
                        a.pst[phase][whoseKing][kingSquare][piece][square] += r
    for i in 0..7:
        a.openingPassedPawnTable[i] += r
        a.endgamePassedPawnTable[i] += r
    a.bonusIsolatedPawn += r
    a.bonusPawnHasTwoNeighbors += r
    a.bonusBothBishops += r
    a.bonusRookOnOpenFile += r
    a.mobilityMultiplierKnight += r
    a.mobilityMultiplierBishop += r
    a.mobilityMultiplierRook += r
    a.mobilityMultiplierQueen += r
    a.bonusBishopTargetingKingArea += r
    a.bonusRookTargetingKingArea += r
    a.bonusQueenTargetingKingArea += r
    a.bonusRookSecondRankFromKing += r
    a.kingSafetyMultiplier += r

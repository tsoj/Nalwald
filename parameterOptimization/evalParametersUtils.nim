import ../evalParameters
import ../types
import random
import strformat

func convertTemplate[InValueType, OutValueType](a: EvalParametersTemplate[InValueType]): EvalParametersTemplate[OutValueType] =
    for phase in opening..endgame:
        for whoseKing in ourKing..enemyKing:
            for kingSquare in a1..h8:
                for piece in pawn..king:
                    for square in a1..h8:
                        result.pst[phase][whoseKing][kingSquare][piece][square] =
                            a.pst[phase][whoseKing][kingSquare][piece][square].OutValueType
    for i in 0..7:
        result.passedPawnTable[opening][i] = a.passedPawnTable[opening][i].OutValueType
        result.passedPawnTable[endgame][i] = a.passedPawnTable[endgame][i].OutValueType
    result.bonusIsolatedPawn = a.bonusIsolatedPawn.OutValueType
    result.bonusPawnHasTwoNeighbors = a.bonusPawnHasTwoNeighbors.OutValueType
    result.bonusBothBishops = a.bonusBothBishops.OutValueType
    result.bonusRookOnOpenFile = a.bonusRookOnOpenFile.OutValueType
    result.mobilityMultiplierKnight = a.mobilityMultiplierKnight
    result.mobilityMultiplierBishop = a.mobilityMultiplierBishop
    result.mobilityMultiplierRook = a.mobilityMultiplierRook
    result.mobilityMultiplierQueen = a.mobilityMultiplierQueen
    result.bonusBishopTargetingKingArea = a.bonusBishopTargetingKingArea.OutValueType
    result.bonusRookTargetingKingArea = a.bonusRookTargetingKingArea.OutValueType
    result.bonusQueenTargetingKingArea = a.bonusQueenTargetingKingArea.OutValueType
    result.kingSafetyMultiplier = a.kingSafetyMultiplier

func convert*(a: EvalParameters): EvalParametersFloat =
    a.convertTemplate[:Value, float32]

func convert*(a: EvalParametersFloat): EvalParameters =
    a.convertTemplate[:float32, Value]

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


    result &= "    " & "passedPawnTable: [\n"
    for phase in opening..endgame:
        result &= "        " & $phase & ": ["
        for i in 0..7:
            result &= fmt"{a.passedPawnTable[phase][i]:>3}" & ".Value, "
        result &= "],\n"
    result &= "    ],\n"
    
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
        a.passedPawnTable[opening][i] += b.passedPawnTable[opening][i]
        a.passedPawnTable[endgame][i] += b.passedPawnTable[endgame][i]
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
    a.kingSafetyMultiplier += b.kingSafetyMultiplier

func `*=`*(a: var EvalParametersFloat, b: float32) =
    for phase in opening..endgame:
        for whoseKing in ourKing..enemyKing:
            for kingSquare in a1..h8:
                for piece in pawn..king:
                    for square in a1..h8:
                        a.pst[phase][whoseKing][kingSquare][piece][square] *= b
    for i in 0..7:
        a.passedPawnTable[opening][i] *= b
        a.passedPawnTable[endgame][i] *= b
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
        a.passedPawnTable[opening][i] += r
        a.passedPawnTable[endgame][i] += r
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
    a.kingSafetyMultiplier += r

proc randomEvalParametersFloat*(max = 5.0): EvalParametersFloat =
    result.randomEvalParametersFloat(max)
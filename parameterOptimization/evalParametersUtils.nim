import ../evalParameters
import ../types
import random
import strformat

func `$`*(a: EvalParameters): string =
    result = "[\n"

    for phase in Phase:

        result &= "    " & $phase & ": SinglePhaseEvalParametersTemplate[Value](\n"

        result &= "    pst: [\n"

        for whoseKing in ourKing..enemyKing: 
            result &= "            " & $whoseKing & ": [\n"

            for kingSquare in a1..h8:
                result &= "                " & $kingSquare & ": [\n"

                for piece in pawn..king:
                    result &= "                    " & $piece & ": ["

                    for square in a1..h8:
                        if square.int8 mod 8 == 0:
                            result &= "\n                        "
                        result &= fmt"{a[phase].pst[whoseKing][kingSquare][piece][square]:>3}" & ".Value"
                        if square != h8:
                            result &= ", "

                    result &= "\n                    ],\n"

                result &= "                ],\n"
        
            result &= "            ],\n"

        result &= "    ],\n"
        
        result &= "    " & "passedPawnTable: ["
        for i in 0..7:
            result &= fmt"{a[phase].passedPawnTable[i]:>3}" & ".Value, "
        result &= "],\n"
        
        result &= "    bonusIsolatedPawn: " & fmt"{a[phase].bonusIsolatedPawn:>3}" & ".Value"
        result &= ",\n    bonusPawnHasTwoNeighbors: " & fmt"{a[phase].bonusPawnHasTwoNeighbors:>3}" & ".Value"
        result &= ",\n    bonusBothBishops: " & fmt"{a[phase].bonusBothBishops:>3}" & ".Value"
        result &= ",\n    bonusRookOnOpenFile: " & fmt"{a[phase].bonusRookOnOpenFile:>3}" & ".Value"
        result &= ",\n    mobilityMultiplierKnight: " & fmt"{a[phase].mobilityMultiplierKnight:>5.2f}"
        result &= ",\n    mobilityMultiplierBishop: " & fmt"{a[phase].mobilityMultiplierBishop:>5.2f}"
        result &= ",\n    mobilityMultiplierRook: " & fmt"{a[phase].mobilityMultiplierRook:>5.2f}"
        result &= ",\n    mobilityMultiplierQueen: " & fmt"{a[phase].mobilityMultiplierQueen:>5.2f}"
        result &= ",\n    bonusBishopTargetingKingArea: " & fmt"{a[phase].bonusBishopTargetingKingArea:>3}" & ".Value"
        result &= ",\n    bonusRookTargetingKingArea: " & fmt"{a[phase].bonusRookTargetingKingArea:>3}" & ".Value"
        result &= ",\n    bonusQueenTargetingKingArea: " & fmt"{a[phase].bonusQueenTargetingKingArea:>3}" & ".Value"
        result &= ",\n    kingSafetyMultiplier: " & fmt"{a[phase].kingSafetyMultiplier:>5.2f}"
        result &= "\n    ),\n"

    result &= "\n]"

func opTemplate(a: var EvalParametersFloat, b: EvalParametersFloat, op: proc(a: var float, b: float)) =
    for phase in Phase:
        for whoseKing in ourKing..enemyKing:
            for kingSquare in a1..h8:
                for piece in pawn..king:
                    for square in a1..h8:
                        op(
                            a[phase].pst[whoseKing][kingSquare][piece][square],
                            b[phase].pst[whoseKing][kingSquare][piece][square]
                        )
        for i in 0..7:
            op(a[phase].passedPawnTable[i], b[phase].passedPawnTable[i])
        op(a[phase].bonusIsolatedPawn, b[phase].bonusIsolatedPawn)
        op(a[phase].bonusPawnHasTwoNeighbors, b[phase].bonusPawnHasTwoNeighbors)
        op(a[phase].bonusBothBishops, b[phase].bonusBothBishops)
        op(a[phase].bonusRookOnOpenFile, b[phase].bonusRookOnOpenFile)
        op(a[phase].mobilityMultiplierKnight, b[phase].mobilityMultiplierKnight)
        op(a[phase].mobilityMultiplierBishop, b[phase].mobilityMultiplierBishop)
        op(a[phase].mobilityMultiplierRook, b[phase].mobilityMultiplierRook)
        op(a[phase].mobilityMultiplierQueen, b[phase].mobilityMultiplierQueen)
        op(a[phase].bonusBishopTargetingKingArea, b[phase].bonusBishopTargetingKingArea)
        op(a[phase].bonusRookTargetingKingArea, b[phase].bonusRookTargetingKingArea)
        op(a[phase].bonusQueenTargetingKingArea, b[phase].bonusQueenTargetingKingArea)
        op(a[phase].kingSafetyMultiplier, b[phase].kingSafetyMultiplier)

func `+=`*(a: var EvalParametersFloat, b: EvalParametersFloat) =
    opTemplate(a, b, proc(a: var float, b: float) = a += b)

func `*=`*(a: var EvalParametersFloat, b: EvalParametersFloat) =
    opTemplate(a, b, proc(a: var float, b: float) = a *= b)

func `*=`*(a: var EvalParametersFloat, b: float) =
    for phase in Phase:
        a[phase] *= b


proc randomEvalParametersFloat*(a: var EvalParametersFloat, max = 5.0) =

    template r: float = rand(max) - max/2.0

    for phase in Phase:
        for whoseKing in ourKing..enemyKing:
            for kingSquare in a1..h8:
                for piece in pawn..king:
                    for square in a1..h8:
                        a[phase].pst[whoseKing][kingSquare][piece][square] += r
        for i in 0..7:
            a[phase].passedPawnTable[i] += r
        a[phase].bonusIsolatedPawn += r
        a[phase].bonusPawnHasTwoNeighbors += r
        a[phase].bonusBothBishops += r
        a[phase].bonusRookOnOpenFile += r
        a[phase].mobilityMultiplierKnight += r
        a[phase].mobilityMultiplierBishop += r
        a[phase].mobilityMultiplierRook += r
        a[phase].mobilityMultiplierQueen += r
        a[phase].bonusBishopTargetingKingArea += r
        a[phase].bonusRookTargetingKingArea += r
        a[phase].bonusQueenTargetingKingArea += r
        a[phase].kingSafetyMultiplier += r

proc randomEvalParametersFloat*(max = 5.0): EvalParametersFloat =
    result.randomEvalParametersFloat(max)
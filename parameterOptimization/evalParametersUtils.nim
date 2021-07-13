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
        
        result &= "    passedPawnTable: ["
        for i in 0..7:
            result &= fmt"{a[phase].passedPawnTable[i]:>3}" & ".Value, "
        result &= "],\n"

        result &= "    mobilityMultiplier: ["
        for piece in knight..queen:
            result &= $piece & ": " & fmt"{a[phase].mobilityMultiplier[piece]:>5.2f}" & ", "
        result &= "],\n"

        result &= "    bonusTargetingKingArea: ["
        for piece in bishop..queen:
            result &= $piece & ": " & fmt"{a[phase].passedPawnTable[i]:>3}" & ".Value, "
        result &= "],\n"

        result &= "    bonusIsolatedPawn: " & fmt"{a[phase].bonusIsolatedPawn:>3}" & ".Value"
        result &= ",\n    bonusPawnHasTwoNeighbors: " & fmt"{a[phase].bonusPawnHasTwoNeighbors:>3}" & ".Value"
        result &= ",\n    bonusBothBishops: " & fmt"{a[phase].bonusBothBishops:>3}" & ".Value"
        result &= ",\n    bonusRookOnOpenFile: " & fmt"{a[phase].bonusRookOnOpenFile:>3}" & ".Value"
        result &= ",\n    kingSafetyMultiplier: " & fmt"{a[phase].kingSafetyMultiplier:>5.2f}"
        result &= "\n    ),\n"

    result &= "]\n"

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
        for piece in knight..queen:
            op(a[phase].mobilityMultiplier[piece], b[phase].mobilityMultiplier[piece])        
        for piece in bishop..queen:
            op(a[phase].bonusTargetingKingArea[piece], b[phase].bonusTargetingKingArea[piece])
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
        for piece in knight..queen:
            a[phase].mobilityMultiplier[piece] += r
        for piece in bishop..queen:
            a.bonusTargetingKingArea[piece] += r
        a[phase].kingSafetyMultiplier += r

proc randomEvalParametersFloat*(max = 5.0): EvalParametersFloat =
    result.randomEvalParametersFloat(max)
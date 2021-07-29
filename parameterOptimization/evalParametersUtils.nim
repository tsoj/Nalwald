import
    ../evalParameters,
    ../types,
    strformat

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

        result &= "        ],\n"
        
        result &= "        passedPawnTable: ["
        for i in 0..7:
            result &= fmt"{a[phase].passedPawnTable[i]:>3}" & ".Value, "
        result &= "],\n"

        result &= "        mobilityMultiplier: ["
        for piece in knight..queen:
            result &= $piece & ": " & fmt"{a[phase].mobilityMultiplier[piece]:>5.2f}" & ", "
        result &= "],\n"

        result &= "        bonusTargetingKingArea: ["
        for piece in bishop..queen:
            result &= $piece & ": " & fmt"{a[phase].bonusTargetingKingArea[piece]:>3}" & ".Value, "
        result &= "],\n"

        result &= "        bonusIsolatedPawn: " & fmt"{a[phase].bonusIsolatedPawn:>3}" & ".Value,\n"
        result &= "        bonusPawnHasTwoNeighbors: " & fmt"{a[phase].bonusPawnHasTwoNeighbors:>3}" & ".Value,\n"
        result &= "        bonusKnightAttackingPiece: " & fmt"{a[phase].bonusKnightAttackingPiece:>3}" & ".Value,\n"
        result &= "        bonusBothBishops: " & fmt"{a[phase].bonusBothBishops:>3}" & ".Value,\n"
        result &= "        bonusRookOnOpenFile: " & fmt"{a[phase].bonusRookOnOpenFile:>3}" & ".Value,\n"
        result &= "        kingSafetyMultiplier: " & fmt"{a[phase].kingSafetyMultiplier:>5.2f}" & "\n"

        result &= "    ),\n"

    result &= "]\n"

func convertTemplate[InValueType, OutValueType](
    a: SinglePhaseEvalParametersTemplate[InValueType]
): SinglePhaseEvalParametersTemplate[OutValueType] =
    for whoseKing in ourKing..enemyKing:
        for kingSquare in a1..h8:
            for piece in pawn..king:
                for square in a1..h8:
                    result.pst[whoseKing][kingSquare][piece][square] =
                        a.pst[whoseKing][kingSquare][piece][square].OutValueType
    for i in 0..7:
        result.passedPawnTable[i] = a.passedPawnTable[i].OutValueType
    result.bonusIsolatedPawn = a.bonusIsolatedPawn.OutValueType
    result.bonusPawnHasTwoNeighbors = a.bonusPawnHasTwoNeighbors.OutValueType
    result.bonusKnightAttackingPiece = a.bonusKnightAttackingPiece.OutValueType
    result.bonusBothBishops = a.bonusBothBishops.OutValueType
    result.bonusRookOnOpenFile = a.bonusRookOnOpenFile.OutValueType
    result.mobilityMultiplier = a.mobilityMultiplier
    for piece in bishop..queen:
        result.bonusTargetingKingArea[piece] = a.bonusTargetingKingArea[piece].OutValueType
    result.kingSafetyMultiplier = a.kingSafetyMultiplier

func convertTemplate[InValueType, OutValueType](a: EvalParametersTemplate[InValueType]): EvalParametersTemplate[OutValueType] =
    for phase in Phase:
        result[phase] = a[phase].convertTemplate[:InValueType, OutValueType]

func convert*(a: EvalParameters): EvalParametersFloat =
    a.convertTemplate[:Value, float]

func convert*(a: EvalParametersFloat): EvalParameters =
    a.convertTemplate[:float, Value]

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
        op(a[phase].bonusKnightAttackingPiece, b[phase].bonusKnightAttackingPiece)
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
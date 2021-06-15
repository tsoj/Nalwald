import ../evalParameters
import ../types
import random
import strformat

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
    a.kingSafetyMultiplier += r

const startingEvalParametersFloat* = block:
    var startingEvalParametersFloat = EvalParametersFloat(
        openingPassedPawnTable: [0.0'f32, 0.0'f32, 0.0'f32, 10.0'f32, 15.0'f32, 20.0'f32, 45.0'f32, 0.0'f32],
        endgamePassedPawnTable: [0.0'f32, 20.0'f32, 30.0'f32, 40.0'f32, 60.0'f32, 100.0'f32, 120.0'f32, 0.0'f32],
        bonusIsolatedPawn: -10.0,
        bonusPawnHasTwoNeighbors: 1.0,
        bonusBothBishops: 10.0,
        bonusRookOnOpenFile: 5.0,
        mobilityMultiplierKnight: 2.0,
        mobilityMultiplierBishop: 3.0,
        mobilityMultiplierRook: 4.0,
        mobilityMultiplierQueen: 2.0,
        bonusBishopTargetingKingArea: 1.0,
        bonusRookTargetingKingArea: 1.0,
        bonusQueenTargetingKingArea: 1.0,
        kingSafetyMultiplier: 2.5
    )

    const openingPst: array[pawn..king, array[a1..h8, int]] =
        [
            pawn:
            [
                0, 0, 0, 0, 0, 0, 0, 0,
                45, 45, 45, 45, 45, 45, 45, 45,
                10, 10, 20, 30, 30, 20, 10, 10,
                5, 5, 10, 25, 25, 10, 5, 5,
                0, 0, 0, 20, 20, 0, 0, 0,
                5, -5, -10, 0, 0, -10, -5, 5,
                5, 10, 10, -20, -20, 10, 10, 5,
                0, 0, 0, 0, 0, 0, 0, 0
            ],
            knight:
            [
                -50, -40, -30, -30, -30, -30, -40, -50,
                -40, -20, 0, 0, 0, 0, -20, -40,
                -30, 0, 10, 15, 15, 10, 0, -30,
                -30, 5, 15, 20, 20, 15, 5, -30,
                -30, 0, 15, 20, 20, 15, 0, -30,
                -30, 5, 10, 15, 15, 10, 5, -30,
                -40, -20, 0, 5, 5, 0, -20, -40,
                -50, -40, -30, -30, -30, -30, -40, -50
            ],
            bishop:
            [
                -20, -10, -10, -10, -10, -10, -10, -20,
                -10, 0, 0, 0, 0, 0, 0, -10,
                -10, 0, 5, 10, 10, 5, 0, -10,
                -10, 5, 5, 10, 10, 5, 5, -10,
                -10, 0, 10, 10, 10, 10, 0, -10,
                -10, 10, 10, 10, 10, 10, 10, -10,
                -10, 5, 0, 0, 0, 0, 5, -10,
                -20, -10, -10, -10, -10, -10, -10, -20
            ],
            rook:
            [
                0, 0, 0, 0, 0, 0, 0, 0,
                5, 10, 10, 10, 10, 10, 10, 5,
                -5, 0, 0, 0, 0, 0, 0, -5,
                -5, 0, 0, 0, 0, 0, 0, -5,
                -5, 0, 0, 0, 0, 0, 0, -5,
                -5, 0, 0, 0, 0, 0, 0, -5,
                -5, 0, 0, 0, 0, 0, 0, -5,
                0, 0, 0, 5, 5, 0, 0, 0
            ],
            queen:
            [
                -20, -10, -10, -5, -5, -10, -10, -20,
                -10, 0, 0, 0, 0, 0, 0, -10,
                -10, 0, 5, 5, 5, 5, 0, -10,
                -5, 0, 5, 5, 5, 5, 0, -5,
                0, 0, 5, 5, 5, 5, 0, -5,
                -10, 5, 5, 5, 5, 5, 0, -10,
                -10, 0, 5, 0, 0, 0, 0, -10,
                -20, -10, -10, -5, -5, -10, -10, -20
            ],
            king:
            [
                -30, -40, -40, -50, -50, -40, -40, -30,
                -30, -40, -40, -50, -50, -40, -40, -30,
                -30, -40, -40, -50, -50, -40, -40, -30,
                -30, -40, -40, -50, -50, -40, -40, -30,
                -20, -30, -30, -40, -40, -30, -30, -20,
                -10, -20, -20, -20, -20, -20, -20, -10,
                20, 20, 0, 0, 0, 0, 20, 20,
                20, 30, 10, 0, 0, 10, 30, 20
            ],
        ]
    const endgamePst: array[pawn..king, array[a1..h8, int]] =
        [
            pawn:
            [
                0, 0, 0, 0, 0, 0, 0, 0,
                90, 90, 90, 90, 90, 90, 90, 90,
                30, 30, 40, 45, 45, 40, 40, 30,
                20, 20, 20, 25, 25, 20, 20, 20,
                0, 0, 0, 20, 20, 0, 0, 0,
                -5, -5, -10, -10, -10, -10, -5, -5,
                -15, -15, -15, -20, -20, -15, -15, -15,
                0, 0, 0, 0, 0, 0, 0, 0
            ],
            knight:
            [
                -50, -40, -30, -30, -30, -30, -40, -50,
                -40, -20, 0, 0, 0, 0, -20, -40,
                -30, 0, 10, 15, 15, 10, 0, -30,
                -30, 5, 15, 20, 20, 15, 5, -30,
                -30, 0, 15, 20, 20, 15, 0, -30,
                -30, 5, 10, 15, 15, 10, 5, -30,
                -40, -20, 0, 5, 5, 0, -20, -40,
                -50, -40, -30, -30, -30, -30, -40, -50
            ],
            bishop:
            [
                -20, -10, -10, -10, -10, -10, -10, -20,
                -10, 0, 0, 0, 0, 0, 0, -10,
                -10, 0, 5, 10, 10, 5, 0, -10,
                -10, 5, 5, 10, 10, 5, 5, -10,
                -10, 0, 10, 10, 10, 10, 0, -10,
                -10, 10, 10, 10, 10, 10, 10, -10,
                -10, 5, 0, 0, 0, 0, 5, -10,
                -20, -10, -10, -10, -10, -10, -10, -20
            ],
            rook:
            [
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 5, 5, 5, 5, 5, 5, 0,
                -5, 0, 0, 0, 0, 0, 0, -5,
                -5, 0, 0, 0, 0, 0, 0, -5,
                -5, 0, 0, 0, 0, 0, 0, -5,
                -5, 0, 0, 0, 0, 0, 0, -5,
                -5, 0, 0, 0, 0, 0, 0, -5,
                0, 0, 0, 0, 0, 0, 0, 0
            ],
            queen:
            [
                -20, -10, -10, -5, -5, -10, -10, -20,
                -10, 0, 0, 0, 0, 0, 0, -10,
                -10, 0, 5, 5, 5, 5, 0, -10,
                -5, 0, 5, 5, 5, 5, 0, -5,
                0, 0, 5, 5, 5, 5, 0, -5,
                -10, 0, 5, 5, 5, 5, 0, -10,
                -10, 0, 0, 0, 0, 0, 0, -10,
                -20, -10, -10, -5, -5, -10, -10, -20
            ],
            king:
            [
                -50, -40, -30, -20, -20, -30, -40, -50,
                -30, -20, -10, 0, 0, -10, -20, -30,
                -30, -10, 20, 30, 30, 20, -10, -30,
                -30, -10, 30, 40, 40, 30, -10, -30,
                -30, -10, 30, 40, 40, 30, -10, -30,
                -30, -10, 20, 30, 30, 20, -10, -30,
                -30, -30, 0, 0, 0, 0, -30, -30,
                -50, -30, -30, -30, -30, -30, -30, -50
            ],
        ]

    for whoseKing in ourKing..enemyKing:
        for kingSquare in a1..h8:
            for piece in pawn..king:
                for square in a1..h8:
                    startingEvalParametersFloat.pst[opening][whoseKing][kingSquare][piece][square] =
                        openingPst[piece][square].float32 / 2.0
                    startingEvalParametersFloat.pst[endgame][whoseKing][kingSquare][piece][square] =
                        endgamePst[piece][square].float32 / 2.0
    startingEvalParametersFloat

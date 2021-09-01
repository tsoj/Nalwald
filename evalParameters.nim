import types

type Phase* = enum
    opening, endgame

type OurKingOrEnemyKing* = enum
    ourKing, enemyKing

type SinglePhaseEvalParametersTemplate*[ValueType] = object
    pieceValues*: array[pawn..king, ValueType]
    pst*: array[ourKing..enemyKing, array[a1..h8, array[pawn..king, array[a1..h8, ValueType]]]]
    passedPawnTable*: array[8, ValueType]
    bonusIsolatedPawn*: ValueType
    bonusPawnHasTwoNeighbors*: ValueType
    bonusKnightAttackingPiece*: ValueType
    bonusBothBishops*: ValueType
    bonusRookOnOpenFile*: ValueType
    bonusMobility*: array[knight..queen, array[32, ValueType]]
    bonusTargetingKingArea*: array[bishop..queen, ValueType]
    bonusAttackingKing*: array[bishop..queen, ValueType]
    bonusKingSafety*: array[32, ValueType]#float#TODO: change this to a table

type EvalParametersTemplate*[ValueType] = array[Phase, SinglePhaseEvalParametersTemplate[ValueType]]

type EvalParametersFloat* = EvalParametersTemplate[float]

type EvalParameters* = EvalParametersTemplate[Value]

func `*=`*(a: var SinglePhaseEvalParametersTemplate[float], b: float) =
    for piece in pawn..king:
        a.pieceValues[piece] *= b
    for whoseKing in ourKing..enemyKing:
        for kingSquare in a1..h8:
            for piece in pawn..king:
                for square in a1..h8:
                    a.pst[whoseKing][kingSquare][piece][square] *= b
    for i in 0..7:
        a.passedPawnTable[i] *= b
    a.bonusIsolatedPawn *= b
    a.bonusPawnHasTwoNeighbors *= b
    a.bonusKnightAttackingPiece *= b
    a.bonusBothBishops *= b
    a.bonusRookOnOpenFile *= b
    for piece in knight..queen:
        for i in 0..<32:
            a.bonusMobility[piece][i] *= b
    for piece in bishop..queen:
        a.bonusTargetingKingArea[piece] *= b
        a.bonusAttackingKing[piece] *= b
    for i in 0..<32:
        a.bonusKingSafety[i] *= b
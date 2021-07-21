import types

type Phase* = enum
    opening, endgame

type OurKingOrEnemyKing* = enum
    ourKing, enemyKing

type SinglePhaseEvalParametersTemplate*[ValueType] = object
    pst*: array[ourKing..enemyKing, array[a1..h8, array[pawn..king, array[a1..h8, ValueType]]]]
    passedPawnTable*: array[8, ValueType]
    bonusIsolatedPawn*: ValueType
    bonusPawnHasTwoNeighbors*: ValueType
    bonusKnightAttackingPiece*: ValueType
    bonusBothBishops*: ValueType
    bonusRookOnOpenFile*: ValueType
    mobilityMultiplier*: array[knight..queen, float]
    bonusTargetingKingArea*: array[bishop..queen, ValueType]
    kingSafetyMultiplier*: float

type EvalParametersTemplate[ValueType] = array[Phase, SinglePhaseEvalParametersTemplate[ValueType]]

type EvalParametersFloat* = EvalParametersTemplate[float]

type EvalParameters* = EvalParametersTemplate[Value]

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

func `*=`*(a: var SinglePhaseEvalParametersTemplate[float], b: float) =
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
        a.mobilityMultiplier[piece] *= b
    for piece in bishop..queen:
        a.bonusTargetingKingArea[piece] *= b
    a.kingSafetyMultiplier *= b
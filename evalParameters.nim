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
    bonusBothBishops*: ValueType
    bonusRookOnOpenFile*: ValueType
    mobilityMultiplierKnight*: float
    mobilityMultiplierBishop*: float
    mobilityMultiplierRook*: float
    mobilityMultiplierQueen*: float
    bonusBishopTargetingKingArea*: ValueType
    bonusRookTargetingKingArea*: ValueType
    bonusQueenTargetingKingArea*: ValueType
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
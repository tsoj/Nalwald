import types

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
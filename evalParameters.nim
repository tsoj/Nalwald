import types
import pieceSquareTable
import utils

type EvalParametersTemplate[ValueType] = object
    pst*: array[GamePhase, array[pawn..king, array[a1..h8, ValueType]]]
    openingPassedPawnTable*: array[8, ValueType]
    endgamePassedPawnTable*: array[8, ValueType]
    bonusIsolatedPawn*: ValueType
    bonusBothBishops*: ValueType
    bonusRookOnOpenFile*: ValueType
    mobilityMultiplierKnight*: float32
    mobilityMultiplierBishop*: float32
    mobilityMultiplierRook*: float32
    mobilityMultiplierQueen*: float32
    bonusRookSecondRankFromKing*: ValueType
    kingSafetyMultiplier*: float32

type EvalParameters* = EvalParametersTemplate[Value]
type EvalParametersFloat32* = EvalParametersTemplate[float32]

const defaultEvalParameters* = block:
    var defaultEvalParameters = EvalParameters(
        openingPassedPawnTable: [0.Value, 0.Value, 0.Value, 10.Value, 15.Value, 20.Value, 45.Value, 0.Value],
        endgamePassedPawnTable: [0.Value, 20.Value, 30.Value, 40.Value, 60.Value, 100.Value, 120.Value, 0.Value],
        bonusIsolatedPawn: -10.Value,
        bonusBothBishops: 10.Value,
        bonusRookOnOpenFile: 5.Value,
        mobilityMultiplierKnight: 2.0,
        mobilityMultiplierBishop: 3.0,
        mobilityMultiplierRook: 4.0,
        mobilityMultiplierQueen: 2.0,
        bonusRookSecondRankFromKing: -10.Value,
        kingSafetyMultiplier: 2.5
    )
    for piece in pawn..king:
        for square in a1..h8:
            for gamePhase in GamePhase.low..GamePhase.high:
                defaultEvalParameters.pst[gamePhase][piece][square] =
                    gamePhase.interpolate(openingPst[piece][square].Value, endgamePst[piece][square].Value)
    defaultEvalParameters

func convert*[InValueType, OutValueType](
    evalParameters: EvalParametersTemplate[InValueType]
): EvalParametersTemplate[OutValueType] =
    for piece in pawn..king:
        for square in a1..h8:
            for gamePhase in GamePhase.low..GamePhase.high:
                result.pst[gamePhase][piece][square] = evalParameters.pst[gamePhase][piece][square].OutValueType
    for i in 0..7:
        result.openingPassedPawnTable[i] = evalParameters.openingPassedPawnTable[i].OutValueType
        result.endgamePassedPawnTable[i] = evalParameters.endgamePassedPawnTable[i].OutValueType
    result.bonusIsolatedPawn = evalParameters.bonusIsolatedPawn.OutValueType
    result.bonusBothBishops = evalParameters.bonusBothBishops.OutValueType
    result.bonusRookOnOpenFile = evalParameters.bonusRookOnOpenFile.OutValueType
    result.mobilityMultiplierKnight = evalParameters.mobilityMultiplierKnight
    result.mobilityMultiplierBishop = evalParameters.mobilityMultiplierBishop
    result.mobilityMultiplierRook = evalParameters.mobilityMultiplierRook
    result.mobilityMultiplierQueen = evalParameters.mobilityMultiplierQueen
    result.bonusRookSecondRankFromKing = evalParameters.bonusRookSecondRankFromKing.OutValueType
    result.kingSafetyMultiplier = evalParameters.kingSafetyMultiplier

func `+=`*[ValueType](a: var EvalParametersTemplate[ValueType], b: EvalParametersTemplate[ValueType]) =
    for piece in pawn..king:
        for square in a1..h8:
            for gamePhase in GamePhase.low..GamePhase.high:
                a.pst[gamePhase][piece][square] += b.pst[gamePhase][piece][square]
    for i in 0..7:
        a.openingPassedPawnTable[i] += b.openingPassedPawnTable[i]
        a.endgamePassedPawnTable[i] += b.endgamePassedPawnTable[i]
    a.bonusIsolatedPawn += b.bonusIsolatedPawn
    a.bonusBothBishops += b.bonusBothBishops
    a.bonusRookOnOpenFile += b.bonusRookOnOpenFile
    a.mobilityMultiplierKnight += b.mobilityMultiplierKnight
    a.mobilityMultiplierBishop += b.mobilityMultiplierBishop
    a.mobilityMultiplierRook += b.mobilityMultiplierRook
    a.mobilityMultiplierQueen += b.mobilityMultiplierQueen
    a.bonusRookSecondRankFromKing += b.bonusRookSecondRankFromKing
    a.kingSafetyMultiplier += b.kingSafetyMultiplier

func `*=`*[ValueType](a: var EvalParametersTemplate[ValueType], b: float32) =
    for piece in pawn..king:
        for square in a1..h8:
            for gamePhase in GamePhase.low..GamePhase.high:
                a.pst[gamePhase][piece][square] *= b
    for i in 0..7:
        a.openingPassedPawnTable[i] *= b
        a.endgamePassedPawnTable[i] *= b
    a.bonusIsolatedPawn *= b
    a.bonusBothBishops *= b
    a.bonusRookOnOpenFile *= b
    a.mobilityMultiplierKnight *= b
    a.mobilityMultiplierBishop *= b
    a.mobilityMultiplierRook *= b
    a.mobilityMultiplierQueen *= b
    a.bonusRookSecondRankFromKing *= b
    a.kingSafetyMultiplier *= b

func `-`*[ValueType](a: EvalParametersTemplate[ValueType]): EvalParametersTemplate[ValueType] =
    for piece in pawn..king:
        for square in a1..h8:
            for gamePhase in GamePhase.low..GamePhase.high:
                result.pst[gamePhase][piece][square] = -a.pst[gamePhase][piece][square]
    for i in 0..7:
        result.openingPassedPawnTable[i] = -a.openingPassedPawnTable[i]
        result.endgamePassedPawnTable[i] = -a.endgamePassedPawnTable[i]
    result.bonusIsolatedPawn = -a.bonusIsolatedPawn
    result.bonusBothBishops = -a.bonusBothBishops
    result.bonusRookOnOpenFile = -a.bonusRookOnOpenFile
    result.mobilityMultiplierKnight = -a.mobilityMultiplierKnight
    result.mobilityMultiplierBishop = -a.mobilityMultiplierBishop
    result.mobilityMultiplierRook = -a.mobilityMultiplierRook
    result.mobilityMultiplierQueen = -a.mobilityMultiplierQueen
    result.bonusRookSecondRankFromKing = -a.bonusRookSecondRankFromKing
    result.kingSafetyMultiplier = -a.kingSafetyMultiplier

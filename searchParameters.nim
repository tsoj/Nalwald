import
    types,
    utils,
    evaluation

#TODO maybe use this also for evalParameters (refactor it)
type
    PhaseType[T] = object
        forOpening, forEndgame: T
    PhaseValue* = PhaseType[Value]
    PhasePly* = PhaseType[Ply]
    PhaseInt* = PhaseType[int]

func toPhaseType*[T](t: T): PhaseType[T] =
    PhaseType[T](forOpening: t, forEndgame: t)

func pt*[T](forOpening, forEndgame: T): PhaseType[T] =
    PhaseType[T](forOpening: forOpening, forEndgame: forEndgame)

func get*(phaseValue: PhaseType, gamePhase: GamePhase): auto =
    gamePhase.interpolate(forOpening = phaseValue.forOpening, forEndgame = phaseValue.forEndgame)


type SearchParameters* = object
    futilityMargins*: array[0.Ply..6.Ply, PhaseValue]
    hashResultFutilityMargin*: PhaseValue
    nullMoveSubtractor*: PhasePly
    nullMoveDivider*: PhasePly
    lmrHalfLife*: PhaseInt
    deltaMargin*: PhaseValue
    failHighDeltaMargin*: PhaseValue

static: doAssert pawn.value == 100.cp

const defaultSearchParams* = SearchParameters(
    futilityMargins: [
        0.Ply: pt(100.cp, 70.cp),
        1.Ply: pt(150.cp, 100.cp),
        2.Ply: pt(250.cp, 170.cp),
        3.Ply: pt(400.cp, 280.cp),
        4.Ply: pt(650.cp, 450.cp),
        5.Ply: pt(900.cp, 630.cp),
        6.Ply: pt(1200.cp, 840.cp)
    ],
    hashResultFutilityMargin: 200.cp.toPhaseType,
    nullMoveSubtractor: 3.Ply.toPhaseType,
    nullMoveDivider: 4.Ply.toPhaseType,
    lmrHalfLife: 35.toPhaseType,
    deltaMargin: 150.cp.toPhaseType,
    failHighDeltaMargin: 50.cp.toPhaseType
)

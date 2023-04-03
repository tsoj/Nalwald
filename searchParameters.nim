import
    types,
    utils,
    evaluation

import std/[
    options,
    strformat,
    tables
]

#TODO maybe use this also for evalParameters (refactor it)
type
    PhaseType[T] = array[opening..endgame, T]
    PhaseValue* = PhaseType[Value]
    PhasePly* = PhaseType[Ply]
    PhaseInt* = PhaseType[int]

func toPhaseType*[T](t: T): PhaseType[T] =
    [opening: t, endgame: t]

func pt*[T](forOpening, forEndgame: T): PhaseType[T] =
    [opening: forOpening, endgame: forEndgame]

func get*(phaseValue: PhaseType, gamePhase: GamePhase): auto =
    gamePhase.interpolate(forOpening = phaseValue[opening], forEndgame = phaseValue[endgame])

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

func strictlyChange[T](a: T, multiplier: float): T =

    doAssert multiplier != 1.0, "Must be different from 1 to be able to strictly change a value"

    var c = a.float * multiplier

    if c.BiggestInt in (T.low.BiggestInt .. T.high.BiggestInt) and c.T != a:
        return c.T

    if multiplier < 1.0 and T.low + 1 <= a:
        return a - 1.T

    if multiplier > 1.0 and T.high - 1 >= a:
        return a + 1.T

    doAssert a in [T.high, T.low]
    doAssert false, fmt"Can't strictly change value {a} with multiplier {multiplier}, as it would get out of bounds"



func getChangesFutilityMargins(searchParams: SearchParameters): seq[SearchParameters] =

    for phase in opening..endgame:

        result.add searchParams
        for a in result[^1].futilityMargins.mitems:
            if a[phase] < Value.high:
                a[phase] = a[phase].strictlyChange(1.1)

        result.add searchParams
        for a in result[^1].futilityMargins.mitems:
            if a[phase] > Value.low:
                a[phase] = a[phase].strictlyChange(0.9)

template getChanges(searchParams: SearchParameters, multiplier: float, field: untyped): seq[SearchParameters] =
    doAssert multiplier > 1.0, "Must be different greater than 1 to be able to strictly change a value"
    var r: seq[SearchParameters]
    for phase in opening..endgame:

        if searchParams.field[phase] > searchParams.field[phase].type.low:
            r.add searchParams
            r[^1].field[phase] = searchParams.field[phase].strictlyChange(1.0/multiplier)
        
        if searchParams.field[phase] < searchParams.field[phase].type.high:
            r.add searchParams
            r[^1].field[phase] = searchParams.field[phase].strictlyChange(multiplier)
    r

func getChangesHashResultFutilityMargin(searchParams: SearchParameters): seq[SearchParameters] =
    searchParams.getChanges(1.1, hashResultFutilityMargin)

func getChangesNullMoveSubtractor(searchParams: SearchParameters): seq[SearchParameters] =
    searchParams.getChanges(1.1, nullMoveSubtractor)

func getChangesNullMoveDivider(searchParams: SearchParameters): seq[SearchParameters] =
    searchParams.getChanges(1.1, nullMoveDivider)

func getChangesLmrHalfLife(searchParams: SearchParameters): seq[SearchParameters] =
    searchParams.getChanges(1.1, lmrHalfLife)

func getChangesDeltaMargin(searchParams: SearchParameters): seq[SearchParameters] =
    searchParams.getChanges(1.1, deltaMargin)

func getChangesFailHighDeltaMargin(searchParams: SearchParameters): seq[SearchParameters] =
    searchParams.getChanges(1.1, failHighDeltaMargin)

func getChanges*(searchParams: SearchParameters): seq[SearchParameters] =

    const specializedFunctions = {
        # "futilityMargins": getChangesFutilityMargins,
        # "hashResultFutilityMargin": getChangesHashResultFutilityMargin,
        # "nullMoveSubtractor": getChangesNullMoveSubtractor,
        "nullMoveDivider": getChangesNullMoveDivider,
        # "lmrHalfLife": getChangesLmrHalfLife,
        # "deltaMargin": getChangesDeltaMargin,
        # "failHighDeltaMargin": getChangesFailHighDeltaMargin
    }.toTable

    for name, field in fieldPairs(searchParams):
        when name in specializedFunctions:
            static: doAssert(
                name in specializedFunctions,
                "Need to have a function for every field in SearchParameters. This is just to make sure that no search param has been forgotten."
            )
            result.add specializedFunctions[name](searchParams)
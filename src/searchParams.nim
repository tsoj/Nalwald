import types

import std/[tables, macros, typetraits, json, strformat]

const floatQuantizer = 1_000.0

type ParamEntry = object
  address: ptr int
  min: int
  max: int
  step: int

var paramTable: OrderedTable[string, ParamEntry]

proc getVarName(name: NimNode): NimNode =
  parseExpr($toStrLit(name) & "Var")

proc getVarString(name: NimNode): NimNode =
  parseExpr("\"" & $toStrLit(name) & "\"")

func getAsInt[T](a: T): int =
  when distinctBase(T) is SomeFloat:
    (a.float * floatQuantizer).int
  else:
    a.int

macro addParam[T](name: untyped, default, min, max, step: T): untyped =
  let
    varName: NimNode = getVarName(name)
    varString: NimNode = getVarString(name)
  quote:
    var `varName`: int = `default`.getAsInt

    paramTable[`varString`] = ParamEntry(
      address: addr `varName`,
      min: `min`.getAsInt,
      max: `max`.getAsInt,
      step: `step`.getAsInt,
    )

    func `name`*(): auto =
      type R = typeof(`default`)
      {.cast(noSideEffect).}:
        when distinctBase(R) is SomeFloat:
          R(R(`varName`).float / floatQuantizer)
        else:
          R(`varName`)

proc hasSearchOption*(name: string): bool =
  name in paramTable

proc setSearchOption*(name: string, value: int) =
  if name in paramTable:
    let allowedRange = paramTable[name].min .. paramTable[name].max
    if value notin allowedRange:
      raise newException(
        KeyError,
        "Parameter '" & name & "' doesn't allow values outside " & $allowedRange &
          " but value is '" & $value & "'",
      )
    paramTable[name].address[] = value
  else:
    raise newException(KeyError, "Parameter '" & name & "' doesn't exist")

proc printUciSearchParams*() =
  for name, param in paramTable:
    echo "option name ",
      name,
      " type spin default ",
      param.address[],
      " min ",
      param.min,
      " max ",
      param.max

addParam(deltaMargin, default = 92, min = 30, max = 300, step = 10)
addParam(failHighDeltaMargin, default = 69, min = 10, max = 200, step = 10)
addParam(aspirationWindowStartingOffset, default = 9, min = 2, max = 100, step = 2)
addParam(aspirationWindowMultiplier, default = 1.9, min = 1.1, max = 10.0, step = 0.2)
addParam(futilityReductionDiv, default = 83, min = 10, max = 500, step = 10)
addParam(hashResultFutilityMarginMul, default = 280, min = 50, max = 1000, step = 10)
addParam(nullMoveDepthSub, default = 3.Ply, min = 0.Ply, max = 10.Ply, step = 1.Ply)
addParam(nullMoveDepthDiv, default = 3, min = 1, max = 15, step = 1)
addParam(lmrDepthHalfLife, default = 36, min = 5, max = 60, step = 5)
addParam(lmrDepthSub, default = 1.Ply, min = 0.Ply, max = 5.Ply, step = 1.Ply)
addParam(iirMinDepth, default = 4.Ply, min = 0.Ply, max = 12.Ply, step = 1.Ply)
addParam(minMoveCounterLmr, default = 5, min = 1, max = 15, step = 1)
addParam(minMoveCounterFutility, default = 2, min = 1, max = 10, step = 1)
addParam(
  maxHistoryTableValue, default = 104000, min = 1000, max = 10000000, step = 50000
)
addParam(historyTableBadMoveDivider, default = 8.5, min = 1.0, max = 100.0, step = 10.0)
addParam(historyTableCounterMul, default = 72.0, min = 1.0, max = 200.0, step = 20.0)
addParam(historyTableShrinkDiv, default = 1.9, min = 1.1, max = 10.0, step = 0.5)

proc getWeatherFactoryConfig*(): string =
  result = "{"
  for name, param in paramTable:
    result &= "\"" & name & "\": {"
    result &=
      fmt"""
          "value": {param.address[]},
          "min_value": {param.min},
          "max_value": {param.max},
          "step": {param.step}
          """
    result &= "},"
  result &= "}"
  result = result.parseJson.pretty

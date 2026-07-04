import std/[times, strformat, strutils, math]

import types

import nimchess

type Seconds* = distinct float

func `$`*(a: Seconds): string =
  $a.float & " s"

func high*(T: typedesc[Seconds]): Seconds =
  float.high.Seconds
func low*(T: typedesc[Seconds]): Seconds =
  float.low.Seconds

func `==`*(a, b: Seconds): bool {.borrow.}
func `<=`*(a, b: Seconds): bool {.borrow.}
func `<`*(a, b: Seconds): bool {.borrow.}

func `-`*(a, b: Seconds): Seconds {.borrow.}
func `+`*(a, b: Seconds): Seconds {.borrow.}
func `*`*(a: Seconds, b: SomeNumber): Seconds =
  Seconds(a.float * b.float)
func `*`*(a: SomeNumber, b: Seconds): Seconds =
  Seconds(a.float * b.float)
func `/`*(a: Seconds, b: SomeNumber): Seconds =
  Seconds(a.float / b.float)

func `+=`*(a: var Seconds, b: Seconds) =
  a = a + b
func `-=`*(a: var Seconds, b: Seconds) =
  a = a - b
func `*=`*(a: var Seconds, b: SomeNumber) =
  a = a * b
func `/=`*(a: var Seconds, b: SomeNumber) =
  a = a / b

func secondsSince1970*(): Seconds =
  {.cast(noSideEffect).}:
    epochTime().Seconds

func stringForHuman*(time: Seconds): string =
  let s = time.int
  if time < 1.Seconds:
    fmt"{int(time * 1000.0)} ms"
  elif time < 10.Seconds:
    fmt"{time.float:.1f} s"
  elif time < 60.Seconds:
    fmt"{s} s"
  elif time < 3600.Seconds:
    fmt"{(s mod 3600) div 60:02}:{s mod 60:02} min"
  else:
    fmt"{s div 3600}:{(s mod 3600) div 60:02} h"

func stringForHuman*(n: SomeNumber): string =
  let x = n.float
  if x >= 1e9:
    (x / 1e9).formatFloat(ffDecimal, 2) & "G"
  elif x >= 1e6:
    (x / 1e6).formatFloat(ffDecimal, 2) & "M"
  elif x >= 1e3:
    (x / 1e3).formatFloat(ffDecimal, 1) & "k"
  else:
    x.formatFloat(ffDecimal, 1)

func toScore*(value: Value): Score =
  if value.abs < valueCheckmate:
    Score(kind: skCp, cp: int(value * 100))
  else:
    Score(
      kind: skMate,
      mate: (if value > 0: 1 else: -1) * ceilDiv(plysUntilCheckmate(value.abs), 2),
    )

func `$`*(value: Value): string =
  $value.toScore

static:
  doAssert $(9.Ply.checkmateValue) == "mate 5"
  doAssert $(-(1.Ply.checkmateValue)) == "mate -1"
  doAssert $(2.Ply.checkmateValue) == "mate 1"
  doAssert $(-(3.Ply.checkmateValue)) == "mate -2"
  doAssert $(maxPly.Ply.checkmateValue) == "mate 100"

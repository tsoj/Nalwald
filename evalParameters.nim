import types
import pieceSquareTable
import utils
import random
import strformat

type EvalParameters* = object
# TODO: make it simple and have only an opning and engame table and not all gamephases
    pstOpening*: array[pawn..king, array[a1..h8, float]]
    pstEndgame*: array[pawn..king, array[a1..h8, float]]
    openingPassedPawnTable*: array[8, float]
    endgamePassedPawnTable*: array[8, float]
    bonusIsolatedPawn*: float
    bonusBothBishops*: float
    bonusRookOnOpenFile*: float
    mobilityMultiplierKnight*: float
    mobilityMultiplierBishop*: float
    mobilityMultiplierRook*: float
    mobilityMultiplierQueen*: float
    bonusRookSecondRankFromKing*: float
    kingSafetyMultiplier*: float


func `$`*(evalParameters: EvalParameters): string =
    result = "(\n"
    for c in [(evalParameters.pstOpening, "pstOpening"), (evalParameters.pstEndgame, "pstEndgame")]:
        result &= c[1] & ":["
        for piece in pawn..king:
            result &= "\n  " & $piece & ":["
            for square in a1..h8:
                if square.int8 mod 8 == 0:
                    result &= "\n      "
                result &= fmt"{c[0][piece][square]:>5.2f}"# $(c[0][piece][square].formatFloat(ffDecimal, 2))
                if square != h8:
                    result &= ", "
            result &= "\n  ], "
        result &= "\n],\n"
    for c in [
        (evalParameters.openingPassedPawnTable, "openingPassedPawnTable"),
        (evalParameters.endgamePassedPawnTable, "endgamePassedPawnTable")
    ]:
        result &= c[1] & ": ["
        for i in 0..7:
            result &= fmt"{c[0][i]:>5.2f}"
            if i != 7:
                result &= ", "
        result &= "],\n"
    
    result &= "bonusIsolatedPawn: " & fmt"{evalParameters.bonusIsolatedPawn:>5.2f}"
    result &= ",\nbonusBothBishops: " & fmt"{evalParameters.bonusBothBishops:>5.2f}"
    result &= ",\nbonusRookOnOpenFile: " & fmt"{evalParameters.bonusRookOnOpenFile:>5.2f}"
    result &= ",\nmobilityMultiplierKnight: " & fmt"{evalParameters.mobilityMultiplierKnight:>5.2f}"
    result &= ",\nmobilityMultiplierBishop: " & fmt"{evalParameters.mobilityMultiplierBishop:>5.2f}"
    result &= ",\nmobilityMultiplierRook: " & fmt"{evalParameters.mobilityMultiplierRook:>5.2f}"
    result &= ",\nmobilityMultiplierQueen: " & fmt"{evalParameters.mobilityMultiplierQueen:>5.2f}"
    result &= ",\nbonusRookSecondRankFromKing: " & fmt"{evalParameters.bonusRookSecondRankFromKing:>5.2f}"
    result &= ",\nkingSafetyMultiplier: " & fmt"{evalParameters.kingSafetyMultiplier:>5.2f}"

    result &= ")"


func `+=`*(a: var EvalParameters, b: EvalParameters) =
    for piece in pawn..king:
        for square in a1..h8:
            a.pstOpening[piece][square] += b.pstOpening[piece][square]
            a.pstEndgame[piece][square] += b.pstEndgame[piece][square]
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

func `*=`*(a: var EvalParameters, b: float) =
    for piece in pawn..king:
        for square in a1..h8:
            a.pstOpening[piece][square] *= b
            a.pstEndgame[piece][square] *= b
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

func `-`*(a: EvalParameters): EvalParameters =
    for piece in pawn..king:
        for square in a1..h8:
            result.pstOpening[piece][square] = -a.pstOpening[piece][square]
            result.pstEndgame[piece][square] = -a.pstEndgame[piece][square]
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

const defaultEvalParameters* = block:
    var defaultEvalParameters = EvalParameters(
        openingPassedPawnTable: [0.0, 0.0, 0.0, 10.0, 15.0, 20.0, 45.0, 0.0],
        endgamePassedPawnTable: [0.0, 20.0, 30.0, 40.0, 60.0, 100.0, 120.0, 0.0],
        bonusIsolatedPawn: -10.0,
        bonusBothBishops: 10.0,
        bonusRookOnOpenFile: 5.0,
        mobilityMultiplierKnight: 2.0,
        mobilityMultiplierBishop: 3.0,
        mobilityMultiplierRook: 4.0,
        mobilityMultiplierQueen: 2.0,
        bonusRookSecondRankFromKing: -10.0,
        kingSafetyMultiplier: 2.5
    )
    for piece in pawn..king:
        for square in a1..h8:
            defaultEvalParameters.pstOpening[piece][square] = openingPst[piece][square].float
            defaultEvalParameters.pstEndgame[piece][square] = endgamePst[piece][square].float
    defaultEvalParameters

proc randomEvalParameters*(max = 10.0): EvalParameters =

    template r: float = rand(max) - max/2.0
    for i in 0..7:
        result.openingPassedPawnTable[i] = r
        result.endgamePassedPawnTable[i] = r
    result.bonusIsolatedPawn = r
    result.bonusBothBishops = r
    result.bonusRookOnOpenFile = r
    result.mobilityMultiplierKnight = r
    result.mobilityMultiplierBishop = r
    result.mobilityMultiplierRook = r
    result.mobilityMultiplierQueen = r
    result.bonusRookSecondRankFromKing = r
    result.kingSafetyMultiplier = r

    for piece in pawn..king:
        for square in a1..h8:
            result.pstOpening[piece][square] = r
            result.pstEndgame[piece][square] = r

const defaultEvalParameters2* = EvalParameters(
pstOpening:[
  pawn:[
       0.18,  4.07, -4.91, -0.03, -4.34,  3.53, -3.79,  3.99, 
      15.65, 13.51,  4.03,  3.54,  0.65,  5.78,  2.12,  6.76, 
      15.82,  7.66, 10.28,  7.61,  1.95,  8.51,  2.85,  9.19, 
       6.98, 17.05, -0.32, 20.34, 19.85,  7.11, 12.83,  0.40, 
      -10.82, -2.19,  3.01, 25.93, 15.40, -2.81, -3.05, -17.69, 
      -2.01, -1.74, -3.52,  1.19, -1.42,  0.80, 14.33, -2.99, 
      -5.32,  3.01, -16.82, -7.90, -9.27, 10.65, 22.53, -4.17, 
      -3.54,  0.41, -4.98,  0.62, -0.12, -4.02,  4.38, -0.74
  ], 
  knight:[
      -3.51,  4.14, -3.77, -1.33,  3.63, -4.07,  3.89,  0.03, 
      -6.49, -0.94,  1.10, -2.06,  2.99,  4.75, -2.14, -1.02, 
      -4.99,  1.28, -1.44,  6.45, -1.34,  6.84, -2.06,  0.79, 
       1.07,  1.18,  1.83,  9.45,  5.85,  5.91, -0.03,  2.66, 
       0.19, -1.84,  6.69,  5.87, 13.29, -2.00,  2.61, -3.96, 
      -11.44, -6.51,  6.00,  4.13,  1.32, 25.67,  0.53, -7.48, 
      -1.54, -4.14, -1.61, 15.53, 14.11,  2.20,  2.20, -2.31, 
      -2.43, -8.40, -7.32, -5.30,  3.05, -4.06, -13.65,  4.09
  ], 
  bishop:[
       3.66,  3.52,  2.86, -0.79,  1.97,  3.66, -0.66, -2.38, 
       2.44,  2.21,  0.37, -0.36, -2.89,  0.92,  1.96, -2.62, 
      -5.64, -0.68, -0.37, -3.23,  2.55,  6.58, -2.29, -2.55, 
      -3.56, -5.80,  0.61,  0.71,  5.98,  1.15, -0.54, -3.00, 
       1.40, -2.20, -2.53,  5.33,  7.38, -8.37, -4.14,  2.51, 
      -4.71,  2.61,  6.15,  2.50,  4.65,  5.88,  4.43,  0.84, 
       3.69, 13.25,  0.48,  2.49, 14.37, -2.06, 26.67, -3.84, 
       0.89,  4.42, -3.93,  0.47,  2.69, -11.81, -2.90, -6.08
  ], 
  rook:[
       5.88,  1.27,  3.35,  4.88,  0.44,  0.20, -2.04,  2.92, 
       2.18,  0.52,  3.82, -0.55,  1.53,  6.98, -2.17,  1.13, 
       5.27, -1.23,  0.95,  1.49, -1.51,  2.85,  4.28, -3.01, 
      -0.67,  4.02,  3.34, -1.11, -3.66,  5.28, -4.02, -2.24, 
      -4.53, -0.12,  4.63,  2.25,  3.60,  2.92,  3.04,  0.89, 
      -6.22, -2.04,  2.15, -4.31,  0.97,  2.61, -3.92, -5.08, 
      -6.87,  0.52, -1.38,  3.76, -0.59,  4.88,  1.35, -11.66, 
      -3.93, -0.98, 10.29, 13.62, 10.63, 22.45, -14.18, -7.07
  ], 
  queen:[
       1.57,  2.22,  1.25, -0.77,  0.78, -2.42,  3.37, -1.44, 
      -2.61, -2.36,  1.98,  0.82,  0.16, -1.94, -0.13,  5.59, 
       1.55,  2.11,  3.77, -3.90, -0.98, -0.04,  3.27,  4.63, 
      -3.75, -7.67, -5.80, -6.17,  3.39, -3.63,  3.21, -4.04, 
      -9.40, -3.09, -4.72, -7.38, -2.33, -2.80,  2.95,  3.01, 
       0.10, -5.99,  2.73, -9.12,  0.77, -5.15,  1.96, -1.89, 
      -2.65, -3.72, 11.97, 11.49, 16.15,  4.63, -5.22, -2.46, 
       1.26,  4.07,  1.06, 54.06, -2.81, -5.15, -5.21,  3.34
  ], 
  king:[
      -4.08, -3.49,  3.81, -1.05,  1.93, -2.85, -0.17, -2.21, 
      -2.19,  0.16, -3.76,  4.95, -2.58, -0.26, -2.18, -3.71, 
       0.13, -3.30,  3.59,  4.67, -1.51,  4.90,  4.23, -0.03, 
       0.50,  5.52,  0.95,  6.89,  7.53, -1.29, -2.21,  0.01, 
       1.04, -0.65,  0.47,  4.50,  8.45,  4.70,  3.96,  0.58, 
      -2.71,  1.11,  1.16,  3.92,  3.39,  8.84,  0.86, -2.38, 
      -0.60,  2.00,  1.90, -4.79, -8.85,  3.00,  7.18, -8.13, 
      -0.06,  4.63,  1.50, -16.69, -4.88, -15.14, 29.20, -13.19
  ], 
],
pstEndgame:[
  pawn:[
       0.48,  4.11, -2.69,  2.64, -3.75,  0.45,  2.79, -3.65, 
      27.33, 26.76, 14.67, 14.12,  7.27, 11.19, 12.49, 15.92, 
      34.24, 24.80, 13.81,  6.83, 11.86, 14.80, 15.33, 18.08, 
      23.29, 13.81, 13.54,  0.44,  0.67,  8.24, 14.07, 16.57, 
      12.80,  9.55,  0.99, -7.53, -2.85, -1.00,  7.12,  3.85, 
      -5.81,  3.44, -2.02, -1.90,  9.45,  4.51, -1.42, -6.57, 
      -2.66, -0.35,  4.81, -2.88,  5.70, 13.40,  3.69, -12.01, 
      -1.46,  3.06,  3.78,  0.48, -2.29,  1.96,  3.05,  3.21
  ], 
  knight:[
      -6.05, -0.39,  3.10,  0.19, -5.48, -4.73, -4.50, -3.65, 
       0.81, -1.71,  2.39, -4.07, -5.31, -0.24, -0.30, -6.30, 
      -6.00,  1.58, -2.50,  4.52,  0.07, -1.67, -4.24, -0.38, 
       1.31,  4.27, -1.54,  3.18,  4.76, -0.22, -1.52,  2.43, 
      -0.68, -4.53, -0.39,  5.99, -0.44,  4.82,  1.36,  2.55, 
      -0.86,  2.24, -8.01, -1.26,  2.54, -6.67, -5.60,  1.66, 
      -2.58, -4.18, -5.45,  0.39, -0.36, -0.38,  1.50,  2.56, 
      -3.15, -5.77,  2.32,  1.92, -3.42, -3.43, -3.62, -4.80
  ], 
  bishop:[
      -4.41,  1.31, -5.58,  3.46,  3.94,  0.56,  1.30, -1.42, 
      -3.25,  2.40, -1.42,  1.64, -0.95,  2.33,  2.15, -0.46, 
       1.92, -0.23, -0.23, -3.12, -2.96, -3.27, -3.05,  1.11, 
       0.24,  0.12,  5.82,  5.55,  3.38,  1.27, -2.50,  5.17, 
       1.02, -2.70,  0.94,  7.57, -4.99,  2.58, -0.71,  1.93, 
      -1.13,  4.48,  6.15,  5.20,  6.05,  0.96,  4.50,  0.99, 
       2.07, -2.48,  2.97,  0.35, -0.51, -3.57,  1.02, -0.42, 
      -3.80,  2.01,  0.44, -1.91, -3.57,  0.78, -2.84, -0.54
  ], 
  rook:[
       5.12,  3.45,  3.00,  3.37, -2.35,  5.07,  4.16, -2.23, 
       4.64,  7.83,  1.94,  6.34, -0.43,  4.37, -0.01, -1.06, 
       4.24,  7.69, -0.37,  3.85,  0.14,  5.28,  6.29,  4.68, 
       0.44,  1.03,  1.36, -1.60, -0.30,  1.73, -2.55,  0.11, 
       3.91,  4.80,  3.67, -0.31, -2.95,  2.98, -3.48, -0.57, 
       0.45, -3.18, -4.75, -1.00,  0.75, -3.39, -1.23, -5.98, 
      -1.89, -3.26, -1.91, -1.65,  1.16,  2.06,  3.07, -0.84, 
      -7.05,  3.04,  4.28,  1.62,  1.51,  2.40, -4.90, -13.93
  ], 
  queen:[
       0.52,  1.72,  0.59,  4.59, -2.27,  0.46,  3.45,  5.08, 
       2.98, -3.73, -0.59,  4.82,  2.97, -1.54, -3.00,  3.12, 
      -0.59,  0.09, -4.57,  2.49,  3.85,  2.74, -2.20,  0.98, 
       3.62,  2.65,  1.82,  0.15,  0.57,  5.34,  5.89,  7.04, 
      -5.38, -1.33,  2.44,  0.53,  2.96,  3.93,  2.54,  2.39, 
      -4.92, -3.93,  2.85, -0.47,  4.08,  4.04,  2.57, -2.36, 
       1.30, -5.47, -3.31, -0.85,  0.05,  0.33,  3.15,  4.29, 
       3.50, -4.71, -1.49,  4.80,  0.56, -1.46, -2.48,  2.89
  ], 
  king:[
       1.51, -2.80,  0.96,  4.71, -2.02, -1.95, -0.21, -4.33, 
      -1.16, -1.93,  5.98,  2.38,  0.58,  5.53,  3.36, -0.78, 
       4.04,  2.03,  1.41,  2.44,  1.89,  9.20,  3.31, -0.21, 
       0.41,  3.96,  6.33,  4.21,  8.48, 12.33,  6.17, -3.65, 
      -1.52,  1.06,  8.58, 11.54, 10.68, 13.38, -0.81, -7.08, 
      -3.46, -2.72,  1.54,  7.52, 12.84, 10.95,  7.06, -9.83, 
      -4.71, -2.88, -3.76, -1.37,  3.83,  1.11,  0.27, -14.76, 
      -7.56, -9.67, -5.07, -6.09, -12.38, -13.41, -17.24, -22.22
  ], 
],
openingPassedPawnTable: [-2.67,  0.56,  4.32,  9.53, 23.24, 53.50, 50.28, -3.49],
endgamePassedPawnTable: [ 3.23, 10.77, 11.35, 37.57, 69.62, 136.34, 136.33, -2.58],
bonusIsolatedPawn: -12.00,
bonusBothBishops: 32.03,
bonusRookOnOpenFile: 12.89,
mobilityMultiplierKnight:  9.99,
mobilityMultiplierBishop:  8.50,
mobilityMultiplierRook:  7.63,
mobilityMultiplierQueen:  8.24,
bonusRookSecondRankFromKing: -38.73,
kingSafetyMultiplier:  3.00)

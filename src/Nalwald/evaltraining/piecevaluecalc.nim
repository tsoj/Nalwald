import nimchess

import ../types, ../evalparams, ../eval, datautils

func getPieceValue(
    piece: Piece, evalParameters: EvalParameters, data: openArray[Entry]
): Value =
  var
    sum = 0.0
    numPieceEvals = 0
  for entry in data:
    let
      position = entry.position
      # eval is relative to the side to move
      startEval = position.eval(evalParameters)
    for square in position[piece]:
      let owner = position.coloredPieceAt(square).color
      assert position.coloredPieceAt(square).piece == piece
      var newPosition = position
      newPosition.removePiece(owner, piece, square)
      var diff = startEval - newPosition.eval(evalParameters)
      if owner != position.us:
        diff = -diff
      sum += diff.float
      numPieceEvals += 1
  (sum / numPieceEvals.float).Value

proc pieceValuesAsString*(
    evalParameters: EvalParameters, data: openArray[Entry]
): string =
  for piece in pawn .. queen:
    result &= $piece & ": " & $getPieceValue(piece, evalParameters, data) & ".Value, "

when isMainModule:
  import std/os
  var data: seq[Entry]
  for dir in commandLineParams():
    data.loadDataDir dir
  echo pieceValuesAsString(defaultEvalParameters, data)

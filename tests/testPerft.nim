import unittest
import ../src/chess/[position, chessStrutils, perft]
import ../src/utils
import testData/exampleFens

import std/terminal

const maxNumPerftNodes {.intdefine.} = int.high

proc testPerft(usePseudoLegalTest: bool, maxNodes: int) =
  for (fen, trueNumNodesList) in perftFens:
    let position = fen.toPosition

    for depth in 1 .. trueNumNodesList.len:
      let trueNumNodes = trueNumNodesList[depth - 1]

      if trueNumNodes > maxNodes:
        break

      let perftResult = position.perft(depth)
      check perftResult == trueNumNodes

suite "Perft Tests":

  test "Perft correctness":
    testPerft(usePseudoLegalTest = false, maxNodes = maxNumPerftNodes)

  test "Pseudo legality check based perft correctness":
    testPerft(usePseudoLegalTest = true, maxNodes = max(1000, maxNumPerftNodes div 10))

  test "Perft zero depth":
    let position = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1".toPosition
    check position.perft(0) == 1

  test "Perft negative depth":
    let position = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1".toPosition
    check position.perft(-1) == 1

  test "Speed perft benchmark":
    var totalNodes = 0
    let start = secondsSince1970()

    for (fen, numNodeList) in perftFens:
      let position = fen.toPosition
      var depth = 0
      while depth + 1 < numNodeList.len and numNodeList[depth] <= maxNumPerftNodes:
        depth += 1
      if depth > 0:
        totalNodes += position.perft(depth).int

    let time = secondsSince1970() - start
    let nps = totalNodes.float / max(0.00001, time.float)

    # This is more of a benchmark than a test - we just ensure it completes
    check totalNodes > 0
    check nps > 0

    styledEcho styleBright,
      "Speed perft test: ", resetStyle, $int(nps / 1000.0), styleItalic, " knps"
    echo getCpuInfo()

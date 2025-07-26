import unittest
import ../src/position
import ../src/chessStrutils
import ../src/perft
import ../src/types
import ../src/utils
import exampleFens

import std/terminal

const maxNumPerftNodes {.intdefine.} = int.high

suite "Perft Tests":

  test "Basic perft correctness":
    const weirdFen = "QQQQQQBk/Q6B/Q6Q/Q6Q/Q6Q/Q6Q/Q6Q/KQQQQQQQ w - - 0 1"

    for (fen, trueNumNodesList) in perftFens:
      let position = fen.toPosition

      for depth in 1 .. trueNumNodesList.len:
        let trueNumNodes = trueNumNodesList[depth - 1]

        if trueNumNodes > maxNumPerftNodes:
          break

        let perftResult = position.perft(depth)
        check perftResult == trueNumNodes

  test "Perft for Chess960 positions":
    for (fen, trueNumNodesList) in perftFens:
      if fen.toPosition.isChess960:
        let position = fen.toPosition

        # Test at least depth 1
        if trueNumNodesList.len > 0:
          let expectedNodes = trueNumNodesList[0]
          if expectedNodes <= maxNumPerftNodes:
            check position.perft(1) == expectedNodes

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

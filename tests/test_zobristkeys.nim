import unittest

import nimchess

import Nalwald/[zobristkey, rootsearch]
import testdata/examplefens

suite "Zobrist Key Tests":
  test "Zobrist key uniqueness across all example fens":
    for fen1 in someFens:
      for fen2 in someFens:
        let
          p1 = fen1.toPosition(suppressWarnings = true)
          p2 = fen2.toPosition(suppressWarnings = true)

        check (p1 == p2) == (p1.zobristKey == p2.zobristKey)

  test "Key changes with position changes":
    let baseFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    let basePosition = baseFen.toPosition

    # Test that different side to move produces different key
    let differentSideFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1"
    let differentSidePosition = differentSideFen.toPosition
    check basePosition.zobristKey != differentSidePosition.zobristKey

  test "En passant affects Zobrist key":
    let noEnPassantFen = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1"
    let withEnPassantFen = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"

    let pos1 = noEnPassantFen.toPosition
    let pos2 = withEnPassantFen.toPosition

    check pos1.zobristKey != pos2.zobristKey

  test "Castling rights affect Zobrist key":
    let withCastlingFen = "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1"
    let noCastlingFen = "r3k2r/8/8/8/8/8/8/R3K2R w - - 0 1"

    let pos1 = withCastlingFen.toPosition
    let pos2 = noCastlingFen.toPosition

    check pos1.zobristKey != pos2.zobristKey

func searchPosPerft(searchPos: SearchPos, depth: int): int64 =
  ## Like perft, but goes through SearchPos.doMove so that the incremental
  ## zobrist key gets exercised (and checked) for every visited node.
  if depth <= 0:
    return 1
  for move in searchPos.pos.legalMoves:
    let newSearchPos = searchPos.doMove(move)
    doAssert newSearchPos.key == newSearchPos.pos.zobristKey
    result += newSearchPos.searchPosPerft(depth - 1)

suite "SearchPos Tests":
  test "Incremental key matches recomputed key during perft":
    for fen in someFens:
      let position = fen.toPosition(suppressWarnings = true)
      check position.searchPos.searchPosPerft(2) == position.perft(2)

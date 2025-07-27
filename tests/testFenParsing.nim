import unittest
import ../src/position
import ../src/chessStrutils
import ../src/types
import testData/exampleFens
import std/[strutils]

suite "FEN Parsing Tests":

  test "FEN parsing and regeneration":
    for fen in someFens:
      let
        position = fen.toPosition
        fenTestLen =
          if position.isChess960:
            fen.splitWhitespace()[0].len
          else:
            fen.len

      check fen[0 ..< fenTestLen] == position.fen(alwaysShowEnPassantSquare = true)[0 ..< fenTestLen]

  test "Chess960 FEN conversion":
    const
      frcFen1 = "qrrk1bnn/8/4b3/pppppppp/PPPPPPPP/4B3/8/QRRK1BNN w Qq - 8 13"
      frcFen2 = "qrrk1bnn/8/4b3/pppppppp/PPPPPPPP/4B3/8/QRRK1BNN w Bb - 8 13"

    check frcFen1.toPosition(suppressWarnings = true).fen == frcFen2

  test "Chess960 detection":
    for fen in classicalFens:
      check not fen.toPosition.isChess960

    for fen in chess960Fens:
      check fen.toPosition.isChess960

  test "FEN components parsing white":
    let testFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    let position = testFen.toPosition

    check position.us == white
    check position.halfmoveClock == 0
    check position.halfmovesPlayed == 0

  test "FEN components parsing black":
    let testFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1"
    let position = testFen.toPosition

    check position.us == black
    check position.halfmoveClock == 0
    check position.halfmovesPlayed == 1

  test "En passant target parsing":
    let testFen = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
    let position = testFen.toPosition

    check position.enPassantTarget == e3

  test "Castling rights parsing":
    let testFen = "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1"
    let position = testFen.toPosition

    # This test assumes the position has castling rights stored somewhere
    # The exact implementation may vary based on how castling is stored
    check position.rookSource[white][kingside] != noSquare
    check position.rookSource[white][queenside] != noSquare
    check position.rookSource[black][kingside] != noSquare
    check position.rookSource[black][queenside] != noSquare

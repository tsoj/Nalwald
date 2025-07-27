import unittest
import ../src/position
import ../src/chessStrutils
import ../src/types
import testData/exampleFens

suite "Zobrist Key Tests":

  test "No Zobrist key collisions":
    for fen1 in someFens:
      for fen2 in someFens:
        var
          p1 = fen1.toPosition
          p2 = fen2.toPosition

        # Normalize halfmove counters to isolate position-based differences
        p1.halfmoveClock = p2.halfmoveClock
        p1.halfmovesPlayed = p2.halfmovesPlayed

        check p1.fen == p2.fen or p1.zobristKey != p2.zobristKey

  test "Pawn key consistency":
    for fen1 in someFens:
      for fen2 in someFens:
        var
          p1 = fen1.toPosition
          p2 = fen2.toPosition

        # Normalize halfmove counters
        p1.halfmoveClock = p2.halfmoveClock
        p1.halfmovesPlayed = p2.halfmovesPlayed

        let samePawnStructure = (p1[pawn] == p2[pawn] and p1[white, pawn] == p2[white, pawn])
        let samePawnKey = (p1.pawnKey == p2.pawnKey)

        check samePawnStructure == samePawnKey

  test "Zobrist key calculation correctness":
    for fen in someFens:
      let position = fen.toPosition
      check position.zobristKeysAreOk

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

  test "Zobrist key uniqueness across classical positions":
    var seenKeys: seq[Key] = @[]

    for fen in classicalFens:
      let position = fen.toPosition
      let key = position.zobristKey

      check key notin seenKeys

      seenKeys.add(key)

  test "Zobrist key uniqueness across Chess960 positions":
    var seenKeys: seq[Key] = @[]

    for fen in chess960Fens:
      let position = fen.toPosition
      let key = position.zobristKey

      check key notin seenKeys

      seenKeys.add(key)

  test "Pawn key only depends on pawn structure":
    # Test that non-pawn pieces don't affect pawn key
    let fen1 = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    let fen2 = "r1bqkb1r/pppppppp/2n2n2/8/8/2N2N2/PPPPPPPP/R1BQKB1R w KQkq - 0 1"

    let pos1 = fen1.toPosition
    let pos2 = fen2.toPosition

    # Same pawn structure should have same pawn key
    check pos1.pawnKey == pos2.pawnKey

    # But different overall position should have different zobrist key
    check pos1.zobristKey != pos2.zobristKey

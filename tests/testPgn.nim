import ../src/chess/[pgn, chessStrutils]
import std/[unittest, tables, streams, strutils]

suite "PGN Parser Tests":

  test "Move to SAN notation":
    const testCases = [
      ("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 1 1", "e1g1", "O-O"),
      ("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 1 1", "e1c1", "O-O-O"),
      ("r3k2r/8/8/8/8/8/8/R3K2R b KQkq - 1 1", "e8g8", "O-O"),
      ("r3k2r/8/8/8/8/8/8/R3K2R b KQkq - 1 1", "e8c8", "O-O-O"),
      ("3r1k1r/4pp2/8/8/8/8/8/4RKR1 w Gd - 1 1", "f1g1", "O-O"),
      ("6bk/7b/8/3pP3/8/8/8/Q3K3 w - d6 0 2", "e5d6", "exd6#"),
      ("N3k2N/8/8/3N4/N4N1N/2R5/1R6/4K3 w - - 0 1", "e1f1", "Kf1"),
      ("N3k2N/8/8/3N4/N4N1N/2R5/1R6/4K3 w - - 0 1", "c3c2", "Rcc2"),
      ("N3k2N/8/8/3N4/N4N1N/2R5/1R6/4K3 w - - 0 1", "b2c2", "Rbc2"),
      ("N3k2N/8/8/3N4/N4N1N/2R5/1R6/4K3 w - - 0 1", "a4b6", "N4b6"),
      ("N3k2N/8/8/3N4/N4N1N/2R5/1R6/4K3 w - - 0 1", "h8g6", "N8g6"),
      ("N3k2N/8/8/3N4/N4N1N/2R5/1R6/4K3 w - - 0 1", "h4g6", "Nh4g6"),
      ("8/2KN1p2/5p2/3N1B1k/5PNp/7P/7P/8 w - -", "d5f6", "N5xf6#"),
      ("8/8/8/R2nkn2/8/8/2K5/8 b - - 0 1", "f5e3", "Ne3+"),
      ("7k/1p2Npbp/8/2P5/1P1r4/3b2QP/3q1pPK/2RB4 b - - 1 29", "f2f1q", "f1=Q"),
      ("7k/1p2Npbp/8/2P5/1P1r4/3b2QP/3q1pPK/2RB4 b - - 1 29", "f2f1n", "f1=N+"),
      ("4r3/3k4/8/8/8/8/q5PP/1R1KR3 w Q - 2 2", "d1b1", "O-O-O+"),
      ("8/8/8/B2p3Q/2qPp1P1/b7/2P2PkP/4K2R b K - 0 1", "g2h1", "Kxh1"),
      ("8/8/rk6/8/8/6KR/8/8 w - - 100 10", "h3h6", "Rh6+ 1/2-1/2"),
      ("8/8/rk6/8/8/6KR/8/8 w - - 100 10", "h3h5", "Rh5 1/2-1/2"),
      ("8/8/8/8/8/1k6/3r4/K7 b - - 31 117", "d2b2", "Rb2 1/2-1/2"),
    ]

    for (fen, uciMove, sanMove) in testCases:
      let
        position = fen.toPosition
        claimedSAN = uciMove.toMove(position).toSAN(position)
        claimedUCI = sanMove.toMoveFromSAN(position).notation(position)

      check claimedSAN == sanMove
      check claimedUCI == uciMove

  test "Parse single game from string":
    let pgnContent = """
[Event "Test Game"]
[Site "Test Site"]
[Date "2024.01.01"]
[White "Player 1"]
[Black "Player 2"]
[Result "1-0"]

1. e4 e5 2. Nf3 Nc6 3. Bb5 1-0
"""

    let games = parseGamesFromString(pgnContent)
    check games.len == 1

    let game = games[0]
    check game.headers["Event"] == "Test Game"
    check game.headers["White"] == "Player 1"
    check game.headers["Black"] == "Player 2"
    check game.result == "1-0"
    check game.moves.len == 5  # e4, e5, Nf3, Nc6, Bb5

    # Verify moves are correct
    let startPos = toPosition("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
    check game.moves[0] == toMoveFromSAN("e4", startPos)

  test "Parse multiple games from string":
    let pgnContent = """
[Event "Game 1"]
[White "A"]
[Black "B"]
[Result "1-0"]

1. e4 e5 2. Nf3 1-0

[Event "Game 2"]
[White "C"]
[Black "D"]
[Result "0-1"]

1. d4 d5 2. c4 0-1
"""

    let games = parseGamesFromString(pgnContent)
    check games.len == 2
    check games[0].headers["Event"] == "Game 1"
    check games[1].headers["Event"] == "Game 2"
    check games[0].result == "1-0"
    check games[1].result == "0-1"

  test "Parse game with FEN starting position":
    let pgnContent = """
[Event "Custom Position"]
[FEN "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2"]
[White "Player 1"]
[Black "Player 2"]
[Result "*"]

2. Nf3 Nc6 *
"""

    let games = parseGamesFromString(pgnContent)
    check games.len == 1
    check "4p3/4P3" in games[0].startPosition.fen

  test "Parse game with comments and annotations":
    let pgnContent = """
[Event "Annotated Game"]
[White "Annotator"]
[Black "Student"]
[Result "1/2-1/2"]

1. e4 {Good opening move} e5 2. Nf3! (The Italian is also good) Nc6
3. Bb5?! {Dubious} a6 4. Ba4 Nf6 1/2-1/2
"""

    let games = parseGamesFromString(pgnContent)
    check games.len == 1
    check games[0].result == "1/2-1/2"
    # Should parse moves despite comments
    check games[0].moves.len >= 6

  test "Handle castling moves":
    let pgnContent = """
[Event "Castling Test"]
[White "King"]
[Black "Rook"]
[Result "*"]

1. d4 e6 2. Bf4 Nf6 3. Qd2 Be7 4. Nc3 O-O 5. O-O-O *
"""

    let games = parseGamesFromString(pgnContent)
    check games.len == 1
    let game = games[0]

    # Check that castling moves are parsed correctly
    var pos = game.startPosition
    check game.moves[7].isCastling # black's O-O
    check game.moves[8].isCastling # whites's O-O-O

  test "Handle pawn promotion":
    let pgnContent = """
[Event "Promotion Test"]
[White "Promoter"]
[Black "Promoted"]
[Result "*"]

1. e4 e5 2. f4 exf4 { C33 King's Gambit Accepted } 3. e5 f3 4. e6 fxg2 5. e7 gxh1=Q 6. exd8=Q *
"""

    let games = parseGamesFromString(pgnContent)
    check games.len == 1
    let game = games[0]

    # Check for promotion moves
    var foundPromotion = false
    for move in game.moves:
      if move.promoted != noPiece:
        foundPromotion = true
        break
    check foundPromotion

  test "Empty content returns empty sequence":
    let games = parseGamesFromString("")
    check games.len == 0

  test "Malformed PGN gracefully handled":
    let pgnContent = """
[Event "Malformed"
1. e4 e5 this is not a valid move
"""

    let games = parseGamesFromString(pgnContent, suppressWarnings = true)
    # Should either parse partially or return empty, but not crash
    check games.len >= 0

  test "Parse from StringStream":
    let pgnContent = """
[Event "Stream Test"]
[White "Stream"]
[Black "Test"]
[Result "1-0"]

1. e4 e5 2. Qh5 1-0
"""

    let stream = newStringStream(pgnContent)
    let games = parseGamesFromStream(stream)
    stream.close()

    check games.len == 1
    check games[0].headers["Event"] == "Stream Test"

  test "Game result variations":
    let tests = [
      ("1-0", "1-0"),
      ("0-1", "0-1"),
      ("1/2-1/2", "1/2-1/2"),
      ("*", "*")
    ]

    for (resultStr, expected) in tests:
      let pgnContent = """
[Event "Result Test"]
[Result """ & "\"" & resultStr & "\"" & """]
[White "A"]
[Black "B"]

1. e4 e5 """ & resultStr

      let games = parseGamesFromString(pgnContent)
      check games.len == 1
      check games[0].result == expected

  test "Handle semicolon comments":
    let pgnContent = """
[Event "Semicolon Comments"]
[White "Player1"]
[Black "Player2"]
[Result "1-0"]

1. e4 ; This is a comment
e5 2. Nf3 ; Another comment
Nc6 3. Bb5 1-0
"""

    let games = parseGamesFromString(pgnContent)
    check games.len == 1
    check games[0].result == "1-0"
    # Should parse moves despite semicolon comments
    check games[0].moves.len == 5  # e4, e5, Nf3, Nc6, Bb5

  test "Handle brace comments spanning multiple lines":
    let pgnContent = """
[Event "Multi-line Comments"]
[White "Player1"]
[Black "Player2"]
[Result "1-0"]

1. e4 { This is a long comment
that spans multiple lines
and should be ignored } e5 2. Nf3 Nc6 1-0
"""

    let games = parseGamesFromString(pgnContent)
    check games.len == 1
    check games[0].result == "1-0"
    check games[0].moves.len == 4  # e4, e5, Nf3, Nc6

  test "Ignore game results inside comments":
    let pgnContent = """
[Event "Result in Comment"]
[White "Player1"]
[Black "Player2"]
[Result "*"]

1. e4 { The game 1-0 was great } e5 2. Nf3 ; Another game ended 0-1
Nc6 3. Bb5 *
"""

    let games = parseGamesFromString(pgnContent)
    check games.len == 1
    check games[0].result == "*"  # Should be *, not 1-0 or 0-1 from comments
    check games[0].moves.len == 5

  test "Ignore headers inside comments":
    let pgnContent = """
[Event "Header in Comment"]
[White "Player1"]
[Black "Player2"]
[Result "1-0"]

1. e4 { [White "FakePlayer"] should be ignored } e5
2. Nf3 ; [Black "AnotherFake"] also ignored
Nc6 1-0

[Event "Second Game"]
[White "RealPlayer"]
[Black "AnotherReal"]
[Result "0-1"]

1. d4 d5 0-1
"""

    let games = parseGamesFromString(pgnContent)
    check games.len == 2
    check games[0].headers["White"] == "Player1"  # Not FakePlayer
    check games[1].headers["White"] == "RealPlayer"

  test "Game ends with result token":
    let pgnContent = """
[Event "Result Ending"]
[White "Player1"]
[Black "Player2"]
[Result "1-0"]

1. e4 e5 2. Qh5 Nf6 3. Qxf7# 1-0

[Event "Next Game"]
[White "Player3"]
[Black "Player4"]
[Result "0-1"]

1. d4 d5 0-1
"""

    let games = parseGamesFromString(pgnContent)
    check games.len == 2
    check games[0].result == "1-0"
    check games[1].result == "0-1"

  test "Handle illegal moves":
    let pgnContent = """
[Event "Illegal Moves"]
[White "Cheater"]
[Black "Victim"]
[Result "*"]

1. e4 e5 2. Nf3 Ke2 ; IllegalMove
"""

    let games = parseGamesFromString(pgnContent, suppressWarnings = true)
    check games.len == 0

  test "Handle completely invalid PGN moves":
    let pgnContent = """
[Event "Invalid PGN"]
[White "Bad"]
[Black "Parser"]
[Result "*"]

1. xyz abc 2. NotAMove StillNotAMove *
"""

    let games = parseGamesFromString(pgnContent, suppressWarnings = true)
    check games.len == 0

  test "Handle unclosed brace comment at end":
    let pgnContent = """
[Event "Unclosed Comment"]
[White "Player1"]
[Black "Player2"]
[Result "*"]

1. e4 e5 2. Nf3 { This comment is never closed
and continues to the end of the game
"""

    let games = parseGamesFromString(pgnContent)
    check games.len == 1
    check games[0].moves.len == 3  # e4, e5, Nf3

  test "Handle empty game with only result":
    let pgnContent = """
[Event "Empty Game"]
[White "Nobody"]
[Black "Played"]
[Result "1/2-1/2"]

1/2-1/2
"""

    let games = parseGamesFromString(pgnContent)
    check games.len == 1
    check games[0].moves.len == 0
    check games[0].result == "1/2-1/2"

  test "Complex comment scenarios":
    let pgnContent = """
[Event "Complex Comments"]
[White "Complex"]
[Black "Parser"]
[Result "1-0"]

1. e4 ; First move { with brace comment }
e5 2. Nf3 { Multi-line
; with semicolon inside
} Nc6 ; Final comment
3. Bb5 1-0
"""

    let games = parseGamesFromString(pgnContent)
    check games.len == 1
    check games[0].moves.len == 5
    check games[0].result == "1-0"


  test "Move commentary":
    let pgnContent = """
[Event "?"]
[Site "?"]
[Black "?"]
[Result "*"]
[VeryLongHeader "This is a very long header, much wider than the 80 columns that PGNs are formatted with by default"]
{ Test game: } 1. e4 { Scandinavian Defense: } 1... d5 ( { This } 1... h5 $2
{ is nonsense } ) ( 1... e5 2. Qf3 $2 ) ( 1... c5 { Sicilian } ) 2. exd5
{ Best } { and the end of this example } *
1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. c3 Nf6 5. d3 d6 6. Nbd2 a6 $6 (6... Bb6 $5 {
/\\ Ne7, c6}) *
"""

    let games = parseGamesFromString(pgnContent)
    check games.len == 2
    check games[0].moves.len == 3
    check games[0].result == "*"
    check games[1].moves.len == 12
    check games[1].result == "*"

  test "PGN position validation against ground truth FENs":
    # Load the test PGN file and expected FEN positions
    let games1 = parseGamesFromFile("tests/testData/testPgns.pgn")
    let games2 = games1.toPgnString.parseGamesFromString
    let expectedFens = readFile("tests/testData/testPgns.epd").strip().splitLines()

    var fenIndex = 0

    for games in [games1, games2]:
      for game in games:
        var currentPosition = game.startPosition

        # Check starting position FEN
        if fenIndex < expectedFens.len:
          check currentPosition.fen == expectedFens[fenIndex].toPosition.fen
          fenIndex += 1

        # Check FEN after each move
        for moveIndex, move in game.moves:
          currentPosition = currentPosition.doMove(move, allowNullMove = true)

          if fenIndex < expectedFens.len:
            check currentPosition.fen == expectedFens[fenIndex].toPosition.fen
            fenIndex += 1
          else:
            # Stop if we've run out of expected FENs
            break

        # Stop processing games if we've exhausted all expected FENs
        if fenIndex >= expectedFens.len:
          break

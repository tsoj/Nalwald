import types, position, move, movegen, utils, bitboard, castling

export move, position

import std/[strutils, options, strformat, streams]


func fen*(position: Position): string =
  result = ""
  var emptySquareCounter = 0
  for rank in countdown(7, 0):
    for file in 0 .. 7:
      let square = (rank * 8 + file).Square
      let coloredPiece = position.coloredPieceAt(square)
      if coloredPiece.piece != noPiece:
        if emptySquareCounter > 0:
          result &= $emptySquareCounter
          emptySquareCounter = 0
        result &= coloredPiece.notation
      else:
        emptySquareCounter += 1
    if emptySquareCounter > 0:
      result &= $emptySquareCounter
      emptySquareCounter = 0
    if rank != 0:
      result &= "/"

  result &= (if position.us == white: " w " else: " b ")

  for color in [white, black]:
    for castlingSide in [kingside, queenside]:
      let rookSource = position.rookSource[color][castlingSide]
      if rookSource != noSquare:
        result &= ($rookSource)[0]

        if result[^1] == 'h':
          result[^1] = 'k'
        if result[^1] == 'a':
          result[^1] = 'q'

        if color == white:
          result[^1] = result[^1].toUpperAscii

  if result.endsWith(' '):
    result &= "-"

  result &= " "

  if position.enPassantTarget != noSquare:
    result &= $position.enPassantTarget
  else:
    result &= "-"

  result &= " " & $position.halfmoveClock & " " & $(position.halfmovesPlayed div 2 + 1)

func `$`*(position: Position): string =
  result =
    boardString(
      proc(square: Square): Option[string] =
        if not empty(square.toBitboard and position.occupancy):
          return some($position.coloredPieceAt(square))
        none(string)
    ) & "\n"
  let fenWords = position.fen.splitWhitespace
  for i in 1 ..< fenWords.len:
    result &= fenWords[i] & " "

func debugString*(position: Position): string =
  result = ""
  for piece in pawn .. king:
    result &= $piece & ":\n"
    result &= $position[piece] & "\n"
  for color in white .. black:
    result &= $color & ":\n"
    result &= $position[color] & "\n"
  result &= "enPassantTarget:\n"
  result &= $position.enPassantTarget & "\n"
  result &= "us: " & $position.us & ", enemy: " & $position.enemy & "\n"
  result &=
    "halfmovesPlayed: " & $position.halfmovesPlayed & ", halfmoveClock: " &
    $position.halfmoveClock & "\n"
  result &= "zobristKey: " & $position.zobristKey & "\n"
  result &= "rookSource: " & $position.rookSource



func toMove*(s: string, position: Position): Move =
  if s.len != 4 and s.len != 5:
    raise newException(ValueError, "Move string is wrong length: " & s)

  let
    source = parseEnum[Square](s[0 .. 1])
    target = parseEnum[Square](s[2 .. 3])
    promoted =
      if s.len == 5:
        s[4].toColoredPiece.piece
      else:
        noPiece

  for move in position.legalMoves:
    if move.source == source and move.promoted == promoted:
      if move.target == target:
        return move
      if move.isCastling and target == kingTarget[position.us][move.castlingSide(position)] and
          not position.isChess960:
        return move
  raise newException(ValueError, "Move is illegal: " & s)

proc toPosition*(fen: string, suppressWarnings = false): Position =
  result = default(Position)

  var fenWords = fen.splitWhitespace()
  if fenWords.len < 4:
    raise newException(ValueError, "FEN must have at least 4 words")
  if fenWords.len > 6 and not suppressWarnings:
    echo "WARNING: FEN shouldn't have more than 6 words"
  while fenWords.len < 6:
    fenWords.add("0")

  for i in 2 .. 8:
    fenWords[0] = fenWords[0].replace($i, repeat("1", i))

  let piecePlacement = fenWords[0]
  let activeColor = fenWords[1]
  let castlingRights = fenWords[2]
  let enPassant = fenWords[3]
  let halfmoveClock = fenWords[4]
  let fullmoveNumber = fenWords[5]

  var squareList = block:
    var squareList = default(seq[Square])
    for y in 0 .. 7:
      for x in countdown(7, 0):
        squareList.add Square(y * 8 + x)
    squareList

  for pieceChar in piecePlacement:
    if squareList.len == 0:
      raise
        newException(ValueError, "FEN is not correctly formatted (too many squares)")

    case pieceChar
    of '/':
      # we don't need to do anything, except check if the / is at the right place
      if not squareList[^1].isLeftEdge:
        raise newException(ValueError, "FEN is not correctly formatted (misplaced '/')")
    of '1':
      discard squareList.pop
    of '0':
      if not suppressWarnings:
        echo "WARNING: '0' in FEN piece placement data is not official notation"
    else:
      doAssert pieceChar notin ['2', '3', '4', '5', '6', '7', '8']
      try:
        let sq = squareList.pop
        result.addColoredPiece(pieceChar.toColoredPiece, sq)
      except ValueError:
        raise newException(
          ValueError,
          "FEN piece placement is not correctly formatted: " & getCurrentExceptionMsg(),
        )

  if squareList.len != 0:
    raise newException(ValueError, "FEN is not correctly formatted (too few squares)")

  # active color
  case activeColor
  of "w", "W":
    result.us = white
  of "b", "B":
    result.us = black
  else:
    raise newException(
      ValueError, "FEN active color notation does not exist: " & activeColor
    )

  # castling rights
  result.rookSource = [[noSquare, noSquare], [noSquare, noSquare]]
  for castlingChar in castlingRights:
    if castlingChar == '-':
      continue

    let
      us = if castlingChar.isUpperAscii: white else: black
      kingSquare = (result[us] and result[king]).toSquare

    let rookSource =
      case castlingChar
      of 'K', 'k', 'Q', 'q':
        let (makeStep, atEdge) = if castlingChar in ['K', 'k']: (right, isRightEdge) else: (left, isLeftEdge)
        var
          square = kingSquare
          rookSource = noSquare
        while not square.atEdge:
          square = square.makeStep
          if not empty(result[rook, us] and square.toBitboard):
            rookSource = square
        rookSource
      else:
        let rookSourceBit =
          files(parseEnum[Square](castlingChar.toLowerAscii & "1")) and homeRank(us)

        if rookSourceBit.countSetBits != 1:
          raise newException(
            ValueError,
            fmt"FEN castling erroneous. Invalid castling char: {castlingChar}",
          )

        rookSourceBit.toSquare

    let castlingSide = if rookSource < kingSquare: queenside else: kingside
    result.rookSource[us][castlingSide] = rookSource
    if rookSource == noSquare or empty (rookSource.toBitboard and result[us, rook]):
      raise newException(
        ValueError,
        fmt"FEN castling erroneous. Rook for {us} for {castlingSide} doesn't exist",
      )

  # en passant square
  result.enPassantTarget = noSquare
  if enPassant != "-":
    try:
      result.enPassantTarget = parseEnum[Square](enPassant.toLowerAscii)
    except ValueError:
      raise newException(
        ValueError,
        "FEN en passant target square is not correctly formatted: " &
          getCurrentExceptionMsg(),
      )

  # halfmove clock and fullmove number
  try:
    result.halfmoveClock = halfmoveClock.parseInt.int8
  except ValueError:
    raise newException(
      ValueError,
      "FEN halfmove clock is not correctly formatted: " & getCurrentExceptionMsg(),
    )

  try:
    result.halfmovesPlayed = (fullmoveNumber.parseInt - 1) * 2
    if result.us == black:
      result.halfmovesPlayed += 1
  except ValueError:
    raise newException(
      ValueError,
      "FEN fullmove number is not correctly formatted: " & getCurrentExceptionMsg(),
    )

  result.setZobristKeys

  if result[white, king].countSetBits != 1 or result[black, king].countSetBits != 1:
    raise newException(
      ValueError, "FEN is not correctly formatted: Need exactly one king for each color"
    )

func notation*(move: Move, position: Position): string =
  if move.isCastling and not position.isChess960:
    return $move.source & $kingTarget[position.us][move.castlingSide(position)]
  $move

func notation*(pv: seq[Move], position: Position): string =
  result = ""
  var currentPosition = position
  for move in pv:
    result &= move.notation(currentPosition) & " "
    currentPosition = currentPosition.doMove(move)

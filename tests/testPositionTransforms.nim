import unittest
import ../src/position
import ../src/chessStrutils
import ../src/types
import testData/exampleFens


suite "Position Transform Tests":

  template rotate(position: Position): Position =
    position.mirrorHorizontally(skipKeyCalculation = true).mirrorVertically()

  test "Identity transforms":
    for fen in someFens:
      let position = fen.toPosition

      # Test double rotation (180 degrees twice = identity)
      let doubleRotated = position.rotate.rotate
      check position == doubleRotated

      # Test quadruple mirror operations
      let quadMirrored = position
        .mirrorHorizontally
        .mirrorVertically(swapColors = false)
        .mirrorHorizontally
        .mirrorVertically(swapColors = false)
      check position == quadMirrored

  test "Complex transform combinations":
    for fen in someFens:
      let position = fen.toPosition

      # Test rotate + mirror combinations that should return to original
      let transformed1 = position
        .rotate
        .mirrorVertically
        .rotate
        .mirrorVertically
      check position == transformed1

      # Test complex sequence that should be identity
      let transformed2 = position
        .mirrorVertically
        .mirrorHorizontally
        .rotate
        .mirrorVertically(swapColors = false)
        .rotate
        .mirrorVertically
        .mirrorVertically(swapColors = false)
        .mirrorHorizontally
      check position == transformed2

  test "Single transforms produce valid positions":
    for fen in someFens:
      let position = fen.toPosition

      # Test vertical mirror
      let vertMirrored = position.mirrorVertically
      let vertMirroredFen = vertMirrored.fen(alwaysShowEnPassantSquare = true)

      # echo vertMirroredFen.toPosition.debugString
      # echo vertMirrored.debugString

      # assert false

      check vertMirroredFen.toPosition == vertMirrored

      # # Test horizontal mirror
      # let horizMirrored = position.mirrorHorizontally
      # let horizMirroredFen = horizMirrored.fen
      # check horizMirroredFen.toPosition == horizMirrored

      # # Test rotation
      # let rotated = position.rotate
      # let rotatedFen = rotated.fen
      # check rotatedFen.toPosition == rotated

  # test "Transform properties":
  #   for fen in someFens:
  #     let position = fen.toPosition

  #     # Test that horizontal mirror is its own inverse
  #     check position == position.mirrorHorizontally.mirrorHorizontally

  #     # Test that vertical mirror is its own inverse
  #     check position == position.mirrorVertically.mirrorVertically

  #     # Test that rotation twice equals horizontal + vertical mirror
  #     let rotatedTwice = position.rotate.rotate
  #     let hvMirrored = position.mirrorHorizontally.mirrorVertically
  #     check rotatedTwice == hvMirrored

  # test "Zobrist keys after transforms":
  #   for fen in someFens:
  #     let position = fen.toPosition

  #     # Verify that transforms with key calculation maintain key consistency
  #     let vertMirrored = position.mirrorVertically(skipKeyCalculation = false)
  #     check vertMirrored.zobristKeysAreOk

  #     let horizMirrored = position.mirrorHorizontally(skipKeyCalculation = false)
  #     check horizMirrored.zobristKeysAreOk

  # test "Color swapping in vertical mirror":
  #   let testFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
  #   let position = testFen.toPosition

  #   # Test with color swapping (default)
  #   let mirrored = position.mirrorVertically(swapColors = true)
  #   check mirrored.us != position.us

  #   # Test without color swapping
  #   let mirroredNoSwap = position.mirrorVertically(swapColors = false)
  #   check mirroredNoSwap.us == position.us

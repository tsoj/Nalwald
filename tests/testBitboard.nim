import unittest
import ../src/bitboard
import ../src/types

suite "Bitboard Tests":

  test "toBitboard and toSquare":
    # Test noSquare
    check noSquare.toBitboard == 0.Bitboard
    check 0.Bitboard.toSquare == noSquare

  test "mirrorVertically":
    # Test specific squares
    let bb1 = a1.toBitboard
    let mirrored1 = bb1.mirrorVertically
    check mirrored1 == a8.toBitboard

    let bb2 = h1.toBitboard
    let mirrored2 = bb2.mirrorVertically
    check mirrored2 == h8.toBitboard

    # Test that double mirroring returns original
    let original = (a1.toBitboard or c3.toBitboard or h7.toBitboard)
    check original.mirrorVertically.mirrorVertically == original

    # Test empty bitboard
    check 0.Bitboard.mirrorVertically == 0.Bitboard

  test "mirrorHorizontally":
    # Test specific squares
    let bb1 = a1.toBitboard
    let mirrored1 = bb1.mirrorHorizontally
    check mirrored1 == h1.toBitboard

    let bb2 = a8.toBitboard
    let mirrored2 = bb2.mirrorHorizontally
    check mirrored2 == h8.toBitboard

    # Test that double mirroring returns original
    let original = (a1.toBitboard or c3.toBitboard or h7.toBitboard)
    check original.mirrorHorizontally.mirrorHorizontally == original

    # Test empty bitboard
    check 0.Bitboard.mirrorHorizontally == 0.Bitboard

  test "isPassedMask":
    # Test that passed pawn masks include the correct files
    let whiteMask = isPassedMask(white, d4)
    check whiteMask.isSet(d5) == true  # Same file, ahead
    check whiteMask.isSet(c5) == true  # Left file, ahead
    check whiteMask.isSet(e5) == true  # Right file, ahead
    check whiteMask.isSet(d3) == false # Same file, behind
    check whiteMask.isSet(f5) == false # Too far to the right

    let blackMask = isPassedMask(black, d4)
    check blackMask.isSet(d3) == true  # Same file, ahead for black
    check blackMask.isSet(c3) == true  # Left file, ahead for black
    check blackMask.isSet(e3) == true  # Right file, ahead for black
    check blackMask.isSet(d5) == false # Same file, behind for black

  test "mask3x3":
    let mask = mask3x3(d4)

    # Should include the square itself and all adjacent squares
    check mask.isSet(d4) == true  # Center
    check mask.isSet(c3) == true  # Bottom-left
    check mask.isSet(d3) == true  # Bottom
    check mask.isSet(e3) == true  # Bottom-right
    check mask.isSet(c4) == true  # Left
    check mask.isSet(e4) == true  # Right
    check mask.isSet(c5) == true  # Top-left
    check mask.isSet(d5) == true  # Top
    check mask.isSet(e5) == true  # Top-right

    # Should not include squares further away
    check mask.isSet(b2) == false
    check mask.isSet(f6) == false

  test "mask5x5":
    let mask = mask5x5(d4)

    # Should include the 3x3 mask
    let mask3 = mask3x3(d4)
    for sq in mask3:
      check mask.isSet(sq) == true

    # Should include squares in the 5x5 area
    check mask.isSet(b2) == true
    check mask.isSet(f6) == true

    # Should not include squares outside 5x5
    check mask.isSet(a1) == false
    check mask.isSet(g7) == false

  test "homeRank":
    check homeRank(white) == ranks(a1)
    check homeRank(black) == ranks(a8)

    # Verify that home ranks contain the correct squares
    let whiteHome = homeRank(white)
    for file in 0..7:
      check whiteHome.isSet(newSquare(file, 0)) == true
      check whiteHome.isSet(newSquare(file, 7)) == false

    let blackHome = homeRank(black)
    for file in 0..7:
      check blackHome.isSet(newSquare(file, 7)) == true
      check blackHome.isSet(newSquare(file, 0)) == false

  test "mirror operations preserve bit count":
    let original = (a1.toBitboard or c3.toBitboard or e5.toBitboard or g7.toBitboard)
    let vertMirror = original.mirrorVertically
    let horizMirror = original.mirrorHorizontally

    check original.countSetBits == vertMirror.countSetBits
    check original.countSetBits == horizMirror.countSetBits

    # Test that mirroring twice gives back original
    check original == vertMirror.mirrorVertically
    check original == horizMirror.mirrorHorizontally

  test "passed pawn mask edge cases":
    # Test corner squares
    let whiteA1 = isPassedMask(white, a1)
    check whiteA1.isSet(a2) == true  # Same file ahead
    check whiteA1.isSet(b2) == true  # Adjacent file ahead
    check whiteA1.isSet(h2) == false # Too far away

    let blackH8 = isPassedMask(black, h8)
    check blackH8.isSet(h7) == true  # Same file ahead (for black)
    check blackH8.isSet(g7) == true  # Adjacent file ahead (for black)
    check blackH8.isSet(a7) == false # Too far away

  test "mask functions with edge squares":
    # Test 3x3 mask for corner
    let cornerMask = mask3x3(a1)
    check cornerMask.isSet(a1) == true
    check cornerMask.isSet(a2) == true
    check cornerMask.isSet(b1) == true
    check cornerMask.isSet(b2) == true
    check cornerMask.countSetBits == 4  # Only 4 squares available from corner

    # Test 5x5 mask for corner
    let corner5x5 = mask5x5(a1)
    check corner5x5.countSetBits == 9  # Limited by board edge

    # Test masks don't extend beyond board
    let edgeMask = mask3x3(a4)  # Middle of a-file
    for sq in edgeMask:
      check sq.int8 mod 8 <= 2  # Should not extend beyond c-file

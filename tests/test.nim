# sodiumoxid/tests/test.nim
import unittest

# A simple function to test
proc add(a, b: int): int =
  result = a + b

# Another simple function
proc isEven(n: int): bool =
  n mod 2 == 0

suite "Math Functions":
  test "add function":
    check add(2, 3) == 5
    check add(-1, 1) == 0
    check add(0, 0) == 0

  test "isEven function":
    check isEven(4) == true
    check isEven(7) == false
    check isEven(0) == true
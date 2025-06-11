# sodiumoxid/tests/test.nim
import unittest

# A simple function to test
proc add(a, b: int): int =
  result = a + b

# Another simple function
proc isEven(n: int): bool =
  debugEcho "Hello?"
  n mod 2 == 0

suite "Math Functions":
  test "add function":
    check add(2, 3) == 5
    check add(-1, 1) == 0
    check add(0, 0) == 0
    check add(1000, 2000) == 3000
    check add(-5, -10) == -15

  test "isEven function":
    check isEven(4) == true
    check isEven(7) == false
    check isEven(0) == true
    check isEven(100) == true
    check isEven(99) == false
    check isEven(1) == false
    check isEven(-2) == true
    check isEven(-3) == false

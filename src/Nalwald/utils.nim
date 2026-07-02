import std/times

type Seconds* = distinct float

func `$`*(a: Seconds): string =
  $a.float & " s"

func high*(T: typedesc[Seconds]): Seconds =
  float.high.Seconds
func low*(T: typedesc[Seconds]): Seconds =
  float.low.Seconds

func `==`*(a, b: Seconds): bool {.borrow.}
func `<=`*(a, b: Seconds): bool {.borrow.}
func `<`*(a, b: Seconds): bool {.borrow.}

func `-`*(a, b: Seconds): Seconds {.borrow.}
func `+`*(a, b: Seconds): Seconds {.borrow.}
func `*`*(a: Seconds, b: SomeNumber): Seconds =
  Seconds(a.float * b.float)
func `*`*(a: SomeNumber, b: Seconds): Seconds =
  Seconds(a.float * b.float)
func `/`*(a: Seconds, b: SomeNumber): Seconds =
  Seconds(a.float / b.float)

func `+=`*(a: var Seconds, b: Seconds) =
  a = a + b
func `-=`*(a: var Seconds, b: Seconds) =
  a = a - b
func `*=`*(a: var Seconds, b: SomeNumber) =
  a = a * b
func `/=`*(a: var Seconds, b: SomeNumber) =
  a = a / b

func secondsSince1970*(): Seconds =
  {.cast(noSideEffect).}:
    epochTime().Seconds

proc randU64*(): uint64 =
  func rotl(x: uint64, k: int): uint64 =
    (x shl k) or (x shr (64 - k))

  var
    s0 {.global.} = 10532447193056740057u64
    s1 {.global.} = 15725061932195978535u64

  result = rotl(s0 + s1, 17) + s0
  s1 = s1 xor s0
  s0 = rotl(s0, 49) xor s1 xor (s1 shl 21)
  s1 = rotl(s1, 28)

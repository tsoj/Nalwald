import
  ../position,
  ../types,
  ../perft,
  ../searchUtils,
  ../hashTable,
  ../moveIterator,
  ../positionUtils,
  ../evaluation,
  ../utils,
  ../timeManagedSearch,
  ../see,
  exampleFens,
  testPerft

import std/[random, strutils, sequtils, terminal, options, strformat]

const
  maxNumPerftNodes {.intdefine.} = int.high
  useInternalFens {.booldefine.} = true
  useExternalFens {.booldefine.} = false

proc testFen(): Option[string] =
  for fen in someFens:
    if fen != fen.toPosition.fen[0 ..< fen.len]:
      return some fmt"{fen} != {fen.toPosition.fen}"

proc getPerftTestData(): seq[tuple[position: Position, nodes: seq[int]]] =
  var lines =
    if useInternalFens:
      perftFens.toSeq
    else:
      @[]

  var file: File
  if useExternalFens and file.open("./perft_test.txt"):
    var line: string
    while file.readLine(line):
      if line.isEmptyOrWhitespace:
        continue
      lines.add(line)
    file.close

  for line in lines:
    var words = line.split(',')
    doAssert words.len >= 1
    result.add (position: words[0].toPosition, nodes: newSeq[int](0))
    for i in 1 ..< words.len:
      result[^1].nodes.add(words[i].parseInt)

# proc testPerft(): Option[string] =
#   for (fen, targetNodes) in perftFens:
#     let position = fen.toPosition
#     for i, nodesTarget in targetNodes:
#       if nodesTarget <= maxNumPerftNodes:
#         let nodes = position.perft(i)
#         if nodesTarget != nodes:
#           return some &"Perft to depth {i} for \"{fen}\" should be {nodesTarget} but is {nodes}"

proc testSearchAndPerft() =
  let start = secondsSince1970()

  var
    hashTable = newHashTable()
    testPerftState = newTestPerftState(addr hashTable)

  hashTable.setByteSize(megaByteToByte * 16)

  for (position, trueNumNodesList) in getPerftTestData():
    echo "---------------\nTesting ", position.fen
    echo "Perft test:"
    # perft test
    for depth in 1 .. trueNumNodesList.len:
      let trueNumNodes = trueNumNodesList[depth - 1]

      if trueNumNodes > maxNumPerftNodes:
        break

      let testPseudoLegality = trueNumNodes < 20_000

      let
        testPerftResult = position.runTestPerft(
          testPerftState, depth = depth.Ply, testPseudoLegality = testPseudoLegality
        )
        perftResult = position.perft(depth.Ply)

      echo testPerftResult,
        (if testPerftResult == trueNumNodes: " == " else: " != "), trueNumNodes
      doAssert testPerftResult == trueNumNodes, "Failed perft test"
      doAssert perftResult == testPerftResult, "Failed fast perft test"

    # testing real search
    echo "Search test:"
    hashTable.clear()

    let searchResult = timeManagedSearch(
      SearchInfo(
        positionHistory: @[position],
        hashTable: addr hashTable,
        moveTime: 2.Seconds,
        evaluation: evaluate,
      )
    )
    doAssert searchResult.len > 0
    doAssert searchResult[0].value in -checkmateValue(Ply.low) .. checkmateValue(
      Ply.low
    ), $searchResult[0].value
    doAssert searchResult[0].pv.len > 0
    echo "Value: ",
      searchResult[0].value, ", pv: ", searchResult[0].pv.notation(position)

  echo "---------------\nPassed time: ", secondsSince1970() - start
  echo "Finished search/perft test successfully"

proc speedPerftTest(maxNodes = 100_000_000): float =
  var nodes = 0
  let start = secondsSince1970()
  for lines in someFens:
    let
      words = lines.split ','
      position = words[0].toPosition
    var depth = 0
    while depth + 1 < words.len and words[depth + 1].parseBiggestInt <= maxNodes:
      depth += 1
    nodes += position.perft(depth.Ply)
  let time = secondsSince1970() - start
  nodes.float / time.float

proc runTests*(
    maxNodes = int64.high,
    useInternal = true,
    useExternal = true,
    testSee = true,
    testPerftSearch = true,
    testPerftSpeed = true,
) =
  doAssert "QQQQQQBk/Q6B/Q6Q/Q6Q/Q6Q/Q6Q/Q6Q/KQQQQQQQ w - - 0 1".toPosition.legalMoves.len ==
    265

  echo fmt"{maxNumPerftNodes = }"
  echo fmt"{useInternalFens = }"
  echo fmt"{useExternalFens = }"

  if testSee:
    echo "---------------"
    styledEcho styleBright, "SEE test:"
    seeTest()

  if testPerftSearch:
    echo "---------------"
    styledEcho styleBright, "Search and perft test:"
    testSearchAndPerft()

  if testPerftSpeed:
    echo "---------------"
    styledEcho styleBright,
      "Speed perft test: ",
      resetStyle,
      $int(speedPerftTest(maxNodes) / 1000.0),
      styleItalic,
      " knps"
    echo getCpuInfo()

  echo "---------------"
  styledEcho styleBright, fgGreen, "Finished all tests successfully"

when isMainModule:
  runTests()

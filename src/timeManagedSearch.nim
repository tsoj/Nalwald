import types, move, position, hashTable, rootSearch, evaluation, utils

import std/[atomics, sets]

export Pv

type MoveTime = object
  maxTime, approxTime: Seconds

func calculateMoveTime(
    moveTime, timeLeft, incPerMove: Seconds, movesToGo, halfmovesPlayed: int16
): MoveTime =
  doAssert movesToGo >= 0
  let
    estimatedGameLength = 70
    estimatedMovesToGo = max(20, estimatedGameLength - halfmovesPlayed div 2)
    newMovesToGo = max(2, min(movesToGo, estimatedMovesToGo))

  result.maxTime = min(timeLeft / 2, moveTime)
  result.approxTime = incPerMove + timeLeft / newMovesToGo

  if incPerMove >= 2.Seconds or timeLeft > 180.Seconds:
    result.approxTime = result.approxTime * 1.2
  elif incPerMove < 0.2.Seconds and timeLeft < 30.Seconds:
    result.approxTime = result.approxTime * 0.8
    if movesToGo > 2:
      result.maxTime = min(timeLeft / 4, moveTime)

type SearchInfo* #[ {.requiresInit.} ]# = object
  stopFlag*: ptr Atomic[bool] = nil
  positionHistory*: seq[Position]
  hashTable*: ptr HashTable
  targetDepth*: Ply = Ply.high
  movesToGo*: int = int.high
  increment*: array[white .. black, Seconds] = [white: 0.Seconds, black: 0.Seconds]
  timeLeft*: array[white .. black, Seconds] = [white: Seconds.high, black: Seconds.high]
  moveTime*: Seconds = Seconds.high
  maxNodes*: int = int.high
  numThreads*: int = 1
  multiPv*: int = 1
  searchMoves*: HashSet[Move] = initHashSet[Move]()
  evaluation*: proc(position: Position): Value {.noSideEffect.}# = evaluate # TODO default eval breaks Nim

iterator iterativeTimeManagedSearch*(
    searchInfo: SearchInfo
): tuple[pvList: seq[Pv], nodes: int64, passedTime: Seconds] =
  var
    stopFlag: Atomic[bool]
    externalStopFlag =
      if searchInfo.stopFlag == nil:
        addr stopFlag
      else:
        searchInfo.stopFlag

  stopFlag.store(false)

  doAssert searchInfo.positionHistory.len >= 1,
    "Need at least the current position in positionHistory"

  let
    position = searchInfo.positionHistory[^1]
    calculatedMoveTime = calculateMoveTime(
      searchInfo.moveTime,
      searchInfo.timeLeft[position.us],
      searchInfo.increment[position.us],
      searchInfo.movesToGo.clampToType(int16),
      position.halfmovesPlayed.clampToType(int16),
    )

  let start = secondsSince1970()
  var
    startLastIteration = secondsSince1970()
    branchingFactors = newSeq[float](searchInfo.targetDepth.int)
    lastNumNodes = int64.high

  var iteration = -1
  for (pvList, nodes, canStop) in iterativeDeepeningSearch(
    positionHistory = searchInfo.positionHistory,
    hashTable = searchInfo.hashTable[],
    externalStopFlag = externalStopFlag,
    targetDepth = searchInfo.targetDepth,
    numThreads = searchInfo.numThreads,
    maxNodes = searchInfo.maxNodes,
    stopTime = start + calculatedMoveTime.maxTime,
    multiPv = searchInfo.multiPv,
    searchMoves = searchInfo.searchMoves,
    evaluation = searchInfo.evaluation,
  ):
    iteration += 1
    let
      totalPassedTime = secondsSince1970() - start
      iterationPassedTime = (secondsSince1970() - startLastIteration)
    startLastIteration = secondsSince1970()

    yield (pvList: pvList, nodes: nodes, passedTime: iterationPassedTime)

    doAssert calculatedMoveTime.approxTime >= 0.Seconds

    branchingFactors[iteration] = nodes.float / lastNumNodes.float
    lastNumNodes = if nodes <= 100_000: int64.high else: nodes
    var averageBranchingFactor = branchingFactors[iteration]
    if iteration >= 4:
      averageBranchingFactor =
        (
          branchingFactors[iteration] + branchingFactors[iteration - 1] +
          branchingFactors[iteration - 2] + branchingFactors[iteration - 3]
        ) / 4.0

    let estimatedTimeNextIteration = iterationPassedTime * averageBranchingFactor
    if estimatedTimeNextIteration + totalPassedTime > calculatedMoveTime.approxTime and
        iteration >= 4:
      break

    if searchInfo.timeLeft[position.us] < Seconds.high and canStop:
      break

proc timeManagedSearch*(searchInfo: SearchInfo): seq[Pv] =
  for (pvList, nodes, passedTime) in iterativeTimeManagedSearch(searchInfo):
    result = pvList

import
  std/[atomics, cpuinfo, os, random, sequtils, strformat, strutils, terminal, times]

import nimchess

import ../hashtable, ../rootsearch, ../version, ../utils
import openings, dashboard

const
  hardNodeLimit = 20_000
  softNodeLimit = 5_000
  datagenHashSizeMB = defaultHashSizeMB

proc playGame(
    opening: Position,
    hashTable: var HashTable,
    gameIndex: int,
    dashboard: ptr Dashboard,
): Game =
  result = newGame(
    event = "Nalwald datagen",
    date = now().format("yyyy'.'MM'.'dd"),
    round = $gameIndex,
    white = "Nalwald " & versionOrId(),
    black = "Nalwald " & versionOrId(),
    startPosition = opening,
  )
  hashTable.clear

  var stopFlag: Atomic[bool]
  while not result.isGameOver(
    claimFiftyMoveRule = true, claimThreefoldRepetition = true
  )
  :
    stopFlag.store(false)
    let moverIsWhite = result.currentPosition.us == white
    let (move, value, nodes) = search(
      GoParams(
        game: result,
        searchMoves: result.currentPosition.legalMoves,
        limit: Limit(nodes: hardNodeLimit),
        stopFlag: addr stopFlag,
      ),
      hashTable,
      softNodes = softNodeLimit,
      printUciInfo = false,
    )
    doAssert not move.isNoMove
    let
      score = if value == 0: 0.0 else: value.float # avoid negative zero
      annotation = (if score >= 0: "+" else: "") & score.formatFloat(ffDecimal, 2)
    result.addMove(move, annotation)

    dashboard[].recordSearchedPosition(nodes)
    dashboard[].updateLiveView(
      $result.currentPosition,
      if moverIsWhite:
        score
      else:
        -score,
    )

  if result.result == "*":
    # Game ended by a claimable draw rule (50 move rule or threefold
    # repetition), which addMove doesn't apply automatically.
    result.result = "1/2-1/2"
    result.headers["Result"] = result.result

type DatagenThreadParams = object
  targetGames: int
  rootPosition: Position
  pgnFileName: string
  seed: int64
  dashboard: ptr Dashboard

proc datagenThread(params: DatagenThreadParams) {.thread.} =
  {.cast(gcsafe).}:
    var
      rng = initRand(params.seed)
      hashTable = newHashTable()
    hashTable.setByteSize(datagenHashSizeMB * megaByte)

    while true:
      let gameIndex = params.dashboard[].claimGameIndex()
      if gameIndex >= params.targetGames:
        break

      let
        opening = rng.nextOpening(params.rootPosition)
        game = playGame(opening, hashTable, gameIndex + 1, params.dashboard)

      let file = open(params.pgnFileName, fmAppend)
      file.write game.toPgnString & "\n"
      file.close

      params.dashboard[].recordFinishedGame(game.result, game.moves.len)

proc datagen*(targetGames: int, numThreads: int) =
  when not defined(datagenAllowDirtyGit):
    doAssert not gitHasUnstagedChanges,
      "datagen must be compiled without unstaged git changes"

  doAssert targetGames >= 1, "targetGames must be at least 1"
  doAssert numThreads >= 1, "numThreads must be at least 1"

  let
    rootPosition = classicalStartPos
    launchDate = now()
    outDir =
      "res/data/datagen-" & shortCommitHash() & "-" &
      launchDate.format("yyyy-MM-dd-HH-mm-ss")

  if dirExists(outDir) or fileExists(outDir):
    raise newException(IOError, "Datagen output folder already exists: " & outDir)
  createDir outDir

  writeFile(
    outDir / "settings.txt",
    &"""git commit: {commitHash()}
compile date: {compileDate()}
launch date: {launchDate.format("yyyy-MM-dd HH:mm:ss")}
threads: {numThreads}
target games: {targetGames}
hard node limit: {hardNodeLimit}
soft node limit: {softNodeLimit}
hash size: {datagenHashSizeMB} MB (shared by both sides of a game, cleared between games)
adjudication: none (games end by checkmate, stalemate, insufficient material, 50 move rule, threefold repetition)
root opening position: {rootPosition.fen} (classical)
initial opening random plies: {initialOpeningRandomPlies}
score annotation: pawns from the perspective of the side to move
""",
  )

  echo fmt"Writing datagen games to {outDir}/"

  initOpenings()

  let
    useDashboard = isatty(stdout)
    baseSeed = (secondsSince1970() * 1000.0).int64

  var dashboard: Dashboard
  dashboard.initDashboard(targetGames, startTime = secondsSince1970())

  var threads = newSeq[Thread[DatagenThreadParams]](numThreads)
  for i in 0 ..< numThreads:
    createThread(
      threads[i],
      datagenThread,
      DatagenThreadParams(
        targetGames: targetGames,
        rootPosition: rootPosition,
        pgnFileName: outDir / fmt"games-thread-{i}.pgn",
        seed: baseSeed + i,
        dashboard: addr dashboard,
      ),
    )

  if useDashboard:
    var prevFrameLines = 0
    stdout.hideCursor

    proc redraw() =
      let frame = dashboard.frame()
      if prevFrameLines > 0:
        stdout.write "\x1b[" & $prevFrameLines & "F\x1b[J"
      stdout.write frame & "\n"
      stdout.flushFile
      prevFrameLines = frame.splitLines.len

    while threads.anyIt(it.running):
      redraw()
      sleep 1000
    redraw()
    stdout.showCursor

  joinThreads threads

  echo fmt"Finished datagen: {dashboard.numFinishedGames()} games written to {outDir}/"

when isMainModule:
  const usage = "Usage: datagen <targetGames> [numThreads]"
  let params = commandLineParams()
  if params.len notin 1 .. 2:
    quit usage
  try:
    let
      targetGames = parseInt(params[0])
      numThreads =
        if params.len >= 2:
          parseInt(params[1])
        else:
          countProcessors()
    datagen(targetGames, numThreads)
  except ValueError:
    quit usage

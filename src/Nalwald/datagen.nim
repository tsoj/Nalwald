import std/[atomics, locks, os, random, sets, strformat, strutils, times]

import nimchess

import hashtable, rootsearch, version

const
  hardNodeLimit = 20_000
  softNodeLimit = 5_000
  initialOpeningRandomPlies = 8
  datagenHashSizeMB = defaultHashSizeMB

var
  openingsLock: Lock
  knownOpenings: HashSet[string]
  consecutiveOpeningSkips = 0
  openingRandomPlies = initialOpeningRandomPlies
  claimedGames: Atomic[int]
  finishedGames: Atomic[int]

proc randomOpening(
    rng: var Rand, rootPosition: Position, plies: int
): Option[Position] =
  var position = rootPosition
  for _ in 1 .. plies:
    let moves = position.legalMoves
    if moves.len == 0:
      return none Position
    position = position.doMove(rng.sample(moves))

  if position.legalMoves.len == 0 or position.insufficientMaterial:
    return none Position

  position.halfmovesPlayed = 0
  position.halfmoveClock = 0
  some position

proc nextOpening(rng: var Rand, rootPosition: Position): Position =
  while true:
    var plies: int
    withLock openingsLock:
      plies = openingRandomPlies

    let opening = rng.randomOpening(rootPosition, plies)
    if opening.isNone:
      continue

    let position = opening.get

    var isNew = false
    withLock openingsLock:
      if position.fen in knownOpenings:
        consecutiveOpeningSkips += 1
        if consecutiveOpeningSkips >= 2:
          openingRandomPlies += 1
          consecutiveOpeningSkips = 0
      else:
        knownOpenings.incl position.fen
        consecutiveOpeningSkips = 0
        isNew = true

    if isNew:
      return position

proc playGame(opening: Position, hashTable: var HashTable, gameIndex: int): Game =
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
    let (move, value, _) = search(
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

proc datagenThread(params: DatagenThreadParams) {.thread.} =
  {.cast(gcsafe).}:
    var
      rng = initRand(params.seed)
      hashTable = newHashTable()
    hashTable.setByteSize(datagenHashSizeMB * megaByte)

    while true:
      let gameIndex = claimedGames.fetchAdd(1)
      if gameIndex >= params.targetGames:
        break

      let
        opening = rng.nextOpening(params.rootPosition)
        game = playGame(opening, hashTable, gameIndex + 1)

      let file = open(params.pgnFileName, fmAppend)
      file.write game.toPgnString & "\n"
      file.close

      let numFinished = finishedGames.fetchAdd(1) + 1
      echo fmt"Finished game {numFinished}/{params.targetGames}: {game.result} ({game.moves.len} moves)"

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
      "datagen-" & shortCommitHash() & "-" & launchDate.format("yyyy-MM-dd-HH-mm-ss")

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

  initLock openingsLock
  claimedGames.store(0)
  finishedGames.store(0)

  let baseSeed = (epochTime() * 1000.0).int64
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
      ),
    )
  joinThreads threads

  echo fmt"Finished datagen: {finishedGames.load} games written to {outDir}/"

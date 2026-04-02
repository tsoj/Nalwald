import std/[times, strutils]
import nimchess
import nimchess/perft
import version, rootSearch

const benchFens = [
  "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
  "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
  "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1",
  "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
  "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8",
  "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10",
]

proc benchCommand(game: var Game, params: seq[string]) =
  let depth =
    if params.len >= 1:
      try:
        parseInt(params[0])
      except ValueError:
        4
    else:
      4
  var totalNodes: int64 = 0
  let start = epochTime()
  for fen in benchFens:
    totalNodes += fen.toPosition.perft(depth)
  let elapsed = epochTime() - start
  let nps =
    if elapsed > 0.0:
      int(totalNodes.float / elapsed)
    else:
      0
  echo totalNodes, " nodes ", nps, " nps"

var uciServer* = newUciServer(
  name = "Nalwald " & versionOrId(),
  author = "Jost Triller",
  options = [
    EngineOption(name: "Hash", kind: eotSpin, defaultInt: 16, minVal: 1, maxVal: 512),
    EngineOption(name: "Threads", kind: eotSpin, defaultInt: 1, minVal: 1, maxVal: 1),
  ],
  onGo = search,
  onSetOption = nil,
  onNewGame = nil,
  onQuit = nil,
  customCommands = [
    CustomCommand(
      name: "bench",
      helpText: "bench [depth] -- Run benchmark positions",
      handler: benchCommand,
    )
  ],
)

# uciServer.uciLoop()

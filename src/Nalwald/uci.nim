import nimchess
import version, rootSearch

var uciServer* = newUciServer(
  name = "Nalwald " & versionOrId(),
  author = "Jost Triller",
  options = [],
  onGo = search,
  onSetOption = nil,
  onNewGame = nil,
  onQuit = nil,
  customCommands = [],
)

# uciServer.uciLoop()

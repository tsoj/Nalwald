import std/[os, strutils]
import nimchess
import Nalwald/uci

if paramCount() >= 1:
  uci.uciServer.runCommand(commandLineParams().join(" "))
else:
  uci.uciServer.uciLoop()

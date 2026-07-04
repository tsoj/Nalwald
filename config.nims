# begin Nimble config (version 2)
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"
# end Nimble config

import std/strutils
import src/Nalwald/version

# Common flags
switch("cc", "clang")
switch("mm", "arc")
switch("define", "useMalloc")
# switch("passL", "-lm")

when defined(buildDebug):
  switch("define", "release")
  switch("debugger", "native")
  switch("passC", "-fno-omit-frame-pointer -g")
else:
  # Shared by default (nimble build), release, and modern
  switch("panics", "on")
  switch("define", "danger")

  switch("passC", "-flto")
  switch("passL", "-flto")

  when defined(windows):
    switch("passL", "-fuse-ld=lld")

  when defined(buildRelease):
    switch("passL", "-static")

  when defined(buildModern):
    doAssert not defined(buildGeneric), "buildGeneric and buildModern are exclusive"
    switch("passC", "-mbmi2")
    switch("passC", "-mpopcnt")

  when not defined(buildModern) and not defined(buildGeneric):
    switch("passC", "-march=native -mtune=native")

var binaryName = projectName()
when defined(buildRelease):
  binaryName &= "-" & versionOrId()
when defined(buildDebug):
  binaryName &= "-debug"
when defined(buildModern):
  binaryName &= "-modern"

for i in 1 .. paramCount():
  let p = paramStr(i)
  if p.startsWith("--out:"):
    binaryName = p.split(":")[1]
    break
  elif p.startsWith("-o:"):
    binaryName = p[3 ..^ 1]
    break

switch("out", binaryName)

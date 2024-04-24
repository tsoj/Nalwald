import src/version

#!fmt: off

# Default flags
--mm:arc
--define:useMalloc
--passL:"-static"
--cc:clang
--threads:on
--styleCheck:hint

func lto() =
  --passC:"-flto"
  --passL:"-flto"

  if defined(windows):
    --passL:"-fuse-ld=lld"

func highPerformance() =
  --panics:on  
  --define:danger
  lto()

func lightDebuggerInfo() =
  --passC:"-fno-omit-frame-pointer -g"

func fullDebuggerInfo() =
  lightDebuggerInfo()
  --debugger:native

let
  projectNimFile = "src/Nalwald.nim"
  suffix = if defined(windows): ".exe" else: ""
  binDir = "bin/"

proc setBinaryName(name: string) =
  switch("o", binDir & name & suffix)

task debug, "debug compile":
  --define:debug
  --passC:"-O2"
  fullDebuggerInfo()
  setBinaryName(projectName() & "-debug")
  setCommand "c", projectNimFile

task checks, "checks compile":
  --define:release
  fullDebuggerInfo()
  setBinaryName(projectName() & "-checks")
  setCommand "c", projectNimFile

task profile, "profile compile":
  highPerformance()
  fullDebuggerInfo()
  setBinaryName(projectName() & "-profile")
  setCommand "c", projectNimFile

task default, "default compile":
  lightDebuggerInfo()
  highPerformance()
  setBinaryName(projectName())
  setCommand "c", projectNimFile

task native, "native compile":
  highPerformance()
  --passC:"-march=native"
  --passC:"-mtune=native"
  setBinaryName(projectName() & "-native")
  setCommand "c", projectNimFile

task modern, "BMI2 and POPCNT compile":
  highPerformance()
  --passC:"-mbmi2"
  --passC:"-mpopcnt"
  setBinaryName(projectName() & "-modern")
  setCommand "c", projectNimFile

task tests, "Runs tests":
  --define:release
  fullDebuggerInfo()
  setBinaryName("tests")
  setCommand "c", "src/tests.nim"

#!fmt: on

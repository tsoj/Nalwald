import version
import distros

--panics:on
--gc:arc
--define:useMalloc
--passC:"-flto"
--passL:"-flto"
--passL:"-static"
--cc:clang
--threads:on
--styleCheck:hint

if defined(windows):
    --passL:"-fuse-ld=lld"

let suffix = if defined(windows): ".exe" else: ""
let name = projectName() & "-" & version()

task debug, "debug compile":
    --define:release
    --passC:"-fno-omit-frame-pointer -g"
    switch("o", name & "-debug" & suffix)
    setCommand "c"

task default, "default compile":
    --define:danger
    switch("o", name & suffix)
    setCommand "c"

task native, "native compile":
    --define:danger
    --passC:"-march=native"
    --passC:"-mtune=native"
    switch("o", name & "-native" & suffix)
    setCommand "c"

task modern, "BMI2 and POPCNT compile":
    --define:danger
    --passC:"-mbmi2"
    --passC:"-mpopcnt"
    switch("o", name & "-modern" & suffix)
    setCommand "c"
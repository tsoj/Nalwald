import version
import distros

--define:danger
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

task default, "default compile":
    switch("o", name & "-default" & suffix)
    setCommand "c"

task native, "native compile":
    --passC:"-march=native"
    --passC:"-mtune=native"
    switch("o", name & "-native" & suffix)
    setCommand "c"

task modern, "BMI2 and POPCNT compile":
    --passC:"-mbmi2"
    --passC:"-mpopcnt"
    switch("o", name & "-modern" & suffix)
    setCommand "c"
import std/[
    strutils,
    options
]

export options

const
    gitHasUnstagedChanges = "nothing to commit, working tree clean" notin staticExec("git status")
    gitHash = staticExec("git rev-parse HEAD").strip
    gitShortHash = staticExec("git rev-parse --short HEAD").strip
    gitTag = staticExec("git tag --points-at HEAD").strip

func compileDate*(): string = CompileDate & " " & CompileTime & " (UTC)"

func compileYear*(): string = CompileDate.split('-')[0]

func version*(): Option[string] =
    when not gitTag.isEmptyOrWhitespace and not gitHasUnstagedChanges:
        some(gitTag)
    
func id(): string =
    result = gitShortHash
    when gitHasUnstagedChanges:
        const d = CompileDate.split('-')
        const t = CompileTime.split(':')
        result &= "-" & d[0] & d[1] & d[2] & t[0] & t[1] & t[2]

func versionOrId*(): string =
    version().get(otherwise = id())

func commitHash*(): string =
    result = gitHash
    when gitHasUnstagedChanges:
        result &= " + unstaged changes"

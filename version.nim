import strutils


const gitHasUnstagedChanges = "nothing to commit, working tree clean" notin staticExec("git status")
const gitHash = staticExec("git rev-parse HEAD").strip
const gitTag = staticExec("git tag --points-at HEAD").strip

func version*(): string =
    when gitTag == "":
        "dev"
    else:
        gitTag

func compileDate*(): string = CompileDate & " " & CompileTime & " (UTC)"

func compileYear*(): string = CompileDate.split('-')[0]

func commitHash*(): string =
    result = gitHash
    when gitHasUnstagedChanges:
        result &= " + unstaged changes"

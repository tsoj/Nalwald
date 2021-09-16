import strutils

func version*(): string = "14"
func compileDate*(): string = CompileDate & " " & CompileTime & " (UTC)"
func compileYear*(): string = CompileDate.split('-')[0]

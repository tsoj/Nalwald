import strutils

func version*(): string = "16.TODO"
func compileDate*(): string = CompileDate & " " & CompileTime & " (UTC)"
func compileYear*(): string = CompileDate.split('-')[0]

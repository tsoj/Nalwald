import strutils

func version*(): string = "1.11.1"#TODO
func compileDate*(): string = CompileDate & " " & CompileTime
func compileYear*(): string = CompileDate.split('-')[0]

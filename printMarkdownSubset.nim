import std/[
    terminal
]


proc printMarkdownSubset*(markdown: string) =

    var
        markdown = "\n" & markdown
        isTitle = false
        isInlineCode = false
        isCodeBlock = false
        isBright = false
        isItalic = false
        currentString = ""

    func popFront(s: var string) =
        if s.len >= 1:
            s = s[1..^1]
        else:
            s = ""

    proc printCurrentString() =
        stdout.resetAttributes()
        if isCodeBlock or isInlineCode:
            stdout.setStyle {styleDim}

        if isItalic:
            stdout.setStyle {styleItalic}

        if isBright:
            stdout.setStyle {styleBright}

        if isTitle:
            stdout.setStyle {styleBright, styleUnderscore}

        stdout.write currentString
        stdout.resetAttributes()
        currentString = ""

    while markdown.len > 0:

        if markdown[0] == '\n':
            printCurrentString()
            isTitle = false
            stdout.write "\n"
            markdown.popFront
            if isCodeBlock and markdown.len > 0:
                stdout.write "    "
            elif markdown.len > 1 and not isInlineCode:
                if markdown[0] == '#':
                    isTitle = true
        
        elif markdown.len >= 2 and markdown[0..1] == "**":
            printCurrentString()
            isBright = not isBright
            markdown.popFront
            markdown.popFront

        elif markdown[0] == '*':
            printCurrentString()
            isItalic = not isItalic
            markdown.popFront

        elif markdown.len > 0 and markdown[0..2] == "```":
            printCurrentString()
            isCodeBlock = not isCodeBlock
            markdown.popFront
            markdown.popFront
            markdown.popFront

        elif markdown[0] == '`':
            printCurrentString()
            isInlineCode = not isInlineCode
            markdown.popFront

        else:
            currentString &= markdown[0]
            markdown.popFront
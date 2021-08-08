import
    terminal,
    unicode

func toRune*(s: string): Rune =
    doAssert s.runeLen == 1
    s.runeAt(0)

type Framebuffer* = object
    buffer: seq[seq[Rune]]
    width, height: int
    transparentRune: Rune

func width*(framebuffer: Framebuffer): int = framebuffer.width
func height*(framebuffer: Framebuffer): int = framebuffer.height

func clear*(framebuffer: var Framebuffer, fillWith = " ".toRune) =
    for line in framebuffer.buffer.mitems:
        for rune in line.mitems:
            rune = fillWith

proc newFramebuffer*(transparentRune = "\0".toRune): Framebuffer =
    result.transparentRune = transparentRune
    result.height = terminalHeight()
    result.width = terminalWidth()
    result.buffer.setLen(result.height)
    for line in result.buffer.mitems:
        line.setLen(result.width)
    result.clear()

proc print*(framebuffer: Framebuffer) =
    hideCursor()
    doAssert framebuffer.buffer.len == terminalHeight()
    doAssert framebuffer.buffer.len == framebuffer.height
    for index, line in framebuffer.buffer.pairs:
        doAssert line.len == terminalWidth()
        doAssert line.len == framebuffer.width
        setCursorPos(0, index)
        stdout.write($line)
    stdout.flushFile()
    showCursor()

func add*(framebuffer: var Framebuffer, image: openArray[seq[Rune]], x, y: int) =
    for yOffset, line in image.pairs:
        if y + yOffset < 0 or y + yOffset >= framebuffer.height:
            continue
        for xOffset, rune in line.pairs:
            if x + xOffset < 0 or x + xOffset >= framebuffer.width:
                continue
            if rune != framebuffer.transparentRune:
                framebuffer.buffer[y + yOffset][x + xOffset] = image[yOffset][xOffset]

func add*(framebuffer: var Framebuffer, image: seq[Rune] or Rune, x, y: int) =
    framebuffer.add(@[image], x, y)
import
    terminal,
    deques,
    threadpool

proc catchInput(inputQueue: ptr Deque[char], quitChars: seq[char]): bool =
    while true:
        let c = getch()
        inputQueue[].addLast c
        if c in quitChars:
            break

type InputCatcher* = object
    inputQueue: Deque[char]
    thread: FlowVar[bool]

proc `=destroy`(x: var InputCatcher) =
    discard ^x.thread
    `=destroy`(x.inputQueue)
    `=destroy`(x.thread)

proc start*(inputCatcher: var InputCatcher, quitChars: openArray[char]) =
    var qc: seq[char]
    qc.add quitChars
    inputCatcher.thread = spawn catchInput(addr inputCatcher.inputQueue, qc)

iterator get*(inputCatcher: var InputCatcher): char =
    while inputCatcher.inputQueue.len > 0:
        yield inputCatcher.inputQueue.popFirst()

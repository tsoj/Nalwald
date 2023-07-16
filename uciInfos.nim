import
    version,
    printMarkdownSubset

import std/[
    terminal,
    strformat,
    strutils
]

proc printSeperatorLine() =
    styledEcho {styleDim}, "-----------------------------------------"

proc printCommandBulletPoint(command: string) =
    styledEcho {styleDim}, "* ", resetStyle, {styleItalic}, command


proc help*(params: openArray[string]) =
    if params.len == 0:
        printSeperatorLine()
        echo "Possible commands:"
        printCommandBulletPoint "uci"
        printCommandBulletPoint "setoption"
        printCommandBulletPoint "isready"
        printCommandBulletPoint "position"
        printCommandBulletPoint "go"
        printCommandBulletPoint "stop"
        printCommandBulletPoint "quit"
        printCommandBulletPoint "ucinewgame"
        printCommandBulletPoint "moves"
        printCommandBulletPoint "print"
        printCommandBulletPoint "printdebug"
        printCommandBulletPoint "fen"
        printCommandBulletPoint "perft"
        printCommandBulletPoint "test"
        printCommandBulletPoint "eval"
        printCommandBulletPoint "piecevalues"
        printCommandBulletPoint "about"
        printCommandBulletPoint "help"
        echo "Use 'help <command>' to get info about a specific command"
        printSeperatorLine() 
    else:
        printSeperatorLine()
        case params[0]:
        of "uci":
            echo(
                "Tells engine to use the uci (universal chess interface). ",
                "After receiving the uci command the engine will identify itself with the 'id' command ",
                "and send the 'option' commands to inform which settings the engine supports if any. ",
                "After that the engine will sent 'uciok' to acknowledge the uci mode."
            )
        of "setoption":
            styledEcho {styleBright}, "setoption name <id> [value <x>]"
            echo(
                "This can be used to change the internal setting <id> to ",
                "the value <x>. For a setting with the 'button' type no value is needed. ",
                "Some examples:"
            )
            echo "'setoption name Hash value 512'"
            echo "'setoption name Threads value 8'"
            echo "'setoption name UCI_Chess960 value true'"
        of "isready":
            echo "Sends a ping to the engine that will be shortly answered with 'readyok' if the engine is still alive."
        of "position":
            styledEcho {styleBright}, "position [fen <fenstring> | startpos] moves <move_1> ... <move_i>"
            echo(
                "Sets up the position described in by <fenstring> on the internal board and ",
                "plays the moves <move_1> to <move_i> on the internal chess board. ",
                "To start from the start position the string 'startpos' must be sent instead of 'fen <fenstring>'. ",
                "If this position is from a different game than ",
                "the last position sent to the engine, the command 'ucinewgame' should be sent inbetween."
            )
        of "go":
            styledEcho {styleBright}, "go [wtime|btime|winc|binc|movestogo|movetime|depth|infinite [<x>]]..."
            echo(
                "Starts calculating on the current position set up with the 'position' command. ",
                "There are a number of commands that can follow this command, all will be sent as arguments ",
                "of the same command. ",
                "If one command is not sent its value will not influence the search."
            )
            printCommandBulletPoint "wtime <x>"
            echo "    White has <x> msec left on the clock."
            printCommandBulletPoint "btime <x>"
            echo "    Black has <x> msec left on the clock."
            printCommandBulletPoint "winc <x>"
            echo "    White has <x> msec increment per move."
            printCommandBulletPoint "binc <x>"
            echo "    Black has <x> msec increment per move."
            printCommandBulletPoint "movestogo <x>"
            echo "    There are <x> moves to the next time control. If this is not sent sudden death is assumed."
            printCommandBulletPoint "depth <x>"
            echo "    Search to <x> plies only."
            printCommandBulletPoint "movetime <x>"
            echo "    Search for exactly <x> msec."
            printCommandBulletPoint "infinite"
            echo "    Search until the 'stop' or 'quit' command."
            echo "Example:"
            echo "'go depth 35 wtime 60000 btime 60000 winc 1000 binc 1000'"
            echo(
                "Starts a search to a maximum of depth 35 and assumes that the ",
                "time control is 1 min + 1 second per move."
            )
        of "stop":
            echo "Stops the calculation as soon as possible."
        of "quit":
            echo "Quits the program as soon as possible."
        of "ucinewgame":
            echo "This is sent to the engine when the next search should be assumed to be from a different game."
        of "moves":
            styledEcho {styleBright}, "moves <move_1> ... <move_i>"
            echo(
                "Plays the moves <move_1> to <move_i> on the internal chess board. The keyword 'moves' can also be",
                " omitted: If all moves are detected to be legal they will be played on the internal board."
            )
            echo "Example:"
            echo "'e2e4 c7c6 d2d4 d7d5' will have the same effect as 'moves e2e4 c7c6 d2d4 d7d5'"
        of "print":
            echo "Prints the current internal board."
        of "printdebug":
            echo "Prints the internal representation of the current board."
        of "fen":
            echo "Prints the FEN notation of the current internal board."    
        of "perft":
            styledEcho {styleBright}, "perft <x> [fast]"
            echo(
                "Calculates the perft of the current position to depth <x>. ",
                "If 'fast' is added, no node counts for root moves are printed. ",
                "Instead printed will be final node count and time needed for the most optimized perft function."
            )
        of "test":
            styledEcho {styleBright}, "test [<x>] [nozobrist|pseudo|onlytxt]..."
            echo(
                "Runs SEE and perft tests. ",
                "If a file 'perft_test.txt' exists then the positions from that file will be included."
            )
            printCommandBulletPoint "<x>"
            echo "    Run perft test only to a maximum of <x> nodes per position."
            printCommandBulletPoint "nozobrist"
            echo "    Don't do zobrist key tests."
            printCommandBulletPoint "pseudo"
            echo "    Do tests for the pseudo legality function."
            printCommandBulletPoint "nointernal"
            echo "    Don't use the internal test positions."
            printCommandBulletPoint "noexternal"
            echo "    Don't use the positions given in 'perft_test.txt'."
            echo "Example:"
            echo "'test 100000 nozobrist nointernal'"
            echo(
                "Runs perft only up to 100000 nodes per positions, doesn't do zobrist key test and only ",
                "uses positions from 'perft_test.txt'."
            )
        of "eval":
            echo "Prints the static evaluation value for the current internal position."
        of "piecevalues":
            echo "Prints the values for each piece type."
        of "about":
            styledEcho {styleBright}, "about [extra]"
            echo "Prints some info about the program. When 'extra' is added, additional information will be provided."
        of "help":
            styledEcho {styleBright}, "help [<command>]"
            echo "Prints all possible commands, or if <command> is given, then help about <command> is printed."
        else:
            echo "Unknown command: ", params[0]
        
        printSeperatorLine()

proc printLogo*() =

    echo fmt"---------------- Nalwald ----------------"
    echo fmt"       __,      o     n_n_n   ooooo    + "
    echo fmt" o    // o\    ( )    \   /    \ /    \ /"
    echo fmt"( )   \  \_>   / \    |   |    / \    ( )"
    echo fmt"|_|   /__\    /___\   /___\   /___\   /_\"
    echo fmt"------------ by Jost Triller ------------"

proc about*(extra = true) =
    const readme = readFile("README.md")
    printSeperatorLine()
    echo "Nalwald ", version()
    echo "Compiled at ", compileDate()
    echo "Copyright © 2016-", compileYear() , " by Jost Triller"
    echo "git hash: ", commitHash()
    printSeperatorLine()
    if extra:
        printMarkdownSubset readme
        printSeperatorLine()
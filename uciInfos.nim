import version

proc help*(params: openArray[string]) =
    if params.len <= 1:
        echo "Possible commands:"
        echo "* uci"
        echo "* setoption"
        echo "* isready"
        echo "* position"
        echo "* go"
        echo "* stop"
        echo "* quit"
        echo "* ucinewgame"
        echo "* moves"
        echo "* print"
        echo "* printdebug"
        echo "* fen"
        echo "* perft"
        echo "* test"
        echo "* eval"
        echo "* about"
        echo "Use 'help <command>' to get info about a specific command"
    else:
        echo "-----------------------------------------"
        case params[1]:
        of "uci":
            echo(
                "Tells engine to use the uci (universal chess interface). ",
                "After receiving the uci command the engine will identify itself with the 'id' command ",
                "and send the 'option' commands to inform which settings the engine supports if any. ",
                "After that the engine will sent 'uciok' to acknowledge the uci mode."
            )
        of "setoption":
            echo "setoption name <id> [value <x>]"
            echo(
                "This can be used to change the internal setting <id> to ",
                "the value <x>. For a setting with the 'button' type no value is needed. ",
                "Some examples:"
            )
            echo "'setoption name Hash value 512'"
            echo "'setoption name UCI_Chess960 value true'"
        of "isready":
            echo "Sends a ping to the engine that will be shortly answered with 'readyok' if the engine is still alive."
        of "position":
            echo "position [fen <fenstring> | startpos] moves <move_1> ... <move_i>"
            echo(
                "Sets up the position described in fenstring on the internal board and ",
                "plays the moves <move_1> to <move_i> on the internal chess board. ",
                "To start from the start position the string 'startpos' must be sent instead of 'fen <fenstring>. ",
                "If this position is from a different game than ",
                "the last position sent to the engine, the command 'ucinewgame' should be sent inbetween."
            )
        of "go":
            echo "go [wtime|btime|winc|binc|movestogo|movetime|depth|infinite [<x>]]..."
            echo(
                "Starts calculating on the current position set up with the 'position' command. ",
                "There are a number of commands that can follow this command, all will be sent as arguments ",
                "of the same command. ",
                "If one command is not sent its value will not influence the search."
            )
            echo "* wtime <x>"
            echo "White has <x> msec left on the clock."
            echo "* btime <x>"
            echo "Black has <x> msec left on the clock."
            echo "* winc <x>"
            echo "White has <x> msec increment per move."
            echo "* binc <x>"
            echo "Black has <x> msec increment per move."
            echo "* movestogo <x>"
            echo "There are <x> moves to the next time control. If this is not sent sudden death is assumed."
            echo "* depth <x>"
            echo "Search to <x> plies only."
            echo "* movetime <x>"
            echo "Search for exactly <x> msec."
            echo "* infinite"
            echo "Search until the 'stop' or 'quit' command."
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
            echo "moves <move_1> ... <move_i>"
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
            echo "perft <x>"
            echo "Calculates the perft of the current position to depth <x>."
        of "test":
            echo "test [<x>] [nozobrist|pseudo|onlytxt]..."
            echo(
                "Runs SEE and perft tests. ",
                "If a file 'perft_test.txt' exists then the positions from that file will be included."
            )
            echo "* <x>"
            echo "Run perft test only to a maximum of <x> nodes per position."
            echo "* nozobrist"
            echo "Don't do zobrist key tests."
            echo "* pseudo"
            echo "Do tests for the pseudo legality function."
            echo "* onlytxt"
            echo "Use only the positions given in 'perft_test.txt' and not the internal test positions."
            echo "Example:"
            echo "'test 100000 nozobrist onlytxt'"
            echo(
                "Runs perft only up to 100000 nodes per positions, doens't do zobrist key test and only ",
                "uses positions from 'perft_test.txt'."
            )
        of "eval":
            echo "Prints the static evaluation value for the current internal position."
        of "about":
            echo "Just some info about Nalwald. Also, feel free to take a look at my gitlab repos: gitlab.com/tsoj :)"
        else:
            echo "Unknown command: ", params[1]
        
        echo "-----------------------------------------"


proc about*() =
    echo(
        "-----------------------------------------\n",
        "Nalwald ", version(), "\n",
        "Compiled at ", compileDate(), "\n",
        "Copyright (c) 2016-", compileYear() , " by Jost Triller\n",
        "\n",
        "Nalwald is a Super GM level chess engine\n",
        "for classical and fischer random chess.\n",
        "It supports the UCI, so it can be used in\n",
        "most chess GUIs (e.g. Cutechess, Arena).\n",
        "Nalwald is written in the programming\n",
        "language Nim, which is a compiled\n",
        "language with an intuitive and clean\n",
        "syntax.\n",
        "I started programming in 2016. After the\n",
        "well-known \"Hello World\" program, my\n",
        "first big project was jht-chess, a chess\n",
        "playing program with an console GUI. I\n",
        "used C++ but it looked more like messy C.\n",
        "In hindsight I would say that it is hard\n",
        "to write worse spaghetti code than I did\n",
        "then, but it played well enough to win\n",
        "against amateur chess players. Since then\n",
        "I wrote multiple chess engine, most in\n",
        "C++ (jht-chess, zebra-chess, jht-chess 2,\n",
        "squared-chess, Googleplex Starthinker)\n",
        "but also one in Rust (Hactar) and now\n",
        "also in Nim. While my first engine could\n",
        "barely beat me (and I am not a very\n",
        "good chess player, and much less in\n",
        "2016), today maybe Nalwald could even\n",
        "beat Magnus Carlsen.\n",
        "On this way from a at best mediocre chess\n",
        "program to a chess engine that could win\n",
        "against the best human players, the\n",
        "chessprogamming.org wiki was of great\n",
        "help many times. From there I got most\n",
        "ideas for search improvements (move\n",
        "ordering, transposition table, LMR, etc.).\n",
        "At the beginning the Wikipedia article\n",
        "\"Schachprogramm\" was really important\n",
        "for my understand of chess programming.\n",
        "During the development of Nalwald I also\n",
        "introduced some techniques that I believe\n",
        "are novelties (king contextual PSTs,\n",
        "fail-high delta pruning, futility\n",
        "reductions, hash result futility pruning).\n",
        "Anyway, have fun using Nalwald!\n",
        "-----------------------------------------"
    )
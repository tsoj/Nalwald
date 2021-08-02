import terminal

const asteroidMiddleTemplates = [
    [
        "OOOOOOO",
        "OOOOOOO"
    ],
    [
        "OOOOOOO",
        "OOOOOO "
    ],
    [
        "OOOOOOO",
        " OOOOOO"
    ],
    [
        "OOOOOOO",
        " OOOOO "
    ],
    [
        "OOOOOO ",
        " OOOOOO"
    ],
    [
        " OOOOOO",
        "OOOOOO "
    ],
    [
        "OOOOOO ",
        "OOOOOOO"
    ],
    [
        " OOOOOO",
        "OOOOOOO"
    ],
    [
        " OOOOO ",
        "OOOOOOO"
    ]
]

const asteroidTopTemplates = [
    " OOOOO ",
    "  OOOO ",
    " OOOO  ",
    "   OOO ",
    "  OOO  ",
    " OOO   "
]

type Asteroid = object
    image: array[4, string]

discard getch()
discard getch()
discard getch()
discard getch()
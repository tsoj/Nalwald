import unicode

const asteroidMiddleTemplates* = [
    [
        "OOOOOOO".toRunes,
        "OOOOOOO".toRunes
    ],
    [
        "OOOOOOO".toRunes,
        "OOOOOO`".toRunes
    ],
    [
        "OOOOOOO".toRunes,
        "`OOOOOO".toRunes
    ],
    [
        "OOOOOOO".toRunes,
        "`OOOOO`".toRunes
    ],
    [
        "OOOOOO`".toRunes,
        "`OOOOOO".toRunes
    ],
    [
        "`OOOOOO".toRunes,
        "OOOOOO`".toRunes
    ],
    [
        "OOOOOO`".toRunes,
        "OOOOOOO".toRunes
    ],
    [
        "`OOOOOO".toRunes,
        "OOOOOOO".toRunes
    ],
    [
        "`OOOOO`".toRunes,
        "OOOOOOO".toRunes
    ]
]
const asteroidTopTemplates* = [
    "`OOOOO`".toRunes,
    "``OOOO`".toRunes,
    "`OOOO``".toRunes,
    "```OOO`".toRunes,
    "``OOO``".toRunes,
    "`OOO```".toRunes
]
const asteroidBigMiddleTemplates* = [
    [
        "OOOOOOOOO".toRunes,
        "OOOOOOOOO".toRunes
    ],
    [
        "OOOOOOOOO".toRunes,
        "OOOOOOOO`".toRunes
    ],
    [
        "OOOOOOOOO".toRunes,
        "`OOOOOOOO".toRunes
    ],
    [
        "OOOOOOOOO".toRunes,
        "`OOOOOOO`".toRunes
    ],
    [
        "OOOOOOOO`".toRunes,
        "`OOOOOOOO".toRunes
    ],
    [
        "`OOOOOOOO".toRunes,
        "OOOOOOOO`".toRunes
    ],
    [
        "OOOOOOOO`".toRunes,
        "OOOOOOOOO".toRunes
    ],
    [
        "`OOOOOOOO".toRunes,
        "OOOOOOOOO".toRunes
    ],
    [
        "`OOOOOOO`".toRunes,
        "OOOOOOOOO".toRunes
    ]
]
const asteroidBigTopTemplates* = [
    # "`OOOOOOO`".toRunes,
    # "``OOOOOO`".toRunes,
    # "`OOOOOO``".toRunes,
    "```OOOOO`".toRunes,
    "``OOOOO``".toRunes,
    "`OOOOO```".toRunes,
    "```OOOO``".toRunes,
    "``OOOO```".toRunes
]
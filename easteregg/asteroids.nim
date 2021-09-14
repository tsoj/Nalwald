import
    framebuffer,
    inputCatcher,
    ecm,
    asteroidTemplates,
    unicode,
    random,
    os,
    times,
    strformat,
    options

type
    Image = object
        data: seq[seq[Rune]]
    Vec2 = object
        x, y: float
    Position = object
        x, y: float
    Velocity = object
        x, y: float
    Asteroid = distinct int
    Star = distinct int
    Player = object
        score: int
    BulletMagazine = object
        last: DateTime
        refillTime: Duration
        content: int
        capacity: int
    Bullet = object
        whoShot: Entity
    RenderPriority = 0..3
    Exhaust = object
        offsets: seq[(int, int)]
    Timer = object
        activation: DateTime
        duration: Duration
    Dust = object
        chancePerSec: float
    Box = object
        pos: Position
        dims: Vec2

const transparentRune = "`".toRune

const dustRune = "·".toRune

proc asteroidImage(): Image =
    if rand(1.0) < 0.8:
        result.data.add asteroidTopTemplates[rand(asteroidTopTemplates.high)]
        result.data.add asteroidMiddleTemplates[rand(asteroidMiddleTemplates.high)]
        result.data.add asteroidTopTemplates[rand(asteroidTopTemplates.high)]
    else:
        result.data.add asteroidBigTopTemplates[rand(asteroidBigTopTemplates.high)]
        if rand(1.0) < 0.5:
            result.data.add asteroidBigMiddleTemplates[rand(asteroidBigMiddleTemplates.high)][0]
        elif rand(1.0) < 0.2:
            result.data.add asteroidBigMiddleTemplates[rand(asteroidBigMiddleTemplates.high)]
        result.data.add asteroidBigMiddleTemplates[rand(asteroidBigMiddleTemplates.high)]
        result.data.add asteroidBigTopTemplates[rand(asteroidBigTopTemplates.high)]

    for line in result.data.mitems:
        for rune in line.mitems:
            if rune == "O".toRune:
                if rand(1.0) < 0.3:
                    rune = "o".toRune
                elif rand(1.0) < 0.2:
                    rune = "0".toRune

const spaceshipImg = Image(data: @[
    "``Λ``".toRunes,
    "`/^\\`".toRunes,
    "/___\\".toRunes,
    "`^^^`".toRunes
])

const bulletImg = Image(data: @["▲".toRunes])
const bulletExhaust = Exhaust(offsets: @[(0,1)])
proc exhaustRune(): Rune =
    const possibleRunes = [
        "*".toRune,
        "^".toRune,
        "'".toRune,
        "ʼ".toRune,
        "˟".toRune,
        "΅".toRune,
        "\"".toRune,
        "´".toRune
    ]
    possibleRunes[rand(possibleRunes.high)]

proc starImage(): Image =
    result.data = @[".".toRunes]
    if rand(1.0) < 0.05:
        result.data[0] = "✦".toRunes

const spaceshipMaxVelocity = Velocity(x: 20.0, y: 15.0)
const starVelocity = Velocity(x: 0.0, y: spaceshipMaxVelocity.y)
proc asteroidVelocity(): Velocity = Velocity(x: rand(-7.0..7.0), y: rand(10.0..15.0))
const bulletVelocity = Velocity(x: 0.0, y: -20.0)

const bulletMagazineStartCapacity = 6
const bulletMagazineStartContent = min(6, bulletMagazineStartCapacity)
const bulletMagazineRefillTime = initDuration(seconds = 1)

func isOk(img: Image): bool =
    if img.data.len == 0:
        return false
    for line in img.data:
        if line.len != img.data[0].len:
            return false
    true

func width(img: Image): int =
    doAssert img.data.len > 0
    doAssert img.isOk
    img.data[0].len

func height(img: Image): int =
    img.data.len

func colliding(posA, posB: Position, imgA, imgB: Image): bool =
    let
        xA = posA.x.int
        yA = posA.y.int
        xB = posB.x.int
        yB = posB.y.int

        left = max(xA, xB)
        right = min(xA + imgA.width - 1, xB + imgB.width - 1)
        top = max(yA, yB)
        bottom = min(yA + imgA.height - 1, yB + imgB.height - 1)

    template getRune(img: Image, xImg, yImg, xAt, yAt): Rune =
        let
            x = xAt - xImg
            y = yAt - yImg            

        doAssert y >= 0
        doAssert y < img.data.len
        doAssert x >= 0
        doAssert x < img.data[0].len

        img.data[y][x]

    for x in left..right:
        for y in top..bottom:
            if imgA.getRune(xA, yA, x, y) != transparentRune and
            imgB.getRune(xB, yB, x, y) != transparentRune:
                return true
    false

proc randomPositionInBox(b: Box): Position =
    result.x = rand(b.pos.x..(b.pos.x + b.dims.x)).int.float
    result.y = rand(b.pos.y..(b.pos.y + b.dims.y)).int.float

func physics(ecm: var EntityComponentManager, delta: Duration) =
    let deltaS = delta.inMicroseconds.float / 1_000_000.0
    forEach(ecm, p: var Position, v: Velocity):
        p.x += v.x * deltaS
        p.y += v.y * deltaS

proc draw(ecm: EntityComponentManager, fb: var Framebuffer) =
    fb.clear()
    let fbPtr = addr fb
    for renderPriority in RenderPriority.low..RenderPriority.high:
        forEach(ecm, p: Position, img: Image, rp: RenderPriority):
            if rp == renderPriority:
                fbPtr[].add(img.data, x = p.x.int, y = p.y.int)
        forEach(ecm, p: Position, exhaust: Exhaust, rp: RenderPriority):
            if rp == renderPriority:
                for (xOffset, yOffset) in exhaust.offsets:
                    fbPtr[].add(exhaustRune(), x = p.x.int + xOffset, y = p.y.int + yOffset)

proc addAsteroid(ecm: var EntityComponentManager, box: Box) =
    let entity = ecm.addEntity()
    ecm.add(entity, Asteroid(0))
    ecm.add(entity, RenderPriority(2))
    ecm.add(entity, asteroidImage())
    var box = box
    box.dims.x -= ecm[entity, Image].width.float
    box.dims.y -= ecm[entity, Image].height.float
    ecm.add(entity, randomPositionInBox(box))
    ecm.add(entity, asteroidVelocity())

proc addStar(ecm: var EntityComponentManager, box: Box) =
    let entity = ecm.addEntity()
    ecm.add(entity, Star(0))
    ecm.add(entity, RenderPriority(1))
    ecm.add(entity, starImage())
    ecm.add(entity, randomPositionInBox(box))
    ecm.add(entity, starVelocity)    

func screenBox(fb: Framebuffer): Box =
    result.pos.x = 0.0
    result.dims.x = fb.width.float
    result.pos.y = 0.0
    result.dims.y = fb.height.float

func aboveScreenBox(fb: Framebuffer, doubleHeight = false): Box =
    result = fb.screenBox
    result.pos.y = -fb.height.float
    if doubleHeight:
        result.pos.y *= 2.0
        result.dims.y *= 2.0

proc respawner(ecm: var EntityComponentManager, fb: Framebuffer) =
    var removeQueue: seq[Entity]
    for entity in ecm.iter(Position):
        doAssert ecm.has(entity)
        if ecm[entity, Position].y.int > fb.height:
            doAssert ecm.has(entity)
            removeQueue.add entity
    
    let spawnBox = fb.aboveScreenBox()
    while removeQueue.len > 0:
        let entity = removeQueue.pop()
        doAssert ecm.has(entity)
        if ecm.has(entity, Asteroid):
            ecm.addAsteroid(spawnBox)
        if ecm.has(entity, Star):
            ecm.addStar(spawnBox)
        ecm.remove(entity)

func limitPlayer(ecm: var EntityComponentManager, box: Box) =
    let box = box
    forEach(ecm, player: Player, p: var Position, img: Image):
        p.x = clamp(p.x, box.pos.x, box.pos.x + box.dims.x - img.width.float)
        p.y = clamp(p.y, box.pos.y, box.pos.y + box.dims.y - img.height.float)

proc addBullet(ecm: var EntityComponentManager, spaceshipPos: Position, spaceshipImg: Image, whoShot: Entity) =
    let entity = ecm.addEntity()
    ecm.add(entity, Bullet(whoShot: whoShot))
    ecm.add(entity, RenderPriority(1))
    ecm.add(entity, bulletImg)
    ecm.add(entity, bulletExhaust)
    ecm.add(entity, bulletVelocity)
    ecm.add(entity, Position(
        x: spaceshipPos.x + spaceshipImg.width.float / 2.0,
        y: spaceshipPos.y
    ))
    ecm.add(entity, Timer(
        activation: now(),
        duration: initDuration(seconds = 10)
    ))

func centerPosition(fb: Framebuffer, img: Image): Position =
    Position(
        x: (fb.width div 2 - img.width div 2).float,
        y: (fb.height div 2 - img.height div 2).float
    )

proc addPlayer(ecm: var EntityComponentManager, pos: Position): Entity =
    result = ecm.addEntity()
    ecm.add(result, Player(score: 0))
    ecm.add(result, RenderPriority(3))
    ecm.add(result, spaceshipImg)
    ecm.add(result, pos)
    ecm.add(result, Velocity(x: 0.0, y: 0.0))
    ecm.add(result, BulletMagazine(
        last: now(),
        content: bulletMagazineStartContent,
        refillTime: bulletMagazineRefillTime,
        capacity: bulletMagazineStartCapacity
    ))

proc refillBulletMagazin(ecm: var EntityComponentManager) =
    forEach(ecm, bulletMagazine: var BulletMagazine):
        if now() - bulletMagazine.last > bulletMagazine.refillTime:
            bulletMagazine.content = min(bulletMagazine.capacity, bulletMagazine.content + 1)
            bulletMagazine.last = now()

proc removeTimers(ecm: var EntityComponentManager) =
    var removeQueue: seq[Entity]
    for entity in ecm.iter(Timer):
        if now() - ecm[entity, Timer].activation > ecm[entity, Timer].duration:
            removeQueue.add entity
    while removeQueue.len > 0:
        ecm.remove(removeQueue.pop())

func collidingWithAsteroid(ecm: EntityComponentManager, entity: Entity): Option[Entity] =
    if ecm.has(entity, (Image, Position)):
        for asteroidEntity in ecm.iter(Asteroid, Image, Position):
            if colliding(
                posA = ecm[entity, Position],
                imgA = ecm[entity, Image],
                posB = ecm[asteroidEntity, Position],
                imgB = ecm[asteroidEntity, Image]
            ):
                return some(asteroidEntity)
    none(Entity)

proc makeToDust(
    ecm: var EntityComponentManager,
    entity: Entity,
    chancePerSec = 0.8,
    timeout = initDuration(seconds = 10)
) =
    doAssert ecm.has(entity, Image)
    for line in ecm[entity, Image].data.mitems:
        for rune in line.mitems:
            if rune != transparentRune:
                rune = dustRune
    ecm.add(entity, Timer(
        activation: now(),
        duration: timeout
    ))
    ecm.add(entity, Dust(chancePerSec: chancePerSec))
    if ecm.has(entity, RenderPriority):
        ecm[entity] = RenderPriority(0)

proc bulletHits(ecm: var EntityComponentManager, respawnBox: Box) =
    var removeQueue: seq[Entity]
    for entity in ecm.iter(Bullet, Image, Position):
        let collidingAsteroid = ecm.collidingWithAsteroid(entity)
        if collidingAsteroid.isSome:
            let whoShot = ecm[entity, Bullet].whoShot
            removeQueue.add entity
            removeQueue.add collidingAsteroid.get()
            if ecm.has(whoShot, Player):
                ecm[whoShot, Player].score += 1
    while removeQueue.len > 0:
        let entity = removeQueue.pop()
        if ecm.has(entity, Asteroid):
            ecm.addAsteroid(respawnBox)
            ecm.remove(entity, Asteroid)
            ecm.makeToDust(entity)
        else:
            ecm.remove(entity)

proc processDust(ecm: var EntityComponentManager, delta: Duration) =
    let deltaS = delta.inMicroseconds.float / 1_000_000.0
    forEach(ecm, dust: Dust, img: var Image):
        for line in img.data.mitems:
            for rune in line.mitems:
                if rune == dustRune and dust.chancePerSec * deltaS > rand(1.0):
                    rune = transparentRune

proc getInfoImage(score: int, bulletMagazine: BulletMagazine): Image =
    doAssert bulletMagazine.content <= bulletMagazine.capacity
    var infoString = "Score: " & fmt"{score:>5}" & "┃"
    for i in 0..<bulletMagazine.content:
        infoString &= "▲"
    for i in bulletMagazine.content..<bulletMagazine.capacity:
        infoString &= "△"
    infoString &= "┃"
    let line1 = infoString.toRunes
    var line2 = line1
    line2[^1] = "┛".toRune
    for i, rune in line2.mpairs:
        if i == line2.len - 1:
            continue
        if rune == "┃".toRune:
            rune = "┻".toRune
        else:
            rune = "━".toRune
    Image(data: @[line1, line2])

func getEndImage(score: int): Image =
    result = Image(data: @[
        "╔════════════════════╗".toRunes,
        "║┌┬┐┬ ┬┌─┐  ┌─┐┬ ┬┌─╮║".toRunes,
        "║ │ ├─┤├─   ├─ │╲││ │║".toRunes,
        "║ ┴ ┴ ┴└─┘  └─┘┴ ┴└─╯║".toRunes,
        "╚══════╦══════╦══════╝".toRunes,
        ("```````║" & fmt"{score:^6}" & "║```````").toRunes,
        "```````╚══════╝```````".toRunes,
        "┌────────────────────┐".toRunes,
        "│ press 'q' to quit  │".toRunes,
        "└────────────────────┘".toRunes
    ])

proc game() =
    var
        ecm: EntityComponentManager
        fb = newFramebuffer(transparentRune)
        inputCatcher: InputCatcher
        last = now()
        lastNewAsteroid = now()
        endImage: Image

    let
        quitChars = ['q', 27.char]
        numAsteroid = (fb.width * fb.height) div 300
        numStars = (fb.width * fb.height) div 50
        playerEntity = ecm.addPlayer(fb.centerPosition(spaceshipImg))
        newAsteroidDuration = initDuration(milliseconds = 50_000_000 div (fb.width * fb.height))


    for i in 1..numAsteroid:
        ecm.addAsteroid(fb.aboveScreenBox(doubleHeight = true))
    for i in 1..(numStars div 2):
        ecm.addStar(fb.screenBox)
        ecm.addStar(fb.aboveScreenBox)

    inputCatcher.start(quitChars)    
    while true:

        ecm.draw(fb)
        if ecm.has(playerEntity, Player):
            fb.add(getInfoImage(ecm[playerEntity, Player].score,ecm[playerEntity, BulletMagazine]).data, 0, 0)
        else:
            let pos = fb.centerPosition(endImage)
            fb.add(endImage.data, x = pos.x.int, y = pos.y.int)
        fb.print()

        # Don't waste CPU cycles if we don't notice a difference anyway
        while now() - last < initDuration(milliseconds = 10):
            sleep(1)
        let delta = now() - last
        last = now()        
        
        ecm.physics(delta)
        ecm.limitPlayer(fb.screenBox)
        ecm.respawner(fb)
        ecm.refillBulletMagazin()
        ecm.bulletHits(fb.aboveScreenBox)
        ecm.processDust(delta)
        ecm.removeTimers()

        if ecm.has(playerEntity, Player):
            if now() - lastNewAsteroid > newAsteroidDuration:
                lastNewAsteroid = now()
                ecm.addAsteroid(fb.aboveScreenBox())
            if ecm.collidingWithAsteroid(playerEntity).isSome():
                endImage = getEndImage(ecm[playerEntity, Player].score)
                ecm.remove(playerEntity, Player)
                ecm[playerEntity, Velocity].x *= 0.1
                ecm[playerEntity, Velocity].y = 2.0
                ecm.makeToDust(playerEntity, chancePerSec = 0.5)
        
        for input in inputCatcher.get():
            if input in quitChars:
                return

            if ecm.has(playerEntity, Player):
                case input:
                of 'a', 'd':
                    ecm[playerEntity] = Velocity(
                        x: spaceshipMaxVelocity.x * (if input == 'a': -1 else: 1),
                        y: 0.0
                    )
                of 's', 'w':
                    ecm[playerEntity] = Velocity(
                        x: 0.0,
                        y: spaceshipMaxVelocity.y * (if input == 'w': -1 else: 1)
                    )
                of ' ':
                    if ecm[playerEntity, BulletMagazine].content > 0:
                        ecm.addBullet(ecm[playerEntity, Position], ecm[playerEntity, Image], playerEntity)
                        ecm[playerEntity, BulletMagazine].content -= 1
                else:
                    discard
    echo ""

proc run*() =
    randomize()
    game()
when isMainModule:
    run()
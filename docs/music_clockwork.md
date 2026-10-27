# The Clockwork's music: ten more pieces

The Clockwork had ten pieces. Now it has twenty, in the Crown's shape:
two opening pieces, three skirmish pieces, eight full battle pieces and seven calm pieces.
The ten new ones are written in `tools/music/clock_more.py`.
Their percussion comes from `tools/music/clock_kit.py`.

Render them with `python3 tools/music/compose.py clock_battle_6` (or any other name).
The files go to `assets/music/<name>.ogg`.

## The Clockwork's theme

Every new piece is built on one short theme, the Clockwork's motif.
It has five notes: the home note, the fifth, the sharp fourth, the fifth again, and the ninth.
In C that is C, G, F sharp, G, D.
The sharp fourth and the fifth are a tick and a tock, like the escapement of a clock.
The last note is left hanging. It does not go home.

The theme changes with the mood.
In the calm pieces a music box plays it plainly.
In the skirmishes the machine repeats it, shifts it, and turns it upside down.
In the battles the whole orchestra hammers it, and its last note falls a half step, to the flat ninth. That sounds like a threat.
Only twice does it go home: at the end of The Grand Calculation, and at the end of Canon of Perfect Order.

## The owner's recordings as instruments

The owner sent eight recordings of clocks and machines.
Single hits were cut from them and are played on the grid, like drums:

- the alarm clock's tick and tock are the pulse;
- a burst of the alarm ringing is the alert;
- the old clock bell is struck as it was recorded, and it is also played at any pitch, as a tuned bell;
- three metal clangs are anvils;
- the typewriter gives three key strikes, a run of keys and its little bell;
- one turn of the crank is a ratchet;
- the spring scrape and its long ring are a texture;
- the metallic noise and the wobble are kept for later.

The typewriter's bell is also played at any pitch, as a small glassy bell.
Two new synthesised sounds join them: a choir of brass pipes with no vibrato, and a glass harmonica.

## Roles in the game

- Opening (the start of a match): The Great Escapement, Calibration. The old calm piece Winding the Spring may open a match too.
- Skirmish (a small fight): Tick, Tock, Alarm; The Watchful Gear; Pressure Rising.
- Full battle (a big fight): Cathedral of Gears; Anvil Chorus of a Thousand Hands; The Grand Calculation; and the five old battle pieces.
- Calm: The Clockmaker's Lament; Canon of Perfect Order; and the five old calm pieces.

The roles are in `scripts/music.gd` (ROLES and OPEN_CALM).
`tools/test_music_clock.gd` checks that every mood has Clockwork pieces and that every piece has its file.

## The pieces

### The Great Escapement

Opening. B minor. Four beats to the bar, 96 beats a minute. About 3 minutes.

The great machine winds up.
A real alarm clock ticks from the first second to the last.
The old bell strikes and a crank turns.
Then the gears engage, one at a time.
First a music box plays the theme, plainly.
Then a dulcimer turns in threes against the bar.
Then plucked basses turn in fives.
Then bows and typewriter keys run in sixteenths, and the horns take the theme, slowly.
The strings sing the theme, then its mirror, and a cymbal swells.
Then everything stops but the clock.
The music box plays the theme backwards, then forwards, and lands a step too low.
The crank winds again, and every gear starts at once.
Horns and trumpets play the theme in canon, held back, never at full power.
The machine locks on an open chord. One last tock.

### Calibration

Opening. E flat lydian. Five beats to the bar, counted three and two. 104 beats a minute. About 2 minutes 40.

The instruments are tuned against each other.
A harpsichord tests the home note against the sharp fourth, the theme's strangest interval.
A glass harmonica holds a high note. Typewriter keys check each beat.
The theme fits one five-beat bar exactly.
The harpsichord plays it from five different notes, each time answered.
Then a clarinet sings, and a celesta answers with the theme's first three notes, overlapping.
Then the strings tremble, and the horns play the theme very slowly through foreign keys, to B major and a long held dominant.
An alarm rings once.
Then everything returns in tune: horns with the theme, glass two octaves above, trumpets a beat behind.
It ends on one held chord, the harpsichord striking the home note, the typewriter's bell, and the clock.

### Tick, Tock, Alarm

Skirmish. D harmonic minor. Four beats to the bar, 132 beats a minute. About 3 minutes.

An alarm clock ticks in eighth notes all the way through.
Over it runs a pattern of eight notes made from the theme.
Every six bars one note of the pattern changes. Its top note climbs from E to A.
With each change a new layer joins: harpsichord, plucked basses, bows, timpani, a dulcimer one step behind, typewriter keys, horns, then a choir of pipes and trumpets.
The alarm goes off at the turns.
In the middle everything drops away: the clock, a tolling bell, the theme muted in the horns, trembling strings.
Then the last four changes, the strongest.
It never breaks into a full battle: no cymbals, no great drums.
At the end the pattern returns to where it began, and a music box plays the theme, resolved this once.
The alarm runs down, the bell strikes, one last tock.

### The Watchful Gear

Skirmish. F sharp phrygian. Eleven eighth notes to the bar, counted three, three, three and two. 300 eighth notes a minute. About 2 minutes 45.

A sentry gear turns and scans.
Bows and a dulcimer circle in elevens.
The theme fits one bar exactly: three, three, one, one, three.
Here it ends on the flat ninth, a warning.
A clarinet plays it; high glass answers with its mirror.
Then a current buzzes underneath. Muted horns call the theme's first notes over each other.
Typewriter keys mark the beats. A small bell pings at random, like a scan.
Then the gear climbs a key at a time, and the last turn of its pattern changes by a note each time.
Then the guard turns out: anvils, low brass, horns and trumpets with the theme.
Still held back: no cymbals and no great drums.
At the end the gear loses its teeth one by one, until only one note is left.
The small bell plays the theme alone. The typewriter's bell and the old bell close it.

### Pressure Rising

Skirmish. B flat minor. Nine eighth notes to the bar, counted two, two, two and three. 288 eighth notes a minute. About 2 minutes 40.

A boiler under pressure.
Pistons strike the beats, steam hisses on the long beat.
A low pattern pumps under everything.
The horns play the theme upside down.
Every twelve bars the whole machine rises a half step: B flat, B, C, C sharp, D.
Each time it rises, something joins: plucked basses, trembling strings, a choir of pipes, timpani.
At D the alarm sounds twice, and trumpets join the horns.
Then the valve opens: a long hiss of steam, the spring rings, the pressure falls back to B flat.
A music box plays the theme the right way up, slowly, resolved.
Then the pistons start again, quietly, and stop with one last strike.

### Cathedral of Gears

Full battle. C sharp minor, rising to D minor. A bar of five beats and a bar of six, an eleven-beat pair. 126 beats a minute. About 3 minutes.

A cathedral made of machinery.
The old clock bell rings changes, like church bells: six bells, the order shifting each round.
An organ holds the floor.
A choir sings the theme, stretched over one whole eleven-beat pair, with a choir of pipes an octave below.
The strings answer.
Then the brass take the theme with its threatening flat ninth, and the choir sings its mirror.
Then the gears are left alone: ticks, keys, clangs.
The theme is passed from bell to bell, one note each: glass, the small bell, the music box, the harpsichord, the old bell.
Then the whole building climbs, out of the key and up a half step, to D minor.
At the top the choir, horns and trumpets play the theme in canon, two beats apart, over the full peal, hammers and timpani.
It ends on an open chord. The theme's last note hangs in the bells.

### Anvil Chorus of a Thousand Hands

Full battle. A phrygian. Bars of seven eighth notes (two, two, three) and of eight (three, three, two). 360 eighth notes a minute. About 2 minutes 50.

A forge of a thousand hands.
It begins with one steam hammer. Then hand after hand joins, each on its own beat of the bar, until four anvils and clangs interlock.
The low brass grind a riff on the flat second.
The trumpets play the theme, short enough to fit one seven-beat bar.
Then the bar becomes three, three and two, and the strings sing a long, slow line over the forge, with a choir.
Then the forge falls quiet. The theme runs fast, at double speed, in canon in glass, celesta and the small bell.
The strings climb by half steps, everything builds.
At the climax everyone hammers the theme, a bar each: brass, then strings and choir, in turn.
Then the hands stop one by one, and everyone strikes once, together.

### The Grand Calculation

Full battle. G sharp minor. A phrase of four bars: four beats, seven eighths, five beats, three beats. 280 eighth notes a minute. About 2 minutes 45.

The machine computes.
First the theme is stated, in the low brass.
Then the theme and its mirror sound at the same time: horns upright, strings upside down.
Then the working: the old bell plays the theme backwards, the music box plays it upside down and backwards, the small bell plays it fast.
Then every form at once: slow in the choir, as written in the trumpets, mirrored in the horns, four times as fast in the glass.
At the end everyone plays the theme as one, each note struck with a hammer.
The last note goes home at last: the calculation is complete.

### The Clockmaker's Lament

Calm. F minor. Four beats to the bar, 60 beats a minute. About 2 minutes 50.

An empty workshop. One clock is still ticking.
A music box plays the theme, then a lament built on it.
Its sharp fourth, B natural against F minor, makes it strange and sad.
Then the strings take the lament, and the music box answers with the theme's first notes. The clockmaker's bell tolls, low.
Then the lament at its fullest: the strings higher, the horns with the theme slowed down, a choir of pipes.
Then the music box is alone again.
It begins to run down: each note a little later than the last. The ticking slows and stops.
The theme plays once more, very slowly, and the last note hangs. A low bell.

### Canon of Perfect Order

Calm. D flat lydian. Three half notes to the bar, 72 beats a minute. About 3 minutes 15.

The beauty of perfect order.
The tune is the theme, followed by a short answer.
A celesta plays it alone.
Then three speeds at once: the celesta at its own speed, a glass harmonica at half speed, the strings at a quarter speed.
They start together and end together.
Then the music box plays the tune upside down, over a drone, and the harpsichord rings the theme's first notes.
Then a mirror canon: the dulcimer plays the tune upright while the celesta plays it upside down, over the tune at half speed in the old clock bell.
At last the music box plays the theme, and this time it goes home.

## How the pieces were checked

Nobody listened before this was pushed, so the pieces were checked with numbers.

- Loudness: each piece is mastered to about -12.5 LUFS, like the old Clockwork and Crown pieces (they measure -11 to -14). `CSong` masters, measures and corrects until it lands within a quarter of a decibel.
- Peaks: below -0.2 dB, no clipped samples.
- Shape: loudness in every ten seconds, to make sure each piece has quiet and loud parts and its climax where it was meant.
- Balance: each instrument rendered alone, to make sure the theme is above the accompaniment.
- Harmony: each lead note was compared with the bass under it, to find wrong clashes. The ones left are wanted: the flat ninth and the sharp fourth.

## Decisions made without the owner

- Opening and skirmish pieces are named clock_battle_6 to 10, like the Crown's opening piece crown_battle_6. Their roles keep them out of the full battle.
- Winding the Spring was added as a calm piece that may open a match.
- The metallic noise and the wobble are cut but not used: they sounded more like a creature than a machine on paper, and the Brood owns that.
- No new tune for the victory sting: it stays as it was.
- compose.py rewrites scripts/music_tracks.gd only when librosa is installed (the Crown's marches need it). Here the new titles were added by hand at the end of the list, in the same form.

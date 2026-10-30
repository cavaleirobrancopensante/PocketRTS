# The Brood's music, second set

The owner asked for the rest of the Brood's music: varied and profound, combat and tense, epic, and true to the Brood.
The Brood had ten pieces. Now it has twenty, in the same shape as the Crown's.
Two pieces open a match. Three are skirmish pieces, for a lighter fight. Eight are the full battle. Seven are calm.

The new pieces are written in `tools/music/brood_more.py`.
Render them with `python3 tools/music/compose.py brood_battle_6` and so on.
They go to `assets/music/<name>.ogg`. Their titles are in `scripts/music_tracks.gd`.
Their jobs are in `scripts/music.gd`: `ROLES` and `OPEN_CALM`.
`tools/test_music_roles.gd` checks that every faction has music for every moment, and that every piece has its file.

## The Brood's sound, and what it stays away from

The Brood is the swamp. Primal, organic, ancient, alive.
Its colours are the throat choir, low and growling. Bone flutes. Log drums and an udu, a clay water-pot drum.
Big drums and taiko. Frogs, insects and bubbles. A bullroarer, a slat whirled on a cord, that roars and wobbles.
The orchestra plays too, in the Brood's colours: low brass, low horns, tremolo and spiccato strings, the big choir.
There are no trumpets and no fanfares. There is no harp, no harpsichord, no waltz. That is the Crown's court.
Nothing ticks, and nothing sits dead on the grid. That is the Clockwork.
The Brood's timing breathes. Every piece drifts a little in tempo, like breathing.
Some pieces speed up into their climax and slow down at the end. The notes are placed loosely.
The modes are dark: phrygian, phrygian dominant, locrian, aeolian with a flat second.

## The Hive Call

The Brood has a theme now, a motif of six notes. It is called the Hive Call.
It starts on a low note. It leaps up a fourth to the home note, and up a fourth again.
Then it sighs down by steps, back to the home note.
In phrygian that is: low five, one, four, flat three, flat two, one.
The rising leaps are the swarm waking. The falling sigh is the swamp settling.
It comes back in all ten pieces, and it changes each time.
In the calm pieces a flute sings it plainly and slowly.
In the skirmishes it is broken into pieces and chased: only its first three notes, climbing step by step, or turned in circles.
In the battles the whole choir roars it in long notes over the fight.
In "Night over the Drowned Wood" it is turned upside down.

## The pieces

### The Brood Wakes (brood_battle_6)

Role: opening. It plays when a match starts.
Mood: the swamp before dawn, then the eggs crack and the hive gathers. Tense under the calm.
F phrygian. 4/4. The tempo breathes from 68 up to 82 at the swell, then back down to 66.
Length: about 3:17.
It begins almost silent: insects, slow bubbles, a far bullroarer, and a throat drone that swells up from nothing.
A heartbeat starts, very soft, on a big drum.
The bone flute sings the Hive Call slowly, twice as long as usual. The low choir answers.
The answer stops on the flat second, so it hangs, unresolved.
Then the hive gathers. A log drum plays in three plus three plus two. The call is passed around: low strings, then flute, then choir.
Tremolo strings swell underneath. The flute climbs higher.
At the swell, taiko join and the choir sings the call in fourths. Horns, low strings and the flute join it.
It never breaks into a fight. It settles: half the call, a gong, and the home chord.

### The Hive Gathers (brood_battle_7)

Role: opening.
Mood: the log drums call the hive together. Restless and gathering, held under the surface.
G aeolian with a flat second. 7/4, in three plus two plus two. About 92 to 97.
Length: about 3:20.
A lone log drum plays a pattern in seven. A seed rattle marks the groups.
The low choir hums the Hive Call, one bar long, and answers it with a falling line.
Then pizzicato strings walk in seven, a bone flute sings a long line over them, and the taiko keeps the groups.
The low strings take up the call, again and again, and the horns join.
At the height the choir sings the call in two parts, the strings carry the flute's line, timpani mark the groups.
There is no cymbal crash: the fight has not come yet.
It subsides to the log drums alone, the choir hums the answer, and it ends on the home chord with a gong.

### Something in the Water (brood_battle_8)

Role: skirmish.
Mood: something hunts in the shallows. A stalk, not yet a kill.
B flat phrygian. 5/4, in three plus two. About 110 to 116.
Length: about 2:53.
A heartbeat on a low tom. A stalking ostinato on pizzicato strings and a log drum. A high string pedal that never moves.
The bone flute plays only the first three notes of the Hive Call, then waits. The choir gasps the end of it.
Frogs croak in the gaps.
Then spiccato strings join, and the head of the call climbs one step at a time, between the low strings and the flute.
Twice the whole call is sung, the second time a step higher.
Then it stops and listens: only the heartbeat, and the flute far off.
A second wave comes closer, with taiko for the heart and low horns on the call, rising.
At its height there is one great blow, and then only the heartbeat and the call fading away.

### The Scent of Blood (brood_battle_9)

Role: skirmish.
Mood: restless, on the scent, held back from the kill.
G phrygian. 7/8, in two plus two plus three. About 244 to 258 eighths a minute.
Length: about 2:47.
Low toms and a rattle. Spiccato strings in seven. A shawm, the Brood's raucous reed, calls the Hive Call.
The choir hunts with the call's first notes. The shawm plays a longer line.
Then a pedal on the flat second, high in the strings, and the call climbs in the choir, a step each time.
It loses the trail: only drums, frogs and a far flute.
It finds it again, and grows bar by bar.
At the edge, the horns play the call low, the choir sings in chords, the taiko marks every bar. Still no cymbals.
The scent goes cold. The pulse fades, the call twice more, and one last blow on the big drum.

### Circling (brood_battle_10)

Role: skirmish.
Mood: round and round the prey. Uneasy, coiled.
E flat locrian, the darkest mode, with a tritone at its heart. 4/4. About 84 to 96.
Length: about 3:00.
Tremolo strings hold the home note and its flat fifth together, the tritone. A throat drone. A heartbeat on taiko.
The bone flute circles: it plays the Hive Call starting from each of its notes in turn, round and round.
The choir circles with it, a beat behind.
Wave one rises: spiccato strings, horns, drums. Then it breaks off and listens.
Wave two is tighter and higher. The call is played fast, in quick notes, passed between flute and choir, climbing.
The choir sings the call in long notes over it.
At the last moment it pulls back: one stroke, and the call alone in the low strings. It ends on the home note.

### The Swarm at Full Cry (brood_battle_11)

Role: full battle.
Mood: the swarm at full cry. Savage and epic.
E phrygian dominant. 7/8, in two plus two plus three. About 262 to 288 eighths a minute: it speeds up into the climax.
Length: about 2:40.
A lone taiko, bullroarers and a swelling throat. The swamp holds its breath.
The choir calls the Hive Call over spiccato strings and log drums.
Then the war tune, on shawm and horns, over low brass and the choir.
A second part, the wings: strings and horns in long notes, the bone flute and then the shawm above.
A breakdown: drums, logs, frogs and the throat, the call in pieces.
Then the long build: a timpani roll, a cymbal swell, the choir begins the roar under its breath.
The climax: the whole choir roars the Hive Call in long notes, while the strings and horns play the war tune.
It rises a half step, into F, for the last round.
The coda stabs out the call with everyone together, then a final chord, a gong and the throat.

### The Queen's War-Song (brood_battle_12)

Role: full battle.
Mood: a processional, savage war-song. The Queen sends her brood to war.
F sharp phrygian. 5/4, in three plus two. About 128 to 142.
Length: about 3:15.
A lone throat choir chants, with one taiko stroke a bar. The chant ends with the Hive Call.
The swamp answers: log drums, low strings, the bigger choir.
Then low brass, spiccato strings, and a shawm doubling the chant.
The war-song itself comes on horns and strings, the second time with the full choir.
A breakdown: a lone bone flute sings the call slowly, over the udu, bone clacks and frogs.
Then the build: a timpani roll, the chant comes back in the choir, rising.
The climax: everyone. The choir roars the call in long notes. Then the chant by all. Then the war-song a half step higher, in G.
It ends with the chant once more by everyone, and a great chord.

### Ten Thousand Mouths (brood_battle_13)

Role: full battle.
Mood: one long gathering crescendo, a layer at a time, until ten thousand mouths roar.
G sharp aeolian with a flat second. 11/8, in three plus three plus three plus two. About 288 to 312 eighths a minute.
Length: about 3:30.
It is built like one long crescendo. Every eight bars a new layer joins.
First bullroarers, the throat and the udu. Then log drums, and the choir humming the Hive Call.
Then spiccato strings, frame drums, and the bone flute's chant. Then taiko and the low choir. Then low brass and horns.
Then the strings an octave up, the choir in chords, a crash. Then the shawm and the full drums.
There is one dip, a held breath, and the drums roll it back in.
Then the roar: every voice sings the Hive Call in very long notes, the chant under it.
It rises a half step for the peak. The call is stabbed out by everyone, and it ends.

### The Queen's Lullaby (brood_peace_6)

Role: calm.
Mood: the Queen sings her brood to sleep. Tender, sad and old.
F aeolian. 3/4, a rocking three. About 58, slowing to 44 at the end.
Length: about 3:04.
This is where the Hive Call is plainest. A bone flute sings it slowly, with a gentle answer.
A log drum rocks on the first beat and the third. A low drone, bubbles, the choir humming.
The choir hums the whole tune, and the flute floats a third above it.
Then the Queen's own verse, on low voices, with a halo of tremolo strings.
The call comes back in canon: the flute, and the choir one bar behind.
The verse again, on the flute, with the strings swelling under it.
The last time is slower. The flute sings the call alone, and the answer is left open.
Asleep: the start of the call, then the home chord, and a soft gong.

### Night over the Drowned Wood (brood_peace_7)

Role: calm.
Mood: night over a sunken forest. Eerie, mournful and beautiful. Slow and spacious.
G sharp phrygian. 6/4. About 52 to 56, slowing to 44 at the end.
Length: about 3:20.
Frogs, slow bubbles, a far bullroarer. Three high string notes hold, two of them a half step apart, rubbing softly.
The bone flute plays the Hive Call upside down: it falls where the call rises, and rises home at the end. A second flute echoes it across the water.
The throat choir sings a lament in slow chords.
Then the call the right way up, dark in the low strings. The flute answers it upside down.
The one swell: the strings sing the lament high, the choir opens, a gong, a bullroarer.
It dies away: the call slowly on the flute, the choir humming.
The last upside-down call comes home to the home note, and the night goes quiet.

## How it was checked

I cannot listen, so each piece was checked with numbers.
Loudness over time, in ten-second steps: each piece breathes, with quiet and loud parts, and its loudest part comes where it was meant.
The openings and skirmishes peak late but stay under the battles. The battles build to their climax in the last third.
Integrated loudness: the new pieces sit between about -12 and -13.5 LUFS. The old Brood pieces sit between -11 and -14.5, and the Crown's between -12 and -15.
No piece is clipped. True peaks are below -0.4 dBFS.
The share of each section was measured too: drums, throat, choir, strings, brass, flutes and logs.
The battles are about a third drums, a fifth brass, a sixth choir and a sixth strings.
The calm pieces are mostly flute and choir. The skirmishes lean on drums and the throat.
Every bar of every melody is checked to fill its meter exactly; a wrong bar stops the build.

## Decisions I made while the owner was away

- The openings and skirmishes are named `brood_battle_6` to `brood_battle_10`, like the Crown's `crown_battle_6` and so on. Their job comes from `ROLES`.
- The full battle pieces are `brood_battle_11` to `brood_battle_13`. They need no role.
- The calm pieces are `brood_peace_6` and `brood_peace_7`.
- "The Queen Stirs" (`brood_peace_4`) may now open a match too (`OPEN_CALM`), as the Crown's two calm openers do.
- The music player's titles stay in English, like every other piece; they are not translated.
- The test skips the Clockwork's opening and skirmish checks until its own new set, with roles, is merged.
- `compose.py --tracks` needs librosa for the Crown's marches; I wrote `music_tracks.gd` by keeping every old title and adding the ten new ones in `TRACK_ORDER`.

## The numbers

| piece | role | length | loudness (LUFS) | loudness range (LU) | true peak (dBFS) |
|---|---|---|---|---|---|
| The Brood Wakes | open | 3:17 | -12.6 | 14.6 | -0.8 |
| The Hive Gathers | open | 3:20 | -12.8 | 7.4 | -0.8 |
| Something in the Water | skirmish | 2:53 | -13.4 | 6.0 | -0.8 |
| The Scent of Blood | skirmish | 2:47 | -12.8 | 8.1 | -0.6 |
| Circling | skirmish | 3:00 | -13.2 | 10.0 | -0.9 |
| The Swarm at Full Cry | battle | 2:40 | -12.8 | 9.7 | -0.5 |
| The Queen's War-Song | battle | 3:15 | -12.8 | 10.4 | -0.5 |
| Ten Thousand Mouths | battle | 3:31 | -12.6 | 11.1 | -0.4 |
| The Queen's Lullaby | calm | 3:04 | -13.4 | 5.3 | -1.4 |
| Night over the Drowned Wood | calm | 3:22 | -13.1 | 13.8 | -1.0 |

## Whose music you hear (brood-tune, 0.24.7)

The owner, 2026-10-30: "brood music is not playing a good mix of brood, a lot of crown music is playing".

What the picker did (scripts/music.gd `_pool`, the default setting "YOUR FACTION + A LITTLE OF THE ENEMY"): every time a
piece was chosen, in EVERY moment (the opening, calm, skirmish and full battle), there was a 20% chance (`ENEMY_CHANCE`) of
playing the enemy's piece for that moment instead. So a Brood player against the Crown heard a Crown piece about one
piece in five all match long, calm music included, and the Crown's calm pieces (court and march colours) are the most
un-Brood sound there is. The rule was the same for every faction. Nothing else mixed in: the openings (`OPEN_CALM`) and
the roles are read per faction, and the web prefetch only chooses among the pool already picked.

Now (the same rule for all three factions): the opening, calm and skirmish pieces are always your own. Only in a FULL
battle (the fight hot enough for the battle pieces) is there a 20% chance of one of the enemy's battle pieces, the two
armies' music meeting. "YOUR FACTION ONLY" never plays the enemy's; "EVERYTHING" and "ONLY THE TICKED PIECES" are as
before.

Measured (tools/test_music_mix.gd, 200 picks a moment, each faction against each other one): opening, calm and
skirmish 100% own; full battle 77% to 84% own (about 80%). Before: about 80% own in every moment.

### Brood pieces that may not sound Brood (not remade in this job)

The second set (brood_battle_6 to _13, brood_peace_6 and _7, tools/music/brood_more.py) follows the rules above: dark
modes, breathing tempo, the Hive Call, no fanfares. The FIRST set (tools/music/compose.py, written before those rules)
does not always. Candidates for a redo, worst first:

- **The Queen Stirs** (brood_peace_4, compose.py `brood_peace_4`; it also OPENS matches): G **dorian** (the bright minor,
  not one of the Brood's dark modes), a square 4/4 at a steady 88 (no breathing), sections called "the anthem" and "the
  procession": the tune is sung by the choir, then played by **horn and shawm** as a march over a parade drum
  pattern and an even shaker (eighths), and the last section is the anthem by horn, choir and shawm with a drum fill.
  No Hive Call. A processional anthem on horn is the Crown's language: it most likely is the piece that "doesn't feel
  Brood". Redo: phrygian, breathing tempo, the Hive Call, throat and bone flute instead of horn, no march.
- **Moonlit Mudflats** (brood_peace_3): C **dorian**, square 4/4 at 84, a bright, tuneful bone-flute song over log
  arpeggios. The instruments are Brood but the mode and the singable tune make it pastoral; no Hive Call.
- **Mist on the Brood-Mere** (brood_peace_5): B aeolian, mostly bone flute, but with an orchestral **strings** pad and the
  big chorus: closer to the Crown's calm orchestra than the swamp. A milder case.
- **Blood Moon Rite** (brood_battle_4) and **The Hive Unleashed** (brood_battle_5): orchestral (strings, horns section,
  chorus) more than swamp (throat, logs); phrygian, so they stay dark, but the brass-and-strings battle sound is shared
  with the Crown's battles. A milder case; they play only in full battles.
- The rest of the first set (The Warm Swamp, Hunger, Spawning Pools, Teeth in the Reeds, The Swarm Rises) is throat,
  shawm, logs, choir and dark modes: Brood enough, though none carries the Hive Call.

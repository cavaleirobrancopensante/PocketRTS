# Taking a horse by the reins (0.14.98)

The owner, 2026-10-27: "I think the leash doesn't have an animation: they mount the horse and dismount and then it's leashed."
And: "Labourers can do it, but I think I was trying it with an army unit and it wasn't intuitive."

## What the player saw before

- I filmed it frame by frame: a Labourer with the LEAD button, a Labourer with a right-click, a Musketeer and an Officer with the LEAD button.
- No mount strip ever played on a LEAD order. Nobody got on the horse. That part was fine.
- But there was no moment at all. The man walked up to the horse, and on the very same frame he walked away with it.
- The horse just started to follow. The thin rein appeared at that frame. It was a dark one-pixel line, hard to see on a dark horse.
- A soldier's right-click on a horse MOUNTS it. That is what the owner saw: the Musketeer got on (the mount strip), then DISMOUNT, then LEAD. Only the LEAD button (Q) makes a soldier lead. Labourers lead on a right-click.

## What changed

- When he reaches the horse, he stops for half a second at its head (work "reins", Unit.REINS_T).
- He turns to the horse's head and reaches out. The pose is a held frame of an existing strip (Unit.REINS_POSE):
  - Labourer: his hoe and pick frame 3, the arm out.
  - Musketeer: reload frame 0, the hand raised.
  - Winder: repair frame 0, hands out.
  - Officer and Messenger: they stand still (idle).
- The horse stops and turns its head to him.
- The rein appears at that moment, his hand held out to the bridle.
- Then both walk off. With three horses in one LEAD, he pauses at each one.
- The rein is now easier to see: tan leather with a dark edge, smooth, with a little sag. It is drawn for every led horse; the second and third are tied to the saddle of the one ahead.
- Mounting is unchanged. A soldier's right-click still mounts.
- The haulers who fetch horses for the Barracks and the Foundry don't pause. They are automatic, and the pause would only slow them.
- The pause is sent to online guests (it is the man's "work"), so they see it too.

## Pictures

docs/shots/lead_anim/:
- before_labourer_lead.gif, after_labourer_lead.gif: the Labourer with the LEAD button.
- before_musketeer_lead.gif, after_musketeer_lead.gif: the Musketeer with the LEAD button.
- after_officer_lead.gif: the Officer.
- *_sheet.png: one picture every 0.2 s, for each case, before and after (also the right-clicks: labourer_click, and musketeer_click, which mounts).

Made by tools/shot_lead_anim.gd (it also prints each frame's strip, work and mounted state) and tools/lead_anim_gif.py.

## Tests

- tools/test_lead_no_mount.gd: no mount strip and no mounting on LEAD; the pause, the pose, both standing still, the horse turning; the rein from that moment; walking off with it; three horses, three pauses; a soldier's right-click still mounts.
- The horse tests still pass: test_horse_leash, test_horses, test_mount_anim, test_mount_select, the hauler tests, test_files, test_replay.

## Wanted art

A painted "take the reins" strip per facing for each man who leads (a hand out to the bridle, 3 or 4 frames), and a head toss for the horse. Logged in docs/art_style_inconsistency.md.

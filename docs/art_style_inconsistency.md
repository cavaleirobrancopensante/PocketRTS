# Code-edited art that must be redrawn by ChatGPT for a uniform style (owner decision 2026-10-24)

The legs and tools below were rebuilt IN CODE (hard pixels, the unit's own palette) to give a real gait
or a different tool. They work, but their drawing style differs a little from the ChatGPT-drawn bodies
above them (leg shape and shading, boot shape, outline weight). When the art rework resumes, each entry
gets a ChatGPT redraw of the WHOLE strip (a full body, not just legs), then the code pass is retired
(the importer entry in tools/rebuild_art.sh is removed and the source sheet installed instead).
Source snapshots of the pristine strips are in `art/redraws/gait_src/`.

## A. Legs rebuilt in code (the gait passes)

| unit | strips / views | script (tools/) | notes |
| --- | --- | --- | --- |
| Labourer | carry (gold sack), carry_keg: now the NEW walk legs pasted under the carry bodies (import_labourer_carry_legs.py); the old e/se/ne code legs are superseded: e, se, ne (west mirrored), 6 frames each | import_labourer_gait.py | stride built from contact / down / passing, near leg light, far leg dark |
| Labourer walk, all five views | DONE 2026-10-24: ChatGPT sheets (prompts 30-34: labourer_walk_east_test, _s_v3, _se_v3, _ne_v3, _n_v3), no code legs left | import_labourer_v2.py (walk_frames_v3) | the old walk_frames() code legs are unused; carry and carry_keg still have code legs (prompts 08, 09 next, same technique) |
| Missionary | walk, all five views | import_gait_missionary.py | robe-black wide trousers + boots under the hem |
| Windup Soldier (Clockwork) | walk, all five views | import_gait_windup_soldier.py | |
| Winder (Clockwork) | walk, all five views | import_gait_winder.py | |
| Armoured Musketeer (Guardsman) | walk, all five views | import_gait_musketeer_armoured.py | prompt 16 (guardsman_walk) also covers a redraw |
| Labourer (walk s, se; so also sw, carry, keg-carry, Musketeers) | 2026-10-24: the ChatGPT s / se walk sheets barely moved the feet, so the legs are the east walk's stride squeezed sideways under the body (import_labourer_stride.py): a code placeholder; ask ChatGPT for a stronger s / se stride to match | import_labourer_stride.py | the legs in these views are east-walk legs squeezed, not drawn for the view |
| Armoured Musketeer, Musketeer | 2026-10-24: legs replaced by the labourer's ChatGPT walk legs (both Musketeers' are recoloured silver-grey; his ChatGPT walk with the red plumed hat was dropped) by the labourer's ChatGPT-drawn walk legs (import_crown_legs.py, runs after the code gait pass, which is now superseded; the musket's stock and hands are kept; the north walk also gets the dismounted Cuirassier's steel back plate pasted on) | import_crown_legs.py | the armoured musketeer's code legs are gone; mixed boot style until a ChatGPT redraw |
| Raptor (Brood) | walk: s, se, ne, n (walk_e kept: a real run already) | import_gait_raptor.py | stride is small in front/back views; prompt 18 |

Shared code: tools/gait_lib.py. Audit and ranking: docs/animation_gait_audit.md (tools/audit_walk_gait.py).

## B. Tools and poses drawn or composed in code (not legs)

| what | where | script | notes |
| --- | --- | --- | --- |
| Labourer farm hoe (the pickaxe replaced by a hoe, soil debris, weight shift) | mine_s/se/e/ne/n, 4 frames | import_labourer_hoe.py | the owner liked it; ChatGPT candidate labourer_hoe_v2.png exists (not installed) |
| Labourer shovel at the Powder Mill (3 loads x 4 frames) | shovel_s/se/e/ne/n | import_labourer_shovel.py | shovel and loads drawn on the hoe bodies |
| Labourer walking with a loaded shovel at the Powder Mill (3 loads x 6 frames): the shovel strip's lift body on the new walk's legs (import_labourer_redraw.compose) | walk_shovel_s/se/e/ne/n | import_labourer_shovel_walk.py | code composite, no ChatGPT source: ask for a hand-drawn loaded-shovel walk when the labourer is redrawn |
| Labourer bury, north row (repaired in code: the sheet repeated the standing back view) | bury_n | import_labourer_v2.py (REPAIRS) | crouch + soil pile, no shovel |
| Labourer walk/idle/death repairs listed in docs/animation_audit_labourer.md | various | import_labourer_redraw.py / import_labourer_v2.py | |
| Officer and Armoured Officer idle / aim / fire / death (rotated standing body, pistol drawn in code) | branch wt-officer-pose, NOT merged yet | import_officer_poses.py | owner has not approved; prompts 10-13 exist |

- Clutch Mound (0.12.84, tools/import_mound_chatgpt.py): BUILT is the owner's ChatGPT drawing (art/redraws/clutch_mound_vent_chatgpt.png: dome with two vent chimneys, crystals, spore plume), cut off the navy and box-scaled to 74 px wide. The other three states are derived from it IN CODE and need their own ChatGPT redraw: construction (chimneys, crystals and plume cut off, washed pale and grey, 90% size), damaged (small chimney and plume knocked off, drawn dark cracks, three dark burst-sac patches, a thin green ooze), destroyed (dome squashed to about half height, darkened and browned, the big chimney lying toppled, burst sacs, bone shards). The plain mound sheets and the old Spore Vent art are archived in `old units obsolete for now/`.

## C. Still to prompt (new ids when the art rework resumes)

- Missionary walk (new prompt), Windup Soldier walk, Winder walk (new prompts; Armoured Musketeer = 16, Raptor = 18, Labourer walk/carry/keg = 07, 08, 09).
- For each, attach the CURRENT strip (the code-legged one) as the only 'what to keep: body, outfit, proportions' reference, and say: draw the whole figure including legs in one consistent style, with a real alternating gait.

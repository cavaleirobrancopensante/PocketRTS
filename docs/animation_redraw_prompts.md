# ChatGPT prompts: animation redraws (from docs/animation_audit_labourer.md and animation_audit_units.md)

Each request stands alone (attach only the references listed, at most 3). Reference files are in
reference_images.zip (4 to 5x enlarged for reading; the game sprites themselves are tiny). Ask for the
result as ONE flat PNG strip per direction on a plain flat dark navy background, frames left to right
at the same cell size as the reference, NO anti-aliasing, hard pixel edges, no text, no grid lines.

Style line used in every prompt: "pixel art, 16th to 18th century European, painted soft shading, dark
outline, the same pixel scale and palette as the reference, three-quarter top-down view like a classic RTS."

## 1. Labourer hammering (the weakest animation)
Attach: lab_build_e.png, lab_build_s.png, lab_walk_e.png
Prompt: "The attached sprites are an RTS worker: a labourer in a felt hat and red coat with grey trousers. Strip 1 (build_e) shows him crouched beside a stake, hammering, but the hammer barely moves. Redraw this build animation as 4 frames in a row, same cell size and same man, same crouch and feet position in all frames (the body stays still, only the arm and hammer move): frame 1 hammer raised clearly high over his head, frame 2 hammer halfway down, frame 3 hammer striking the top of the stake with a small spark, frame 4 hammer lifting back up. Make the hammer big and dark so it reads at tiny size. Draw it for 5 directions as 5 separate strips: south (facing the viewer), south-east, east, north-east and north (back to the viewer). In the north-east strip he must also crouch beside the stake (the old one stood upright). Pixel art, painted soft shading, dark outline, same pixel scale and palette as the reference, hard pixel edges, plain flat dark navy background."

## 2. Labourer carrying a keg, in his own clothes
Attach: lab_carry_keg_e.png, lab_walk_e.png, lab_idle_e.png
Prompt: "The first sprite shows a worker carrying a powder keg, but he wears a red cap and brown clothes. The second and third show the same worker in his real outfit: felt hat, red coat, grey trousers. Redraw the keg-carrying animations with the real outfit (felt hat, red coat, grey trousers), same keg, same cell size. Make: a 6-frame walk cycle with the legs clearly moving (the keg must not hide the legs: carry the keg on the shoulder or in front of the chest, below the chin), a 4-frame idle with slow breathing, in 5 directions each (south, south-east, east, north-east, north) as separate strips. Pixel art, painted soft shading, dark outline, same pixel scale and palette as the reference, hard pixel edges, plain flat dark navy background."

## 3. Labourer walk and carry cycles, even gait
Attach: lab_walk_e.png, lab_walk_s.png, lab_carry_e.png
Prompt: "The attached strips are a worker's walk cycles (5 frames, so one foot gets 2 frames and the other 3 and the gait limps). Redraw the plain walk and the walk carrying a sack of gold on his back as 6-frame cycles: contact, down, passing, contact (other foot), down, passing; same man, same outfit (felt hat, red coat), same cell size, feet on the same ground line, the loop must be seamless. 5 directions each (south, south-east, east, north-east, north) as separate strips. Pixel art, painted soft shading, dark outline, same pixel scale and palette as the reference, hard pixel edges, plain flat dark navy background."

## 4. Labourer mining recovery frame, idle fix, idle with a sack
Attach: lab_mine_e.png, lab_idle_ne.png, lab_idle_e.png
Prompt: "Same worker as the attached sprites (felt hat, red coat). Make three things in the same cell size. (a) The mining animation has no recovery: add one in-between frame (pick coming up from the ground, half raised) after the strike frame, so the strip is: raise, swing, strike, recover; in 5 directions. (b) The north-east idle (second image) holds the hoe raised across the body, unlike the other views: redraw the north-east idle with the hoe held low at his side like the east idle (third image), 2 frames. (c) A new idle with a gold sack on his back, 2 frames of slow breathing, in 5 directions (south, south-east, east, north-east, north). Pixel art, painted soft shading, dark outline, same pixel scale and palette as the reference, hard pixel edges, plain flat dark navy background."

## 5. Officer melee (light Officer)
Attach: officer_melee_e.png, officer_walk_e.png, officer_idle_e.png
Prompt: "The attached sprites are an 18th-century cavalry officer on foot, with a pistol and a sabre. The melee strip has only a still pose with a sabre added later. Redraw the melee animation as 4 frames in the same cell size: frame 1 sabre raised back over the shoulder (wind-up), frame 2 arm swinging forward, frame 3 the sabre cutting down in front with a bright arc, frame 4 follow-through low. The sabre must be long (about two thirds of his height), a clear bright steel curved blade with a gold hilt guard, readable at tiny size. Give some headroom in the cell. 5 directions as separate strips (south, south-east, east, north-east, north). Pixel art, painted soft shading, dark outline, same pixel scale and palette as the reference, hard pixel edges, plain flat dark navy background."

## 6. Armoured Officer melee
Attach: armoured_melee_e.png, armoured_walk_e.png, officer_melee_e.png
Prompt: "The first two sprites are an armoured officer on foot (breastplate, helmet); the third is a lighter officer. The armoured officer's melee strip uses the same body in all frames and the arm never moves. Redraw it as 4 frames in the same cell size, the same man and armour: wind-up (sabre back over the shoulder), swing, cut with a bright steel arc in front, follow-through. Long curved steel sabre (about two thirds of his height), gold hilt. Leave 2 pixels of headroom (he is 35 of 36 px tall now, shrink the pose slightly if needed). 5 directions as separate strips. Pixel art, painted soft shading, dark outline, same pixel scale and palette as the reference, hard pixel edges, plain flat dark navy background."

## 7. Officer walk with a real stride
Attach: officer_walk_e.png, armoured_walk_e.png, officer_idle_e.png
Prompt: "The first two sprites are the walk cycle of an officer on foot (light and armoured); the legs take steps that are far too short for the speed he moves, so he skates. Redraw both walk cycles as 8 frames with a clearly longer stride (a brisk military march, feet reaching 1.5 times further apart than now, slight body bob), same man, same outfit, same cell size, feet on the same ground line, seamless loop, no frame bigger than the others. 5 directions each (south, south-east, east, north-east, north) as separate strips. Pixel art, painted soft shading, dark outline, same pixel scale and palette as the reference, hard pixel edges, plain flat dark navy background."

## 8. Musketeer walk, front and back views
Attach: musk_walk_s.png, musk_walk_e.png, musk_walk_n.png
Prompt: "The attached strips are a musketeer's walk: east has 6 frames but the south view has only 3 and the north has 7, so turning jumps. Redraw the walk as 6 frames in every direction (south, south-east, east, north-east, north) so the phases match, same man, red coat, black hat with NO green plume (some frames have a green plume by mistake: all red/black), musket carried on the shoulder, same cell size, same height in every frame, feet on the same ground line. Pixel art, painted soft shading, dark outline, same pixel scale and palette as the reference, hard pixel edges, plain flat dark navy background."

## 9. Pikeman walk
Attach: pike_walk_e.png, pike_walk_s.png, pike_walk_n.png
Prompt: "The attached strips are a pikeman's walk. South and south-east have only 2 frames, north has 4 frames where the legs hardly move, and one north-east frame draws two pike shafts. Redraw the walk as 6 frames in all 5 directions (south, south-east, east, north-east, north) with the legs clearly stepping, the pike held upright over the shoulder in the same place in every frame (a single shaft, the tip must stay inside the cell and not make him taller in some frames), same man, same outfit, same cell size, feet on one ground line, seamless loop. Pixel art, painted soft shading, dark outline, same pixel scale and palette as the reference, hard pixel edges, plain flat dark navy background."

## 10. Raptor and Grub walk, all views
Attach: raptor_walk_e.png, grub_walk_e.png
Prompt: "The attached strips show two small reptile-like creatures (a raptor with pink spines and a grub worker) walking east only; in the other directions the game just turns the east strip, so they slide sideways going up or down the screen. Draw the walk for the creature in the first reference (and then, in a separate image, the grub in the second reference) in four more directions: south (coming toward the viewer), south-east, north-east and north (going away), same number of frames as the east strip, same cell size, same colours and size, same ground line, seamless loop. Pixel art, painted soft shading, dark outline, same pixel scale and palette as the reference, hard pixel edges, plain flat dark navy background."

## 11. Mounted walks: Dragoon north-east, Horseman and Cuirassier north-east
Attach: dragoon_walk_e.png, dragoon_walk_n.png, cuirassier_walk_e.png
Prompt: "The attached strips are galloping cavalry (dragoon, cuirassier). The north-east view is a copy of the north or east view (the game has no north-east drawing), and the dragoon's first frame is larger than the others in every view. Draw a proper north-east gallop (rider and horse seen from behind and to the right, three-quarter view) for the dragoon and, in a separate image, for the cuirassier, same number of frames as the east strip, same cell size, same riders and horse coats, every frame the same size, hoof line steady. Pixel art, painted soft shading, dark outline, same pixel scale and palette as the reference, hard pixel edges, plain flat dark navy background."

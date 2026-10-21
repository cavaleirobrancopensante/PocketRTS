#!/bin/sh
# Cuts the designer's lizard recording (art/audio_src/lizard_multiple_sounds.mp3) at its
# silences into the Raptor's voice (8 clips) and deaths (the last 4), then: make_mix.py
F=art/audio_src/lizard_multiple_sounds.mp3
i=0
for seg in "0.31 0.83 voice/raptor/select_1" "2.52 3.11 voice/raptor/select_2" "4.67 5.15 voice/raptor/select_3" \
	"6.89 7.48 voice/raptor/move_1" "9.09 9.65 voice/raptor/attack_1" "10.90 11.53 voice/raptor/attack_2" \
	"12.73 13.45 voice/raptor/move_2" "14.66 15.39 voice/raptor/move_3" "16.66 17.39 audio/combat/raptor_death_1" \
	"18.66 19.39 audio/combat/raptor_death_2" "20.67 21.39 audio/combat/raptor_death_3" "22.67 23.39 audio/combat/raptor_death_4"; do
	set -- $seg
	s=$(python3 -c "print(max(0,$1-0.03))"); d=$(python3 -c "print($2-$1+0.1)"); fo=$(python3 -c "print($2-$1+0.04)")
	ffmpeg -v error -y -ss $s -t $d -i $F -af "afade=t=in:d=0.01,afade=t=out:st=$fo:d=0.06" -ac 1 -ar 44100 assets/$3.wav
done

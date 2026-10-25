"""The universal attack alarm (the same for all three factions): assets/audio/ui/alert_all.wav.
Three rising two-tone blasts, a klaxon you can't mistake for anything else in the game."""
import numpy as np, wave, sys
sr = 44100
def tone(f, d, amp=1.0):
    t = np.arange(int(sr * d)) / sr
    ph = 2 * np.pi * f * t
    w = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.33 * np.sin(3 * ph) + 0.2 * np.sin(5 * ph)   # a reedy horn
    w = np.tanh(1.6 * w) * 0.6
    n = len(t)
    env = np.minimum(1, t / 0.008) * np.minimum(1, (d - t) / 0.03)
    return w * env * amp
parts = []
for i in range(3):
    lo, hi = 523.25, 783.99          # C5 up to G5
    parts += [tone(lo, 0.13), tone(hi, 0.2), np.zeros(int(sr * 0.1))]
out = np.concatenate(parts)
out = np.concatenate([out, np.zeros(int(sr * 0.05))])
out = out / np.max(np.abs(out)) * 0.8
data = (out * 32767).astype(np.int16)
with wave.open(sys.argv[1] if len(sys.argv) > 1 else "assets/audio/ui/alert_all.wav", "wb") as f:
    f.setnchannels(1); f.setsampwidth(2); f.setframerate(sr); f.writeframes(data.tobytes())
print(len(out) / sr, "s")

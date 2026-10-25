"""The universal attack alarm (the same for all three factions): assets/audio/ui/alert_all.wav.
Variant "horn": a low war horn calling twice (a rising fifth) over deep war-drum hits, warm and
round (the harmonics are low-passed and the horn swells in), with a short room tail.
Variant "toll": a deep bell struck three times, falling, with a drum under each.
usage: make_alert_all.py out.wav [horn|toll|toll3]"""
import numpy as np, wave, sys
from scipy import signal
sr = 44100
rng = np.random.default_rng(7)

def horn(f, d, amp=1.0):
    t = np.arange(int(sr * d)) / sr
    ph = 2 * np.pi * f * (t + 0.004 * np.sin(2 * np.pi * 5 * t))        # a little breath in the pitch
    w = sum(np.sin(k * ph) / (k ** 0.9) for k in range(1, 9))
    # the brass "opens": the filter rises through the note
    out = np.zeros_like(w)
    chunks = 8
    n = len(w) // chunks
    for i in range(chunks):
        cut = 500 + 1500 * (i / (chunks - 1)) ** 0.7
        b, a = signal.butter(2, cut / (sr / 2))
        seg = signal.lfilter(b, a, w[i * n:(i + 1) * n if i < chunks - 1 else None])
        out[i * n:(i + 1) * n if i < chunks - 1 else None] = seg
    env = np.minimum(1, t / 0.07) * np.minimum(1, (d - t) / 0.18)
    return out * env * amp * 0.55

def drum(f0=70, d=0.45, amp=1.0):
    t = np.arange(int(sr * d)) / sr
    f = f0 * (1 + 1.2 * np.exp(-t * 30))
    body = np.sin(2 * np.pi * np.cumsum(f) / sr) * np.exp(-t * 7)
    noise = signal.lfilter(*signal.butter(2, 900 / (sr / 2)), rng.normal(0, 1, len(t))) * np.exp(-t * 40) * 0.25
    return (body + noise) * amp

def bell(f, d, amp=1.0):
    t = np.arange(int(sr * d)) / sr
    w = np.zeros_like(t)
    for ratio, a, dec in [(1, 1, 3.2), (2.0, 0.5, 4), (2.76, 0.35, 5), (4.07, 0.2, 7), (5.4, 0.1, 9)]:
        w += a * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t * dec)
    return w * np.minimum(1, t / 0.003) * amp * 0.5

def place(buf, snd, at):
    i = int(at * sr)
    buf[i:i + len(snd)] += snd[:len(buf) - i]

variant = sys.argv[2] if len(sys.argv) > 2 else "horn"
buf = np.zeros(int(sr * 2.2))
if variant == "horn":
    place(buf, drum(), 0.0)
    place(buf, horn(98.0, 0.55), 0.02)          # G2
    place(buf, drum(65, 0.5, 1.1), 0.62)
    place(buf, horn(146.83, 0.95), 0.64)        # D3, a rising fifth, held
elif variant == "toll3":
    for at in (0.0, 0.3, 0.6):                 # the first bell note, struck three times quickly
        place(buf, bell(196.0, 0.9), at)
        place(buf, drum(60, 0.35, 0.85), at)
else:
    for i, (f, at) in enumerate([(196.0, 0.0), (174.6, 0.55), (146.8, 1.1)]):    # G3, F3, D3: falling
        place(buf, bell(f, 1.1), at)
        place(buf, drum(60, 0.4, 0.9), at)
# a short room: a few soft early echoes
rev = np.zeros(len(buf))
for dly, g in [(0.045, 0.35), (0.083, 0.28), (0.127, 0.2), (0.19, 0.14), (0.27, 0.08)]:
    i = int(dly * sr)
    rev[i:] += buf[:-i] * g
buf = buf + signal.lfilter(*signal.butter(1, 3000 / (sr / 2)), rev)
buf = buf[:int(sr * 2.0)]
buf *= np.minimum(1, (len(buf) - np.arange(len(buf))) / (0.15 * sr))
buf = buf / np.max(np.abs(buf)) * 0.85
with wave.open(sys.argv[1] if len(sys.argv) > 1 else "assets/audio/ui/alert_all.wav", "wb") as f:
    f.setnchannels(1); f.setsampwidth(2); f.setframerate(sr); f.writeframes((buf * 32767).astype(np.int16).tobytes())
w = np.abs(np.fft.rfft(buf)); fr = np.fft.rfftfreq(len(buf), 1 / sr)
print(variant, "%.2f s, spectral centroid %.0f Hz" % (len(buf) / sr, (w * fr).sum() / w.sum()))

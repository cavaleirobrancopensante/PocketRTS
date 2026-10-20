"""Small DSP toolkit shared by make_sfx2.py and make_voices.py (numpy/scipy/numba)."""
import os

import numpy as np
import soundfile as sf
from numba import njit
from scipy.signal import butter, sosfilt, fftconvolve, resample_poly

SR = 44100


# ------------------------------------------------------------------ basics

def T(d):
    return np.arange(int(SR * d)) / SR


def N(d):
    return int(SR * d)


def noise(rng, d):
    return rng.standard_normal(N(d))


def _sos(kind, f, o):
    if kind == "band":
        lo, hi = f
        hi = min(hi, SR / 2 - 100)
        lo = max(lo, 5)
        return butter(o, [lo, hi], btype="band", fs=SR, output="sos")
    f = min(f, SR / 2 - 100)
    return butter(o, f, btype=kind, fs=SR, output="sos")


def lp(x, f, o=2):
    return sosfilt(_sos("low", f, o), x)


def hp(x, f, o=2):
    return sosfilt(_sos("high", f, o), x)


def bp(x, lo, hi, o=2):
    return sosfilt(_sos("band", (lo, hi), o), x)


def reson(x, f, q):
    """Narrow resonant band-pass (bandwidth f/q)."""
    bw = f / q
    return bp(x, f - bw / 2, f + bw / 2, 1) * q ** 0.5


def expenv(d, decay, attack=0.002):
    t = T(d)
    return np.minimum(1.0, t / max(attack, 1e-5)) * np.exp(-t * decay)


def adsr(d, a, dcy, s, r):
    n = N(d)
    t = T(d)
    e = np.empty(n)
    rel_start = max(d - r, a + dcy)
    e = np.where(t < a, t / max(a, 1e-5),
                 np.where(t < a + dcy, 1 - (1 - s) * (t - a) / max(dcy, 1e-5), s))
    rel = np.clip((t - rel_start) / max(r, 1e-5), 0, 1)
    return e * (1 - rel)


def smooth_rand(rng, d, rate, lo=0.0, hi=1.0):
    """Slow random curve (cubic-ish interpolation of random points)."""
    n = N(d)
    k = max(4, int(d * rate) + 4)
    pts = rng.uniform(lo, hi, k)
    xs = np.linspace(0, n, k)
    c = np.interp(np.arange(n), xs, pts)
    w = max(3, int(SR / rate / 2))
    c = np.convolve(np.pad(c, (w, w), mode="edge"), np.ones(w) / w, mode="same")[w:-w]
    return c[:n]


def phase(freq):
    """Integrate a frequency curve (array) into phase."""
    return 2 * np.pi * np.cumsum(freq) / SR


def glide(f0, f1, d, shape=1.0):
    t = T(d)
    return f0 + (f1 - f0) * (t / d) ** shape


def expglide(f0, f1, d):
    t = T(d)
    return f0 * (f1 / f0) ** (t / d)


def saw_ph(ph, k=30, fmax=None, f=None):
    out = np.zeros_like(ph)
    for i in range(1, k + 1):
        out += np.sin(i * ph) / i
    return out


def bl_saw(freq):
    """Band-limited saw for a frequency curve (harmonics up to ~16 kHz)."""
    ph = phase(freq)
    out = np.zeros_like(ph)
    fmax = float(np.max(freq))
    k = max(1, int(16000 / max(fmax, 20)))
    k = min(k, 80)
    for i in range(1, k + 1):
        g = np.clip((16000 - i * freq) / 2000, 0, 1)
        out += g * np.sin(i * ph) / i
    return out


def pulse(freq, width=0.3):
    return bl_saw(freq) - _shift_saw(phase(freq), width, freq)


def _shift_saw(ph, width, freq):
    out = np.zeros_like(ph)
    fmax = float(np.max(freq))
    k = min(80, max(1, int(16000 / max(fmax, 20))))
    for i in range(1, k + 1):
        out += np.sin(i * (ph + 2 * np.pi * width)) / i
    return out


def place(out, x, t, g=1.0):
    """Mix x into out at time t (seconds), growing out if necessary."""
    s = int(t * SR)
    need = s + len(x)
    if need > len(out):
        out = np.concatenate([out, np.zeros(need - len(out))])
    out[s:s + len(x)] += g * x
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    o = np.zeros(n)
    for p in parts:
        o[:len(p)] += p
    return o


def fit(x, d):
    n = N(d)
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


# ------------------------------------------------------------------ synthesis blocks

def modal(freqs, amps, decays, d, rng=None, detune=0.0):
    t = T(d)
    out = np.zeros_like(t)
    for f, a, k in zip(freqs, amps, decays):
        if rng is not None and detune:
            f *= 1 + rng.uniform(-detune, detune)
        if f >= SR / 2 - 200:
            continue
        ph0 = 0 if rng is None else rng.uniform(0, 2 * np.pi)
        out += a * np.sin(2 * np.pi * f * t + ph0) * np.exp(-t * k)
    return out


METAL_RATIOS = [1.0, 2.32, 4.25, 6.63, 9.38, 12.5, 15.9]
BELL_RATIOS = [0.5, 1.0, 1.183, 1.506, 2.0, 2.514, 2.662, 3.011, 4.166]


def metal_hit(rng, f0, d, decay=8.0, bright=1.0, ratios=METAL_RATIOS):
    fs = [f0 * r * (1 + rng.uniform(-0.02, 0.02)) for r in ratios]
    amps = [bright ** i / (1 + 0.3 * i) * rng.uniform(0.6, 1.0) for i in range(len(fs))]
    decs = [decay * (1 + 0.45 * i) * rng.uniform(0.8, 1.2) for i in range(len(fs))]
    body = modal(fs, amps, decs, d, rng)
    tr = hp(noise(rng, 0.006), 2000) * np.exp(-T(0.006) * 700)
    return place(body, tr * 0.6, 0)


def bell(rng, f0, d, decay=2.5, bright=0.8):
    fs = [f0 * r for r in BELL_RATIOS]
    amps = [0.5, 1.0, 0.6, 0.5, 0.55, 0.35, 0.3, 0.25, 0.18]
    amps = [a * bright ** max(0, i - 1) for i, a in enumerate(amps)]
    decs = [decay * 0.6, decay, decay * 1.3, decay * 1.6, decay * 1.8, decay * 2.4, decay * 2.6, decay * 3, decay * 4]
    b = modal(fs, amps, decs, d, rng, detune=0.002)
    strike = hp(noise(rng, 0.004), 3000) * np.exp(-T(0.004) * 900) * 0.4
    return place(b, strike, 0)


def fm_bell(f0, d, ratio=1.4, index=3.0, decay=4.0):
    t = T(d)
    ie = index * np.exp(-t * decay * 1.5)
    mod = ie * np.sin(2 * np.pi * f0 * ratio * t)
    return np.sin(2 * np.pi * f0 * t + mod) * np.exp(-t * decay)


def wood_hit(rng, f0, d=0.15, decay=45.0):
    ratios = [1.0, 2.7, 4.9, 7.6]
    fs = [f0 * r * rng.uniform(0.97, 1.03) for r in ratios]
    body = modal(fs, [1, .5, .3, .15], [decay, decay * 1.6, decay * 2.4, decay * 3.5], d, rng)
    click = bp(noise(rng, 0.01), f0 * 2, f0 * 8) * np.exp(-T(0.01) * 500)
    return place(body, click * 0.7, 0)


def brass(rng, f0, d, vib=5.5, vib_depth=0.012, bright=1.0, attack=0.035, release=0.08, scoop=0.03):
    """Additive brass: brightness follows amplitude, scoop up into pitch, delayed vibrato."""
    t = T(d)
    a = adsr(d, attack, 0.08, 0.8, release)
    vd = vib_depth * np.clip((t - 0.12) / 0.2, 0, 1)
    f = f0 * (1 + vd * np.sin(2 * np.pi * vib * t + rng.uniform(0, 6)))
    f *= 1 - scoop * np.exp(-t / 0.03)
    f *= 1 + 0.002 * smooth_rand(rng, d, 12, -1, 1)
    ph = phase(f)
    out = np.zeros_like(t)
    k = int(min(28, 14000 / f0))
    for i in range(1, k + 1):
        amp_i = a ** (1 + 0.35 * (i - 1) / bright) / i ** 0.7
        out += amp_i * np.sin(i * ph)
    breath = bp(noise(rng, d), 1500, 5000) * a * 0.02
    blip = bp(noise(rng, 0.03), 300, 3000) * np.exp(-T(0.03) * 120) * 0.15
    return place(out + breath, blip, 0)


def karplus(rng, f0, d, damp=0.996, bright=0.6):
    n = N(d)
    p = int(SR / f0)
    buf = rng.uniform(-1, 1, p)
    buf = lp(buf, 1000 + 8000 * bright)
    return _ks(buf, n, damp)


@njit(cache=True)
def _ks(buf, n, damp):
    p = len(buf)
    out = np.zeros(n)
    b = buf.copy()
    for i in range(n):
        j = i % p
        out[i] = b[j]
        b[j] = damp * 0.5 * (b[j] + b[(j + 1) % p])
    return out


@njit(cache=True)
def svf_bp(x, fc, q):
    """Time-varying state-variable band-pass; fc array same length as x."""
    n = len(x)
    out = np.zeros(n)
    low = 0.0
    band = 0.0
    for i in range(n):
        f = 2.0 * np.sin(np.pi * min(fc[i], 16000.0) / 88200.0)
        for _ in range(2):
            high = x[i] - low - band / q
            band += f * high
            low += f * band
        out[i] = band
    return out


@njit(cache=True)
def svf_lp(x, fc, q):
    n = len(x)
    out = np.zeros(n)
    low = 0.0
    band = 0.0
    for i in range(n):
        f = 2.0 * np.sin(np.pi * min(fc[i], 16000.0) / 88200.0)
        for _ in range(2):
            high = x[i] - low - band / q
            band += f * high
            low += f * band
        out[i] = low
    return out


def formants(src, fmts, q=8.0):
    """fmts: list of (freq or freq-array, gain)."""
    out = np.zeros_like(src)
    for f, g in fmts:
        fc = f if isinstance(f, np.ndarray) else np.full(len(src), float(f))
        out += g * svf_bp(src, fc[:len(src)], q)
    return out


def glottal(rng, f0curve, jitter=0.01, shimmer=0.1, rough=0.0):
    """Voice-ish source: band-limited saw with jitter, shimmer and optional subharmonic roughness."""
    n = len(f0curve)
    d = n / SR
    f = f0curve * (1 + jitter * smooth_rand(rng, d, 40, -1, 1))
    src = bl_saw(f)
    src *= 1 + shimmer * smooth_rand(rng, d, 30, -1, 1)
    if rough:
        ph = phase(f / 2)
        src *= 1 + rough * np.sin(ph)
    return src


def bubble(rng, f0, d=0.08, rise=4.0, decay=None):
    """Minnaert-style bubble: sine with rising pitch and exponential decay."""
    t = T(d)
    decay = decay or (f0 * 0.06 + 20)
    f = f0 * (1 + rise * t)
    return np.sin(phase(f)) * np.exp(-t * decay) * np.minimum(1, t / 0.001)


def grains(rng, d, density, gdur=(0.005, 0.03), lo=200, hi=3000, src="noise", env=None):
    """Scatter short filtered-noise grains; density in grains/sec (scalar or callable(t))."""
    out = np.zeros(N(d) + N(0.1))
    t = 0.0
    while t < d:
        dens = density(t) if callable(density) else density
        t += rng.exponential(1 / max(dens, 1e-3))
        if t >= d:
            break
        g = rng.uniform(*gdur)
        if src == "noise":
            c = np.exp(rng.uniform(np.log(lo), np.log(hi)))
            gr = bp(noise(rng, g), c * 0.7, c * 1.4)
        else:
            gr = bubble(rng, rng.uniform(lo, hi), g)
        gr *= np.hanning(len(gr)) if len(gr) > 2 else 1
        amp = env(t) if env else 1.0
        out = place(out, gr * amp * rng.uniform(0.4, 1.0), t)
    return out[:N(d) + N(0.1)]


def click_train(rng, times, f0=3000, decay=250, amp=1.0, jitter=0.1):
    out = np.zeros(1)
    for i, tt in enumerate(times):
        c = metal_hit(rng, f0 * rng.uniform(1 - jitter, 1 + jitter), 0.04, decay=decay, bright=0.8)
        out = place(out, c * amp, tt)
    return out


def crackle(rng, d, rate, amp_env=None, lo=1500):
    """Electric/fire crackle: sparse sharp impulses, high-passed."""
    n = N(d)
    x = np.zeros(n)
    k = rng.poisson(rate * d)
    idx = rng.integers(0, n, k)
    x[idx] = rng.uniform(-1, 1, k) * rng.uniform(0.2, 1, k) ** 2
    x = hp(x, lo)
    x = x + 0.3 * hp(np.convolve(x, np.ones(8) / 8, mode="same"), lo / 2)
    if amp_env is not None:
        x *= amp_env[:n]
    return x


def reverb(x, rng, rt=0.4, wet=0.15, pre=0.01, damp=6000):
    d = rt * 1.2
    ir = noise(rng, d) * np.exp(-T(d) * 6.9 / rt)
    ir = lp(ir, damp)
    ir = np.concatenate([np.zeros(int(pre * SR)), ir])
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    w = fftconvolve(x, ir)[:len(x) + len(ir)]
    dry = np.concatenate([x, np.zeros(len(w) - len(x))])
    return dry * (1 - wet) + w * wet * 1.2


def echo(x, delay, g, n=2, lowpass=2000):
    out = x.copy()
    y = x
    for i in range(1, n + 1):
        y = lp(y, lowpass)
        out = place(out, y * g ** i, delay * i)
    return out


def comb(x, delay_s, g):
    dd = int(delay_s * SR)
    y = x.copy()
    y[dd:] += g * x[:-dd]
    return y


def resample_speed(x, factor):
    """Play back faster (factor>1) / slower; changes pitch and duration."""
    from fractions import Fraction
    fr = Fraction(1 / factor).limit_denominator(200)
    return resample_poly(x, fr.numerator, fr.denominator)


# ------------------------------------------------------------------ output

def finish(x, peak_db=-1.0, fade_in=0.001, fade_out=0.012, trim=True, thresh_db=-45):
    x = np.asarray(x, dtype=np.float64)
    x = x - np.mean(x[: min(len(x), 64)]) * 0  # keep DC untouched (filters already remove it)
    x = hp(x, 25, 2)
    if trim:
        a = np.abs(x)
        pk = a.max() + 1e-12
        th = pk * 10 ** (thresh_db / 20)
        idx = np.nonzero(a > th)[0]
        if len(idx):
            s = max(0, idx[0] - int(0.0005 * SR))
            e = min(len(x), idx[-1] + int(0.005 * SR))
            x = x[s:e]
    fi = max(1, int(fade_in * SR))
    fo = max(1, min(len(x) // 3, int(fade_out * SR)))
    x[:fi] *= np.linspace(0, 1, fi)
    x[-fo:] *= np.linspace(1, 0, fo) ** 1.5
    x = x / (np.max(np.abs(x)) + 1e-12) * 10 ** (peak_db / 20)
    return x


def write_wav(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sf.write(path, np.clip(x, -1, 1), SR, subtype="PCM_16")


def write_ogg(path, x, quality=0.4):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sf.write(path, np.clip(x, -1, 1).astype(np.float32), SR, format="OGG", subtype="VORBIS")


def loopify(x, length, xfade):
    """Seamless loop of `length` s from x (needs length+xfade s of material)."""
    n = N(length)
    L = N(xfade)
    out = x[:n].copy()
    w = np.linspace(0, 1, L)
    fin = np.sin(w * np.pi / 2)
    fout = np.cos(w * np.pi / 2)
    out[:L] = x[:L] * fin + x[n:n + L] * fout
    return out

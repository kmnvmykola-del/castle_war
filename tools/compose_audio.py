"""Compose original game music and UI cues; export Roblox-ready PCM WAV files.

All notes and synthesis are authored here. No recordings, samples or existing
melodies are used. Re-running the score produces identical audio.
"""
from pathlib import Path
import hashlib
import json
import math
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio/original'
SITE = ROOT / 'audio-site/dist/audio'
RATE = 32000
RNG = np.random.default_rng(20261005)


def tone(note, duration, voice='lute'):
    t = np.arange(max(1, round(duration * RATE)), dtype=np.float32) / RATE
    frequency = 440 * 2 ** ((note - 69) / 12)
    y = np.zeros_like(t)
    if voice == 'lute':
        for k in range(1, 10):
            y += np.sin(2 * math.pi * frequency * k * t + k * .23) * np.exp(-t * (3.7 + k * .66)) / k ** 1.45
        y *= np.minimum(t / .006, 1)
    elif voice == 'flute':
        phase = 2 * math.pi * frequency * t + .028 * np.sin(2 * math.pi * 4.8 * t)
        y = np.sin(phase) + .18 * np.sin(phase * 2) + .045 * np.sin(phase * 3)
        y *= np.minimum(t / .10, 1) * np.minimum((duration - t) / .18, 1)
    elif voice == 'strings':
        for k in range(1, 8):
            y += (np.sin(2 * math.pi * frequency * k * 1.001 * t) + np.sin(2 * math.pi * frequency * k * .999 * t)) / (k ** 1.75 * 2)
        y *= np.minimum(t / .12, 1) * np.minimum((duration - t) / .22, 1)
    elif voice == 'bell':
        for k, gain in [(1, 1), (2.01, .27), (2.76, .10), (4.02, .07)]:
            y += gain * np.sin(2 * math.pi * frequency * k * t) * np.exp(-t * (3 + k))
        y *= np.minimum(t / .004, 1)
    return y.astype(np.float32)


def drum(duration=.30, pitch=90, noise=.10):
    t = np.arange(round(duration * RATE), dtype=np.float32) / RATE
    phase = 2 * math.pi * (pitch * t + 36 * (1 - np.exp(-t * 21)) / 21)
    y = np.sin(phase) * np.exp(-t * 19)
    y += RNG.normal(0, noise, len(t)).astype(np.float32) * np.exp(-t * 55)
    y *= np.minimum(t / .002, 1)
    return y


def add(buffer, signal, at, gain, pan=0):
    start = round(at * RATE)
    end = min(len(buffer), start + len(signal))
    if end <= start:
        return
    signal = signal[:end-start] * gain
    buffer[start:end, 0] += signal * math.sqrt((1-pan)/2)
    buffer[start:end, 1] += signal * math.sqrt((1+pan)/2)


def room(buffer):
    dry = buffer.copy()
    for delay, gain in [(.061, .08), (.109, .06), (.177, .045), (.287, .025)]:
        offset = round(delay * RATE)
        buffer[offset:, 0] += dry[:-offset, 1] * gain
        buffer[offset:, 1] += dry[:-offset, 0] * gain


def score(battle=False):
    bpm = 112 if battle else 86
    beat = 60 / bpm
    bars = 32
    duration = bars * beat * 4
    out = np.zeros((round(duration * RATE), 2), dtype=np.float32)
    # D minor, B-flat, F, C; final dominant supplies a return to the opening.
    chords = [[50, 53, 57], [46, 50, 53], [48, 53, 57], [48, 52, 55]]
    phrases = [
        [74, 77, 76, 74, 72, 69, 72, 74],
        [77, 81, 79, 77, 74, 72, 74, 77],
        [72, 77, 76, 72, 69, 67, 69, 72],
        [76, 79, 77, 76, 72, 70, 69, 73],
    ]
    for bar in range(bars):
        at = bar * 4 * beat
        chord = chords[(bar // 2) % 4]
        if bar >= 30:
            chord = [45, 49, 52]
        for i, note in enumerate(chord):
            add(out, tone(note, 4*beat, 'strings'), at, .023 if battle else .030, (i-1)*.35)
        add(out, tone(chord[0]-12, 2.5*beat, 'strings'), at, .045 if battle else .026, -.05)
        pattern = [0, 1, 2, 1, 0, 2, 1, 2]
        for i, index in enumerate(pattern):
            note = chord[index] + (12 if i % 3 == 1 else 0)
            add(out, tone(note, beat * .95), at + i*beat/2, .070 if battle else .093, -.24)
        if battle:
            for pulse in range(4):
                add(out, drum(.32, 62 if pulse % 2 == 0 else 115, .035), at+pulse*beat, .12 if pulse % 2 == 0 else .067, .10)
            for pulse in [1.5, 3.5]:
                add(out, drum(.13, 170, .30), at+pulse*beat, .045, .38)
        elif bar % 2 == 0:
            add(out, drum(.24, 105, .016), at, .032, .16)
        if bar % 2 == 0:
            phrase = phrases[(bar // 2) % 4]
            for i, note in enumerate(phrase):
                add(out, tone(note, beat * 1.12, 'flute' if not battle else 'strings'), at+i*beat, .065 if battle else .048, .22)
        if bar in [7, 15, 23]:
            for j, note in enumerate([81, 84, 86]):
                add(out, tone(note, beat*1.8, 'bell'), at+(2.5+j*.5)*beat, .028, .45)
    room(out)
    fade = round(.65 * RATE)
    out[:fade] *= np.linspace(0, 1, fade)[:, None]
    out[-fade:] *= np.linspace(1, 0, fade)[:, None]
    return out, bpm


def cue(name):
    specs = {
        'Click': (.18, [(77, 0, .11, .15, 'lute')]),
        'Select': (.32, [(74, 0, .22, .13, 'lute'), (81, .07, .20, .10, 'bell')]),
        'Order': (.52, [(69, 0, .25, .12, 'lute'), (74, .08, .25, .12, 'lute'), (81, .16, .30, .10, 'bell')]),
        'Place': (.30, [(62, 0, .20, .12, 'lute'), (74, .065, .18, .08, 'lute')]),
        'Error': (.34, [(65, 0, .16, .10, 'lute'), (62, .11, .17, .095, 'lute')]),
        'Chest': (1.45, [(62, 0, .40, .08, 'lute'), (69, .12, .40, .08, 'lute'), (74, .24, .50, .10, 'bell'), (77, .38, .75, .08, 'bell'), (81, .55, .82, .08, 'bell')]),
        'Victory': (2.65, [(62, 0, .50, .10, 'strings'), (65, .35, .50, .10, 'strings'), (69, .70, .50, .10, 'strings'), (74, 1.05, 1.45, .10, 'strings'), (77, 1.05, 1.45, .07, 'strings'), (81, 1.05, 1.45, .06, 'bell')]),
        'Defeat': (2.10, [(69, 0, .65, .09, 'strings'), (65, .45, .65, .09, 'strings'), (62, .9, 1.05, .08, 'strings')]),
    }
    duration, notes = specs[name]
    out = np.zeros((round(duration*RATE), 2), dtype=np.float32)
    for note, at, length, gain, voice in notes:
        add(out, tone(note, length, voice), at, gain)
    if name in ('Click', 'Place', 'Chest'):
        add(out, drum(.07, 190, .08), 0, .024)
    room(out)
    out[-min(len(out), 450):] *= np.linspace(1, 0, min(len(out), 450))[:, None]
    return out


def save(key, title, category, signal, use, bpm=None):
    peak = float(np.max(np.abs(signal)))
    target = .58 if category == 'music' else .38
    signal *= target / max(peak, 1e-6)
    pcm = np.round(np.clip(signal, -1, 1) * 32767).astype('<i2')
    filename = key.lower() + '.wav'
    destination = OUT / filename
    with wave.open(str(destination), 'wb') as wav:
        wav.setnchannels(2); wav.setsampwidth(2); wav.setframerate(RATE)
        wav.writeframes(pcm.tobytes())
    (SITE / filename).write_bytes(destination.read_bytes())
    mono = np.max(np.abs(signal), axis=1)
    peaks = [round(float(np.max(chunk)), 4) for chunk in np.array_split(mono, 120)]
    return {'key': key, 'title': title, 'category': category, 'file': 'audio/'+filename,
            'duration': round(len(signal)/RATE, 3), 'use': use, 'bpm': bpm,
            'peaks': peaks, 'sampleRate': RATE, 'peak': round(float(np.max(np.abs(signal))), 4),
            'rms': round(float(np.sqrt(np.mean(signal*signal))), 4),
            'sha256': hashlib.sha256(destination.read_bytes()).hexdigest(), 'robloxAssetId': 0}


def main():
    OUT.mkdir(parents=True, exist_ok=True); SITE.mkdir(parents=True, exist_ok=True)
    menu, bpm = score()
    tracks = [save('Menu', 'Frontier Dawn', 'music', menu, 'Menu, map editor and preparation', bpm)]
    battle, bpm = score(True)
    tracks.append(save('Battle', 'March of the Banners', 'music', battle, 'Battle', bpm))
    names = {'Click': ('Wooden Click', 'Buttons and menus'), 'Select': ('Banner Call', 'Building selection'),
             'Order': ('Advance', 'Troop orders'), 'Place': ('Foundation', 'Map editor changes'),
             'Error': ('Not Yet', 'Rejected actions'), 'Chest': ('Treasury', 'Chest reward'),
             'Victory': ('The Keep Is Ours', 'Victory'), 'Defeat': ('Fallen Banner', 'Defeat')}
    for key, (title, use) in names.items():
        tracks.append(save(key, title, 'effect', cue(key), use))
    manifest = {'title': 'Frontier Kingdoms · Sound Library', 'author': 'Original procedural score for Frontier Kingdoms',
                'format': 'Stereo PCM WAV · 32 kHz · 16 bit', 'tracks': tracks}
    payload = json.dumps(manifest, indent=2)
    (OUT/'manifest.json').write_text(payload, encoding='utf8')
    (SITE.parent/'manifest.json').write_text(payload, encoding='utf8')
    print(json.dumps({'files':len(tracks), 'musicSeconds':sum(t['duration'] for t in tracks if t['category']=='music'),
                      'output':str(OUT), 'peakMax':max(t['peak'] for t in tracks)}))


if __name__ == '__main__':
    main()

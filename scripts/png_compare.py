#!/usr/bin/env python3
"""png_compare.py – Famlist: Pixelvergleich zweier gleich großer PNGs ohne Zusatzpakete.

Aufruf:  python3 scripts/png_compare.py <design.png> <simulator.png> <vergleich.png> [--ignore x,y,b,h …]

--ignore nimmt Rechtecke in Bildpunkten aus der Zählung heraus (z. B. die Uhrzeit, die watchOS selbst
zeichnet und die sich im Simulator nicht festlegen lässt: 300,16,116,56).

Schreibt ein Vergleichsbild (Design | Simulator | Differenz ×4) und gibt die mittlere Abweichung
sowie den Anteil stark abweichender Pixel (> 32 von 255) aus. Unterstützt 8-Bit-RGB/RGBA-PNGs.
"""
import struct
import sys
import zlib


def read_png(path):
    data = open(path, 'rb').read()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', f'kein PNG: {path}'
    pos, idat, width, height, channels = 8, b'', 0, 0, 0
    while pos < len(data):
        length, kind = struct.unpack('>I4s', data[pos:pos + 8])
        chunk = data[pos + 8:pos + 8 + length]
        if kind == b'IHDR':
            width, height, depth, color = struct.unpack('>IIBB', chunk[:10])
            assert depth == 8 and color in (2, 6), f'nur 8-Bit RGB/RGBA: {path}'
            channels = 3 if color == 2 else 4
        elif kind == b'IDAT':
            idat += chunk
        pos += 12 + length
    raw, stride, rows, prev = zlib.decompress(idat), width * channels, [], bytearray(width * channels)
    for y in range(height):
        f, line = raw[y * (stride + 1)], bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            a = line[i - channels] if i >= channels else 0
            b, c = prev[i], prev[i - channels] if i >= channels else 0
            if f == 1: line[i] = (line[i] + a) & 255
            elif f == 2: line[i] = (line[i] + b) & 255
            elif f == 3: line[i] = (line[i] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append([tuple(line[x * channels:x * channels + 3]) for x in range(width)])
        prev = line
    return width, height, rows


def write_png(path, width, height, rows):
    raw = b''.join(b'\x00' + bytes(v for px in row for v in px) for row in rows)
    def chunk(kind, body):
        return struct.pack('>I', len(body)) + kind + body + struct.pack('>I', zlib.crc32(kind + body) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
    open(path, 'wb').write(png + chunk(b'IDAT', zlib.compress(raw, 6)) + chunk(b'IEND', b''))


def main():
    design, sim, out = sys.argv[1:4]
    ignore = [tuple(map(int, r.split(','))) for r in sys.argv[5:]] if sys.argv[4:5] == ['--ignore'] else []
    skip = lambda x, y: any(rx <= x < rx + rw and ry <= y < ry + rh for rx, ry, rw, rh in ignore)
    w, h, a = read_png(design)
    w2, h2, b = read_png(sim)
    assert (w, h) == (w2, h2), f'Größen verschieden: {w}×{h} vs {w2}×{h2}'
    total, strong, counted, rows, gap = 0, 0, 0, [], (255, 255, 255)
    for y in range(h):
        diff = []
        for x in range(w):
            d = 0 if skip(x, y) else max(abs(a[y][x][i] - b[y][x][i]) for i in range(3))
            counted += not skip(x, y)
            total += d
            strong += d > 32
            diff.append((min(255, d * 4),) * 3)
        rows.append(a[y] + [gap] * 8 + b[y] + [gap] * 8 + diff)
    write_png(out, w * 3 + 16, h, rows)
    print(f'{out}: mittlere Abweichung {total / counted:.2f}, stark abweichend {100 * strong / counted:.2f} %')


if __name__ == '__main__':
    main()

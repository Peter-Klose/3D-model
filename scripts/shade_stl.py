#!/usr/bin/env python3
"""Shaded orthographic front view of an STL (looking along +Y, Z up).

OpenSCAD's preview lighting is too flat to show shallow reliefs, so this
renders a small raking-light image with a plain z-buffer rasteriser.

Usage: shade_stl.py in.stl out.png X0 X1 Z0 Z1 [--px-per-mm 12]
"""
import argparse

import numpy as np
import trimesh
from PIL import Image


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("stl"); ap.add_argument("png")
    ap.add_argument("window", nargs=4, type=float, metavar=("X0", "X1", "Z0", "Z1"))
    ap.add_argument("--px-per-mm", type=float, default=12)
    a = ap.parse_args()
    x0, x1, z0, z1 = a.window
    s = a.px_per_mm
    W, H = int((x1 - x0) * s), int((z1 - z0) * s)

    m = trimesh.load(a.stl, force="mesh")
    n = m.face_normals
    tri = m.triangles
    keep = (n[:, 1] < 0) & (tri[:, :, 0].max(1) > x0) & (tri[:, :, 0].min(1) < x1) \
         & (tri[:, :, 2].max(1) > z0) & (tri[:, :, 2].min(1) < z1)

    # z-buffer of the distance towards the viewer (smaller y = nearer)
    depth = np.full((H, W), np.inf)
    for t in tri[keep]:
        px = (t[:, 0] - x0) * s
        py = (z1 - t[:, 2]) * s
        i0, i1 = max(int(px.min()), 0), min(int(px.max()) + 1, W - 1)
        j0, j1 = max(int(py.min()), 0), min(int(py.max()) + 1, H - 1)
        if i1 < i0 or j1 < j0:
            continue
        X, Y = np.meshgrid(np.arange(i0, i1 + 1) + 0.5, np.arange(j0, j1 + 1) + 0.5)
        d = (py[1] - py[2]) * (px[0] - px[2]) + (px[2] - px[1]) * (py[0] - py[2])
        if abs(d) < 1e-9:
            continue
        u = ((py[1] - py[2]) * (X - px[2]) + (px[2] - px[1]) * (Y - py[2])) / d
        v = ((py[2] - py[0]) * (X - px[2]) + (px[0] - px[2]) * (Y - py[2])) / d
        w = 1 - u - v
        y = u * t[0, 1] + v * t[1, 1] + w * t[2, 1]
        sub = depth[j0:j1 + 1, i0:i1 + 1]
        hit = (u >= -1e-6) & (v >= -1e-6) & (w >= -1e-6) & (y < sub)
        sub[hit] = y[hit]

    # shade from the depth map itself, so steps in the relief catch the light
    bg = np.isinf(depth)
    dm = np.where(bg, depth[~bg].max() if (~bg).any() else 0.0, depth)
    gz, gx = np.gradient(dm * s)                 # per pixel, rows run downwards
    nrm = np.stack([gx, -np.ones_like(gx), -gz], axis=2)   # (x, y, z) surface normal
    nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)
    light = np.array([-0.5, -0.62, 0.6]); light /= np.linalg.norm(light)
    img = 0.22 + 0.78 * np.clip(nrm @ light, 0, 1)

    rgb = np.stack([img * 0.88, img * 0.91, img * 0.97], axis=2)
    rgb[bg] = 0.97
    Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)).save(a.png)


if __name__ == "__main__":
    main()

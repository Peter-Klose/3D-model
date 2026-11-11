#!/usr/bin/env python3
"""Verify that STL files are printable solids.

Checks per file: watertight (every edge shared by exactly two faces),
consistent winding, positive volume, a single connected body, sits on the
bed (z_min = 0) and fits the build plate.

Overhang check: faces steeper than the allowed angle (bed contact excluded)
count as unsupported unless solid material is reached within one extrusion
line width along a slope of the allowed angle. Ledges narrower than one
line (e.g. the micro-steps of a relief) are fine; real ceilings, bridges
and continuous slopes steeper than the limit are not.

Usage: check_stl.py [--plate 256] [--max-overhang 45] [--line-width 0.45] file.stl ...
Exit code 1 if any file fails.
"""
import argparse
import sys

import numpy as np
import trimesh


def points_inside(tris, pts, cell=2.0):
    """Point-in-solid test: count surface crossings of a ray going straight up.

    Triangles are binned on an XY grid so each point only tests a few of them.
    """
    lo = tris[:, :, :2].min(axis=(0, 1))
    grid = {}
    cmin = np.floor((tris[:, :, :2].min(axis=1) - lo) / cell).astype(int)
    cmax = np.floor((tris[:, :, :2].max(axis=1) - lo) / cell).astype(int)
    for t, (a, b) in enumerate(zip(cmin, cmax)):
        for i in range(a[0], b[0] + 1):
            for j in range(a[1], b[1] + 1):
                grid.setdefault((i, j), []).append(t)
    grid = {k: tris[v] for k, v in grid.items()}
    inside = np.zeros(len(pts), dtype=bool)
    for n, p in enumerate(pts):
        T = grid.get(tuple(np.floor((p[:2] - lo) / cell).astype(int)))
        if T is None:
            continue
        a, b, c = T[:, 0], T[:, 1], T[:, 2]
        # barycentric coordinates of p in the XY projection of each triangle
        d = (b[:, 1] - c[:, 1]) * (a[:, 0] - c[:, 0]) + (c[:, 0] - b[:, 0]) * (a[:, 1] - c[:, 1])
        ok = np.abs(d) > 1e-12
        d = np.where(ok, d, 1.0)
        u = ((b[:, 1] - c[:, 1]) * (p[0] - c[:, 0]) + (c[:, 0] - b[:, 0]) * (p[1] - c[:, 1])) / d
        v = ((c[:, 1] - a[:, 1]) * (p[0] - c[:, 0]) + (a[:, 0] - c[:, 0]) * (p[1] - c[:, 1])) / d
        w = 1 - u - v
        hit = ok & (u >= 0) & (v >= 0) & (w >= 0)
        z = u * a[:, 2] + v * b[:, 2] + w * c[:, 2]
        inside[n] = np.count_nonzero(hit & (z > p[2])) % 2 == 1
    return inside


def check(path, plate, max_overhang, line_width):
    m = trimesh.load(path, force="mesh")
    edges = np.sort(m.edges, axis=1)
    _, counts = np.unique(edges, axis=0, return_counts=True)
    bad_edges = int((counts != 2).sum())
    size = m.extents
    zmin = m.bounds[0][2]
    bodies = m.body_count

    # overhang: angle between surface and vertical; 90 deg = horizontal ceiling
    nz = m.face_normals[:, 2]
    tri_z = m.triangles[:, :, 2]
    on_bed = tri_z.max(axis=1) < zmin + 1e-3
    steep = (nz < -np.sin(np.radians(max_overhang + 1.0))) & ~on_bed
    steep_area = float(m.area_faces[steep].sum())
    # A steep face still prints cleanly if, going one line width sideways and
    # the same distance down (i.e. along a 45 deg slope), we end up in solid
    # material: true for narrow ledges, false for real ceilings and for
    # continuous slopes steeper than the limit.
    unsupported_area = 0.0
    idx = np.flatnonzero(steep)
    if len(idx):
        ang = np.linspace(0, 2 * np.pi, 12, endpoint=False)
        t = np.tan(np.radians(max_overhang))
        ring = np.concatenate([np.stack([np.cos(ang) * d, np.sin(ang) * d, np.full_like(ang, -d / t)], axis=1)
                               for d in np.linspace(0.25, 1.0, 7) * line_width])
        pts = (m.triangles_center[idx][:, None, :] + ring[None]).reshape(-1, 3)
        inside = points_inside(m.triangles, pts)
        supported = inside.reshape(len(idx), -1).any(axis=1)
        unsupported_area = float(m.area_faces[idx[~supported]].sum())

    problems = []
    if bad_edges or not m.is_watertight:
        problems.append(f"{bad_edges} non-manifold/open edges")
    if not m.is_winding_consistent:
        problems.append("inconsistent winding")
    if not m.volume > 0:
        problems.append("non-positive volume")
    if bodies != 1:
        problems.append(f"{bodies} separate bodies")
    if abs(zmin) > 1e-3:
        problems.append(f"z_min = {zmin:.3f} (not on bed)")
    if size[0] > plate or size[1] > plate or size[2] > plate:
        problems.append("does not fit build plate")
    if unsupported_area > 0.5:
        problems.append(f"{unsupported_area:.1f} mm2 unsupported overhang > {max_overhang:g} deg")

    status = "OK  " if not problems else "FAIL"
    print(f"{status} {path.split('/')[-1]:24s} {size[0]:6.1f} x {size[1]:6.1f} x {size[2]:6.1f} mm  "
          f"{len(m.faces):6d} tris  vol {m.volume / 1000:6.1f} cm3  "
          f"micro-ledges {steep_area - unsupported_area:5.1f} mm2  unsupported {unsupported_area:4.1f} mm2"
          + ("" if not problems else "  <- " + "; ".join(problems)))
    return not problems


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("files", nargs="+")
    ap.add_argument("--plate", type=float, default=256, help="build plate edge / height in mm")
    ap.add_argument("--max-overhang", type=float, default=45)
    ap.add_argument("--line-width", type=float, default=0.45, help="extrusion line width in mm")
    a = ap.parse_args()
    ok = all([check(f, a.plate, a.max_overhang, a.line_width) for f in a.files])
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()

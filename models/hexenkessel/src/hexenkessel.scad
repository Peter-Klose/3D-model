// ===========================================================================
// Hexenkessel – witch's cauldron with lid, bail handle and crest
// Parametric OpenSCAD model. All dimensions in mm.
//
// Select what to build with `part` (the export script sets it via -D):
//   "kessel_mit_henkel"  body with lugs for the handle
//   "kessel_ohne_henkel" body without lugs (smooth sides)
//   "deckel"             lid   (print orientation: flat underside on the bed)
//   "henkel"             handle (print orientation: lying flat)
//   "assembly"           everything put together (preview only, not printable)
//   "assembly_stl"       the same, built from the exported files in ../stl/
//
// Everything prints without supports: no overhang is steeper than 45 deg.
// ===========================================================================
use <emblem.scad>

part = "assembly";

// ---------------- key dimensions -------------------------------------------
body_d        = 150;   // outer diameter at the widest point of the belly
body_h        = 120;   // total height of the body (bed to top of rim)
wall          = 2.4;   // wall thickness (6 perimeters with a 0.4 nozzle)
base_d        = 72;    // diameter of the flat bottom
neck_d        = 104;   // outer diameter of the neck
neck_h        = 16;    // height of the straight neck incl. rim
max_overhang  = 45;    // steepest allowed overhang; fixed by the geometry

// ---------------- rim -------------------------------------------------------
rim_r         = 4;     // radius of the rolled rim bead
rim_out       = 1;     // how far the bead centre sits outside the neck surface
seat          = 2.5;   // 45 deg conical lid seat cut into the inside of the rim

// ---------------- legs ------------------------------------------------------
leg_count     = 3;
leg_d         = 13;    // foot diameter
leg_taper     = 1.5;   // legs get this much wider (radius) towards the top
leg_offset    = 9;     // leg axis distance outside the flat bottom edge

// ---------------- lid -------------------------------------------------------
clearance     = 0.3;   // radial gap between lid and rim
lid_plug_h    = 2;     // straight part of the lid reaching into the neck
lid_overlap   = 5;     // lid radius beyond the inner neck radius
lid_edge_h    = 1.2;   // vertical edge of the lid
lid_dome_h    = 7;     // rise of the dome
knob_stem_d   = 9;
knob_d        = 18;
knob_stem_h   = 3;
knob_cap_h    = 4.5;

// ---------------- handle + lugs --------------------------------------------
hinge_clear   = 0.35;  // radial gap pin <-> hole (0.3 .. 0.4)
handle_t      = 4;     // wire thickness (octagonal section, flat to flat)
pin_len       = 4;     // length of the snap-in pins inside the lugs
lug_out       = 8;     // lugs protrude this far from the neck
lug_r         = 6.5;   // lug radius (seen from the side)
lug_drop      = 14;    // pivot axis below the top of the rim
lug_embed     = 1.6;   // how deep the lugs are anchored in the wall
handle_gap    = 0.6;   // gap between lug face and handle
handle_angle  = 70;    // handle position in the assembly view (90 = upright)

// ---------------- emblem ----------------------------------------------------
emblem_on      = true;
emblem_use_svg = false;        // true: import emblem_svg instead of the crest
emblem_svg     = "emblem.svg"; // relative to this file
emblem_h       = 60;           // emblem height
emblem_max_w   = 56;           // widest emblem the relief zone must cover
emblem_relief  = 1.0;          // raised height
emblem_z       = 8;            // emblem centre above the widest point (keeps it
                               // off the strongly overhanging lower belly)
emblem_steps   = 5;            // undersides of the relief are drafted in this
                               // many micro-steps (support-free printing)
emblem_band    = 3;            // the draft is adapted to the wall angle in
                               // horizontal bands of this height
emblem_draft_margin = 1.15;    // safety factor on the 45 deg draft

// ---------------- resolution ------------------------------------------------
fn_body  = 128;  // facets around the body
fn_curve = 44;   // points along the belly curve

// ===========================================================================
// derived values
// ===========================================================================
R       = body_d / 2;
r_base  = base_d / 2;
r_neck  = neck_d / 2;
r_bore  = r_neck - wall;
// The belly is an ellipse limited to the range where its slope is <= 45 deg,
// continued by 45 deg cones down to the flat bottom and up to the neck.
// For that construction the heights add up to 2*S - r_base - r_neck + neck_h.
S       = (body_h + r_base + r_neck - neck_h) / 2;
belly_b = sqrt(S*S - R*R);          // vertical semi axis of the belly
r_e     = R*R / S;                  // radius where ellipse meets the cones
dz_e    = belly_b*belly_b / S;      // height of that point above/below centre
z_c     = (r_e - r_base) + dz_e;    // height of the widest point
t0      = atan(belly_b / R);
z_neck  = z_c + dz_e + (r_e - r_neck);   // start of the straight neck
assert(S > R && r_e > r_neck && r_e > r_base, "belly does not fit: adjust body_h / neck_h / base_d / neck_d");

rim_cx  = r_neck + rim_out;
rim_cz  = body_h - rim_r;

z_pivot = body_h - lug_drop;
x_lug   = r_neck + lug_out;                         // outer face of the lugs
pin_circ_d = handle_t / cos(22.5);                  // octagon across corners
hole_d  = pin_circ_d + 2*hinge_clear;
hole_depth = pin_len + 1;
handle_r = x_lug + handle_gap + handle_t/2;         // centre line radius

r_plug  = r_bore - clearance;
r_lid   = r_bore + lid_overlap;
lid_cone_h = r_lid - r_plug;
lid_z_edge = lid_plug_h + lid_cone_h + lid_edge_h;  // start of the dome
lid_top    = lid_z_edge + lid_dome_h;
lid_seat_z = body_h - seat - lid_plug_h - clearance; // lid origin when seated

echo(widest_point_z = z_c, neck_start_z = z_neck, pivot_z = z_pivot,
     handle_radius = handle_r, hole_d = hole_d, lid_d = 2*r_lid);

// ===========================================================================
// 2D profiles (x = radius, y = height)
// ===========================================================================
function belly_pts() = [for (i = [0:fn_curve]) let (t = -t0 + 2*t0*i/fn_curve)
    [R*cos(t), z_c + belly_b*sin(t)]];

// outer silhouette without rim; `top` lets the cavity run out of the top
module outer_2d(top = body_h)
    polygon(concat([[0, 0], [r_base, 0]], belly_pts(),
                   [[r_neck, z_neck], [r_neck, top], [0, top]]));

// rolled rim: a bead whose underside is closed by a 45 deg tangent
module rim_2d() hull() {
    translate([rim_cx, rim_cz]) circle(rim_r, $fn = 48);
    translate([r_neck - 2, rim_cz - rim_r*sqrt(2) - rim_out - 0.5]) square([2, 2]);
}

module cavity_2d() {
    // offset the full (mirrored) silhouette so the axis itself gets no "wall"
    intersection() {
        offset(delta = -wall) union() {
            outer_2d(body_h + 2*wall + 1);
            mirror([1, 0]) outer_2d(body_h + 2*wall + 1);
        }
        square([R, body_h + 2*wall + 2]);
    }
    // conical lid seat
    polygon([[0, body_h - seat], [r_bore, body_h - seat],
             [r_bore + seat + 1, body_h + 1], [0, body_h + 1]]);
}

module wall_2d() difference() {
    union() { outer_2d(); rim_2d(); }
    cavity_2d();
}

// ===========================================================================
// body
// ===========================================================================
module legs() {
    // legs are vertical stubs under the 45 deg lower cone; their feet are
    // flush with the flat bottom so everything starts on the bed
    intersection() {
        for (i = [0:leg_count-1]) rotate(90 + i*360/leg_count)
            translate([r_base + leg_offset, 0, 0])
                cylinder(r1 = leg_d/2, r2 = leg_d/2 + leg_taper,
                         h = leg_offset + leg_d + 4, $fn = 40);
        rotate_extrude($fn = fn_body)
            polygon([[r_base - 1.5, 0], [R, 0], [R, R - r_base + 1.5]]);
    }
}

module teardrop(d, h) {   // horizontal hole along +x with a 45 deg roof
    rotate([0, 90, 0]) rotate(90) linear_extrude(h) union() {
        circle(d = d, $fn = 40);
        rotate(45) square(d/2);
    }
}

module lug() {
    // side profile (x radial, z up); underside leans back at 45 deg and the
    // inner edge stays inside the wall so nothing pokes into the cavity
    x0 = r_neck - lug_embed;
    zl = z_pivot - lug_r;
    k  = max(0, (lug_embed - r_neck - z_neck + zl + x_lug) / 2);
    difference() {
        intersection() {
            rotate([90, 0, 0]) linear_extrude(2*lug_r + 1, center = true)
                polygon([[x0, z_pivot + lug_r + 1], [x_lug, z_pivot + lug_r + 1],
                         [x_lug, zl], [x_lug - k, zl - k],
                         [x0, zl - k + (x_lug - k - x0)]]);
            hull() for (dz = [0, -3*lug_r]) translate([x0 - 1, 0, z_pivot + dz])
                rotate([0, 90, 0]) cylinder(r = lug_r, h = lug_out + lug_embed + 2, $fn = 48);
        }
        translate([x_lug - hole_depth, 0, z_pivot]) teardrop(hole_d, hole_depth + 1);
    }
}

// thin shell layer hugging the body surface in front (-y), radial offsets a..b
module emblem_zone(a, b) {
    step = 360 / fn_body;
    n = ceil(asin(min(1, (emblem_max_w/2 + 2) / (R*0.85))) / step);
    rotate(270 - n*step) rotate_extrude(angle = 2*n*step, $fn = fn_body)
        intersection() {
            difference() { offset(delta = b) outer_2d(); offset(delta = a) outer_2d(); }
            translate([1, z_c + emblem_z - emblem_h/2 - 8]) square([R + 5, emblem_h + 11]);
        }
}

// Outward lean of the body surface at height z (deg from vertical;
// > 0 = overhanging lower belly, < 0 = upper belly leaning inwards).
function lean(z) =
    let (st = max(-sin(t0), min(sin(t0), (z - z_c) / belly_b)))
    atan(-R * st / (belly_b * cos(asin(st))));

// How far (in multiples of the radial step) a relief edge has to be drawn
// downwards per step so that its underside stays at <= 45 deg. On a vertical
// wall that is 1; the more the wall itself overhangs, the longer the draft.
function draft_factor(z) =
    let (b = min(lean(z), 40)) emblem_draft_margin / (cos(b) - sin(b));

// Emblem as needed for shell k: every horizontal band of the emblem is
// smeared downwards by k steps of its local draft.
module emblem_drafted_2d(k) {
    s  = emblem_relief / emblem_steps;
    nb = ceil(emblem_h / emblem_band);
    for (j = [0:nb-1]) {
        y0 = -emblem_h/2 + j*emblem_band;
        d  = s * draft_factor(z_c + emblem_z + y0 - 4);  // the draft reaches a little below the band
        for (i = [0:2*k]) translate([0, -i*d/2])
            intersection() {
                emblem_2d(emblem_h, emblem_use_svg, emblem_svg);
                translate([-emblem_max_w, y0 - (j == 0 ? 1 : 0)])
                    square([2*emblem_max_w, emblem_band + (j == 0 || j == nb-1 ? 1 : 0)]);
            }
    }
}

// Relief following the curved surface. Built from overlapping shells: shell k
// is k steps lower (radially) and uses the emblem drafted k steps downwards.
// That turns every underside into a fine staircase of <= 45 deg whose steps
// are narrower than one extrusion line, so the relief prints without supports.
module emblem_relief_3d() {
    s = emblem_relief / emblem_steps;
    for (k = [0:emblem_steps-1])
        intersection() {
            emblem_zone(-0.3, emblem_relief - k*s);
            rotate([90, 0, 0]) linear_extrude(R + 5)
                translate([0, z_c + emblem_z]) emblem_drafted_2d(k);
        }
}

module body(with_lugs = true) {
    rotate_extrude($fn = fn_body) wall_2d();
    legs();
    if (with_lugs) for (a = [0, 180]) rotate(a) lug();
    if (emblem_on) emblem_relief_3d();
}

// ===========================================================================
// lid (origin: flat underside, as printed)
// ===========================================================================
module lid() {
    dome_R = (r_lid*r_lid + lid_dome_h*lid_dome_h) / (2*lid_dome_h);
    a_max  = asin(r_lid / dome_R);
    a_min  = asin((knob_stem_d/2 - 0.5) / dome_R);
    n = 32;
    zk = lid_top + knob_stem_h;                 // start of knob flare
    flare = (knob_d - knob_stem_d) / 2;         // 45 deg flare under the cap
    rotate_extrude($fn = fn_body) polygon(concat(
        [[0, 0], [r_plug, 0], [r_plug, lid_plug_h], [r_lid, lid_plug_h + lid_cone_h]],
        [for (i = [0:n]) let (a = a_max - (a_max - a_min)*i/n)
            [dome_R*sin(a), lid_top - dome_R*(1 - cos(a))]],
        [[knob_stem_d/2, zk]],
        [for (i = [0:n]) let (t = 90*i/n)
            [knob_d/2*cos(t), zk + flare + knob_cap_h*sin(t)]]));
}

// ===========================================================================
// handle (origin: lying flat on the bed, pivots at (+-handle_r, 0))
// ===========================================================================
module octagon(t) rotate(22.5) circle(d = t / cos(22.5), $fn = 8);

module handle() {
    rotate_extrude(angle = 180, $fn = fn_body)
        translate([handle_r, handle_t/2]) octagon(handle_t);
    // snap-in pins pointing towards each other
    for (s = [-1, 1]) translate([s*handle_r, 0, handle_t/2]) rotate([0, -s*90, 0]) {
        L = handle_t/2 + handle_gap + pin_len;
        linear_extrude(L - 0.8) octagon(handle_t);
        hull() {   // 45 deg chamfered tip helps the pin snap in
            translate([0, 0, L - 0.8]) linear_extrude(0.01) octagon(handle_t);
            translate([0, 0, L - 0.01]) linear_extrude(0.01) octagon(handle_t - 1.6);
        }
    }
}

// ===========================================================================
// output
// ===========================================================================
if (part == "kessel_mit_henkel")  body(true);
if (part == "kessel_ohne_henkel") body(false);
if (part == "deckel")             lid();
if (part == "henkel")             handle();
module place_lid()    translate([0, 0, lid_seat_z]) children();
module place_handle() translate([0, 0, z_pivot]) rotate([handle_angle, 0, 0])
                          translate([0, 0, -handle_t/2]) children();
if (part == "assembly_stl") {   // same as "assembly" but from the exported STLs
    color("#7d8590")   import("../stl/kessel_mit_henkel.stl", convexity = 10);
    color("SlateGray") place_lid() import("../stl/deckel.stl", convexity = 10);
    color("Silver")    place_handle() import("../stl/henkel.stl", convexity = 10);
}
if (part == "assembly") {
    color("#7d8590")   body(true);
    color("SlateGray") place_lid() lid();
    color("Silver")    place_handle() handle();
}

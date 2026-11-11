// ---------------------------------------------------------------------------
// emblem.scad – 2D emblem for the Hexenkessel
//
// emblem_2d(h, use_svg, svg_file) produces a 2D shape, centred on the origin,
// scaled to a total height of `h` mm. It is turned into a relief that follows
// the cauldron surface by hexenkessel.scad.
//
//   use_svg = false : built-in ORIGINAL wizard-school crest (free to use):
//                     quartered shield (crescent moon, star, owl, key),
//                     letter in the centre, ribbon banner below.
//   use_svg = true  : imports `svg_file` (default src/emblem.svg) instead.
//                     Only filled shapes are used; keep details >= 1 mm.
// ---------------------------------------------------------------------------

// --- crest parameters (design units = mm at 60 mm emblem height) -----------
crest_letter   = "W";     // letter in the centre medallion
crest_motto    = "";      // optional text on the ribbon ("" = three stars)
crest_font     = "DejaVu Sans:style=Bold";
crest_line     = 1.6;     // width of shield border / dividing bars
crest_design_h = 60;      // native height of the drawing (do not change)

module emblem_2d(h = 60, use_svg = false, svg_file = "emblem.svg") {
    if (use_svg)
        resize([0, h], auto = true) import(svg_file, center = true);
    else
        scale(h / crest_design_h) crest_2d();
}

// --- built-in crest ---------------------------------------------------------
shield_w    = 48;   // shield width
shield_top  = 30;   // y of upper edge
shield_mid  = 10;   // y where the straight sides end
shield_tip  = -16;  // y of the lower tip
cross_y     = 8;    // y of the horizontal dividing bar
medal_r     = 6.5;  // radius of centre medallion

function shield_pts(n = 24) = concat(
    [[-shield_w/2, shield_top], [shield_w/2, shield_top]],
    [for (i = [0:n]) let (u = i/n)
        [ shield_w/2 * (1 - u*u), shield_mid - u * (shield_mid - shield_tip)]],
    [for (i = [n-1:-1:0]) let (u = i/n)
        [-shield_w/2 * (1 - u*u), shield_mid - u * (shield_mid - shield_tip)]]);

module shield() polygon(shield_pts());

module star(ro = 6.5, ri = 2.8, n = 5)
    polygon([for (i = [0:2*n-1]) let (r = i % 2 ? ri : ro, a = 90 + i*180/n)
        [r*cos(a), r*sin(a)]]);

module moon(r = 6.5)
    rotate(-25) difference() {
        circle(r, $fn = 48);
        translate([r*0.48, 0]) circle(r*0.82, $fn = 48);
    }

module owl() {
    difference() {
        union() {
            scale([0.82, 1]) circle(5, $fn = 40);                 // body
            translate([0, 4.2]) circle(3.6, $fn = 40);            // head
            for (s = [-1, 1])                                     // ear tufts
                translate([0, 4.2]) polygon([[s*1.0, 2.6], [s*3.5, 1.0], [s*3.9, 5.6]]);
            for (s = [-1, 1])                                     // feet
                translate([s*1.6, -5.4]) square([1.6, 1.6], center = true);
        }
        for (s = [-1, 1]) translate([s*1.55, 4.7]) circle(1.05, $fn = 20);  // eyes
        polygon([[-0.7, 3.2], [0.7, 3.2], [0, 1.9]]);                       // beak
        translate([0, -1.2]) scale([0.45, 1]) circle(2.6, $fn = 24);        // belly
    }
}

module key() {
    rotate(-35) {
        translate([0, 5]) difference() {                          // bow
            circle(3.2, $fn = 32);
            circle(1.5, $fn = 24);
        }
        translate([-0.8, -6.5]) square([1.6, 9]);                 // shaft
        translate([0.6, -6.5]) square([2.6, 1.5]);                // bit
        translate([0.6, -3.6]) square([1.9, 1.4]);
    }
}

module ribbon() {
    bw = 34; bh = 8; by = -24.5;   // band width / height / centre y
    // band outline
    difference() {
        translate([0, by]) square([bw, bh], center = true);
        translate([0, by]) square([bw - 2*1.3, bh - 2*1.3], center = true);
    }
    // band content: motto or three little stars
    if (crest_motto != "")
        translate([0, by]) text(crest_motto, size = 3.6, font = crest_font,
                                halign = "center", valign = "center", $fn = 24);
    else
        for (x = [-9, 0, 9]) translate([x, by]) star(1.9, 0.85);
    // swallow tails, tucked behind the band
    for (s = [-1, 1]) difference() {
        polygon([[s*(bw/2 - 2), by + bh/2 - 2], [s*24, by + bh/2 - 2],
                 [s*21.3, by - 1.75], [s*24, by - bh/2 - 1.5],
                 [s*(bw/2 - 2), by - bh/2 - 1.5]]);
        translate([0, by]) square([bw + 2*0.9, 3*bh], center = true);
    }
}

module crest_2d() {
    // shield border
    difference() { shield(); offset(delta = -crest_line) shield(); }
    // quartering bars (interrupted by the medallion)
    difference() {
        intersection() {
            shield();
            union() {
                translate([0, (shield_top + shield_tip)/2])
                    square([crest_line, shield_top - shield_tip], center = true);
                translate([0, cross_y]) square([shield_w, crest_line], center = true);
            }
        }
        translate([0, cross_y]) circle(medal_r - 0.1, $fn = 48);
    }
    // centre medallion with letter
    translate([0, cross_y]) {
        difference() { circle(medal_r, $fn = 48); circle(medal_r - 1.3, $fn = 48); }
        text(crest_letter, size = 5.6, font = crest_font,
             halign = "center", valign = "center", $fn = 24);
    }
    // the four charges
    translate([-13.2, 20.3]) moon();
    translate([ 13.2, 19.8]) star();
    translate([-10.2, -1.6]) scale(0.86) owl();
    translate([ 10.0, -1.2]) scale(0.92) key();
    ribbon();
}

// preview when this file is opened directly
emblem_2d();

fun min(a, b) {
    if (a < b) return a;
    return b;
}

fun max(a, b) {
    if (a > b) return a;
    return b;
}

// tan(a) = sin(a)/sin((pi/2)-a)
fun tan(a) {
    return(a.sin()/(1.5707963-a).sin());
}

class Vec3 {
    init(self, x, y, z) {
        self.x = x;
        self.y = y;
        self.z = z;
    }
}

let width = 600;
let height = 600;

// Cube
let a = Vec3(0, 0, 0);
let b = Vec3(0, 1, 0);
let c = Vec3(1, 1, 0);
let d = Vec3(1, 0, 0);

let e = Vec3(0, 1, 1);
let f = Vec3(1, 1, 1);
let g = Vec3(1, 0, 1);

let h = Vec3(0, 0, 1);

// FRONT = abcd
// TOP = befc
// RIGHT = cfgd
// BOTTOM = gdah
// LEFT = abeh

// Triangles for each side (clockwise)
let south = [
    [a,b,c], 
    [a,c,d]
];

let north = [
    [h,e,f],
    [h,f,g]
];

let east = [
    [d,c,f],
    [d,f,g]
];

let west = [
    [a,b,e],
    [a,b,h]
];

let top = [
    [b,e,f],
    [b,f,c]
];

let bottom = [
    [a,h,g],
    [a,g,d]
];

// Projecton matrix setup
let fNear = 0.1;
let fFar = 1000.0;
let fFov = 90.0; // Degrees
let fAspectRatio = (width/height);

let fFovRad = 1/tan((fFov*0.5/180)*3.14159);

// Fill projection matrix with 0s
let matProj = [];
for (let var i = 0; i < 4; ++i) {
    let row = [];
    for (let var j = 0; j < 4; ++j) {
        row.push(0.0);
    }
    matProj.push(row);
}

matProj[0][0] = fAspectRatio*fFovRad;
    $println(matProj[0][0].to_s());
matProj[1][1] = fFovRad;
    $println(matProj[1][1].to_s());
matProj[2][2] = fFar / (fFar - fNear);
    $println(matProj[2][2].to_s());
matProj[2][3] = 1.0;
    $println(matProj[2][3].to_s());
matProj[3][2] = (-fFar * fNear) / (fFar - fNear);
    $println(matProj[3][2].to_s());

// Vec1 = i
// Vec2 = o
// matProj = m

fun multMatVec(i, m) {
    let o = Vec3(0, 0, 0);
    
    o.x = i.x * m[0][0] + i.y * m[1][0] + i.z * m[2][0] + m[3][0];
    o.y = i.x * m[0][1] + i.y * m[1][1] + i.z * m[2][1] + m[3][1];
    o.z = i.x * m[0][2] + i.y * m[1][2] + i.z * m[2][2] + m[3][2];
    let w = i.x * m[0][3] + i.y * m[1][3] + i.z * m[2][3] + m[3][3];

    $println("w: " + w.to_s());
    if (w.floor() != 0) {
        o.x = o.x/w;
        o.y = o.y/w;
        o.z = o.z/w;
    }

    return o;
}

let var v1 = multMatVec(Vec3(a.x, a.y, a.z + 3), matProj);
let var v2 = multMatVec(Vec3(b.x, b.y, b.z + 3), matProj);
let var v3 = multMatVec(Vec3(c.x, c.y, c.z + 3), matProj);
let var v4 = multMatVec(Vec3(d.x, d.y, d.z + 3), matProj);
let var v5 = multMatVec(Vec3(e.x, e.y, e.z + 3), matProj);
let var v6 = multMatVec(Vec3(f.x, f.y, f.z + 3), matProj);
let var v7 = multMatVec(Vec3(g.x, g.y, g.z + 3), matProj);
let var v8 = multMatVec(Vec3(h.x, h.y, h.z + 3), matProj);

// Map projected coordinates to screen space (centered)
let v1_screen_x = (v1.x + 1) * 0.4 * width;
let v1_screen_y = (v1.y + 1) * 0.4 * height;
let v2_screen_x = (v2.x + 1) * 0.4 * width;
let v2_screen_y = (v2.y + 1) * 0.4 * height;
let v3_screen_x = (v3.x + 1) * 0.4 * width;
let v3_screen_y = (v3.y + 1) * 0.4 * height;
let v4_screen_x = (v4.x + 1) * 0.4 * width;
let v4_screen_y = (v4.y + 1) * 0.4 * height;
let v5_screen_x = (v5.x + 1) * 0.4 * width;
let v5_screen_y = (v5.y + 1) * 0.4 * height;
let v6_screen_x = (v6.x + 1) * 0.4 * width;
let v6_screen_y = (v6.y + 1) * 0.4 * height;
let v7_screen_x = (v7.x + 1) * 0.4 * width;
let v7_screen_y = (v7.y + 1) * 0.4 * height;
let v8_screen_x = (v8.x + 1) * 0.4 * width;
let v8_screen_y = (v8.y + 1) * 0.4 * height;

$println("v1: x=" + v1.x.to_s() + ", y=" + v1.y.to_s() + ", z=" + v1.z.to_s());
$println("v2: x=" + v2.x.to_s() + ", y=" + v2.y.to_s() + ", z=" + v2.z.to_s());
$println("v3: x=" + v3.x.to_s() + ", y=" + v3.y.to_s() + ", z=" + v3.z.to_s());
$println("v4: x=" + v4.x.to_s() + ", y=" + v4.y.to_s() + ", z=" + v4.z.to_s());
$println("v5: x=" + v5.x.to_s() + ", y=" + v5.y.to_s() + ", z=" + v5.z.to_s());
$println("v6: x=" + v6.x.to_s() + ", y=" + v6.y.to_s() + ", z=" + v6.z.to_s());
$println("v7: x=" + v7.x.to_s() + ", y=" + v7.y.to_s() + ", z=" + v7.z.to_s());
$println("v8: x=" + v8.x.to_s() + ", y=" + v8.y.to_s() + ", z=" + v8.z.to_s());

let framebuffer = ByteArray.with_size(width * height * 4);

// Clear to black
framebuffer.fill_u32(0, width * height, 0xFF000000);

// Draw projected vertices as white pixels
fun draw(x, y) {
    let ix = x.floor();
    let iy = y.floor();
    $println("draw: ix=" + ix.to_s() + ", iy=" + iy.to_s());
    if (ix >= 0 && ix < width && iy >= 0 && iy < height) {
        let idx = (iy*width + ix);
        framebuffer.write_u32(idx, 0xFFFFFFFF);
    }
}

// Draw a line between (x0, y0) and (x1, y1) using Bresenham's algorithm
fun drawline(x0, y0, x1, y1) {
    let ix0 = x0.floor();
    let iy0 = y0.floor();
    let ix1 = x1.floor();
    let iy1 = y1.floor();

    let dx = (ix1 - ix0).abs();
    let dy = -(iy1 - iy0).abs();
    let sx = ix0 < ix1 ? 1 : -1;
    let sy = iy0 < iy1 ? 1 : -1;
    let var err = dx + dy;

    let var x = ix0;
    let var y = iy0;
    while (true) {
        if (x >= 0 && x < width && y >= 0 && y < height) {
            let idx = (y*width + x);
            framebuffer.write_u32(idx, 0xFFFFFFFF);
        }
        if (x == ix1 && y == iy1) break;
        let var e2 = 2 * err;
        if (e2 >= dy) {
            err = err + dy;
            x = x + sx;
        }
        if (e2 <= dx) {
            err = err + dx;
            y = y + sy;
        }
    }
}

// Draw a triangle by drawing its three edges
fun drawtriangle(x0, y0, x1, y1, x2, y2) {
    drawline(x0, y0, x1, y1);
    drawline(x1, y1, x2, y2);
    drawline(x2, y2, x0, y0);
}

drawtriangle(v1_screen_x, v1_screen_y, v2_screen_x, v2_screen_y, v3_screen_x, v3_screen_y);
// Draw additional triangles as per a-h = v1-v8 mapping
// acd: a=v1, c=v3, d=v4
drawtriangle(v1_screen_x, v1_screen_y, v3_screen_x, v3_screen_y, v4_screen_x, v4_screen_y);
// bef: b=v2, e=v5, f=v6
drawtriangle(v2_screen_x, v2_screen_y, v5_screen_x, v5_screen_y, v6_screen_x, v6_screen_y);
// bfc: b=v2, f=v6, c=v3
drawtriangle(v2_screen_x, v2_screen_y, v6_screen_x, v6_screen_y, v3_screen_x, v3_screen_y);
// dcf: d=v4, c=v3, f=v6
drawtriangle(v4_screen_x, v4_screen_y, v3_screen_x, v3_screen_y, v6_screen_x, v6_screen_y);
// dfg: d=v4, f=v6, g=v7
drawtriangle(v4_screen_x, v4_screen_y, v6_screen_x, v6_screen_y, v7_screen_x, v7_screen_y);
// abe: a=v1, b=v2, e=v5
drawtriangle(v1_screen_x, v1_screen_y, v2_screen_x, v2_screen_y, v5_screen_x, v5_screen_y);
// abh: a=v1, b=v2, h=v8
drawtriangle(v1_screen_x, v1_screen_y, v2_screen_x, v2_screen_y, v8_screen_x, v8_screen_y);

// ahg: a=v1, h=v8, g=v7
drawtriangle(v1_screen_x, v1_screen_y, v8_screen_x, v8_screen_y, v7_screen_x, v7_screen_y);
// agd: a=v1, g=v7, d=v4
drawtriangle(v1_screen_x, v1_screen_y, v7_screen_x, v7_screen_y, v4_screen_x, v4_screen_y);

// hef
drawtriangle(v8_screen_x, v8_screen_y, v5_screen_x, v5_screen_y, v6_screen_x, v6_screen_y);
// hfg: b=v2, f=v6, c=v3 (duplicate, but included as per request)
drawtriangle(v8_screen_x, v8_screen_y, v6_screen_x, v6_screen_y, v8_screen_x, v8_screen_y);

// Draw in a window
let window = $window_create(width, height, "Render", 0);

$window_draw_frame(window, framebuffer);

loop {
    let msg = $actor_recv();

    if (!(msg instanceof UIEvent)) {
        continue;
    }
    if (msg.kind == 'CLOSE_WINDOW' || (msg.kind == 'KEY_DOWN' && msg.key == 'ESCAPE')) {
        break;
    }
}




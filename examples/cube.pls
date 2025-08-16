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

fun cos(a) {
    return((a + 1.5707963).sin());
}

// Initialise 4x4 matrix
fun initMat4() {
    let m = [];
    
    for (let var i = 0; i < 4; ++i) {
        let row = Array.with_size(4, 0);
        m.push(row);
    }

    return m;
}

class Vec3 {
    init(self, x, y, z) {
        self.x = x;
        self.y = y;
        self.z = z;
    }
}

// Screen setup
let WIDTH = 600;
let HEIGHT = 600;

// Vertices setup (centered at origin)
let a = Vec3(-1, -1, -1);
let b = Vec3(-1,  1, -1);
let c = Vec3( 1,  1, -1);
let d = Vec3( 1, -1, -1);
let e = Vec3(-1,  1,  1);
let f = Vec3( 1,  1,  1);
let g = Vec3( 1, -1,  1);
let h = Vec3(-1, -1,  1);

// Array of vertices
let vertices = [a, b, c, d, e, f, g, h];

// Time setup
let var time = $time_current_ms();
let var fTheta = 1.0 * time;

// Projecton matrix setup
let fNear = 0.1;
let fFar = 1000.0;
let fFov = 90.0; // Degrees
let fAspectRatio = (WIDTH/HEIGHT);
let fFovRad = 1/tan((fFov*0.5/180)*3.14159);

// Create empty 4x4 matrices
let matProj = initMat4();
let matRotZ = initMat4();
let matRotX = initMat4();

// Projection
matProj[0][0] = fAspectRatio*fFovRad;
matProj[1][1] = fFovRad;
matProj[2][2] = fFar / (fFar - fNear);
matProj[2][3] = 1.0;
matProj[3][2] = (-fFar * fNear) / (fFar - fNear);

// Rotation Z
matRotZ[0][0] = cos(fTheta);
matRotZ[0][1] = (fTheta).sin();
matRotZ[1][0] = -((fTheta).sin());
matRotZ[1][1] = cos(fTheta);
matRotZ[2][2] = 1.0;
matRotZ[3][3] = 1.0;

// Rotation X
matRotX[0][0] = 1.0;
matRotX[1][1] = cos(fTheta * 0.5);
matRotX[1][2] = (fTheta * 0.5).sin();
matRotX[2][1] = -((fTheta * 0.5).sin());
matRotX[2][2] = cos(fTheta * 0.5);
matRotX[3][3] = 1.0;

// i: input
// m: matrix
fun multMatVec(i, m) {
    let o = Vec3(0, 0, 0);
    
    o.x = i.x * m[0][0] + i.y * m[1][0] + i.z * m[2][0] + m[3][0];
    o.y = i.x * m[0][1] + i.y * m[1][1] + i.z * m[2][1] + m[3][1];
    o.z = i.x * m[0][2] + i.y * m[1][2] + i.z * m[2][2] + m[3][2];
    let w = i.x * m[0][3] + i.y * m[1][3] + i.z * m[2][3] + m[3][3];

    if (w.floor() != 0) {
        o.x = o.x/w;
        o.y = o.y/w;
    }

    return o;
}

let var vars = [];
for (let var i = 0; i < 8; ++i) {
    vars.push(multMatVec(vertices[i], matRotZ));
}

for (let var i = 0; i < 8; ++i) {
    vars[i] = multMatVec(vars[i], matRotX);
}

for (let var i = 0; i < 8; ++i) {
    vars[i] = multMatVec(Vec3(vars[i].x, vars[i].y, vars[i].z + 3), matProj);
}

for (let var i = 0; i < 8; ++i) {
    vars[i] = Vec3(
        (vars[i].x + 1) * 0.5 * WIDTH,
        (vars[i].y + 1) * 0.5 * HEIGHT,
        vars[i].z
    );
}

// Create framebuffer
let framebuffer = ByteArray.with_size(WIDTH * HEIGHT * 4);

// Clear to black
framebuffer.fill_u32(0, WIDTH * HEIGHT, 0xFF000000);

// Draw a line between v0(x0, y0) and v1(x1, y1) using Bresenham's algorithm
fun drawline(v0, v1) {
    let ix0 = v0.x.floor();
    let iy0 = v0.y.floor();
    let ix1 = v1.x.floor();
    let iy1 = v1.y.floor();

    let dx = (ix1 - ix0).abs();
    let dy = -(iy1 - iy0).abs();
    let sx = ix0 < ix1 ? 1 : -1;
    let sy = iy0 < iy1 ? 1 : -1;
    let var err = dx + dy;

    let var x = ix0;
    let var y = iy0;
    while (true) {
        if (x >= 0 && x < WIDTH && y >= 0 && y < HEIGHT) {
            let idx = (y*WIDTH + x);
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
fun drawtriangle(v0, v1, v2) {
    drawline(v0, v1);
    drawline(v1, v2);
    drawline(v2, v0);
}

// Indices for each triangle
let triangles = [
    [0, 1, 2], // abc
    [0, 2, 3], // acd
    [1, 4, 5], // bef
    [1, 5, 2], // bfc
    [3, 2, 5], // dcf
    [3, 5, 6], // dfg
    [0, 1, 4], // abe
    [0, 4, 7], // aeh
    [0, 7, 6], // ahg
    [0, 6, 3], // agd
    [7, 4, 5], // hef
    [7, 5, 6], // hfg
];

for (let var i = 0; i < triangles.len; ++i) {
    let t = triangles[i];
    drawtriangle(vars[t[0]], vars[t[1]], vars[t[2]]);
}

fun rasterize_triangle(framebuffer, width, height, v0, v1, v2, color) {
    // Convert vertices to integer coordinates
    let x0 = v0.x.floor();
    let y0 = v0.y.floor();
    let x1 = v1.x.floor();
    let y1 = v1.y.floor();
    let x2 = v2.x.floor();
    let y2 = v2.y.floor();

    // Compute bounding box
    let minX = max(0, min(x0, min(x1, x2)));
    let maxX = min(width - 1, max(x0, max(x1, x2)));
    let minY = max(0, min(y0, min(y1, y2)));
    let maxY = min(height - 1, max(y0, max(y1, y2)));

    // Precompute barycentric coordinate divisors
    let area = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2);
    if (area == 0) return; // Degenerate triangle

    // Scan through bounding box
    for (let var y = minY; y <= maxY; y = y + 1) {
        for (let var x = minX; x <= maxX; x = x + 1) {
            // Compute barycentric coordinates
            let w0 = (y1 - y2) * (x - x2) + (x2 - x1) * (y - y2);
            let w1 = (y2 - y0) * (x - x2) + (x0 - x2) * (y - y2);
            let w2 = area - w0 - w1;

            // Check if point is inside triangle. Respect triangle winding by
            // comparing barycentric weights with the sign of `area`.
            if ((area > 0 && w0 >= 0 && w1 >= 0 && w2 >= 0) ||
                (area < 0 && w0 <= 0 && w1 <= 0 && w2 <= 0)) {
                let index = y * width + x;
                framebuffer.write_u32(index, color);
            }
        }
    }
}

let color = [
    0xFFFF0000,
    0xFFFF0000,
    0xFF00FF00,
    0xFF00FF00,
    0xFF0000FF,
    0xFF0000FF,
    0xFFFFFF00,
    0xFFFFFF00,
    0xFFFF00FF,
    0xFFFF00FF,
    0xFF00FFFF,
    0xFF00FFFF
];

// Draw in a window
let window = $window_create(WIDTH, HEIGHT, "Cube", 0);
$window_draw_frame(window, framebuffer);

loop {
    time = $time_current_ms();
    fTheta = 0.001 * time;

    matRotZ[0][0] = cos(fTheta);
    matRotZ[0][1] = (fTheta).sin();
    matRotZ[1][0] = -((fTheta).sin());
    matRotZ[1][1] = cos(fTheta);

    matRotX[1][1] = cos(fTheta * 0.5);
    matRotX[1][2] = (fTheta * 0.5).sin();
    matRotX[2][1] = -((fTheta * 0.5).sin());
    matRotX[2][2] = cos(fTheta * 0.5);

    for (let var i = 0; i < 8; ++i) {
        // Apply rotation Z
        // Use original vertices as reset
        vars[i] = multMatVec(vertices[i], matRotZ);

        // Apply rotation X
        vars[i] = multMatVec(vars[i], matRotX);

        // Project and move forward in z
        vars[i] = multMatVec(Vec3(vars[i].x, vars[i].y, vars[i].z + 3), matProj);

        // Recalculate screen coordinates
        vars[i].x = (vars[i].x + 1) * 0.5 * WIDTH;
        vars[i].y = (vars[i].y + 1) * 0.5 * HEIGHT;
    }

    framebuffer.fill_u32(0, WIDTH*HEIGHT, 0xFF000000);

    for (let var i = 0; i < triangles.len; ++i) {
        let t = triangles[i];
        rasterize_triangle(framebuffer, WIDTH, HEIGHT, vars[t[0]], vars[t[1]], vars[t[2]], color[i]);
    }

    for (let var i = 0; i < triangles.len; ++i) {
        let t = triangles[i];
        drawtriangle(vars[t[0]], vars[t[1]], vars[t[2]]);
    }

    $window_draw_frame(window, framebuffer);

    let msg = $actor_poll();

    if (msg == nil) {
        continue;
    }
    if (!(msg instanceof UIEvent)) {
        continue;
    }
    if (msg.kind == 'CLOSE_WINDOW' || (msg.kind == 'KEY_DOWN' && msg.key == 'ESCAPE')) {
        break;
    }
    
    $actor_sleep(33);
}
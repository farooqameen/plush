// Colors for each triangle (face)
let face_colors = [
    0xFFFF0000, // Red
    0xFFFF0000, // Red
    0xFF00FF00, // Green
    0xFF00FF00, // Green
    0xFF0000FF, // Blue
    0xFF0000FF, // Blue
    0xFFFFFF00, // Yellow
    0xFFFFFF00, // Yellow
    0xFF00FFFF, // Cyan
    0xFF00FFFF, // Cyan
    0xFFFF00FF, // Magenta
    0xFFFF00FF, // Magenta
];
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
        o.z = o.z/w;
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

// Map projected coordinates to screen space (centered) using a loop
let var screen_x = [];
let var screen_y = [];
for (let var i = 0; i < 8; ++i) {
    screen_x.push((vars[i].x + 1) * 0.5 * WIDTH);
    screen_y.push((vars[i].y + 1) * 0.5 * HEIGHT);
}

// Create framebuffer and z-buffer
let framebuffer = ByteArray.with_size(WIDTH * HEIGHT * 4);
let zbuffer = Array.with_size(WIDTH * HEIGHT, 1e9); // Large initial value (far away)

// Clear to black and reset z-buffer
framebuffer.fill_u32(0, WIDTH * HEIGHT, 0xFF000000);
for (let var i = 0; i < zbuffer.len; ++i) zbuffer[i] = 1e9;

// Draw projected vertices as white pixels
fun draw(x, y) {
    let ix = x.floor();
    let iy = y.floor();
    if (ix >= 0 && ix < WIDTH && iy >= 0 && iy < HEIGHT) {
        let idx = (iy * WIDTH + ix);
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
fun drawtriangle(x0, y0, x1, y1, x2, y2) {
    drawline(x0, y0, x1, y1);
    drawline(x1, y1, x2, y2);
    drawline(x2, y2, x0, y0);
}

// Indices for each triangle (using screen_x/y arrays)
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

// Rasterize a triangle into a ByteArray framebuffer
fun rasterize(framebuffer, zbuffer, width, height, v0, v1, v2, color) {
    // Convert vertices to integer coordinates (already in screen space)
    let x0 = v0.x.floor();
    let y0 = v0.y.floor();
    let z0 = v0.z;
    let x1 = v1.x.floor();
    let y1 = v1.y.floor();
    let z1 = v1.z;
    let x2 = v2.x.floor();
    let y2 = v2.y.floor();
    let z2 = v2.z;


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

            // Check if point is inside triangle (handle both windings)
            if ((area > 0 && w0 >= 0 && w1 >= 0 && w2 >= 0) || (area < 0 && w0 <= 0 && w1 <= 0 && w2 <= 0)) {
                // Interpolate z
                let f0 = w0 / area;
                let f1 = w1 / area;
                let f2 = w2 / area;
                let z = f0 * z0 + f1 * z1 + f2 * z2;
                let index = y * width + x;
                if (z < zbuffer[index]) {
                    zbuffer[index] = z;
                    framebuffer.write_u32(index, color);
                }
            }
        }
    }
}

for (let var i = 0; i < triangles.len; ++i) {
    let t = triangles[i];
    let color = face_colors[i];
    // Backface culling: use pre-projection (view space) coordinates
    let v0w = vars[t[0]];
    let v1w = vars[t[1]];
    let v2w = vars[t[2]];
    let ux = v1w.x - v0w.x;
    let uy = v1w.y - v0w.y;
    let uz = v1w.z - v0w.z;
    let vx = v2w.x - v0w.x;
    let vy = v2w.y - v0w.y;
    let vz = v2w.z - v0w.z;
    let nx = uy * vz - uz * vy;
    let ny = uz * vx - ux * vz;
    let nz = ux * vy - uy * vx;
    // Camera looks down -z, so cull if normal.z > 0
    if (nz > 0) continue;
    drawtriangle(screen_x[t[0]], screen_y[t[0]], screen_x[t[1]], screen_y[t[1]], screen_x[t[2]], screen_y[t[2]]);
    let v0 = Vec3(screen_x[t[0]], screen_y[t[0]], vars[t[0]].z);
    let v1 = Vec3(screen_x[t[1]], screen_y[t[1]], vars[t[1]].z);
    let v2 = Vec3(screen_x[t[2]], screen_y[t[2]], vars[t[2]].z);
    rasterize(framebuffer, zbuffer, WIDTH, HEIGHT, v0, v1, v2, color);
}

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
        // Reset vars from original vertices
        vars[i] = vertices[i];

        // Apply rotation Z
        vars[i] = multMatVec(vars[i], matRotZ);

        // Apply rotation X
        vars[i] = multMatVec(vars[i], matRotX);

        // Project and move forward in z
        vars[i] = multMatVec(Vec3(vars[i].x, vars[i].y, vars[i].z + 3), matProj);

        // Recalculate screen coordinates
        screen_x[i] = (vars[i].x + 1) * 0.5 * WIDTH;
        screen_y[i] = (vars[i].y + 1) * 0.5 * HEIGHT;
    }

    framebuffer.fill_u32(0, WIDTH*HEIGHT, 0xFF000000);
    for (let var i = 0; i < zbuffer.len; ++i) zbuffer[i] = 1e9;

    for (let var i = 0; i < triangles.len; ++i) {
        let t = triangles[i];
        let color = face_colors[i];
        let v0 = Vec3(screen_x[t[0]], screen_y[t[0]], vars[t[0]].z);
        let v1 = Vec3(screen_x[t[1]], screen_y[t[1]], vars[t[1]].z);
        let v2 = Vec3(screen_x[t[2]], screen_y[t[2]], vars[t[2]].z);
        rasterize(framebuffer, zbuffer, WIDTH, HEIGHT, v0, v1, v2, color);
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
    
    $actor_sleep(16);
}




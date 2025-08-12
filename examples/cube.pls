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

let width = 800;
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
    [b,e,f],
    [b,f,c]
];

let east = [
    [d,c,f],
    [d,f,g]
];

let west = [
    [a,b,e],
    [a,e,h]
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

let fFovRad = 1-tan((fFov*0.5/180)*3.14159);

// Fill projection matrix with 0s
let matProj = [];
for (let var i = 0; i < 4; ++i) {
    let row = [];
    for (let var j = 0; j < 4; ++j) {
        row.push(1.0);
    }
    matProj.push(row);
}

matProj[0][0] = fAspectRatio*fFovRad;
    $println(matProj[0][0].to_s());
matProj[1][1] = fFovRad;
    $println(matProj[1][1].to_s());
matProj[2][2] = fFar / (fFar - fNear);
    $println(matProj[2][2].to_s());
matProj[3][2] = (-fFar * fNear) / (fFar - fNear);
    $println(matProj[3][2].to_s());
matProj[2][3] = 1.0;
    $println(matProj[2][3].to_s());
matProj[3][3] = 0.0;
    $println(matProj[3][3].to_s());

// Vec1 = i
// Vec2 = o
// matProj = m

fun multMatVec(i, m) {
    let o = Vec3(0, 0, 0);
    
    o.x = i.x * m[0][0] + i.y * m[1][0] + i.z * m[2][0] + m[3][0];
    o.y = i.x * m[0][1] + i.y * m[1][1] + i.z * m[2][1] + m[3][1];
    o.z = i.x * m[0][2] + i.y * m[1][2] + i.z * m[2][2] + m[3][2];
    let w = i.x * m[0][3] + i.y * m[1][3] + i.z * m[2][3] + m [3][3];

    if (w != 0) {
        o.x = o.x/w;
        o.y = o.y/w;
        o.z = o.z/w;
    }

    return o;
}

let v1 = multMatVec(a, matProj);
let v2 = multMatVec(b, matProj);
let v3 = multMatVec(c, matProj);

loop {
    let msg = $actor_recv();

    if (!(msg instanceof UIEvent)) {
        continue;
    }
    if (msg.kind == 'CLOSE_WINDOW' || (msg.kind == 'KEY_DOWN' && msg.key == 'ESCAPE')) {
        break;
    }
}




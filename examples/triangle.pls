fun max(a, b) {
    if (a > b) return a;
    return b;
}

fun min(a, b) {
    if (a < b) return a;
    return b;
}

class Vector2 {
    init(self, x, y) {
        self.x = x;
        self.y = y;
    }
}

fun rasterize_tile(xmin, ymin, xmax, ymax, width, height, v0, v1, v2, color) {
    let tile_width = xmax - xmin;
    let tile_height = ymax - ymin;
    let tile_img = Image(tile_width, tile_height);

    // Convert vertices to integer coordinates
    let x0 = (v0.x * width).floor();
    let y0 = (v0.y * height).floor();
    let x1 = (v1.x * width).floor();
    let y1 = (v1.y * height).floor();
    let x2 = (v2.x * width).floor();
    let y2 = (v2.y * height).floor();

    // Compute bounding box for the triangle, clipped to tile bounds
    let minX = max(xmin, min(x0, min(x1, x2)));
    let maxX = min(xmax - 1, max(x0, max(x1, x2)));
    let minY = max(ymin, min(y0, min(y1, y2)));
    let maxY = min(ymax - 1, max(y0, max(y1, y2)));

    // Precompute barycentric coordinate divisors
    let area = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2);
    if (area == 0) return tile_img; // Degenerate triangle

    // Scan through the clipped bounding box
    for (let var y = minY; y <= maxY; y = y + 1) {
        for (let var x = minX; x <= maxX; x = x + 1) {
            // Compute barycentric coordinates
            let w0 = (y1 - y2) * (x - x2) + (x2 - x1) * (y - y2);
            let w1 = (y2 - y0) * (x - x2) + (x0 - x2) * (y - y2);
            let w2 = area - w0 - w1;

            // Check if point is inside triangle
            if (w0 >= 0 && w1 >= 0 && w2 >= 0) {
                // Convert global coordinates to tile-local coordinates
                tile_img.set_pixel(x - xmin, y - ymin, color);
            }
        }
    }
    
    return tile_img;
}

let WIDTH = 600;
let HEIGHT = 600;
let TILE_SIZE = 60;
let framebuffer = ByteArray.with_size(WIDTH * HEIGHT * 4);

// Clear to black
framebuffer.fill_u32(0, WIDTH * HEIGHT, 0xFF000000);

// Triangle vertices in normalized coordinates [0,1]
let v0 = Vector2(0.5, 0.2); // Top vertex
let v1 = Vector2(0.9, 0.8); // Bottom-right vertex
let v2 = Vector2(0.1, 0.8); // Bottom-left vertex

class RenderRequest
{
    init(self, xmin, ymin, xmax, ymax, x, y, color, v0, v1, v2)
    {
        self.xmin = xmin;
        self.ymin = ymin;
        self.xmax = xmax;
        self.ymax = ymax;
        self.x = x;
        self.y = y;
        self.color = color;
        self.v0 = v0;
        self.v1 = v1;
        self.v2 = v2;
    }
}

class RenderResult
{
    init(self, tile_img, x, y, actor_id)
    {
        self.tile_img = tile_img;
        self.x = x;
        self.y = y;
        self.actor_id = actor_id;
    }
}

class Image
{
    init(self, width, height)
    {
        assert(width instanceof Int64);
        assert(height instanceof Int64);

        self.width = width;
        self.height = height;
        self.bytes = ByteArray.with_size(4 * width * height);
    }

    // The color is specified as an u32 value in RGBA32 format
    set_pixel(self, x, y, color)
    {
        let idx = y * self.width + x;
        self.bytes.write_u32(idx, color);
    }

    // Copy a source image into this image at a given position
    blit(self, src_img, dst_x, dst_y)
    {
        let var dst_x = dst_x;
        let var dst_y = dst_y;
        let var src_x = 0;
        let var src_y = 0;
        let var width = src_img.width;
        let var height = src_img.height;

        if (dst_x < 0)
        {
            src_x = -dst_x;
            width = width + dst_x;
            dst_x = 0;
        }

        if (dst_y < 0)
        {
            src_y = -dst_y;
            height = height + dst_y;
            dst_y = 0;
        }

        if (dst_x + width > self.width)
        {
            width = self.width - dst_x;
        }

        if (dst_y + height > self.height)
        {
            height = self.height - dst_y;
        }

        if (width <= 0 || height <= 0)
        {
            return;
        }

        // Number of bytes per row of the images
        let dst_pitch = self.width * 4;
        let src_pitch = src_img.width * 4;

        for (let var j = 0; j < height; ++j)
        {
            let src_idx = (src_y + j) * src_pitch + src_x * 4;
            let dst_idx = (dst_y + j) * dst_pitch + dst_x * 4;
            self.bytes.memcpy(dst_idx, src_img.bytes, src_idx, width * 4);
        }
    }
}

fun render(v0, v1, v2, color) {
    let num_actors = 8;

    let actor_ids = [];
    for (let var i = 0; i < num_actors; ++i)
        actor_ids.push($actor_spawn(actor_loop));
    
    // Create a list of tile requests to render
    let requests = [];
    for (let var y = 0; y < HEIGHT; y = y + TILE_SIZE) {
        for (let var x = 0; x < WIDTH; x = x + TILE_SIZE) {
            let xmax = min(x + TILE_SIZE, WIDTH);
            let ymax = min(y + TILE_SIZE, HEIGHT);
            requests.push(RenderRequest(x, y, xmax, ymax, x, y, color, v0, v1, v2));
        }
    }

    let num_tiles = requests.len;

    // Image to render into
    let image = Image(WIDTH, HEIGHT);

    let start_time = $time_current_ms();

    // Send one requests to each actor, round-robin
    for (let var i = 0; i < num_actors; ++i)
    {
        $actor_send(actor_ids[i % num_actors], requests.pop());
    }

    // Receive all the render results
    for (let var num_received = 0; num_received < num_tiles; ++num_received)
    {
        let msg = $actor_recv();

        // Send more work to this actor, since it is no longer busy
        if (requests.len > 0)
        {
            $actor_send(msg.actor_id, requests.pop());
        }

        image.blit(msg.tile_img, msg.x, msg.y);
    }

    let render_time = $time_current_ms() - start_time;
    $println("Parallel render time: " + render_time.to_s() + "ms");

    // Tell actors to terminate
    for (let var i = 0; i < num_actors; ++i)
    {
        $actor_send(actor_ids[i], nil);
    }

    return image;
}

fun actor_loop() {
    while(true) {
        let msg = $actor_recv();

        if (msg == nil) 
            return;
            
        let tile_img = rasterize_tile(msg.xmin, msg.ymin, msg.xmax, msg.ymax, WIDTH, HEIGHT, msg.v0, msg.v1, msg.v2, msg.color);

        let result = RenderResult(tile_img, msg.x, msg.y, $actor_id());
        $actor_send($actor_parent(), result);
    }
}

let var color = 0xFF00FF00; // Green
let image = render(v0, v1, v2, color);

// Display the rendered image instead of the framebuffer
let window = $window_create(WIDTH, HEIGHT, "Triangle Rasterizer (parallel)", 0);
$window_draw_frame(window, image.bytes);

loop {
    let msg = $actor_recv();
    if (msg instanceof UIEvent) {
        if (msg.kind == 'CLOSE_WINDOW' || (msg.kind == 'KEY_DOWN' && msg.key == 'ESCAPE')) {
            break;
        }
    }
}
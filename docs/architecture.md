# Plush Architecture Overview

> Status: exploratory interpreter/VM for a small actor‑capable scripting language.

This document expands the high‑level project overview into a deeper tour of the code in `src/` and the runtime model exposed to Plush programs (`.pls` files under `examples/`, `benchmarks/`, `tests/`). It is based on inspection of the current sources (August 2025).

---

## 1. End‑to‑End Pipeline

```
 Source (.pls) ──► Lexer ──► Parser ──► AST ──► Symbol Resolution ──► Codegen (bytecode)
                                                           │
                                                           ▼
                                            VM (execution: stack + heap + actors)
                                                           │
                                                           ▼
                                           Host & Runtime Services (IO, time, UI)
```

Components:
1. `lexer.rs`: converts UTF‑8 source text to a token stream (keywords, identifiers, literals, operators, punctuation) with position info for diagnostics.
2. `parser.rs`: builds an abstract syntax tree (`ast.rs`) using tokens (recursive descent/Pratt hybrid). Supports: statements, expressions, functions, classes, loops (`for`, `while`), conditionals, closures, arrays, byte arrays, method calls, postfix inc/dec, ternaries.
3. `ast.rs`: data structures for programs, functions, classes, fields, methods, statements, expressions. Also owns symbol resolution logic (`Program::resolve_syms`) which assigns function & class IDs, maps variable references to slot indices and transforms AST for efficient codegen.
4. `symbols.rs`: symbol table / scope machinery (stack of scopes, variable mutability flags, slot allocation, perhaps string interning of identifiers).
5. `codegen.rs`: lowers AST to a linear bytecode (Rust enum `Insn`) stored in a single instruction vector shared across functions. Emits patchable jump offsets and caches method & field metadata for quick dispatch.
6. `vm.rs`: the bytecode virtual machine, value model, call stack, instructions, closure model, object layout, actors & concurrency, message passing, direct call patching optimization.
7. `runtime.rs`: built‑in classes (e.g., `UIEvent`) and primitive methods (e.g., `Int64.abs`, `Float64.sqrt`, `Array.with_size`, `ByteArray.read_u32`) exposed via host function wrappers.
8. `host.rs`: native host functions prefixed with `$` in source (printing, time queries, actor operations, possibly window/event functions).
9. `alloc.rs`: bump or arena allocator abstraction for allocating GC‑unmanaged heap objects (closures, arrays, objects, strings, byte arrays). No full GC implemented yet (objects live for process or actor lifetime).
10. `array.rs`, `bytearray.rs`: language visible container types with host methods & VM field/method handling.
11. `deepcopy.rs`: structural cloning of values for actor message passing isolation (copy on send + remap to fix internal pointer graphs).
12. `window.rs`: SDL2 based minimal window + event polling (UI events marshalled into runtime `UIEvent` objects and delivered as actor messages to actor 0 via `poll_ui_msg`).
13. `exec_tests.rs`: harness to execute `.pls` scripts under `tests/` (smoke & semantic tests run through `cargo test`).
14. `main.rs`: CLI driver. Steps: parse args → parse/eval string or file → symbol resolution → optional no‑exec exit → create `VM` → invoke main function → convert return `Value` to process exit code.

---

## 2. Value Model

Defined in `vm.rs` enum `Value`:

Primitive immediates:
- `Nil`, `True`, `False`
- `Int64(i64)`
- `Float64(f64)`

Heap references (raw pointers allocated via `Alloc`):
- `String(*const String)` (interning not yet enforced, but strings are deduplicated opportunistically when created through runtime methods)
- `Closure(*mut Closure)` containing `fun_id` + captured slots
- `Cell(*mut Value)` (mutable captured variable, enabling closures to share state)
- `Object(*mut Object)` where `Object` holds `class_id` + `Vec<Value>` (field slots)
- `Array(*mut Array)` dynamic array
- `ByteArray(*mut ByteArray)` raw byte storage with typed read/write helpers
- `Dict(*mut Dict)` (dictionary creation opcode currently commented out; placeholder for future maps)

Meta / code:
- `HostFn(HostFn)` (native function pointer variant with arity encoded by variant name, e.g., `Fn2_1` = 2 args, 1 return)
- `Fun(FunId)` (reference to a declared function)
- `Class(ClassId)` (class metaobject used for `instanceof` and constructing via `new` / `Class()` call in code)

Semantics:
- `Value::is_heap()` distinguishes pointer vs immediate for future GC or copy semantics.
- Structural equality is special‑cased for strings (contents), pointer equality for other heap objects, numeric equality for ints/floats, identity for booleans & nil.

---

## 3. Instruction Set (Bytecode)

`Insn` enumerates opcodes; representative groups:

Stack & flow:
- `push { val }`, `pop`, `dup`, `swap`, `getn{idx}`
- `get_arg{idx}`, `get_local{idx}`, `set_local{idx}`, `get_global{idx}`, `set_global{idx}`
- Control flow: `if_true`, `if_false`, `jump`, `ret`

Arithmetic & logic:
- `add`, `sub`, `mul`, `div`, `modulo`, `add_i64{val}` (in‑place fast add constant)
- Bit ops: `bit_and`, `bit_or`, `bit_xor`, `lshift`, `rshift`
- Comparisons: `lt`, `le`, `gt`, `ge`, `eq`, `ne`, logical negation `not`

Objects & classes:
- `new{class_id, argc}` allocate + call optional `init`
- `instanceof{class_id}`
- Field access with caching: `get_field{field, class_id, slot_idx}`, `set_field{...}`; if cached `class_id` mismatches actual, VM recalculates slot index then patches the instruction in place (inline polymorphic inline cache style)

Closures & lexical scope:
- `clos_new{fun_id, num_slots}` allocate closure object
- `clos_set{idx}` / `clos_get{idx}` assign or load captured variables

Arrays & indexing:
- `arr_new{capacity}`, `arr_push`, `get_index`, `set_index`

Calls:
- Generic: `call{argc}` where callee is on stack top after args
- Direct: `call_direct{fun_id, argc}` (first call; patched to `call_pc`)
- Patched: `call_pc{entry_pc, fun_id, num_locals, argc}` (fast path skipping function lookup)
- Methods: `call_method{name, argc}` resolves per object or primitive (primitives delegate via `runtime::get_method`)

Optimization: Transition `call_direct` → `call_pc` after first execution implementing a simple inline caching / direct threading for subsequent invocations.

---

## 4. Stack & Frames

Each `Actor` holds:
- `stack: Vec<Value>` (value + local slots)
- `frames: Vec<StackFrame>` with: function `Value`, arg count, previous base pointer, return address (PC)
- Base pointer (`bp`) is maintained outside the frame struct during execution; locals live from `bp` to current stack length minus 1.

Call convention (for bytecode functions):
1. Arguments pushed left‑to‑right.
2. Frame pushed with metadata (argc, fun, prev_bp, ret_pc).
3. Locals preallocated as `Nil` after arguments.
4. Return pops frame, truncates stack to caller’s baseline excluding arguments (callee pops its own args enabling tail call potential), then pushes return value.

Closures capture by slot: codegen allocates closure slots, `clos_set` fills them when building closure values.

---

## 5. Classes & Objects

Class definition (AST) registers a `ClassId`, maps field names to slot indices, and associates method names to `FunId`s. Instances (`Object`) store a fixed `Vec<Value>` sized to number of fields. Field access instructions embed:
- Raw pointer to interned field name (`*const String`), used for fallback resolution.
- Cached `class_id` & `slot_idx` enabling fast path; fallback path rewrites the executing instruction with updated cache (inline self‑patching).

Instance construction opcode `new` optionally calls `init(self, ...)` if present; the object is inserted before arguments on stack to align with method call convention.

Primitives get pseudo‑methods via `runtime::get_method` (e.g., `77.to_s()`, `4.0.sqrt()`), implemented as host functions.

---

## 6. Concurrency: Actor Model

Actors are user‑space units of isolation executed each on their own OS thread (spawned via `std::thread`). Core pieces:
- `VM` manages global program metadata, assigns actor IDs, stores thread join handles, and keeps per‑actor message queue endpoints.
- `Actor` owns: private heap allocator (`Alloc`), message queue receiver, cached sender endpoints, its own compiled function cache & instruction vector (shared code storage semantics; functions compiled lazily per actor and appended to local `insns`).
- Message passing uses `mpsc` channels; send copies values via `deepcopy` into the receiver’s `msg_alloc` (copy semantics for isolation).
- The main actor (ID 0) additionally polls UI events (`window.rs`) to convert them into messages (non‑blocking interleaving of UI + actor messages).

Actor lifecycle:
1. `$actor_spawn(f)` copies closure/function & its captured/global state into a fresh message allocator; new thread starts and executes `f`.
2. `$actor_send(id, msg)` deep‑copies `msg` into recipient’s message heap.
3. `$actor_recv()` blocks (with periodic UI polling on main actor) until message available.
4. `$actor_join(id)` waits for actor thread termination and returns its return value (no copy needed because sender is done).

Isolation Guarantee (current stage): pointers are never shared directly between actors; messages are deep copies. No GC implies memory reclaimed only when actor exits.

---

## 7. Memory Management

`alloc.rs` (arena allocator) supplies raw allocations for all heap objects; pointers are stored directly in `Value`. There is currently:
- No tracing garbage collector.
- No reference counting.
- Lifetime model: objects live for the life of the actor (arena deallocated en masse when actor terminates). This simplifies concurrency (no shared mutable ownership across threads) at the cost of potential leaks for long‑running actors.

Implications / future directions:
- Add a simple mark & sweep per actor if long‑running sessions matter.
- Consider interning of small immutable strings to reduce duplication across actors (currently intern only per actor).
- Introduce copy‑on‑write or zero‑copy transfer for large `ByteArray` between actors with ownership handoff.

---

## 8. Host & Runtime Functions

`host.rs` exports special functions referenced with `$` prefix in Plush source (examples from tests):
- `$print(str)`, `$time_current_ms()`
- Actor ops: `$actor_id()`, `$actor_parent()`, `$actor_spawn(fun)`, `$actor_send(id, msg)`, `$actor_recv()`, `$actor_join(id)`
- Likely additional window / graphics operations (used by visual examples such as `raytracer.pls`, `plasma.pls`, `mandelbrot.pls`).

Method dispatch for primitives (e.g., `Int64.abs`, `Float64.sqrt`, `Array.with_size`) is implemented via `runtime::get_method` returning a `HostFn` variant. Each `HostFn` variant embeds a function pointer with fixed arity; the VM extracts arguments from stack and pushes return values uniformly.

---

## 9. Arrays and Byte Arrays

`array.rs`:
- Growable vector of `Value` with `push`, `pop`, indexing, length via synthetic `.len` field accessor at VM level.
- `Array.with_size(n, fill)` host method (through `Class(Array)` + method lookup) preallocates `n` slots.

`bytearray.rs`:
- Contiguous `Vec<u8>` wrapper with bounds‑checked indexed access; specialized methods: `read_u32`, `write_u32`, `fill_u32`, `memcpy`, `zero_fill`, plus `.len` synthetic field.
- Used for image/pixel buffers in graphics examples and algorithms requiring raw binary manipulation.

---

## 10. Deep Copy & Message Passing

`deepcopy.rs` walks `Value` graphs producing equivalent structures in a destination `Alloc`. It builds a remap table to adjust internal pointers (e.g., multiple references to same object become multiple references to the same cloned object, preserving aliasing). After cloning, `remap` finalizes any needed pointer fixups. This underpins actor isolation.

Edge Cases Handled:
- Self‑referential closures (slots referencing same closure) → consistent mapping.
- Arrays/byte arrays nested inside objects → fully cloned.
- Strings reused across structure → single duplicate clone (depending on map strategy). 

Not yet handled / potential improvements:
- Cycle detection for dictionaries (currently `Dict` not actively used).
- Large structure optimization (zero‑copy for immutable blobs like large strings or byte arrays by reference counting).

---

## 11. UI & Window Integration

`window.rs` (with `sdl2` crate) provides:
- Window creation & pixel buffer updates (used in demos: `mandelbrot.pls`, `plasma.pls`, `raytracer.pls`, `bouncing_ball.pls`).
- Event polling bridging SDL events into `UIEvent` objects (core runtime class with fields: `kind`, `window_id`, `key`, `button`, `x`, `y`).
- Main actor periodically polls for events inside blocking receive loops (8ms timeout pattern) to merge UI and actor messages.

Design Rationale:
- Keeps SDL confined to a single thread while still allowing background actors for computation.
- UI events treated uniformly as messages, consistent with actor model semantics.

---

## 12. Testing Strategy

Coverage layers:
- Rust unit tests inside `vm.rs` (exercise expression evaluation, control flow, closures, recursion, arrays, byte arrays, classes, instanceof, primitive methods, actor API).
- `.pls` scripts in `tests/` simulate higher‑level algorithmic workloads (graph algorithms, geometry: Delaunay, QuickHull, Tarjan, DFS, etc.) verifying language features under more complex control flow.
- Benchmarks in `benchmarks/` compare performance or allocate stress conditions (`fib.pls` vs a Python version, array/object property access, frame copies, actor ping‑pong).

Suggested additions:
- Add negative tests for error diagnostics (uninitialized global, panic opcode, invalid field access) to ensure friendly messages instead of panics.
- Performance regression guard using criterion or simple runtime logging in CI.

---

## 13. Command Line Interface

`main.rs` supports:
- Run a file: `plush program.pls`
- Evaluate a string: `plush --eval "return 7;"`
- Parse only: add `--no-exec`

On success: program `return` value of main compilation unit determines process exit code (Nil => 0; Int64 => integer value; other types currently panic if returned as top level).

Potential future flags (commented TODO): permission model `--allow`, `--deny`, `--allow-all` for sandboxing host functions.

---

## 14. Performance Characteristics & Current Optimizations

Implemented:
- Direct call patching (`call_direct` → `call_pc`).
- Inline polymorphic inline cache for field access & set (self‑patching `get_field`/`set_field`).
- Constant folding for `add_i64` immediate form (post‑codegen micro optimization when incrementing integer by constant).
- Arena allocation (low overhead object creation, no per-object freeing).

Not yet present (opportunities):
- Bytecode peephole optimizer (stack slot elimination, constant propagation, dead code removal after jumps).
- String interning across actors.
- Escape analysis to stack‑allocate short‑lived closures/objects.
- JIT compilation (mapping `Insn` to native code via Cranelift or similar).
- Real garbage collector (space & fragmentation improvements for long runs).

---

## 15. Error Handling & Diagnostics

Current approach:
- Parsing & symbol resolution return `Result` with error string; CLI prints message and exits with `-1`.
- VM runtime errors typically `panic!()` (e.g., uninitialized field, wrong types). These unwind Rust stack without pretty user message.

Recommended roadmap:
- Introduce a `RuntimeError` enum and replace panics in hot path with error propagation up to call site or top loop.
- Source span tracking for runtime errors pointing back to AST nodes (store debug metadata with instructions during codegen).

---

## 16. Security & Sandboxing Considerations

Because host functions expose time, printing, window creation, and thread/actor spawning, a permission model (as hinted) would allow embedding Plush safely in larger applications. Basic strategy:
- Permission flags parsed in CLI, stored in `Options`.
- `host.rs` checks permission before executing sensitive host function (e.g., window / filesystem / network if later added).
- Deny by default; explicit allow list model.

---

## 17. Roadmap Ideas

Short Term:
- Graceful runtime errors; add regression tests for each.
- Dictionary literal & access opcodes (uncomment `dict_new` path, implement `get_field` / `set_field` for dicts, hashing). 
- GC or at least per‑actor periodic arena reset for ephemeral workloads.

Medium Term:
- Module / import system (multi‑file programs; current CLI enforces single file or `--eval`).
- Standard library layer (math, collections, concurrency utilities) separate from core host fns.
- Deterministic actor scheduling option (use a work‑stealing pool instead of 1 OS thread per actor).

Long Term:
- JIT (Cranelift or custom) with inline caching & specialization.
- Foreign Function Interface (FFI) to Rust/C for numeric kernels.
- Structured concurrency (scoped actors, supervision trees).
- Hot reload of functions/classes during dev.

---

## 18. Quick Start

Build:
```
cargo build --release
```

Run a program:
```
./target/release/plush examples/helloworld.pls
```

Evaluate inline code:
```
./target/release/plush --eval "return 6 * 7;"
```

Run tests (Rust + Plush script tests):
```
cargo test
```

Benchmark (example):
```
./benchmarks/fib_vs_python.sh
```

---

## 19. Glossary

- Actor: Independent unit of execution with isolated heap and message queue.
- Closure: Heap object capturing free variables by slot index for later invocation.
- Inline cache: Mechanism where an instruction patches itself with fast path metadata (class id, slot index) after first execution.
- Host Function: Native Rust function exposed to Plush code via `$name` or primitive methods.
- Arena Allocation: Strategy where objects are allocated out of an arena and freed all at once.

---

## 20. High‑Level Design Principles Evident

1. Simplicity first: No GC, minimal instruction set, direct patterns, aggressive use of `panic!` for invariants.
2. Copy isolation: Deep copy for actor messages to avoid synchronization / locking of shared mutable structures.
3. Patch‑after‑first‑use optimization: Minimal dynamic profiling; just enough to remove dispatch overhead for common patterns (calls, fields).
4. Explicitness: AST → codegen path is straightforward; instructions explicitly encode immediate constants & metadata.
5. Leverage Rust safety where convenient, escape with raw pointers where required for compact `Value` and arena semantics.

---

## 21. Potential Risks / Technical Debt

- Raw pointers without GC: risk of accidental use‑after‑free if allocation strategy changes.
- Panics for user errors: poor UX, difficult embedding in larger host.
- Unbounded actor spawning: each actor is an OS thread; can exhaust system resources quickly.
- No backpressure on message queues.
- Lack of numeric tower (only Int64 & Float64) and limited type checks (panic on misuse).

Mitigations:
- Introduce configuration limits (max actors, max message size).
- Implement a pooled executor for actors or a green thread scheduler.
- Replace panics with recoverable errors; add language level try/catch (future extension).

---

## 22. Summary

Plush is a compact experimental language runtime featuring a classical front‑end, a patchable bytecode VM with closure & class support, and an actor concurrency model coupled with simple host integration (time, printing, UI). The architecture favors clarity and hackability over completeness. Key next steps center on robustness (errors, GC) and performance (additional caching, optimization passes, potential JIT).

---

_Generated August 2025 based on repository state. Some points involve forward‑looking suggestions, not yet implemented._

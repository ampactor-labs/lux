# UI/IDE Playground Vision: The Deterministic Holograph

> *This document captures the post-first-light vision for the Mentl interactive Web Playground and the ultimate Mentl UX.*

## 1. The Mentl Interface: Deterministic Holography

We must discard the notion of an AI chatbot. Mentl has no LLM, no embedding space, and no chat window. 
Mentl is the **voice of the graph**, purely deterministic, gaining intelligence from extreme computational leverage via Multi-Shot continuations. 

### The Interaction Loop: No Text, Only Geometry
When a developer violates a topological constraint (e.g., calling an `Alloc` function under a `!Alloc` guard), the compiler halts at an `NErrorHole`. 
This triggers Mentl's `Propose` tentacle. She uses a Multi-Shot handler to systematically brute-force the algebraic space of the codebase. She tests hundreds of topological variations per second:
- *Relax the signature to `with Alloc`? (Typechecks)*
- *Wrap this specific stage in `~> arena_allocator`? (Typechecks)*

Mentl filters the surviving, mathematically-proven realities and projects them directly into the editor as **Holographic Ghost Text**.

1. A sharp, geometric indicator appears at the boundary—a **Lens**.
2. The Lens projects a deterministic fact: `[Constraint Violation: Alloc inside !Alloc]`.
3. The editor renders the Holographic Geometries overlaid on the code. The developer cycles through them with an arrow key.
4. The developer presses `Tab`. The geometry snaps into reality.

### The Annotation Gradient as UX
Because Mentl is deterministic, she never guesses. If you want Mentl to do more work for you, you simply tighten the algebraic constraints. 
If you write `fn process(data) with !Mutate`, you mathematically prove to Mentl that state cannot change. Mentl immediately multi-shots the graph, finds that a sequential `|>` map can be safely upgraded to a structural `><` parallel zip, and offers the geometric projection.

---

## 2. The Mentl Web Playground: Synchronizing the 8 Tentacles

A custom Web Playground is the uncompromised manifestation of Mentl's algebraic medium. Because the Mentl compiler is self-hosted, pure, and compiles to WASM, the playground runs natively in the browser at 60fps. The compiler runs synchronously with every keystroke, rendering the Graph directly to the DOM.

### The Three Visual Layers
1. **The Topographic Canvas (Center):** The text editor with faint geometric lines physically connecting `|>` and `<|` pipelines.
2. **The Capability HUD (Right Panel):** A live matrix showing the ambient effect row and ownership ledger.
3. **The Wavefront (Bottom Panel):** A timeline scrub bar representing the `Why` engine's reasoning DAG and Multi-Shot realities.

### Exposing the 8 Voices
1. **Query (Graph + Env) & Why (Reason DAG):** When you click a type variable, the Wavefront highlights the entire provenance chain. Faint lines connect the variable to every `<|` branch that influenced its inference.
2. **Topology (The 5 Verbs):** The layout rules are enforced visually. If you violate topology, the text physically resists and snaps into the canonical indented layout. 
3. **Unlock (Boolean Algebra) & Propose (Handlers):** Drive the Holographic Lens described above.
4. **Trace (Ownership Ledger):** `own` variables are color-coded (amber). When consumed, the amber glow physically drains from the text and transfers to the next stage. The HUD lists the `Consume` ledger's remaining budget.
5. **Verify (Refinement Types):** Hovering over a `ValidPort` variable surfaces a slider. As you drag it, the topological pipe updates its correctness state instantly.
6. **Teach (Annotation Gradient):** The volume knob. Low annotations hide the HUD. High annotations (e.g., `with !Alloc + !Async`) expand the HUD into a mission-control dashboard.

### Why the Web Playground First?
Zero-latency WASM loops, custom SVG geometric renderers, and instant sandbox execution. The ultimate demo: a URL where someone can type `with !Alloc` and watch Mentl physically re-arrange their code topology in real-time.

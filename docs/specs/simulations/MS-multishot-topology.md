# The Topology of Alternate Realities: 5 Verbs × Multi-Shot

*This document captures the brainstorm exploring the absolute limit of Mentl's algebraic primitives, specifically the intersection of spatial topology and temporal realities.*

When we talk about the Five Verbs (`|>`, `<|`, `><`, `~>`, `<~`), we are talking about **spatial topology** — how data moves through the graph. 
When we talk about Multi-Shot Continuations (`@resume=MultiShot`), we are talking about **temporal topology** — how execution forks into alternate realities (backtracking, generators, quantum superpositions).

What happens when we intersect them? We stop writing code and start sculpting N-dimensional state spaces.

---

## 1. The Borrowed Realities: `<|` (Fanout) meets Multi-Shot

Per `SYNTAX.md`, `<|` is the structural diverge. It takes one input and routes it into multiple branches, **borrowing** the input so it cannot escape. 

```mentl
sensor_data
  <| (
    process_a,
    process_b,
  )
  ~> stochastic_handler
```

If `process_a` invokes a Multi-Shot effect (e.g., `guess()`), and `stochastic_handler` resumes it 3 times, what happens to the `<|` tuple? 
Because the handler wraps the whole chain (block-form `~>`), the continuation of `guess()` includes the evaluation of `process_b` and the rest of the pipe. 
The universe forks. `process_b` is dragged into 3 parallel realities. 

But what if the handler is inline (Form B)?
```mentl
sensor_data
  <| (
    process_a ~> stochastic_handler,
    process_b,
  )
```
Now the Multi-Shot explosion is *contained* within branch A. Branch A resolves its alternate realities (perhaps aggregating them into a List, or picking the best one via a probabilistic handler) *before* the tuple is formed. The topological boundary `(...)` explicitly scopes the multi-shot explosion.

**Developer Scenario:** You are writing a constraint solver. `<|` borrows the constraint state into three different heuristics. Heuristic A uses a Multi-Shot `guess()` to explore the sub-space. Because it's inline-handled, it collapses its findings into an optimal sub-solution, joining back with Heuristic B cleanly at the tuple boundary.

---

## 2. Orthogonal Universes: `><` (Parallel) meets Multi-Shot

Per `SYNTAX.md`, `><` is a structural N-ary parallel compose. The branches are independent pipelines.

```mentl
(camera_feed |> track_objects ~> multi_shot_tracker)
    ><
(lidar_feed  |> track_depth)
|> fuse_sensors
```

If the `camera_feed` branch forks into 5 realities (hypothesizing 5 different object trajectories), but `lidar_feed` is pure, how does `><` behave? 
Because `><` pipelines are independent and run in parallel, the `fuse_sensors` stage acts as the synchronization point. If the handler is *outside* the `><`, the entire parallel zip forks. If the handler is *inside* the camera branch, the camera thread computes its 5 realities locally, aggregating them before `><` synchronization.

**Mentl's Perspective:** Mentl looks at `><` and sees a perfect hyper-plane. If you try to run a Multi-Shot effect that escapes a parallel branch without a handler, she intervenes: *"You are trying to fork the universe across an asynchronous boundary. Install a handler inside the branch to collapse the wave function, or annotate `with !Async` to prove this runs sequentially."*

---

## 3. Time Travel in a Multiverse: `<~` (Feedback) meets Multi-Shot

Per `SYNTAX.md`, `<~` routes data back to a previous layer, but it requires an iterative context (`Sample`, `Tick`, `Clock`).

```mentl
system_state
  |> predict_next
  ~> particle_filter_handler
  |> measure_error
  <~ accumulate(0)
```

If `particle_filter_handler` is Multi-Shot, it resumes `predict_next` 1,000 times with random noise. 
We just created 1,000 alternate realities.
When those realities hit `<~ accumulate(0)`, what happens? 
Because each reality holds its own continuation state, the iterative context (`Tick`) maintains 1,000 independent feedback loops. 

**Developer Scenario:** You just wrote a Monte Carlo Particle Filter in 5 lines of code. No arrays. No `for` loops. The topological wire `|>` carries a single particle. The Multi-Shot handler forks it into 1,000 particles. The `<~` feedback loops the state of all 1,000 particles back to the next tick. 
You wrote the logic for one reality; Mentl compiled it into a massively parallel tensor operation.

---

## 4. Conclusion

The 5 verbs aren't just syntax—they are geometric constraints.
Multi-Shot isn't just an effect—it is dimensionality.

When you enforce layout (`SYNTAX.md`), you are forcing the developer to draw the topology exactly as the graph sees it. 
- `<|` proves a shared root.
- `><` proves orthogonal independence.
- `<~` proves a closed time-like curve.

And when you throw Multi-Shot into that graph, the compiler doesn't panic. It just spins up alternate realities that perfectly obey the geometric laws the developer drew on the screen.

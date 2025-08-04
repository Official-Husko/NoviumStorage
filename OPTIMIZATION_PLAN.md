# NoviumStorage Optimization Plan

## 1. Profiling & Bottleneck Identification

- Add debug/profiling hooks to measure execution time of key functions (especially those called when opening the terminal).
- Log or print the time taken for:
  - Network refreshes
  - Item list generation
  - Pattern list generation
  - Any synchronous world or entity calls

## 2. Code Review & Hotspot Analysis

- Review all code paths triggered by opening the terminal (UI, network queries, item/pattern fetching).
- Identify heavy operations:
  - Large table traversals (e.g., flattening all items or patterns)
  - Synchronous calls to other entities (e.g., `world.callScriptedEntity`)
  - Repeated or redundant data processing

## 3. Optimization Strategies

- Cache results of expensive operations (e.g., item lists, pattern lists) and only refresh when necessary.
- Avoid unnecessary table copies and flattening, especially in loops.
- Minimize synchronous entity calls; batch requests or use asynchronous messaging if possible.
- Use local variables for frequently accessed globals (e.g., `local pairs = pairs`).
- Preallocate tables when possible to avoid resizing overhead.
- Reduce upvalue lookups in tight loops.

## 4. Refactor Data Structures

- Use indexed tables for fast lookups (e.g., by item unique index).
- Avoid deep nesting and flatten data only when needed for UI.
- Consider weak tables for cache if memory is a concern.

## 5. Asynchronous & Deferred Processing

- Defer heavy processing to multiple frames if possible (e.g., split large item list generation).
- Use coroutines for long-running tasks to avoid blocking the main thread.

## 6. Testing & Validation

- Test with large networks and inventories to ensure performance gains.
- Monitor server and client FPS and lag during terminal open/close.

## 7. Documentation & Best Practices

- Document all optimizations and reasoning.
- Follow Lua 5.3 idioms (e.g., use `table.move`, `table.unpack`, integer for indices, etc.).
- Remove legacy or unused code that may add overhead.

## 8. Iterate

- Profile again after each major change.
- Repeat steps 2–7 as needed.

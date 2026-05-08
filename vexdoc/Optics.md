AI generated 
Here's a minimal but complete API design:

**Core types**

```lua
-- An optic is just a table with two coroutines
Optic = {
  get = function*(data) -> yields focuses,
  set = function*(data, func) -> yields modified copies
}
```

**Primitive constructors**

```lua
-- Single field
field(name)
-- e.g. field("title") focuses task.title

-- All items in a collection  
items()
-- e.g. items() focuses each element of a table

-- Conditional focus
filtered(predicate)
-- e.g. filtered(function(t) return t.done end)

-- Structural transformation (iso)
iso(forward, backward)
-- e.g. iso(serialize, deserialize)

-- Partial focus (prism) - may find nothing
prism(match, build)
-- e.g. prism on a specific decision branch
```

**The two core actions**

```lua
get(optic, data)
-- returns iterator of focused values

set(optic, data, func)
-- func receives each focused value, returns replacement
-- set(field("title"), task, function(t) return t:upper() end)
-- if func is omitted, func = identity (no-op, useful for dry runs)
```

**Composition — the meta layer**

```lua
-- Sequential (the fundamental one)
compose(optic_a, optic_b, ...)
-- get digs deeper, set propagates back up

-- Parallel fanout — one data source, many optics
fanout(optic_a, optic_b, ...)
-- get yields tuples, set applies each optic independently

-- Fold — read only, collapses to single value
fold(optic, data, func, init)
-- func is (accumulator, value) -> accumulator
-- e.g. fold(items(), tasks, function(acc, t) return acc + 1 end, 0)

-- Guard — make any optic conditional
guard(optic, predicate)
-- focuses only when predicate holds on the *optic itself*, not the value
-- (contrast with filtered which tests the value)

-- Reindex — transform the path, not the value
reindex(optic, func)
-- func receives current path, returns new path
-- powers vex mv

-- Context — attach path provenance to each focused value  
with_context(optic)
-- get now yields {value=v, path=p} instead of bare v
```

**Derived operations — all built from the above**

```lua
-- These are just sugar, not primitives

select(data, ...)
-- fanout(field(f1), field(f2), ...) + get

filter(data, predicate)
-- get(filtered(predicate), data)

map(optic, data, func)
-- set(optic, data, func) -- map IS set

traverse(optic, data)
-- get(compose(optic, items()), data) -- flatmap

group_by(optic, data, key_func, fold_func)
-- traverse + partition + fold
```

**Usage examples to validate the design**

```lua
-- Get all titles
get(compose(items(), field("title")), tasks)

-- Uppercase all titles of done tasks
set(compose(filtered(done), field("title")), tasks, string.upper)

-- Count tasks
fold(items(), tasks, function(acc, _) return acc + 1 end, 0)

-- Get title and status together
get(fanout(field("title"), field("status")), task)
-- yields {"My Task", "open"}

-- Walk DAG and collect all descendant titles
get(compose(dag_traverse(), field("title")), root)

-- Rename a field path (vex mv)
reindex(field("old_name"), function(p) return "new_name" end)
```

**The one design decision to make explicitly**

`set` with a fold in the composition chain — should it error, silently no-op, or return a capability flag? I'd recommend: fold makes the optic **read-only**, and calling `set` on a read-only optic returns an error with a clear message. Then you can check capability upfront:

```lua
optic.writable  -- boolean, false if fold is anywhere in chain
```

That keeps the API honest without needing a type system.
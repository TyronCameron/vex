Each `.lua` file in `.vex/tasks` can register task types and transients.

## Task types

A type extends an existing one and adds a schema. Its schema is merged over its ancestors': a field it defines replaces the ancestor's definition of that field, and it inherits every other field. Its tasks must pass the merged schema:

```lua
task:task 'bug':extends 'atom' {
    schema = schema.atleast {
        severity = schema.any {'low', 'high'},
        reported = schema.maybe {schema.formatted {schema.datetime}},
    }
}
```

```console
$ vex add Crash on start --vextype bug --severity high
```

A `schema` validates, normalises, derives and converts a task's fields each time it is resolved. Build yours from these blocks, among others:

| Schema | Accepts |
| --- | --- |
| `schema.atleast {...}` | A table with at least these fields. Other fields pass through. |
| `schema.maybe {s}` | Nothing, or a value matching `s`. |
| `schema.default {s, default = fn}` | A value matching `s`, using `fn()` when there is none. |
| `schema.vec {s}` | A list of values matching `s`. |
| `schema.any {...}`, `schema.all {...}`, `schema.none {...}` | Any, all or none of the given schemas or constants. |
| `schema.none` | No value: nil, or an empty list or string. It marks a field a task type does not use. |
| `schema.formatted {s}` | A value matching `s`, read from and written as its readable form, such as a datetime. |
| `schema.str`, `schema.num`, `schema.int`, `schema.bool` | Plain values. |
| `schema.datetime`, `schema.date` | Timestamps. |
| `schema.vexlink` | The vexid of an existing task, written `[[vexid]]`. |
| `schema.constraint {fn}` | A value for which `fn(value, context)` returns true. |

## Transients

A transient is a field computed whenever it is read and never stored. It is registered for a type and inherited by the types that extend it:

```lua
task:transient 'shouting' {
    vextype = 'task',
    definition = function(t) return t.description:upper() end
}
```

```console
$ vex focus all --select shouting
```

A definition can read other fields and transients, and query other tasks through `focus`.

A type redefines an inherited transient by registering its own.

A type checks a transient through its schema with `schema.unstored`, which validates the value a field reads without ever storing it. Every task takes children unless its type says otherwise. Atoms and explorations refuse them with the vexations plugin's `hasnochildren` check on `children`, and a type of your own can do the same. Then a task naming one as its `parent` fails with `has-children`:

```lua
task:task 'chore':extends 'task' {
    schema = schema.atleast { children = schema.unstored {schema.hasnochildren} }
}
```

## Writing a file

Each example on this page is a complete file: save it as a `.lua` file in `.vex/tasks` and vex loads it on the next command, with nothing else required. Every file runs with these already in scope, alongside Lua's standard globals: `task` (the task manager), `recipe` (the recipe manager), `focus` (the `Focus` class), `view` (the view manager) and `schema` (the schema library).

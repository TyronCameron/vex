-- Test file for lib/schema.lua using busted
local busted = require 'busted'
local schema = require 'lib.schema'

describe("schema", function()

    it("should register schemas", function()
        assert.truthy(schema.str._name == "str", 'str not registered')
        assert.truthy(schema.num._name == "num", 'num not registered')
        assert.truthy(schema.constant._name == "constant", 'constant not registered')
        assert.truthy(schema.exactly._name == "exactly", 'exactly not registered')
        assert.truthy(schema.atmost._name == "atmost", 'atmost not registered')
        assert.truthy(schema.atleast._name == "atleast", 'atleast not registered')
        assert.truthy(schema.any._name == "any", 'any not registered')
        assert.truthy(schema.all._name == "all", 'all not registered')
        assert.truthy(schema.none._name == "none", 'none not registered')
        assert.truthy(schema.maybe._name == "maybe", 'maybe not registered')
        assert.truthy(schema.vec._name == "vec", 'vec not registered')
        assert.truthy(schema.int._name == "int", 'int not registered')
        assert.truthy(schema.uint._name == "uint", 'uint not registered')
        assert.truthy(schema.bool._name == "bool", 'bool not registered')
        assert.truthy(schema.thr._name == "thr", 'thr not registered')
        assert.truthy(schema.table._name == "table", 'table not registered')
        assert.truthy(schema.date._name == "date", 'date not registered')
        assert.truthy(schema.datetime._name == "datetime", 'datetime not registered')
        assert.truthy(schema.rng._name == "rng", 'rng not registered')
        assert.truthy(schema.hasmetatable._name == "hasmetatable", 'hasmetatable not registered')
        assert.truthy(schema.empty._name == "empty", 'empty not registered')
        assert.truthy(schema.size._name == "size", 'size not registered')
        assert.truthy(schema.default._name == "default", 'default not registered')
        assert.truthy(schema.derive._name == "derive", 'derive not registered')
        assert.truthy(schema.formatted._name == "formatted", 'formatted not registered')
        assert.truthy(schema.serialized._name == "serialized", 'serialized not registered')
        assert.truthy(schema.constraint._name == "constraint", 'constraint not registered')
    end)

    it("should create schemas", function()
        local custom_schema = schema.new {
            validate = function(self, instance)
                return type(instance) == "number"
            end,
            name = "custom_num"
        }
        assert.truthy(custom_schema)
        assert.equal("custom_num", custom_schema._name)
        assert.equal(true, custom_schema:validate(42))
        assert.falsy(custom_schema:validate("hello"))
    end)

    it("should instantiate words automatically", function()
        local str_schema = schema.instantiate('str')
        assert.truthy(str_schema)
        assert.equal('str', str_schema._name)
        assert.equal(true, str_schema:validate("hello"))
        assert.falsy(str_schema:validate(42))

        local num_schema = schema.instantiate('num')
        assert.truthy(num_schema)
        assert.equal('num', num_schema._name)
        assert.equal(true, num_schema:validate(42))
        assert.falsy(num_schema:validate("hello"))

        local big_schema = schema.atleast {
            str = 'str',
            num = 'num'
        }
        assert.truthy(big_schema:validate({ str = "hello world", num = 15 }))
        assert.falsy(big_schema:validate({ str = "hello world", num = "hello world" }))
    end)

    it("should instantiate constants automatically", function()
        local const_schema = schema.instantiate(42)
        assert.truthy(const_schema)
        assert.equal('constant', const_schema._name)
        assert.equal(true, const_schema:validate(42))
        assert.falsy(const_schema:validate(43))

        local big_schema = schema.atleast {
            str = 'hello world',
            num = 15
        }
        assert.truthy(big_schema:validate({ str = "hello world", num = 15 }))
        assert.falsy(big_schema:validate({ str = "hello world", num = 16 }))
    end)

    it("should instantiate schemas automatically", function()
        local big_schema = schema.atleast {
            str = schema.str,
            num = schema.num
        }
        assert.truthy(big_schema:validate({ str = "hello world", num = 15 }))
        assert.falsy(big_schema:validate({ str = "hello world", num = "ehllo" }))
    end)

    it("should add specification when called", function()
        local exactly = schema.exactly {
            name = schema.instantiate('str'),
            age  = schema.instantiate('num')
        }
        assert.truthy(exactly.specification)
        assert.truthy(exactly.specification.name)
        assert.truthy(exactly.specification.age)
    end)

    it("should prevalidate first", function()
        local exactly = schema.exactly {
            def = schema.default({'num', default = function() return 10 end})
        }
        local instance = {}
        exactly:prevalidate(instance)
        assert.equal(10, instance.def)
    end)

    it("should validate second", function()
        local exactly = schema.exactly {
            name = schema.instantiate('str'),
            age  = schema.instantiate('num')
        }
        local isvalid = exactly:validate({ name = "bob", age = 42 })
        assert.truthy(isvalid)
    end)

    it("should postvalidate third", function()
        local numeric_check = schema.num()
        numeric_check._postvalidate = function()
            return 10
        end
        assert.equal(10, numeric_check:postvalidate(42))
    end)

    -- ==================== Primitive type schemas ====================

    it("`schema.str` validates a string", function()
        assert.truthy(schema.str:validate("hello"))
    end)

    it("`schema.str` invalidates a non-string", function()
        assert.falsy(schema.str:validate(42))
    end)

    it("`schema.num` validates a number", function()
        assert.truthy(schema.num:validate(42))
    end)

    it("`schema.num` invalidates a non-number", function()
        assert.falsy(schema.num:validate("hello"))
    end)

    it("`schema.int` validates an integer", function()
        assert.truthy(schema.int:validate(42))
    end)

    it("`schema.int` invalidates a float", function()
        assert.falsy(schema.int:validate(42.5))
    end)

    it("`schema.uint` validates a nonnegative integer", function()
        assert.truthy(schema.uint:validate(5))
    end)

    it("`schema.uint` invalidates a negative integer", function()
        assert.falsy(schema.uint:validate(-1))
    end)

    it("`schema.bool` validates a boolean", function()
        assert.truthy(schema.bool:validate(true))
    end)

    it("`schema.bool` invalidates a non-boolean", function()
        assert.falsy(schema.bool:validate(1))
    end)

    it("`schema.thr` validates a thread", function()
        local thread = coroutine.create(function() end)
        assert.truthy(schema.thr:validate(thread))
    end)

    it("`schema.thr` invalidates a non-thread", function()
        assert.falsy(schema.thr:validate(42))
    end)

    it("`schema.table` validates a table", function()
        assert.truthy(schema.table:validate({}))
    end)

    it("`schema.table` invalidates a non-table", function()
        assert.falsy(schema.table:validate("hello"))
    end)

    it("`schema.func` validates a function", function()
        assert.truthy(schema.func:validate(function() end))
    end)

    it("`schema.func` invalidates a non-function", function()
        assert.falsy(schema.func:validate(42))
    end)

    -- ==================== Container schemas ====================

    it("`schema.exactly` validates a table with exactly the right keys", function()
        local s = schema.exactly { name = 'str', age = 'num' }
        assert.truthy(s:validate({ name = "bob", age = 42 }))
    end)

    it("`schema.exactly` invalidates a table with a missing key", function()
        local s = schema.exactly { name = 'str', age = 'num' }
        assert.falsy(s:validate({ name = "bob" }))
    end)

    it("`schema.exactly` invalidates a table with an extra key", function()
        local s = schema.exactly { name = 'str' }
        assert.falsy(s:validate({ name = "bob", extra = "bad" }))
    end)

    it("`schema.atmost` validates a table that is a subset of the schema keys", function()
        local s = schema.atmost { name = 'str', age = 'num' }
        assert.truthy(s:validate({ name = "bob" }))
    end)

    it("`schema.atmost` invalidates a table with a key not in the schema", function()
        local s = schema.atmost { name = 'str', age = 'num' }
        assert.falsy(s:validate({ name = "bob", age = 42, extra = "bad" }))
    end)

    it("`schema.atleast` validates a table that is a superset of the schema keys", function()
        local s = schema.atleast { name = 'str', age = 'num' }
        assert.truthy(s:validate({ name = "bob", age = 42, extra = "ok" }))
    end)

    it("`schema.atleast` invalidates a table missing a required key", function()
        local s = schema.atleast { name = 'str', age = 'num' }
        assert.falsy(s:validate({ name = "bob" }))
    end)

    it("`schema.any` validates when at least one subschema matches", function()
        local s = schema.any { schema.str, schema.num }
        assert.truthy(s:validate("hello"))
    end)

    it("`schema.any` invalidates when no subschema matches", function()
        local s = schema.any { schema.str, schema.num }
        assert.falsy(s:validate(true))
    end)

    it("`schema.all` validates when all subschemas match", function()
        local s = schema.all { schema.num, schema.rng { lower = 0, upper = 100 } }
        assert.truthy(s:validate(50))
    end)

    it("`schema.all` invalidates when any subschema fails", function()
        local s = schema.all { schema.num, schema.rng { lower = 0, upper = 100 } }
        assert.falsy(s:validate(-1))
    end)

    it("`schema.none` validates when no subschema matches", function()
        local s = schema.none { schema.str, schema.num }
        assert.truthy(s:validate(true))
    end)

    it("`schema.none` invalidates when a subschema matches", function()
        local s = schema.none { schema.str, schema.num }
        assert.falsy(s:validate("hello"))
    end)

    it("`schema.maybe` validates nil", function()
        local s = schema.maybe { schema.num }
        assert.truthy(s:validate(nil))
    end)

    it("`schema.maybe` validates the inner type", function()
        local s = schema.maybe { schema.num }
        assert.truthy(s:validate(42))
    end)

    it("`schema.maybe` invalidates a wrong type", function()
        local s = schema.maybe { schema.num }
        assert.falsy(s:validate("hello"))
    end)

    it("`schema.vec` validates an integer-keyed table", function()
        local s = schema.vec { schema.num }
        assert.truthy(s:validate({ 1, 2, 3 }))
    end)

    it("`schema.vec` invalidates a table with string keys", function()
        local s = schema.vec { schema.num }
        assert.falsy(s:validate({ [1] = 1, ["a"] = 2 }))
    end)

    -- ==================== Descriptive schemas ====================

    it("`schema.constant` validates the exact constant", function()
        local s = schema.constant(42)
        assert.truthy(s:validate(42))
    end)

    it("`schema.constant` invalidates a different value", function()
        local s = schema.constant(42)
        assert.falsy(s:validate(43))
    end)

    it("`schema.constraint` validates when the function returns true", function()
        local s = schema.constraint(function(v) return v > 0 end)
        assert.truthy(s:validate(5))
    end)

    it("`schema.constraint` invalidates when the function returns false", function()
        local s = schema.constraint(function(v) return v > 0 end)
        assert.falsy(s:validate(-1))
    end)

    it("`schema.rng` validates a value within range", function()
        local s = schema.rng { lower = 0, upper = 100 }
        assert.truthy(s:validate(50))
    end)

    it("`schema.rng` invalidates a value outside range", function()
        local s = schema.rng { lower = 0, upper = 100 }
        assert.falsy(s:validate(150))
    end)

    it("`schema.size` validates a table within size range", function()
        local s = schema.size { lower = 1, upper = 5 }
        assert.truthy(s:validate({ 1, 2, 3 }))
    end)

    it("`schema.size` invalidates a table outside size range", function()
        local s = schema.size { lower = 1, upper = 5 }
        assert.falsy(s:validate({ 1, 2, 3, 4, 5, 6 }))
    end)

    it("`schema.hasmetatable` validates a table with the specified metatable", function()
        local mt = {}
        local s = schema.hasmetatable(mt)
        local obj = setmetatable({}, mt)
        assert.truthy(s:validate(obj))
    end)

    it("`schema.hasmetatable` invalidates a table with a different metatable", function()
        local mt = {}
        local other = {}
        local s = schema.hasmetatable(mt)
        local obj = setmetatable({}, other)
        assert.falsy(s:validate(obj))
    end)

    it("`schema.empty` validates an empty string", function()
        assert.truthy(schema.empty:validate(""))
    end)

    it("`schema.empty` invalidates a non-empty string", function()
        assert.falsy(schema.empty:validate("hello"))
    end)

    -- ==================== Modifier schemas ====================

    it("`schema.default` sets default when value is nil", function()
        local s = schema.default { 'num', default = function() return 10 end }
        local result = s:prevalidate(nil)
        assert.equal(10, result)
    end)

    it("`schema.default` preserves a non-nil value", function()
        local s = schema.default { 'num', default = function() return 10 end }
        local result = s:prevalidate(99)
        assert.equal(99, result)
    end)

end)

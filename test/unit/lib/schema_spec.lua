-- Test file for lib/schema.lua using busted
local busted = require 'busted'
local schema = require 'lib.schema'

describe("schema", function()

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

    it("`schema.any` of constants is a categorical variable", function()
        local s = schema.any { 'low', 'medium', 'high' }
        assert.truthy(s:validate('medium'))
        assert.falsy(s:validate('urgent'))
    end)

    it("`schema.any` of nothing matches nothing", function()
        assert.falsy(schema.any {}:validate('anything'))
        assert.falsy(schema.any(nil):validate('anything'))
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

    it("`schema.unique` drops repeated elements, keeping the first", function()
        local s = schema.unique { schema.str }
        assert.same({"a", "b"}, s:prevalidate({"a", "b", "a"}, {}))
        assert.same({"a", "b", "a"}, schema.vec { schema.str }:prevalidate({"a", "b", "a"}, {}))
    end)

    it("`schema.unique` validates like a vec", function()
        local s = schema.unique { schema.num }
        assert.is_true(s:validate({1, 2}))
        assert.is_false(s:validate({a = 1}))
    end)

    it("`schema.vec` normalises a single value into a one-element list", function()
        local s = schema.vec { schema.num }
        assert.same({ 5 }, s:prevalidate("5"))
        assert.is_nil(s:prevalidate(nil))
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

    it("`schema.empty` validates a missing value", function()
        assert.truthy(schema.empty:validate(nil))
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

    -- ==================== CLI input coercion (fix-typed-field-cli-input-1) ====================

    it("`schema.num` coerces a numeric string on prevalidate", function()
        local result = schema.num:prevalidate("15")
        assert.equal(15, result)
    end)

    it("`schema.num` leaves a non-numeric string alone on prevalidate, so validate still reports the error", function()
        local result = schema.num:prevalidate("hello")
        assert.equal("hello", result)
        assert.falsy(schema.num:validate(result))
    end)

    it("`schema.num` leaves an already-numeric instance unchanged", function()
        local result = schema.num:prevalidate(42)
        assert.equal(42, result)
    end)

    it("`schema.maybe{schema.num}` coerces a CLI-style numeric string end-to-end (covers `cost`/`benefit`)", function()
        local s = schema.maybe { schema.num }
        local result = s:prevalidate("15")
        assert.equal(15, result)
        assert.truthy(s:validate(result))
    end)

    it("`unapply` leaves a value that is already unformatted untouched", function()
        local s = schema.atleast { at = schema.formatted { schema.datetime } }
        assert.same({at = 60}, s:unapply('format', {at = 60}))
        assert.same({at = 60}, s:unapply('format', s:apply('format', {at = 60})))
    end)

    it("`schema.maybe{schema.formatted{schema.datetime}}` converts a datetime string end-to-end (covers `due`)", function()
        local s = schema.maybe { schema.formatted { schema.datetime } }
        local result = s:prevalidate("2026-07-10 09:00:00")
        assert.equal("number", type(result))
        assert.truthy(s:validate(result))
    end)

    it("`schema.datetime` reads a date-only value as midnight", function()
        local s = schema.formatted { schema.datetime }
        assert.equal(os.time({year = 2026, month = 1, day = 1, hour = 0, isdst = false}), s:prevalidate("2026-01-01"))
    end)

    it("`schema.datetime` reads ISO 8601 times, with or without seconds and a zone", function()
        local s = schema.formatted { schema.datetime }
        local local8 = os.time({year = 2026, month = 10, day = 1, hour = 8, isdst = false})
        assert.equal(local8, s:prevalidate("2026-10-01T08:00"))
        assert.equal(local8, s:prevalidate("2026-10-01T08:00:00"))
        assert.equal(local8 + local8 - os.time(os.date("!*t", local8)), s:prevalidate("2026-10-01T08:00:00Z"))
        assert.equal(s:prevalidate("2026-10-01T06:00:00Z"), s:prevalidate("2026-10-01T08:00:00+02:00"))
        assert.equal(s:prevalidate("2026-10-01T06:00:00Z"), s:prevalidate("2026-10-01T06:00:00.123Z"))
        assert.equal(s:prevalidate("2026-10-01T06:00:00Z"), s:prevalidate("2026-10-01T01:30:00-0430"))
    end)

    it("`schema.datetime` does not format an ISO time with an unknown zone", function()
        assert.equal("2026-10-01T08:00:00 later", schema.datetime:unapply('format', "2026-10-01T08:00:00 later"))
    end)

    it("`schema.datetime` interprets a phrase through containers, relative to now", function()
        local naturaltime = require 'lib.naturaltime'
        local s = schema.maybe { schema.formatted { schema.datetime } }
        assert.equal(naturaltime.parse("next year"), s:unapply('interpret', "next year"))
        assert.equal(60, s:unapply('interpret', 60))
        assert.equal("in 3 days", s:apply('interpret', os.time() + 3 * 86400))
    end)

    it("`schema.date` interprets a phrase as the midnight of its day", function()
        local naturaltime = require 'lib.naturaltime'
        local t = os.date('*t', naturaltime.parse("tomorrow"))
        local midnight = os.time({year = t.year, month = t.month, day = t.day, hour = 0, isdst = false})
        assert.equal(midnight, schema.date:unapply('interpret', "tomorrow arvo"))
    end)

    it("`schema.formatted` reads a value its format iso cannot through its interpret iso", function()
        local naturaltime = require 'lib.naturaltime'
        local s = schema.atleast { due = schema.maybe { schema.formatted { schema.datetime } } }
        assert.equal(naturaltime.parse("next year"), s:prevalidate({due = "next year"}).due)
        assert.equal(os.time({year = 2026, month = 1, day = 1, hour = 0, isdst = false}), s:prevalidate({due = "2026-01-01"}).due)
    end)

    it("`schema.formatted` raises which value and field it could not read", function()
        local s = schema.atleast { due = schema.maybe { schema.formatted { schema.datetime } } }
        local ok, err = pcall(s.prevalidate, s, {due = "garbage words"})
        local text = tostring(err):gsub("\27%[[%d;]*m", "")
        assert.is_false(ok)
        assert.truthy(text:find("Cannot interpret `garbage words`", 1, true))
        assert.truthy(text:find('due = "garbage words"', 1, true))
    end)

    it("`schema.datetime` rejects a phrase it cannot interpret", function()
        assert.has_error(function() schema.datetime:unapply('interpret', "tomorrow blorp") end)
    end)

    it("`schema.all` prevalidates through each of its subschemas", function()
        local s = schema.all { schema.num, schema.rng {0, 20} }
        assert.equal(15, s:prevalidate("15"))
    end)

    it("`schema.maybe{schema.num}` still validates nil as fine", function()
        local s = schema.maybe { schema.num }
        assert.truthy(s:validate(s:prevalidate(nil)))
    end)

    it("`collect` gathers the values that sit under a named schema, wherever they are nested", function()
        local s = schema.atleast {
            first = schema.maybe { schema.str },
            many = schema.vec { schema.formatted { schema.str } },
            count = schema.num
        }
        local found = s:collect('str', {first = "a", many = {"b", "c"}, count = 1})
        table.sort(found)
        assert.same({"a", "b", "c"}, found)
        assert.same({}, s:collect('str', {count = 1}))
        assert.same({1}, s:collect('num', {first = "a", count = 1}))
    end)

    it("`apply` formats every element of a vec through its element's iso", function()
        local s = schema.maybe { schema.vec { schema.formatted { schema.datetime } } }
        assert.same({os.date("%Y-%m-%d %H:%M:%S", 0), os.date("%Y-%m-%d %H:%M:%S", 60)}, s:apply('format', {0, 60}))
    end)

    it("`unapply` unformats every element of a vec through its element's iso", function()
        local s = schema.vec { schema.formatted { schema.datetime } }
        local formatted = s:apply('format', {0, 60})
        assert.same({0, 60}, s:unapply('format', formatted))
    end)

    it("`apply` only formats the fields of a table schema that have the iso", function()
        local s = schema.atleast { at = schema.formatted { schema.datetime }, name = schema.str }
        local result = s:apply('format', {at = 0, name = "x", extra = 1})
        assert.same({at = os.date("%Y-%m-%d %H:%M:%S", 0), name = "x", extra = 1}, result)
    end)

    it("`apply` leaves nil and its input untouched", function()
        local s = schema.atleast { at = schema.maybe { schema.formatted { schema.datetime } } }
        local input = {at = nil}
        assert.same({}, s:apply('format', input))
        local list = {0}
        schema.vec { schema.formatted { schema.datetime } }:apply('format', list)
        assert.same({0}, list)
    end)

    it("`apply` leaves values its iso owner does not validate untouched", function()
        local s = schema.atleast { at = schema.formatted { schema.datetime } }
        assert.same({at = "2026-07-10 09:00:00"}, s:apply('format', {at = "2026-07-10 09:00:00"}))
    end)

    it("postvalidate passes through wrapper schemas to their subschema", function()
        schema.register '__spec_double' {
            postvalidate = function(self, instance) return instance * 2 end,
            validate = function() return true end
        }
        assert.equal(4, schema.formatted { schema.__spec_double }:postvalidate(2))
        assert.equal(4, schema.all { schema.__spec_double, schema.num }:postvalidate(2))
        assert.same({4}, schema.vec { schema.formatted { schema.__spec_double } }:postvalidate({2}))
    end)

    describe("failures", function()
        local function plain(failure)
            return (tostring(failure):gsub("\27%[[%d;]*m", ""))
        end

        local function count(text, needle)
            return select(2, text:gsub(needle, ""))
        end

        it("shows the error, then the failing data, then the stack", function()
            local s = schema.atleast { name = schema.all { schema.str } }
            local ok, failure = s:validate({name = 5})
            local text = plain(failure)
            assert.falsy(ok)
            assert.equal("ERROR: Expected a string, got number", text:match("^[^\n]*"))
            assert.truthy(text:find("name = 5", 1, true))
            assert.truthy(text:find("Stack:", 1, true))
            assert.truthy(text:find("at name", 1, true) < text:find("at (root)", 1, true))
        end)

        it("merges the schemas on one path into a single stack line and repeats no context", function()
            local s = schema.atleast { name = schema.all { schema.str } }
            local text = plain(select(2, s:validate({name = 5})))
            assert.equal(1, count(text, "at name"))
            assert.truthy(text:find("at name%s+str"))
            assert.is_nil(text:find("<", 1, true))
            assert.is_nil(text:find("Context:", 1, true))
        end)

        it("leaves out the stack when the failure never leaves one path", function()
            local text = plain(select(2, schema.str:validate(5)))
            assert.is_nil(text:find("Stack", 1, true))
        end)

        it("names the check that failed when it gives no reason", function()
            local text = plain(select(2, schema.constraint(function() return false end):validate(1)))
            assert.equal("ERROR: Failed `constraint` check", text:match("^[^\n]*"))
        end)

        it("lists why each alternative of an any failed", function()
            local text = plain(select(2, schema.any { schema.str, schema.bool }:validate(5)))
            assert.truthy(text:find("- Expected a string, got number", 1, true))
            assert.truthy(text:find("- Expected a boolean, got number", 1, true))
        end)

        it("raises one failure with the whole stack when a prevalidate crashes", function()
            schema.register '__spec_crash' {
                prevalidate = function() error("boom") end,
                validate = function() return true end
            }
            local s = schema.atleast { field = schema.all { schema.__spec_crash } }
            local ok, failure = pcall(s.prevalidate, s, {field = 1})
            local text = plain(failure)
            assert.falsy(ok)
            assert.truthy(text:match("^ERROR: Prevalidation step errored: [^\n]*boom"))
            assert.equal(1, count(text, "ERROR:"))
            assert.truthy(text:find("at field", 1, true) < text:find("at (root)", 1, true))
        end)

        it("raises one failure with the whole stack when a postvalidate crashes", function()
            schema.register '__spec_postcrash' {
                postvalidate = function() error("bang") end,
                validate = function() return true end
            }
            local s = schema.atleast { field = schema.__spec_postcrash }
            local ok, failure = pcall(s.postvalidate, s, {field = 1})
            local text = plain(failure)
            assert.falsy(ok)
            assert.truthy(text:match("^ERROR: Postvalidation step errored: [^\n]*bang"))
            assert.equal(1, count(text, "ERROR:"))
        end)
    end)

end)

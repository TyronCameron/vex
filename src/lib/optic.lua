local func = require 'lib.func'
local function id(x) return x end 

--------------------------------------------------------------------
-- Cardinality
--------------------------------------------------------------------

local Cardinality = {}
setmetatable(Cardinality, {__call = function(self, min, max)
	assert(min == "all" or min == "plus" or min >= 0, "Cardinality requires valid min value")
	assert(max == "all" or max == "plus" or max >= 0, "Cardinality requires valid max value")
	return setmetatable({min = min, max = max}, Cardinality)
end})

local function cardmul(a, b) 
	if a == 0 or b == 0 then return 0 end 
	if a == "plus" or b == "plus" then return "plus" end 
	if a == "all" or b == "all" then return "all" end 
	return a * b 
end 
local function cardmin(a, b) 
	if a == 0 or b == 0 then return 0 end 
	if a == "plus" then return b end 
	if b == "plus" then return a end 
	if a == "all" then return b end 
	if b == "all" then return a end 
	return math.min(a, b)
end 
local function cardmax(a, b) 
	if a == "plus" or b == "plus" then return "plus" end 
	if a == "all" or b == "all" then return "all" end 
	if a == 0 then return b end 
	if b == 0 then return a end 
	return math.max(a, b)
end 

Cardinality.__mul = function(a, b)
	return Cardinality(cardmul(a.min, b.min), cardmul(a.max, b.max))
end
Cardinality.__add = function(a, b)
	return Cardinality(cardmin(a.min, b.min), cardmax(a.max, b.max))
end

--------------------------------------------------------------------

local Optic = {}
Optic.__index = Optic
Optic.__call = function(self, ...)
	-- return Optic.new(...)
end

function Optic.new(t)
	assert(t.cardinality, "optic requires a cardinality field")
	assert(type(t._get) == "function", "optic requires a get function")
	assert(type(t._set) == "function", "optic requires a set function")
	return setmetatable(t, Optic) 
end

--------------------------------------------------------------------
-- Primitives
--------------------------------------------------------------------

function Optic.field(key)
	return Optic.new {
		cardinality = Cardinality(1,1),
		mutating = true,
		_get = function(data, func)
			coroutine.yield(func(data[key]))
		end,
		_set = function(data, func)
			data[key] = func(data[key])
			coroutine.yield(data)
		end 
	}
end 

function Optic.maybe(key)
	return Optic.new {
		cardinality = Cardinality(0,1),
		mutating = true,
		_get = function(data, func)
			if data[key] then coroutine.yield(func(data[key])) end 
		end,
		_set = function(data, func)
		    if data[key] == nil then coroutine.yield(data); return end
		    data[key] = func(data[key])
		    return coroutine.yield(data)
		end
	}
end 

function Optic.iso(forward, backward)
	return Optic.new {
		cardinality = Cardinality(1,1),
		mutating = false,
		_get = function(data)
			coroutine.yield(forward(data))
		end,
		_set = function(data)
			coroutine.yield(backward(data))
		end 
	}
end 

function Optic.none()
	return Optic.new {
		cardinality = Cardinality(0,0),
		mutating = true,
		_get = function(data, func) end,
		_set = function(data, func) end
	}
end

function Optic.ipairs()
	return Optic.new {
		cardinality = Cardinality(0,"all"),
		mutating = true,
		_get = function(data, func)
			for _, v in ipairs(data) do
				coroutine.yield(func(v))
			end
		end,
		_set = function(data, func)
			for i, v in ipairs(data) do
				data[i] = func(v)
			end
			return coroutine.yield(data)
		end
	}
end 

function Optic.pairs()
	return Optic.new {
		cardinality = Cardinality("all","all"),
		mutating = true,
		_get = function(data, func)
			for _, v in pairs(data) do
				coroutine.yield(func(v))
			end
		end,
		_set = function(data, func)
			for i, v in pairs(data) do
				data[i] = func(v)
			end
			return coroutine.yield(data)
		end
	}
end 

function Optic.ifilter(predicate)
	return Optic.new {
		cardinality = Cardinality(0,"all"),
		mutating = true,
		_get = function(data, func)
			for _, v in ipairs(data) do
				if predicate(v) then 
					coroutine.yield(func(v))
				end 
			end
		end,
		_set = function(data, func)
			for i, v in ipairs(data) do
				if predicate(v) then 
					data[i] = func(v)
				end 
			end
			return coroutine.yield(data)
		end
	}
end 

function Optic.filter(predicate)
	return Optic.new {
		cardinality = Cardinality(0,"all"),
		mutating = true,
		_get = function(data, func)
			for _, v in pairs(data) do
				if predicate(v) then 
					coroutine.yield(func(v))
				end 
			end
		end,
		_set = function(data, func)
			for i, v in pairs(data) do
				if predicate(v) then 
					data[i] = func(v)
				end 
			end
			return coroutine.yield(data)
		end
	}
end 

function Optic.ifold(f, init)
	return Optic.new {
		cardinality = Cardinality(1,1),
		mutating = false,
		_get = function(data, func)
			local acc = init
			for i, v in ipairs(data) do
				if init == nil and i == 1 then 
					acc = v
				else 
					acc = f(acc, v, i)
				end 
			end
			coroutine.yield(func(acc))
		end,
		_set = function(data, func) 
			coroutine.yield(data)
		end
	}
end

function Optic.iaccumulate(f, init)
	return Optic.new {
		cardinality = Cardinality("all","all"),
		mutating = false,
		_get = function(data, func)
			local acc = init
			for i, v in ipairs(data) do
				if init == nil and i == 1 then 
					acc = v
				else 
					acc = f(acc, v, i)
				end 
				coroutine.yield(func(acc))
			end
		end,
		_set = function(data, func) 
			coroutine.yield(data)
		end
	}
end

local function gettraverse(data, children, func, visited)
	visited[data] = true
	coroutine.yield(func(data))
	for _, child in ipairs(children(data)) do
		if not visited[child] then 
			gettraverse(child, children, func, visited)
		end 
	end
end 

local function settraverse(data, children, func, visited)
	visited[data] = true
	local childs = children(data)
	for i, child in ipairs(childs) do
		if not visited[child] then 
			childs[i] = func(child)
			settraverse(childs[i], children, func, visited)
		end 
	end
end 

function Optic.traverse(children)
	return Optic.new {
		cardinality = Cardinality(1,"plus"),
		mutating = true,
		_get = function(data, func)
			gettraverse(data, children, func, {})
		end,
		_set = function(data, func)
			settraverse(data, children, func, {})
			coroutine.yield(data)
		end
	}
end

local function isleaf(data, children)
	for i, v in ipairs(children(data)) do
		return false 
	end
	return true
end

local function isbranch(data, children)
	for i, v in ipairs(children(data)) do
		return true
	end
	return false
end

function Optic.leaves(children)
	return Optic.chain(Optic.traverse(children), Optic.ifilter(isleaf))
end 

function Optic.branches(children)
	return Optic.chain(Optic.traverse(children), Optic.ifilter(isbranch))
end 
	
--------------------------------------------------------------------
-- Combinators
--------------------------------------------------------------------

function Optic.chain(...)
	local optics = {...}
	return Optic.new {
		cardinality = func.ifold(optics, function(card, optic) return card * optic.cardinality end, Cardinality(1,1)),
		mutating = func.ifold(optics, function(mut, optic) return mut and optic.mutating end, true),
		_get = function(data, func)
            local focus = {data}
            for _, optic in ipairs(optics) do
                local next = {}
                for _, v in ipairs(focus) do
                    for _, r in ipairs(optic:get(v)) do
                        table.insert(next, r)
                    end
                end
                focus = next
            end
            for _, v in ipairs(focus) do
                coroutine.yield(func(v))
            end
        end,
        _set = function(data, func)
		    local focus = {data}
		    for i, optic in ipairs(optics) do
		        if i == #optics then
		            for _, v in ipairs(focus) do
		                optic:set(v, func)
		            end
		        else
		            local next = {}
		            for _, v in ipairs(focus) do
		                for _, r in ipairs(optic:get(v)) do
		                    table.insert(next, r)
		                end
		            end
		            focus = next
		        end
		    end
		    coroutine.yield(data)
		end,
	}
end

function Optic.fanout(...)
	local optics = {...}
	return Optic.new {
		cardinality = func.ifold(optics, function(card, optic) return card + optic.cardinality end, Cardinality(1,1)),
		mutating = func.ifold(optics, function(mut, optic) return mut or optic.mutating end, true),
		_get = function(data, func)
			for _,optic in ipairs(optics) do
				coroutine.yield(optic:get(data, func))
			end
		end,
		_set = function(data, func)
			for _,optic in ipairs(optics) do
				optic:set(data, func)
			end
			coroutine.yield(data)
		end
	}
end

local function increment_multi_index(indexes, maxindexes)
	for i = #indexes, 1 do
		if indexes[i] == maxindexes[i] then 
			for j = i, #indexes do
				indexes[j] = 1 
			end
			if i == 1 then return indexes, true end
		else 
			indexes[i] = indexes[i] + 1 
			return indexes, false
		end 
	end
end 

local function cartesian_product_gen(lists, func)
	local indexes, maxindexes = {}, {}
	for i, list in ipairs(lists) do
		table.insert(indexes, 1)
		table.insert(maxindexes, #list)
	end

	local done = false
	while not done do 
		local tab = {}
		for i, list in ipairs(lists) do
			table.insert(tab, list[indexes[i]])
		end
		coroutine.yield(func(tab))
		index, done = increment_multi_index(index, maxindexes)
	end 
end

function Optic.cartesian(...)
	local optics = {...}
	return Optic.new {
		cardinality = func.ifold(optics, function(card, optic) return card * optic.cardinality end, 1),
		mutating = false,
		_get = function(data, func)
		    local lists = {}
		    for _, optic in ipairs(optics) do
		        table.insert(lists, optic:get(data))
		    end
		    cartesian_product_gen(lists, func)
		end,
		_set = function(data, func)
			coroutine.yield(data)
		end
	}
end

--------------------------------------------------------------------
-- Terminals
--------------------------------------------------------------------

function Optic:get(data, func)
    func = func or id
    local results = {}
    local co = coroutine.create(function()
        self._get(data, func)
    end)
    while true do
        local ok, val = coroutine.resume(co)
        if not ok or coroutine.status(co) == "dead" then break end
        table.insert(results, val)
    end
    return results
end

function Optic:set(data, func)
    local co = coroutine.create(function()
        self._set(data, func)
    end)
    local ok, result = coroutine.resume(co)
    return result
end

return Optic
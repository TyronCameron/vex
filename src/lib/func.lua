
local func = {}

function func.imap(arr, f)
	local res = {}
	for i, v in ipairs(arr) do
		table.insert(res, f(v, i))
	end
	return res
end

function func.map(arr, f)
	local res = {}
	for i, v in pairs(arr) do
		res[i] = f(v, i)
	end
	return res
end

function func.ifilter(arr, f)
	local res = {}
	for i, v in ipairs(arr) do
		if f(v, i) then
			table.insert(res, v)
		end
	end
	return res
end

function func.filter(arr, f)
	local res = {}
	for i, v in pairs(arr) do
		if f(v, i) then
			res[i] = v
		end
	end
	return res
end

function func.ifold(arr, f, init)
	local acc = init
	for i, v in ipairs(arr) do
		if init == nil and i == 1 then 
			acc = v
		else 
			acc = f(acc, v, i)
		end 
	end
	return acc
end

function func.ireduce(arr, f, init)
	local acc = init
	for i, v in ipairs(arr) do
		if init == nil and i == 1 then 
			acc = v
		else 
			acc = f(acc, v, i)
		end 
	end
	return acc
end

function func.reduce(tab, f, init)
	local acc = init
	local seeded = init ~= nil
	for k, v in pairs(tab) do
		if seeded then 
			acc = f(acc, v, k)
		else 
			acc = v
			seeded = true
		end 
	end
	return acc
end

function func.keys(tab)
	local keys = {}
	for key in pairs(tab) do
		table.insert(keys, key)
	end
	return keys 
end

function func.values(tab)
	local values = {}
	for _, value in pairs(tab) do
		table.insert(values, value)
	end
	return values 
end

function func.imerge(a, b)
	local tab = {}
	for _, value in ipairs(a) do
		table.insert(tab, value)
	end
	for _, value in ipairs(b) do
		table.insert(tab, value)
	end
	return tab
end


---


function func.sum(tab)
	return func.reduce(tab, function(a,b) return a + b end)
end

function func.prod(tab)
	return func.reduce(tab, function(a,b) return a * b end)
end

function func.count(tab, f)
	if not f and type(tab) == "function" then return function(x) return func.count(x, tab) end end
	local f = f or function(x) return true end
	return #func.values(func.filter(tab, f))
end

function func.any(tab, f)
	if not f and type(tab) == "function" then return function(x) return func.any(x, tab) end end
	local f = f or function(x) return x end
	return func.reduce(func.map(tab, f), function(a,b) return a or b end, false)
end

function func.all(tab, f)
	if not f and type(tab) == "function" then return function(x) return func.all(x, tab) end end
	local f = f or function(x) return x end
	return func.reduce(func.map(tab, f), function(a,b) return a and b end, true)
end

function func.reverse(tab)
	local new_tab = {}
	for i,v in ipairs(tab) do
		new_tab[#tab - i + 1] = v
	end
	return new_tab
end

function func.range(start_val, end_val, by)
	local by = by or 1
	assert(by ~= 0, "Cannot give 0 to the range function")
	if not end_val then 
		end_val = start_val
		start_val = 1
	end 
	local n = (end_val - start_val) / by
	if end_val < start_val and by > 0 then return {} end
	if n < 1 then return {} end
	local tab = {start_val}
	for i=1,n do
		table.insert(tab, tab[i] + by)
	end
	return tab
end

function func.slice(tab, start_idx, end_idx)
	if not end_idx and type(tab) == "number" then return function(x) return func.slice(x, tab, start_idx) end end
	if end_idx < start_idx then return {} end 
	if not end_idx then 
		end_idx = start_idx
		start_idx = 1
	end
	if end_idx == "end" or end_idx > #tab then end_idx = #tab end 
	if start_idx == "begin" or start_idx < 1 then start_idx = 1 end 
	local new_tab = {}
	for i=start_idx,end_idx do
		table.insert(new_tab, tab[i])
	end
	return new_tab
end

function func.first(tab, n)
	if not n and type(tab) == "function" then return function(x) return func.first(x, tab) end end
	n = n or 1 
	return func.slice(tab, 1, n)
end

function func.last(tab, n)
	if not n and type(tab) == "function" then return function(x) return func.last(x, tab) end end
	n = n or 1 
	return func.slice(tab, #tab - n + 1, #tab)
end

function func.rep(tab, n)
	if not n then return function(x) return func.rep(x, tab) end end
	local new_tab = {}
	for i=1,n do
		if type(tab) == "table" then 
			for _,v in ipairs(tab) do
				table.insert(new_tab, v)
			end
		else 
			table.insert(new_tab, tab)
		end
	end
	return new_tab
end

function func.isempty(tab)
	return #tab == 0 
end

return func 

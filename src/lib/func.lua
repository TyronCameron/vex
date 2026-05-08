
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
		table.insert(res, f(v, i))
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
			table.insert(res, v)
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

return func 

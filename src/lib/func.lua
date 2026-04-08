
local func = {}

function func.ifilter(arr, f)
	local res = {}
	for _, v in ipairs(arr) do
		if f(v) then
			table.insert(res, v)
		end
	end
	return res
end

function func.ifilteriter(arr, f)
	return coroutine.wrap(function()
		local i = 0
		for _, v in ipairs(arr) do
			if f(v) then
				i = i + 1
				coroutine.yield(i, v)
			end
		end
	end)
end

return func 

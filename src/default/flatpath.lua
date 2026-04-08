
return {
	path = function(config, rootpath, task)
		return rootpath .. '/' .. task.vexid .. '.md'
	end 
}

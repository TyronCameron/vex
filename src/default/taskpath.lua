
return function(rootpath, config, task)
	return rootpath .. '/' .. config.taskfolder .. '/' .. task.vexid .. '.md'
end 

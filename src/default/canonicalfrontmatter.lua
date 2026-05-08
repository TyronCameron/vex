return function(task)
    local front = {}
    for key, value in pairs(task) do
        if key ~= "vexbody" then 
            front[key] = value
        end 
    end
    return front
end 
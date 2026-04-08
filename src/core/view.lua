


local View = {views = {}}
View.__index = View

-- create new view manager
function View.new()
    return setmetatable({}, View)
end 

function View:view(name)
    return function(tab)
        self.views[name] = tab
    end
end

-- actually print stuff to screen
function View:display(optic)

end

-- only need one
return View.new()
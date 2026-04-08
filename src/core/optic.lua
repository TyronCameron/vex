


local Optic = {optics = {}}
Optic.__index = Optic

-- new lens manager
function Optic.new()
    
end 

function Optic:optic(name)
    return function(tab)
        self.optics[name] = tab
    end
end

function Optic:get(name)
    return self.optics[name]
end

-- only need one
return Optic.new()
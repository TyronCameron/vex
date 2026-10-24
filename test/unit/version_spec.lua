describe("version", function()

    it("is a semantic version", function()
        assert.truthy(require('version'):match('^%d+%.%d+%.%d+[%w%.%-]*$'))
    end)

    it("matches the version in lux.toml", function()
        local f = assert(io.open(debug.getinfo(1, 'S').source:match('^@(.+[\\/])') .. '../../lux.toml'))
        local lux = f:read('*a')
        f:close()
        assert.equal(require('version'), lux:match('\nversion = "([^"]+)"'))
    end)

end)

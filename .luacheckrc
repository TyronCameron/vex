std = "luajit"
only = {"1", "5"}
ignore = {"512", "581"}
exclude_files = {"src/lib/binser.lua", "src/lib/lfs.lua"}
files["test"] = {std = "+busted", globals = {"io", "os"}}

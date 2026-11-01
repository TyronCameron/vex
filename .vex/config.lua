return {
	default = {
    	tasktype = "task",
    },
    paths = {
        groupby = {
       		"status",
            "lineage"
     	},
    },
    taskfolder = "vexdoc/vex",
    taskowners = {},
    loglimit = 1000,
    fingerprint = {
        exclude = {"modified"},
    },
}

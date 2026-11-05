return {
    taskfolder = '.',
    default = {
        tasktype = 'task'
    },
    paths = {
        groupby = {'status', 'lineage'}
    },
    taskowners = {},
    loglimit = 100,
    fingerprint = {
        exclude = {'modified'}
    }
}

--- SparkMod plugin scheduler.
-- Scheduled tasks are automatically unscheduled when a plugin is unloaded

scheduler = { tasks = { } }

--- Schedules a task to be run in amount of seconds
-- @number seconds the amount of time until the callback is called
-- @func callback the function to be called at the scheduled time
-- @param ... any number of tag strings which will be associated with this task
-- @treturn table a table containing info about the scheduled task
function scheduler.In(seconds, callback, ...)
    local task = Scheduler.In(seconds, callback, ...)
    task.plugin_name = plugin_name
    table.insert(scheduler.tasks, { id = task.id, tags = {...} })
    return task
end

--- Schedules a task to be run every amount of seconds
-- @number seconds the amount of time between each time the callback is called
-- @func callback the function to be called at the scheduled time
-- @param ... any number of tag strings which will be associated with this task
-- @treturn table a table containing info about the scheduled task
function scheduler.Every(seconds, callback, ...)
    local task = Scheduler.Every(seconds, callback, ...)
    task.plugin_name = plugin_name
    table.insert(scheduler.tasks, { id = task.id, tags = {...} })
    return task
end

--- Unschedules any number of tasks by ids, tags or task tables
-- @param ... any number of tag strings, ids or task tables
function scheduler.Unschedule(...)
    for i = 1, select('#', ...) do
        local arg = select(i, ...)
        local tag, id
        if type(arg) == "string" then
            tag = arg
        else
            id = type(arg) == "table" and arg.id or arg
        end
        for task_index = #scheduler.tasks, 1, -1 do
            local task = scheduler.tasks[task_index]
            if task.id == id or tag and #task.tags > 0 then
                if task.id == id then
                    Scheduler.Unschedule(task.id)
                    table.remove(scheduler.tasks, task_index)
                    break
                elseif tag and table.contains(task.tags, tag) then
                    Scheduler.Unschedule(task.id)
                    table.remove(scheduler.tasks, task_index)
                end
            end
        end
    end
end

--- Unschedules all tasks that the plugin has scheduled
function scheduler.UnscheduleAll()
    for _, task in ipairs(scheduler.tasks) do
        Scheduler.Unschedule(task.id)
    end
    scheduler.tasks = { }
end
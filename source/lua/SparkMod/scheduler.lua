-- A simple scheduler that supports scheduling tasks with incremental ids and tags

Scheduler = { tasks = { }, current_id = 0 }

-- Schedules task in amount of seconds: seconds, callback, tags...
function Scheduler.In(seconds, callback, ...)
    Scheduler.current_id = Scheduler.current_id + 1
    local task = { id = Scheduler.current_id, at = Shared.GetTime() + seconds, callback = callback, tags = {...} }
    table.insert(Scheduler.tasks, task)
    return task
end

-- Schedules task every amount of seconds: seconds, callback, tags...
function Scheduler.Every(seconds, callback, ...)
    Scheduler.current_id = Scheduler.current_id + 1
    local task = { id = Scheduler.current_id, at = Shared.GetTime() + seconds, callback = callback, tags = {...}, every = seconds }
    table.insert(Scheduler.tasks, task)
    return task
end

-- Unschedule by task table(s), id(s) or tag(s)
function Scheduler.Unschedule(...)
    for i = 1, select('#', ...) do
        local arg = select(i, ...)
        local tag, id
        if type(arg) == "string" then
            tag = arg
        else
            id = type(arg) == "table" and arg.id or arg
        end
        for task_index = #Scheduler.tasks, 1, -1 do
            local task = Scheduler.tasks[task_index]
            if task.id == id or tag and #task.tags > 0 then
                if task.id == id then
                    task.destroy = true
                    break
                elseif tag and table.contains(task.tags, tag) then
                    task.destroy = true
                end
            end
        end
    end
end

-- Called at least once every 0.1 seconds making timers accurate to 0.1
function Scheduler.Update()
    local now = Shared.GetTime()
    for i = #Scheduler.tasks, 1, -1 do
        local task = Scheduler.tasks[i]
        if task.destroy then
            table.remove(Scheduler.tasks, i)
        elseif task.at <= now then
            if task.every then
                task.at = now + task.every
            else
                table.remove(Scheduler.tasks, i)
            end
            local suceeded, err = SparkMod.Call(task.callback)
            if not suceeded then
                Puts("Error while processing scheduled callback: %s", err.message)
                Puts(err.traceback)
                Plugin.On("Error", err, task.plugin_name or "SparkMod", "Scheduler")
            end
        end
    end
end
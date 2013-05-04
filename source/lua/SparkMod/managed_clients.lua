-- SparkMod managed clients table

SparkMod.clients = {
    count = 0,

    Count = function(obj)
        if obj then
            obj_type = type(obj)                
            if not obj_type == "function" and not obj_type == "table" then
                error("You must pass a function or a table to clients.Count()")
            end
            local count = 0
            for _, data in SparkMod.clients do
                if obj_type == "table" then
                    local is_equal = true
                    for index, value in pairs(obj) do
                        if data[index] ~= value then
                            is_equal = false
                            break
                        end
                    end
                    if is_equal then
                        count = count + 1
                    end
                else
                    if func(data) then
                        count = count + 1
                    end
                end
            end
            return count
        end
        
        return SparkMod.clients.count
    end,

    Each = function(func)
        for _, data in SparkMod.clients do
            func(data)
        end
        return SparkMod.clients.count
    end
}
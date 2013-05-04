-- SparkMod cookie management

function SparkMod.SetUserIdCookie(user_id, cookie_name, value)
    SparkMod.RefreshCookies()

    SparkMod.cookies[user_id] = SparkMod.cookies[user_id] or { }

    local old_value = SparkMod.cookies[user_id][cookie_name]
    if table.eq(old_value, value) then
        return false
    end
    
    SparkMod.cookies[user_id][cookie_name] = SparkMod.cookies[user_id][cookie_name] or { }
    SparkMod.cookies[user_id][cookie_name].value = value
    SparkMod.cookies[user_id][cookie_name].timestamp = Shared.GetSystemTime()

    SparkMod.SaveCookies()
    
    return true
end

function SparkMod.SetClientCookie(client, cookie_name, value)
    return SparkMod.SetUserIdCookie(client:GetUserId(), cookie_name, value)
end

function SparkMod.GetUserIdRawCookie(user_id, cookie_name)
    SparkMod.RefreshCookies()

    local user_cookies = SparkMod.cookies[user_id]
    
    return user_cookies and user_cookies[cookie_name]
end

function SparkMod.GetUserIdCookie(user_id, cookie_name)
    local cookie = SparkMod.GetUserIdRawCookie(user_id, cookie_name)

    return cookie and cookie.value
end

function SparkMod.GetClientCookie(client, cookie_name)
    return SparkMod.GetUserIdCookie(client:GetUserId(), cookie_name)
end

function SparkMod.GetClientCookieTime(client, cookie_name)
    local cookie = SparkMod.GetUserIdRawCookie(user_id, cookie_name)
    
    return cookie and cookie.timestamp
end

function SparkMod.BuildClientCookiesProxy(client)
    local metatable = {
        __index = function(_, index)
            return SparkMod.GetClientCookie(client, index)
        end,
        __newindex = function(_, index, value)
            SparkMod.SetClientCookie(client, index, value)
        end
    }

    return setmetatable({ }, metatable)
end
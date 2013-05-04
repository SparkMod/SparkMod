-- SparkMod web interface

local function JsonResponse(obj)
    return "application/json", json.encode(obj)
end

SparkMod.event_prehooked.WebRequest = true

local getmods_cache = { }

function SparkMod.OnPreWebRequest(params)
    if params.request == "getmods" then

        local url = "http://www.unknownworlds.com/spark/browse_workshop.php?appid=4920"
        local searchtext = params.searchtext
        if type(searchtext) == "string" then
            url = string.format("%s&searchtext=%s", url, url_encode(searchtext))
        end
        local page = tostring(params.p)
        if type(page) == "string" then
            url = string.format("%s&p=%s", url, page)
        end
        
        local requested_at = Shared.GetTime()
        
        if getmods_cache[url] then
            local started_loading_at = getmods_cache[url].started_loading_at
            if started_loading_at then
                -- Request times out after 30 seconds
                if requested_at - started_loading_at < 30 then
                    return "application/json", '{"loading": true}'
                end
            else
                -- Cache workshop mods for 60 seconds
                if requested_at - getmods_cache[url].cached_at < 60 then
                    return "application/json", getmods_cache[url].result
                else
                    getmods_cache[url] = nil
                end
            end
        end

        getmods_cache[url] = { started_loading_at = requested_at }
        
        Shared.SendHTTPRequest(url, "GET", function(result)
            getmods_cache[url] = { cached_at = Shared.GetTime(), result = result }
        end)

        return "application/json", '{"loading": true}'

    elseif params.request == "filelist" then

        local root = "sparkmod/plugins"
        local path = "config://"
        if params.dir then
            if not params.dir:starts(root) then
                return "text/html", "Access denied"
            end
            path = path .. params.dir
        end

        local html = '<ul class="jqueryFileTree" style="display: none;">'

        local file_paths = SparkMod.FindMatchingFiles(path .. "/*")

        for _, file_path in ipairs(file_paths) do
            if file_path:ends("/") then
                local dir_name = file_path:match("([^/]+)/$")
                html = ('%s<li class="directory collapsed"><a href="#" rel="%s">%s</a></li>'):format(html, file_path, dir_name)
            else
                local file_name = file_path:match("([^/]+)$")
                local file_ext = file_path:match("([^%.]+)$")
                html = ('%s<li class="file ext_%s"><a href="#" rel="%s">%s</a></li>'):format(html, file_ext, file_path, file_name)
            end
        end

        html = html .. '</ul>'

        return "text/html", html

    elseif params.request == "filecontents" then

        local file = io.open("config://" .. params.file)
        if not file then
            return JsonResponse { error = "File not found: " .. params.file }
        end

        local contents = file:read("*all")

        file:close()

        local plugin_name = params.file:match("sparkmod/plugins/([^/%.]+)")
        local plugin = Plugin.plugins[plugin_name]
        if plugin then plugin_name = plugin.info.name end

        return JsonResponse { file = params.file, plugin = plugin_name, contents = contents }

    elseif params.request == "savepluginfile" then

        local file = io.open("config://" .. params.file, "w+")
        if not file then
            return JsonResponse { error = "File not found: " .. params.file }
        end

        file:write(params.contents)
        file:close()

        return JsonResponse { success = true }

    elseif params.request == "reloadplugin" then

        if Plugin.Reload(params.plugin) then
            return JsonResponse { success = true }
        else
            return JsonResponse { error = Plugin.plugin_errors[params.plugin] }
        end

    end
end
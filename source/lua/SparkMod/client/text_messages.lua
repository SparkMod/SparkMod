SparkMod.screen_text_messages = { }

function SparkMod.DestroyScreenMessage(screen_message)
    GUI.DestroyItem(screen_message.gui_message)
    if screen_message.tag then
        SparkMod.screen_text_messages[screen_message.tag] = nil
    end
end

function SparkMod.PrintToScreen(x, y, text, duration, color, tag)
    x = Client.GetScreenWidth() * x
    y = Client.GetScreenHeight() * y

    local screen_message = tag and screen_text_messages[tag]
    if screen_message then
        screen_message.duration = duration
        screen_message.text = text
        screen_message.x = x
        screen_message.y = y
        screen_message.color = color
        
        local gui_message = screen_message.gui_message
        gui_message:SetPosition(Vector(x, y, 0))
        gui_message:SetText(text)  
        gui_message:SetColor(color)

        Scheduler.Unschedule("destroy-screen-message-" .. tag)
        Scheduler.In(duration, function() SparkMod.DestroyScreenMessage(screen_message) end, "destroy-screen-message-" .. tag)

        return
    end

    local gui_message = GUI.CreateItem()
    gui_message:SetOptionFlag(GUIItem.ManageRender)
    gui_message:SetPosition(Vector(x, y, 0))
    gui_message:SetTextAlignmentX(GUIItem.Align_Center)
    gui_message:SetTextAlignmentY(GUIItem.Align_Center)
    gui_message:SetFontName("fonts/AgencyFB_small.fnt")
    gui_message:SetIsVisible(true)
    gui_message:SetText(text)
    gui_message:SetColor(color)
    
    screen_message = { duration = duration, text = text, tag = tag, gui_message = gui_message }
    
    if screen_message.tag then
        SparkMod.screen_text_messages[tag] = screen_message
        Scheduler.In(duration, function() SparkMod.DestroyScreenMessage(screen_message) end, "destroy-screen-message-" .. tag)
    else
        Scheduler.In(duration, function() SparkMod.DestroyScreenMessage(screen_message) end)
    end
end
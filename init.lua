local mq                     = require('mq')
local ImGui                  = require('ImGui')
local Icons                  = require('mq.ICONS')

local openGUI                = true

local SnipItConsole          = ImGui.ConsoleWidget.new("##SnipItConsole")
SnipItConsole.maxBufferLines = 1000
SnipItConsole.autoScroll     = true

local scriptText             = ""
local captureOutput          = false
local execRequested          = false
local showTimestamps         = true
local execCoroutine          = nil
local status                 = "Idle..."

local function LogToConsole(output, ...)
    if (... ~= nil) then output = string.format(output, ...) end

    local now = os.date('%H:%M:%S')

    if SnipItConsole ~= nil then
        local consoleText = showTimestamps and string.format('\aw[\at%s\aw] \ao%s', now, output) or string.format("\ao%s", output)
        SnipItConsole:AppendText(consoleText)
    end
end

mq.event("SnipItEvent", "#*#", function(output)
    if captureOutput then
        LogToConsole(output)
    end
    mq.flushevents("SnipItEvent")
end)

local function ExecCoroutine()
    captureOutput = true

    return coroutine.create(function()
        local success, msg = Exec()
        if not success then
            LogToConsole("\ar" .. msg)
        end
    end)
end

function Exec()
    local runEnv = [[mq = require('mq')
        %s
        ]]

    local func, err = load(string.format(runEnv, scriptText), "SnipItScript", "t", _G)

    if not func then
        return false, err
    end

    local success, msg = pcall(func)

    return success, msg or ""
end

local function RenderConsole()
    local contentSizeX, contentSizeY = ImGui.GetContentRegionAvail()
    SnipItConsole:Render(ImVec2(contentSizeX, math.max(200, (contentSizeY - 10))))
end

local function RenderEditor()
    ImGui.PushFont(ImGui.ConsoleFont)
    local yPos = ImGui.GetCursorPosY()
    local footerHeight = 35
    local editHeight = (ImGui.GetWindowHeight() * .5) - yPos - footerHeight

    scriptText, _ = ImGui.InputTextMultiline("##_Cmd_Edit", scriptText,
        ImVec2(ImGui.GetWindowWidth() * 0.98, editHeight), ImGuiInputTextFlags.AllowTabInput)
    ImGui.PopFont()
end

local function RenderTooltip(text)
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip(text)
    end
end

local function CenteredButton(label)
    local style = ImGui.GetStyle()

    local framePaddingX = style.FramePadding.x * 2
    local framePaddingY = style.FramePadding.y * 2

    local availableWidth = ImGui.GetContentRegionAvailVec().x
    local availableHeight = 30

    local textSizeVec = ImGui.CalcTextSizeVec(label)
    local textWidth = textSizeVec.x
    local textHeight = textSizeVec.y

    local paddingX = (availableWidth - textWidth - framePaddingX) / 2
    local paddingY = (availableHeight - textHeight - framePaddingY) / 2

    if paddingX > 0 then
        ImGui.SetCursorPosX(ImGui.GetCursorPosX() + paddingX)
    end
    if paddingY > 0 then
        ImGui.SetCursorPosY(ImGui.GetCursorPosY() + paddingY)
    end
    return ImGui.SmallButton(string.format("%s", label))
end

local function RenderToolbar()
    if ImGui.BeginTable("##SnipItToolbar", 5, ImGuiTableFlags.Borders) then
        ImGui.TableSetupColumn("##SnipItToolbarCol1", ImGuiTableColumnFlags.WidthFixed, 30)
        ImGui.TableSetupColumn("##SnipItToolbarCol2", ImGuiTableColumnFlags.WidthFixed, 30)
        ImGui.TableSetupColumn("##SnipItToolbarCol3", ImGuiTableColumnFlags.WidthFixed, 30)
        ImGui.TableSetupColumn("##SnipItToolbarCol4", ImGuiTableColumnFlags.WidthFixed, 180)
        ImGui.TableSetupColumn("##SnipItToolbarCol5", ImGuiTableColumnFlags.WidthStretch, 200)
        ImGui.TableNextColumn()

        if CenteredButton(Icons.MD_PLAY_ARROW) then
            execRequested = true
        end
        RenderTooltip("Execute Script")

        ImGui.TableNextColumn()
        if CenteredButton(Icons.MD_CLEAR) then
            scriptText = ""
        end
        RenderTooltip("Clear Script")

        ImGui.TableNextColumn()
        if CenteredButton(Icons.MD_PHONELINK_ERASE) then
            SnipItConsole:Clear()
        end
        RenderTooltip("Clear Console")

        ImGui.TableNextColumn()
        showTimestamps = ImGui.Checkbox("Print Time Stamps", showTimestamps)
        ImGui.TableNextColumn()
        ImGui.Text("Status: " .. status)
        ImGui.EndTable()
    end
end

local function SnipItGUI()
    ImGui.SetNextWindowSize(ImVec2(800, 600), ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowPos(ImVec2(ImGui.GetIO().DisplaySize.x / 2 - 400, ImGui.GetIO().DisplaySize.y / 2 - 300), ImGuiCond.FirstUseEver)

    ImGui.Begin("Lua SnipIt - By: Derple", openGUI, ImGuiWindowFlags.None)
    RenderEditor()
    RenderToolbar()
    RenderConsole()
    ImGui.End()
end

mq.imgui.init('SnipItGUI', SnipItGUI)
mq.bind('/snipit', function()
    openGUI = not openGUI
end)

LogToConsole("\awSnipIt by: \amDerple \awLoaded...")

while true do
    if execRequested then
        execRequested = false
        execCoroutine = ExecCoroutine()
        coroutine.resume(execCoroutine)
        status = "Running..."
    end

    mq.doevents()

    if execCoroutine and coroutine.status(execCoroutine) ~= 'dead' then
        coroutine.resume(execCoroutine)
    else
        captureOutput = false
        status = "Idle..."
    end

    mq.delay(1000)
end

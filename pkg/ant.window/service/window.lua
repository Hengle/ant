local ltask = require "ltask"
local exclusive = require "ltask.exclusive"
local platform = require "bee.platform"
local SupportGesture <const> = platform.os == "ios"

local function init()
    if SupportGesture then
        local gesture = require "ios.gesture"
        gesture.tap {}
        gesture.pinch {}
        gesture.long_press {}
        gesture.pan {}
    end
end

local message = {}
local quit = false

local function message_loop(update)
    local ServiceWorld = ltask.queryservice "ant.window|world"
    assert(#message > 0 and message[1][1] == "init")
    local initmsg = table.remove(message, 1)
    ltask.call(ServiceWorld, table.unpack(initmsg, 1, initmsg.n))
    init()
    while not quit do
        if #message > 0 then
            ltask.send(ServiceWorld, "msg", message)
            for i = 1, #message do
                message[i] = nil
            end
        end
        if update then
            ltask.wait "update"
        else
            ltask.sleep(0)
        end
    end
    if #message > 0 then
        ltask.send(ServiceWorld, "msg", message)
    end
    ltask.call(ServiceWorld, "exit")
    ltask.multi_wakeup "quit"
end

local S = {}

local function ios_init()
    local scheduling = exclusive.scheduling()
    local window = require "window"
    local function update()
        local SCHEDULE_SUCCESS <const> = 3
        ltask.wakeup "update"
        repeat
            scheduling()
        until ltask.schedule_message() ~= SCHEDULE_SUCCESS
    end
    local handle = window.init(message, update)
    ltask.fork(message_loop, true)
    ltask.fork(function()
        window.mainloop(handle, true)
    end)
end

local function windows_init()
    local window = require "window"
    window.init(message)
    ltask.fork(message_loop, false)
    ltask.fork(function()
        repeat
            exclusive.sleep(0)
            ltask.sleep(0)
        until not window.peekmessage()
        quit = true
    end)
end

if platform.os == "windows" then
    S.create_window = windows_init
else
    S.create_window = ios_init
end

function S.wait()
    ltask.multi_wait "quit"
end

return S

-- Hammerspoon Window Management
-- Reload config: Cmd+Ctrl+R

-- Enable IPC for CLI access
require("hs.ipc")

-- Modifier keys
local hyper = {"ctrl", "alt", "cmd"}

-- Reload config
hs.hotkey.bind(hyper, "R", function()
    hs.reload()
end)
hs.alert.show("Hammerspoon config loaded")

-- Helper function to move and resize window
local function moveWindow(x, y, w, h)
    local win = hs.window.focusedWindow()
    if not win then return end
    local screen = win:screen():frame()
    win:setFrame({
        x = screen.x + (screen.w * x),
        y = screen.y + (screen.h * y),
        w = screen.w * w,
        h = screen.h * h
    })
end

-- Half screen positions
hs.hotkey.bind(hyper, "Left", function()
    moveWindow(0, 0, 0.5, 1)  -- Left half
end)

hs.hotkey.bind(hyper, "Right", function()
    moveWindow(0.5, 0, 0.5, 1)  -- Right half
end)

hs.hotkey.bind(hyper, "Up", function()
    moveWindow(0, 0, 1, 0.5)  -- Top half
end)

hs.hotkey.bind(hyper, "Down", function()
    moveWindow(0, 0.5, 1, 0.5)  -- Bottom half
end)

-- Fullscreen (not native fullscreen, just maximized)
hs.hotkey.bind(hyper, "F", function()
    moveWindow(0, 0, 1, 1)
end)

hs.hotkey.bind(hyper, "M", function()
    moveWindow(0, 0, 1, 1)  -- Maximum
end)

-- Center window (60% width, 80% height)
hs.hotkey.bind(hyper, "C", function()
    moveWindow(0.2, 0.1, 0.6, 0.8)
end)

-- Quarters (corners)
hs.hotkey.bind(hyper, "1", function()
    moveWindow(0, 0, 0.5, 0.5)  -- Top-left
end)

hs.hotkey.bind(hyper, "2", function()
    moveWindow(0.5, 0, 0.5, 0.5)  -- Top-right
end)

hs.hotkey.bind(hyper, "3", function()
    moveWindow(0, 0.5, 0.5, 0.5)  -- Bottom-left
end)

hs.hotkey.bind(hyper, "4", function()
    moveWindow(0.5, 0.5, 0.5, 0.5)  -- Bottom-right
end)

-- Move to next/previous screen
hs.hotkey.bind(hyper, "N", function()
    local win = hs.window.focusedWindow()
    if not win then return end
    win:moveToScreen(win:screen():next())
end)

hs.hotkey.bind(hyper, "P", function()
    local win = hs.window.focusedWindow()
    if not win then return end
    win:moveToScreen(win:screen():previous())
end)

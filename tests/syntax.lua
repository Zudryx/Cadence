-- Syntax check every addon Lua file (compile only, don't run).
local root = arg[1]
local files = { "Core.lua", "Parser.lua", "Rotations/Warrior.lua", "Build.lua", "Engine.lua", "Keys.lua", "Tracker.lua", "Helper.lua", "Utility.lua", "Probe.lua", "Display.lua", "HelperDisplay.lua", "Editor.lua" }
local bad = 0
for _, f in ipairs(files) do
  local fn, err = loadfile(root .. "/" .. f)
  if fn then print("ok   " .. f) else print("FAIL " .. err); bad = bad + 1 end
end
-- Lua 5.1 compatibility: flag 5.2+ only syntax we must avoid in WoW
for _, f in ipairs(files) do
  local h = io.open(root .. "/" .. f); local src = h:read("a"); h:close()
  local n = 0
  for line in src:gmatch("[^\n]*") do
    n = n + 1
    local code = line:gsub("%-%-.*$", "")
    if code:find("goto%s") or code:find("::%w+::") or code:find("[^/]//[^/]") or code:find("~=") == nil and code:find("[^~]~[^=]") or code:find("<<") or code:find(">>") then
      print(("WARN 5.1-compat? %s:%d: %s"):format(f, n, line))
    end
  end
end
-- the secure snippet must also compile
local h = io.open(root .. "/Engine.lua"); local src = h:read("a"); h:close()
local snippet = src:match("local PRE_CLICK = %[=%[(.-)%]=%]")
local fn, err = load("local self, button, down = ...\n" .. snippet, "=PRE_CLICK")
print(fn and "ok   PRE_CLICK snippet" or ("FAIL PRE_CLICK " .. err))
if not fn then bad = bad + 1 end
-- version must match in Cadence.toc and Core.lua
local toc = io.open(root .. "/Cadence.toc"):read("a")
local core = io.open(root .. "/Core.lua"):read("a")
local tv = toc:match("## Version:%s*([%d%.]+)")
local cv = core:match('ns.VERSION = "([%d%.]+)"')
if tv and tv == cv then print("ok   version " .. tv .. " (toc + Core.lua)") else print("FAIL version mismatch: toc " .. tostring(tv) .. ", Core.lua " .. tostring(cv)); bad = bad + 1 end
os.exit(bad == 0 and 0 or 1)

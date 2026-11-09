-- Syntax check every addon Lua file (compile only, don't run).
local root = arg[1]
-- every .lua file the game loads, in Tactara.toc order
local files = {}
for line in io.open(root .. "/Tactara.toc"):read("a"):gmatch("[^\r\n]+") do
  if not line:find("^##") and line:find("%.lua$") then files[#files + 1] = (line:gsub("\\", "/")) end
end
local bad = 0
-- the addon-list icon named in Tactara.toc must exist and be a 32-bit TGA with power-of-two sides
do
  local toc = io.open(root .. "/Tactara.toc"):read("a")
  local icon = toc:match("## IconTexture:%s*Interface\\AddOns\\Tactara\\([^\r\n]+)")
  if not icon then print("FAIL no IconTexture in Tactara.toc"); bad = bad + 1
  else
    local f = io.open(root .. "/" .. icon:gsub("\\", "/") .. ".tga", "rb")
    if not f then print("FAIL icon file missing: " .. icon .. ".tga"); bad = bad + 1
    else
      local h = f:read(18); f:close()
      local w, ht = h:byte(13) + 256 * h:byte(14), h:byte(15) + 256 * h:byte(16)
      local pow2 = function(n) return n > 0 and (n & (n - 1)) == 0 end
      if h:byte(3) ~= 2 or h:byte(17) ~= 32 or not pow2(w) or not pow2(ht) then
        print(("FAIL icon must be an uncompressed 32-bit TGA with power-of-two sides (%dx%d)"):format(w, ht)); bad = bad + 1
      else print(("ok   icon %s.tga %dx%d"):format(icon, w, ht)) end
    end
  end
end
if #files < 13 then print("FAIL only " .. #files .. " files listed in Tactara.toc"); bad = bad + 1 end
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
-- version must match in Tactara.toc and Core.lua
local toc = io.open(root .. "/Tactara.toc"):read("a")
local core = io.open(root .. "/Core.lua"):read("a")
local tv = toc:match("## Version:%s*([%d%.]+)")
local cv = core:match('ns.VERSION = "([%d%.]+)"')
if tv and tv == cv then print("ok   version " .. tv .. " (toc + Core.lua)") else print("FAIL version mismatch: toc " .. tostring(tv) .. ", Core.lua " .. tostring(cv)); bad = bad + 1 end
os.exit(bad == 0 and 0 or 1)

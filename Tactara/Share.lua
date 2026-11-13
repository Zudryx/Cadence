-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: your settings as text, to back them up or give them to a friend.
--
-- /tac export shows this character's settings (the same ones "Copy settings
-- from..." copies: keys, display positions and sizes, the glow, suggestions,
-- minimap button, reminders and talent options) as plain text. /tac import
-- takes text like that and, after asking, puts it on this character. Keys
-- only come along if you choose "With keys".
--
-- The text is read line by line; it's never run as code.

local ADDON, ns = ...

local S = {}
ns.Share = S

local HEADER = "Tactara settings 1"
local MAX_LINES = 400

local function Esc(s) return (s:gsub("\\", "\\\\"):gsub("\n", "\\n")) end
local function Unesc(s)
  return (s:gsub("\\(.)", function(c) return c == "n" and "\n" or c end))
end

local function SafeKey(k)
  if type(k) == "number" then return "#" .. k end
  if type(k) == "string" and k ~= "" and not k:find("[%.=#\n\\]") then return k end
  return nil
end

local function Walk(path, v, out)
  local t = type(v)
  if t == "table" then
    local keys = {}
    for k in pairs(v) do if SafeKey(k) then keys[#keys + 1] = k end end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do Walk(path .. "." .. SafeKey(k), v[k], out) end
  elseif t == "boolean" then
    out[#out + 1] = path .. "=b:" .. (v and "1" or "0")
  elseif t == "number" then
    out[#out + 1] = path .. "=n:" .. string.format("%.10g", v)
  elseif t == "string" then
    out[#out + 1] = path .. "=s:" .. Esc(v)
  end
end

function S.Export(settings)
  settings = settings or ns.Profiles.Snapshot()
  local out = { ("%s (Tactara %s)"):format(HEADER, ns.VERSION) }
  for _, k in ipairs(ns.Profiles.KEYS) do
    if settings[k] ~= nil then Walk(k, settings[k], out) end
  end
  out[#out + 1] = "end"
  return table.concat(out, "\n")
end

local ALLOWED = {}
for _, k in ipairs(ns.Profiles.KEYS) do ALLOWED[k] = true end

-- Returns settings, count or nil, reason. Only Tactara's own setting names
-- are taken; anything else in the text is skipped.
function S.Parse(text)
  if type(text) ~= "string" then return nil, "There's no text." end
  local lines = {}
  for line in (text:gsub("\r", "") .. "\n"):gmatch("([^\n]*)\n") do
    line = line:gsub("^%s+", ""):gsub("%s+$", "")
    if line ~= "" then lines[#lines + 1] = line end
  end
  if not (lines[1] and lines[1]:find("^" .. HEADER)) then
    return nil, "That isn't Tactara settings text (it should start with \"" .. HEADER .. "\")."
  end
  if lines[#lines] ~= "end" then return nil, "The text looks cut off (the last line should be \"end\"). Copy all of it." end
  if #lines > MAX_LINES then return nil, "That's more text than Tactara settings ever are." end
  local settings, count = {}, 0
  for i = 2, #lines - 1 do
    local path, kind, value = lines[i]:match("^([^=]+)=([bns]):(.*)$")
    if path then
      local parts = {}
      for part in path:gmatch("[^%.]+") do
        parts[#parts + 1] = part:match("^#(%d+)$") and tonumber(part:sub(2)) or part
      end
      local v
      if kind == "b" then v = (value == "1")
      elseif kind == "n" then v = tonumber(value)
      else v = Unesc(value) end
      if v ~= nil and ALLOWED[parts[1]] then
        local t = settings
        for j = 1, #parts - 1 do
          local p = parts[j]
          if type(t[p]) ~= "table" then t[p] = {} end
          t = t[p]
        end
        t[parts[#parts]] = v
        count = count + 1
      end
    end
  end
  if count == 0 then return nil, "There are no Tactara settings in that text." end
  return settings, count
end

local function KeyList(binds)
  local list = {}
  for _, which in ipairs({ "main", "aoe", "interrupt" }) do
    if type(binds) == "table" and type(binds[which]) == "string" then list[#list + 1] = binds[which] end
  end
  return list
end

-- Puts imported settings on this character. withKeys: also its keys.
function S.Apply(settings, withKeys)
  local copy = {}
  for k, v in pairs(settings) do
    -- a setting of a different kind than this character's (a number where
    -- a yes/no goes) is left out
    local now = TactaraCharDB[k]
    if now == nil or type(now) == type(v) then copy[k] = v end
  end
  if not withKeys then copy.binds = nil end
  ns.Profiles.Apply(copy)
  ns.Profiles.Save()
  ns.Print("Imported Tactara settings" .. (withKeys and ", keys included." or ". Your keys stayed as they were."))
end

function S.ShowExport()
  ns.ShowCopyText("Tactara settings", S.Export(), {
    hint = "Ctrl+C to copy. Paste it with /tac import on another character, account or computer.",
  })
end

function S.ShowImport()
  if InCombatLockdown() then ns.Print("Import settings out of combat.") return end
  ns.ShowCopyText("Import Tactara settings", "", {
    editable = true, button = "Import",
    hint = "Paste settings text here (Ctrl+V), then click Import.",
    onAccept = function(text)
      local settings, info = S.Parse(text)
      if not settings then
        ns.Print(info)
        return false
      end
      S.Confirm(settings)
      return true
    end,
  })
end

function S.Confirm(settings)
  local keys = KeyList(settings.binds)
  local text = "Put these Tactara settings on this character?\n\nDisplay positions and sizes, the glow, suggestions, minimap button, reminders and talent options change. Rotation and talent builds stay as they are."
  if #keys > 0 then
    text = text .. ("\n\nThe text also has keys (%s). |cffffd100With keys|r sets them here too."):format(table.concat(keys, ", "))
  end
  if not (StaticPopupDialogs and StaticPopup_Show) then S.Apply(settings, false) return end
  StaticPopupDialogs.TACTARA_IMPORT = {
    text = "%s", button1 = "Import", button2 = "Cancel", button3 = (#keys > 0) and "With keys" or nil,
    OnAccept = function() S.Apply(settings, false) end,
    OnAlt = function() S.Apply(settings, true) end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
  StaticPopup_Show("TACTARA_IMPORT", text)
end

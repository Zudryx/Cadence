-- Tactara: settings page in Esc > Options > AddOns > Tactara.
--
-- Everything here can also be done with /tac commands; this page just puts
-- it in one place. Values live in TactaraDB (account) and TactaraCharDB
-- (this character), the same tables the commands use, so both always agree.
--
-- Uses the game's Settings API. If this client doesn't have the parts we
-- need, the page shows the /tac commands instead, so it never breaks the
-- options window.

local ADDON, ns = ...

local Options = {}
ns.Options = Options

local category
local registered = false
local keyRows = {}   -- which -> { init = initializer, frame = row frame on screen }

-- What a key button says: the key it's set to, or how to set one.
local function KeyButtonText(which)
  local label = ns.KeyLabel(which)
  if not label or label == "none" then return "Not set (click)" end
  return label
end

-- Update the key buttons after a key changes, including while the page is open.
function Options.OnKeysChanged()
  for which, row in pairs(keyRows) do
    local text = KeyButtonText(which)
    if row.init.data then row.init.data.buttonText = text end
    local f = row.frame
    -- the list reuses row frames, so only touch one that still shows this row
    if f and f.Button and f.Button.SetText and f.GetElementData then
      local ok, data = pcall(f.GetElementData, f)
      if ok and data == row.init then f.Button:SetText(text) end
    end
  end
end

local function VarType(kind)
  local vt = Settings and Settings.VarType
  if kind == "boolean" then return vt and vt.Boolean or "boolean" end
  if kind == "number" then return vt and vt.Number or "number" end
  return vt and vt.String or "string"
end

local function OnChange(setting, variable, fn)
  if not fn then return end
  local cb = function(_, value) fn(value) end
  if setting and setting.SetValueChangedCallback then
    setting:SetValueChangedCallback(cb)
  elseif Settings.SetOnValueChangedCallback then
    Settings.SetOnValueChangedCallback(variable, cb)
  end
end

local function Refresh()
  ns.HelperRefresh()
  if ns.Editor and ns.Editor.OnRebuilt then ns.Editor.OnRebuilt() end
end

---------------------------------------------------------------------------
-- Display size
---------------------------------------------------------------------------

-- Keep a display where it is on screen while its size changes.
local function ScaleFrame(f, key, scale)
  if not f then return end
  scale = tonumber(scale) or 1
  local old = f:GetScale() or 1
  if math.abs(old - scale) < 0.001 then return end
  local point, _, relPoint, x, y = f:GetPoint(1)
  f:SetScale(scale)
  if point then
    f:ClearAllPoints()
    x, y = (x or 0) * old / scale, (y or 0) * old / scale
    f:SetPoint(point, UIParent, relPoint, x, y)
    TactaraCharDB[key] = { point = point, relPoint = relPoint, x = x, y = y }
  end
end

function ns.ApplyDisplayScales()
  ScaleFrame(ns.display, "display", TactaraCharDB.displayScale)
  ScaleFrame(ns.helperPopup, "helperPos", TactaraCharDB.helperScale)
end

function ns.ResetDisplayPositions()
  TactaraCharDB.display, TactaraCharDB.helperPos = {}, nil
  TactaraCharDB.displayScale, TactaraCharDB.helperScale = 1, 1
  for _, f in ipairs({ ns.display, ns.helperPopup }) do
    if f then f:SetScale(1) f:ClearAllPoints() end
  end
  if ns.display then ns.display:SetPoint("CENTER", UIParent, "CENTER", 0, -180) end
  if ns.helperPopup then ns.helperPopup:SetPoint("CENTER", UIParent, "CENTER", 0, -110) end
  Refresh()
  ns.Print("Displays moved back to the middle of the screen at normal size.")
end

---------------------------------------------------------------------------
-- Build the page with the Settings API
---------------------------------------------------------------------------

local function BuildVertical()
  local cat, layout = Settings.RegisterVerticalLayoutCategory("Tactara")
  local CreateCheckbox = Settings.CreateCheckbox or Settings.CreateCheckBox
  local CreateDropdown = Settings.CreateDropdown or Settings.CreateDropDown
  assert(cat and layout and CreateCheckbox and CreateDropdown and Settings.CreateSlider, "settings API incomplete")

  local function Header(text)
    if CreateSettingsListSectionHeaderInitializer then
      layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end
  end

  local function Check(tbl, key, label, tooltip, default, fn)
    local variable = "Tactara_" .. key
    local s = Settings.RegisterAddOnSetting(cat, variable, key, tbl, VarType("boolean"), label, default)
    CreateCheckbox(cat, s, tooltip)
    OnChange(s, variable, fn)
    return s
  end

  local function Proxy(key, kind, label, default, get, set)
    return Settings.RegisterProxySetting(cat, "Tactara_" .. key, VarType(kind), label, default, get, set)
  end

  local function Choices(list)
    return function()
      local c = Settings.CreateControlTextContainer()
      for _, item in ipairs(type(list) == "function" and list() or list) do c:Add(item[1], item[2], item[3]) end
      return c:GetData()
    end
  end

  local function Dropdown(tbl, key, label, tooltip, default, list, fn, kind)
    local variable = "Tactara_" .. key
    local s = Settings.RegisterAddOnSetting(cat, variable, key, tbl, VarType(kind or "string"), label, default)
    CreateDropdown(cat, s, Choices(list), tooltip)
    OnChange(s, variable, fn)
    return s
  end

  -- A slider that shows its value as a percentage.
  local function PercentSlider(key, label, tooltip, default, min, max, fn)
    local variable = "Tactara_" .. key
    local s = Settings.RegisterAddOnSetting(cat, variable, key, TactaraCharDB, VarType("number"), label, default)
    local opts = Settings.CreateSliderOptions(min, max, 0.05)
    if opts.SetLabelFormatter and MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
      opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v)
        return ("%d%%"):format(math.floor(v * 100 + 0.5))
      end)
    end
    Settings.CreateSlider(cat, s, opts, tooltip)
    OnChange(s, variable, fn)
  end

  local function SizeSlider(key, label, tooltip)
    PercentSlider(key, label, tooltip, 1, 0.5, 2, function() ns.ApplyDisplayScales() end)
  end

  local function Button(label, text, tooltip, fn)
    if CreateSettingsButtonInitializer then
      layout:AddInitializer(CreateSettingsButtonInitializer(label, text, fn, tooltip, true))
    end
  end

  -- A key row: the button shows the key it's set to; click it to pick another.
  local function KeyRow(which, label, tooltip)
    if not CreateSettingsButtonInitializer then return end
    local init = CreateSettingsButtonInitializer(label, KeyButtonText(which),
      function() ns.StartKeyCapture(which) end, tooltip, true)
    local row = { init = init }
    keyRows[which] = row
    local initFrame = init.InitFrame
    if type(initFrame) == "function" then
      init.InitFrame = function(self, frame, ...)
        if self.data then self.data.buttonText = KeyButtonText(which) end
        initFrame(self, frame, ...)
        row.frame = frame
      end
    end
    layout:AddInitializer(init)
  end

  -- Rotation ---------------------------------------------------------------
  Header("Rotation")
  local rotation = Proxy("active", "string", "Rotation", "auto",
    function() return TactaraCharDB.active or "auto" end,
    function(v)
      TactaraCharDB.active = v
      ns.RequestRebuild("settings", 0.05)
    end)
  CreateDropdown(cat, rotation, Choices(function()
    local out = { { "auto", "Automatic (follow my talents)", "Picks from your talents, then your weapon." } }
    for _, r in ipairs(ns.ListRotations(ns.GetClassToken())) do
      out[#out + 1] = { r.name, r.name .. (r.edited and " (edited)" or (r.builtin and "" or " (yours)")) }
    end
    return out
  end), "Which rotation the key and the helper use. Automatic follows your talents and changes as you level.")
  Button("Rotation editor", "Open", "See, edit or write rotations (/tac).", function()
    if SettingsPanel and SettingsPanel.Hide then pcall(SettingsPanel.Hide, SettingsPanel) end
    ns.Editor.Show()
  end)

  -- Keys -------------------------------------------------------------------
  Header("Keys")
  local HOW = "\n\nClick, then press any key (even one on your action bar). Tactara takes it over while it's loaded; your keybinds aren't changed."
  KeyRow("main", "One-button key", "The key that plays your rotation, one step per press." .. HOW)
  KeyRow("aoe", "AoE key", "A second key that plays the AoE version of your rotation." .. HOW)
  KeyRow("interrupt", "Interrupt key", "Casts the best interrupt you have." .. HOW)
  Button("Give keys back", "Remove", "Removes all Tactara keys. Each key goes back to what it did before.",
    function() ns.Unbind("all") end)
  Check(TactaraDB, "hideErrors", "Hide \"not ready\" errors", "Hides the red error text (\"Not enough rage\", \"Ability not ready\") while you press Tactara keys. Normal key presses still show them.", true)
  local keyDown = Proxy("keyDown", "boolean", "Cast when the key goes down", true,
    function() return TactaraCharDB.keyDown ~= false end,
    function(v)
      if v then TactaraCharDB.keyDown = nil else TactaraCharDB.keyDown = false end
      ns.SyncKeyDown()
    end)
  CreateCheckbox(cat, keyDown, "Leave this on. Only turn it off if your game is set to cast on key release and the key doesn't cast.")

  -- Displays ---------------------------------------------------------------
  Header("Displays")
  Check(TactaraCharDB, "showHelper", "Show the helper popup", "The best spell to use right now, plus interrupt and defensive suggestions.", true, Refresh)
  SizeSlider("helperScale", "Helper popup size", "Makes the helper popup bigger or smaller.")
  local function CountChoices(allLabel, allTip)
    local list = {}
    for i = 1, 10 do
      list[#list + 1] = { i, i == 1 and "1 (just the next one)" or i == 3 and "3 (default)" or tostring(i) }
    end
    list[#list + 1] = { 0, allLabel, allTip }
    return list
  end
  Dropdown(TactaraCharDB, "helperIcons", "Helper popup icons", "How many spells the helper popup shows: the best one now, then the next best.", 3,
    CountChoices("Everything usable now", "Every spell in the rotation you can use right now, best first."), Refresh, "number")
  Check(TactaraCharDB, "helperCooldowns", "Cooldowns on helper icons", "A clock sweep over helper icons that are on cooldown, so you can see when they'll be ready.", true, Refresh)
  Check(TactaraCharDB, "helperTint", "Color helper icons", "Red when the target is out of range, blue when you're short on mana, rage or energy, grey when the spell can't be used right now.", true, Refresh)
  Check(TactaraCharDB, "showDisplay", "Show the key bar", "What your Tactara key will cast on its next presses.", true, Refresh)
  SizeSlider("displayScale", "Key bar size", "Makes the key bar bigger or smaller.")
  Dropdown(TactaraCharDB, "keyIcons", "Key bar icons", "How many of your key's next presses the key bar shows.", 3,
    CountChoices("Whole rotation", "Every step until the rotation repeats."), Refresh, "number")
  local IDLE_CHOICES = {
    { "show", "Show normally" },
    { "fade", "See-through" },
    { "hide", "Hide" },
  }
  local IDLE_TIP = " \"Not fighting\" means out of combat with no enemy targeted; target an enemy and it's back. While the displays are unlocked, Hide shows them see-through instead so you can still move them."
  Dropdown(TactaraCharDB, "helperIdle", "Helper popup when not fighting", "How the helper popup looks between fights." .. IDLE_TIP, "fade", IDLE_CHOICES, Refresh)
  Dropdown(TactaraCharDB, "keyIdle", "Key bar when not fighting", "How the key bar looks between fights." .. IDLE_TIP, "show", IDLE_CHOICES, Refresh)
  PercentSlider("fadeAlpha", "See-through amount", "How visible a see-through display is: lower is fainter.", 0.45, 0.1, 0.9, Refresh)
  Check(TactaraCharDB, "locked", "Lock positions", "Turn off to drag the displays where you want them.", false, Refresh)
  Button("Positions", "Reset", "Moves both displays back to the middle of the screen at normal size.", ns.ResetDisplayPositions)

  -- Bar highlight ----------------------------------------------------------
  Header("Bar highlight")
  Check(TactaraCharDB, "highlight", "Highlight spells on my action bars", "A glowing border on the spell to press next. Works with Blizzard's bars and most bar addons.", true, Refresh)
  Dropdown(TactaraDB, "glowStyle", "Glow strength", "How loud the glow is.", "strong", {
    { "strong", "Strong", "Thick border, halo and a tinted icon." },
    { "normal", "Normal" },
    { "subtle", "Subtle" },
  }, function(v) ns.SetGlowStyle(v) end)
  Button("Preview the glow", "Preview", "Shows the next-spell, interrupt and defensive glows on your bars for 3 seconds.", function() ns.PreviewGlow() end)
  Dropdown(TactaraCharDB, "helperMode", "Helper follows", "What the helper and the glow show.", "auto", {
    { "auto", "Automatic", "The best spell right now, or the key's next step while you're pressing the key." },
    { "priority", "Best spell right now" },
    { "sequence", "The key's next step" },
  }, Refresh)

  -- Suggestions ------------------------------------------------------------
  Header("Suggestions")
  Check(TactaraCharDB, "interrupts", "Suggest interrupts", "A red slot when your target is casting something you can stop.", true, Refresh)
  Check(TactaraCharDB, "defensives", "Suggest defensives", "An orange slot when you're low on health and a defensive or self-heal is ready.", true, Refresh)

  Settings.RegisterAddOnCategory(cat)
  return cat
end

-- If the Settings API is missing pieces, show a plain page with the commands.
local COMMANDS = {
  "/tac  - rotation editor and keys",
  "/tac bind  - pick your one-button key",
  "/tac show | hide [key|helper]  - the two displays",
  "/tac lock | unlock  - drag the displays",
  "/tac icons helper|key 1-10 | all  - how many icons",
  "/tac fade helper|key show|fade|hide  - between fights",
  "/tac fade 40  - how visible see-through is",
  "/tac highlight  - bar glow on/off",
  "/tac glow strong | normal | subtle | test",
  "/tac helper auto | priority | sequence",
  "/tac interrupts | defensives  - suggestions on/off",
  "/tac use <name> | auto  - pick a rotation",
  "/tac help  - every command",
}

local function BuildCanvas()
  local f = CreateFrame("Frame")
  f.name = "Tactara"
  local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Tactara " .. ns.VERSION)
  local body = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
  body:SetJustifyH("LEFT")
  body:SetText("This game version can't show Tactara's settings here yet. These commands do the same:\n\n"
    .. table.concat(COMMANDS, "\n"))
  local cat = Settings.RegisterCanvasLayoutCategory(f, "Tactara")
  Settings.RegisterAddOnCategory(cat)
  return cat
end

function Options.Register()
  if registered or not Settings then return end
  registered = true
  local ok, cat = pcall(BuildVertical)
  if not ok then
    ns.Debug("settings page: " .. tostring(cat))
    ok, cat = pcall(BuildCanvas)
  end
  if ok then category = cat end
end

-- Keys set in WoW's own Keybindings menu show up here too.
local watcher = CreateFrame("Frame")
pcall(watcher.RegisterEvent, watcher, "UPDATE_BINDINGS")
watcher:SetScript("OnEvent", function() Options.OnKeysChanged() end)

function Options.Open()
  if not category then
    ns.Print("The settings page isn't available in this game version. /tac help lists every command.")
    return
  end
  local id = category.GetID and category:GetID() or category
  if not pcall(Settings.OpenToCategory, id) then
    ns.Print("Find Tactara under Esc > Options > AddOns.")
  end
end

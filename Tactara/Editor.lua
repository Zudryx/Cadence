-- Tactara: in-game rotation editor (/tac)
-- Left: rotations for your class. Right: the rotation text.
-- Import = click New, paste, Save. Export = Select All, Ctrl+C.

local ADDON, ns = ...

local Editor = {}
ns.Editor = Editor

local frame, editBox, scrollFrame, header, status, listTitle
local listItems = {}
local buttons = {}
local selectedName   -- rotation currently loaded in the editor (nil = new / unsaved)
local dirty = false
local deleteArmed = false
local statusTimer = false

local MAX_LIST = 10

local HELP_LINES = {
  "Rotation format",
  "name: My Rotation    class: WARRIOR",
  "detect: Mortal Strike   (auto-pick when you know this spell)",
  " ",
  "[keypress]  lines added to every press (stance, /startattack)",
  "[opener]  steps played once at the start of each fight",
  "[loop]  steps repeated for the rest of the fight",
  "[aoe]  steps for the AoE button (optional)",
  "[priority]  rotation helper: best ready spell first",
  "[interrupt] / [defensive]  helper suggestions (red / orange)",
  " ",
  "3x /cast Spell   = this step comes up 3 times per loop",
  "Indented /cast lines = fallbacks inside the same step",
  "  (tried when the line above can't be cast)",
  "@ifmissing Buff   only cast if that buff is missing",
  "@if Spell / @unless Spell   only if you do / don't know a spell",
  "@missing Buff  @nodebuff Debuff  @enemies 3  @health 35  (live checks)",
  "@creature Undead, Demon  @nopet  @combo 4  (live checks)",
  "tree: Arms   weapon: two-hand / dual / shield   (auto-pick)",
  "prefer: Talent, Talent   (pick between rotations on the same tree)",
  "# comment",
  " ",
  "Spells you haven't learned are skipped automatically.",
}

local function SafeFrame(ftype, name, parent, template)
  if template then
    local ok, f = pcall(CreateFrame, ftype, name, parent, template)
    if ok and f then return f, true end
  end
  return CreateFrame(ftype, name, parent), false
end

local function MakeButton(parent, text, width)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width or 90, 22)
  b:SetText(text)
  return b
end

local function NewTemplate()
  local class = ns.GetClassToken() or "ANY"
  return table.concat({
    "name: My Rotation",
    "class: " .. class,
    "# detect: Some Talent Spell",
    "",
    "[keypress]",
    "/startattack [harm,nodead]",
    "",
    "[opener]",
    "/cast First Spell",
    "",
    "[loop]",
    "2x /cast Main Spell",
    "    /cast Fallback Spell",
    "1x /cast Other Spell",
    "",
    "# Or delete all of this and paste a rotation someone shared, then click Save.",
  }, "\n")
end

---------------------------------------------------------------------------
-- Status line (live check of the text being edited)
---------------------------------------------------------------------------

local function UpdateStatus()
  if not frame or not frame:IsShown() then return end
  local text = editBox:GetText()
  local rot = ns.Parse(text)
  if not rot then
    status:SetText("|cffff5555Nothing to read.|r")
    return
  end
  local env = ns.MakeEnv()
  local main = ns.Compile(rot, "main", env)
  local aoe = ns.Compile(rot, "aoe", env)
  local parts = {}
  if not rot.name then parts[#parts + 1] = "|cffff5555Needs a 'name:' line.|r" end
  local cls = rot.meta.class
  local mine = ns.GetClassToken()
  if cls and cls ~= "ANY" and mine and cls ~= mine then
    parts[#parts + 1] = ("|cffffaa00For %s, not your class.|r"):format(cls)
  end
  parts[#parts + 1] = ("At your level: main %d opener + %d loop steps, AoE %d + %d%s.")
    :format(main.openerCount, main.loopCount, aoe.openerCount, aoe.loopCount,
      aoe.aoeFallback and " (copies [loop])" or "")
  local warns = {}
  for _, w in ipairs(rot.warnings) do warns[#warns + 1] = w end
  for _, w in ipairs(main.warnings) do warns[#warns + 1] = w end
  if #warns > 0 then
    parts[#parts + 1] = "|cffffaa00" .. warns[1] .. (#warns > 1 and (" (+" .. (#warns - 1) .. " more)") or "") .. "|r"
  end
  if dirty then parts[#parts + 1] = "|cffffd100Unsaved changes.|r" end
  status:SetText(table.concat(parts, "  "))
end

local function QueueStatus()
  if statusTimer then return end
  statusTimer = true
  C_Timer.After(0.3, function()
    statusTimer = false
    UpdateStatus()
  end)
end

---------------------------------------------------------------------------
-- List + selection
---------------------------------------------------------------------------

local function UpdateHeader()
  local label
  if not selectedName then
    label = "New rotation (not saved yet)"
  else
    local tag = ""
    if ns.IsEdited(selectedName) then tag = "  |cffaaaaaa[built-in, edited]|r"
    elseif ns.IsBuiltin(selectedName) then tag = "  |cffaaaaaa[built-in]|r"
    else tag = "  |cffaaaaaa[yours]|r" end
    if selectedName == ns.activeName then tag = tag .. "  |cff00ff00ACTIVE|r" end
    label = selectedName .. tag
  end
  header:SetText(label)

  deleteArmed = false
  if selectedName and ns.IsBuiltin(selectedName) then
    buttons.delete:SetText("Revert")
    if ns.IsEdited(selectedName) then buttons.delete:Enable() else buttons.delete:Disable() end
  else
    buttons.delete:SetText("Delete")
    if selectedName then buttons.delete:Enable() else buttons.delete:Disable() end
  end
  if selectedName then buttons.use:Enable() else buttons.use:Disable() end
  local auto = TactaraCharDB.active == "auto"
  buttons.auto:SetText(auto and "Auto-pick: ON" or "Auto-pick: OFF")
  buttons.highlight:SetText("Bar highlight: " .. (TactaraCharDB.highlight and "ON" or "OFF"))
  buttons.keyMain:SetText("Main key: " .. ns.KeyLabel("main"))
  buttons.keyAoE:SetText("AoE key: " .. ns.KeyLabel("aoe"))
  buttons.keyInt:SetText("Interrupt key: " .. ns.KeyLabel("interrupt"))
end

local function RefreshList()
  local class = ns.GetClassToken()
  local list = ns.ListRotations(class)
  listTitle:SetText("Rotations (" .. (class or "?") .. ")")
  for i = 1, MAX_LIST do
    local item = listItems[i]
    local r = list[i]
    if r then
      local label = r.name
      if r.edited then label = label .. " *" end
      if not r.builtin then label = label .. " |cff88ccff(yours)|r" end
      if r.name == ns.activeName then label = "|cff00ff00>|r " .. label end
      item.text:SetText(label)
      item.name = r.name
      if r.name == selectedName then item.sel:Show() else item.sel:Hide() end
      item:Show()
    else
      item.name = nil
      item:Hide()
    end
  end
end

function Editor.Select(name)
  if dirty and name ~= selectedName then
    ns.Print("Unsaved changes in the editor were discarded.")
  end
  selectedName = name
  editBox:SetText(ns.GetRotationText(name) or "")
  editBox:SetCursorPosition(0)
  dirty = false
  RefreshList()
  UpdateHeader()
  UpdateStatus()
end

---------------------------------------------------------------------------
-- Button actions
---------------------------------------------------------------------------

local function DoNew()
  selectedName = nil
  editBox:SetText(NewTemplate())
  editBox:SetFocus()
  dirty = true
  RefreshList()
  UpdateHeader()
  UpdateStatus()
end

local function DoSave()
  local ok, res = ns.SaveRotation(editBox:GetText())
  if not ok then
    status:SetText("|cffff5555" .. tostring(res) .. "|r")
    return
  end
  selectedName = res
  dirty = false
  ns.Print("Saved '" .. res .. "'.")
  ns.RequestRebuild("editor save", 0.05)
  RefreshList()
  UpdateHeader()
  UpdateStatus()
end

local function DoUse()
  if not selectedName then return end
  if dirty then DoSave() end
  TactaraCharDB.active = selectedName
  ns.RequestRebuild("editor use", 0.05)
end

local function DoAuto()
  if TactaraCharDB.active == "auto" then
    TactaraCharDB.active = ns.activeName or "auto"
  else
    TactaraCharDB.active = "auto"
  end
  ns.RequestRebuild("editor auto", 0.05)
  UpdateHeader()
end

local function DoDelete()
  if not selectedName then return end
  if not deleteArmed then
    deleteArmed = true
    buttons.delete:SetText("Sure?")
    return
  end
  local name = selectedName
  local wasBuiltin = ns.IsBuiltin(name)
  ns.DeleteRotation(name)
  ns.Print((wasBuiltin and "Reverted '" or "Deleted '") .. name .. "'.")
  ns.RequestRebuild("editor delete", 0.05)
  if wasBuiltin then
    Editor.Select(name)
  else
    Editor.Select(ns.activeName)
  end
end

local function DoSelectAll()
  editBox:SetFocus()
  editBox:HighlightText()
  status:SetText("Text selected. Press Ctrl+C to copy it, then paste it anywhere to share.")
end

local function DoPreview()
  local rot = ns.Parse(editBox:GetText())
  if not rot then return end
  local env = ns.MakeEnv()
  local saved = ns.activeName
  ns.activeName = (rot.name or "unsaved") .. " (preview)"
  ns.PrintSequence(ns.Compile(rot, "main", env), "Main button")
  ns.PrintSequence(ns.Compile(rot, "aoe", env), "AoE button", true)
  ns.activeName = saved
end

---------------------------------------------------------------------------
-- Build the window
---------------------------------------------------------------------------

local function Build()
  local templated
  frame, templated = SafeFrame("Frame", "TactaraEditor", UIParent, "BasicFrameTemplateWithInset")
  if not templated then
    frame:Hide()
    frame = nil
    frame = SafeFrame("Frame", "TactaraEditorPlain", UIParent, "BackdropTemplate")
    if frame.SetBackdrop then
      frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
      })
    end
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
  end
  frame:SetSize(780, 500)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetScript("OnShow", function() Editor.OnShow() end)
  table.insert(UISpecialFrames, frame:GetName())

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", frame, "TOP", 0, -6)
  title:SetText("Tactara " .. ns.VERSION .. " - one-button rotations")

  -- left: rotation list
  listTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  listTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -34)
  for i = 1, MAX_LIST do
    local item = CreateFrame("Button", nil, frame)
    item:SetSize(176, 18)
    item:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -52 - (i - 1) * 19)
    item.sel = item:CreateTexture(nil, "BACKGROUND")
    item.sel:SetAllPoints()
    item.sel:SetColorTexture(1, 0.82, 0, 0.18)
    item.sel:Hide()
    item.hl = item:CreateTexture(nil, "HIGHLIGHT")
    item.hl:SetAllPoints()
    item.hl:SetColorTexture(1, 1, 1, 0.08)
    item.text = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    item.text:SetPoint("LEFT", 4, 0)
    item.text:SetPoint("RIGHT", -2, 0)
    item.text:SetJustifyH("LEFT")
    item:SetScript("OnClick", function(self) if self.name then Editor.Select(self.name) end end)
    listItems[i] = item
  end

  local function KeyButton(which, y)
    local b = MakeButton(frame, "", 176)
    b:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, y)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(_, mouse)
      if mouse == "RightButton" then ns.Unbind(which) else ns.StartKeyCapture(which) end
    end)
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(({ aoe = "AoE rotation key", interrupt = "Interrupt key (best interrupt for your stance and gear)" })[which] or "Main rotation key")
      GameTooltip:AddLine("Left-click, then press any key (even one on your action bar).", 1, 1, 1, true)
      GameTooltip:AddLine("Your normal keybinds aren't changed. Right-click gives the key back.", 1, 1, 1, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
  end
  buttons.highlight = MakeButton(frame, "Bar highlight", 176)
  buttons.highlight:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 144)
  buttons.highlight:SetScript("OnClick", function() ns.HandleSlash("highlight") end)
  buttons.highlight:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Bar highlight")
    GameTooltip:AddLine("A pulsing blue border on the next spell on your action bars.", 1, 1, 1, true)
    GameTooltip:AddLine("Use it with the Tactara key, or on its own as a rotation helper: press the glowing spell and Tactara moves to the next one.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  buttons.highlight:SetScript("OnLeave", function() GameTooltip:Hide() end)
  buttons.keyMain = KeyButton("main", 118)
  buttons.keyAoE = KeyButton("aoe", 92)
  buttons.keyInt = KeyButton("interrupt", 66)

  buttons.new = MakeButton(frame, "New / Import", 176)
  buttons.new:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 40)
  buttons.new:SetScript("OnClick", DoNew)

  buttons.auto = MakeButton(frame, "Auto-pick", 176)
  buttons.auto:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 14)
  buttons.auto:SetScript("OnClick", DoAuto)
  buttons.auto:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Auto-pick")
    GameTooltip:AddLine("ON: Tactara switches rotation based on the talents you have (detect: line).", 1, 1, 1, true)
    GameTooltip:AddLine("OFF: it keeps using the one you chose with Use This.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  buttons.auto:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- right: header, text box, status, buttons
  header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  header:SetPoint("TOPLEFT", frame, "TOPLEFT", 206, -34)
  header:SetPoint("RIGHT", frame, "RIGHT", -40, 0)
  header:SetJustifyH("LEFT")

  local help = MakeButton(frame, "?", 24)
  help:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -30)

  buttons.settings = MakeButton(frame, "Settings", 80)
  buttons.settings:SetPoint("RIGHT", help, "LEFT", -6, 0)
  buttons.settings:SetScript("OnClick", function()
    frame:Hide()
    ns.Options.Open()
  end)
  buttons.settings:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Settings")
    GameTooltip:AddLine("Displays, sizes, the bar glow, suggestions and keys, all on one page (Esc > Options > AddOns > Tactara).", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  buttons.settings:SetScript("OnLeave", function() GameTooltip:Hide() end)
  help:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    for i, l in ipairs(HELP_LINES) do
      if i == 1 then GameTooltip:AddLine(l) else GameTooltip:AddLine(l, 1, 1, 1) end
    end
    GameTooltip:Show()
  end)
  help:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local box = frame:CreateTexture(nil, "BACKGROUND")
  box:SetPoint("TOPLEFT", frame, "TOPLEFT", 200, -54)
  box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 72)
  box:SetColorTexture(0, 0, 0, 0.45)

  local okScroll
  okScroll, scrollFrame = pcall(CreateFrame, "ScrollFrame", "TactaraEditorScroll", frame, "UIPanelScrollFrameTemplate")
  if not okScroll or not scrollFrame then
    scrollFrame = CreateFrame("ScrollFrame", "TactaraEditorScroll", frame)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
      local cur, max = self:GetVerticalScroll(), self:GetVerticalScrollRange()
      self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 40)))
    end)
  end
  scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 206, -58)
  scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -34, 76)

  editBox = CreateFrame("EditBox", "TactaraEditorText", scrollFrame)
  editBox:SetMultiLine(true)
  editBox:SetAutoFocus(false)
  editBox:SetFontObject(ChatFontNormal)
  editBox:SetWidth(530)
  editBox:SetHeight(360)
  editBox:SetMaxLetters(0)
  editBox:SetTextInsets(2, 2, 2, 2)
  editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  editBox:SetScript("OnTextChanged", function(self, userInput)
    if userInput then
      dirty = true
      deleteArmed = false
    end
    if ScrollingEdit_OnTextChanged then pcall(ScrollingEdit_OnTextChanged, self, scrollFrame) end
    QueueStatus()
  end)
  if ScrollingEdit_OnCursorChanged then
    editBox:SetScript("OnCursorChanged", ScrollingEdit_OnCursorChanged)
  end
  if ScrollingEdit_OnUpdate then
    editBox:SetScript("OnUpdate", function(self, elapsed) ScrollingEdit_OnUpdate(self, elapsed, scrollFrame) end)
  end
  scrollFrame:SetScrollChild(editBox)
  scrollFrame:EnableMouse(true)
  scrollFrame:SetScript("OnMouseDown", function() editBox:SetFocus() end)

  status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  status:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 206, 50)
  status:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
  status:SetJustifyH("LEFT")
  status:SetWordWrap(true)

  local row = {
    { "save", "Save", DoSave, 80 },
    { "use", "Use This", DoUse, 90 },
    { "delete", "Delete", DoDelete, 80 },
    { "selectall", "Select All", DoSelectAll, 90 },
    { "preview", "Show Steps", DoPreview, 100 },
  }
  local prev
  for _, def in ipairs(row) do
    local b = MakeButton(frame, def[2], def[4])
    if prev then
      b:SetPoint("LEFT", prev, "RIGHT", 6, 0)
    else
      b:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 206, 14)
    end
    b:SetScript("OnClick", def[3])
    buttons[def[1]] = b
    prev = b
  end
  buttons.preview:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Show Steps")
    GameTooltip:AddLine("Prints the steps this text builds at your current level to chat, without saving.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  buttons.preview:SetScript("OnLeave", function() GameTooltip:Hide() end)

  Editor.buttons = buttons
  Editor.listItems = listItems
  frame:Hide()
end

function Editor.OnShow()
  if not selectedName or not ns.GetRotationText(selectedName) then
    selectedName = ns.activeName
  end
  if not dirty then
    editBox:SetText(ns.GetRotationText(selectedName) or "")
    editBox:SetCursorPosition(0)
  end
  RefreshList()
  UpdateHeader()
  UpdateStatus()
end

function Editor.Toggle()
  if not frame then Build() end
  if frame:IsShown() then frame:Hide() else frame:Show() end
end

function Editor.Show()
  if not frame then Build() end
  frame:Show()
end

-- Called after every rebuild so the list shows the right active rotation.
function Editor.OnRebuilt()
  if frame and frame:IsShown() then
    RefreshList()
    UpdateHeader()
    UpdateStatus()
  end
end

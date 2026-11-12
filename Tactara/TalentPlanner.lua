-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: the talent planner window (/tac talents).
--
-- Left: Tactara's builds for your class and your own. Middle: your three
-- talent trees, drawn from the game, with the build's points on them.
-- Right: the build point by point, level 10 to 60.
-- Click a talent to add a point to the end of the build, right-click to take
-- its last point back. Changing a built-in build makes your own copy first.

local ADDON, ns = ...
local T = ns.Talents
local P = {}
ns.TalentPlanner = P

local ICON, GAP = 34, 10
local CELL = ICON + GAP
local QUESTION_MARK = 134400

local frame, selected, statusText
local treePanels, talentButtons, lines = {}, {}, {}
local listButtons, orderLines = {}, {}
local ui = {}
local clearArmed, deleteArmed = false, false

local function SafeFrame(ftype, name, parent, template)
  if template then
    local ok, f = pcall(CreateFrame, ftype, name, parent, template)
    if ok and f then return f, true end
  end
  return CreateFrame(ftype, name, parent), false
end

local function Button(parent, text, width)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width or 90, 22)
  b:SetText(text)
  return b
end

local function Status(msg, bad)
  if statusText then statusText:SetText((bad and "|cffff7070" or "") .. (msg or "") .. (bad and "|r" or "")) end
end

local function SpellIcon(id)
  local tex = id and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
  return tex or QUESTION_MARK
end

---------------------------------------------------------------------------
-- Changing the selected build
---------------------------------------------------------------------------

-- Built-in builds are read-only: make your own copy before changing one.
local function Editable()
  if not selected then return nil end
  if selected.builtin then
    local copy = {
      name = T.UniqueName("My " .. (selected.tree or "talent") .. " build"),
      class = selected.class or ns.GetClassToken(),
      tree = selected.tree, notes = selected.notes,
      source = "based on " .. selected.name, picks = {},
    }
    for i, p in ipairs(selected.picks) do copy.picks[i] = p end
    T.SaveCustom(copy)
    selected = T.GetBuild(copy.name)
    Status(("Made your own copy, \"%s\", to change. Tactara's build stays as it was."):format(copy.name))
  end
  return selected
end

local function Save(b)
  T.SaveCustom(b)
  selected = T.GetBuild(b.name)
  P.Refresh()
end

function P.AddPoint(node)
  local tree = P.tree
  if not (tree and selected) then return end
  local picks = {}
  for i, p in ipairs(selected.picks) do picks[i] = p end
  picks[#picks + 1] = node.name
  local sim = T.Simulate(picks, tree)
  local last = sim.steps[#picks]
  if last.err then
    Status(("Can't add %s at level %d: %s."):format(node.name, last.level, last.err), true)
    return false
  end
  local b = Editable()
  b.picks = picks
  Save(b)
  Status(("Level %d: %s %d/%d."):format(last.level, node.name, last.rank, node.max))
  return true
end

function P.RemovePoint(node)
  if not selected then return end
  local found
  for i = #selected.picks, 1, -1 do
    if selected.picks[i]:lower() == node.name:lower() then found = i break end
  end
  if not found then return false end
  local b = Editable()
  table.remove(b.picks, found)
  Save(b)
  local sim = P.tree and T.Simulate(b.picks, P.tree)
  if sim and sim.firstError then
    Status(("Took a point out of %s. Level %d no longer works: %s."):format(node.name, sim.firstError.level, sim.firstError.err), true)
  else
    Status(("Took a point out of %s."):format(node.name))
  end
  return true
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

local function TalentTooltip(btn)
  local node = btn.node
  if not (node and GameTooltip) then return end
  GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
  if node.spellID and GameTooltip.SetSpellByID then
    pcall(GameTooltip.SetSpellByID, GameTooltip, node.spellID)
  else
    GameTooltip:AddLine(node.name)
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(("Learned: %d/%d"):format(node.rank, node.max), 1, 1, 1)
  local levels = btn.levels or {}
  if #levels > 0 then
    GameTooltip:AddLine(("In this build: %d/%d, at level %s"):format(#levels, node.max, table.concat(levels, ", ")), 0.4, 0.8, 1)
  else
    GameTooltip:AddLine("Not in this build", 0.6, 0.6, 0.6)
  end
  GameTooltip:AddLine("Click: add a point   Right-click: take one back", 0.6, 0.8, 1)
  GameTooltip:Show()
end

local function MakeTalentButton(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(ICON, ICON)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.border = b:CreateTexture(nil, "BACKGROUND")
  b.border:SetPoint("TOPLEFT", -2, 2)
  b.border:SetPoint("BOTTOMRIGHT", 2, -2)
  b.border:SetColorTexture(0, 0, 0, 0.8)
  b.rank = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  b.rank:SetPoint("BOTTOMRIGHT", 3, -3)
  b.first = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.first:SetPoint("TOPLEFT", 1, -1)
  b:SetScript("OnClick", function(self, mouse)
    if mouse == "RightButton" then P.RemovePoint(self.node) else P.AddPoint(self.node) end
  end)
  b:SetScript("OnEnter", TalentTooltip)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  return b
end

local function Line(parent)
  local t = parent:CreateTexture(nil, "BORDER")
  t:SetColorTexture(0.5, 0.5, 0.5, 0.8)
  return t
end

local function DrawTrees()
  for _, b in ipairs(talentButtons) do b:Hide() end
  for _, l in ipairs(lines) do l:Hide() end
  for _, p in ipairs(treePanels) do p:Hide() end
  local tree = P.tree
  if not tree then
    ui.noTree:Show()
    ui.noTree:SetText("Tactara can't read your talents right now" .. (P.treeError and (": " .. P.treeError) or "") .. ".")
    return
  end
  ui.noTree:Hide()
  local sim = selected and T.Simulate(selected.picks, tree)
  local levels = {}
  if sim then
    for _, step in ipairs(sim.steps) do
      if step.node and not step.err then
        levels[step.node.id] = levels[step.node.id] or {}
        table.insert(levels[step.node.id], step.level)
      end
    end
  end
  local nextStep = selected and T.ActiveBuild() and T.ActiveBuild().name == selected.name and T.Progress(selected, tree).next
  local bi, li = 0, 0
  for t, tr in ipairs(tree.trees) do
    local panel = treePanels[t]
    if not panel then
      panel = CreateFrame("Frame", nil, ui.treeArea)
      panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      panel.title:SetPoint("TOP", panel, "TOP", 0, 0)
      treePanels[t] = panel
    end
    local width = math.max(4, tr.cols) * CELL
    panel:SetSize(width, 20 + tr.rows * CELL)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", ui.treeArea, "TOPLEFT", (t - 1) * (4 * CELL + 16), 0)
    panel:Show()
    local planned = sim and (sim.perTree[t] or 0) or 0
    panel.title:SetText(("%s  %d"):format(tr.name, planned))
    local pos = {}
    for _, node in ipairs(tr.nodes) do
      bi = bi + 1
      local b = talentButtons[bi] or MakeTalentButton(ui.treeArea)
      talentButtons[bi] = b
      b:SetParent(panel)
      b:ClearAllPoints()
      local x, y = (node.col - 1) * CELL + GAP / 2, -(20 + (node.row - 1) * CELL)
      b:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
      pos[node.id] = { x = x + ICON / 2, y = y - ICON / 2 }
      b.node = node
      b.levels = levels[node.id] or {}
      b.icon:SetTexture(SpellIcon(node.spellID))
      local inBuild = #b.levels
      b.icon:SetDesaturated(inBuild == 0)
      b.icon:SetAlpha(inBuild == 0 and 0.45 or 1)
      if inBuild > 0 then
        local color = node.rank >= inBuild and "|cff40ff40" or (inBuild >= node.max and "|cffffd100" or "|cffffffff")
        b.rank:SetText(("%s%d/%d|r"):format(color, inBuild, node.max))
        b.first:SetText(tostring(b.levels[1]))
      else
        b.rank:SetText(node.rank > 0 and ("|cffff7070%d/%d|r"):format(node.rank, node.max) or "")
        b.first:SetText("")
      end
      if nextStep and nextStep.node == node then
        b.border:SetColorTexture(0.3, 0.75, 1, 1)
      else
        b.border:SetColorTexture(0, 0, 0, 0.8)
      end
      b:Show()
    end
    -- arrows: straight down, or across then down
    for _, node in ipairs(tr.nodes) do
      for _, to in ipairs(node.to) do
        local a, z = pos[node.id], pos[to]
        if a and z then
          if math.abs(a.x - z.x) > 1 then
            li = li + 1
            local h = lines[li] or Line(ui.treeArea); lines[li] = h
            h:SetParent(panel); h:ClearAllPoints()
            h:SetPoint("TOPLEFT", panel, "TOPLEFT", math.min(a.x, z.x), a.y + 1)
            h:SetSize(math.abs(a.x - z.x), 3)
            h:Show()
          end
          li = li + 1
          local v = lines[li] or Line(ui.treeArea); lines[li] = v
          v:SetParent(panel); v:ClearAllPoints()
          v:SetPoint("TOPLEFT", panel, "TOPLEFT", z.x - 1, a.y)
          v:SetSize(3, math.max(1, a.y - z.y))
          v:Show()
        end
      end
    end
  end
end

local function DrawOrder()
  local tree = P.tree
  local text = {}
  if selected and tree then
    local prog = T.ActiveBuild() and T.ActiveBuild().name == selected.name and T.Progress(selected, tree)
    local nextIndex = prog and prog.next and prog.next.index
    local sim = T.Simulate(selected.picks, tree)
    local have = {}
    for _, step in ipairs(sim.steps) do
      local line
      if step.err then
        line = ("|cffff7070%d  %s - %s|r"):format(step.level, step.name, step.err)
      else
        have[step.node.id] = (have[step.node.id] or 0) + 1
        local learned = step.node.rank >= have[step.node.id]
        local color = learned and "|cff40ff40" or (step.index == nextIndex and "|cff4dc0ff" or "|cffffffff")
        line = ("%s%d  %s %d/%d%s|r"):format(color, step.level, step.node.name, step.rank, step.node.max,
          step.index == nextIndex and "  < next" or "")
      end
      text[#text + 1] = line
    end
    if #sim.steps < T.MAX_POINTS then
      text[#text + 1] = ("|cff888888%d  (click a talent to add level %d)|r"):format(T.FIRST_LEVEL + #sim.steps, T.FIRST_LEVEL + #sim.steps)
    end
  end
  ui.orderText:SetText(table.concat(text, "\n"))
  local h = math.max(1, #text * 14 + 8)
  ui.orderChild:SetHeight(h)
end

local function DrawList()
  local builds = T.BuildsForClass(ns.GetClassToken())
  for _, b in ipairs(listButtons) do b:Hide() end
  local active = T.ActiveBuild()
  for i, b in ipairs(builds) do
    local btn = listButtons[i]
    if not btn then
      btn = CreateFrame("Button", nil, ui.list)
      btn:SetSize(170, 20)
      btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      btn.text:SetPoint("LEFT", 4, 0)
      btn.text:SetJustifyH("LEFT")
      btn.text:SetWidth(166)
      btn.bg = btn:CreateTexture(nil, "BACKGROUND")
      btn.bg:SetAllPoints()
      btn:SetScript("OnClick", function(self) P.Select(self.build.name) end)
      listButtons[i] = btn
    end
    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", ui.list, "TOPLEFT", 0, -(i - 1) * 22)
    btn.build = b
    local mark = (active and active.name == b.name) and "|cff40ff40> |r" or ""
    btn.text:SetText(mark .. b.name .. (b.builtin and "" or " |cff888888(yours)|r"))
    if selected and selected.name == b.name then
      btn.bg:SetColorTexture(0.3, 0.5, 0.9, 0.35)
    else
      btn.bg:SetColorTexture(0, 0, 0, 0)
    end
    btn:Show()
  end
end

local function DrawHeader()
  if not selected then
    ui.name:SetText("")
    ui.info:SetText("Pick a build on the left, or click New to make your own.")
    return
  end
  ui.name:SetText(selected.name)
  ui.name:SetTextColor(selected.builtin and 0.7 or 1, selected.builtin and 0.7 or 1, selected.builtin and 0.7 or 1)
  local split = P.tree and T.Split(selected, P.tree) or "?"
  local parts = { ("%s points (%s)"):format(#selected.picks, split) }
  if selected.source then parts[#parts + 1] = selected.source end
  if selected.notes then parts[#parts + 1] = selected.notes end
  ui.info:SetText(table.concat(parts, "  |cff888888|||r  "))
end

local function DrawButtons()
  local active = T.ActiveBuild()
  local isActive = selected and active and active.name == selected.name
  ui.use:SetText(isActive and "Using this build" or "Use this build")
  ui.use:SetEnabled(selected ~= nil and not isActive)
  local unspent = P.tree and P.tree.unspent or 0
  local canLearn = isActive and unspent > 0 and not T.blocked
  ui.learn:SetEnabled(canLearn)
  ui.learnAll:SetText(("Learn all (%d)"):format(unspent))
  ui.learnAll:SetEnabled(canLearn and unspent > 1)
  local mine = selected and not selected.builtin
  ui.undo:SetEnabled(selected ~= nil and #selected.picks > 0)
  ui.clear:SetEnabled(selected ~= nil and #selected.picks > 0)
  ui.delete:SetEnabled(mine and true or false)
  ui.share:SetEnabled(selected ~= nil)
  ui.copy:SetEnabled(selected ~= nil)
  ui.auto:SetChecked(TactaraCharDB.talentAutoLearn and true or false)
  ui.glow:SetChecked(TactaraCharDB.talentGlow ~= false)
  if T.blocked then
    ui.points:SetText(("%d to spend. WoW doesn't let addons learn talents: click the glowing talent in your talent window."):format(unspent))
  elseif P.tree then
    ui.points:SetText(("Talent points: %d to spend, %d of %d earned."):format(unspent, P.tree.earned, T.MAX_POINTS))
  else
    ui.points:SetText("")
  end
end

function P.Refresh()
  if not frame or not frame:IsShown() then return end
  P.tree, P.treeError = T.ReadTree()
  if selected then selected = T.GetBuild(selected.name) end
  DrawList()
  DrawHeader()
  DrawTrees()
  DrawOrder()
  DrawButtons()
end

function P.Select(name)
  selected = T.GetBuild(name)
  clearArmed, deleteArmed = false, false
  if ui.clear then ui.clear:SetText("Clear") end
  if ui.delete then ui.delete:SetText("Delete") end
  Status("")
  P.Refresh()
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------

local function Build()
  local templated
  frame, templated = SafeFrame("Frame", "TactaraTalentPlanner", UIParent, "BasicFrameTemplateWithInset")
  if not templated then
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
  end
  frame:SetSize(1010, 600)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetScript("OnShow", function() P.Refresh() end)
  if UISpecialFrames then table.insert(UISpecialFrames, "TactaraTalentPlanner") end

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", frame, "TOP", 0, -6)
  title:SetText("Tactara " .. ns.VERSION .. " - talent planner")

  -- builds list
  local listTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  listTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -34)
  listTitle:SetText("Builds")
  ui.list = CreateFrame("Frame", nil, frame)
  ui.list:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -56)
  ui.list:SetSize(172, 380)
  ui.new = Button(frame, "New", 84)
  ui.new:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -446)
  ui.copy = Button(frame, "Copy", 84)
  ui.copy:SetPoint("LEFT", ui.new, "RIGHT", 4, 0)
  ui.import = Button(frame, "Import", 84)
  ui.import:SetPoint("TOPLEFT", ui.new, "BOTTOMLEFT", 0, -4)
  ui.delete = Button(frame, "Delete", 84)
  ui.delete:SetPoint("LEFT", ui.import, "RIGHT", 4, 0)
  ui.fromMine = Button(frame, "Start from my talents", 172)
  ui.fromMine:SetPoint("TOPLEFT", ui.import, "BOTTOMLEFT", 0, -4)

  -- build name and info
  ui.name = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  ui.name:SetSize(260, 22)
  ui.name:SetPoint("TOPLEFT", frame, "TOPLEFT", 210, -32)
  ui.name:SetAutoFocus(false)
  ui.name:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    if selected and not selected.builtin then
      local new = self:GetText()
      if T.RenameCustom(selected.name, new) then
        Status("Renamed to \"" .. new .. "\".")
        P.Select(new)
      else
        Status("That name is taken (or empty).", true)
        self:SetText(selected.name)
      end
    end
  end)
  ui.name:SetScript("OnEditFocusGained", function(self)
    if selected and selected.builtin then
      self:ClearFocus()
      Status("Tactara's builds can't be renamed. Click Copy to make your own.")
    end
  end)
  ui.name:SetScript("OnEscapePressed", function(self) self:ClearFocus(); if selected then self:SetText(selected.name) end end)
  ui.info = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ui.info:SetPoint("TOPLEFT", frame, "TOPLEFT", 212, -58)
  ui.info:SetWidth(560)
  ui.info:SetJustifyH("LEFT")

  -- trees
  ui.treeArea = CreateFrame("Frame", nil, frame)
  ui.treeArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 210, -80)
  ui.treeArea:SetSize(3 * (4 * CELL + 16), 7 * CELL + 30)
  ui.noTree = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  ui.noTree:SetPoint("CENTER", ui.treeArea, "CENTER")

  -- the build point by point
  local orderTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  orderTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 796, -34)
  orderTitle:SetText("Level by level")
  local okS, scroll = pcall(CreateFrame, "ScrollFrame", "TactaraTalentOrderScroll", frame, "UIPanelScrollFrameTemplate")
  if not okS or not scroll then scroll = CreateFrame("ScrollFrame", "TactaraTalentOrderScroll", frame) end
  scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 794, -56)
  scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 104)
  ui.orderChild = CreateFrame("Frame", nil, scroll)
  ui.orderChild:SetSize(180, 10)
  scroll:SetScrollChild(ui.orderChild)
  ui.orderText = ui.orderChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ui.orderText:SetPoint("TOPLEFT", 2, -2)
  ui.orderText:SetWidth(176)
  ui.orderText:SetJustifyH("LEFT")
  ui.orderText:SetSpacing(2)

  -- bottom: using and learning
  ui.points = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  ui.points:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 210, 76)
  ui.use = Button(frame, "Use this build", 130)
  ui.use:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 210, 44)
  ui.learn = Button(frame, "Learn next", 100)
  ui.learn:SetPoint("LEFT", ui.use, "RIGHT", 6, 0)
  ui.learnAll = Button(frame, "Learn all", 110)
  ui.learnAll:SetPoint("LEFT", ui.learn, "RIGHT", 6, 0)
  ui.undo = Button(frame, "Undo", 70)
  ui.undo:SetPoint("LEFT", ui.learnAll, "RIGHT", 22, 0)
  ui.clear = Button(frame, "Clear", 70)
  ui.clear:SetPoint("LEFT", ui.undo, "RIGHT", 6, 0)
  ui.share = Button(frame, "Share", 70)
  ui.share:SetPoint("LEFT", ui.clear, "RIGHT", 6, 0)

  ui.auto = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
  ui.auto:SetSize(24, 24)
  ui.auto:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 206, 14)
  ui.autoLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ui.autoLabel:SetPoint("LEFT", ui.auto, "RIGHT", 2, 0)
  ui.autoLabel:SetText("Learn the next points automatically when I level up")
  ui.glow = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
  ui.glow:SetSize(24, 24)
  ui.glow:SetPoint("LEFT", ui.autoLabel, "RIGHT", 16, 0)
  ui.glowLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ui.glowLabel:SetPoint("LEFT", ui.glow, "RIGHT", 2, 0)
  ui.glowLabel:SetText("Glow the next talent in my talent window")

  statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  statusText:SetPoint("TOPLEFT", frame, "TOPLEFT", 796, -502)
  statusText:SetWidth(196)
  statusText:SetJustifyH("LEFT")

  -- actions
  ui.new:SetScript("OnClick", function()
    local b = T.SaveCustom({ name = T.UniqueName("My build"), class = ns.GetClassToken(), picks = {} })
    Status("New build. Click talents in the order you want them, starting at level 10.")
    P.Select(b.name)
  end)
  ui.fromMine:SetScript("OnClick", function() P.FromMyTalents() end)
  ui.copy:SetScript("OnClick", function()
    if not selected then return end
    local copy = { name = T.UniqueName(selected.name), class = selected.class or ns.GetClassToken(),
      tree = selected.tree, notes = selected.notes, source = selected.builtin and ("based on " .. selected.name) or selected.source, picks = {} }
    for i, p in ipairs(selected.picks) do copy.picks[i] = p end
    T.SaveCustom(copy)
    P.Select(copy.name)
    Status("Copied. This one is yours to change.")
  end)
  ui.delete:SetScript("OnClick", function(self)
    if not selected or selected.builtin then return end
    if not deleteArmed then deleteArmed = true; self:SetText("Sure?") return end
    local name = selected.name
    T.DeleteCustom(name)
    deleteArmed = false
    self:SetText("Delete")
    selected = nil
    Status("Deleted \"" .. name .. "\".")
    P.Refresh()
  end)
  ui.import:SetScript("OnClick", function()
    ns.ShowCopyText("Import a talent build", "", {
      editable = true, button = "Import",
      hint = "Paste a build (Ctrl+V), then click Import.",
      onAccept = function(text)
        local b = T.Parse(text)
        if #b.picks == 0 then Status("That doesn't look like a talent build.", true) return false end
        b.class = b.class or ns.GetClassToken()
        b.name = T.UniqueName(b.name or "Imported build")
        T.SaveCustom(b)
        P.Select(b.name)
        Status(("Imported \"%s\" (%d points)."):format(b.name, #b.picks))
        return true
      end,
    })
  end)
  ui.share:SetScript("OnClick", function()
    if selected then ns.ShowCopyText("Share \"" .. selected.name .. "\"", T.Export(selected)) end
  end)
  ui.use:SetScript("OnClick", function()
    if not selected then return end
    T.SetActive(selected.name)
    Status(("Using \"%s\". Learn next, Learn all, the reminders and the glow follow it."):format(selected.name))
    P.Refresh()
  end)
  local function DoLearn(count)
    local learned, why = T.Learn(count)
    if learned then
      Status(("Learning %d point%s..."):format(#learned, #learned == 1 and "" or "s"))
    else
      Status("Couldn't learn: " .. tostring(why), true)
    end
  end
  ui.learn:SetScript("OnClick", function() DoLearn(1) end)
  ui.learnAll:SetScript("OnClick", function() DoLearn("all") end)
  ui.undo:SetScript("OnClick", function()
    if not selected or #selected.picks == 0 then return end
    local b = Editable()
    local removed = table.remove(b.picks)
    Save(b)
    Status("Took back " .. tostring(removed) .. ".")
  end)
  ui.clear:SetScript("OnClick", function(self)
    if not selected or #selected.picks == 0 then return end
    if not clearArmed then clearArmed = true; self:SetText("Sure?") return end
    clearArmed = false
    self:SetText("Clear")
    local b = Editable()
    b.picks = {}
    Save(b)
    Status("Cleared. Click talents in the order you want them.")
  end)
  ui.auto:SetScript("OnClick", function(self)
    TactaraCharDB.talentAutoLearn = self:GetChecked() and true or false
    Status(TactaraCharDB.talentAutoLearn
      and "When you level up, Tactara learns the next points of the build you're using (never in combat)."
      or "Tactara will remind you instead when you have points to spend.")
  end)
  ui.glow:SetScript("OnClick", function(self)
    TactaraCharDB.talentGlow = self:GetChecked() and true or false
    T.Refresh()
  end)
end

-- A new build of your own that starts with the talents you have now.
function P.FromMyTalents()
  local tree = T.ReadTree()
  if not tree then Status("Tactara can't read your talents right now.", true) return end
  local picks = T.FromCurrent(tree)
  if #picks == 0 then Status("You haven't learned any talents yet. Click New to plan from scratch.", true) return end
  local b = T.SaveCustom({ name = T.UniqueName("My talents"), class = ns.GetClassToken(),
    notes = "Started from the talents I had at level " .. tostring(UnitLevel and UnitLevel("player") or "?") .. ".", picks = picks })
  P.Select(b.name)
  Status(("Your %d point%s are in. Click talents to plan the rest, then Use this build."):format(#picks, #picks == 1 and "" or "s"))
  return b
end

function P.Show()
  if not frame then Build() end
  if not selected then
    local active = T.ActiveBuild()
    local pick = active and active.name
    if not pick and ns.activeName and T.GetBuild(ns.activeName) then pick = ns.activeName end
    if not pick then
      local list = T.BuildsForClass(ns.GetClassToken())
      pick = list[1] and list[1].name
    end
    selected = pick and T.GetBuild(pick)
  end
  frame:Show()
  P.Refresh()
end

function P.Toggle()
  if frame and frame:IsShown() then frame:Hide() else P.Show() end
end

function P.Selected() return selected end
P.debug = { buttons = talentButtons, ui = ui, status = function() return statusText and statusText:GetText() end }

T.OnChange(function() P.Refresh() end)

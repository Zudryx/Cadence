-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: /tac probe
-- Reports which game information WoW Forever lets addons read, so the
-- build-aware "best next skill" feature can use whatever is available.
-- Run it once out of combat and once in combat (on a mob in the open world).

local ADDON, ns = ...
local unpack = unpack or table.unpack

local function IsHidden(v)
  if issecretvalue then
    local ok, secret = pcall(issecretvalue, v)
    if ok and secret then return true end
  end
  if v == nil then return false end
  local ok = pcall(function() local _ = (v == v) and tostring(v) end)
  return not ok
end

local function Fmt(...)
  local n = select("#", ...)
  if n == 0 then return "nil" end
  local parts = {}
  for i = 1, math.min(n, 8) do
    local v = select(i, ...)
    if IsHidden(v) then
      parts[#parts + 1] = "|cffff5555HIDDEN|r"
    elseif type(v) == "table" then
      local keys = {}
      for k, val in pairs(v) do
        if #keys < 6 then
          keys[#keys + 1] = tostring(k) .. "=" .. (IsHidden(val) and "HIDDEN" or tostring(val))
        end
      end
      parts[#parts + 1] = "{" .. table.concat(keys, " ") .. "}"
    else
      parts[#parts + 1] = tostring(v)
    end
  end
  return table.concat(parts, ", ")
end

local function Check(label, fn)
  local results = { pcall(fn) }
  local ok = table.remove(results, 1)
  local text
  if not ok then
    local err = tostring(results[1] or "?")
    if err:find("MISSING") then
      text = "|cffaaaaaano such API|r"
    else
      text = "|cffff5555error|r " .. err:gsub("^.-:%d+: ", ""):sub(1, 80)
    end
  else
    text = Fmt(unpack(results, 1, math.max(1, #results)))
  end
  ns.Print(("  %s: %s"):format(label, text))
end

local function need(f, name)
  if not f then error("MISSING " .. name) end
  return f
end

function ns.Probe()
  local inCombat = InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player"))
  ns.Print(("probe - %s, target: %s. Please screenshot this and send it over.")
    :format(inCombat and "|cffff5555IN COMBAT|r" or "|cff00ff00out of combat|r",
      tostring(UnitName and UnitName("target") or "none")))

  -- talents / build
  Check("talents (Tactara reader)", function()
    local t = ns.ReadTalents(ns.GetClassToken())
    local parts = {}
    for _, tr in ipairs(t.trees) do parts[#parts + 1] = tr.name .. " " .. tr.points end
    return t.info, table.concat(parts, " / ")
  end)
  Check("talent layout", function()
    local configID = need(C_ClassTalents and C_ClassTalents.GetActiveConfigID, "GetActiveConfigID")()
    local cfg = C_Traits.GetConfigInfo(configID)
    local trees, nodes, subs, minX, maxX, named = 0, 0, {}, nil, nil, 0
    for _, treeID in ipairs(cfg.treeIDs or {}) do
      trees = trees + 1
      for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
        local n = C_Traits.GetNodeInfo(configID, nodeID)
        if n and n.ID and n.ID ~= 0 then
          nodes = nodes + 1
          if n.subTreeID and n.subTreeID ~= 0 then subs[n.subTreeID] = true end
          if n.posX then
            minX = minX and math.min(minX, n.posX) or n.posX
            maxX = maxX and math.max(maxX, n.posX) or n.posX
          end
        end
      end
    end
    local subCount = 0
    for _ in pairs(subs) do subCount = subCount + 1 end
    return ("config %s, %d trees, %d nodes, %d sub-trees, x %s-%s"):format(
      tostring(configID), trees, nodes, subCount, tostring(minX), tostring(maxX))
  end)
  Check("weapon (Tactara reader)", function() return ns.ReadWeapon() end)
  Check("main hand / off hand", function()
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local function loc(slot)
      local id = GetInventoryItemID("player", slot)
      if not id then return "empty" end
      local _, _, _, l = f(id)
      return l
    end
    return loc(16), loc(17)
  end)
  Check("dual wielding", function() return need(IsDualWielding, "IsDualWielding")() end)
  Check("enemies near (Tactara)", function() return ns.CountEnemies() end)

  -- what can be read during a fight
  Check("your power (rage, energy or mana)", function() return need(UnitPower, "UnitPower")("player") end)
  Check("combo points (game / Tactara count)", function()
    local game = GetComboPoints and GetComboPoints("player", "target")
    return game, ns.ComboPoints()
  end)
  Check("pet", function()
    if not UnitExists("pet") then return "none" end
    return UnitName("pet"), UnitIsDead("pet") and "dead" or "alive"
  end)
  Check("target creature type", function() return UnitCreatureType("target") end)
  Check("target health / max", function() return UnitHealth("target"), UnitHealthMax("target") end)
  Check("YOUR health / max", function() return UnitHealth("player"), UnitHealthMax("player") end)
  Check("target casting (name, interruptible?)", function()
    local name, _, _, _, _, _, _, notInt = UnitCastingInfo("target")
    if not name then
      local cname, _, _, _, _, _, cnot = UnitChannelInfo("target")
      if not cname then return "not casting" end
      return cname, cnot
    end
    return name, notInt
  end)
  Check("Tactara reads target cast as", function() return ns.TargetCastState() end)
  -- a buff and a debuff your rotation checks, and two of its spells
  local comp = ns.compiled and ns.compiled.main
  local buff, debuff
  for _, e in ipairs(comp and comp.priority or {}) do
    for _, c in ipairs(e.live or {}) do
      if c.kind == "missing" and not buff then buff = c.arg end
      if c.kind == "nodebuff" and not debuff then debuff = c.arg end
    end
  end
  if buff then
    Check(buff .. " on you", function()
      local a = need(C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName, "GetAuraDataBySpellName")("player", buff, "HELPFUL")
      if a == nil then return "not up" end
      return a.expirationTime, a.duration
    end)
  end
  if debuff then
    Check(debuff .. " on target", function()
      local a = need(C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName, "GetAuraDataBySpellName")("target", debuff, "HARMFUL")
      if a == nil then return "not up" end
      return a.expirationTime, a.duration
    end)
  end
  local knownSpells = {}
  for _, s in ipairs(comp and comp.spells or {}) do
    if ns.IsKnown(s) and #knownSpells < 2 then knownSpells[#knownSpells + 1] = s end
  end
  for _, sp in ipairs(knownSpells) do
    Check(sp .. " cooldown", function() return need(C_Spell and C_Spell.GetSpellCooldown, "GetSpellCooldown")(sp) end)
    Check(sp .. " usable / no power", function() return need(C_Spell and C_Spell.IsSpellUsable, "IsSpellUsable")(sp) end)
  end
end

---------------------------------------------------------------------------
-- A window with text you can copy (Ctrl+C), for reports that are too long
-- for a screenshot.
---------------------------------------------------------------------------

local copyFrame

function ns.ShowCopyText(title, text)
  if not copyFrame then
    local ok, f = pcall(CreateFrame, "Frame", "TactaraCopyFrame", UIParent, "BasicFrameTemplateWithInset")
    if not ok or not f then f = CreateFrame("Frame", "TactaraCopyFrame", UIParent) end
    f:SetSize(640, 440)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if UISpecialFrames then table.insert(UISpecialFrames, "TactaraCopyFrame") end
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOP", f, "TOP", 0, -6)
    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 12)
    f.hint:SetText("It's all selected: press Ctrl+C to copy it, then paste it anywhere.")
    local okS, scroll = pcall(CreateFrame, "ScrollFrame", "TactaraCopyScroll", f, "UIPanelScrollFrameTemplate")
    if not okS or not scroll then scroll = CreateFrame("ScrollFrame", "TactaraCopyScroll", f) end
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -30)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -32, 32)
    local eb = CreateFrame("EditBox", "TactaraCopyText", scroll)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal)
    eb:SetWidth(580)
    eb:SetMaxLetters(0)
    eb:SetScript("OnEscapePressed", function() f:Hide() end)
    -- read only: typing puts the report back
    eb:SetScript("OnTextChanged", function(self, userInput)
      if userInput then self:SetText(f.text or ""); self:HighlightText() end
    end)
    scroll:SetScrollChild(eb)
    f.edit = eb
    copyFrame = f
  end
  copyFrame.text = text
  copyFrame.title:SetText(title)
  copyFrame.edit:SetText(text)
  copyFrame:Show()
  copyFrame.edit:SetFocus()
  copyFrame.edit:HighlightText()
  return copyFrame
end

---------------------------------------------------------------------------
-- /tac probe talents
-- Read only: reports how WoW Forever's talents look to an addon (trees,
-- talents, ranks, requirements, which talent functions exist, and how the
-- talent window is built), for the talent planner. It never learns, stages
-- or changes a talent. Best run with the talent window open.
---------------------------------------------------------------------------

local TALENT_FUNCTIONS = {
  "C_ClassTalents.GetActiveConfigID", "C_ClassTalents.CanChangeTalents", "C_ClassTalents.CommitConfig",
  "C_ClassTalents.LoadConfig", "C_ClassTalents.SaveConfig", "C_ClassTalents.GetConfigIDsBySpecID",
  "C_ClassTalents.ImportLoadout", "C_ClassTalents.GetLastSelectedSavedConfigID",
  "C_Traits.GetConfigInfo", "C_Traits.GetTreeInfo", "C_Traits.GetTreeNodes", "C_Traits.GetNodeInfo",
  "C_Traits.GetEntryInfo", "C_Traits.GetDefinitionInfo", "C_Traits.GetConditionInfo",
  "C_Traits.GetTreeCurrencyInfo", "C_Traits.CanPurchaseRank", "C_Traits.PurchaseRank", "C_Traits.RefundRank",
  "C_Traits.SetSelection", "C_Traits.CommitConfig", "C_Traits.ConfigHasStagedChanges",
  "C_Traits.RollbackConfig", "C_Traits.ResetTree", "C_Traits.GetLoadoutSerializationVersion",
  "C_SpecializationInfo.GetActiveSpecGroup", "C_SpecializationInfo.GetNumSpecGroups",
  "C_SpecializationInfo.CanPlayerUseTalentUI", "C_SpecializationInfo.CanPlayerUseTalentSpecUI",
  "GetTalentInfo", "LearnTalent", "GetNumTalentTabs", "GetUnspentTalentPoints", "UnitCharacterPoints",
  "GetActiveTalentGroup", "GetNumTalentGroups",
}

local function Has(path)
  local t = _G
  for part in path:gmatch("[^%.]+") do
    if type(t) ~= "table" then return false end
    t = t[part]
  end
  return t ~= nil
end

local function Str(v)
  if IsHidden(v) then return "HIDDEN" end
  if type(v) == "table" then return Fmt(v) end
  return tostring(v)
end

local function TalentName(configID, node)
  local entryID = (node.activeEntry and node.activeEntry.entryID) or (node.entryIDs and node.entryIDs[1])
  if not entryID then return "?", nil, 0 end
  local entry = C_Traits.GetEntryInfo(configID, entryID) or {}
  local def = entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID) or {}
  local spellID = def.spellID or def.overriddenSpellID
  local name = (def.overrideName and def.overrideName ~= "" and def.overrideName)
    or (spellID and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)) or "?"
  return name, spellID, entry.maxRanks or 0
end

function ns.ProbeTalents()
  local L = {}
  local function add(text) L[#L + 1] = text end
  local function try(label, fn)
    local r = { pcall(fn) }
    if not r[1] then add(label .. ": error " .. tostring(r[2]):gsub("^.-:%d+: ", ""):sub(1, 100)) end
    return r[1]
  end

  local version, build, _, iface = GetBuildInfo()
  local _, class = UnitClass("player")
  add(("Tactara %s talent probe. Read only: nothing was learned or changed."):format(ns.VERSION))
  add(("game %s (%s), interface %s, %s level %s"):format(tostring(version), tostring(build), tostring(iface), tostring(class),
    tostring(UnitLevel and UnitLevel("player"))))

  local yes, no = {}, {}
  for _, f in ipairs(TALENT_FUNCTIONS) do
    if Has(f) then yes[#yes + 1] = f else no[#no + 1] = f end
  end
  add("functions there: " .. (#yes > 0 and table.concat(yes, ", ") or "none"))
  add("functions missing: " .. (#no > 0 and table.concat(no, ", ") or "none"))

  try("can change talents", function()
    if C_ClassTalents and C_ClassTalents.CanChangeTalents then
      local canChange, canAdd, err = C_ClassTalents.CanChangeTalents()
      add(("can change talents: %s, can add: %s, reason: %s"):format(Str(canChange), Str(canAdd), Str(err)))
    end
    if UnitCharacterPoints then add("UnitCharacterPoints: " .. Str(UnitCharacterPoints("player"))) end
    if GetUnspentTalentPoints then add("GetUnspentTalentPoints: " .. Str(GetUnspentTalentPoints())) end
    if C_SpecializationInfo and C_SpecializationInfo.GetNumSpecGroups then
      add(("spec groups: %s, active: %s"):format(Str(C_SpecializationInfo.GetNumSpecGroups()),
        Str(C_SpecializationInfo.GetActiveSpecGroup and C_SpecializationInfo.GetActiveSpecGroup())))
    end
  end)

  local configID
  local nodes = {}
  local okTree = try("talent config", function()
    configID = C_ClassTalents.GetActiveConfigID()
    local cfg = C_Traits.GetConfigInfo(configID) or {}
    add(("config %s, type %s, name %s, trees %s"):format(Str(configID), Str(cfg.type), Str(cfg.name),
      table.concat(cfg.treeIDs or {}, " ")))
    for _, treeID in ipairs(cfg.treeIDs or {}) do
      if C_Traits.GetTreeInfo then
        local ti = C_Traits.GetTreeInfo(configID, treeID) or {}
        local gates = {}
        for _, g in ipairs(ti.gates or {}) do
          gates[#gates + 1] = ("node %s cond %s"):format(Str(g.topLeftNodeID), Str(g.conditionID))
        end
        add(("tree %s gates: %s"):format(treeID, #gates > 0 and table.concat(gates, "; ") or "none"))
      end
      if C_Traits.GetTreeCurrencyInfo then
        for _, c in ipairs(C_Traits.GetTreeCurrencyInfo(configID, treeID, false) or {}) do
          add(("tree %s points: currency %s, unspent %s, max %s, spent %s"):format(treeID, Str(c.traitCurrencyID),
            Str(c.quantity), Str(c.maxQuantity), Str(c.spent)))
        end
      end
      for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
        local n = C_Traits.GetNodeInfo(configID, nodeID)
        if n and n.ID and n.ID ~= 0 then nodes[#nodes + 1] = n end
      end
    end
  end)

  if okTree and #nodes > 0 then
    table.sort(nodes, function(a, b)
      local sa, sb = a.subTreeID or 0, b.subTreeID or 0
      if sa ~= sb then return sa < sb end
      if (a.posY or 0) ~= (b.posY or 0) then return (a.posY or 0) < (b.posY or 0) end
      return (a.posX or 0) < (b.posX or 0)
    end)
    add(("%d talents (sub-tree, x, y, ranks, flags, name, spell id, requirements, arrows to):"):format(#nodes))
    local condSeen, firstBuyable = {}, nil
    for _, n in ipairs(nodes) do
      try("talent " .. tostring(n.ID), function()
        local name, spellID, entryMax = TalentName(configID, n)
        local flags = {}
        if n.isAvailable then flags[#flags + 1] = "available" end
        if n.canPurchaseRank then flags[#flags + 1] = "can-learn"; firstBuyable = firstBuyable or n end
        if n.meetsEdgeRequirements == false then flags[#flags + 1] = "needs-arrow" end
        if n.isVisible == false then flags[#flags + 1] = "hidden" end
        if n.entryIDs and #n.entryIDs > 1 then flags[#flags + 1] = "choice-of-" .. #n.entryIDs end
        local conds = {}
        for _, cid in ipairs(n.conditionIDs or {}) do
          conds[#conds + 1] = tostring(cid)
          condSeen[cid] = true
        end
        local edges = {}
        for _, e in ipairs(n.visibleEdges or {}) do edges[#edges + 1] = tostring(e.targetNode) end
        add(("n%s sub%s x%s y%s %s/%s type%s [%s] %s spell%s cond[%s] ->[%s]%s"):format(
          Str(n.ID), Str(n.subTreeID or 0), Str(n.posX), Str(n.posY), Str(n.ranksPurchased or n.currentRank or 0),
          Str(n.maxRanks or entryMax), Str(n.type), table.concat(flags, ","), name, Str(spellID),
          table.concat(conds, ","), table.concat(edges, ","),
          (n.groupIDs and #n.groupIDs > 0) and (" groups[" .. table.concat(n.groupIDs, ",") .. "]") or ""))
      end)
    end
    if C_Traits.GetConditionInfo then
      local ids = {}
      for cid in pairs(condSeen) do ids[#ids + 1] = cid end
      table.sort(ids)
      for _, cid in ipairs(ids) do
        try("requirement " .. cid, function()
          local c = C_Traits.GetConditionInfo(configID, cid) or {}
          add(("requirement %s: points spent %s, level %s, met %s, gate %s, always %s"):format(cid,
            Str(c.spentAmountRequired), Str(c.playerLevel), Str(c.isMet), Str(c.isGate), Str(c.isAlwaysMet)))
        end)
      end
    end
    if firstBuyable and C_Traits.CanPurchaseRank then
      try("can learn check", function()
        local entryID = firstBuyable.nextEntry and firstBuyable.nextEntry.entryID
          or (firstBuyable.entryIDs and firstBuyable.entryIDs[1])
        add(("check only, not learned: CanPurchaseRank(n%s) = %s"):format(Str(firstBuyable.ID),
          Str(C_Traits.CanPurchaseRank(configID, firstBuyable.ID, entryID))))
      end)
    end
  end

  -- how the talent window is built (for putting a glow on the next talent)
  try("talent window", function()
    local loaded = {}
    local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    for _, a in ipairs({ "Blizzard_PlayerSpells", "Blizzard_ClassTalentUI", "Blizzard_TalentUI" }) do
      local ok, l = pcall(isLoaded or function() return nil end, a)
      loaded[#loaded + 1] = a .. "=" .. Str(ok and l)
    end
    add("talent UI addons loaded: " .. table.concat(loaded, ", "))
    local candidates = {
      { "PlayerSpellsFrame", PlayerSpellsFrame }, { "PlayerSpellsFrame.TalentsFrame", PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame },
      { "ClassTalentFrame", ClassTalentFrame }, { "ClassTalentFrame.TalentsTab", ClassTalentFrame and ClassTalentFrame.TalentsTab },
      { "PlayerTalentFrame", PlayerTalentFrame }, { "TalentFrame", TalentFrame },
      { "PlayerTalentFrameTalent1", _G.PlayerTalentFrameTalent1 }, { "TalentFrameTalent1", _G.TalentFrameTalent1 },
    }
    for _, c in ipairs(candidates) do
      local f = c[2]
      if f then
        local shown = f.IsShown and f:IsShown()
        local methods = {}
        for _, m in ipairs({ "GetTalentButtonByNodeID", "EnumerateAllTalentButtons", "GetConfigID", "GetTalentTreeID" }) do
          if f[m] then methods[#methods + 1] = m end
        end
        add(("%s: there, %s%s"):format(c[1], shown and "shown" or "not shown",
          #methods > 0 and (", has " .. table.concat(methods, ", ")) or ""))
        if f.GetTalentButtonByNodeID and nodes[1] then
          local okB, btn = pcall(f.GetTalentButtonByNodeID, f, nodes[1].ID)
          if okB and btn then
            add(("  button for n%s: %s, %sx%s"):format(Str(nodes[1].ID), Str(btn.GetName and btn:GetName() or "unnamed"),
              Str(btn.GetWidth and math.floor(btn:GetWidth())), Str(btn.GetHeight and math.floor(btn:GetHeight()))))
          end
        end
      else
        add(c[1] .. ": not there")
      end
    end
  end)

  local text = table.concat(L, "\n")
  ns.ShowCopyText("Tactara talent probe", text)
  local windowOpen = (PlayerSpellsFrame and PlayerSpellsFrame:IsShown()) or (ClassTalentFrame and ClassTalentFrame:IsShown())
    or (PlayerTalentFrame and PlayerTalentFrame:IsShown()) or (TalentFrame and TalentFrame:IsShown())
  ns.Print("Talent probe done. Copy the text in the window (Ctrl+C) and paste it to whoever asked for it. Nothing was changed.")
  if not windowOpen then
    ns.Print("Tip: open your talent window (N) and run |cffffd100/tac probe talents|r again, so the report covers the window too.")
  end
  return text
end

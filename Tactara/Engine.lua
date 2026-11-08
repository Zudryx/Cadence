-- Tactara: the one-button engine.
--
-- How it works:
--   * Hidden secure buttons hold the compiled steps as attributes:
--     step1, step2, ... Each step is a small macro.
--   * Every press runs a tiny secure snippet that loads the next step into
--     the button's macro text and advances the counter. One press = one step.
--   * The sequence is rebuilt (out of combat only) whenever your spells,
--     talents or rotation change, and restarts from the opener after combat.
-- Nothing here reads hidden combat data or presses anything for you.
--
-- The buttons always fire on key down (pressAndHoldAction), which is what
-- real keypresses need. They're driven by key bindings: either /tac bind
-- (override binding, see Keys.lua) or Esc > Keybindings > AddOns > Tactara.
-- Action-bar macros can't drive them: WoW doesn't let a macro /click a
-- button that runs another macro.

local ADDON, ns = ...

-- Accept one half of each press, load the step, advance.
local PRE_CLICK = [=[
  local want = self:GetAttribute("useKeyDown")
  if want ~= nil then
    local isDown = down and true or false
    if isDown ~= want then return false end
  end
  local n = self:GetAttribute("numSteps") or 0
  if n < 1 then return false end
  local idx = self:GetAttribute("idx") or 1
  if idx < 1 or idx > n then idx = 1 end
  self:SetAttribute("macrotext", self:GetAttribute("step" .. idx))
  self:SetAttribute("lastIdx", idx)
  local nxt = idx + 1
  if nxt > n then nxt = self:GetAttribute("loopStart") or 1 end
  self:SetAttribute("idx", nxt)
]=]

local function CreateSequenceButton(name)
  local b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
  b:SetSize(1, 1)
  b:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
  b:EnableMouse(false)
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetAttribute("type", "macro")
  b:SetAttribute("macrotext", "")
  b:SetAttribute("numSteps", 0)
  b:SetAttribute("idx", 1)
  b:SetAttribute("loopStart", 1)
  SecureHandlerWrapScript(b, "OnClick", b, PRE_CLICK)
  -- Fallback lines make failed casts normal, so hide the red error text
  -- just for the duration of a Tactara press.
  b:HookScript("PreClick", function(self, button, down)
    ns.HideErrorsForPress(self, down)
  end)
  b:HookScript("OnClick", function(self, button, down)
    ns.RestoreErrors()
    ns.OnSequenceClick(self, down)
  end)
  return b
end

local errorsHidden = false

function ns.HideErrorsForPress(button, down)
  if not (TactaraDB and TactaraDB.hideErrors) or not UIErrorsFrame then return end
  if (down and true or false) ~= (ns.useKeyDown and true or false) then return end
  if UIErrorsFrame:IsShown() then
    UIErrorsFrame:Hide()
    errorsHidden = true
  end
end

function ns.RestoreErrors()
  if errorsHidden and UIErrorsFrame then
    errorsHidden = false
    UIErrorsFrame:Clear()
    UIErrorsFrame:Show()
  end
end

ns.mainButton = CreateSequenceButton("TactaraMainButton")
ns.aoeButton = CreateSequenceButton("TactaraAoEButton")
-- Tactara Interrupt key: one "step" holding every known interrupt as fallbacks.
ns.interruptButton = CreateSequenceButton("TactaraInterruptButton")
ns.interruptButton.isUtility = true
ns.allButtons = { ns.mainButton, ns.aoeButton, ns.interruptButton }
ns.lastClicked = ns.mainButton

function ns.IsAoEButton(button)
  return button == ns.aoeButton
end

function ns.CompiledFor(button)
  if ns.IsAoEButton(button) then return ns.compiled.aoe end
  return ns.compiled.main
end

function ns.OnSequenceClick(button, down)
  local isDown = down and true or false
  local accepted = isDown == (ns.useKeyDown and true or false)
  if button.isUtility then
    if accepted then ns.Debug("Interrupt key pressed: " .. (button:GetAttribute("step1") or "no interrupt known"):gsub("\n", " / ")) end
    return
  end
  if TactaraDB and TactaraDB.debug then
    local comp = ns.CompiledFor(button)
    local idx = button:GetAttribute("lastIdx") or "?"
    local step = accepted and comp and comp.steps[idx]
    ns.Debug(("%s %s: %s"):format(
      ns.IsAoEButton(button) and "AoE" or "Main",
      isDown and "key down" or "key up",
      accepted and ("step " .. tostring(idx) .. " -> " .. (step and step.label or "?")) or "ignored (other half of the press)"))
    if accepted then ns.debugPressTime = GetTime() end
  end
  if not accepted then return end
  ns.lastClicked = button
  ns.HelperSync(button)
  ns.HelperRefresh()
end

---------------------------------------------------------------------------
-- Key-down / key-up handling
--
-- Blizzard's secure button only runs its action on ONE half of a press:
-- key down if the ActionButtonUseKeyDown setting is on, key up if it's off.
-- Setting the "pressAndHoldAction" attribute makes it always use key down,
-- whatever that setting is. We then accept only key down ourselves, and the
-- macros send a key-down click. Result: one press = one step = one cast,
-- with no dependence on the player's settings.
--
-- /tac keydown off switches to the old key-up behaviour, for troubleshooting.
---------------------------------------------------------------------------

function ns.SyncKeyDown()
  local mode = TactaraCharDB and TactaraCharDB.keyDown
  ns.useKeyDown = (mode ~= false)
  ns.cvarKeyDown = (GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")) and true or false
  if InCombatLockdown() then
    ns.syncAfterCombat = true
    return
  end
  for _, b in ipairs(ns.allButtons) do
    b:SetAttribute("useKeyDown", ns.useKeyDown)
    b:SetAttribute("pressAndHoldAction", ns.useKeyDown and true or nil)
  end
end

---------------------------------------------------------------------------
-- Loading compiled steps onto the buttons
---------------------------------------------------------------------------

local function ApplyToButton(b, comp)
  if InCombatLockdown() then
    ns.rebuildAfterCombat = true
    return false
  end
  local old = b:GetAttribute("numSteps") or 0
  local n = comp and #comp.steps or 0
  for i = 1, n do b:SetAttribute("step" .. i, comp.steps[i].text) end
  for i = n + 1, old do b:SetAttribute("step" .. i, nil) end
  b:SetAttribute("numSteps", n)
  b:SetAttribute("loopStart", comp and comp.loopStart or 1)
  b:SetAttribute("idx", 1)
  b:SetAttribute("macrotext", "")
  return true
end

-- Which rotation should be active? Manual choice wins. Otherwise auto-pick,
-- in this order:
--   1. the talent tree you've put the most points in (rotation "tree:")
--   2. a signature spell you know (rotation "detect:")
--   3. your weapons: two-hand / dual / shield (rotation "weapon:")
--   4. the rotation marked "default: yes"
-- Returns name, wasAuto, reason.
function ns.ResolveActive()
  local class = ns.GetClassToken()
  local chosen = TactaraCharDB and TactaraCharDB.active
  if chosen and chosen ~= "auto" and ns.GetRotationText(chosen) then
    return chosen, false, "your choice"
  end
  local list = ns.ListRotations(class)
  local build = ns.ReadBuild()
  local function weaponFits(r)
    return not r.weapon or r.weapon == "any" or not build.weapon or r.weapon == build.weapon
  end
  if build.top then
    local top = build.top:lower()
    local points = 0
    for _, t in ipairs(build.talents.trees or {}) do if t.name == build.top then points = t.points end end
    local reason = ("%d talent points in %s"):format(points, build.top)
    -- Several rotations can share a tree (Druid cat and bear): prefer the one
    -- that fits your weapon, then the one whose "prefer:" talents you took.
    local best, bestScore
    for _, r in ipairs(list) do
      if r.tree and r.tree:lower() == top then
        local score = weaponFits(r) and 1000 or 0
        for t in (r.prefer or ""):gmatch("[^,]+") do
          score = score + ((build.talents.talents or {})[ns.trim(t)] or 0)
        end
        if not bestScore or score > bestScore then best, bestScore = r, score end
      end
    end
    if best then return best.name, true, reason end
  end
  for _, r in ipairs(list) do
    if r.detect and ns.IsKnown(r.detect) then return r.name, true, "you know " .. r.detect end
  end
  if build.weapon then
    for _, r in ipairs(list) do
      if r.weapon == build.weapon then
        local what = ({ ["two-hand"] = "two-hander", dual = "dual wield", shield = "shield" })[build.weapon] or build.weapon
        return r.name, true, "your " .. what
      end
    end
  end
  for _, r in ipairs(list) do
    if r.default then return r.name, true, "default" end
  end
  if list[1] then return list[1].name, true, "first available" end
  return nil, true, nil
end

function ns.MakeEnv()
  return { isKnown = ns.IsKnown, hasBuff = ns.HasBuff }
end

function ns.Rebuild(reason)
  if InCombatLockdown() then
    ns.rebuildAfterCombat = true
    return
  end
  ns.ClearKnownCache()
  ns.InvalidateBuild()

  local name, auto, why = ns.ResolveActive()
  local rot = name and ns.Parse(ns.GetRotationText(name))
  ns.SetTrackedSpells(rot)
  local env = ns.MakeEnv()
  local main = ns.Compile(rot, "main", env)
  local aoe = ns.Compile(rot, "aoe", env)

  ApplyToButton(ns.mainButton, main)
  ApplyToButton(ns.aoeButton, aoe)
  local im = main.interruptMacro or ""
  ApplyToButton(ns.interruptButton, { steps = (im ~= "") and { { text = im } } or {}, loopStart = 1 })
  ns.compiled.main, ns.compiled.aoe = main, aoe
  ns.usesBuffChecks = rot and rot.usesBuffChecks or false

  -- Tell the player what changed.
  if name ~= ns.activeName then
    if name then
      ns.Print(("Using |cffffd100%s|r%s. %d opener + %d loop steps, %d helper priorities at your level.")
        :format(name, auto and (" (auto: " .. tostring(why) .. ")") or "", main.openerCount, main.loopCount, #main.priority))
    elseif ns.loggedIn then
      ns.Print("No rotation for your class yet. Open /tac and click New to write one.")
    end
  elseif ns.lastSpells then
    local added = {}
    for _, s in ipairs(main.spells) do
      if not ns.lastSpells[s] then added[#added + 1] = s end
    end
    for _, s in ipairs(aoe.spells) do
      if not ns.lastSpells[s] and not tContains(added, s) then added[#added + 1] = s end
    end
    if #added > 0 then ns.Print("Added to your rotation: |cff00ff00" .. table.concat(added, ", ") .. "|r") end
  end
  ns.lastSpells = {}
  for _, s in ipairs(main.spells) do ns.lastSpells[s] = true end
  for _, s in ipairs(aoe.spells) do ns.lastSpells[s] = true end

  for _, w in ipairs(main.warnings) do ns.Debug(w) end
  if rot then for _, w in ipairs(rot.warnings) do ns.Debug(w) end end

  ns.activeName, ns.activeAuto, ns.activeWhy = name, auto, why
  ns.Debug("rebuilt (" .. tostring(reason) .. ")")
  ns.HelperReset()
  ns.HelperRefresh()
  if ns.Editor and ns.Editor.OnRebuilt then ns.Editor.OnRebuilt() end
end

function ns.OnCombatEnd()
  if ns.syncAfterCombat then
    ns.syncAfterCombat = false
    ns.SyncKeyDown()
  end
  if ns.bindAfterCombat then ns.ApplyBindings() end
  if ns.migrateBindsAfterCombat then ns.MigrateOldKeybinds() end
  ns.rebuildAfterCombat = false
  ns.Rebuild("combat ended")   -- also restarts both sequences at the opener
end

function ns.ResetSequence()
  if InCombatLockdown() then
    ns.Print("The sequence resets by itself when combat ends.")
    return
  end
  for _, b in ipairs(ns.allButtons) do b:SetAttribute("idx", 1) end
  ns.HelperReset()
  ns.HelperRefresh()
  ns.Print("Sequence restarted from the opener.")
end

function ns.PrintSequence(comp, title, isAoE)
  if not comp or #comp.steps == 0 then
    ns.Print(title .. ": no steps (no rotation, or no known spells yet).")
    return
  end
  local note = (isAoE and comp.aoeFallback) and " (no [aoe] section, using [loop])" or ""
  ns.Print(("%s - %s%s"):format(title, ns.activeName or "?", note))
  if comp.pull then
    ns.Print(("  0. |cffff8800pull|r %s (first press while out of combat)"):format(comp.pull))
  end
  if comp.prefix and #comp.prefix > 0 then
    ns.Print("  every press: " .. table.concat(comp.prefix, " ; "))
  end
  for i, st in ipairs(comp.steps) do
    local tag = (i == comp.loopStart and comp.loopCount > 0) and "|cff00ff00loop>|r " or ""
    if st.kind == "opener" then tag = "|cffffd100open|r " end
    ns.Print(("  %d. %s%s"):format(i, tag, st.label))
  end
end

---------------------------------------------------------------------------
-- /tac test: everything needed to diagnose "it cycles but doesn't cast"
---------------------------------------------------------------------------

function ns.Diagnose()
  local P = ns.Print
  local build = GetBuildInfo and select(4, GetBuildInfo())
  P(("diagnostics - Tactara %s, game interface %s"):format(ns.VERSION, tostring(build)))
  P(("  key-down setting (ActionButtonUseKeyDown): %s"):format(ns.cvarKeyDown and "ON" or "OFF"))
  P(("  Tactara fires on: %s%s"):format(ns.useKeyDown and "key down (always)" or "key up",
    (not ns.useKeyDown and ns.cvarKeyDown) and " |cffff5555- won't cast while the game setting is ON; use /tac keydown auto|r" or ""))
  for _, b in ipairs({ ns.mainButton, ns.aoeButton }) do
    local label = ns.IsAoEButton(b) and "AoE" or "Main"
    local key1, key2
    if GetBindingKey then key1, key2 = GetBindingKey("CLICK " .. b:GetName() .. ":LeftButton") end
    local keys = key1 and (key1 .. (key2 and (", " .. key2) or "")) or "none"
    P(("  %s key binding: %s | %d steps | next step %s | pressAndHold=%s")
      :format(label, keys, b:GetAttribute("numSteps") or 0, tostring(b:GetAttribute("idx")),
        tostring(b:GetAttribute("pressAndHoldAction"))))
  end
  P(("  Tactara keys (/tac bind): main %s, AoE %s, interrupt %s"):format(ns.KeyLabel("main"), ns.KeyLabel("aoe"), ns.KeyLabel("interrupt")))
  local u = ns.UtilityPicks()
  P(("  interrupts %s (target: %s) | defensives %s | your health: %s")
    :format(TactaraCharDB.interrupts and "ON" or "OFF", tostring(u.castState or "-"),
      TactaraCharDB.defensives and "ON" or "OFF", ns.PlayerHealthPct() and (math.floor(ns.PlayerHealthPct()) .. "%") or "hidden"))
  P("  " .. ns.HelperDiagnose())
  local known, missing = ns.RotationSpells()
  P(("  rotation spells you know: %d of %d (/tac spells for the list)"):format(#known, #known + #missing))
  P("  build: " .. ns.BuildSummary())
  P(("  rotation: %s (%s) | red error text while pressing: %s | debug: %s")
    :format(tostring(ns.activeName), tostring(ns.activeWhy), TactaraDB.hideErrors and "hidden" or "shown", TactaraDB.debug and "on" or "off"))
  P("  Tip: /tac debug, then press the button on a mob. Chat shows each press, each cast sent, and each error.")
end

---------------------------------------------------------------------------
-- /tac spells: which rotation spells Tactara sees as learned
---------------------------------------------------------------------------

function ns.RotationSpells()
  local rot = ns.activeName and ns.Parse(ns.GetRotationText(ns.activeName))
  local known, missing, seen = {}, {}, {}
  if not rot then return known, missing end
  if not InCombatLockdown() then ns.ClearKnownCache() end
  local function addLine(line)
    if not line.spells then return end
    for _, s in ipairs(line.spells) do
      if not seen[s] then
        seen[s] = true
        if ns.IsKnown(s) then known[#known + 1] = s else missing[#missing + 1] = s end
      end
    end
  end
  for _, line in ipairs(rot.sections.keypress) do addLine(line) end
  for _, key in ipairs({ "opener", "loop", "aoeopener", "aoe" }) do
    for _, step in ipairs(rot.sections[key]) do
      for _, line in ipairs(step.lines) do addLine(line) end
    end
  end
  return known, missing
end

function ns.ReportSpells()
  if not ns.activeName then
    ns.Print("No active rotation.")
    return
  end
  local known, missing = ns.RotationSpells()
  ns.Print(("%s - spells in use (%d): |cff00ff00%s|r"):format(ns.activeName, #known,
    #known > 0 and table.concat(known, ", ") or "none"))
  if #missing > 0 then
    ns.Print(("Not learned yet (%d): |cffaaaaaa%s|r"):format(#missing, table.concat(missing, ", ")))
    ns.Print("New spells are bought from your class trainer (some come from talents or class quests). "
      .. "Tactara adds each one as soon as you learn it.")
  end
end

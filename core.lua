-- dummy frame for event subscriptions
local frame = CreateFrame("Frame")

-- this avoids lookups in the '_G' table, improves performance for functions that are used in hot code paths
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local UnitGUID= UnitGUID

-- forward declarations
local playerGuid

-- store values once on login
local function StoreStaticLoginValues()
  playerGuid = UnitGUID("player")
end

local function HandleLoadingScreen()
  if IsInInstance() then
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  else
    frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  end
end

-- announce successful interrupts when in a group
local function ProcessCombatLogEvent()
  local _,
        type,
        _,
        sourceGuid,
        _,
        _,
        _,
        _,
        destName,
        destFlags,
        _,
        _,
        _,
        _,
        spellId,
        spellName = CombatLogGetCurrentEventInfo()
  local doneBySelf = sourceGuid == playerGuid
  local petGuid = UnitGUID("pet")
  local doneByPet = petGuid and (sourceGuid == petGuid)

  if (type == "SPELL_INTERRUPT") and (doneBySelf or doneByPet) then
    local isEnemy = bit.band(destFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) > 0
    local isInBG = false

    for bgId = 1, GetMaxBattlefieldID() do
      local bgStatus, _, _, _, _, _, _, _, _, bgType = GetBattlefieldStatus(bgId)
      if bgStatus == "active" and bgType == "BATTLEGROUND" then
        isInBG = true
        break
      end
    end

    if IsInGroup() and not isInBG and isEnemy then
      local prefix = "Kicked"

      -- workaround when spellId is 0 (in Classic WoW some spellId return values were removed on purpose)
      local message = spellId ~= 0 and
        format("%s |cff71d5ff|Hspell:%d:0|h[%s]|h|r @ %s!", prefix, spellId, spellName, destName) or
        format("%s \"%s\" @ %s!", prefix, spellName, destName)

      SendChatMessage(message)
    end
  end
end

local function EnableSoundFor(seconds)
  -- if the sound is disabled...
  if (GetCVar("Sound_EnableAllSound") == "0") then
    -- ...enable it temporarily...
    SetCVar("Sound_EnableAllSound", "1")
    -- ...but also schedule a disable after _time_ seconds to restore the previous state
    C_Timer.After(seconds, function() SetCVar("Sound_EnableAllSound", "0") end)
  end

  -- Set volume to full, but restore afterwards
  local currentVolume = GetCVar("Sound_MasterVolume")
  GetCVar("Sound_MasterVolume", "1")
  C_Timer.After(seconds, function() SetCVar("Sound_MasterVolume", currentVolume) end)
end

-- plays a warning sound when the idle message is displayed
local function CheckForLogout(message)
  if message == IDLE_MESSAGE then
    EnableSoundFor(8)
    PlaySoundFile("Sound\\Character\\Gnome\\GnomeMaleChooChoo01.ogg", "Master")
  end
end

-- now that everything is defined, register for events
local eventHandlers = {
  PLAYER_LOGIN = StoreStaticLoginValues,
  PLAYER_ENTERING_WORLD = HandleLoadingScreen,
  CHAT_MSG_SYSTEM = CheckForLogout,
  COMBAT_LOG_EVENT_UNFILTERED = ProcessCombatLogEvent,
}

for event in pairs(eventHandlers) do
  -- COMBAT_LOG_EVENT_UNFILTERED will be subscribed dynamically
  if event ~= COMBAT_LOG_EVENT_UNFILTERED then
    frame:RegisterEvent(event)
  end
end
frame:SetScript("OnEvent", function (_, event, ...) eventHandlers[event](...) end)



-- Global functions
if TsengTools == nil then TsengTools = {} end

local function IsItemOnCooldown(itemId)
  return GetItemCooldown(itemId) > 0
end

local function IsSpellOnCooldown(spellId)
  return GetSpellCooldown(spellId) > 0
end

local function IsCCed()
  return C_LossOfControl.GetActiveLossOfControlDataCount() > 0
end

local function HasResourcesForSpell(spellId)
  for _, data in pairs(GetSpellPowerCost(spellId)) do
    if UnitPower("player", data.type) < data.cost then
      return false
    end
  end

  return true
end

function TsengTools.PowerConsume(itemId, spell)
  local _, _, _, _, _, _, spellId = GetSpellInfo(spell)

  if IsItemOnCooldown(itemId) or IsSpellOnCooldown(spellId) or IsCCed() or not HasResourcesForSpell(spellId) then
    SetCVar("autoUnshift", 0)
  end
end

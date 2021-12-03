-- dummy frame for event subscriptions
local frame = CreateFrame("Frame")

-- this avoids lookups in the '_G' table, improves performance for functions that are used in hot code paths
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local GetBattlefieldStatus = GetBattlefieldStatus
local IsInGroup = IsInGroup
local SendChatMessage = SendChatMessage
local UnitIsEnemy = UnitIsEnemy

-- forward declarations
local playerGuid, petGuid, maxBattleFieldId

-- store values once on login
local function StoreStaticLoginValues()
  playerGuid = UnitGUID("player")
  petGuid = UnitGUID("pet")
  maxBattleFieldId = GetMaxBattlefieldID()
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
  local _, type, _, sourceGuid, name, _, _, _, _, _, _, _, _, _, spellId, spellName = CombatLogGetCurrentEventInfo()
  local doneBySelf = sourceGuid == playerGuid
  local doneByPet = petGuid and (sourceGuid == petGuid)
  local isInBG = false

  for bgId = 1, maxBattleFieldId, 1 do
    if GetBattlefieldStatus() == "active" then
      isInBG = true
    end
  end

  local isEnemy = UnitIsEnemy("player", name)

  if (type == "SPELL_INTERRUPT" or type == "SPELL_DISPEL") and (doneBySelf or doneByPet) and IsInGroup() and not isInBG and isEnemy then
    local prefix = type == "SPELL_INTERRUPT" and "Interrupted" or "Purged"

    -- workaround when spellId is 0 (in Classic WoW spellId return values were removed on purpose)
    local message = spellId ~= 0 and
      format("%s |cff71d5ff|Hspell:%d:0|h[%s]|h|r!", prefix, spellId, spellName) or
      format("%s \"%s\"!", prefix, spellName)

    SendChatMessage(message)
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

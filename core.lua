-- dummy frame for event subscriptions
local frame = CreateFrame("Frame")

-- this avoids lookups in the '_G' table, improves performance for functions that are used in hot code paths
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo

-- forward declarations
local playerGuid, petGuid

-- store player and pet guids once on login
local function StoreGuids()
  playerGuid = UnitGUID("player")
  petGuid = UnitGUID("pet")
end

local function HandleLoadingScreen()
  if IsInInstance() and not frame:IsEventRegistered("COMBAT_LOG_EVENT_UNFILTERED") then
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  elseif frame:IsEventRegistered("COMBAT_LOG_EVENT_UNFILTERED") then
    frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  end
end

-- announce successful interrupts when in a group
local function ProcessCombatLogEvent()
  local _, type, _, sourceGuid, _, _, _, _, _, _, _, _, _, _, spellId, spellName = CombatLogGetCurrentEventInfo()
  local interruptedBySelf = sourceGuid == playerGuid
  local interruptedByPet = petGuid and (sourceGuid == petGuid)

  if (type == "SPELL_INTERRUPT") and (sinterruptedBySelf or interruptedByPet) and IsInGroup() then
    -- workaround when spellId is 0 (in Classic WoW spellId return values were removed on purpose)
    local message = spellId ~= 0 and
      format("Interrupted |cff71d5ff|Hspell:%d:0|h[%s]|h|r!", spellId, spellName) or
      format("Interrupted \"%s\"!", spellName)

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
  PLAYER_LOGIN = StoreGuids,
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

require "Window"
require "ApolloTimer"

local VikingClassResources = {}

-- local knEngineerPetGroupId = 298 -- TODO Hardcoded engineer pet grouping

-- local ktEngineerStanceToShortString =
-- {
--   [0] = "",
--   [1] = Apollo.GetString("EngineerResource_Aggro"),
--   [2] = Apollo.GetString("EngineerResource_Defend"),
--   [3] = Apollo.GetString("EngineerResource_Passive"),
--   [4] = Apollo.GetString("EngineerResource_Assist"),
--   [5] = Apollo.GetString("EngineerResource_Stay"),
-- }

-- medic 4, warrior 1, stalker 5, engineer 2
local tClassName = {
  [1] = "Warrior",
  [2] = "Engineer",
  [3] = "Esper",
  [4] = "Medic",
  [5] = "Stalker",
  [7] = "Spellslinger"
}

local tResourceType = {
  [1] = 1,
  [2] = 1,
  [3] = 1,
  [4] = 1,
  [5] = 3,
  [7] = 4
}

function VikingClassResources:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function VikingClassResources:Init()
    Apollo.RegisterAddon(self, nil, nil, {"VikingActionBarFrame"})
end

function VikingClassResources:OnLoad()
  self.xmlDoc = XmlDoc.CreateFromFile("VikingClassResources.xml")
  self.xmlDoc:RegisterCallback("OnDocumentReady", self)

  Apollo.RegisterEventHandler("ActionBarLoaded", "OnRequiredFlagsChanged", self)


  Apollo.LoadSprites("VikingClassResourcesSprites.xml")
end

function VikingClassResources:OnDocumentReady()
  if self.xmlDoc == nil then
    return
  end

  self.bDocLoaded = true
  self:OnRequiredFlagsChanged()
end

function VikingClassResources:OnRequiredFlagsChanged()
  if g_wndActionBarResources and self.bDocLoaded then
    if GameLib.GetPlayerUnit() then
      self:OnCharacterCreated()
    else
      Apollo.RegisterEventHandler("CharacterCreated", "OnCharacterCreated", self)
    end
  end
end


function VikingClassResources:OnCharacterCreated()
  local unitPlayer = GameLib.GetPlayerUnit()
  if not unitPlayer then
    return
  end

  self.eClassID =  unitPlayer:GetClassId()

  self:CreateClassResources()

end


function VikingClassResources:CreateClassResources()

  Apollo.RegisterEventHandler("VarChange_FrameCount",     "OnUpdateTimer", self)
  Apollo.RegisterEventHandler("UnitEnteredCombat",        "OnEnteredCombat", self)
  Apollo.RegisterTimerHandler("OutOfCombatFade",          "OnOutOfCombatFade", self)

  self.wndMain = Apollo.LoadForm(self.xmlDoc, "VikingClassResourceForm", g_wndActionBarResources, self)
  self.wndMain:ToFront()
  --
end


function VikingClassResources:ResizeResourceNodes(nResourceMax)
  local nOffsets = {}
  nOffsets.nOL, nOffsets.nOT, nOffsets.nOR, nOffsets.nOB = self.wndMain:GetAnchorOffsets()

  local nWidth = (nOffsets.nOR - nOffsets.nOL) / nResourceMax

  for i = 1, nResourceMax do
    local p       = i-1
    local wndNode = self.wndMain:FindChild("Node" .. i)
    wndNode:SetAnchorPoints(0, 0, 0, 1)
    wndNode:SetAnchorOffsets(nWidth * p, 0, nWidth * i, 0)
  end

end

function VikingClassResources:OnUpdateTimer()

  local unitPlayer = GameLib.GetPlayerUnit()
  local className  = tClassName[self.eClassID]
  local resourceID = tResourceType[self.eClassID]


  local nResourceMax     = unitPlayer:GetMaxResource(resourceID)
  local nResourceCurrent = unitPlayer:GetResource(resourceID)
  self["Update" .. className .. "Resources"](self, unitPlayer, nResourceMax, nResourceCurrent)

end


function VikingClassResources:UpdateProgressBar(unitPlayer, nResourceMax, nResourceCurrent)
  local nProgressCurrent = nResourceCurrent and nResourceCurrent or math.floor(unitPlayer:GetMana())
  local nProgressMax     = nResourceMax and nResourceMax or math.floor(unitPlayer:GetMaxMana())
  local className        = tClassName[self.eClassID]

  self.wndMain:FindChild("PrimaryProgressBar"):SetMax(nProgressMax)
  self.wndMain:FindChild("PrimaryProgressBar"):SetProgress(nProgressCurrent)
  self.wndMain:FindChild("PrimaryProgressBar"):SetTooltip(String_GetWeaselString(Apollo.GetString( className .. "Resource_FocusTooltip" ), nProgressCurrent, nProgressMax))
  self.wndMain:FindChild("PrimaryProgressText"):SetText(nProgressCurrent == nProgressMax and "" or (math.floor(nProgressCurrent / nProgressMax * 100).."%"))

end


--
-- WARRIOR


function VikingClassResources:UpdateWarriorResources(unitPlayer, nResourceMax, nResourceCurrent)
  local bOverdrive           = GameLib.IsOverdriveActive()
  local wndPrimaryProgress   = self.wndMain:FindChild("PrimaryProgressBar")
  local wndSecondaryProgress = self.wndMain:FindChild("SecondaryProgressBar")
  local unitPlayer           = GameLib.GetPlayerUnit()

  self:UpdateProgressBar(unitPlayer, nResourceMax, nResourceCurrent)

  if bOverdrive and not self.bOverDriveActive then
    self.bOverDriveActive = true
    wndSecondaryProgress:SetMax(100)
    wndSecondaryProgress:SetProgress(100)

    self.WarriorOverdriveTick = ApolloTimer.Create(0.01, true, "OnWarriorOverdriveTick", self)
    self.WarriorOverdriveDone = ApolloTimer.Create(8, false, "OnWarriorOverdriveDone", self)
  end

  wndSecondaryProgress:Show(self.bOverDriveActive)
  wndPrimaryProgress:Show(not self.bOverDriveActive)


  self.wndMain:FindChild("InnateGlow"):Show(bOverdrive)

end

function VikingClassResources:OnWarriorOverdriveTick()
  self.wndMain:FindChild("SecondaryProgressBar"):SetProgress(0, 8)
end

function VikingClassResources:OnWarriorOverdriveDone()
  self.bOverDriveActive = false

  self.WarriorOverdriveTick:Stop()
end



--
-- ENGINEER

function VikingClassResources:UpdateEngineerResources(unitPlayer, nResourceMax, nResourceCurrent)
  self:UpdateProgressBar(unitPlayer, nResourceMax, nResourceCurrent)
  self:ShowInnate()

end


--
-- ESPER

function VikingClassResources:UpdateEsperResources(unitPlayer, nResourceMax, nResourceCurrent)

  self:UpdateProgressBar(unitPlayer)
  self:ResizeResourceNodes(nResourceMax)

  for i = 1, nResourceMax do
    local nShow = nResourceCurrent >= i and 1 or 0

    local wndNodeProgress = self.wndMain:FindChild("Node"..i):FindChild("NodeProgress")
    wndNodeProgress:SetMax(nShow)
    wndNodeProgress:SetProgress(nShow)
  end

  self:ShowInnate()
end


--
-- MEDIC

function VikingClassResources:UpdateMedicResources(unitPlayer, nResourceMax, nResourceCurrent)

  local nPartialMax   = 3
  local unitPlayer    = GameLib.GetPlayerUnit()
  local nPartialCount = 0
  self:UpdateProgressBar(unitPlayer)


  tBuffs = unitPlayer:GetBuffs()

  for idx, tCurrBuffData in pairs(tBuffs.arBeneficial or {}) do
    if tCurrBuffData.splEffect:GetId() == 42569 then
      nPartialCount = tCurrBuffData.nCount
      break
    end
  end

  for i = 1, nResourceMax do
    local nProgress = nPartialMax
    if i-1 < nResourceCurrent then
      nProgress = nPartialMax
    elseif i-1 == nResourceCurrent then
      nProgress = nPartialCount
    else
      nProgress = 0
    end

    local wndNodeProgress = self.wndMain:FindChild("Node"..i):FindChild("NodeProgress")
    wndNodeProgress:SetMax(nPartialMax)
    wndNodeProgress:SetProgress(nProgress)

    self:ShowInnate()
  end
end



--
-- STALKER

function VikingClassResources:UpdateStalkerResources(unitPlayer, nResourceMax, nResourceCurrent)
  self:UpdateProgressBar(unitPlayer, nResourceMax, nResourceCurrent)
  self:ShowInnate()
end



--
-- SPELLSLINGER

function VikingClassResources:UpdateSpellslingerResources(unitPlayer, nResourceMax, nResourceCurrent)

  local nNodes            = 4
  local unitPlayer        = GameLib.GetPlayerUnit()
  local nNodeProgressSize = nResourceMax / nNodes
  self:UpdateProgressBar(unitPlayer)

  for i = 1, nNodes do
    local nPartialProgress = nResourceCurrent - (nNodeProgressSize * (i - 1))
    local wndNodeProgress = self.wndMain:FindChild("Node"..i):FindChild("NodeProgress")
    wndNodeProgress:SetMax(nNodeProgressSize)
    wndNodeProgress:SetProgress(nPartialProgress, nResourceMax)
  end

  self:ShowInnate()
end


function VikingClassResources:OnEnteredCombat()
end


function VikingClassResources:OnOutOfCombatFade()
end


-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function VikingClassResources:ShowInnate()
  local bInnate = GameLib.IsCurrentInnateAbilityActive()
  self.wndMain:FindChild("InnateGlow"):Show(bInnate)
end

function VikingClassResources:HelperToggleVisibiltyPreferences(wndParent, unitPlayer)
  -- TODO: REFACTOR: Only need to update this on Combat Enter/Exit
  --Toggle Visibility based on ui preference
  local nVisibility = Apollo.GetConsoleVariable("hud.ResourceBarDisplay")

  if nVisibility == 2 then --always off
    wndParent:Show(false)
  elseif nVisibility == 3 then --on in combat
    wndParent:Show(unitPlayer:IsInCombat())
  elseif nVisibility == 4 then --on out of combat
    wndParent:Show(not unitPlayer:IsInCombat())
  else
    wndParent:Show(true)
  end
end

function VikingClassResources:OnGeneratePetCommandTooltip(wndControl, wndHandler, eType, arg1, arg2)
  local xml = nil
  if eType == Tooltip.TooltipGenerateType_PetCommand then
    xml = XmlDoc.new()
    xml:AddLine(arg2)
    wndControl:SetTooltipDoc(xml)
  elseif eType == Tooltip.TooltipGenerateType_Spell then
    xml = XmlDoc.new()
    if arg1 ~= nil then
      xml:AddLine(arg1:GetFlavor())
    end
    wndControl:SetTooltipDoc(xml)
  end
end

local VikingClassResourcesInst = VikingClassResources:new()
VikingClassResourcesInst:Init()

-- IRememberYou addon (IRY)
-- Allows player to rate all players he ever met.

-- Initialize object
IRY=ZO_Object:Subclass()

local IRY_debug=true
local version=0.1

-- Util functions
-- debug
local function debug(text)
	if not IRY_debug then return end
	d(text)
end
-- end of Util functions

-- Addon onload
function IRY_OnLoad(eventCode,AddonName)
	if AddonName~="IRememberYou" then return end
	debug("Addon loaded")
	
	IRY_Obj = IRY:New()
	IRY:LoadSavedVars()

	-- chat commanhs
	SLASH_COMMANDS["/iry"] = IRY.commandHandler
end

-- Event functions
-- EVENT_RETICLE_TARGET_CHANGED
local function AddReticle()
	unitTag="reticleover"

	if IRY:GetPlayerInfo(unitTag) then
		alliance,name,level,vetrank=IRY:GetPlayerInfo(unitTag)
		IRY:AddPlayer(alliance,name,level,vetrank)
	end
end

local function AddGroup()
	debug("AddGroup called")

	for i=1,GetGroupSize() do
		unitTag=GetGroupUnitTagByIndex(i)

		if IRY:GetPlayerInfo(unitTag) then
			alliance,name,level,vetrank=IRY:GetPlayerInfo(unitTag)
			IRY:AddPlayer(alliance,name,level,vetrank)
		end
	end
end



-- end of Event functions

-- Core functions
function IRY:New()
	debug("New called")
	local obj = ZO_Object.New(self)
	obj:Initialize(self)
	return obj
end

-- initialize
function IRY:Initialize(self)
	debug("Initialize called")
	self.control=self
end

function IRY:LoadSavedVars()
	debug("LoadSavedVars called")
	local default_playerDatabase={
		data={},
		index={},
		counter = 0
	}

	self.playerDatabase = ZO_SavedVars:NewAccountWide("IRY_SavedVars", version, "playerDatabase", default_playerDatabase, nil)
end

-- chat commands
function IRY.commandHandler(text)
	if text=="cls" then 
		IRY.cls()
	else 
		d("==IRY commands: ==")
		d("==/iry cls - clear all data: ==")
	end
end

function IRY.cls()
	self.playerDatabase={
		data={},
		index={},
		counter = 0
	}

	ReloadUI()
end
-- end of chat commands

-- get info about target
function IRY:GetPlayerInfo(unitTag)
	local unitType = GetUnitType(unitTag)
	local name = GetUnitName(unitTag)

	if unitType~=UNIT_TYPE_PLAYER then return false end
	if name=="" then return false end

	local level = GetUnitLevel(unitTag)
	local vetrank = GetUnitVeteranRank(unitTag)
	local alliance = GetUnitAlliance(unitTag)

	return alliance,name,level,vetrank
end

-- add player to database
function IRY:AddPlayer(alliance,name,level,vetrank)

	debug(tostring(alliance)..", "..tostring(name)..", "..tostring(level)..", "..tostring(vetrank))

	-- non-updateable info
	-- add this player to index table
	if self.playerDatabase.data[name]==nil then
		self.playerDatabase.index[#self.playerDatabase.index+1]=name
		self.playerDatabase.counter=self.playerDatabase.counter+1
		self.playerDatabase.data[name]={
			["id"]=self.playerDatabase.counter,
			["rate"]=-1
		}
	end

	-- updatable info
	-- update info even if table already contains info about this player
	local saved_id=self.playerDatabase.data[name].id
	local saved_rate=self.playerDatabase.data[name].rate
	self.playerDatabase.data[name]={
		["id"]=saved_id,
		["alliance"]=alliance,
		["level"]=level,
		["vetrank"]=vetrank,
		["rate"]=saved_rate
	}
end

-- Register Events

-- Target changed
EVENT_MANAGER:RegisterForEvent("IRememberYou", EVENT_RETICLE_TARGET_CHANGED, AddReticle)

-- Group 
-- someone (except me) joined
EVENT_MANAGER:RegisterForEvent("IRememberYou", EVENT_GROUP_MEMBER_JOINED, AddGroup)
-- someone left
EVENT_MANAGER:RegisterForEvent("IRememberYou", EVENT_GROUP_MEMBER_LEFT, AddGroup)
-- invite recived
EVENT_MANAGER:RegisterForEvent("IRememberYou", EVENT_GROUP_INVITE_RECEIVED, AddGroup)
-- role changed
EVENT_MANAGER:RegisterForEvent("IRememberYou", EVENT_GROUP_MEMBER_ROLES_CHANGED, AddGroup)

EVENT_MANAGER:RegisterForEvent("IRememberYou", EVENT_ADD_ON_LOADED, IRY_OnLoad)


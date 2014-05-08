-- IRememberYou addon (IRY)
-- Allows player to rate all players he ever met.

-- Initialize object
IRY=ZO_Object:Subclass()

local IRY_debug=true
local version=0.2

-- Util functions
-- debug
local function debug(text)
	if not IRY_debug then return end
	d(text)
end

local function compareByName(a,b)
	-- debug("Key: "..tostring(k))
	-- for k,v in pairs(a) do
	-- 	debug("Key: "..tostring(v))
	-- end
	return a["name"]<b["name"]
end
-- end of Util functions

-- Addon onload
function IRY_OnLoad(eventCode,AddonName)
	if AddonName~="IRememberYou" then return end
	debug("Addon loaded")
	
	IRY_Obj = IRY:New()


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
	self.rows={
		left={},
		right={}
	}

-- Greate rows
	-- left page
	for i=1,18 do
		self.rows[i] = CreateControlFromVirtual("IRY_BookRow", IRY_Book, "IRY_BookRow_Virtual",i)
		self.rows[i]:SetAnchor(RIGHT,IRY_Book,CENTER,0,-340+(35*i))
		self.rows[i].stars={}
		-- stars
		for j=1,5 do
			self.rows[i].stars[j] = CreateControlFromVirtual(("IRY_BookRow"..i.."Star"), self.rows[i], "IRY_Star_Virtual",j)
			self.rows[i].stars[j]:SetAnchor(LEFT,self.rows[i],LEFT,250-30+(30*j),0)
			self.rows[i].stars[j].starnumber=j
		end
	end

	-- right page
	for i=19,36 do
		self.rows[i] = CreateControlFromVirtual("IRY_BookRow", IRY_Book, "IRY_BookRow_Virtual",i)
		self.rows[i]:SetAnchor(LEFT,IRY_Book,CENTER,20,-970+(35*i))
		self.rows[i].stars={}
		-- stars
		for j=1,5 do
			self.rows[i].stars[j] = CreateControlFromVirtual(("IRY_BookRow"..i.."Star"), self.rows[i], "IRY_Star_Virtual",j)
			self.rows[i].stars[j]:SetAnchor(LEFT,self.rows[i],LEFT,250-30+(30*j),0)
			self.rows[i].stars[j].starnumber=j
		end
	end	

	-- load data
	IRY:LoadSavedVars()

	-- create page switchers

	IRY:SwitchPage(1)
end

function IRY:LoadSavedVars()
	debug("LoadSavedVars called")
	local default_playerDatabase={
		data={}
	}

	self.playerDatabase = ZO_SavedVars:NewAccountWide("IRY_SavedVars", version, "playerDatabase", default_playerDatabase, nil)
end

-- chat commands
function IRY.commandHandler(text)
	text = string.lower(text)
	if text=="cls" then 
		IRY:cls()
	else 
		d("==IRY commands: ==")
		d("/iry cls - clear all data")
	end
end

-- clear addon data
function IRY:cls()
	self.playerDatabase.data={}

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

	local playerid=false
	local saved_rate

	debug(tostring(alliance)..", "..tostring(name)..", "..tostring(level)..", "..tostring(vetrank))

	-- search for database
	for i=1,#self.playerDatabase.data do
		if self.playerDatabase.data[i].name==name then
			playerid=i
		end
	end

	if playerid then
		-- if this player is already at our DB -> update info
		saved_rate=self.playerDatabase.data[playerid].rate
		self.playerDatabase.data[playerid]={
			["name"]=name,
			["alliance"]=alliance,
			["level"]=level,
			["vetrank"]=vetrank,
			["rate"]=saved_rate
		}
	else
		-- if there's no such player -> add player data
		self.playerDatabase.data[#self.playerDatabase.data+1]={
			["name"]=name,
			["alliance"]=alliance,
			["level"]=level,
			["vetrank"]=vetrank,
			["rate"]=-1
		}
	end

	-- sort table by name
	table.sort(self.playerDatabase.data, compareByName)

	IRY:SwitchPage(IRY_Book.currentpage)
end

-- Allows playername or #table
function IRY:RemovePlayer(...)
	local arg={...}
	local removed=false
	if #arg>1 then
		debug("Too many RemovePlayer attributes")
		return false 
	end

	if type(arg[1])=="number" then
		local id=arg[1]
		for k,v in pairs(self.playerDatabase.data) do
			if k==id then
				debug ("Player "..v.name.." with ID "..k.." was removed from db")
				-- self.playerDatabase.data[k]=nil
				table.remove (self.playerDatabase.data,k)
				removed = true
			end
		end
	elseif type(arg[1])=="string" then
		local name=arg[1]
		for k,v in pairs(self.playerDatabase.data) do
			if v.name==name then
				debug ("Player "..v.name.." with ID "..k.." was removed from db")
				-- self.playerDatabase.data[k]=nil
				table.remove (self.playerDatabase.data,k)
				removed = true
			end
		end
	else
		debug("Wrong RemovePlayer attribute type")
	end

	-- IRY:RecountIndex()

	return removed
end

-- Allows playername or id, rate
function IRY:RatePlayer(id,rate)
	local rated=false

	if type(id)=="number" and type(rate)=="number" then
		for k,v in pairs(self.playerDatabase.data) do
			if k==id then
				debug ("Player "..v.name.." with ID "..k.." was rated for: "..rate)
				v.rate=rate
				rated=true
			end
		end
	else
		debug("Wrong attr type")
		return rated
	end
end

-- Switch page. Form 1
function IRY:SwitchPage(pagen)
	local maxpages=math.ceil(#self.playerDatabase.data/36) or 0

	-- hide/show Prev button
	if pagen>1 then
		IRY_BookKeyStripMouseButtonsPreviousPage:SetHidden(false)
	else
		IRY_BookKeyStripMouseButtonsPreviousPage:SetHidden(true)
	end

	-- hide/show Prev button
	if pagen<maxpages then
		IRY_BookKeyStripMouseButtonsNextPage:SetHidden(false)
	else
		IRY_BookKeyStripMouseButtonsNextPage:SetHidden(true)
	end

	debug("pagen: "..pagen)
	debug("maxpages: "..maxpages)

	if pagen<1 or pagen>maxpages then return end

	IRY_Book.currentpage=pagen

	pagen=pagen-1

	for i=1,36 do
		IRY:FillRow(i,i+(pagen*36))
	end
end

-- Fill row
function IRY:FillRow(RowID,PlayerId)
	if RowID<1 or RowID>36 then debug("Wrong Row ID") return false end
	local basename=self.rows[RowID]:GetName()

	if not self.playerDatabase.data[PlayerId] then
		self.rows[RowID]:SetHidden(true)
		return
	end

	-- hide if no such PlayerId
	if self.playerDatabase.data[PlayerId] then
		self.rows[RowID]:SetHidden(false)
	else
		self.rows[RowID]:SetHidden(true)
		return
	end

-- Apply name
	if self.playerDatabase.data[PlayerId].name then
		_G[basename.."Name"]:SetText(self.playerDatabase.data[PlayerId].name)
	else
		debug ("No Name for id: "..PlayerId)
	end

-- Apply Alliance
	if self.playerDatabase.data[PlayerId].alliance then
		_G[basename.."Alliance"]:SetTexture(GetAllianceBannerIcon(self.playerDatabase.data[PlayerId].alliance))
	else
		debug ("No Alliance for id: "..PlayerId)
	end

-- Apply Rate
	if self.playerDatabase.data[PlayerId].rate then
		local rate=self.playerDatabase.data[PlayerId].rate
		for i=1,rate do
			_G[basename].stars[i]:SetColor(0,1,0,1)
		end
	else
		debug ("No Rate for id: "..PlayerId)
	end

	self.rows[RowID].id=PlayerId
end

-- XML function
-- Apply star to row clicked
function IRY:ApplyStar(self)
	local id=(self:GetParent()).id
	local rate=self.starnumber

	debug("Player id: "..id)
	debug("Rate: "..rate)

	IRY:RatePlayer(id,rate)

	-- Update book
	IRY:SwitchPage(IRY_Book.currentpage)
end

-- XML function
-- Capture click on next/previous page
function IRY:SwitchPageClick(self, button)
	debug("Button clicked: "..button)

	local name=self:GetName()

	if button==1 and name=="IRY_BookKeyStripMouseButtonsPreviousPage" then
		IRY:SwitchPage(IRY_Book.currentpage-1)
	elseif button == 2 and name=="IRY_BookKeyStripMouseButtonsNextPage" then
		IRY:SwitchPage(IRY_Book.currentpage+1)
	end
end


-- Register Events

-- Addon loaded
EVENT_MANAGER:RegisterForEvent("IRememberYou", EVENT_ADD_ON_LOADED, IRY_OnLoad)

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
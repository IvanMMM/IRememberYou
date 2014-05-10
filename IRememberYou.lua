-- IRememberYou addon (IRY)
-- Allows player to rate all players he ever met.

-- Initialize object
IRY=ZO_Object:Subclass()

local IRY_debug=true
local version=0.35

-- Util functions
-- debug
local function debug(text)
	if not IRY_debug then return end
	d(text)
end

local function compareByName(a,b)
	if not a["name"] or not a["name"] then return end
	return a["name"]<b["name"]
end
-- end of Util functions

-- Addon onload
function IRY_OnLoad(eventCode,AddonName)
	if AddonName~="IRememberYou" then return end
	debug("Addon loaded")
	IRY_Book.currentpage=1

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

local function HookChatLinkClicked(self,linkData, linkText, button, ...)

	local function AddPlayerFromMenu()
		IRY:AddPlayer(GetUnitAlliance("player"),name,0,0)
	end

	-- thx Kentarii
	local linkType, _, _ = zo_strsplit(":", linkData)

	local start,stop=string.find(linkData,":.+%[")
	local name=string.sub(linkData,start+1,stop-1)

	debug("linkData: "..tostring(linkData))
	debug("linkType: "..tostring(linkType))
	debug("name: "..tostring(name))
	debug("Self: "..tostring(self:GetName()))
	debug("Parent: "..tostring((self:GetParent()):GetName()))

	-- add our menu only to player linktype

	if linkType ~= CHARACTER_LINK_TYPE and linkType~=DISPLAY_NAME_LINK_TYPE then return end


	-- Call original 
	ZO_ChatSystem_OnLinkClicked(linkData, linkText, button, ...)

	if button == 2 then
        ZO_Menu:SetHidden(true)
        AddMenuItem("Rate", AddPlayerFromMenu)

        ShowMenu(nil, 1)
    end

	-- We want our item added after all items. So, wait untill they are created. Littly hacky, but... :banana:
	-- zo_callLater(
	-- 	function () 
			-- ZO_Menu:SetHidden(true)
	-- 		d("added")

	-- 		AddMenuItem("Rate", AddPlayerFromMenu)

			-- ShowMenu(nil, 1)
	-- 		ZO_Menu:SetHeight(ZO_Menu:GetHeight()+22.3125)
 --   			ZO_Menu.height=ZO_Menu.height+22.3125

 --   			ZO_Menu:SetHidden(true)
 --   			ZO_Menu:SetHidden(false)

 --   			-- Интересно.
 --  			-- ZO_Menu_SelectItem(ZO_Menu.items[id].item)



	-- 	end
	-- , 1)
end

local function HookChatLink()

	debug("Unregistered: "..tostring(EVENT_MANAGER:UnregisterForEvent("IRememberYou", EVENT_PLAYER_ACTIVATED)))

	for i=1,#ZO_ChatWindow.container.windows do
		d("window handler: "..i)
		-- 
		-- ZO_PreHookHandler(ZO_ChatWindow.container.windows[i].buffer,"OnLinkClicked",HookChatLinkClicked)
		ZO_ChatWindow.container.windows[i].buffer:SetHandler("OnLinkClicked",HookChatLinkClicked)
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

-- Create rows
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

	--check if DB is not empty
	if #self.playerDatabase.data~=0 then
		IRY:SwitchPage(1)
	end

	-- search in progress
	IRY.searching=false

	-- Register handler on right button click
	-- ZO_ChatWindow:SetHandler("OnLinkClicked", function()
	-- 	d("Sth happend")
	-- end)

	-- Should work now




	-- WORK on all menu
	-- ZO_Menu:SetHandler("OnShow", function()
	-- 	d("Window showed")
	-- end)

	-- WORK on all menu
	-- ZO_Menu:SetHandler("OnUpdate", function()
	-- 	if not ZO_Menu:IsHidden() then
	-- 		d("Window showed")
	-- 	end
	-- end)

end

function IRY:LoadSavedVars()
	debug("LoadSavedVars called")
	local default_playerDatabase={
		data={}
	}

	self.playerDatabase = ZO_SavedVars:NewAccountWide("IRY_SavedVars", version, "playerDatabase", default_playerDatabase, nil)
	self.searchDatabase = {}
end

-- chat commands
function IRY.commandHandler(text)
	text = string.lower(text)
	if text=="cls" then 
		IRY:cls()
	elseif text=="" then
		IRY_Book:SetHidden(not IRY_Book:IsHidden())
	else 
		d("==IRY commands: ==")
		d("/iry - display/hide IRY book")
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

	-- Modify counters
	for i=1,18 do
		if not self.rows[i]:IsHidden() then
			IRY_BookCounterLeftPage:SetText(i+36*(IRY_Book.currentpage-1 or 1))
		end
	end

	local allrowshidden=true
	for i=19,36 do
		-- debug("Row "..i.."is hidden: "..tostring(self.rows[i]:IsHidden()))
		if not self.rows[i]:IsHidden() then
			IRY_BookCounterRightPage:SetText(i+36*(IRY_Book.currentpage-1 or 1))
			allrowshidden=false
		end
	end

	-- hide right counter if all rows are hidden
	if allrowshidden then
		IRY_BookCounterRightPage:SetHidden(true)
	else
		IRY_BookCounterRightPage:SetHidden(false)
	end


	IRY_BookCounterTotal:SetText(#self.playerDatabase.data)
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
		if rate~=-1 then
			for i=1,rate do
				_G[basename].stars[i]:SetColor(0,1,0,1)
			end
		else
			for i=1,5 do
				_G[basename].stars[i]:SetColor(1,0,0,1)
			end
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
function IRY:DropRate(self)
	local id=(self:GetParent()).id

	IRY:RatePlayer(id,-1)

	-- Update book
	IRY:SwitchPage(IRY_Book.currentpage)
	IRY:ApplyRealStars(self)
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

-- XML function
-- Highlight Stars OnMouseEnter
function IRY:HighhlightStars(self)
	local parent=self:GetParent()

	for i=1,self.starnumber do
		parent.stars[i]:SetColor(1,1,0,1)
	end

	for i=self.starnumber+1,1 do
		parent.stars[i]:SetColor(1,0,0,1)
	end
end

-- XML function
-- Apply current star value to this row
function IRY:ApplyRealStars(self)
	local parent=self:GetParent()
	local currentstars=IRY.playerDatabase.data[parent.id].rate

	-- debug("currentstars: "..currentstars)

	if currentstars>=1 and currentstars<=5 then
		for i=1,currentstars do
			parent.stars[i]:SetColor(0,1,0,1)
		end
		for i=currentstars+1,5 do
			parent.stars[i]:SetColor(1,0,0,1)
		end
	else
		for i=1,5 do
			parent.stars[i]:SetColor(1,0,0,1)
		end
	end
 end

 -- XML function 
 -- Search for intut text in db
 -- SearchDatabase stores only player ID from playerDatabase.
 function IRY:SearchPlayer(text)
 	-- do not search if player missed focus
 	IRY:HidePrevNextButtons(self)
 	if text=="Player Name" or text=="" then
 		IRY:SwitchPage(1)
 		return 
 	end

 	self.searchDatabase={}
	for k,v in pairs(IRY.playerDatabase.data) do
		debug("Search for: "..text.." in "..v.name)
		local searchresult,_=string.find(string.lower(v.name),string.lower(text),0,true)
		if searchresult ~=nil then
			self.searchDatabase[#self.searchDatabase+1]=k
		end
	end

	for i=1,#self.searchDatabase do
		IRY:FillRow(i,self.searchDatabase[i])
	end

	for i=#self.searchDatabase+1,36 do
		self.rows[i]:SetHidden(true)
	end
 end

 -- Hide Next/prev button if search is in progress
function IRY:HidePrevNextButtons(self)
	local maxpages=math.ceil(#self.playerDatabase.data/36) or 0

	if maxpages==0 then return end

	if self.searching then
		IRY_BookCounterLeftPage:SetHidden(false)
		IRY_BookCounterRightPage:SetHidden(false)
		IRY_BookCounterTotal:SetHidden(false)
		IRY_BookKeyStripMouseButtonsPreviousPage:SetHidden(true)
		IRY_BookKeyStripMouseButtonsNextPage:SetHidden(true)
	else
		IRY_BookCounterLeftPage:SetHidden(true)
		IRY_BookCounterRightPage:SetHidden(true)
		IRY_BookCounterTotal:SetHidden(true)
		IRY_BookKeyStripMouseButtonsPreviousPage:SetHidden(false)
		IRY_BookKeyStripMouseButtonsNextPage:SetHidden(false)
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

EVENT_MANAGER:RegisterForEvent("IRememberYou", EVENT_PLAYER_ACTIVATED, HookChatLink)
-- IRememberYou addon (IRY)
-- Allows player to rate all players he ever met.

-- Initialize object
IRY=ZO_Object:Subclass()

local IRY_debug=true
local version=0.41

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

	local linkType, _, _ = zo_strsplit(":", linkData)

	-- debug("Self: "..tostring(self:GetName()))
	debug("linkData: "..tostring(linkData))
	debug("linkType: "..tostring(linkType))

	-- Call original 
	ZO_ChatSystem_OnLinkClicked(linkData, linkText, button, ...)

	-- add our menu only to player linktype
	if linkType ~= CHARACTER_LINK_TYPE and linkType~=DISPLAY_NAME_LINK_TYPE then return end


	start,stop=string.find(linkData,"%[.*")
	name=string.sub(linkData,start+1,stop-1)

	debug("name: "..tostring(name))

	function AddPlayerFromMenu()
		IRY:AddPlayer(GetUnitAlliance("player"),name,0,0)

		IRY_BookSearchEdit:SetText(name)
		IRY:SearchPlayer(name)
		IRY:SetHideState(false)
	end


	if button == 2 then
        ZO_Menu:SetHidden(true)
        AddMenuItem("Rate", AddPlayerFromMenu)

        ShowMenu(nil, 1)
    end

end

local function HookChatLink()

	debug("Unregistered: "..tostring(EVENT_MANAGER:UnregisterForEvent("IRememberYou", EVENT_PLAYER_ACTIVATED)))

	for i=1,#ZO_ChatWindow.container.windows do
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
	self.rows={}

-- Create rows
	-- left page
	for i=1,18 do
		self.rows[i] = CreateControlFromVirtual("IRY_BookRow", IRY_Book, "IRY_BookRow_Virtual",i)
		self.rows[i]:SetAnchor(RIGHT,IRY_Book,CENTER,0,-340+(35*i))
		self.rows[i].stars={}
		-- stars
		for j=1,5 do
			self.rows[i].stars[j] = CreateControlFromVirtual(("IRY_BookRow"..i.."Star"), self.rows[i], "IRY_Star_Virtual",j)
			self.rows[i].stars[j]:SetAnchor(LEFT,self.rows[i],LEFT,240-30+(30*j),0)
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
			self.rows[i].stars[j]:SetAnchor(LEFT,self.rows[i],LEFT,240-30+(30*j),0)
			self.rows[i].stars[j].starnumber=j
		end
	end

	-- load data
	IRY:LoadSavedVars()

	-- create settings
	IRY:CreateSettings()

	-- Create scene
	--  /script SCENE_MANAGER:Show("iry")
	IRY:CreateScene()

	-- Register Events
	self:SetGroupCollectState()
	self:SetTargetCollectState()


	-- search in progress
	IRY.searching=false

	-- Current show state:
	IRY.hidden=true

	IRY:SwitchPage(1)
end

-- Load vars
function IRY:LoadSavedVars()
	debug("LoadSavedVars called")
	local default_playerDatabase={
		data={}
	}
	
	local default_settings = {
		groupCollect=true,
		targetCollect=false
	}

	self.settings = ZO_SavedVars:NewAccountWide("IRY_SavedVars", version, "settings", default_settings, nil)
	self.playerDatabase = ZO_SavedVars:NewAccountWide("IRY_SavedVars", version, "playerDatabase", default_playerDatabase, nil)
	self.searchDatabase = {}
end

-- create settings
function IRY:CreateSettings()
	LAM = LibStub("LibAddonMenu-1.0")

	local panel = LAM:CreateControlPanel("IRYSettingsPanel", "I Remember You")
	LAM:AddHeader(panel, "IRYSettingsHeader", "Add players form:")

	LAM:AddCheckbox(panel, "IRYSettingsCollectGroup", "Group", "Enables/Disables adding players from groups",
					function() return self:IsGroupCollectEnabled() end,		--getFunc

					function() 	IRY.settings.groupCollect = not IRY.settings.groupCollect
								return self:SetGroupCollectState() end		--setFunc 
				    )

	LAM:AddCheckbox(panel, "IRYSettingsCollectTarget", "Target", "Enables/Disables adding players from your current target",
					function() return self:IsTargetCollectEnabled() end,	--getFunc

					function() 	IRY.settings.targetCollect = not IRY.settings.targetCollect
								return self:SetTargetCollectState() end,		--setFunc 
					true,													-- warning
					"This option can seriously increase number of players in your IRY book"
				    )
end

-- create scene
function IRY:CreateScene()
	if not IRY_SCENE then

		IRY_BOOK_FRAGMENT = ZO_FadeSceneFragment:New(IRY_Book)
		IRY_COMMENT_FRAGMENT = ZO_FadeSceneFragment:New(IRY_Comment)

		IRY_SCENE = ZO_Scene:New("iry", SCENE_MANAGER)
		IRY_SCENE:AddFragment(FRAME_PLAYER_FRAGMENT)
		IRY_SCENE:AddFragment(FRAME_EMOTE_FRAGMENT_JOURNAL)
		IRY_SCENE:AddFragment(IRY_BOOK_FRAGMENT)
		IRY_SCENE:AddFragment(IRY_COMMENT_FRAGMENT)

		-- .dat unpacked only from 1.0. Looks like sth changed since then, using treasure map sound
		IRY_SCENE:AddFragment(TREASURE_MAP_SOUNDS)
	end
end

function IRY:ShowScene()
	SCENE_MANAGER:Show("iry")
	IRY_Comment:SetHidden(true)
end

function IRY:HideScene()
	SCENE_MANAGER:Hide("iry")
	IRY_Comment:SetHidden(true)
end

function IRY:SetHideState(state)

	debug("New state: "..tostring(state))
	if not state then
		IRY:ShowScene()
	else
		IRY:HideScene()
	end
end

-- settings Get functions
function IRY:IsGroupCollectEnabled()
	return IRY.settings.groupCollect
end

function IRY:IsTargetCollectEnabled()
	return IRY.settings.targetCollect
end

-- settings Set functions
-- Group 
function IRY:SetGroupCollectState()
	if IRY.settings.groupCollect then 
		debug("Registering Group events")
		-- someone (except me) joined
		EVENT_MANAGER:RegisterForEvent("IRememberYou", EVENT_GROUP_MEMBER_JOINED, AddGroup)
		-- someone left
		EVENT_MANAGER:RegisterForEvent("IRememberYou", EVENT_GROUP_MEMBER_LEFT, AddGroup)
		-- invite recived
		EVENT_MANAGER:RegisterForEvent("IRememberYou", EVENT_GROUP_INVITE_RECEIVED, AddGroup)
		-- role changed
		EVENT_MANAGER:RegisterForEvent("IRememberYou", EVENT_GROUP_MEMBER_ROLES_CHANGED, AddGroup)
	else
		debug("Unregistering Group events")
		-- someone (except me) joined
		EVENT_MANAGER:UnregisterForEvent("IRememberYou", EVENT_GROUP_MEMBER_JOINED)
		-- someone left
		EVENT_MANAGER:UnregisterForEvent("IRememberYou", EVENT_GROUP_MEMBER_LEFT)
		-- invite recived
		EVENT_MANAGER:UnregisterForEvent("IRememberYou", EVENT_GROUP_INVITE_RECEIVED)
		-- role changed
		EVENT_MANAGER:UnregisterForEvent("IRememberYou", EVENT_GROUP_MEMBER_ROLES_CHANGED)
	end
end

function IRY:SetTargetCollectState()
	if IRY.settings.targetCollect then 
		debug("Registering Target events")
		-- Target changed
		EVENT_MANAGER:RegisterForEvent("IRememberYou", EVENT_RETICLE_TARGET_CHANGED, AddReticle)
	else
		debug("Unregistering Target events")
		-- someone (except me) joined
		EVENT_MANAGER:UnregisterForEvent("IRememberYou", EVENT_RETICLE_TARGET_CHANGED)
	end
end

-- chat commands
function IRY.commandHandler(text)

	-- We need to save register
	if string.match(text,"^add ") then
		local first,last=string.find(text,'%".+%"')

		if (not first) or (not last) then d("Wrong player name format") return end

		local name = string.sub(text, first+1, last-1)

		debug("Name from add: "..name)
		IRY:AddPlayer(GetUnitAlliance("player"),name,0,0)

		IRY:SetHideState(false)
	end

	-- rest to lower
	text = string.lower(text)
	if text=="cls" then 
		IRY:cls()
	elseif text=="" then
		IRY:SetHideState(not IRY.hidden)
	else 
		d("==IRY commands: ==")
		d("/iry - display/hide IRY book")
		d('/iry add "Name" - add player')
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
		saved_comment=self.playerDatabase.data[playerid].comment
		self.playerDatabase.data[playerid]={
			["name"]=name,
			["alliance"]=alliance,
			["level"]=level,
			["vetrank"]=vetrank,
			["rate"]=saved_rate,
			["comment"]=saved_comment
		}
	else
		-- if there's no such player -> add player data
		self.playerDatabase.data[#self.playerDatabase.data+1]={
			["name"]=name,
			["alliance"]=alliance,
			["level"]=level,
			["vetrank"]=vetrank,
			["rate"]=-1,
			["comment"]=""
		}
	end

	-- sort table by name
	if #self.playerDatabase.data>1 then
		table.sort(self.playerDatabase.data, compareByName)
	end

	IRY:SwitchPage(IRY_Book.currentpage)

	-- repeat search after db is sorted and return id of player added
	for i=1,#self.playerDatabase.data do
		if self.playerDatabase.data[i].name==name then
			debug("Player name: '"..name.."'. Player id: "..i)
			return i
		end
	end

end

-- Allows playername or table[id]
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
				table.remove (self.playerDatabase.data,k)
				removed = true
			end
		end
	elseif type(arg[1])=="string" then
		local name=arg[1]
		for k,v in pairs(self.playerDatabase.data) do
			if v.name==name then
				debug ("Player "..v.name.." with ID "..k.." was removed from db")
				table.remove (self.playerDatabase.data,k)
				removed = true
			end
		end
	else
		debug("Wrong RemovePlayer attribute type")
		return
	end

	if not removed then
		debug("Something went wrong while removing player "..tostring(arg[1]))
	end

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

-- Shows comment window
function IRY:ShowCommentWindow(id)
	IRY_Comment:SetHidden(false)
	IRY_Book:SetHidden(true)

	IRY_Comment.id=id

	local name=self.playerDatabase.data[id].name
	local comment=self.playerDatabase.data[id].comment
	IRY_CommentTitle:SetText(name)
	IRY_CommentTextEdit:SetText(comment)

end

-- Save note about player
function IRY:SaveComment(self)
	-- 2nd parent
	local parent=self:GetParent()
	parent=parent:GetParent()

	local id=parent.id
	local comment=self:GetText()

	debug("SaveComment=>")
	debug("self: "..tostring(self:GetName()))
	debug("2nd parent: "..tostring(parent:GetName()))
	debug("id: "..tostring(id))
	debug("comment: "..tostring(comment))

	IRY.playerDatabase.data[id].comment=comment

	IRY_Comment:SetHidden(true)
	IRY_Book:SetHidden(false)

end

-- Switch page. Form 1
function IRY:SwitchPage(pagen)
	local maxpages=math.ceil(#self.playerDatabase.data/36)
	if maxpages<=0 then maxpages=1 end

	self.searching=false
	IRY:HidePrevNextButtons()

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

	if pagen<1 or pagen>maxpages then return debug("pagen<1 or pagen>maxpages") end

	IRY_Book.currentpage=pagen

	pagen=pagen-1

	for i=1,36 do
		IRY:FillRow(i,i+(pagen*36))
	end

	if #self.playerDatabase.data==0 then
		for i=1,36 do
			self.rows[i]:SetHidden(true)
			IRY_BookCounterLeftPage:SetText(0)
		end
	end


	-- Modify counters
	for i=1,18 do
		if not self.rows[i]:IsHidden() then
			IRY_BookCounterLeftPage:SetText(i+36*(IRY_Book.currentpage-1))
		end
	end

	local allrowshidden=true
	for i=19,36 do
		if not self.rows[i]:IsHidden() then
			IRY_BookCounterRightPage:SetText(i+36*(IRY_Book.currentpage-1))
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
				_G[basename].stars[i]:SetColor(1,1,0,1)
			end
		else
			for i=1,5 do
				_G[basename].stars[i]:SetColor(1,0,0,0.5)
			end
		end
	else
		debug ("No Rate for id: "..PlayerId)
	end

	self.rows[RowID].id=PlayerId

-- Apply comment state
 	if IRY.playerDatabase.data[PlayerId].comment~="" then
 		_G[basename.."SetComment"]:SetColor(0,1,0,1)
 	else
 		_G[basename.."SetComment"]:SetColor(1,1,1,1)
 	end

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
-- Enter comment to player
function IRY:SetComment(self)
	local parent=self:GetParent()
	local id=parent.id

	debug("Set Comment for id: "..id)
	IRY:ShowCommentWindow(id)

	-- Update book
	IRY:SwitchPage(IRY_Book.currentpage)
end

-- XML function
-- LBM - drop rate
-- RMB - remove player from db
function IRY:DropRate(self, button)

	debug("Button clicked: "..button)

	local parent = self:GetParent()
	local id=parent.id

	if button==1 then
		IRY:RatePlayer(id,-1)
		IRY:ApplyRealStars(self)
	elseif button==2 then
		IRY:RemovePlayer(id)
	end

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

-- XML function
-- Highlight Stars OnMouseEnter
function IRY:HighhlightStars(self)
	local parent=self:GetParent()

	for i=1,self.starnumber do
		parent.stars[i]:SetColor(0,1,0,1)
	end

	for i=self.starnumber+1,1 do
		parent.stars[i]:SetColor(1,0,0,0.5)
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
			parent.stars[i]:SetColor(1,1,0,1)
		end
		for i=currentstars+1,5 do
			parent.stars[i]:SetColor(1,0,0,0.5)
		end
	else
		for i=1,5 do
			parent.stars[i]:SetColor(1,0,0,0.5)
		end
	end
 end

 function IRY:ApplyCommentRealState(self)
 	local parent=self:GetParent()
 	local id=parent.id

 	debug("ApplyCommentRealState")
 	debug("self: "..self:GetName())
 	debug("parent: "..parent:GetName())

 	if IRY.playerDatabase.data[id].comment~="" then
 		self:SetColor(0,1,0,1)
 	else
 		self:SetColor(1,1,1,1)
 	end
 end

 -- XML function 
 -- Search for intut text in db
 -- SearchDatabase stores only player ID from playerDatabase.
 function IRY:SearchPlayer(text)
 	-- do not search if player missed focus
 	if text=="Player Name" or text=="" then
 		self.searching=false
 		IRY:HidePrevNextButtons()
 		IRY:SwitchPage(1)

		IRY_BookCounterLeftPage:SetHidden(false)
		IRY_BookCounterRightPage:SetHidden(false)
		IRY_BookCounterTotal:SetHidden(false)
 		return
 	else
 		IRY:HidePrevNextButtons()
 	end

 	self.searching=true
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

	IRY_BookCounterLeftPage:SetHidden(true)
	IRY_BookCounterRightPage:SetHidden(true)
	IRY_BookCounterTotal:SetHidden(true)
 end

 -- Hide Next/prev button if search is in progress
function IRY:HidePrevNextButtons()
	local maxpages=math.ceil(#self.playerDatabase.data/36)
	if maxpages<=0 then maxpages=1 end

	debug("self.searching: "..tostring(self.searching))

	if maxpages==1 then return end

	if self.searching then
		debug("HidePrevNextButtons: hiding all")
		IRY_BookCounterLeftPage:SetHidden(true)
		IRY_BookCounterRightPage:SetHidden(true)
		IRY_BookCounterTotal:SetHidden(true)
		IRY_BookKeyStripMouseButtonsPreviousPage:SetHidden(true)
		IRY_BookKeyStripMouseButtonsNextPage:SetHidden(true)
	else
		debug("HidePrevNextButtons: showing all")
		IRY_BookCounterLeftPage:SetHidden(false)
		IRY_BookCounterRightPage:SetHidden(false)
		IRY_BookCounterTotal:SetHidden(false)
		IRY_BookKeyStripMouseButtonsPreviousPage:SetHidden(false)
		IRY_BookKeyStripMouseButtonsNextPage:SetHidden(false)
	end
end



-- Register Events

-- Addon loaded
EVENT_MANAGER:RegisterForEvent("IRememberYou", EVENT_ADD_ON_LOADED, IRY_OnLoad)
EVENT_MANAGER:RegisterForEvent("IRememberYou", EVENT_PLAYER_ACTIVATED, HookChatLink)

-- Text for bindings.XML
ZO_CreateStringId("SI_BINDING_NAME_SHOWHIDE_BOOK", "Show/Hide IRY book")
local ADDON_NAME, Addon = ...
local L = Addon.L

Addon.ADDON_NAME = ADDON_NAME
Addon.CUSTOM_PREFIX = "KSWheel1"
Addon.LIB_PREFIX = "LibKS"
Addon.entries = {}
Addon.roster = {}
Addon.rosterOrder = {}
Addon.mapCache = {}
Addon.peerStates = {}
Addon.drawnCycle = {}

local WHEEL_PROTOCOL_VERSION = "1"
local FATE_LOCK_SECONDS = 30
local REROLL_VOTE_SECONDS = 12
local PEER_STATE_MAX_AGE = 75
local MAX_WHEEL_KEYS = 5
Addon.FATE_LOCK_SECONDS = FATE_LOCK_SECONDS
local DUNGEON_TELEPORTS = {
	[161] = 159898,  -- Skyreach
	[239] = 1254551, -- Seat of the Triumvirate
	[402] = 393273,  -- Algeth'ar Academy
	[556] = 1254555, -- Pit of Saron
	[557] = 1254400, -- Windrunner Spire
	[558] = 1254572, -- Magisters' Terrace
	[559] = 1254563, -- Nexus-Point Xenas
	[560] = 1254559, -- Maisara Caverns
}

local SOURCE_ORDER = { "self", "addon", "lib", "chat", "manual" }
local SOURCE_LABELS = {
	self = L.SOURCE_SELF,
	addon = L.SOURCE_ADDON,
	lib = L.SOURCE_LIB,
	chat = L.SOURCE_CHAT,
	manual = L.SOURCE_MANUAL,
}

local eventFrame = CreateFrame("Frame")
Addon.eventFrame = eventFrame

local function SafeNumber(value)
	value = tonumber(value)
	if not value then
		return 0
	end
	return math.floor(value + 0.5)
end

local function GroupChannel()
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
		return "INSTANCE_CHAT"
	elseif IsInRaid() then
		return "RAID"
	elseif IsInGroup() then
		return "PARTY"
	end
end

local function FullUnitName(unit)
	local name = GetUnitName(unit, true)
	if not name or name == "" then
		name = UnitName(unit)
	end
	return name
end

local function ShortName(name)
	if not name then
		return nil
	end
	return Ambiguate(name, "short")
end

local function DebugValue(value)
	if issecretvalue and issecretvalue(value) then
		return L.PROTECTED
	end
	if value == nil then
		return "nil"
	end
	return tostring(value)
end

local function YesNo(value)
	return value and L.YES or L.NO
end

local function HashText(value)
	local hash = 5381
	for index = 1, #value do
		hash = ((hash * 33) + value:byte(index)) % 2147483647
	end
	return ("%08x"):format(hash)
end

function Addon:Print(message)
	DEFAULT_CHAT_FRAME:AddMessage(("|cffffc94dKeystoneWheel|r: %s"):format(message))
end

function Addon:DebugLog(formatString, ...)
	if not self.db or not self.db.debug then
		return
	end
	local ok, message = pcall(string.format, formatString, ...)
	self:Print("|cff61d7ffDEBUG|r " .. (ok and message or formatString))
end

function Addon:GetSourceLabel(source)
	return SOURCE_LABELS[source] or source or L.UNKNOWN
end

function Addon:NewMessageID()
	return ("%d-%04d"):format(GetServerTime(), math.random(0, 9999))
end

function Addon:IsOwnSender(sender)
	if type(sender) ~= "string" or sender == "" then
		return false
	end
	local playerName = FullUnitName("player")
	if not playerName then
		return false
	end
	if sender:lower() == playerName:lower() then
		return true
	end
	local senderShortName = ShortName(sender)
	local playerShortName = ShortName(playerName)
	return senderShortName and playerShortName
		and senderShortName:lower() == playerShortName:lower()
end

function Addon:CanPlayerSpin()
	if not self.db or not self.db.leaderOnly or not IsInGroup() then
		return true
	end
	if UnitIsGroupLeader and UnitIsGroupLeader("player") then
		return true
	end
	if IsInRaid() and UnitIsGroupAssistant and UnitIsGroupAssistant("player") then
		return true
	end
	return false, IsInRaid() and L.LEADER_ONLY_RAID or L.LEADER_ONLY_PARTY
end

function Addon:GetDungeonInfo(mapID)
	mapID = SafeNumber(mapID)
	local cached = self.mapCache[mapID]
	if cached then
		return cached.name, cached.texture
	end

	local name, texture
	if mapID > 0 and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
		name, _, _, texture = C_ChallengeMode.GetMapUIInfo(mapID)
	end
	if name then
		self.mapCache[mapID] = { name = name, texture = texture or 134400 }
		return name, texture or 134400
	end
	return L.DUNGEON_FALLBACK:format(mapID), 134400
end

function Addon:GetDungeonTeleportSpell(mapID)
	local spellID = DUNGEON_TELEPORTS[SafeNumber(mapID)]
	if not spellID then
		return nil, false
	end

	local known = false
	if C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook then
		known = C_SpellBook.IsSpellKnownOrInSpellBook(spellID)
	elseif C_SpellBook and C_SpellBook.IsSpellKnown then
		known = C_SpellBook.IsSpellKnown(spellID)
	elseif C_SpellBook and C_SpellBook.IsSpellInSpellBook then
		known = C_SpellBook.IsSpellInSpellBook(spellID, nil, true)
	elseif IsSpellKnown then
		known = IsSpellKnown(spellID)
	end
	return spellID, known == true
end

function Addon:RefreshRoster()
	wipe(self.roster)
	wipe(self.rosterOrder)

	local units = { "player" }
	for index = 1, 4 do
		units[#units + 1] = "party" .. index
	end

	for _, unit in ipairs(units) do
		if UnitExists(unit) then
			local fullName = FullUnitName(unit)
			local displayName = UnitName(unit) or ShortName(fullName) or fullName
			if fullName then
				local info = {
					id = fullName,
					displayName = displayName,
					classFile = select(2, UnitClass(unit)),
					unit = unit,
				}
				self.rosterOrder[#self.rosterOrder + 1] = fullName
				self.roster[fullName:lower()] = info
				self.roster[displayName:lower()] = info
				local ambiguousName = Ambiguate(fullName, "none")
				if ambiguousName then
					self.roster[ambiguousName:lower()] = info
				end
			end
		end
	end

	local rosterIDs = {}
	for _, id in ipairs(self.rosterOrder) do
		rosterIDs[id] = true
	end
	for id, entry in pairs(self.entries) do
		if not rosterIDs[id] then
			local manual = entry.sources and entry.sources.manual
			if manual then
				entry.sources = { manual = manual }
			else
				self.entries[id] = nil
			end
		end
	end

	local groupMembers = {}
	for _, id in ipairs(self.rosterOrder) do
		groupMembers[#groupMembers + 1] = id:lower()
	end
	table.sort(groupMembers)
	local groupSignature = table.concat(groupMembers, ";")
	if self.groupSignature and self.groupSignature ~= groupSignature then
		wipe(self.drawnCycle)
		self.fateLockUntil = nil
		self.currentRollID = nil
		self.pendingVote = nil
	end
	self.groupSignature = groupSignature

	for sender in pairs(self.peerStates) do
		if not self:IsCurrentGroupMember(sender) then
			self.peerStates[sender] = nil
		end
	end

	self:UpdateOwnKey(false)
	self:RefreshUI()
	self:ScheduleWheelStateBroadcast()
end

function Addon:ResolvePlayer(name)
	name = strtrim(name or "")
	if name == "" then
		return nil
	end

	local info = self.roster[name:lower()]
	if not info then
		local short = ShortName(name)
		info = short and self.roster[short:lower()]
	end
	if info then
		return info.id, info.displayName, info.classFile, true
	end

	return "manual:" .. name:lower(), ShortName(name) or name, nil, false
end

function Addon:UpdateEntry(playerName, level, mapID, source, rating)
	local id, displayName, classFile, inRoster = self:ResolvePlayer(playerName)
	if not id then
		self:DebugLog(L.DEBUG_ENTRY_NO_ID, source or "?")
		return false
	end
	if source ~= "manual" and not inRoster then
		self:DebugLog(L.DEBUG_NOT_IN_ROSTER, source or "?", displayName or "?")
		return false
	end

	level = SafeNumber(level)
	mapID = SafeNumber(mapID)
	rating = SafeNumber(rating)

	local entry = self.entries[id]
	if not entry then
		entry = { id = id, sources = {} }
		self.entries[id] = entry
	end
	entry.displayName = displayName
	entry.classFile = classFile or entry.classFile
	entry.sources[source] = {
		level = level,
		mapID = mapID,
		rating = rating,
		source = source,
		seen = GetTime(),
	}
	self:DebugLog(L.DEBUG_KEY_REPORTED, source, displayName, level, mapID)

	self:RefreshUI()
	self:ScheduleWheelStateBroadcast()
	return true
end

function Addon:GetBestData(entry)
	local newestNoKey
	for _, source in ipairs(SOURCE_ORDER) do
		local data = entry.sources[source]
		if data then
			if data.level > 0 and data.mapID > 0 then
				if not newestNoKey or data.seen > newestNoKey then
					return data
				end
				return nil
			end
			newestNoKey = math.max(newestNoKey or 0, data.seen or 0)
		end
	end
end

function Addon:GetIgnoreKey(id, level, mapID)
	return ("%s|%d|%d"):format(tostring(id):lower(), SafeNumber(mapID), SafeNumber(level))
end

function Addon:GetEntrySignature(entry)
	if not entry then
		return nil
	end
	return self:GetIgnoreKey(entry.id or entry.displayName or "?", entry.level, entry.mapID)
end

function Addon:IsEntryDrawn(entry)
	local signature = self:GetEntrySignature(entry)
	return signature and self.drawnCycle[signature] == true or false
end

function Addon:MarkEntryDrawn(entry)
	local signature = self:GetEntrySignature(entry)
	if signature then
		self.drawnCycle[signature] = true
	end
end

function Addon:GetSpinEligibleIndices(entries, resetCycle)
	local eligible, allowed = {}, {}
	local cycleReset = false
	for index, entry in ipairs(entries or {}) do
		if not entry.ignored then
			allowed[#allowed + 1] = index
			if not self.db.noRepeat or not self:IsEntryDrawn(entry) then
				eligible[#eligible + 1] = index
			end
		end
	end

	if self.db.noRepeat and #allowed > 0 and #eligible == 0 and resetCycle then
		wipe(self.drawnCycle)
		cycleReset = true
		for _, entry in ipairs(entries or {}) do
			entry.drawn = false
		end
		for _, index in ipairs(allowed) do
			eligible[#eligible + 1] = index
		end
		self:Print(L.NO_REPEAT_NEW_ROUND)
	end
	return eligible, allowed, cycleReset
end

function Addon:AddResultHistory(entry, rollID, selectedBy)
	if not entry or not self.db or type(self.db.history) ~= "table" then
		return
	end
	if rollID and self.db.history[1] and self.db.history[1].rollID == rollID then
		return
	end

	table.insert(self.db.history, 1, {
		rollID = rollID,
		displayName = entry.displayName,
		level = SafeNumber(entry.level),
		mapID = SafeNumber(entry.mapID),
		dungeonName = entry.dungeonName,
		selectedBy = selectedBy and (ShortName(selectedBy) or selectedBy) or nil,
		time = GetServerTime(),
	})
	while #self.db.history > 3 do
		table.remove(self.db.history)
	end
end

function Addon:ClearResultHistory()
	wipe(self.db.history)
	wipe(self.drawnCycle)
	self:Print(L.HISTORY_RESET_DONE)
	self:RefreshUI()
end

function Addon:IsKeyIgnored(entry)
	if not entry or not self.db or type(self.db.ignoredKeys) ~= "table" then
		return false
	end
	return self.db.ignoredKeys[self:GetIgnoreKey(entry.id, entry.level, entry.mapID)] == true
end

function Addon:ToggleKeyIgnored(entry)
	if not entry or self.spinning then
		return
	end

	local ignoreKey = self:GetIgnoreKey(entry.id, entry.level, entry.mapID)
	local ignored = not self.db.ignoredKeys[ignoreKey]
	self.db.ignoredKeys[ignoreKey] = ignored or nil
	self:Print(L.IGNORE_TOGGLE:format(
		entry.displayName,
		entry.level,
		entry.dungeonName,
		ignored and L.IGNORE_ON or L.IGNORE_OFF
	))
	self:RefreshUI()
end

function Addon:GetActiveKeys()
	local result, added = {}, {}
	local function AddEntry(id)
		local entry = Addon.entries[id]
		local data = entry and Addon:GetBestData(entry)
		if not data then
			return
		end
		local dungeonName, texture = Addon:GetDungeonInfo(data.mapID)
		local activeEntry = {
			id = id,
			displayName = entry.displayName,
			classFile = entry.classFile,
			level = data.level,
			mapID = data.mapID,
			rating = data.rating,
			source = data.source,
			dungeonName = dungeonName,
			texture = texture,
		}
		activeEntry.ignored = Addon:IsKeyIgnored(activeEntry)
		result[#result + 1] = activeEntry
		added[id] = true
	end

	for _, id in ipairs(self.rosterOrder) do
		AddEntry(id)
	end
	local extra = {}
	for id, entry in pairs(self.entries) do
		if not added[id] and entry.sources.manual then
			extra[#extra + 1] = id
		end
	end
	table.sort(extra, function(left, right)
		return (Addon.entries[left].displayName or left) < (Addon.entries[right].displayName or right)
	end)
	for _, id in ipairs(extra) do
		AddEntry(id)
	end
	return result
end

function Addon:GetWheelPoolState()
	local signatures = {}
	for index, entry in ipairs(self:GetActiveKeys()) do
		if index > MAX_WHEEL_KEYS then
			break
		end
		signatures[#signatures + 1] = self:GetEntrySignature(entry)
	end
	table.sort(signatures)
	return HashText(table.concat(signatures, ";")), #signatures
end

function Addon:PrunePeerStates()
	local now = GetTime()
	for sender, state in pairs(self.peerStates) do
		if not self:IsCurrentGroupMember(sender)
			or not state.seen
			or now - state.seen > PEER_STATE_MAX_AGE then
			self.peerStates[sender] = nil
		end
	end
end

function Addon:GetSyncStatus()
	self:PrunePeerStates()
	local ownHash, ownCount = self:GetWheelPoolState()
	local matching, total = 1, 1
	for _, state in pairs(self.peerStates) do
		total = total + 1
		if state.hash == ownHash and state.count == ownCount then
			matching = matching + 1
		end
	end
	return matching, total, ownHash, ownCount
end

function Addon:GetSyncDetails()
	self:PrunePeerStates()
	local ownHash, ownCount = self:GetWheelPoolState()
	local details = {}
	for sender, state in pairs(self.peerStates) do
		details[#details + 1] = {
			name = ShortName(state.name or sender) or state.name or sender,
			matches = state.hash == ownHash and state.count == ownCount,
			count = state.count,
			version = state.version,
		}
	end
	table.sort(details, function(left, right)
		return left.name < right.name
	end)
	return details, ownCount
end

function Addon:SendWheelCommand(kind, ...)
	local channel = GroupChannel()
	if not channel then
		return false
	end

	local fields = { "KW", WHEEL_PROTOCOL_VERSION, kind }
	for index = 1, select("#", ...) do
		local value = tostring(select(index, ...) or ""):gsub(";", "")
		fields[#fields + 1] = value
	end
	C_ChatInfo.SendAddonMessage(self.LIB_PREFIX, table.concat(fields, ";"), channel)
	return true
end

function Addon:BroadcastWheelState(force)
	if not IsInGroup() then
		return
	end
	local hash, count = self:GetWheelPoolState()
	local stateKey = hash .. ":" .. count
	local now = GetTime()
	if not force and self.lastBroadcastState == stateKey
		and self.lastStateBroadcastAt
		and now - self.lastStateBroadcastAt < 8 then
		return
	end

	local version = "?"
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "?"
	elseif GetAddOnMetadata then
		version = GetAddOnMetadata(ADDON_NAME, "Version") or "?"
	end
	if self:SendWheelCommand("STATE", hash, count, version) then
		self.lastBroadcastState = stateKey
		self.lastStateBroadcastAt = now
	end
end

function Addon:ScheduleWheelStateBroadcast(force)
	if not self.initialized or not IsInGroup() then
		return
	end
	if self.stateBroadcastTimer then
		if force then
			self.pendingForcedStateBroadcast = true
		end
		return
	end
	self.pendingForcedStateBroadcast = force == true
	self.stateBroadcastTimer = C_Timer.NewTimer(0.45, function()
		Addon.stateBroadcastTimer = nil
		local shouldForce = Addon.pendingForcedStateBroadcast
		Addon.pendingForcedStateBroadcast = nil
		Addon:BroadcastWheelState(shouldForce)
	end)
end

function Addon:RequestWheelStates()
	if not IsInGroup() then
		return
	end
	self:SendWheelCommand("SYNCREQ", self:NewMessageID())
	self:ScheduleWheelStateBroadcast(true)
end

function Addon:GetOwnKeyInfo()
	local level = C_MythicPlus.GetOwnedKeystoneLevel() or 0
	local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID() or 0
	local rating = 0
	if C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
		local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
		if summary then
			rating = summary.currentSeasonScore or 0
		end
	end
	return SafeNumber(level), SafeNumber(mapID), SafeNumber(rating)
end

function Addon:UpdateOwnKey(shouldBroadcast)
	local playerName = FullUnitName("player")
	if not playerName then
		return
	end
	local level, mapID, rating = self:GetOwnKeyInfo()
	local changed = level ~= self.ownKeyLevel or mapID ~= self.ownKeyMapID
	self.ownKeyLevel = level
	self.ownKeyMapID = mapID
	self:UpdateEntry(playerName, level, mapID, "self", rating)
	if shouldBroadcast and changed then
		self:BroadcastOwnKey()
	end
end

function Addon:BroadcastOwnKey(channel)
	if not IsInGroup() or IsInRaid() then
		return
	end
	local level, mapID, rating = self:GetOwnKeyInfo()
	local message = ("%d,%d,%d"):format(level, mapID, rating)
	C_ChatInfo.SendAddonMessage(self.LIB_PREFIX, message, "PARTY")
end

function Addon:TryAttachLibKeystone()
	if self.libRegistered or not _G.LibStub then
		return
	end
	local lib = _G.LibStub("LibKeystone", true)
	if not lib or not lib.Register then
		return
	end

	self.libKeystone = lib
	lib.Register(self, function(level, mapID, rating, playerName, channel)
		if channel == "PARTY" then
			Addon:UpdateEntry(playerName, level, mapID, "lib", rating)
		end
	end)
	self.libRegistered = true
	self:DebugLog(L.DEBUG_LIB_CALLBACK)
end

function Addon:RequestLibKeystone()
	self:TryAttachLibKeystone()
	if self.libKeystone and self.libKeystone.Request then
		self.libKeystone.Request("PARTY")
	elseif IsInGroup() then
		C_ChatInfo.SendAddonMessage(self.LIB_PREFIX, "R", "PARTY")
	end
end

function Addon:RequestAll(force)
	local now = GetTime()
	if not force and self.lastRequest and now - self.lastRequest < 3 then
		return
	end
	self.lastRequest = now

	self:UpdateOwnKey(false)
	local channel = GroupChannel()
	self:DebugLog(L.DEBUG_REQUEST_CHANNEL, channel or L.NONE)
	if IsInGroup() and not IsInRaid() then
		self:BroadcastOwnKey("PARTY")
	end
	self:RequestLibKeystone()
	self:RequestWheelStates()
	self:RefreshUI()
end

function Addon:ParseKeystoneLink(message)
	if issecretvalue and issecretvalue(message) then
		return nil
	end
	if type(message) ~= "string" then
		return nil
	end
	local payload = message:match("|Hkeystone:([^|]+)|h") or message:match("keystone:([%d:]+)")
	if not payload then
		return nil
	end
	local _, mapID, level = strsplit(":", payload)
	mapID, level = tonumber(mapID), tonumber(level)
	if not mapID or not level or mapID <= 0 or level <= 0 then
		return nil
	end
	return level, mapID
end

function Addon:AddManualKey(playerName, link)
	playerName = strtrim(playerName or "")
	if playerName == "" then
		return false, L.ERROR_PLAYER_REQUIRED
	end
	local level, mapID = self:ParseKeystoneLink(link)
	if not level then
		return false, L.ERROR_KEYSTONE_LINK
	end
	self:UpdateEntry(playerName, level, mapID, "manual", 0)
	return true
end

function Addon:RemoveFallback(id, source)
	local entry = self.entries[id]
	if not entry or (source ~= "chat" and source ~= "manual") then
		return
	end
	entry.sources[source] = nil
	if not next(entry.sources) then
		self.entries[id] = nil
	end
	self:RefreshUI()
end

function Addon:ClearFallbacks()
	for id, entry in pairs(self.entries) do
		entry.sources.chat = nil
		entry.sources.manual = nil
		if not next(entry.sources) then
			self.entries[id] = nil
		end
	end
	self:RefreshUI()
end

function Addon:AskForLinks()
	local channel = GroupChannel()
	if not channel then
		self:Print(L.NO_GROUP)
		return
	end
	SendChatMessage(L.ASK_LINKS_CHAT, channel)
end

function Addon:GetFateLockRemaining()
	if not self.fateLockUntil then
		return 0
	end
	local remaining = self.fateLockUntil - GetTime()
	if remaining <= 0 then
		self.fateLockUntil = nil
		self.currentRollID = nil
		return 0
	end
	return remaining
end

function Addon:StartFateLock(rollID, duration)
	duration = math.max(0, math.min(SafeNumber(duration), 60))
	if duration <= 0 then
		self.fateLockUntil = nil
		self.currentRollID = rollID
		return
	end
	self.currentRollID = rollID
	self.fateLockUntil = GetTime() + duration
end

function Addon:GetPendingVoteCount()
	local vote = self.pendingVote
	if not vote then
		return 0, 0
	end
	local count = 0
	for _ in pairs(vote.votes) do
		count = count + 1
	end
	return count, vote.required
end

function Addon:RequestRerollVote()
	local remaining = self:GetFateLockRemaining()
	if remaining <= 0 then
		self:RefreshUI()
		return
	end
	if self.pendingVote and self.pendingVote.expires > GetTime() then
		local count, required = self:GetPendingVoteCount()
		self:Print(L.VOTE_ALREADY_RUNNING:format(count, required))
		return
	end

	local _, addonUsers = self:GetSyncStatus()
	if addonUsers < 2 then
		self:Print(L.FATE_NO_PEER:format(
			math.ceil(remaining)
		))
		return
	end

	local voteID = self:NewMessageID()
	local required = math.max(2, math.floor(addonUsers / 2) + 1)
	self.pendingVote = {
		id = voteID,
		required = required,
		expires = GetTime() + REROLL_VOTE_SECONDS,
		votes = { player = true },
	}
	self:SendWheelCommand("VOTE", voteID, required)
	self:Print(L.VOTE_STARTED:format(required))
	self:RefreshUI()

	C_Timer.After(REROLL_VOTE_SECONDS + 0.2, function()
		if Addon.pendingVote and Addon.pendingVote.id == voteID then
			Addon.pendingVote = nil
			Addon:Print(L.VOTE_EXPIRED)
			Addon:RefreshUI()
		end
	end)
end

function Addon:SendRerollVoteYes(voteID)
	if type(voteID) ~= "string" or not voteID:match("^[%w%-]+$") then
		return
	end
	self:SendWheelCommand("VOTEYES", voteID)
	self:Print(L.VOTE_SENT)
end

function Addon:AcceptRerollVote(sender, voteID)
	local vote = self.pendingVote
	if not vote or vote.id ~= voteID or vote.expires <= GetTime() then
		return
	end
	vote.votes[sender:lower()] = true
	local count, required = self:GetPendingVoteCount()
	self:RefreshUI()
	if count < required then
		return
	end

	self.pendingVote = nil
	self.fateLockUntil = nil
	self:SendWheelCommand("UNLOCK", voteID)
	self:Print(L.VOTE_MAJORITY:format(count, required))
	self:RefreshUI()
	C_Timer.After(0.15, function()
		Addon:Spin(true)
	end)
end

function Addon:AnnounceWinner(entry)
	local message = L.WINNER_MESSAGE:format(entry.displayName, entry.level, entry.dungeonName)
	local channel = GroupChannel()
	if self.db.announce and channel then
		SendChatMessage("KeystoneWheel: " .. message, channel)
	else
		self:Print(message)
	end
end

function Addon:IsCurrentGroupMember(playerName)
	if type(playerName) ~= "string" or playerName == "" then
		return false
	end

	local rosterEntry = self.roster[playerName:lower()]
	if rosterEntry then
		return true
	end
	if IsInRaid() and UnitInRaid then
		return UnitInRaid(playerName) ~= nil
	end
	if UnitInParty then
		return UnitInParty(playerName) == true
	end

	local shortName = ShortName(playerName)
	return shortName and self.roster[shortName:lower()] ~= nil
end

function Addon:BroadcastWinner(entry, rollID, lockSeconds)
	local channel = GroupChannel()
	if not channel or not entry then
		return
	end

	local winnerID = tostring(entry.id or entry.displayName or ""):gsub(";", "")
	local level = SafeNumber(entry.level)
	local mapID = SafeNumber(entry.mapID)
	if winnerID == "" or level <= 0 or mapID <= 0 then
		self:DebugLog(L.DEBUG_ROLL_SEND_INVALID)
		return
	end

	rollID = rollID or self:NewMessageID()
	lockSeconds = math.max(0, math.min(SafeNumber(lockSeconds), 60))
	self:SendWheelCommand("ROLL", rollID, winnerID, level, mapID, lockSeconds)
	self:DebugLog(L.DEBUG_ROLL_SENT, rollID, channel, winnerID, level, mapID)
end

function Addon:HandleWheelMessage(message, channel, sender)
	if type(message) ~= "string" or type(sender) ~= "string" then
		return
	end
	if channel ~= "PARTY" and channel ~= "RAID" and channel ~= "INSTANCE_CHAT" then
		return
	end

	local fields = { strsplit(";", message) }
	local marker, version, kind = fields[1], fields[2], fields[3]
	if marker ~= "KW" or version ~= WHEEL_PROTOCOL_VERSION or type(kind) ~= "string" then
		return
	end
	if self:IsOwnSender(sender) then
		return
	end
	if not self:IsCurrentGroupMember(sender) then
		self:DebugLog(L.DEBUG_NON_GROUP_MESSAGE, kind, sender)
		return
	end

	if kind == "STATE" then
		local hash = fields[4]
		local count = tonumber(fields[5])
		local addonVersion = fields[6]
		if type(hash) ~= "string" or not hash:match("^[%da-f]+$") or #hash > 16
			or not count or count < 0 or count > 20
			or type(addonVersion) ~= "string" or #addonVersion > 20 then
			self:DebugLog(L.DEBUG_INVALID_SYNC, sender)
			return
		end
		self.peerStates[sender:lower()] = {
			name = sender,
			hash = hash,
			count = math.floor(count),
			version = addonVersion,
			seen = GetTime(),
		}
		self:RefreshUI()
		return
	end

	if kind == "SYNCREQ" then
		local requestID = fields[4]
		if type(requestID) ~= "string" or not requestID:match("^[%w%-]+$") or #requestID > 32 then
			return
		end
		C_Timer.After(math.random() * 0.35, function()
			Addon:BroadcastWheelState(true)
		end)
		return
	end

	if kind == "ROLL" then
		local rollID, winnerID = fields[4], fields[5]
		local level, mapID = tonumber(fields[6]), tonumber(fields[7])
		local lockSeconds = tonumber(fields[8]) or 0
		if type(rollID) ~= "string" or #rollID < 1 or #rollID > 32
			or not rollID:match("^[%w%-]+$")
			or type(winnerID) ~= "string" or winnerID == "" or #winnerID > 80
			or not level or level < 2 or level > 99
			or not mapID or mapID < 1 or mapID > 100000
			or lockSeconds < 0 or lockSeconds > 60 then
			self:DebugLog(L.DEBUG_INVALID_ROLL, sender)
			return
		end

		local now = GetTime()
		self.seenRolls = self.seenRolls or {}
		for key, seenAt in pairs(self.seenRolls) do
			if now - seenAt > 60 then
				self.seenRolls[key] = nil
			end
		end
		local rollKey = sender:lower() .. ":" .. rollID
		if self.seenRolls[rollKey] then
			return
		end
		self.seenRolls[rollKey] = now

		local dungeonName, texture = self:GetDungeonInfo(mapID)
		local winner = {
			id = winnerID,
			displayName = ShortName(winnerID) or winnerID,
			level = math.floor(level),
			mapID = math.floor(mapID),
			dungeonName = dungeonName,
			texture = texture,
			source = "addon",
		}
		self:DebugLog(L.DEBUG_ROLL_RECEIVED, rollID, sender)
		self:ShowSyncedWinner(winner, sender, rollID, lockSeconds)
		return
	end

	if kind == "VOTE" then
		local voteID = fields[4]
		local required = tonumber(fields[5])
		if type(voteID) ~= "string" or not voteID:match("^[%w%-]+$") or #voteID > 32
			or not required or required < 2 or required > 5 then
			return
		end
		self.seenVoteRequests = self.seenVoteRequests or {}
		if self.seenVoteRequests[voteID] then
			return
		end
		self.seenVoteRequests[voteID] = GetTime()
		self:ShowRerollVotePrompt(sender, voteID, math.floor(required))
		return
	end

	if kind == "VOTEYES" then
		local voteID = fields[4]
		if type(voteID) == "string" and voteID:match("^[%w%-]+$") and #voteID <= 32 then
			self:AcceptRerollVote(sender, voteID)
		end
		return
	end

	if kind == "UNLOCK" then
		local voteID = fields[4]
		if type(voteID) == "string" and voteID:match("^[%w%-]+$") and #voteID <= 32 then
			self.fateLockUntil = nil
			self.pendingVote = nil
			self:RefreshUI()
		end
	end
end

function Addon:OnAddonMessage(prefix, message, channel, sender)
	if issecretvalue and (issecretvalue(prefix) or issecretvalue(message) or issecretvalue(channel) or issecretvalue(sender)) then
		self:DebugLog(L.DEBUG_PROTECTED_MESSAGE)
		return
	end
	self:DebugLog(L.DEBUG_MESSAGE_RECEIVED, DebugValue(prefix), DebugValue(channel), DebugValue(sender))
	if prefix == self.CUSTOM_PREFIX then
		if message == "REQUEST" then
			C_Timer.After(math.random() * 0.35, function()
				Addon:BroadcastOwnKey(channel)
			end)
			return
		end
		local kind, level, mapID, rating = strsplit(";", message)
		if kind == "KEY" then
			self:UpdateEntry(sender, level, mapID, "addon", rating)
		end
	elseif prefix == self.LIB_PREFIX then
		if type(message) == "string" and message:sub(1, 3) == "KW;" then
			self:HandleWheelMessage(message, channel, sender)
			return
		end
		if message == "R" then
			if not self.libKeystone and channel == "PARTY" then
				C_Timer.After(math.random() * 0.35, function()
					Addon:BroadcastOwnKey("PARTY")
				end)
			end
			return
		end
		local level, mapID, rating = message:match("^(%d+),(%d+),(%d+)$")
		if level then
			self:UpdateEntry(sender, level, mapID, "lib", rating)
		end
	end
end

function Addon:OnGroupChat(message, sender)
	if issecretvalue and (issecretvalue(message) or issecretvalue(sender)) then
		return
	end
	local level, mapID = self:ParseKeystoneLink(message)
	if level then
		self:UpdateEntry(sender, level, mapID, "chat", 0)
	end
end

function Addon:ScheduleOwnUpdate(delay, broadcast)
	if self.ownUpdateTimer then
		self.ownUpdateTimer:Cancel()
	end
	self.ownUpdateTimer = C_Timer.NewTimer(delay or 0.5, function()
		Addon.ownUpdateTimer = nil
		Addon:UpdateOwnKey(broadcast)
	end)
end

function Addon:PrintDebugReport(label)
	local version = "?"
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "?"
	elseif GetAddOnMetadata then
		version = GetAddOnMetadata(ADDON_NAME, "Version") or "?"
	end

	local prefixCheck = C_ChatInfo and C_ChatInfo.IsAddonMessagePrefixRegistered
		or _G.IsAddonMessagePrefixRegistered
	local libRegistered = prefixCheck and prefixCheck(self.LIB_PREFIX)
	local channel = GroupChannel()
	local level, mapID, rating = self:GetOwnKeyInfo()
	local ownDungeon = mapID > 0 and self:GetDungeonInfo(mapID) or L.DEBUG_NO_KEY
	local activeKeys = self:GetActiveKeys()
	local ignoredCount = 0
	for _, entry in ipairs(activeKeys) do
		if entry.ignored then
			ignoredCount = ignoredCount + 1
		end
	end
	local _, libRevision = _G.LibStub and _G.LibStub("LibKeystone", true)
	local syncedClients, addonClients, poolHash, poolCount = self:GetSyncStatus()

	self:Print(L.DEBUG_REPORT_TITLE:format(label or L.DEBUG_STATUS))
	self:Print(L.DEBUG_VERSION_LINE:format(
		version,
		YesNo(InCombatLockdown()),
		YesNo(IsInGroup()),
		channel or L.NONE
	))
	self:Print(L.DEBUG_PREFIX_LINE:format(
		self.LIB_PREFIX,
		prefixCheck and YesNo(libRegistered) or L.API_MISSING,
		DebugValue(self.libPrefixResult),
		self.CUSTOM_PREFIX
	))
	self:Print(L.DEBUG_LIB_LINE:format(
		YesNo(self.libKeystone ~= nil),
		YesNo(self.libRegistered),
		DebugValue(libRevision)
	))
	self:Print(L.DEBUG_OWN_KEY:format(level, mapID, ownDungeon, rating))
	self:Print(L.DEBUG_ROSTER_LINE:format(
		#self.rosterOrder,
		#activeKeys,
		ignoredCount,
		YesNo(self.db.debug)
	))
	self:Print(L.DEBUG_SYNC_LINE:format(
		syncedClients,
		addonClients,
		poolHash,
		poolCount,
		YesNo(self.db.noRepeat),
		YesNo(self.db.fateLock),
		YesNo(self.db.leaderOnly)
	))

	for index, id in ipairs(self.rosterOrder) do
		local entry = self.entries[id]
		local rosterInfo = self.roster[id:lower()]
		local details = {}
		if entry then
			for _, source in ipairs(SOURCE_ORDER) do
				local data = entry.sources[source]
				if data then
					details[#details + 1] = ("%s=+%d/%d"):format(source, data.level, data.mapID)
				end
			end
		end
		local best = entry and self:GetBestData(entry)
		local active = best and L.DEBUG_ACTIVE_KEY:format(best.level, best.mapID, best.source) or L.DEBUG_NO_ACTIVE_KEY
		self:Print(L.DEBUG_MEMBER_LINE:format(
			index,
			rosterInfo and rosterInfo.displayName or id,
			rosterInfo and rosterInfo.unit and YesNo(UnitIsConnected(rosterInfo.unit)) or "?",
			active,
			#details > 0 and table.concat(details, ", ") or L.DEBUG_NO_SOURCES
		))
	end
	if type(self.libPrefixResult) == "number" and self.libPrefixResult > 1 then
		self:Print(L.DEBUG_PREFIX_WARNING:format(self.libPrefixResult))
	end
	if IsInGroup() and #self.rosterOrder < 2 then
		self:Print(L.DEBUG_ROSTER_WARNING)
	end
	if level == 0 and mapID == 0 then
		self:Print(L.DEBUG_NO_KEY_NOTE)
	end
	if label == L.DEBUG_AFTER_REQUEST and IsInGroup() and #activeKeys == 0 then
		self:Print(L.DEBUG_NO_KEYS_WARNING)
	end
	self:Print(L.DEBUG_REPORT_END)
end

function Addon:RunDebugReport()
	self:RefreshRoster()
	self:PrintDebugReport(L.DEBUG_BEFORE_REQUEST)
	self:RequestAll(true)
	self:Print(L.DEBUG_REQUEST_FOLLOWUP)
	C_Timer.After(4, function()
		Addon:PrintDebugReport(L.DEBUG_AFTER_REQUEST)
	end)
end

function Addon:HandleSlashCommand(message)
	local command, rest = (message or ""):match("^(%S*)%s*(.-)$")
	command = command:lower()
	if command == "spin" or command == "drehen" then
		self:ShowUI()
		self:Spin()
	elseif command == "refresh" or command == "neu" then
		self:RequestAll(true)
	elseif command == "ask" or command == "fragen" then
		self:AskForLinks()
	elseif command == "add" then
		local playerName, link = rest:match("^(%S+)%s+(.+)$")
		local ok, errorMessage = self:AddManualKey(playerName, link)
		if not ok then
			self:Print(errorMessage .. L.ADD_COMMAND_EXAMPLE)
		end
	elseif command == "clear" then
		self:ClearFallbacks()
	elseif command == "minimap" then
		local option = rest:lower()
		if option == "off" or option == "aus" then
			self.db.showMinimap = false
			if self.minimapButton then
				self.minimapButton:Hide()
			end
			self:Print(L.MINIMAP_HIDDEN)
		else
			self.db.showMinimap = true
			self.db.minimapAngle = 225
			self:CreateMinimapButton()
			self.minimapButton:Show()
			self:UpdateMinimapButtonPosition()
		end
	elseif command == "options" or command == "optionen" then
		self:ShowUI()
		self:ToggleOptions()
	elseif command == "history" or command == "verlauf" then
		if rest:lower() == "clear" or rest:lower() == "leeren" then
			self:ClearResultHistory()
		else
			self:Print(L.HISTORY_COMMAND_HELP)
		end
	elseif command == "debug" then
		local option = rest:lower()
		if option == "on" or option == "an" then
			self.db.debug = true
			self:Print(L.DEBUG_ENABLED)
		elseif option == "off" or option == "aus" then
			self.db.debug = false
			self:Print(L.DEBUG_DISABLED)
		else
			self:RunDebugReport()
		end
	elseif command == "" then
		self:ToggleUI()
	else
		self:Print(L.SLASH_HELP)
	end
end

function Addon:Initialize()
	if self.initialized then
		return
	end
	self.initialized = true

	KeystoneWheelDB = type(KeystoneWheelDB) == "table" and KeystoneWheelDB or {}
	self.db = KeystoneWheelDB
	if self.db.announce == nil then
		self.db.announce = true
	end
	if self.db.sound == nil then
		self.db.sound = true
	end
	if self.db.debug == nil then
		self.db.debug = false
	end
	if self.db.noRepeat == nil then
		self.db.noRepeat = false
	end
	if self.db.fateLock == nil then
		self.db.fateLock = false
	end
	if self.db.leaderOnly == nil then
		self.db.leaderOnly = false
	end
	if self.db.reducedMotion == nil then
		self.db.reducedMotion = false
	end
	if self.db.showMinimap == nil then
		self.db.showMinimap = true
	end
	self.db.uiScale = tonumber(self.db.uiScale) or 1
	self.db.uiScale = math.max(0.75, math.min(self.db.uiScale, 1.15))
	if type(self.db.ignoredKeys) ~= "table" then
		self.db.ignoredKeys = {}
	end
	if type(self.db.history) ~= "table" then
		self.db.history = {}
	end
	while #self.db.history > 3 do
		table.remove(self.db.history)
	end

	self.libPrefixResult = C_ChatInfo.RegisterAddonMessagePrefix(self.LIB_PREFIX)
	self.customPrefixResult = L.DISABLED

	local events = {
		"PLAYER_LOGIN",
		"PLAYER_ENTERING_WORLD",
		"GROUP_ROSTER_UPDATE",
		"CHAT_MSG_ADDON",
		"CHAT_MSG_PARTY",
		"CHAT_MSG_PARTY_LEADER",
		"CHAT_MSG_INSTANCE_CHAT",
		"CHAT_MSG_INSTANCE_CHAT_LEADER",
		"BAG_UPDATE_DELAYED",
		"CHALLENGE_MODE_COMPLETED",
		"ITEM_CHANGED",
		"ITEM_PUSH",
		"PLAYER_REGEN_ENABLED",
		"SPELLS_CHANGED",
		"SPELL_UPDATE_COOLDOWN",
	}
	for _, event in ipairs(events) do
		eventFrame:RegisterEvent(event)
	end

	SLASH_KEYSTONEWHEEL1 = "/kwheel"
	SLASH_KEYSTONEWHEEL2 = "/steinrad"
	SlashCmdList.KEYSTONEWHEEL = function(message)
		Addon:HandleSlashCommand(message)
	end

	self:CreateUI()
	self:CreateAddonCompartmentEntry()
	self:RefreshRoster()
	self:TryAttachLibKeystone()
	self.stateTicker = C_Timer.NewTicker(25, function()
		if IsInGroup() then
			Addon:BroadcastWheelState(true)
		end
	end)
	C_Timer.After(1, function()
		Addon:RequestAll(true)
	end)
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		local loadedAddon = ...
		if loadedAddon == ADDON_NAME then
			Addon:Initialize()
		elseif Addon.initialized then
			Addon:TryAttachLibKeystone()
		end
	elseif event == "CHAT_MSG_ADDON" then
		Addon:OnAddonMessage(...)
	elseif event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER"
		or event == "CHAT_MSG_INSTANCE_CHAT" or event == "CHAT_MSG_INSTANCE_CHAT_LEADER" then
		Addon:OnGroupChat(...)
	elseif event == "GROUP_ROSTER_UPDATE" then
		Addon:RefreshRoster()
		C_Timer.After(0.7, function()
			Addon:RequestAll(false)
		end)
	elseif event == "CHALLENGE_MODE_COMPLETED" then
		Addon:ScheduleOwnUpdate(2, true)
	elseif event == "BAG_UPDATE_DELAYED" or event == "ITEM_CHANGED" or event == "ITEM_PUSH" then
		Addon:ScheduleOwnUpdate(0.5, true)
	elseif event == "PLAYER_REGEN_ENABLED" or event == "SPELLS_CHANGED" then
		Addon:UpdatePortButton(Addon.selectedWinner)
	elseif event == "SPELL_UPDATE_COOLDOWN" then
		Addon:UpdatePortButtonCooldown()
	elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
		Addon:CreateAddonCompartmentEntry()
		Addon:RefreshRoster()
		Addon:UpdateMinimapButtonPosition()
		Addon:ScheduleOwnUpdate(0.8, true)
		C_Timer.After(1.2, function()
			Addon:RequestAll(false)
		end)
	end
end)

local ADDON_NAME, Addon = ...

Addon.ADDON_NAME = ADDON_NAME
Addon.CUSTOM_PREFIX = "KSWheel1"
Addon.LIB_PREFIX = "LibKS"
Addon.entries = {}
Addon.roster = {}
Addon.rosterOrder = {}
Addon.mapCache = {}

local WHEEL_PROTOCOL_VERSION = "1"
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
	self = "Eigener Stein",
	addon = "KeystoneWheel",
	lib = "LibKS / LibKeystone",
	chat = "Gruppenchat",
	manual = "Manuell",
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
		return "<geschützt>"
	end
	if value == nil then
		return "nil"
	end
	return tostring(value)
end

local function YesNo(value)
	return value and "ja" or "nein"
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
	return SOURCE_LABELS[source] or source or "Unbekannt"
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
	return ("Dungeon %d"):format(mapID), 134400
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

	self:UpdateOwnKey(false)
	self:RefreshUI()
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
		self:DebugLog("Eintrag ohne Spieler-ID verworfen (Quelle %s).", source or "?")
		return false
	end
	if source ~= "manual" and not inRoster then
		self:DebugLog("%s von %s verworfen: Spieler nicht im Gruppen-Roster.", source or "?", displayName or "?")
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
	self:DebugLog("%s: %s meldet +%d / Map %d.", source, displayName, level, mapID)

	self:RefreshUI()
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
	self:Print(("%s: +%d %s wird %s."):format(
		entry.displayName,
		entry.level,
		entry.dungeonName,
		ignored and "beim Drehen ignoriert" or "wieder berücksichtigt"
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
	self:DebugLog("LibKeystone-Callback registriert.")
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
	self:DebugLog("Abfrage gestartet; Gruppenkanal=%s.", channel or "keiner")
	if IsInGroup() and not IsInRaid() then
		self:BroadcastOwnKey("PARTY")
	end
	self:RequestLibKeystone()
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
		return false, "Bitte einen Spielernamen angeben."
	end
	local level, mapID = self:ParseKeystoneLink(link)
	if not level then
		return false, "Kein gültiger Keystone-Link erkannt."
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
		self:Print("Du bist in keiner Gruppe.")
		return
	end
	SendChatMessage("KeystoneWheel: Bitte verlinkt euren M+ Schlüssel einmal im Gruppenchat.", channel)
end

function Addon:AnnounceWinner(entry)
	local message = ("Das Rad wählt %s: +%d %s!"):format(entry.displayName, entry.level, entry.dungeonName)
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

function Addon:BroadcastWinner(entry)
	local channel = GroupChannel()
	if not channel or not entry then
		return
	end

	local winnerID = tostring(entry.id or entry.displayName or ""):gsub(";", "")
	local level = SafeNumber(entry.level)
	local mapID = SafeNumber(entry.mapID)
	if winnerID == "" or level <= 0 or mapID <= 0 then
		self:DebugLog("Dreh-Synchronisierung nicht gesendet: ungültiges Ergebnis.")
		return
	end

	local rollID = ("%d-%04d"):format(GetServerTime(), math.random(0, 9999))
	local message = ("KW;%s;ROLL;%s;%s;%d;%d"):format(
		WHEEL_PROTOCOL_VERSION,
		rollID,
		winnerID,
		level,
		mapID
	)
	C_ChatInfo.SendAddonMessage(self.LIB_PREFIX, message, channel)
	self:DebugLog("Dreh %s über %s synchronisiert: %s +%d/%d.", rollID, channel, winnerID, level, mapID)
end

function Addon:HandleWheelMessage(message, channel, sender)
	if type(message) ~= "string" or type(sender) ~= "string" then
		return
	end
	if channel ~= "PARTY" and channel ~= "RAID" and channel ~= "INSTANCE_CHAT" then
		return
	end

	local marker, version, kind, rollID, winnerID, level, mapID = strsplit(";", message)
	level, mapID = tonumber(level), tonumber(mapID)
	if marker ~= "KW" or version ~= WHEEL_PROTOCOL_VERSION or kind ~= "ROLL"
		or type(rollID) ~= "string" or #rollID < 1 or #rollID > 32
		or not rollID:match("^[%w%-]+$")
		or type(winnerID) ~= "string" or winnerID == "" or #winnerID > 80
		or not level or level < 2 or level > 99
		or not mapID or mapID < 1 or mapID > 100000 then
		self:DebugLog("Ungültige KeystoneWheel-Synchronisierung von %s verworfen.", sender)
		return
	end

	local playerName = FullUnitName("player")
	local senderShortName = ShortName(sender)
	local playerShortName = ShortName(playerName)
	if playerName and (sender:lower() == playerName:lower()
		or (senderShortName and playerShortName and senderShortName:lower() == playerShortName:lower())) then
		return
	end
	if not self:IsCurrentGroupMember(sender) then
		self:DebugLog("Dreh von Nicht-Gruppenmitglied %s verworfen.", sender)
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
	self:DebugLog("Synchronisierten Dreh %s von %s empfangen.", rollID, sender)
	self:ShowSyncedWinner(winner, sender)
end

function Addon:OnAddonMessage(prefix, message, channel, sender)
	if issecretvalue and (issecretvalue(prefix) or issecretvalue(message) or issecretvalue(channel) or issecretvalue(sender)) then
		self:DebugLog("Geschützte Addon-Nachricht übersprungen.")
		return
	end
	self:DebugLog("Nachricht empfangen: Prefix=%s, Kanal=%s, Sender=%s.", DebugValue(prefix), DebugValue(channel), DebugValue(sender))
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
	local ownDungeon = mapID > 0 and self:GetDungeonInfo(mapID) or "kein Stein"
	local activeKeys = self:GetActiveKeys()
	local ignoredCount = 0
	for _, entry in ipairs(activeKeys) do
		if entry.ignored then
			ignoredCount = ignoredCount + 1
		end
	end
	local _, libRevision = _G.LibStub and _G.LibStub("LibKeystone", true)

	self:Print(("|cffffd45cDEBUG-BERICHT|r (%s)"):format(label or "Status"))
	self:Print(("Version %s | Kampf=%s | Gruppe=%s | Kanal=%s"):format(
		version,
		YesNo(InCombatLockdown()),
		YesNo(IsInGroup()),
		channel or "keiner"
	))
	self:Print(("Geteiltes Prefix %s: registriert=%s, Code=%s | eigenes Prefix %s: deaktiviert"):format(
		self.LIB_PREFIX,
		prefixCheck and YesNo(libRegistered) or "API fehlt",
		DebugValue(self.libPrefixResult),
		self.CUSTOM_PREFIX
	))
	self:Print(("LibKeystone: vorhanden=%s, Callback=%s, Revision=%s"):format(
		YesNo(self.libKeystone ~= nil),
		YesNo(self.libRegistered),
		DebugValue(libRevision)
	))
	self:Print(("Eigener API-Stein: +%d / Map %d (%s), Wertung %d"):format(level, mapID, ownDungeon, rating))
	self:Print(("Roster=%d | aktive Steine=%d | ignoriert=%d | Debug live=%s"):format(
		#self.rosterOrder,
		#activeKeys,
		ignoredCount,
		YesNo(self.db.debug)
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
		local active = best and (("+%d/%d via %s"):format(best.level, best.mapID, best.source)) or "kein aktiver Stein"
		self:Print(("%d. %s | online=%s | %s | Quellen: %s"):format(
			index,
			rosterInfo and rosterInfo.displayName or id,
			rosterInfo and rosterInfo.unit and YesNo(UnitIsConnected(rosterInfo.unit)) or "?",
			active,
			#details > 0 and table.concat(details, ", ") or "keine Antwort"
		))
	end
	if type(self.libPrefixResult) == "number" and self.libPrefixResult > 1 then
		self:Print(("|cffff6666WARNUNG|r Das geteilte LibKS-Prefix ist fehlgeschlagen (Code %d; 3 bedeutet meist Prefix-Limit)."):format(self.libPrefixResult))
	end
	if IsInGroup() and #self.rosterOrder < 2 then
		self:Print("|cffff6666WARNUNG|r WoW meldet eine Gruppe, aber das Gruppen-Roster enthält nur den eigenen Spieler.")
	end
	if level == 0 and mapID == 0 then
		self:Print("|cffffcc66HINWEIS|r Die WoW-API meldet für den eigenen Charakter aktuell keinen Keystone.")
	end
	if label == "4 Sekunden nach Abfrage" and IsInGroup() and #activeKeys == 0 then
		self:Print("|cffff6666WARNUNG|r Nach der Abfrage wurde kein einziger aktiver Stein gefunden.")
	end
	self:Print("|cff9aa8bdEnde des Debug-Berichts|r")
end

function Addon:RunDebugReport()
	self:RefreshRoster()
	self:PrintDebugReport("vor Abfrage")
	self:RequestAll(true)
	self:Print("Neue Abfrage läuft; zweiter Bericht folgt in 4 Sekunden.")
	C_Timer.After(4, function()
		Addon:PrintDebugReport("4 Sekunden nach Abfrage")
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
			self:Print(errorMessage .. " Beispiel: /kwheel add Spieler [Keystone-Link]")
		end
	elseif command == "clear" then
		self:ClearFallbacks()
	elseif command == "minimap" then
		self.db.minimapAngle = 225
		self:CreateMinimapButton()
		self.minimapButton:Show()
		self:UpdateMinimapButtonPosition()
	elseif command == "debug" then
		local option = rest:lower()
		if option == "on" or option == "an" then
			self.db.debug = true
			self:Print("Live-Debug ist aktiviert. Mit /kwheel debug off wieder abschalten.")
		elseif option == "off" or option == "aus" then
			self.db.debug = false
			self:Print("Live-Debug ist deaktiviert.")
		else
			self:RunDebugReport()
		end
	elseif command == "" then
		self:ToggleUI()
	else
		self:Print("/kwheel, /kwheel drehen, /kwheel neu, /kwheel fragen, /kwheel add <Spieler> <Link>, /kwheel clear, /kwheel minimap, /kwheel debug [on|off]")
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
	if type(self.db.ignoredKeys) ~= "table" then
		self.db.ignoredKeys = {}
	end

	self.libPrefixResult = C_ChatInfo.RegisterAddonMessagePrefix(self.LIB_PREFIX)
	self.customPrefixResult = "deaktiviert"

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
	self:RefreshRoster()
	self:TryAttachLibKeystone()
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
		Addon:RefreshRoster()
		Addon:UpdateMinimapButtonPosition()
		Addon:ScheduleOwnUpdate(0.8, true)
		C_Timer.After(1.2, function()
			Addon:RequestAll(false)
		end)
	end
end)

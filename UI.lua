local _, Addon = ...
local L = Addon.L

local TWO_PI = math.pi * 2
local POINTER_ANGLE = math.pi / 2
local SLOT_RADIUS = 118
local SLOT_SIZE = 86
local MAX_SLOTS = 5
local TRACKING_BORDER_CROP = 0.625
local MINIMAP_RADIUS = 5
local KEYSTONE_ITEM_ID = 180653
local WHEEL_TEXTURE = "Interface\\AddOns\\KeystoneWheel\\Media\\WheelBackdrop.tga"
local RESULT_TITLE_Y_OFFSET = -12

local MINIMAP_SHAPES = {
	ROUND = { true, true, true, true },
	SQUARE = { false, false, false, false },
	["CORNER-TOPLEFT"] = { false, false, false, true },
	["CORNER-TOPRIGHT"] = { false, false, true, false },
	["CORNER-BOTTOMLEFT"] = { false, true, false, false },
	["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
	["SIDE-LEFT"] = { false, true, false, true },
	["SIDE-RIGHT"] = { true, false, true, false },
	["SIDE-TOP"] = { false, false, true, true },
	["SIDE-BOTTOM"] = { true, true, false, false },
	["TRICORNER-TOPLEFT"] = { false, true, true, true },
	["TRICORNER-TOPRIGHT"] = { true, false, true, true },
	["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
	["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

local PALETTE = {
	{ 0.25, 0.82, 0.58 },
	{ 1.00, 0.67, 0.22 },
	{ 0.94, 0.38, 0.57 },
	{ 0.25, 0.73, 0.92 },
	{ 0.68, 0.48, 0.94 },
}

local SOURCE_SHORT = {
	self = L.SOURCE_SHORT_SELF,
	addon = L.SOURCE_SHORT_ADDON,
	lib = L.SOURCE_SHORT_LIB,
	chat = L.SOURCE_SHORT_CHAT,
	manual = L.SOURCE_SHORT_MANUAL,
}

local function SetTooltip(widget, title, body)
	widget:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(title, 1, 0.82, 0.3)
		if body then
			GameTooltip:AddLine(body, 0.86, 0.86, 0.86, true)
		end
		GameTooltip:Show()
	end)
	widget:SetScript("OnLeave", GameTooltip_Hide)
end

local function CreateButton(parent, text, width)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, 24)
	button:SetText(text)
	return button
end

local function CreateCheckbox(parent, text)
	local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	local label = checkbox.Text or checkbox.text
	if not label then
		label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
	end
	label:SetText(text)
	checkbox.label = label
	return checkbox
end

local function SetClassColor(fontString, classFile)
	local color = classFile and RAID_CLASS_COLORS[classFile]
	if color then
		fontString:SetTextColor(color.r, color.g, color.b)
	else
		fontString:SetTextColor(1, 0.93, 0.78)
	end
end

local function IsSafeNumber(value)
	return type(value) == "number" and (not issecretvalue or not issecretvalue(value))
end

function Addon:UpdateMinimapButtonPosition()
	local button = self.minimapButton
	if not button then
		return
	end

	local angle = math.rad(self.db.minimapAngle or 225)
	local x, y = math.cos(angle), math.sin(angle)
	local quadrant = 1
	if x < 0 then
		quadrant = quadrant + 1
	end
	if y > 0 then
		quadrant = quadrant + 2
	end

	local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
	local shapeData = MINIMAP_SHAPES[shape] or MINIMAP_SHAPES.ROUND
	local width = (Minimap:GetWidth() / 2) + MINIMAP_RADIUS
	local height = (Minimap:GetHeight() / 2) + MINIMAP_RADIUS
	if shapeData[quadrant] then
		x, y = x * width, y * height
	else
		local diagonalWidth = math.sqrt(2 * width * width) - 10
		local diagonalHeight = math.sqrt(2 * height * height) - 10
		x = math.max(-width, math.min(x * diagonalWidth, width))
		y = math.max(-height, math.min(y * diagonalHeight, height))
	end

	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function Addon:CreateMinimapButton()
	if self.minimapButton then
		return
	end
	if self.db.minimapAngle == nil then
		self.db.minimapAngle = 225
	end

	local button = CreateFrame("Button", "KeystoneWheelMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture(136477)
	self.minimapButton = button

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetSize(50, 50)
	border:SetTexture(136430)
	border:SetPoint("TOPLEFT", button, "TOPLEFT")

	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetSize(24, 24)
	background:SetTexture(136467)
	background:SetPoint("CENTER")

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(18, 18)
	icon:SetPoint("CENTER")
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	button.icon = icon

	local iconLabel = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	iconLabel:SetPoint("CENTER", icon, "CENTER", 0, 0)
	iconLabel:SetText("KW")
	iconLabel:SetTextColor(1, 0.78, 0.2)
	iconLabel:SetShadowOffset(1, -1)
	button.iconLabel = iconLabel

	local function ApplyKeystoneIcon()
		local iconFileID = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(KEYSTONE_ITEM_ID)
		if type(iconFileID) == "number" and iconFileID > 0 then
			icon:SetTexture(iconFileID)
			icon:SetVertexColor(1, 1, 1, 1)
			iconLabel:Hide()
			return true
		end
		icon:SetColorTexture(0.16, 0.09, 0.24, 1)
		iconLabel:Show()
		return false
	end

	if not ApplyKeystoneIcon() then
		if C_Item and C_Item.RequestLoadItemDataByID then
			C_Item.RequestLoadItemDataByID(KEYSTONE_ITEM_ID)
		end
		if Item and Item.CreateFromItemID then
			Item:CreateFromItemID(KEYSTONE_ITEM_ID):ContinueOnItemLoad(function()
				if button and button.icon then
					ApplyKeystoneIcon()
				end
			end)
		end
	end

	local count = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
	count:SetTextColor(1, 0.78, 0.2)
	count:SetShadowOffset(1, -1)
	count:Hide()
	button.count = count

	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("KeystoneWheel", 1, 0.82, 0.3)
		GameTooltip:AddLine(L.OPEN_WHEEL, 0.9, 0.9, 0.9)
		GameTooltip:AddLine(L.REFRESH_KEYS, 0.9, 0.9, 0.9)
		GameTooltip:AddLine(L.DRAG_POSITION, 0.62, 0.72, 0.86)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	button:SetScript("OnClick", function(self, mouseButton)
		if self.wasDragged then
			return
		end
		if mouseButton == "RightButton" then
			Addon:RequestAll(true)
		else
			Addon:ToggleUI()
		end
	end)
	button:SetScript("OnMouseDown", function(self)
		self.icon:SetTexCoord(0.12, 0.88, 0.12, 0.88)
	end)
	button:SetScript("OnMouseUp", function(self)
		self.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end)
	button:SetScript("OnDragStart", function(self)
		self:LockHighlight()
		self.wasDragged = false
		GameTooltip:Hide()
		self:SetScript("OnUpdate", function(dragButton)
			local minimapX, minimapY = Minimap:GetCenter()
			local cursorX, cursorY = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			cursorX, cursorY = cursorX / scale, cursorY / scale
			Addon.db.minimapAngle = math.deg(math.atan2(cursorY - minimapY, cursorX - minimapX)) % 360
			dragButton.wasDragged = true
			Addon:UpdateMinimapButtonPosition()
		end)
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
		self:UnlockHighlight()
		C_Timer.After(0, function()
			self.wasDragged = false
		end)
	end)

	self:UpdateMinimapButtonPosition()
	button:Show()
end

function Addon:CreateAddonCompartmentEntry()
	if self.compartmentRegistered or not AddonCompartmentFrame then
		return
	end

	local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(KEYSTONE_ITEM_ID)
	AddonCompartmentFrame:RegisterAddon({
		text = "KeystoneWheel",
		icon = icon or 134400,
		registerForAnyClick = true,
		notCheckable = true,
		func = function(first, second)
			local buttonName
			if type(second) == "table" then
				buttonName = second.buttonName
			elseif type(second) == "string" then
				buttonName = second
			elseif type(first) == "table" then
				buttonName = first.buttonName
			elseif first == "LeftButton" or first == "RightButton" then
				buttonName = first
			end
			if buttonName == "RightButton" then
				Addon:RequestAll(true)
			else
				Addon:ToggleUI()
			end
		end,
		funcOnEnter = function()
			GameTooltip:SetOwner(AddonCompartmentFrame, "ANCHOR_LEFT")
			GameTooltip:AddLine("KeystoneWheel", 1, 0.82, 0.3)
			GameTooltip:AddLine(L.OPEN_WHEEL, 0.9, 0.9, 0.9)
			GameTooltip:AddLine(L.REFRESH_KEYS, 0.9, 0.9, 0.9)
			GameTooltip:Show()
		end,
		funcOnLeave = function()
			GameTooltip:Hide()
		end,
	})
	self.compartmentRegistered = true
end

function Addon:ShowRerollVotePrompt(sender, voteID, required)
	local displayName = Ambiguate(sender, "short") or sender
	StaticPopup_Show("KEYSTONEWHEEL_REROLL_VOTE", displayName, required, {
		voteID = voteID,
	})
end

StaticPopupDialogs.KEYSTONEWHEEL_REROLL_VOTE = {
	text = L.REROLL_VOTE_POPUP,
	button1 = L.ACCEPT,
	button2 = L.DECLINE,
	OnAccept = function(_, data)
		if data and data.voteID then
			Addon:SendRerollVoteYes(data.voteID)
		end
	end,
	timeout = 12,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

function Addon:CreateSlot(parent, index)
	local slot = CreateFrame("Button", nil, parent, "BackdropTemplate")
	slot:SetSize(SLOT_SIZE, SLOT_SIZE)
	slot:SetFrameLevel(parent:GetFrameLevel() + 3)
	slot:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 2,
	})
	slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	local color = PALETTE[index]
	slot.color = color
	slot:SetBackdropColor(color[1] * 0.12, color[2] * 0.12, color[3] * 0.12, 0.96)
	slot:SetBackdropBorderColor(color[1], color[2], color[3], 0.78)

	slot.icon = slot:CreateTexture(nil, "ARTWORK")
	slot.icon:SetSize(42, 42)
	slot.icon:SetPoint("TOP", 0, -5)
	slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	slot.iconShade = slot:CreateTexture(nil, "OVERLAY")
	slot.iconShade:SetAllPoints(slot.icon)
	slot.iconShade:SetColorTexture(0, 0, 0, 0.13)

	slot.player = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	slot.player:SetPoint("TOPLEFT", slot, "TOPLEFT", 4, -50)
	slot.player:SetPoint("TOPRIGHT", slot, "TOPRIGHT", -4, -50)
	slot.player:SetJustifyH("CENTER")
	slot.player:SetWordWrap(false)
	if slot.player.SetMaxLines then
		slot.player:SetMaxLines(1)
	end

	slot.key = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	slot.key:SetPoint("TOPLEFT", slot.player, "BOTTOMLEFT", 0, -2)
	slot.key:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -4, 5)
	slot.key:SetJustifyH("CENTER")
	slot.key:SetJustifyV("TOP")
	slot.key:SetWordWrap(true)
	if slot.key.SetMaxLines then
		slot.key:SetMaxLines(2)
	end

	slot.levelBadge = CreateFrame("Frame", nil, slot, "BackdropTemplate")
	slot.levelBadge:SetSize(31, 20)
	slot.levelBadge:SetPoint("TOPLEFT", slot, "TOPLEFT", 3, -3)
	slot.levelBadge:SetFrameLevel(slot:GetFrameLevel() + 2)
	slot.levelBadge:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
	})
	slot.levelBadge:SetBackdropColor(0.025, 0.03, 0.04, 0.96)
	slot.levelBadge:SetBackdropBorderColor(1, 0.72, 0.18, 0.95)

	slot.level = slot.levelBadge:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	slot.level:SetPoint("CENTER", 0, 0)
	slot.level:SetTextColor(1, 0.84, 0.3)
	slot.level:SetShadowOffset(1, -1)

	slot.source = slot:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	slot.source:SetPoint("BOTTOMRIGHT", slot.icon, "BOTTOMRIGHT", -1, 1)
	slot.source:SetTextColor(1, 0.9, 0.62)

	slot.flash = slot:CreateTexture(nil, "OVERLAY")
	slot.flash:SetAllPoints()
	slot.flash:SetColorTexture(1, 0.78, 0.18, 0)

	slot.ignoreOverlay = slot:CreateTexture(nil, "OVERLAY", nil, 5)
	slot.ignoreOverlay:SetAllPoints()
	slot.ignoreOverlay:SetColorTexture(0.12, 0.01, 0.015, 0.72)
	slot.ignoreOverlay:Hide()

	slot.ignoreText = slot:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	slot.ignoreText:SetDrawLayer("OVERLAY", 6)
	slot.ignoreText:SetPoint("CENTER")
	slot.ignoreText:SetText(L.IGNORED)
	slot.ignoreText:SetTextColor(1, 0.34, 0.3)
	slot.ignoreText:Hide()

	slot:SetScript("OnEnter", function(self)
		local entry = self.entry
		if not entry then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		local classColor = entry.classFile and RAID_CLASS_COLORS[entry.classFile]
		GameTooltip:AddLine(entry.displayName, classColor and classColor.r or 1, classColor and classColor.g or 0.9, classColor and classColor.b or 0.7)
		GameTooltip:AddLine(("+%d %s"):format(entry.level, entry.dungeonName), 1, 1, 1)
		GameTooltip:AddLine(L.SOURCE_LINE:format(Addon:GetSourceLabel(entry.source)), 0.65, 0.8, 1)
		if entry.rating and entry.rating > 0 then
			GameTooltip:AddLine(L.RATING_LINE:format(entry.rating), 0.76, 0.76, 0.76)
		end
		if Addon.db.noRepeat and entry.drawn and not entry.ignored then
			GameTooltip:AddLine(L.ALREADY_DRAWN, 0.5, 0.72, 1)
		end
		GameTooltip:AddLine(
			entry.ignored and L.ALLOW_KEY or L.IGNORE_KEY,
			entry.ignored and 0.45 or 0.72,
			entry.ignored and 1 or 0.72,
			entry.ignored and 0.45 or 0.72
		)
		if entry.source == "chat" or entry.source == "manual" then
			GameTooltip:AddLine(L.REMOVE_KEY, 0.55, 0.55, 0.55)
		end
		GameTooltip:Show()
	end)
	slot:SetScript("OnLeave", GameTooltip_Hide)
	slot:SetScript("OnClick", function(self, button)
		if button == "LeftButton" and self.entry then
			Addon:ToggleKeyIgnored(self.entry)
		elseif button == "RightButton" and self.entry then
			Addon:RemoveFallback(self.entry.id, self.entry.source)
		end
	end)
	slot:Hide()
	return slot
end

function Addon:CreateCenterButton(parent)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(106, 106)
	button:SetPoint("CENTER")
	button:SetFrameLevel(parent:GetFrameLevel() + 5)

	button.shadow = button:CreateTexture(nil, "BACKGROUND")
	button.shadow:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	button.shadow:SetSize(86, 86)
	button.shadow:SetPoint("CENTER")
	button.shadow:SetVertexColor(0.02, 0.025, 0.04, 0.98)

	button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	button.text:SetPoint("CENTER", 0, 2)
	button.text:SetText(L.SPIN)
	button.text:SetTextColor(1, 0.82, 0.3)

	button.subtext = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	button.subtext:SetPoint("TOP", button.text, "BOTTOM", 0, -3)
	button.subtext:SetText(L.CLICK)
	button.subtext:SetTextColor(0.75, 0.75, 0.78)

	button:SetScript("OnClick", function()
		Addon:Spin()
	end)
	button:SetScript("OnEnter", function(self)
		if self:IsEnabled() then
			self.text:SetTextColor(1, 0.91, 0.42)
			self.subtext:SetTextColor(0.9, 0.9, 0.94)
		end
		if self.permissionReason or self.interactionHint then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(self.permissionReason and L.PERMISSION_TITLE or L.SEALED_TITLE, 1, 0.82, 0.3)
			GameTooltip:AddLine(self.permissionReason or self.interactionHint, 0.9, 0.9, 0.9, true)
			GameTooltip:Show()
		end
	end)
	button:SetScript("OnLeave", function(self)
		self.text:SetTextColor(1, 0.82, 0.3)
		self.subtext:SetTextColor(0.75, 0.75, 0.78)
		GameTooltip_Hide()
	end)
	return button
end

function Addon:ApplyUIScale()
	if not self.frame then
		return
	end
	local scale = tonumber(self.db.uiScale) or 1
	scale = math.max(0.75, math.min(scale, 1.15))
	self.db.uiScale = scale
	self.frame:SetScale(scale)
end

function Addon:CreateOptionsUI(parent)
	local options = CreateFrame("Frame", "KeystoneWheelOptionsFrame", parent, "BasicFrameTemplateWithInset")
	options:SetSize(380, 360)
	options:SetPoint("CENTER", parent, "CENTER", 0, 0)
	options:SetFrameLevel(parent:GetFrameLevel() + 30)
	options:EnableMouse(true)
	options:Hide()
	if options.TitleText then
		options.TitleText:SetText(L.OPTIONS_TITLE)
	end
	self.optionsFrame = options

	local section = options:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	section:SetPoint("TOPLEFT", 22, -42)
	section:SetText(L.GAME_RULES)
	section:SetTextColor(0.58, 0.68, 0.82)

	local function AddOption(text, y, key, tooltip)
		local checkbox = CreateCheckbox(options, text)
		checkbox:SetPoint("TOPLEFT", 20, y)
		checkbox:SetChecked(Addon.db[key])
		checkbox:SetScript("OnClick", function(self)
			Addon.db[key] = self:GetChecked() and true or false
			Addon:RefreshUI()
		end)
		SetTooltip(checkbox, text, tooltip)
		return checkbox
	end

	self.noRepeatCheckbox = AddOption(
		L.NO_REPEAT_OPTION,
		-56,
		"noRepeat",
		L.NO_REPEAT_TOOLTIP
	)
	self.fateLockCheckbox = AddOption(
		L.FATE_OPTION,
		-88,
		"fateLock",
		L.FATE_TOOLTIP
	)
	self.leaderOnlyCheckbox = AddOption(
		L.LEADER_OPTION,
		-120,
		"leaderOnly",
		L.LEADER_TOOLTIP
	)
	self.reducedMotionCheckbox = AddOption(
		L.REDUCED_MOTION_OPTION,
		-152,
		"reducedMotion",
		L.REDUCED_MOTION_TOOLTIP
	)

	self.minimapCheckbox = AddOption(
		L.MINIMAP_OPTION,
		-184,
		"showMinimap",
		L.MINIMAP_TOOLTIP
	)
	self.minimapCheckbox:SetScript("OnClick", function(self)
		Addon.db.showMinimap = self:GetChecked() and true or false
		if Addon.minimapButton then
			Addon.minimapButton:SetShown(Addon.db.showMinimap)
		end
	end)

	local displaySection = options:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	displaySection:SetPoint("TOPLEFT", 22, -229)
	displaySection:SetText(L.DISPLAY)
	displaySection:SetTextColor(0.58, 0.68, 0.82)

	local scaleValue = options:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	scaleValue:SetPoint("TOPRIGHT", -24, -229)
	self.scaleValueText = scaleValue

	local scaleSlider = CreateFrame("Slider", "KeystoneWheelScaleSlider", options, "OptionsSliderTemplate")
	scaleSlider:SetPoint("TOPLEFT", 30, -252)
	scaleSlider:SetPoint("TOPRIGHT", -30, -252)
	scaleSlider:SetMinMaxValues(0.75, 1.15)
	scaleSlider:SetValueStep(0.05)
	if scaleSlider.SetObeyStepOnDrag then
		scaleSlider:SetObeyStepOnDrag(true)
	end
	local sliderName = scaleSlider:GetName()
	local low = scaleSlider.Low or _G[sliderName .. "Low"]
	local high = scaleSlider.High or _G[sliderName .. "High"]
	local text = scaleSlider.Text or _G[sliderName .. "Text"]
	if low then
		low:SetText("75%")
	end
	if high then
		high:SetText("115%")
	end
	if text then
		text:SetText(L.WINDOW_SCALE)
	end
	scaleSlider:SetScript("OnValueChanged", function(_, value)
		value = math.floor((value * 20) + 0.5) / 20
		Addon.db.uiScale = value
		scaleValue:SetText(("%d%%"):format(math.floor((value * 100) + 0.5)))
		Addon:ApplyUIScale()
	end)
	scaleSlider:SetValue(self.db.uiScale)
	self.scaleSlider = scaleSlider

	local clearHistory = CreateButton(options, L.RESET_HISTORY, 150)
	clearHistory:SetPoint("BOTTOMLEFT", 22, 38)
	clearHistory:SetScript("OnClick", function()
		Addon:ClearResultHistory()
	end)
	SetTooltip(clearHistory, L.RESET_HISTORY, L.RESET_HISTORY_TOOLTIP)

	local compartmentNote = options:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	compartmentNote:SetPoint("BOTTOMRIGHT", -22, 45)
	compartmentNote:SetWidth(165)
	compartmentNote:SetJustifyH("RIGHT")
	compartmentNote:SetText(L.COMPARTMENT_NOTE)
end

function Addon:ToggleOptions()
	if not self.optionsFrame then
		return
	end
	local shouldShow = not self.optionsFrame:IsShown()
	if shouldShow then
		self.noRepeatCheckbox:SetChecked(self.db.noRepeat)
		self.fateLockCheckbox:SetChecked(self.db.fateLock)
		self.leaderOnlyCheckbox:SetChecked(self.db.leaderOnly)
		self.reducedMotionCheckbox:SetChecked(self.db.reducedMotion)
		self.minimapCheckbox:SetChecked(self.db.showMinimap)
		self.scaleSlider:SetValue(self.db.uiScale)
	end
	self.optionsFrame:SetShown(shouldShow)
end

function Addon:CreateUI()
	local frame = CreateFrame("Frame", "KeystoneWheelFrame", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(550, 640)
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relativePoint, x, y = self:GetPoint(1)
		Addon.db.position = { point = point, relativePoint = relativePoint, x = x, y = y }
	end)
	frame:SetScript("OnShow", function()
		Addon:RefreshUI()
		Addon:RequestAll(false)
	end)
	frame:SetScript("OnUpdate", function(_, elapsed)
		Addon:OnUIUpdate(elapsed)
	end)
	frame:Hide()
	self.frame = frame
	UISpecialFrames[#UISpecialFrames + 1] = frame:GetName()

	if self.db.position then
		local position = self.db.position
		frame:SetPoint(position.point or "CENTER", UIParent, position.relativePoint or "CENTER", position.x or 0, position.y or 0)
	else
		frame:SetPoint("CENTER")
	end
	self:ApplyUIScale()

	if frame.TitleText then
		frame.TitleText:SetText("KeystoneWheel")
	end

	local optionsButton = CreateFrame("Button", nil, frame)
	optionsButton:SetSize(19, 19)
	optionsButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -31, -3)
	optionsButton:RegisterForClicks("LeftButtonUp")
	local optionsIcon = optionsButton:CreateTexture(nil, "ARTWORK")
	optionsIcon:SetPoint("CENTER")
	optionsIcon:SetSize(17, 17)
	optionsIcon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
	optionsButton.icon = optionsIcon
	local optionsHighlight = optionsButton:CreateTexture(nil, "HIGHLIGHT")
	optionsHighlight:SetAllPoints(optionsIcon)
	optionsHighlight:SetTexture("Interface\\Buttons\\UI-OptionsButton")
	optionsHighlight:SetBlendMode("ADD")
	optionsHighlight:SetAlpha(0.45)
	optionsButton:SetScript("OnMouseDown", function(self)
		self.icon:ClearAllPoints()
		self.icon:SetPoint("CENTER", 1, -1)
	end)
	optionsButton:SetScript("OnMouseUp", function(self)
		self.icon:ClearAllPoints()
		self.icon:SetPoint("CENTER")
	end)
	optionsButton:SetScript("OnClick", function()
		Addon:ToggleOptions()
	end)
	SetTooltip(optionsButton, L.OPTIONS, L.OPTIONS_TOOLTIP)
	self.optionsButton = optionsButton

	local flavor = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	flavor:SetPoint("TOP", 0, -34)
	flavor:SetText(L.FLAVOR)
	flavor:SetTextColor(0.75, 0.76, 0.82)

	local refreshButton = CreateButton(frame, L.REFRESH, 112)
	refreshButton:SetPoint("TOPLEFT", 22, -53)
	refreshButton:SetScript("OnClick", function()
		Addon:RequestAll(true)
	end)
	SetTooltip(refreshButton, L.REFRESH, L.REFRESH_TOOLTIP)

	local askButton = CreateButton(frame, L.ASK_CHAT, 122)
	askButton:SetPoint("LEFT", refreshButton, "RIGHT", 7, 0)
	askButton:SetScript("OnClick", function()
		Addon:AskForLinks()
	end)
	SetTooltip(askButton, L.CHAT_FALLBACK, L.CHAT_FALLBACK_TOOLTIP)

	local announceCheckbox = CreateCheckbox(frame, L.ANNOUNCE_RESULT)
	announceCheckbox:SetPoint("TOPLEFT", 286, -51)
	announceCheckbox:SetChecked(self.db.announce)
	announceCheckbox:SetScript("OnClick", function(self)
		Addon.db.announce = self:GetChecked() and true or false
	end)
	self.announceCheckbox = announceCheckbox

	local soundCheckbox = CreateCheckbox(frame, L.SOUND)
	soundCheckbox:SetPoint("TOPLEFT", 438, -51)
	soundCheckbox:SetChecked(self.db.sound)
	soundCheckbox:SetScript("OnClick", function(self)
		Addon.db.sound = self:GetChecked() and true or false
	end)
	self.soundCheckbox = soundCheckbox

	local status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	status:SetPoint("TOP", 0, -90)
	status:SetWidth(500)
	status:SetJustifyH("CENTER")
	self.statusText = status

	local statusHitbox = CreateFrame("Button", nil, frame)
	statusHitbox:SetSize(500, 18)
	statusHitbox:SetPoint("CENTER", status, "CENTER")
	statusHitbox:SetScript("OnClick", function()
		Addon:RequestWheelStates()
	end)
	statusHitbox:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(L.SYNC_TITLE, 1, 0.82, 0.3)
		local details, ownCount = Addon:GetSyncDetails()
		GameTooltip:AddLine(L.YOU_HAVE_KEYS:format(ownCount), 0.35, 1, 0.55)
		if #details == 0 then
			GameTooltip:AddLine(L.NO_SYNC_PEER, 0.72, 0.72, 0.76, true)
		else
			for _, detail in ipairs(details) do
				local metadata = {}
				if detail.version then
					metadata[#metadata + 1] = "v" .. detail.version
				end
				if detail.transport then
					metadata[#metadata + 1] = detail.transport
				end
				local suffix = #metadata > 0 and (" (" .. table.concat(metadata, ", ") .. ")") or ""
				GameTooltip:AddLine(
					detail.hasState
						and L.PEER_HAS_KEYS:format(detail.name, detail.count, suffix)
						or L.PEER_WAITING_STATE:format(detail.name, suffix),
					detail.matches and 0.35 or 1,
					detail.matches and 1 or 0.42,
					detail.matches and 0.55 or 0.3
				)
			end
		end
		GameTooltip:AddLine(L.REFRESH_SYNC, 0.58, 0.68, 0.82)
		GameTooltip:Show()
	end)
	statusHitbox:SetScript("OnLeave", GameTooltip_Hide)
	self.statusHitbox = statusHitbox

	local wheel = CreateFrame("Frame", nil, frame)
	wheel:SetSize(510, 350)
	wheel:SetPoint("TOP", 0, -112)
	wheel:SetFrameLevel(frame:GetFrameLevel() + 1)
	self.wheel = wheel

	local wheelHub = CreateFrame("Frame", nil, wheel)
	wheelHub:SetSize(338, 338)
	wheelHub:SetPoint("CENTER")
	wheelHub:SetFrameLevel(wheel:GetFrameLevel() + 1)
	self.wheelHub = wheelHub

	local wheelBackground = wheelHub:CreateTexture(nil, "BACKGROUND")
	wheelBackground:SetTexture(WHEEL_TEXTURE)
	wheelBackground:SetAllPoints()
	self.wheelBackground = wheelBackground

	local pointer = wheelHub:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	pointer:SetPoint("TOP", wheelHub, "TOP", 0, 10)
	pointer:SetText("V")
	pointer:SetTextColor(1, 0.76, 0.18)
	pointer:SetShadowOffset(2, -2)
	self.pointer = pointer

	self.slots = {}
	for index = 1, MAX_SLOTS do
		self.slots[index] = self:CreateSlot(wheel, index)
	end

	self.centerButton = self:CreateCenterButton(wheelHub)

	local resultFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	resultFrame:SetSize(506, 50)
	resultFrame:SetPoint("TOP", 0, -468)
	resultFrame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
	})
	resultFrame:SetBackdropColor(0.045, 0.05, 0.07, 0.96)
	resultFrame:SetBackdropBorderColor(0.28, 0.35, 0.48, 0.8)
	self.resultFrame = resultFrame

	local portButton = CreateFrame(
		"Button",
		"KeystoneWheelPortButton",
		resultFrame,
		"InsecureActionButtonTemplate,BackdropTemplate"
	)
	portButton:SetSize(84, 32)
	portButton:SetPoint("RIGHT", -9, 0)
	portButton:RegisterForClicks("AnyDown", "AnyUp")
	portButton:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
	})
	portButton:SetBackdropColor(0.10, 0.13, 0.17, 0.98)
	portButton:SetBackdropBorderColor(0.42, 0.66, 0.92, 0.9)

	local portIcon = portButton:CreateTexture(nil, "ARTWORK")
	portIcon:SetSize(22, 22)
	portIcon:SetPoint("LEFT", 5, 0)
	portIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	portButton.icon = portIcon

	local portCooldown = CreateFrame("Cooldown", nil, portButton, "CooldownFrameTemplate")
	portCooldown:SetAllPoints(portIcon)
	portCooldown:SetDrawEdge(false)
	portButton.cooldown = portCooldown
	self.portCooldown = portCooldown

	local portText = portButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	portText:SetPoint("LEFT", portIcon, "RIGHT", 5, 0)
	portText:SetPoint("RIGHT", -5, 0)
	portText:SetJustifyH("CENTER")
	portText:SetText(L.PORT)
	portButton.text = portText
	portButton:SetScript("OnEnter", function(self)
		Addon:ShowPortTooltip(self)
		if self:IsEnabled() then
			self:SetBackdropBorderColor(1, 0.76, 0.22, 1)
		end
	end)
	portButton:SetScript("OnLeave", function(self)
		GameTooltip_Hide()
		self:SetBackdropBorderColor(0.42, 0.66, 0.92, 0.9)
	end)
	portButton:Hide()
	self.portButton = portButton

	local resultTitle = resultFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	resultTitle:SetPoint("TOPLEFT", 8, RESULT_TITLE_Y_OFFSET)
	resultTitle:SetPoint("TOPRIGHT", resultFrame, "TOPRIGHT", -8, RESULT_TITLE_Y_OFFSET)
	resultTitle:SetJustifyH("CENTER")
	resultTitle:SetText(L.READY_TITLE)
	resultTitle:SetTextColor(0.58, 0.68, 0.82)
	self.resultTitle = resultTitle

	local resultText = resultFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	resultText:SetPoint("TOPLEFT", resultTitle, "BOTTOMLEFT", 0, -3)
	resultText:SetPoint("TOPRIGHT", resultTitle, "BOTTOMRIGHT", 0, -3)
	resultText:SetJustifyH("CENTER")
	resultText:SetText(L.READY_BODY)
	self.resultText = resultText

	local historyBar = CreateFrame("Button", nil, frame)
	historyBar:SetSize(506, 12)
	historyBar:SetPoint("TOP", resultFrame, "BOTTOM", 0, -2)
	local historyText = historyBar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	historyText:SetPoint("LEFT", 4, 0)
	historyText:SetPoint("RIGHT", -20, 0)
	historyText:SetJustifyH("CENTER")
	historyText:SetWordWrap(false)
	if historyText.SetMaxLines then
		historyText:SetMaxLines(1)
	end
	historyBar.text = historyText
	self.historyBar = historyBar
	self.historyText = historyText

	local historyClear = CreateFrame("Button", nil, historyBar, "UIPanelCloseButton")
	historyClear:SetSize(17, 17)
	historyClear:SetPoint("RIGHT", 0, 0)
	historyClear:SetScript("OnClick", function()
		Addon:ClearResultHistory()
	end)
	SetTooltip(historyClear, L.CLEAR_HISTORY, L.RESET_HISTORY_TOOLTIP)
	historyBar.clearButton = historyClear
	historyBar:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(L.LAST_DRAWS, 1, 0.82, 0.3)
		if #Addon.db.history == 0 then
			GameTooltip:AddLine(L.NO_HISTORY, 0.72, 0.72, 0.76)
		else
			for index, entry in ipairs(Addon.db.history) do
				GameTooltip:AddLine(L.HISTORY_TOOLTIP_LINE:format(
					index,
					entry.level or 0,
					entry.dungeonName or ("Dungeon " .. tostring(entry.mapID or "?")),
					entry.displayName or "?"
				), 0.86, 0.86, 0.9)
			end
		end
		GameTooltip:Show()
	end)
	historyBar:SetScript("OnLeave", GameTooltip_Hide)

	local manualLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	manualLabel:SetPoint("TOPLEFT", 22, -535)
	manualLabel:SetText(L.MANUAL_FALLBACK)
	manualLabel:SetTextColor(0.58, 0.68, 0.82)

	local nameEdit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	nameEdit:SetSize(105, 25)
	nameEdit:SetPoint("TOPLEFT", 22, -554)
	nameEdit:SetAutoFocus(false)
	nameEdit:SetMaxLetters(48)
	self.nameEdit = nameEdit

	local namePlaceholder = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	namePlaceholder:SetPoint("LEFT", nameEdit, "LEFT", 7, 0)
	namePlaceholder:SetText(L.PLAYER)

	local linkEdit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	linkEdit:SetSize(282, 25)
	linkEdit:SetPoint("LEFT", nameEdit, "RIGHT", 8, 0)
	linkEdit:SetAutoFocus(false)
	self.linkEdit = linkEdit

	local linkPlaceholder = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	linkPlaceholder:SetPoint("LEFT", linkEdit, "LEFT", 7, 0)
	linkPlaceholder:SetText(L.KEYSTONE_PLACEHOLDER)

	local function UpdatePlaceholder(editBox, placeholder)
		placeholder:SetShown(editBox:GetText() == "" and not editBox:HasFocus())
	end
	nameEdit:SetScript("OnTextChanged", function(self)
		UpdatePlaceholder(self, namePlaceholder)
	end)
	nameEdit:SetScript("OnEditFocusGained", function()
		namePlaceholder:Hide()
	end)
	nameEdit:SetScript("OnEditFocusLost", function(self)
		UpdatePlaceholder(self, namePlaceholder)
	end)
	linkEdit:SetScript("OnTextChanged", function(self)
		UpdatePlaceholder(self, linkPlaceholder)
	end)
	linkEdit:SetScript("OnEditFocusGained", function()
		linkPlaceholder:Hide()
	end)
	linkEdit:SetScript("OnEditFocusLost", function(self)
		UpdatePlaceholder(self, linkPlaceholder)
	end)

	local addButton = CreateButton(frame, L.ADD, 92)
	addButton:SetPoint("LEFT", linkEdit, "RIGHT", 8, 0)
	addButton:SetScript("OnClick", function()
		local ok, errorMessage = Addon:AddManualKey(nameEdit:GetText(), linkEdit:GetText())
		if ok then
			linkEdit:SetText("")
			Addon:Print(L.KEY_ADDED)
		else
			Addon:Print(errorMessage)
		end
	end)
	linkEdit:SetScript("OnEnterPressed", function(self)
		addButton:Click()
		self:ClearFocus()
	end)
	nameEdit:SetScript("OnEscapePressed", nameEdit.ClearFocus)
	linkEdit:SetScript("OnEscapePressed", linkEdit.ClearFocus)
	if ChatEdit_InsertLink then
		hooksecurefunc("ChatEdit_InsertLink", function(link)
			if linkEdit:IsVisible() and linkEdit:HasFocus()
				and (not issecretvalue or not issecretvalue(link)) and type(link) == "string" then
				linkEdit:Insert(link)
			end
		end)
	end

	local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 19)
	footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 19)
	footer:SetJustifyH("CENTER")
	footer:SetText(L.FOOTER)

	self.confetti = {}
	for index = 1, 28 do
		local particle = {
			texture = frame:CreateTexture(nil, "OVERLAY", nil, 7),
			active = false,
		}
		particle.texture:SetTexture("Interface\\Buttons\\WHITE8X8")
		particle.texture:Hide()
		self.confetti[index] = particle
	end

	self:CreateOptionsUI(frame)
	self:CreateMinimapButton()
	self.minimapButton:SetShown(self.db.showMinimap)
	self:RefreshUI()
end

function Addon:ShowUI()
	self.frame:Show()
end

function Addon:ToggleUI()
	if self.frame:IsShown() then
		self.frame:Hide()
	else
		self.frame:Show()
	end
end

function Addon:ApplySlotEntry(slot, entry)
	slot.entry = entry
	slot.icon:SetTexture(entry.texture or 134400)
	slot.player:SetText(entry.displayName)
	SetClassColor(slot.player, entry.classFile)
	slot.level:SetText(("+%d"):format(entry.level))
	slot.key:SetText(entry.dungeonName)
	slot.source:SetText(SOURCE_SHORT[entry.source] or "?")
	slot.ignoreOverlay:SetShown(entry.ignored)
	slot.ignoreText:SetShown(entry.ignored)
	slot:SetAlpha(self.db.noRepeat and entry.drawn and not entry.ignored and 0.62 or 1)
	slot:Show()
end

function Addon:SetSelectedSlot(selectedIndex, winnerIndex)
	for index, slot in ipairs(self.slots) do
		if slot:IsShown() then
			local color = slot.color
			if index == winnerIndex then
				slot:SetBackdropBorderColor(1, 0.82, 0.22, 1)
				slot.flash:SetAlpha(0.2)
			elseif slot.entry and slot.entry.ignored then
				slot:SetBackdropBorderColor(0.72, 0.16, 0.16, 0.9)
				slot.flash:SetAlpha(0)
			elseif index == selectedIndex then
				slot:SetBackdropBorderColor(1, 0.96, 0.72, 1)
				slot.flash:SetAlpha(0.12)
			else
				slot:SetBackdropBorderColor(color[1], color[2], color[3], 0.72)
				slot.flash:SetAlpha(0)
			end
		end
	end
end

function Addon:ShowPortTooltip(button)
	if not button or not button.teleportSpellID then
		return
	end

	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	if GameTooltip.SetSpellByID then
		GameTooltip:SetSpellByID(button.teleportSpellID)
	else
		GameTooltip:AddLine(L.TELEPORT_TITLE, 1, 0.82, 0.3)
	end
	if not button.teleportKnown then
		GameTooltip:AddLine(L.TELEPORT_UNKNOWN, 1, 0.35, 0.35, true)
	elseif InCombatLockdown and InCombatLockdown() then
		GameTooltip:AddLine(L.TELEPORT_COMBAT, 1, 0.35, 0.35)
	else
		local cooldownInfo = C_Spell and C_Spell.GetSpellCooldown
			and C_Spell.GetSpellCooldown(button.teleportSpellID)
		local remaining = cooldownInfo
			and IsSafeNumber(cooldownInfo.duration)
			and IsSafeNumber(cooldownInfo.startTime)
			and math.max(0, cooldownInfo.startTime + cooldownInfo.duration - GetTime())
		if remaining and remaining > 1.5 then
			GameTooltip:AddLine(L.TELEPORT_COOLDOWN:format(SecondsToTime(remaining)), 1, 0.76, 0.25)
		else
			GameTooltip:AddLine(L.TELEPORT_READY, 0.35, 1, 0.55)
		end
	end
	GameTooltip:Show()
end

function Addon:UpdatePortButtonCooldown()
	local button = self.portButton
	if not button or not button.teleportSpellID then
		return
	end

	local cooldownInfo = C_Spell and C_Spell.GetSpellCooldown
		and C_Spell.GetSpellCooldown(button.teleportSpellID)
	if cooldownInfo and IsSafeNumber(cooldownInfo.startTime) and IsSafeNumber(cooldownInfo.duration)
		and cooldownInfo.duration > 1.5 then
		local modRate = IsSafeNumber(cooldownInfo.modRate) and cooldownInfo.modRate or 1
		button.cooldown:SetCooldown(
			cooldownInfo.startTime,
			cooldownInfo.duration,
			modRate
		)
	else
		button.cooldown:Clear()
	end
end

function Addon:UpdateResultLayout(showPortButton)
	if not self.resultTitle or not self.resultFrame or not self.portButton then
		return
	end

	self.resultTitle:ClearAllPoints()
	self.resultTitle:SetPoint("TOPLEFT", self.resultFrame, "TOPLEFT", 8, RESULT_TITLE_Y_OFFSET)
	if showPortButton then
		self.resultTitle:SetPoint("TOPRIGHT", self.portButton, "TOPLEFT", -7, RESULT_TITLE_Y_OFFSET)
	else
		self.resultTitle:SetPoint("TOPRIGHT", self.resultFrame, "TOPRIGHT", -8, RESULT_TITLE_Y_OFFSET)
	end
end

function Addon:UpdatePortButton(entry)
	local button = self.portButton
	if not button then
		return
	end

	self.selectedWinner = entry
	self:UpdateResultLayout(false)
	if InCombatLockdown and InCombatLockdown() then
		self.pendingTeleportEntry = entry
		button:Disable()
		button:Hide()
		return
	end
	self.pendingTeleportEntry = nil

	button:SetAttribute("type", nil)
	button:SetAttribute("spell", nil)
	button.teleportSpellID = nil
	button.teleportKnown = false
	button.cooldown:Clear()

	if not entry then
		button:Hide()
		return
	end

	local spellID, known = self:GetDungeonTeleportSpell(entry.mapID)
	if not spellID then
		button:Hide()
		return
	end

	local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
	button.teleportSpellID = spellID
	button.teleportKnown = known
	button.icon:SetTexture(spellInfo and spellInfo.iconID or 134414)
	button.icon:SetDesaturated(not known)
	button.text:SetText(L.PORT)
	button:Show()
	self:UpdateResultLayout(true)

	if known then
		button:SetAttribute("type", "spell")
		button:SetAttribute("spell", spellID)
		button:Enable()
		button:SetAlpha(1)
	else
		button:Disable()
		button:SetAlpha(0.52)
	end
	self:UpdatePortButtonCooldown()
end

function Addon:LayoutWheel(angle)
	local entries = self.wheelEntries or {}
	local count = #entries
	if count == 0 then
		return
	end

	for index, entry in ipairs(entries) do
		local slot = self.slots[index]
		local slotAngle = POINTER_ANGLE + ((index - 1) * TWO_PI / count) + angle
		local x = math.cos(slotAngle) * SLOT_RADIUS
		local y = math.sin(slotAngle) * SLOT_RADIUS
		slot:ClearAllPoints()
		slot:SetPoint("CENTER", self.wheelHub, "CENTER", x, y)
	end
end

function Addon:GetPointerIndex(angle)
	local count = #(self.wheelEntries or {})
	local closestIndex, closestDistance
	for index = 1, count do
		local slotAngle = POINTER_ANGLE + ((index - 1) * TWO_PI / count) + angle
		local distance = math.abs(((slotAngle - POINTER_ANGLE + math.pi) % TWO_PI) - math.pi)
		if not closestDistance or distance < closestDistance then
			closestDistance = distance
			closestIndex = index
		end
	end
	return closestIndex
end

function Addon:FindWheelWinnerIndex(winner)
	if not winner then
		return nil
	end

	local winnerID = type(winner.id) == "string" and winner.id:lower()
	local winnerShortName = winnerID and Ambiguate(winner.id, "short")
	winnerShortName = winnerShortName and winnerShortName:lower()
	local mapLevelIndex
	local mapLevelMatches = 0
	for index, entry in ipairs(self.wheelEntries or {}) do
		if entry.mapID == winner.mapID and entry.level == winner.level then
			mapLevelIndex = index
			mapLevelMatches = mapLevelMatches + 1
			local entryID = type(entry.id) == "string" and entry.id:lower()
			local entryShortName = entryID and Ambiguate(entry.id, "short")
			entryShortName = entryShortName and entryShortName:lower()
			if entryID and (entryID == winnerID
				or (winnerShortName and entryShortName == winnerShortName)) then
				return index
			end
		end
	end
	if mapLevelMatches == 1 then
		return mapLevelIndex
	end
end

function Addon:UpdateHistoryDisplay()
	if not self.historyBar or not self.historyText then
		return
	end
	local parts = {}
	for _, entry in ipairs(self.db.history or {}) do
		parts[#parts + 1] = ("+%d %s (%s)"):format(
			entry.level or 0,
			entry.dungeonName or ("Dungeon " .. tostring(entry.mapID or "?")),
			entry.displayName or "?"
		)
	end
	if #parts == 0 then
		self.historyText:SetText(L.HISTORY_EMPTY)
		self.historyBar.clearButton:Hide()
	else
		self.historyText:SetText(L.HISTORY_PREFIX .. table.concat(parts, "  |  "))
		self.historyBar.clearButton:Show()
	end
end

function Addon:UpdateCenterButtonState()
	if not self.centerButton then
		return
	end

	local entries = self.wheelEntries or {}
	local eligible, allowed = self:GetSpinEligibleIndices(entries, false)
	self.currentEligibleCount = #eligible
	self.currentAllowedCount = #allowed
	self.centerButton.permissionReason = nil
	self.centerButton.interactionHint = nil

	local canSpin, reason = self:CanPlayerSpin()
	if not canSpin then
		self.centerButton:Disable()
		self.centerButton.text:SetText(L.CENTER_LEADER)
		self.centerButton.subtext:SetText(L.CENTER_MAY_SPIN)
		self.centerButton:SetAlpha(0.55)
		self.centerButton.permissionReason = reason
		return
	end

	local voteCount, voteRequired = self:GetPendingVoteCount()
	if voteRequired > 0 then
		self.centerButton:Disable()
		self.centerButton.text:SetText(L.CENTER_VOTES)
		self.centerButton.subtext:SetText(("%d/%d"):format(voteCount, voteRequired))
		self.centerButton:SetAlpha(0.7)
		return
	end

	local lockRemaining = self:GetFateLockRemaining()
	if lockRemaining > 0 then
		self.centerButton:Enable()
		self.centerButton.text:SetText(L.CENTER_SEALED)
		self.centerButton.subtext:SetText(L.CENTER_SEALED_SUB:format(math.ceil(lockRemaining)))
		self.centerButton:SetAlpha(0.86)
		self.centerButton.interactionHint = L.CENTER_SEALED_HINT
		return
	end

	if #entries == 0 then
		self.centerButton:Disable()
		self.centerButton.text:SetText(L.CENTER_EMPTY)
		self.centerButton.subtext:SetText(L.CENTER_COLLECT)
		self.centerButton:SetAlpha(0.55)
	elseif #allowed == 0 then
		self.centerButton:Disable()
		self.centerButton.text:SetText(L.CENTER_PAUSED)
		self.centerButton.subtext:SetText(L.CENTER_ALL_IGNORED)
		self.centerButton:SetAlpha(0.55)
	elseif #eligible == 0 and self.db.noRepeat then
		self.centerButton:Enable()
		self.centerButton.text:SetText(L.CENTER_NEW_ROUND)
		self.centerButton.subtext:SetText(L.CENTER_ALL_DRAWN)
		self.centerButton:SetAlpha(1)
	else
		self.centerButton:Enable()
		self.centerButton.text:SetText(self.selectedWinner and L.CENTER_AGAIN or L.SPIN)
		self.centerButton.subtext:SetText(self.selectedWinner and L.CENTER_WHY_NOT or L.CLICK)
		self.centerButton:SetAlpha(1)
	end
end

function Addon:RefreshUI()
	if not self.frame or self.spinning then
		return
	end

	local entries = self:GetActiveKeys()
	while #entries > MAX_SLOTS do
		table.remove(entries)
	end
	self.wheelEntries = entries
	self.wheelAngle = self.wheelAngle or 0
	local sourceCounts = { addon = 0, lib = 0, chat = 0, manual = 0, self = 0 }
	local ignoredCount = 0
	for _, entry in ipairs(entries) do
		sourceCounts[entry.source] = (sourceCounts[entry.source] or 0) + 1
		entry.drawn = self:IsEntryDrawn(entry)
		if entry.ignored then
			ignoredCount = ignoredCount + 1
		end
	end
	local eligibleCount = #entries - ignoredCount
	local syncedClients, addonClients = self:GetSyncStatus()
	local syncColor
	if addonClients == 1 then
		syncColor = "ff9aa8bd"
	elseif syncedClients == addonClients then
		syncColor = "ff65d99b"
	else
		syncColor = "ffff6f61"
	end
	local syncLabel = ("|c%sSync %d/%d|r"):format(syncColor, syncedClients, addonClients)

	local rosterSize = math.max(#self.rosterOrder, #entries)
	self.statusText:SetText(L.STATUS_LINE:format(
		#entries,
		rosterSize,
		eligibleCount,
		ignoredCount,
		sourceCounts.addon + sourceCounts.self,
		sourceCounts.lib,
		sourceCounts.chat,
		sourceCounts.manual,
		syncLabel
	))
	if self.minimapButton then
		self.minimapButton.count:SetText(#entries)
		self.minimapButton.count:SetShown(#entries > 0)
	end

	for index, slot in ipairs(self.slots) do
		local entry = entries[index]
		if entry then
			self:ApplySlotEntry(slot, entry)
		else
			slot.entry = nil
			slot:Hide()
		end
	end

	self:LayoutWheel(self.wheelAngle)
	local selectedIndex = self:FindWheelWinnerIndex(self.selectedWinner)
	self.winnerIndex = selectedIndex
	self:SetSelectedSlot(selectedIndex, selectedIndex)
	self:UpdateHistoryDisplay()
	self:UpdateCenterButtonState()
end

function Addon:PlayTick()
	if not self.db.reducedMotion then
		self.pointerBounce = 1
	end
	if not self.db.sound then
		return
	end
	local now = GetTime()
	if self.lastTickSound and now - self.lastTickSound < 0.07 then
		return
	end
	self.lastTickSound = now
	local sound = SOUNDKIT and (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.GS_TITLE_OPTION_OK)
	if sound then
		PlaySound(sound, "SFX")
	end
end

function Addon:Spin(ignoreFateLock)
	if self.spinning then
		return
	end
	local canSpin, reason = self:CanPlayerSpin()
	if not canSpin then
		self:Print(reason)
		return
	end
	if not ignoreFateLock and self:GetFateLockRemaining() > 0 then
		self:RequestRerollVote()
		return
	end
	self:RefreshUI()
	local count = #(self.wheelEntries or {})
	if count == 0 then
		self:Print(L.NO_KEYS_FOUND)
		return
	end
	local eligibleIndices, _, cycleReset = self:GetSpinEligibleIndices(self.wheelEntries, true)
	if #eligibleIndices == 0 then
		self:Print(L.ALL_KEYS_IGNORED)
		return
	end
	if cycleReset then
		for _, slot in ipairs(self.slots) do
			if slot:IsShown() and slot.entry and not slot.entry.ignored then
				slot:SetAlpha(1)
			end
		end
	end

	self.spinning = true
	self.winnerIndex = nil
	self:UpdatePortButton(nil)
	self:SetSelectedSlot(nil, nil)
	self.centerButton:Disable()
	self.centerButton.text:SetText(L.CENTER_SPINNING)
	self.centerButton.subtext:SetText(L.GOOD_LUCK)
	self.resultTitle:SetText(L.WHEEL_SPINNING)
	self.resultTitle:SetTextColor(0.58, 0.68, 0.82)
	self.resultText:SetText(L.WHO_WILL_IT_BE)

	local winnerIndex = eligibleIndices[math.random(1, #eligibleIndices)]
	local startAngle = self.wheelAngle or 0
	local baseAngle = (winnerIndex - 1) * TWO_PI / count
	local targetAngle = -baseAngle
	while targetAngle <= startAngle + 0.001 do
		targetAngle = targetAngle + TWO_PI
	end
	local rotations = self.db.reducedMotion and math.random(1, 2) or math.random(4, 6)
	targetAngle = targetAngle + TWO_PI * rotations

	self.spinAnimation = {
		elapsed = 0,
		duration = self.db.reducedMotion and (1.0 + math.random() * 0.25) or (4.0 + math.random() * 0.8),
		startAngle = startAngle,
		targetAngle = targetAngle,
		winnerIndex = winnerIndex,
		lastPointerIndex = nil,
	}
end

function Addon:PresentWinner(winner, winnerIndex, syncedBy, rollID, lockSeconds)
	self:StartFateLock(rollID, lockSeconds)
	self:MarkEntryDrawn(winner)
	winner.drawn = true
	self:AddResultHistory(winner, rollID, syncedBy)
	self.winnerIndex = winnerIndex
	self.selectedWinner = winner
	self:SetSelectedSlot(winnerIndex, winnerIndex)
	local winnerSlot = winnerIndex and self.slots[winnerIndex]
	if winnerSlot then
		winnerSlot:SetAlpha(1)
	end

	if syncedBy then
		self.resultTitle:SetText(L.SHARED_SPIN_TITLE:format(Ambiguate(syncedBy, "short") or syncedBy))
		self.resultTitle:SetTextColor(0.38, 0.78, 1)
	else
		self.resultTitle:SetText(L.WHEEL_DECIDED)
		self.resultTitle:SetTextColor(1, 0.72, 0.22)
	end
	self.resultText:SetText(L.RESULT_LINE:format(winner.displayName, winner.level, winner.dungeonName))

	self:UpdateHistoryDisplay()
	self:UpdateCenterButtonState()
	self:UpdatePortButton(winner)
	if self.frame:IsShown() then
		if not self.db.reducedMotion then
			self.resultPulse = 2.5
			self:LaunchConfetti()
		end
		if self.db.sound then
			local sound = SOUNDKIT and (SOUNDKIT.UI_BONUS_LOOT_ROLL_END or SOUNDKIT.READY_CHECK)
			if sound then
				PlaySound(sound, "SFX")
			end
		end
	end
end

function Addon:ShowSyncedWinner(winner, sender, rollID, lockSeconds)
	if self.spinning then
		self:DebugLog(L.DEBUG_SHARED_IGNORED, sender)
		return
	end

	local wasShown = self.frame:IsShown()
	self:RefreshUI()
	local winnerIndex = self:FindWheelWinnerIndex(winner)
	if winnerIndex then
		winner = self.wheelEntries[winnerIndex]
		local count = #self.wheelEntries
		self.wheelAngle = (-((winnerIndex - 1) * TWO_PI / count)) % TWO_PI
		self:LayoutWheel(self.wheelAngle)
	end
	self:PresentWinner(winner, winnerIndex, sender, rollID, lockSeconds)

	if not wasShown then
		self:Print(L.SHARED_SELECTED:format(
			Ambiguate(sender, "short") or sender,
			winner.displayName,
			winner.level,
			winner.dungeonName
		))
	end
end

function Addon:FinishSpin(animation)
	self.spinning = false
	self.spinAnimation = nil
	self.wheelAngle = animation.targetAngle % TWO_PI
	self:LayoutWheel(self.wheelAngle)
	local winner = self.wheelEntries[animation.winnerIndex]
	local rollID = self:NewMessageID()
	local lockSeconds = self.db.fateLock and self.FATE_LOCK_SECONDS or 0
	self:PresentWinner(winner, animation.winnerIndex, nil, rollID, lockSeconds)
	self:AnnounceWinner(winner)
	self:BroadcastWinner(winner, rollID, lockSeconds)
	self:ScheduleWheelStateBroadcast()
end

function Addon:LaunchConfetti()
	if self.db.reducedMotion then
		return
	end
	for index, particle in ipairs(self.confetti) do
		local color = PALETTE[((index - 1) % #PALETTE) + 1]
		particle.x = math.random(-75, 75)
		particle.y = math.random(-40, 30)
		particle.vx = math.random(-125, 125)
		particle.vy = math.random(95, 235)
		particle.life = 1.7 + math.random() * 1.4
		particle.maxLife = particle.life
		particle.rotation = math.random() * TWO_PI
		particle.spin = (math.random() - 0.5) * 8
		particle.active = true
		particle.texture:SetSize(math.random(4, 9), math.random(7, 14))
		particle.texture:SetColorTexture(color[1], color[2], color[3], 1)
		particle.texture:ClearAllPoints()
		particle.texture:SetPoint("CENTER", self.frame, "CENTER", particle.x, particle.y)
		particle.texture:Show()
	end
end

function Addon:UpdateConfetti(elapsed)
	for _, particle in ipairs(self.confetti) do
		if particle.active then
			particle.life = particle.life - elapsed
			if particle.life <= 0 then
				particle.active = false
				particle.texture:Hide()
			else
				particle.vy = particle.vy - 245 * elapsed
				particle.x = particle.x + particle.vx * elapsed
				particle.y = particle.y + particle.vy * elapsed
				particle.rotation = particle.rotation + particle.spin * elapsed
				particle.texture:ClearAllPoints()
				particle.texture:SetPoint("CENTER", self.frame, "CENTER", particle.x, particle.y)
				particle.texture:SetRotation(particle.rotation)
				particle.texture:SetAlpha(math.min(1, particle.life / 0.45))
			end
		end
	end
end

function Addon:OnUIUpdate(elapsed)
	local animation = self.spinAnimation
	if animation then
		animation.elapsed = animation.elapsed + elapsed
		local progress = math.min(1, animation.elapsed / animation.duration)
		local eased = 1 - ((1 - progress) ^ 5)
		local angle = animation.startAngle + (animation.targetAngle - animation.startAngle) * eased
		self.wheelAngle = angle
		self:LayoutWheel(angle)

		local pointerIndex = self:GetPointerIndex(angle)
		if pointerIndex ~= animation.lastPointerIndex then
			animation.lastPointerIndex = pointerIndex
			self:SetSelectedSlot(pointerIndex, nil)
			self:PlayTick()
		end
		if progress >= 1 then
			self:FinishSpin(animation)
		end
	end

	self.centerStateElapsed = (self.centerStateElapsed or 0) + elapsed
	if not self.spinning and self.centerStateElapsed >= 0.25 then
		self.centerStateElapsed = 0
		if self.fateLockUntil or self.pendingVote then
			self:UpdateCenterButtonState()
		end
	end

	if self.pointerBounce and self.pointerBounce > 0 then
		self.pointerBounce = math.max(0, self.pointerBounce - elapsed * 8)
		local offset = math.sin(self.pointerBounce * math.pi) * 6
		self.pointer:ClearAllPoints()
		self.pointer:SetPoint("TOP", self.wheelHub, "TOP", 0, 10 - offset)
	end

	if self.resultPulse and self.resultPulse > 0 then
		self.resultPulse = math.max(0, self.resultPulse - elapsed)
		local pulse = 0.55 + math.sin(GetTime() * 9) * 0.25
		self.resultFrame:SetBackdropBorderColor(1, 0.68, 0.2, pulse)
		local winnerSlot = self.winnerIndex and self.slots[self.winnerIndex]
		if winnerSlot then
			winnerSlot.flash:SetAlpha(0.12 + pulse * 0.16)
		end
		if self.resultPulse == 0 then
			self.resultFrame:SetBackdropBorderColor(0.28, 0.35, 0.48, 0.8)
		end
	end

	self:UpdateConfetti(elapsed)
end

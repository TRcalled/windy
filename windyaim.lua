--// Loaded Check

if AirHubV2Loaded or AirHubV2Loading or AirHub then
	return
end

getgenv().AirHubV2Loading = true

--// System Cache & Services

local cloneref = cloneref or function(instance) return instance end
local clonefunction = clonefunction or function(fn) return fn end

local Services = setmetatable({}, {
	__index = function(self, serviceName)
		local success, service = pcall(function()
			return cloneref(game:GetService(serviceName))
		end)
		if success and service then
			rawset(self, serviceName, service)
			return service
		end
		return nil
	end
})

local Players = Services.Players
local RunService = Services.RunService
local UserInputService = Services.UserInputService
local TeleportService = Services.TeleportService
local StarterGui = Services.StarterGui

local LocalPlayer = Players.LocalPlayer

local loadstring, typeof, select, next, pcall = loadstring, typeof, select, next, pcall
local tablefind, tablesort = table.find, table.sort
local mathfloor = math.floor
local stringgsub = string.gsub
local wait, delay, spawn = task.wait, task.delay, task.spawn
local osdate = os.date

--// Module Launching

local function SafeHttpGet(url)
	local success, result = pcall(function()
		return game:HttpGet(url)
	end)
	if success and result then
		return result
	end
	error("[Windy Launcher] Failed to retrieve module from: " .. tostring(url))
end

-- 1. Functions Library
local LibrarySuccess, LibraryModule = pcall(function()
	return loadstring(SafeHttpGet("https://raw.githubusercontent.com/TRcalled/windy/main/Library.lua"))()
end)

local Library = (LibrarySuccess and type(LibraryModule) == "table") and LibraryModule or {}
if Library.ExportGlobals then
	pcall(Library.ExportGlobals, getgenv())
end

-- Fallbacks if not present globally
local SetMouseIconVisibility = SetMouseIconVisibility or (Library and Library.SetMouseIconVisibility) or function(visible)
	UserInputService.MouseIconEnabled = visible
end

local Rejoin = Rejoin or (Library and Library.Rejoin) or function()
	TeleportService:Teleport(game.PlaceId, LocalPlayer)
end

local ServerHop = (Library and Library.ServerHop) or function()
	TeleportService:Teleport(game.PlaceId, LocalPlayer)
end

local SendNotification = (Library and Library.SendNotification) or function(title, text)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title or "Windy",
			Text = text or "",
			Duration = 4
		})
	end)
end

-- 2. UI Library, ESP, and Aimbot
local GUI = loadstring(SafeHttpGet("https://raw.githubusercontent.com/TRcalled/windy/main/UILibrary.lua"))()
local ESP = loadstring(SafeHttpGet("https://raw.githubusercontent.com/TRcalled/windy/main/ESP.lua"))()
local Aimbot = loadstring(SafeHttpGet("https://raw.githubusercontent.com/TRcalled/windy/main/aim.lua"))()

--// Variables & Reference Binding

local MainFrame = GUI:Load()

local ESP_DeveloperSettings = ESP.DeveloperSettings or {}
local ESP_Settings = ESP.Settings or {}
local ESP_Properties = ESP.Properties or {}
local Crosshair = (ESP_Properties and ESP_Properties.Crosshair) or {}
local CenterDot = Crosshair.CenterDot or {}

local Aimbot_DeveloperSettings = Aimbot.DeveloperSettings or {}
local Aimbot_Settings = Aimbot.Settings or {}
local Aimbot_FOV = Aimbot.FOVSettings or {}
local Aimbot_CPT = Aimbot.ClosestPlayerTracer or {}
local Triggerbot = Aimbot.Triggerbot or {}

-- Default initial states
ESP_Settings.LoadConfigOnLaunch = false
ESP_Settings.Enabled = false
Crosshair.Enabled = false
Aimbot_Settings.Enabled = false

local Fonts = {"UI", "System", "Plex", "Monospace"}
local TracerPositions = {"Bottom", "Center", "Mouse"}
local HealthBarPositions = {"Top", "Bottom", "Left", "Right"}
local BoxTypes = {"Square", "Quad", "Corner"}

-- Dynamic fallback resolution for font indices
local InitialFontName = "Plex"
if ESP_Properties.ESP and ESP_Properties.ESP.Font then
	for name, fontVal in pairs(Drawing.Fonts or {}) do
		if fontVal == ESP_Properties.ESP.Font then
			InitialFontName = name
			break
		end
	end
end

--// Tabs Setup

local General, GeneralSignal = MainFrame:Tab("General")
local _Aimbot = MainFrame:Tab("Aimbot")
local _ESP = MainFrame:Tab("ESP")
local _Crosshair = MainFrame:Tab("Crosshair")
local Settings = MainFrame:Tab("Settings")

--// Dynamic Property Generation Utility

local AddValues = function(Section, Object, Exceptions, Prefix)
	if type(Object) ~= "table" then return end
	local Keys, Copy = {}, {}

	for Index, _ in next, Object do
		Keys[#Keys + 1] = Index
	end

	tablesort(Keys, function(A, B)
		return tostring(A) < tostring(B)
	end)

	for _, Value in next, Keys do
		Copy[Value] = Object[Value]
	end

	-- Booleans -> Toggles
	for Index, Value in next, Copy do
		if typeof(Value) ~= "boolean" or (Exceptions and tablefind(Exceptions, Index)) then
			continue
		end

		Section:Toggle({
			Name = stringgsub(Index, "(%l)(%u)", function(...)
				return select(1, ...).." "..select(2, ...)
			end),
			Flag = Prefix..Index,
			Default = Value,
			Callback = function(_Value)
				Object[Index] = _Value
			end
		})
	end

	-- Color3s -> Colorpickers
	for Index, Value in next, Copy do
		if typeof(Value) ~= "Color3" or (Exceptions and tablefind(Exceptions, Index)) then
			continue
		end

		Section:Colorpicker({
			Name = stringgsub(Index, "(%l)(%u)", function(...)
				return select(1, ...).." "..select(2, ...)
			end),
			Flag = Index,
			Default = Value,
			Callback = function(_Value)
				Object[Index] = _Value
			end
		})
	end
end

--// 1. General Tab

local AimbotSection = General:Section({
	Name = "Aimbot Settings",
	Side = "Left"
})

local ESPSection = General:Section({
	Name = "ESP Settings",
	Side = "Right"
})

local ESPDeveloperSection = General:Section({
	Name = "ESP Developer Settings",
	Side = "Right"
})

AddValues(ESPDeveloperSection, ESP_DeveloperSettings, {}, "ESP_DeveloperSettings_")

ESPDeveloperSection:Dropdown({
	Name = "Update Mode",
	Flag = "ESP_UpdateMode",
	Content = {"RenderStepped", "Stepped", "Heartbeat"},
	Default = ESP_DeveloperSettings.UpdateMode or "RenderStepped",
	Callback = function(Value)
		ESP_DeveloperSettings.UpdateMode = Value
	end
})

ESPDeveloperSection:Dropdown({
	Name = "Team Check Option",
	Flag = "ESP_TeamCheckOption",
	Content = {"TeamColor", "Team"},
	Default = ESP_DeveloperSettings.TeamCheckOption or "Team",
	Callback = function(Value)
		ESP_DeveloperSettings.TeamCheckOption = Value
	end
})

ESPDeveloperSection:Slider({
	Name = "Rainbow Speed",
	Flag = "ESP_RainbowSpeed",
	Default = (ESP_DeveloperSettings.RainbowSpeed or 1) * 10,
	Min = 5,
	Max = 30,
	Callback = function(Value)
		ESP_DeveloperSettings.RainbowSpeed = Value / 10
	end
})

if ESP_DeveloperSettings.WidthBoundary ~= nil then
	ESPDeveloperSection:Slider({
		Name = "Width Boundary",
		Flag = "ESP_WidthBoundary",
		Default = ESP_DeveloperSettings.WidthBoundary * 10,
		Min = 5,
		Max = 30,
		Callback = function(Value)
			ESP_DeveloperSettings.WidthBoundary = Value / 10
		end
	})
end

ESPDeveloperSection:Button({
	Name = "Refresh ESP",
	Callback = function()
		if ESP.Restart then ESP:Restart() end
	end
})

ESPDeveloperSection:Button({
	Name = "Rewrite Entries / Hard Reboot",
	Callback = function()
		if ESP.Restart then ESP:Restart(true) end
	end
})

AddValues(ESPSection, ESP_Settings, {"LoadConfigOnLaunch", "PartsOnly"}, "ESPSettings_")

AimbotSection:Toggle({
	Name = "Enabled",
	Flag = "Aimbot_Enabled",
	Default = Aimbot_Settings.Enabled or false,
	Callback = function(Value)
		Aimbot_Settings.Enabled = Value
	end
})

AddValues(AimbotSection, Aimbot_Settings, {
	"Enabled",
	"Toggle",
	"OffsetToMoveDirection",
	"VelocityPrediction",
	"RetargetOnTargetLoss",
	"ForceFieldCheck"
}, "Aimbot_")

local AimbotDeveloperSection = General:Section({
	Name = "Aimbot Developer Settings",
	Side = "Left"
})

AimbotDeveloperSection:Dropdown({
	Name = "Update Mode",
	Flag = "Aimbot_UpdateMode",
	Content = {"RenderStepped", "Stepped", "Heartbeat"},
	Default = Aimbot_DeveloperSettings.UpdateMode or "RenderStepped",
	Callback = function(Value)
		Aimbot_DeveloperSettings.UpdateMode = Value
	end
})

AimbotDeveloperSection:Dropdown({
	Name = "Team Check Option",
	Flag = "Aimbot_TeamCheckOption",
	Content = {"TeamColor", "Team"},
	Default = Aimbot_DeveloperSettings.TeamCheckOption or "Team",
	Callback = function(Value)
		Aimbot_DeveloperSettings.TeamCheckOption = Value
	end
})

AimbotDeveloperSection:Slider({
	Name = "Rainbow Speed",
	Flag = "Aimbot_RainbowSpeed",
	Default = (Aimbot_DeveloperSettings.RainbowSpeed or 3) * 10,
	Min = 5,
	Max = 30,
	Callback = function(Value)
		Aimbot_DeveloperSettings.RainbowSpeed = Value / 10
	end
})

AimbotDeveloperSection:Button({
	Name = "Restart Engine",
	Callback = function()
		if Aimbot.Restart then Aimbot.Restart() end
	end
})

--// 2. Aimbot Tab

local AimbotPropertiesSection = _Aimbot:Section({
	Name = "Properties",
	Side = "Left"
})

AimbotPropertiesSection:Toggle({
	Name = "Toggle Mode",
	Flag = "Aimbot_Toggle",
	Default = Aimbot_Settings.Toggle or false,
	Callback = function(Value)
		Aimbot_Settings.Toggle = Value
	end
})

AimbotPropertiesSection:Toggle({
	Name = "Retarget On Target Loss",
	Flag = "Aimbot_RetargetOnLoss",
	Default = Aimbot_Settings.RetargetOnTargetLoss or true,
	Callback = function(Value)
		Aimbot_Settings.RetargetOnTargetLoss = Value
	end
})

AimbotPropertiesSection:Toggle({
	Name = "ForceField Check",
	Flag = "Aimbot_ForceFieldCheck",
	Default = Aimbot_Settings.ForceFieldCheck or true,
	Callback = function(Value)
		Aimbot_Settings.ForceFieldCheck = Value
	end
})

AimbotPropertiesSection:Toggle({
	Name = "Velocity Prediction",
	Flag = "Aimbot_VelocityPrediction",
	Default = Aimbot_Settings.VelocityPrediction or false,
	Callback = function(Value)
		Aimbot_Settings.VelocityPrediction = Value
	end
})

AimbotPropertiesSection:Slider({
	Name = "Velocity Multiplier",
	Flag = "Aimbot_VelocityMultiplier",
	Default = mathfloor((Aimbot_Settings.VelocityMultiplier or 0.135) * 1000),
	Min = 10,
	Max = 500,
	Callback = function(Value)
		Aimbot_Settings.VelocityMultiplier = Value / 1000
	end
})

AimbotPropertiesSection:Toggle({
	Name = "Offset To Move Direction",
	Flag = "Aimbot_OffsetToMoveDirection",
	Default = Aimbot_Settings.OffsetToMoveDirection or false,
	Callback = function(Value)
		Aimbot_Settings.OffsetToMoveDirection = Value
	end
})

AimbotPropertiesSection:Slider({
	Name = "Offset Increment",
	Flag = "Aimbot_OffsetIncrement",
	Default = Aimbot_Settings.OffsetIncrement or 15,
	Min = 1,
	Max = 30,
	Callback = function(Value)
		Aimbot_Settings.OffsetIncrement = Value
	end
})

-- Smoothness & Mouse Sensitivity handling
local CurrentSmoothness = Aimbot_Settings.Smoothness or (Aimbot_Settings.Sensitivity and Aimbot_Settings.Sensitivity * 10) or 1

AimbotPropertiesSection:Slider({
	Name = "Aim Smoothness",
	Flag = "Aimbot_Smoothness",
	Default = mathfloor(CurrentSmoothness * 10),
	Min = 10, -- 1.0 (Snappy)
	Max = 200, -- 20.0 (Very Smooth)
	Callback = function(Value)
		local resolved = Value / 10
		Aimbot_Settings.Smoothness = resolved
		Aimbot_Settings.Sensitivity = resolved / 10 -- Backwards compatibility
	end
})

AimbotPropertiesSection:Slider({
	Name = "mousemoverel Sensitivity",
	Flag = "Aimbot_Sensitivity2",
	Default = mathfloor((Aimbot_Settings.Sensitivity2 or 1) * 100),
	Min = 10,
	Max = 500,
	Callback = function(Value)
		Aimbot_Settings.Sensitivity2 = Value / 100
	end
})

AimbotPropertiesSection:Dropdown({
	Name = "Lock Mode",
	Flag = "Aimbot_Settings_LockMode",
	Content = {"CFrame", "mousemoverel", "mousemoveabs"},
	Default = (Aimbot_Settings.LockMode == 2 and "mousemoverel") or (Aimbot_Settings.LockMode == 3 and "mousemoveabs") or "CFrame",
	Callback = function(Value)
		Aimbot_Settings.LockMode = (Value == "CFrame" and 1) or (Value == "mousemoverel" and 2) or 3
	end
})

AimbotPropertiesSection:Dropdown({
	Name = "Lock Part",
	Flag = "Aimbot_LockPart",
	Content = {
		"Head", "HumanoidRootPart", "Torso", "UpperTorso", "LowerTorso",
		"Left Arm", "Right Arm", "Left Leg", "Right Leg"
	},
	Default = Aimbot_Settings.LockPart or "Head",
	Callback = function(Value)
		Aimbot_Settings.LockPart = Value
	end
})

AimbotPropertiesSection:Keybind({
	Name = "Trigger Key",
	Flag = "Aimbot_TriggerKey",
	Default = Aimbot_Settings.TriggerKey or Enum.UserInputType.MouseButton2,
	Callback = function(Keybind)
		Aimbot_Settings.TriggerKey = Keybind
	end
})

local UserBox = AimbotPropertiesSection:Box({
	Name = "Player Name (shortened allowed)",
	Flag = "Aimbot_PlayerName",
	Placeholder = "Username"
})

AimbotPropertiesSection:Button({
	Name = "Blacklist (Ignore) Player",
	Callback = function()
		local username = GUI.flags["Aimbot_PlayerName"]
		if type(username) == "string" and #username > 0 then
			local success, err = pcall(function()
				Aimbot:Blacklist(username)
			end)
			if success then
				SendNotification("Blacklist", "Target player blacklisted.")
			else
				SendNotification("Blacklist Error", tostring(err))
			end
			UserBox:Set("")
		end
	end
})

AimbotPropertiesSection:Button({
	Name = "Whitelist Player",
	Callback = function()
		local username = GUI.flags["Aimbot_PlayerName"]
		if type(username) == "string" and #username > 0 then
			local success, err = pcall(function()
				Aimbot:Whitelist(username)
			end)
			if success then
				SendNotification("Whitelist", "Target removed from blacklist.")
			else
				SendNotification("Whitelist Error", tostring(err))
			end
			UserBox:Set("")
		end
	end
})

local AimbotFOVSection = _Aimbot:Section({
	Name = "Field Of View Settings",
	Side = "Right"
})

AddValues(AimbotFOVSection, Aimbot_FOV, {"DynamicFOV"}, "Aimbot_FOV_")

AimbotFOVSection:Toggle({
	Name = "Dynamic FOV (Zoom Scaling)",
	Flag = "Aimbot_FOV_DynamicFOV",
	Default = Aimbot_FOV.DynamicFOV or true,
	Callback = function(Value)
		Aimbot_FOV.DynamicFOV = Value
	end
})

AimbotFOVSection:Slider({
	Name = "Field Of View Radius",
	Flag = "Aimbot_FOV_Radius",
	Default = Aimbot_FOV.Radius or 160,
	Min = 0,
	Max = 720,
	Callback = function(Value)
		Aimbot_FOV.Radius = Value
	end
})

AimbotFOVSection:Slider({
	Name = "Circle Sides",
	Flag = "Aimbot_FOV_NumSides",
	Default = Aimbot_FOV.NumSides or 64,
	Min = 3,
	Max = 80,
	Callback = function(Value)
		Aimbot_FOV.NumSides = Value
	end
})

AimbotFOVSection:Slider({
	Name = "Transparency",
	Flag = "Aimbot_FOV_Transparency",
	Default = (Aimbot_FOV.Transparency or 0.8) * 10,
	Min = 1,
	Max = 10,
	Callback = function(Value)
		Aimbot_FOV.Transparency = Value / 10
	end
})

AimbotFOVSection:Slider({
	Name = "Thickness",
	Flag = "Aimbot_FOV_Thickness",
	Default = Aimbot_FOV.Thickness or 1,
	Min = 1,
	Max = 5,
	Callback = function(Value)
		Aimbot_FOV.Thickness = Value
	end
})

local AimbotCPTSection = _Aimbot:Section({
	Name = "Closest Player Tracer Settings",
	Side = "Right"
})

AddValues(AimbotCPTSection, Aimbot_CPT, {}, "Aimbot_CPT_")

AimbotCPTSection:Dropdown({
	Name = "Position",
	Flag = "CPT_Position",
	Content = TracerPositions,
	Default = TracerPositions[Aimbot_CPT.Position] or "Mouse",
	Callback = function(Value)
		Aimbot_CPT.Position = tablefind(TracerPositions, Value) or 3
	end
})

AimbotCPTSection:Slider({
	Name = "Transparency",
	Flag = "CPT_Transparency",
	Default = (Aimbot_CPT.Transparency or 0.7) * 10,
	Min = 1,
	Max = 10,
	Callback = function(Value)
		Aimbot_CPT.Transparency = Value / 10
	end
})

AimbotCPTSection:Slider({
	Name = "Thickness",
	Flag = "CPT_Thickness",
	Default = Aimbot_CPT.Thickness or 1,
	Min = 1,
	Max = 5,
	Callback = function(Value)
		Aimbot_CPT.Thickness = Value
	end
})

local TriggerbotSection = _Aimbot:Section({
	Name = "Triggerbot Settings",
	Side = "Right"
})

AddValues(TriggerbotSection, Triggerbot, {}, "Triggerbot_")

TriggerbotSection:Slider({
	Name = "Click Delay (ms)",
	Flag = "Triggerbot_Delay",
	Default = (Triggerbot.Delay or 0.05) * 1000,
	Min = 0,
	Max = 500,
	Callback = function(Value)
		Triggerbot.Delay = Value / 1000
	end
})

--// 3. ESP Tab

local ESP_Properties_Section = _ESP:Section({
	Name = "ESP Properties",
	Side = "Left"
})

AddValues(ESP_Properties_Section, ESP_Properties.ESP or {}, {}, "ESP_Properties_")

ESP_Properties_Section:Dropdown({
	Name = "Text Font",
	Flag = "ESP_TextFont",
	Content = Fonts,
	Default = InitialFontName,
	Callback = function(Value)
		if Drawing.Fonts and Drawing.Fonts[Value] then
			ESP_Properties.ESP.Font = Drawing.Fonts[Value]
		end
	end
})

ESP_Properties_Section:Slider({
	Name = "Transparency",
	Flag = "ESP_TextTransparency",
	Default = ((ESP_Properties.ESP and ESP_Properties.ESP.Transparency) or 1) * 10,
	Min = 1,
	Max = 10,
	Callback = function(Value)
		ESP_Properties.ESP.Transparency = Value / 10
	end
})

ESP_Properties_Section:Slider({
	Name = "Font Size",
	Flag = "ESP_FontSize",
	Default = (ESP_Properties.ESP and ESP_Properties.ESP.Size) or 14,
	Min = 1,
	Max = 20,
	Callback = function(Value)
		ESP_Properties.ESP.Size = Value
	end
})

ESP_Properties_Section:Slider({
	Name = "Offset",
	Flag = "ESP_Offset",
	Default = (ESP_Properties.ESP and ESP_Properties.ESP.Offset) or 10,
	Min = 10,
	Max = 30,
	Callback = function(Value)
		ESP_Properties.ESP.Offset = Value
	end
})

local Tracer_Properties_Section = _ESP:Section({
	Name = "Tracer Properties",
	Side = "Right"
})

AddValues(Tracer_Properties_Section, ESP_Properties.Tracer or {}, {}, "Tracer_Properties_")

Tracer_Properties_Section:Dropdown({
	Name = "Position",
	Flag = "Tracer_Position",
	Content = TracerPositions,
	Default = TracerPositions[(ESP_Properties.Tracer and ESP_Properties.Tracer.Position) or 1] or "Bottom",
	Callback = function(Value)
		ESP_Properties.Tracer.Position = tablefind(TracerPositions, Value) or 1
	end
})

Tracer_Properties_Section:Slider({
	Name = "Transparency",
	Flag = "Tracer_Transparency",
	Default = ((ESP_Properties.Tracer and ESP_Properties.Tracer.Transparency) or 1) * 10,
	Min = 1,
	Max = 10,
	Callback = function(Value)
		ESP_Properties.Tracer.Transparency = Value / 10
	end
})

Tracer_Properties_Section:Slider({
	Name = "Thickness",
	Flag = "Tracer_Thickness",
	Default = (ESP_Properties.Tracer and ESP_Properties.Tracer.Thickness) or 1,
	Min = 1,
	Max = 5,
	Callback = function(Value)
		ESP_Properties.Tracer.Thickness = Value
	end
})

local Skeleton_Properties_Section = _ESP:Section({
	Name = "Skeleton Properties",
	Side = "Right"
})

AddValues(Skeleton_Properties_Section, ESP_Properties.Skeleton or {}, {}, "Skeleton_Properties_")

Skeleton_Properties_Section:Slider({
	Name = "Transparency",
	Flag = "Skeleton_Transparency",
	Default = ((ESP_Properties.Skeleton and ESP_Properties.Skeleton.Transparency) or 1) * 10,
	Min = 1,
	Max = 10,
	Callback = function(Value)
		ESP_Properties.Skeleton.Transparency = Value / 10
	end
})

Skeleton_Properties_Section:Slider({
	Name = "Thickness",
	Flag = "Skeleton_Thickness",
	Default = (ESP_Properties.Skeleton and ESP_Properties.Skeleton.Thickness) or 1,
	Min = 1,
	Max = 5,
	Callback = function(Value)
		ESP_Properties.Skeleton.Thickness = Value
	end
})

local HeadDot_Properties_Section = _ESP:Section({
	Name = "Head Dot Properties",
	Side = "Left"
})

AddValues(HeadDot_Properties_Section, ESP_Properties.HeadDot or {}, {}, "HeadDot_Properties_")

HeadDot_Properties_Section:Slider({
	Name = "Transparency",
	Flag = "HeadDot_Transparency",
	Default = ((ESP_Properties.HeadDot and ESP_Properties.HeadDot.Transparency) or 1) * 10,
	Min = 1,
	Max = 10,
	Callback = function(Value)
		ESP_Properties.HeadDot.Transparency = Value / 10
	end
})

HeadDot_Properties_Section:Slider({
	Name = "Thickness",
	Flag = "HeadDot_Thickness",
	Default = (ESP_Properties.HeadDot and ESP_Properties.HeadDot.Thickness) or 1,
	Min = 1,
	Max = 5,
	Callback = function(Value)
		ESP_Properties.HeadDot.Thickness = Value
	end
})

HeadDot_Properties_Section:Slider({
	Name = "Sides",
	Flag = "HeadDot_Sides",
	Default = (ESP_Properties.HeadDot and ESP_Properties.HeadDot.NumSides) or 30,
	Min = 3,
	Max = 30,
	Callback = function(Value)
		ESP_Properties.HeadDot.NumSides = Value
	end
})

local Box_Properties_Section1 = _ESP:Section({
	Name = "Box Properties (1 / 2)",
	Side = "Left"
})

local Box_Properties_Section2 = _ESP:Section({
	Name = "Box Properties (2 / 2)",
	Side = "Right"
})

AddValues(Box_Properties_Section1, ESP_Properties.Box or {}, {}, "Box_Properties_")

Box_Properties_Section2:Slider({
	Name = "Transparency",
	Flag = "Box_Transparency",
	Default = ((ESP_Properties.Box and ESP_Properties.Box.Transparency) or 1) * 10,
	Min = 1,
	Max = 10,
	Callback = function(Value)
		ESP_Properties.Box.Transparency = Value / 10
	end
})

Box_Properties_Section2:Slider({
	Name = "Fill Transparency",
	Flag = "Box_FillTransparency",
	Default = ((ESP_Properties.Box and ESP_Properties.Box.FillTransparency) or 0.1) * 10,
	Min = 1,
	Max = 10,
	Callback = function(Value)
		ESP_Properties.Box.FillTransparency = Value / 10
	end
})

Box_Properties_Section2:Slider({
	Name = "Thickness",
	Flag = "Box_Thickness",
	Default = (ESP_Properties.Box and ESP_Properties.Box.Thickness) or 1,
	Min = 1,
	Max = 5,
	Callback = function(Value)
		ESP_Properties.Box.Thickness = Value
	end
})

Box_Properties_Section2:Slider({
	Name = "Line Size (Corner Type)",
	Flag = "Box_LineSize",
	Default = (ESP_Properties.Box and ESP_Properties.Box.LineSize) or 14,
	Min = 2,
	Max = 20,
	Callback = function(Value)
		ESP_Properties.Box.LineSize = Value
	end
})

Box_Properties_Section2:Dropdown({
	Name = "Box Type",
	Flag = "Box_Type",
	Content = BoxTypes,
	Default = (ESP_Properties.Box and ESP_Properties.Box.Type == 2 and "Quad") or (ESP_Properties.Box and ESP_Properties.Box.Type == 3 and "Corner") or "Square",
	Callback = function(Value)
		ESP_Properties.Box.Type = (Value == "Square" and 1) or (Value == "Quad" and 2) or 3
	end
})

local HealthBar_Properties_Section = _ESP:Section({
	Name = "Health Bar Properties",
	Side = "Right"
})

AddValues(HealthBar_Properties_Section, ESP_Properties.HealthBar or {}, {}, "HealthBar_Properties_")

HealthBar_Properties_Section:Dropdown({
	Name = "Position",
	Flag = "HealthBar_Position",
	Content = HealthBarPositions,
	Default = HealthBarPositions[(ESP_Properties.HealthBar and ESP_Properties.HealthBar.Position) or 3] or "Left",
	Callback = function(Value)
		ESP_Properties.HealthBar.Position = tablefind(HealthBarPositions, Value) or 3
	end
})

HealthBar_Properties_Section:Slider({
	Name = "Transparency",
	Flag = "HealthBar_Transparency",
	Default = ((ESP_Properties.HealthBar and ESP_Properties.HealthBar.Transparency) or 1) * 10,
	Min = 1,
	Max = 10,
	Callback = function(Value)
		ESP_Properties.HealthBar.Transparency = Value / 10
	end
})

HealthBar_Properties_Section:Slider({
	Name = "Thickness",
	Flag = "HealthBar_Thickness",
	Default = (ESP_Properties.HealthBar and ESP_Properties.HealthBar.Thickness) or 1,
	Min = 1,
	Max = 5,
	Callback = function(Value)
		ESP_Properties.HealthBar.Thickness = Value
	end
})

HealthBar_Properties_Section:Slider({
	Name = "Offset",
	Flag = "HealthBar_Offset",
	Default = (ESP_Properties.HealthBar and ESP_Properties.HealthBar.Offset) or 4,
	Min = 4,
	Max = 12,
	Callback = function(Value)
		ESP_Properties.HealthBar.Offset = Value
	end
})

local Highlight_Properties_Section = _ESP:Section({
	Name = "Highlight Properties",
	Side = "Left"
})

AddValues(Highlight_Properties_Section, ESP_Properties.Highlight or {}, {}, "Highlight_Properties_")

Highlight_Properties_Section:Slider({
	Name = "Fill Transparency",
	Flag = "Highlight_Transparency",
	Default = ((ESP_Properties.Highlight and ESP_Properties.Highlight.FillTransparency) or 0.5) * 10,
	Min = 1,
	Max = 10,
	Callback = function(Value)
		ESP_Properties.Highlight.FillTransparency = Value / 10
	end
})

Highlight_Properties_Section:Slider({
	Name = "Outline Transparency",
	Flag = "Highlight_Outline_Transparency",
	Default = ((ESP_Properties.Highlight and ESP_Properties.Highlight.OutlineTransparency) or 1) * 10,
	Min = 1,
	Max = 10,
	Callback = function(Value)
		ESP_Properties.Highlight.OutlineTransparency = Value / 10
	end
})

Highlight_Properties_Section:Dropdown({
	Name = "Depth Mode",
	Flag = "Highlight_DepthMode",
	Content = {"AlwaysOnTop", "Occluded"},
	Default = (ESP_Properties.Highlight and ESP_Properties.Highlight.DepthMode == Enum.HighlightDepthMode.AlwaysOnTop and "AlwaysOnTop") or "Occluded",
	Callback = function(Value)
		ESP_Properties.Highlight.DepthMode = (Value == "AlwaysOnTop" and Enum.HighlightDepthMode.AlwaysOnTop) or Enum.HighlightDepthMode.Occluded
	end
})

--// 4. Crosshair Tab

local Crosshair_Settings = _Crosshair:Section({
	Name = "Crosshair Settings (1 / 2)",
	Side = "Left"
})

Crosshair_Settings:Toggle({
	Name = "Enabled",
	Flag = "Crosshair_Enabled",
	Default = Crosshair.Enabled or false,
	Callback = function(Value)
		Crosshair.Enabled = Value
	end
})

Crosshair_Settings:Toggle({
	Name = "Enable ROBLOX Cursor",
	Flag = "Cursor_Enabled",
	Default = UserInputService.MouseIconEnabled,
	Callback = SetMouseIconVisibility
})

AddValues(Crosshair_Settings, Crosshair, {"Enabled"}, "Crosshair_")

Crosshair_Settings:Dropdown({
	Name = "Position",
	Flag = "Crosshair_Position",
	Content = {"Mouse", "Center"},
	Default = ({"Mouse", "Center"})[Crosshair.Position or 1] or "Mouse",
	Callback = function(Value)
		Crosshair.Position = (Value == "Mouse" and 1) or 2
	end
})

Crosshair_Settings:Slider({
	Name = "Size",
	Flag = "Crosshair_Size",
	Default = Crosshair.Size or 12,
	Min = 1,
	Max = 24,
	Callback = function(Value)
		Crosshair.Size = Value
	end
})

Crosshair_Settings:Slider({
	Name = "Gap Size",
	Flag = "Crosshair_GapSize",
	Default = Crosshair.GapSize or 6,
	Min = 0,
	Max = 24,
	Callback = function(Value)
		Crosshair.GapSize = Value
	end
})

Crosshair_Settings:Slider({
	Name = "Rotation (Degrees)",
	Flag = "Crosshair_Rotation",
	Default = Crosshair.Rotation or 0,
	Min = -180,
	Max = 180,
	Callback = function(Value)
		Crosshair.Rotation = Value
	end
})

Crosshair_Settings:Slider({
	Name = "Rotation Speed",
	Flag = "Crosshair_RotationSpeed",
	Default = Crosshair.RotationSpeed or 5,
	Min = 1,
	Max = 20,
	Callback = function(Value)
		Crosshair.RotationSpeed = Value
	end
})

local _Crosshair_Settings = _Crosshair:Section({
	Name = "Crosshair Settings (2 / 2)",
	Side = "Left"
})

_Crosshair_Settings:Slider({
	Name = "Pulsing Speed",
	Flag = "Crosshair_PulsingSpeed",
	Default = Crosshair.PulsingSpeed or 5,
	Min = 1,
	Max = 20,
	Callback = function(Value)
		Crosshair.PulsingSpeed = Value
	end
})

_Crosshair_Settings:Slider({
	Name = "Pulsing Boundary (Min)",
	Flag = "Crosshair_Pulse_Min",
	Default = (Crosshair.PulsingBounds and Crosshair.PulsingBounds[1]) or 4,
	Min = 0,
	Max = 24,
	Callback = function(Value)
		if Crosshair.PulsingBounds then Crosshair.PulsingBounds[1] = Value end
	end
})

_Crosshair_Settings:Slider({
	Name = "Pulsing Boundary (Max)",
	Flag = "Crosshair_Pulse_Max",
	Default = (Crosshair.PulsingBounds and Crosshair.PulsingBounds[2]) or 8,
	Min = 0,
	Max = 24,
	Callback = function(Value)
		if Crosshair.PulsingBounds then Crosshair.PulsingBounds[2] = Value end
	end
})

_Crosshair_Settings:Slider({
	Name = "Transparency",
	Flag = "Crosshair_Transparency",
	Default = (Crosshair.Transparency or 1) * 10,
	Min = 1,
	Max = 10,
	Callback = function(Value)
		Crosshair.Transparency = Value / 10
	end
})

_Crosshair_Settings:Slider({
	Name = "Thickness",
	Flag = "Crosshair_Thickness",
	Default = Crosshair.Thickness or 1,
	Min = 1,
	Max = 5,
	Callback = function(Value)
		Crosshair.Thickness = Value
	end
})

local Crosshair_CenterDot = _Crosshair:Section({
	Name = "Center Dot Settings",
	Side = "Right"
})

Crosshair_CenterDot:Toggle({
	Name = "Enabled",
	Flag = "Crosshair_CenterDot_Enabled",
	Default = CenterDot.Enabled or true,
	Callback = function(Value)
		CenterDot.Enabled = Value
	end
})

AddValues(Crosshair_CenterDot, CenterDot, {"Enabled"}, "Crosshair_CenterDot_")

Crosshair_CenterDot:Slider({
	Name = "Radius",
	Flag = "Crosshair_CenterDot_Radius",
	Default = CenterDot.Radius or 2,
	Min = 2,
	Max = 8,
	Callback = function(Value)
		CenterDot.Radius = Value
	end
})

Crosshair_CenterDot:Slider({
	Name = "Sides",
	Flag = "Crosshair_CenterDot_Sides",
	Default = CenterDot.NumSides or 60,
	Min = 3,
	Max = 30,
	Callback = function(Value)
		CenterDot.NumSides = Value
	end
})

--// 5. Settings & Miscellaneous Tab

local SettingsSection = Settings:Section({
	Name = "Settings",
	Side = "Left"
})

local ProfilesSection = Settings:Section({
	Name = "Profiles",
	Side = "Left"
})

local InformationSection = Settings:Section({
	Name = "Information",
	Side = "Right"
})

local MiscellaneousSection = Settings:Section({
	Name = "Miscellaneous",
	Side = "Right"
})

SettingsSection:Keybind({
	Name = "Show / Hide GUI",
	Flag = "UI Toggle",
	Default = Enum.KeyCode.RightShift,
	Blacklist = {Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseButton3},
	Callback = function(_, NewKeybind)
		if not NewKeybind then
			GUI:Close()
		end
	end
})

SettingsSection:Button({
	Name = "Unload Script",
	Callback = function()
		getgenv().AirHubV2Loaded = nil
		getgenv().AirHubV2Loading = nil
		pcall(function() GUI:Unload() end)
		pcall(function() if ESP.Exit then ESP:Exit() end end)
		pcall(function() if Aimbot.Exit then Aimbot:Exit() end end)
	end
})

local ConfigList = ProfilesSection:Dropdown({
	Name = "Configurations",
	Flag = "Config Dropdown",
	Content = GUI:GetConfigs()
})

ProfilesSection:Box({
	Name = "Configuration Name",
	Flag = "Config Name",
	Placeholder = "Config Name"
})

ProfilesSection:Button({
	Name = "Load Configuration",
	Callback = function()
		GUI:LoadConfig(GUI.flags["Config Dropdown"])
	end
})

ProfilesSection:Button({
	Name = "Delete Configuration",
	Callback = function()
		GUI:DeleteConfig(GUI.flags["Config Dropdown"])
		ConfigList:Refresh(GUI:GetConfigs())
	end
})

ProfilesSection:Button({
	Name = "Save Configuration",
	Callback = function()
		GUI:SaveConfig(GUI.flags["Config Dropdown"] or GUI.flags["Config Name"])
		ConfigList:Refresh(GUI:GetConfigs())
	end
})

InformationSection:Label("Windy Universal Engine")
InformationSection:Label("AirTeam © 2022 - " .. osdate("%Y"))
InformationSection:Label("Executor: " .. (identifyexecutor and identifyexecutor() or "Unknown"))

InformationSection:Button({
	Name = "Copy Discord Link",
	Callback = function()
		if setclipboard then
			setclipboard("https://discord.gg/Ncz3H3quUZ")
			SendNotification("Clipboard", "Discord link copied!")
		end
	end
})

-- Dynamic Live Stats
local TimeLabel = MiscellaneousSection:Label("Time: " .. osdate("%X"))
local PlayersLabel = MiscellaneousSection:Label("Players: " .. tostring(#Players:GetPlayers()))
local FPSLabel = MiscellaneousSection:Label("FPS: ...")

MiscellaneousSection:Button({
	Name = "Rejoin Server",
	Callback = Rejoin
})

MiscellaneousSection:Button({
	Name = "Server Hop",
	Callback = ServerHop
})

task.spawn(function()
	while wait(1) do
		if not getgenv().AirHubV2Loaded then break end
		if TimeLabel and TimeLabel.Set then TimeLabel:Set("Time: " .. osdate("%X")) end
		if PlayersLabel and PlayersLabel.Set then PlayersLabel:Set("Players: " .. tostring(#Players:GetPlayers())) end
	end
end)

local RenderConnection
RenderConnection = RunService.RenderStepped:Connect(function(deltaTime)
	if not getgenv().AirHubV2Loaded then
		RenderConnection:Disconnect()
		return
	end
	if FPSLabel and FPSLabel.Set then
		local currentFPS = mathfloor(1 / math.max(deltaTime, 0.0001))
		FPSLabel:Set("FPS: " .. tostring(currentFPS))
	end
end)

--// Final Initialization

if ESP.Load and not ESP.Loaded then
	pcall(ESP.Load)
end

if Aimbot.Load and not Aimbot.Loaded then
	pcall(Aimbot.Load)
end

getgenv().AirHubV2Loaded = true
getgenv().AirHubV2Loading = nil

GeneralSignal:Fire()

-- Open GUI smoothly
if not GUI.open then
	GUI:Close()
end

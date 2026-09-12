--// Luraph Macro Compatibility
if LPH_OBFUSCATED == nil then
	LPH_NO_VIRTUALIZE = function(...)
		return ...
	end
end

--// Environment Setup
local getgenv = getgenv or function() return _G end
local cloneref = cloneref or LPH_NO_VIRTUALIZE(function(val) return val end)
local clonefunction = clonefunction or LPH_NO_VIRTUALIZE(function(fn) return fn end)

--// Services
local Services = setmetatable({}, {
	__index = function(self, serviceName)
		local service = cloneref(game:GetService(serviceName))
		rawset(self, serviceName, service)
		return service
	end
})

local Workspace = Services.Workspace
local Players = Services.Players
local RunService = Services.RunService
local UserInputService = Services.UserInputService

--// Globals & Caches
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Update Camera reference on respawn / scene transition
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	Camera = Workspace.CurrentCamera or Camera
end)

-- Safe Input Function Detection
local mousemoverel = mousemoverel or (Input and Input.MouseMove) or (mouse_moverel)
local mousemoveabs = mousemoveabs or (Input and Input.MouseMoveAbs) or (mouse_moveabs)
local mouse1press = mouse1press or (Input and Input.Mouse1Down) or mouse1click
local mouse1release = mouse1release or (Input and Input.Mouse1Up)

-- Drawing API Safe Initialization
local DrawingNew = (Drawing and Drawing.new) or function()
	return {
		Visible = false,
		Remove = function() end,
		Destroy = function() end
	}
end

-- Reusable Raycast Parameters (High Performance WallCheck)
local WallCheckRaycastParams = RaycastParams.new()
WallCheckRaycastParams.FilterType = RaycastFilterType.Exclude
WallCheckRaycastParams.IgnoreWater = true

--// Script Configuration Environment
getgenv().Windydev = {
	DeveloperSettings = {
		UpdateMode = "RenderStepped", -- RenderStepped, Heartbeat, or Stepped
		TeamCheckOption = "Team", -- "Team" or "TeamColor"
		RainbowSpeed = 3, -- Lower = Faster, Higher = Slower
		DisableWarnings = false
	},

	Settings = {
		Enabled = true,

		TeamCheck = false,
		AliveCheck = true,
		WallCheck = false,
		ForceFieldCheck = true, -- Ignores spawn protection shields

		-- Target Prioritization
		LockPart = "Head", -- Preferred target part ("Head", "Torso", "HumanoidRootPart", etc.)
		FallbackParts = {"Head", "UpperTorso", "Torso", "HumanoidRootPart"},

		-- Prediction Settings
		VelocityPrediction = false,
		VelocityMultiplier = 0.135,
		OffsetToMoveDirection = false,
		OffsetIncrement = 15,

		-- Smoothing Settings
		Smoothness = 1, -- 1 = Instant lock; > 1 = Smooth / Humanized aim
		Sensitivity2 = 1, -- Mouse delta sensitivity factor

		LockMode = 1, -- 1 = Camera CFrame; 2 = Mouse Move Relative; 3 = Mouse Move Absolute
		TriggerKey = Enum.UserInputType.MouseButton2,
		Toggle = false,
		RetargetOnTargetLoss = true -- Automatically find new target if current leaves FOV
	},

	Triggerbot = {
		Enabled = false,
		TeamCheck = false,
		AliveCheck = true,
		AimLockedCheck = false,
		Delay = 0.05 -- Seconds between trigger checks/clicks
	},

	ClosestPlayerTracer = {
		Enabled = false,
		Position = 3, -- 1 = Bottom; 2 = Center; 3 = Mouse
		Transparency = 0.7,
		Thickness = 1.5,
		RainbowColor = false,
		Color = Color3.fromRGB(130, 170, 255)
	},

	FOVSettings = {
		Enabled = true,
		Visible = true,
		Radius = 160,
		DynamicFOV = true, -- Adjusts FOV circle size relative to Camera Zoom
		NumSides = 64,
		Thickness = 1,
		Transparency = 0.8,
		Filled = false,

		RainbowColor = false,
		RainbowOutlineColor = false,
		Color = Color3.fromRGB(255, 255, 255),
		OutlineColor = Color3.fromRGB(15, 15, 15),
		LockedColor = Color3.fromRGB(255, 80, 80)
	},

	Blacklisted = {},
	FOVCircleOutline = DrawingNew("Circle"),
	FOVCircle = DrawingNew("Circle"),
	Tracer = DrawingNew("Line")
}

local Environment = getgenv().Windydev
local ServiceConnections = {}
local Running = false
local Typing = false
local OriginalSensitivity = UserInputService.MouseDeltaSensitivity
local LastTriggerbotClick = 0

-- Hide drawings initially
if Environment.FOVCircle then Environment.FOVCircle.Visible = false end
if Environment.FOVCircleOutline then Environment.FOVCircleOutline.Visible = false end
if Environment.Tracer then Environment.Tracer.Visible = false end

--// Helper Utilities

local function GetRainbowColor()
	local Speed = math.max(0.1, Environment.DeveloperSettings.RainbowSpeed)
	return Color3.fromHSV((tick() % Speed) / Speed, 0.8, 1)
end

local function GetTargetPart(character, preferredPart)
	if not character then return nil end
	local part = character:FindFirstChild(preferredPart)
	if part then return part end

	-- Fallback to alternative rig parts (R6 / R15 / Custom)
	for _, fallback in ipairs(Environment.Settings.FallbackParts) do
		part = character:FindFirstChild(fallback)
		if part then return part end
	end
	return nil
end

local function IsAlive(player, character, humanoid)
	if not character or not humanoid then return false end
	if humanoid.Health <= 0 then return false end
	if Environment.Settings.ForceFieldCheck and character:FindFirstChildOfClass("ForceField") then
		return false
	end
	return true
end

local function IsTeammate(player)
	local option = Environment.DeveloperSettings.TeamCheckOption
	if option == "Team" then
		return (player.Team ~= nil and player.Team == LocalPlayer.Team)
	elseif option == "TeamColor" then
		return player.TeamColor == LocalPlayer.TeamColor
	end
	return false
end

local function IsBehindWall(targetPosition, targetCharacter)
	local origin = Camera.CFrame.Position
	local direction = targetPosition - origin

	local localChar = LocalPlayer.Character
	local ignoreList = {Camera}
	if localChar then table.insert(ignoreList, localChar) end
	if targetCharacter then table.insert(ignoreList, targetCharacter) end

	WallCheckRaycastParams.FilterDescendantsInstances = ignoreList

	local result = Workspace:Raycast(origin, direction, WallCheckRaycastParams)
	return (result ~= nil)
end

local function GetDynamicFOVRadius()
	local baseRadius = Environment.FOVSettings.Radius
	if not Environment.FOVSettings.DynamicFOV then
		return baseRadius
	end
	-- Scale radius against default 70 FOV
	return baseRadius * (70 / math.max(Camera.FieldOfView, 1))
end

--// Target Acquisition

local function CancelLock()
	Environment.Locked = nil
	if Environment.FOVCircle then
		Environment.FOVCircle.Color = Environment.FOVSettings.Color
	end
	UserInputService.MouseDeltaSensitivity = OriginalSensitivity
	if Environment.Tracer then
		Environment.Tracer.Visible = false
	end
end

local function GetClosestTarget(isAuxCheck)
	local settings = Environment.Settings
	local fovRadius = Environment.FOVSettings.Enabled and GetDynamicFOVRadius() or 2000
	local shortest2DDistance = fovRadius
	local bestTarget = nil
	local mousePos = UserInputService:GetMouseLocation()

	for _, player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then continue end
		if table.find(Environment.Blacklisted, player.Name) then continue end

		local character = player.Character
		if not character then continue end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if settings.AliveCheck and not IsAlive(player, character, humanoid) then continue end
		if settings.TeamCheck and IsTeammate(player) then continue end

		local targetPart = GetTargetPart(character, settings.LockPart)
		if not targetPart then continue end

		local partPosition = targetPart.Position

		if settings.WallCheck and IsBehindWall(partPosition, character) then
			continue
		end

		local screenPos, onScreen = Camera:WorldToViewportPoint(partPosition)
		if not onScreen then continue end

		local screenPos2D = Vector2.new(screenPos.X, screenPos.Y)
		local screenDistance = (mousePos - screenPos2D).Magnitude

		if screenDistance < shortest2DDistance then
			shortest2DDistance = screenDistance
			bestTarget = player
		end
	end

	if not isAuxCheck then
		Environment.Locked = bestTarget
		if not bestTarget then
			CancelLock()
		end
	end

	return bestTarget
end

--// Core Engine

local function Load()
	OriginalSensitivity = UserInputService.MouseDeltaSensitivity

	local Settings = Environment.Settings
	local Triggerbot = Environment.Triggerbot
	local Tracer = Environment.Tracer
	local FOVCircle = Environment.FOVCircle
	local FOVCircleOutline = Environment.FOVCircleOutline
	local TracerSettings = Environment.ClosestPlayerTracer
	local FOVSettings = Environment.FOVSettings
	local UpdateMode = Environment.DeveloperSettings.UpdateMode

	-- Triggerbot Pipeline
	if mouse1press and mouse1release then
		ServiceConnections.Triggerbot = RunService[UpdateMode]:Connect(LPH_NO_VIRTUALIZE(function()
			if not Triggerbot.Enabled then return end
			if os.clock() - LastTriggerbotClick < Triggerbot.Delay then return end

			local target = Mouse.Target
			if not target or not target.Parent then return end

			local character = target.Parent
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid and character.Parent then
				-- Multi-accessory / model fallback
				character = character.Parent
				humanoid = character:FindFirstChildOfClass("Humanoid")
			end

			local player = Players:GetPlayerFromCharacter(character)
			if not player or player == LocalPlayer then return end

			if Triggerbot.TeamCheck and IsTeammate(player) then return end
			if Triggerbot.AliveCheck and not IsAlive(player, character, humanoid) then return end
			if Triggerbot.AimLockedCheck and Environment.Locked ~= player then return end

			LastTriggerbotClick = os.clock()
			task.spawn(function()
				mouse1press()
				task.wait(0.02)
				mouse1release()
			end)
		end))
	end

	-- Tracer Render Loop
	ServiceConnections.UpdateTracer = RunService[UpdateMode]:Connect(LPH_NO_VIRTUALIZE(function()
		if not TracerSettings.Enabled or not Settings.Enabled then
			Tracer.Visible = false
			return
		end

		local candidate = Environment.Locked or GetClosestTarget(true)
		if not candidate or not candidate.Character then
			Tracer.Visible = false
			return
		end

		local targetPart = GetTargetPart(candidate.Character, Settings.LockPart)
		if not targetPart then
			Tracer.Visible = false
			return
		end

		local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
		if not onScreen then
			Tracer.Visible = false
			return
		end

		local viewport = Camera.ViewportSize
		local mousePos = UserInputService:GetMouseLocation()

		Tracer.Visible = true
		Tracer.Transparency = TracerSettings.Transparency
		Tracer.Thickness = TracerSettings.Thickness
		Tracer.Color = TracerSettings.RainbowColor and GetRainbowColor() or TracerSettings.Color

		if TracerSettings.Position == 1 then
			Tracer.From = Vector2.new(viewport.X / 2, viewport.Y)
		elseif TracerSettings.Position == 2 then
			Tracer.From = Vector2.new(viewport.X / 2, viewport.Y / 2)
		else
			Tracer.From = mousePos
		end

		Tracer.To = Vector2.new(screenPos.X, screenPos.Y)
	end))

	-- Main Render & Aim Step
	ServiceConnections.RenderSteppedConnection = RunService[UpdateMode]:Connect(LPH_NO_VIRTUALIZE(function(deltaTime)
		local mousePos = UserInputService:GetMouseLocation()
		local dynamicRadius = GetDynamicFOVRadius()

		-- FOV Circle Positioning & Color
		if FOVSettings.Enabled and Settings.Enabled then
			FOVCircle.Visible = FOVSettings.Visible
			FOVCircle.Radius = dynamicRadius
			FOVCircle.NumSides = FOVSettings.NumSides
			FOVCircle.Thickness = FOVSettings.Thickness
			FOVCircle.Filled = FOVSettings.Filled
			FOVCircle.Transparency = FOVSettings.Transparency
			FOVCircle.Position = mousePos
			FOVCircle.Color = (Environment.Locked and FOVSettings.LockedColor) or (FOVSettings.RainbowColor and GetRainbowColor()) or FOVSettings.Color

			FOVCircleOutline.Visible = FOVSettings.Visible
			FOVCircleOutline.Radius = dynamicRadius
			FOVCircleOutline.NumSides = FOVSettings.NumSides
			FOVCircleOutline.Thickness = FOVSettings.Thickness + 1.5
			FOVCircleOutline.Filled = false
			FOVCircleOutline.Transparency = FOVSettings.Transparency
			FOVCircleOutline.Position = mousePos
			FOVCircleOutline.Color = FOVSettings.RainbowOutlineColor and GetRainbowColor() or FOVSettings.OutlineColor
		else
			FOVCircle.Visible = false
			FOVCircleOutline.Visible = false
		end

		-- Targeting & Lock Logic
		if Running and Settings.Enabled then
			if not Environment.Locked or Settings.RetargetOnTargetLoss then
				GetClosestTarget(false)
			end

			if Environment.Locked and Environment.Locked.Character then
				local character = Environment.Locked.Character
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				local targetPart = GetTargetPart(character, Settings.LockPart)

				-- Target Invalidated Checks
				if not targetPart or (Settings.AliveCheck and not IsAlive(Environment.Locked, character, humanoid)) then
					CancelLock()
					return
				end

				-- Compute Position Offsets & Predictions
				local targetWorldPos = targetPart.Position
				local offset = Vector3.zero

				if Settings.VelocityPrediction then
					local velocity = targetPart.AssemblyLinearVelocity or targetPart.Velocity or Vector3.zero
					offset = offset + (velocity * Settings.VelocityMultiplier)
				end

				if Settings.OffsetToMoveDirection and humanoid then
					local moveDirection = humanoid.MoveDirection
					local increment = math.clamp(Settings.OffsetIncrement, 1, 30) / 10
					offset = offset + (moveDirection * increment)
				end

				local finalWorldPos = targetWorldPos + offset
				local viewportPoint, onScreen = Camera:WorldToViewportPoint(finalWorldPos)
				local viewport2D = Vector2.new(viewportPoint.X, viewportPoint.Y)

				-- Distance Check (Escape lock if target steps outside FOV radius)
				if (mousePos - viewport2D).Magnitude > dynamicRadius or not onScreen then
					CancelLock()
					return
				end

				-- Aim Action Based on LockMode
				if Settings.LockMode == 1 then
					-- Camera CFrame Manipulation with Smooth Interpolation
					local targetCFrame = CFrame.new(Camera.CFrame.Position, finalWorldPos)
					local factor = math.clamp((1 / math.max(Settings.Smoothness, 1)) * (deltaTime * 60), 0.01, 1)
					Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, factor)
					UserInputService.MouseDeltaSensitivity = 0
				elseif Settings.LockMode == 2 and mousemoverel then
					-- Relative Mouse Shift
					local delta = (viewport2D - mousePos) / math.max(Settings.Sensitivity2, 0.1)
					local smoothFactor = math.clamp(1 / math.max(Settings.Smoothness, 1), 0.05, 1)
					mousemoverel(delta.X * smoothFactor, delta.Y * smoothFactor)
				elseif Settings.LockMode == 3 and mousemoveabs then
					-- Absolute Mouse Coordinates
					mousemoveabs(viewport2D.X, viewport2D.Y)
				end
			else
				CancelLock()
			end
		end
	end))

	-- Input Handling
	ServiceConnections.InputBegan = UserInputService.InputBegan:Connect(LPH_NO_VIRTUALIZE(function(input, processed)
		if Typing or processed then return end

		local trigger = Settings.TriggerKey
		local isTriggerMatch = (input.UserInputType == trigger or (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == trigger))

		if isTriggerMatch then
			if Settings.Toggle then
				Running = not Running
				if not Running then CancelLock() end
			else
				Running = true
			end
		end
	end))

	ServiceConnections.InputEnded = UserInputService.InputEnded:Connect(LPH_NO_VIRTUALIZE(function(input)
		if Typing or Settings.Toggle then return end

		local trigger = Settings.TriggerKey
		local isTriggerMatch = (input.UserInputType == trigger or (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == trigger))

		if isTriggerMatch then
			Running = false
			CancelLock()
		end
	end))
end

-- Focus & Chat Checking
ServiceConnections.FocusStart = UserInputService.TextBoxFocused:Connect(function() Typing = true end)
ServiceConnections.FocusEnd = UserInputService.TextBoxFocusReleased:Connect(function() Typing = false end)

--// API Methods

Environment.Restart = LPH_NO_VIRTUALIZE(function()
	for key, conn in pairs(ServiceConnections) do
		if conn and conn.Disconnect then
			conn:Disconnect()
		end
	end
	table.clear(ServiceConnections)
	Load()
end)

Environment.Exit = LPH_NO_VIRTUALIZE(function()
	for key, conn in pairs(ServiceConnections) do
		if conn and conn.Disconnect then
			conn:Disconnect()
		end
	end
	table.clear(ServiceConnections)

	CancelLock()

	if Environment.FOVCircle then Environment.FOVCircle:Remove() end
	if Environment.FOVCircleOutline then Environment.FOVCircleOutline:Remove() end
	if Environment.Tracer then Environment.Tracer:Remove() end

	getgenv().Windydev = nil
end)

Environment.Blacklist = LPH_NO_VIRTUALIZE(function(self, username)
	assert(type(username) == "string", "Windydev.Blacklist: Username parameter must be a string.")

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Name:lower():sub(1, #username) == username:lower() then
			username = player.Name
			break
		end
	end

	if not table.find(self.Blacklisted, username) then
		table.insert(self.Blacklisted, username)
	end
end)

Environment.Whitelist = LPH_NO_VIRTUALIZE(function(self, username)
	assert(type(username) == "string", "Windydev.Whitelist: Username parameter must be a string.")

	local idx = table.find(self.Blacklisted, username)
	if idx then
		table.remove(self.Blacklisted, idx)
	end
end)

Environment.GetClosestPlayer = function()
	return GetClosestTarget(true)
end

-- Initialize Engine
Load()
return Environment

--// Universal Roblox Utility & Functions Library (Revamped)
--// Optimized for modern executors & Luau performance

local cloneref = cloneref or function(instance) return instance end
local clonefunction = clonefunction or function(fn) return fn end

--// Services
local Services = setmetatable({}, {
	__index = function(self, name)
		local success, service = pcall(function()
			return cloneref(game:GetService(name))
		end)
		if success and service then
			rawset(self, name, service)
			return service
		end
		return nil
	end
})

local Players = Services.Players
local Workspace = Services.Workspace
local HttpService = Services.HttpService
local UserInputService = Services.UserInputService
local RunService = Services.RunService
local TeleportService = Services.TeleportService
local StarterGui = Services.StarterGui

--// Dynamic Camera & Player
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	Camera = Workspace.CurrentCamera or Camera
end)

--// Executor HTTP Abstraction
local httpRequest = (syn and syn.request) 
	or (http and http.request) 
	or (fluxus and fluxus.request) 
	or request 
	or http_request

local httpGet = clonefunction(function(url)
	if game.HttpGet then
		return game:HttpGet(url)
	elseif httpRequest then
		local response = httpRequest({Url = url, Method = "GET"})
		return response.Body
	end
	error("Executor does not support HTTP GET requests.")
end)

--// Persistent Raycast Params
local WallRaycastParams = RaycastParams.new()
WallRaycastParams.FilterType = RaycastFilterType.Exclude
WallRaycastParams.IgnoreWater = true

--// Library Construction
local Library = {
	Services = Services,
	Connections = {},
	Typing = false
}

-- Manage typing state globally without polluting getfenv
table.insert(Library.Connections, UserInputService.TextBoxFocused:Connect(function()
	Library.Typing = true
end))

table.insert(Library.Connections, UserInputService.TextBoxFocusReleased:Connect(function()
	Library.Typing = false
end))

--// String & Color Utilities

function Library.StringToRGB(str)
	if type(str) ~= "string" then return nil end
	local r, g, b = str:match("(%d+)%s*[,%s]%s*(%d+)%s*[,%s]%s*(%d+)")
	if r and g and b then
		return Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))
	end
	return nil
end

function Library.RGBToString(color)
	if typeof(color) ~= "Color3" then return "" end
	return string.format("%d, %d, %d", math.round(color.R * 255), math.round(color.G * 255), math.round(color.B * 255))
end

--// Serialization

function Library.Encode(tbl)
	if type(tbl) ~= "table" then return nil end
	local success, result = pcall(function()
		return HttpService:JSONEncode(tbl)
	end)
	return success and result or nil
end

function Library.Decode(str)
	if type(str) ~= "string" then return nil end
	local success, result = pcall(function()
		return HttpService:JSONDecode(str)
	end)
	return success and result or nil
end

--// Notifications & UI

function Library.SendNotification(title, text, duration, icon)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = tostring(title or "Notification"),
			Text = tostring(text or ""),
			Duration = tonumber(duration) or 5,
			Icon = icon
		})
	end)
end

function Library.SetMouseIconVisibility(visible)
	UserInputService.MouseIconEnabled = visible
end

function Library.SetFOV(fov)
	Camera.FieldOfView = math.clamp(tonumber(fov) or 70, 1, 120)
end

--// Player Checks & Validation

function Library.GetPlayer(query)
	if not query or query == "" then return nil end
	query = tostring(query):lower()

	local playerList = Players:GetPlayers()

	-- 1. Exact Match (Username or DisplayName)
	for _, player in ipairs(playerList) do
		if player.Name:lower() == query or player.DisplayName:lower() == query then
			return player
		end
	end

	-- 2. Prefix / Starts-With Match
	for _, player in ipairs(playerList) do
		if player.Name:lower():sub(1, #query) == query or player.DisplayName:lower():sub(1, #query) == query then
			return player
		end
	end

	return nil
end

function Library.AliveCheck(player)
	player = player or LocalPlayer
	if not player then return false end

	local char = player.Character
	if not char then return false end

	local hum = char:FindFirstChildOfClass("Humanoid")
	return (hum ~= nil and hum.Health > 0)
end

function Library.TeamCheck(player)
	if not player or player == LocalPlayer then return false end
	if player.Team ~= nil and LocalPlayer.Team ~= nil then
		return player.Team == LocalPlayer.Team
	end
	return player.TeamColor == LocalPlayer.TeamColor
end

--// Spatial & Raycast Utilities

function Library.ExtractPosition(object)
	if typeof(object) == "Vector3" then
		return object
	elseif typeof(object) == "Instance" then
		if object:IsA("BasePart") then
			return object.Position
		elseif object:IsA("Model") then
			return object:GetPivot().Position
		end
	end
	return nil
end

function Library.OnScreenCheck(object)
	local pos = Library.ExtractPosition(object)
	if not pos then return false, Vector2.zero end

	local screenPoint, onScreen = Camera:WorldToViewportPoint(pos)
	return onScreen, Vector2.new(screenPoint.X, screenPoint.Y)
end

function Library.WallCheck(target, customIgnore)
	local targetPos = Library.ExtractPosition(target)
	if not targetPos then return true end

	local origin = Camera.CFrame.Position
	local direction = targetPos - origin

	local ignoreList = {Camera}
	if LocalPlayer.Character then
		table.insert(ignoreList, LocalPlayer.Character)
	end

	if typeof(target) == "Instance" then
		local char = target:IsA("Model") and target or target:FindFirstAncestorOfClass("Model")
		if char then
			table.insert(ignoreList, char)
		end
	end

	if type(customIgnore) == "table" then
		for _, item in ipairs(customIgnore) do
			table.insert(ignoreList, item)
		end
	end

	WallRaycastParams.FilterDescendantsInstances = ignoreList
	local hit = Workspace:Raycast(origin, direction, WallRaycastParams)

	return (hit ~= nil)
end

function Library.GetClosestPlayer(maxScreenDist, preferredPart, teamCheck, aliveCheck, wallCheck)
	maxScreenDist = maxScreenDist or math.huge
	preferredPart = preferredPart or "HumanoidRootPart"

	local bestPlayer = nil
	local shortestDist = maxScreenDist
	local mousePos = UserInputService:GetMouseLocation()

	for _, player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then continue end

		local char = player.Character
		if not char then continue end

		if aliveCheck and not Library.AliveCheck(player) then continue end
		if teamCheck and Library.TeamCheck(player) then continue end

		local targetPart = char:FindFirstChild(preferredPart) or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
		if not targetPart then continue end

		if wallCheck and Library.WallCheck(targetPart) then continue end

		local onScreen, screenPos2D = Library.OnScreenCheck(targetPart)
		if not onScreen then continue end

		local dist = (mousePos - screenPos2D).Magnitude
		if dist < shortestDist then
			shortestDist = dist
			bestPlayer = player
		end
	end

	return bestPlayer, shortestDist
end

--// Networking & Server Operations

function Library.GetUniverseId()
	-- game.GameId is natively supported and requires zero HTTP requests
	if game.GameId and game.GameId ~= 0 then
		return game.GameId
	end

	-- Modern v1 Web API fallback
	local success, body = pcall(httpGet, string.format("https://games.roblox.com/v1/games/multiget-place-details?placeIds=%d", game.PlaceId))
	if success and body then
		local data = Library.Decode(body)
		if data and data[1] and data[1].universeId then
			return data[1].universeId
		end
	end
	return nil
end

function Library.GetIP()
	local success, result = pcall(httpGet, "https://api.ipify.org")
	return success and result or nil
end

function Library.GetHWID()
	if gethwid then return gethwid() end

	if httpRequest then
		local success, response = pcall(httpRequest, {Url = "https://httpbin.org/get", Method = "GET"})
		if success and response and response.Body then
			local data = Library.Decode(response.Body)
			local headers = data and data.headers or {}

			for _, header in ipairs({"Exploit-Guid", "Syn-Fingerprint", "Proto-User-Identifier", "Sentinel-Fingerprint", "SW-Fingerprint", "krnl-hwid"}) do
				if headers[header] then
					return headers[header]
				end
			end
		end
	end
	return nil
end

function Library.Rejoin()
	if #Players:GetPlayers() <= 1 then
		LocalPlayer:Kick("\n[Library] Rejoining server...")
		task.wait(0.2)
		TeleportService:Teleport(game.PlaceId, LocalPlayer)
	else
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
	end
end

function Library.ServerHop(minPlayers, maxPing)
	minPlayers = minPlayers or 1
	maxPing = maxPing or 200

	local success, body = pcall(httpGet, string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100", tostring(game.PlaceId)))
	if not success or not body then
		warn("[Library.ServerHop] Failed to query server list.")
		return
	end

	local decoded = Library.Decode(body)
	if not decoded or not decoded.data then
		warn("[Library.ServerHop] Invalid server response data.")
		return
	end

	for _, server in ipairs(decoded.data) do
		if type(server) == "table" and server.id ~= game.JobId then
			local playing = tonumber(server.playing) or 0
			local maxP = tonumber(server.maxPlayers) or 0
			local ping = tonumber(server.ping) or 999

			if playing >= minPlayers and playing < maxP and ping <= maxPing then
				TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
				return
			end
		end
	end

	warn("[Library.ServerHop] No matching server found. Falling back to default teleport.")
	TeleportService:Teleport(game.PlaceId, LocalPlayer)
end

--// Performance Diagnostics

function Library.TestSpeed(func, iterations)
	assert(type(func) == "function", "TestSpeed: Parameter #1 must be a function.")
	iterations = iterations or 1000

	local start = os.clock()
	for _ = 1, iterations do
		func()
	end
	return os.clock() - start
end

--// Optional Global Exporter

function Library.ExportGlobals(targetEnv)
	targetEnv = targetEnv or getgenv and getgenv() or _G
	for key, value in pairs(Library) do
		if key ~= "Connections" and key ~= "ExportGlobals" and key ~= "Unload" then
			targetEnv[key] = value
		end
	end
	for name, service in pairs(Services) do
		targetEnv[name] = service
	end
end

--// Unload Cleanly

function Library.Unload()
	for _, conn in ipairs(Library.Connections) do
		if conn and conn.Disconnect then
			conn:Disconnect()
		end
	end
	table.clear(Library.Connections)
end

return L

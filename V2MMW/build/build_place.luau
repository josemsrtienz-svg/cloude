--[[
	V2MMW • build_place.luau  (herramienta, NO es parte del juego)

	Genera desde cero, con Lune (https://lune-org.github.io/docs):
	  V2MMW.rbxlx                 el place completo listo para abrir en Roblox Studio
	  Models/World/*.rbxmx        Lobby, cabinas y mapas por separado
	  Models/Memes/*.rbxmx        modelos 3D de cada meme

	Uso (desde la carpeta V2MMW):  lune run build/build_place.luau
	El mundo se construye con el MISMO código del juego (WorldBuilder + MemeModels), así que lo que
	ves en Studio es exactamente lo que el servidor espera encontrar.
]]

local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Instance = roblox.Instance
local game = Instance.new("DataModel")

-- ============================================================ servicios
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
for _, name in ipairs({ "Players", "ServerStorage", "StarterGui", "StarterPack", "SoundService", "Teams", "Chat", "TextChatService" }) do
	pcall(function()
		game:GetService(name)
	end)
end
local sps = Instance.new("StarterPlayerScripts")
sps.Parent = StarterPlayer
local scs = Instance.new("StarterCharacterScripts")
scs.Parent = StarterPlayer

-- ============================================================ scripts desde src/
local function addScript(parent, name: string, className: string, path: string)
	local s = Instance.new(className)
	s.Name = name
	s.Source = fs.readFile(path)
	s.Parent = parent
	return s
end

local function walk(dir: string, parent)
	local entries = fs.readDir(dir)
	table.sort(entries)
	for _, entry in ipairs(entries) do
		local full = dir .. "/" .. entry
		if fs.isDir(full) then
			local f = Instance.new("Folder")
			f.Name = entry
			f.Parent = parent
			walk(full, f)
		elseif entry:sub(-4) == ".lua" and entry:sub(1, 5) ~= "init." then
			if entry:sub(-11) == ".server.lua" then
				addScript(parent, entry:sub(1, -12), "Script", full)
			elseif entry:sub(-11) == ".client.lua" then
				addScript(parent, entry:sub(1, -12), "LocalScript", full)
			else
				addScript(parent, entry:sub(1, -5), "ModuleScript", full)
			end
		end
	end
end

local shared = Instance.new("Folder")
shared.Name = "V2MMW"
shared.Parent = ReplicatedStorage
walk("src/ReplicatedStorage/V2MMW", shared)

local server = Instance.new("Folder")
server.Name = "V2MMWServer"
server.Parent = ServerScriptService
walk("src/ServerScriptService/V2MMWServer", server)

local client = addScript(sps, "V2MMWClient", "LocalScript", "src/StarterPlayer/StarterPlayerScripts/V2MMWClient/init.client.lua")
walk("src/StarterPlayer/StarterPlayerScripts/V2MMWClient", client)

-- ============================================================ ejecutar los módulos del juego aquí
local cache = {}
local env
local function requireModule(inst)
	if cache[inst] ~= nil then
		return cache[inst]
	end
	-- en esta herramienta todo existe ya: WaitForChild == FindFirstChild
	local src = inst.Source:gsub(":WaitForChild%(", ":FindFirstChild(")
	local moduleEnv = table.clone(env)
	moduleEnv.script = inst
	local fn = luau.load(src, { debugName = inst.Name, environment = moduleEnv })
	local result = fn()
	cache[inst] = result
	return result
end
env = {
	game = game,
	workspace = Workspace,
	require = requireModule,
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	Enum = roblox.Enum,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	NumberRange = roblox.NumberRange,
	Random = roblox.Random,
	warn = function(...)
		print("[warn]", ...)
	end,
	print = print,
	pcall = pcall,
	typeof = typeof,
	type = type,
	tostring = tostring,
	tonumber = tonumber,
	ipairs = ipairs,
	pairs = pairs,
	next = next,
	select = select,
	error = error,
	assert = assert,
	setmetatable = setmetatable,
	getmetatable = getmetatable,
	math = math,
	table = table,
	string = string,
	utf8 = utf8,
	os = os,
}

local Systems = server:FindFirstChild("Systems")
local WorldBuilder = requireModule(Systems:FindFirstChild("WorldBuilder"))
WorldBuilder.Build()

-- ============================================================ ambiente
Lighting.ClockTime = 14.5
Lighting.Brightness = 2.2
Lighting.Ambient = roblox.Color3.fromRGB(90, 80, 120)
Lighting.OutdoorAmbient = roblox.Color3.fromRGB(150, 140, 180)
Lighting.GlobalShadows = true
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.28
atmosphere.Offset = 0.15
atmosphere.Color = roblox.Color3.fromRGB(200, 180, 255)
atmosphere.Decay = roblox.Color3.fromRGB(120, 90, 200)
atmosphere.Glare = 0.4
atmosphere.Haze = 1.2
atmosphere.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.6
bloom.Size = 30
bloom.Threshold = 1.6
bloom.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect")
cc.Saturation = 0.15
cc.Contrast = 0.05
cc.Parent = Lighting

-- ============================================================ escribir archivos
fs.writeFile("V2MMW.rbxlx", roblox.serializePlace(game, true))
print("✔ V2MMW.rbxlx")

local function ensureDir(path)
	if not fs.isDir(path) then
		fs.writeDir(path)
	end
end
ensureDir("Models")
ensureDir("Models/World")
ensureDir("Models/Memes")
for _, child in ipairs(Workspace:GetChildren()) do
	if child.Name == "Lobby" or child.Name == "MatchStations" or child.Name == "Maps" then
		fs.writeFile("Models/World/" .. child.Name .. ".rbxmx", roblox.serializeModel({ child }, true))
		print("✔ Models/World/" .. child.Name .. ".rbxmx")
	end
end
local MemeModels = requireModule(shared:FindFirstChild("Shared"):FindFirstChild("MemeModels"))
local MemeCatalog = requireModule(shared:FindFirstChild("Config"):FindFirstChild("MemeCatalog"))
local count = 0
for _, meme in ipairs(MemeCatalog.List) do
	local model = MemeModels.Build(meme.Id)
	if model then
		fs.writeFile("Models/Memes/" .. meme.Id .. ".rbxmx", roblox.serializeModel({ model }, true))
		count += 1
	end
end
print(("✔ Models/Memes: %d modelos"):format(count))

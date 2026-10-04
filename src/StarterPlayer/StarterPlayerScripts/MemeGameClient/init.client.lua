--[[
	MemeGame • MemeGameClient (LocalScript)
	StarterPlayer > StarterPlayerScripts > MemeGameClient

	Punto de entrada del cliente. Crea la ScreenGui "MainHUD" (capa ENCIMA del juego, nunca lo
	sustituye) y arranca los controladores de Controllers/. El personaje se mueve con normalidad
	todo el tiempo; los paneles se abren/cierran sin bloquear el movimiento.
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local Controllers = script:WaitForChild("Controllers")

local UI = require(Controllers.UIKit)
local State = require(Controllers.State)

-- La hotbar de Roblox se reemplaza por la nuestra (3 slots de memes)
task.spawn(function()
	for _ = 1, 10 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		if ok then
			break
		end
		task.wait(1)
	end
end)

local gui = UI.new("ScreenGui", {
	Name = "MainHUD",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- ================================================= App: lo que comparten los controladores
local app = {}
app.Gui = gui
app.UI = UI
app.State = State

local panels: { [string]: GuiObject } = {}
local openName: string? = nil

function app.RegisterPanel(name: string, frame: GuiObject, closeButton: GuiButton?)
	panels[name] = frame
	if closeButton then
		closeButton.Activated:Connect(function()
			app.ClosePanels()
		end)
	end
end

function app.ClosePanels()
	for _, frame in pairs(panels) do
		frame.Visible = false
	end
	openName = nil
	app.Tooltip(nil)
end

function app.OpenPanel(name: string)
	local frame = panels[name]
	if not frame then
		return
	end
	if State.GameState() == "Match" and name ~= "Settings" then
		State.Notify:Fire("Termina la partida para usar " .. name, "Error")
		return
	end
	app.ClosePanels()
	openName = name
	frame.Visible = true
	UI.pop(frame, 0.85)
end

function app.TogglePanel(name: string)
	if openName == name then
		app.ClosePanels()
	else
		app.OpenPanel(name)
	end
end

-- Tooltip pequeño que sigue al mouse (descripción de memes)
local tooltip = UI.new("TextLabel", { Name = "Tooltip", BackgroundColor3 = UI.Theme.PanelDark, TextColor3 = UI.Theme.Text,
	Font = UI.Theme.FontBody, TextSize = 14, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
	Size = UDim2.fromOffset(220, 0), Visible = false, ZIndex = 50, Parent = gui })
UI.corner(tooltip, 8)
UI.padding(tooltip, 8)
UI.stroke(tooltip, 2, UI.Theme.Primary)
function app.Tooltip(text: string?)
	tooltip.Visible = text ~= nil and not UserInputService.TouchEnabled
	tooltip.Text = text or ""
end
UserInputService.InputChanged:Connect(function(input)
	if tooltip.Visible and input.UserInputType == Enum.UserInputType.MouseMovement then
		tooltip.Position = UDim2.fromOffset(input.Position.X + 16, input.Position.Y - 20)
	end
end)

-- Confeti (compras y victorias)
function app.Confetti()
	local colors = { UI.Theme.Primary, UI.Theme.Secondary, UI.Theme.Accent, UI.Theme.Success }
	for i = 1, 40 do
		local piece = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(math.random(), 0, -0.05, 0),
			Size = UDim2.fromOffset(math.random(8, 14), math.random(12, 20)), Rotation = math.random(0, 360),
			BackgroundColor3 = colors[(i % #colors) + 1], BorderSizePixel = 0, ZIndex = 40, Parent = gui })
		local t = math.random(14, 24) / 10
		UI.tween(piece, t, { Position = UDim2.new(piece.Position.X.Scale + (math.random() - 0.5) * 0.2, 0, 1.05, 0),
			Rotation = piece.Rotation + math.random(-360, 360) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(t, function()
			piece:Destroy()
		end)
	end
end

-- ================================================= controladores (orden: el HUD necesita Navigation)
State.Init()
local Navigation = require(Controllers.Navigation)
app.Navigation = Navigation
Navigation.Init(app)

for _, name in ipairs({ "HUD", "Hotbar", "InventoryPanel", "ShopPanel", "TradePanel", "SettingsPanel", "StationUI", "MatchUI" }) do
	local ok, err = pcall(function()
		require(Controllers[name]).Init(app)
	end)
	if not ok then
		warn(("[MemeGame] Error iniciando %s: %s"):format(name, tostring(err)))
	end
end

-- ================================================= interacción con el mundo 3D
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "OpenShop" then
		app.OpenPanel("Shop")
	elseif prompt.Name == "OpenTrade" then
		app.OpenPanel("Trade")
	end
end)

-- B del mando cierra el panel abierto
UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.ButtonB and openName then
		app.ClosePanels()
	end
end)

-- Si cambia el estado (cabina/partida), se cierran los paneles para no estorbar
State.GameStateChanged:Connect(function(state)
	if state ~= "Lobby" then
		app.ClosePanels()
		Navigation.Stop()
	end
end)

print("[MemeGame] Cliente listo")

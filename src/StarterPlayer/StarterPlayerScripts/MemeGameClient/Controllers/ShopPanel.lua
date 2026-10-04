--[[
	MemeGame • ShopPanel (ModuleScript, cliente)
	MemeMarket: tienda de memes con MemeCoin (rojo, amarillo y blanco; marca propia).
	Se abre con el botón TIENDA o hablando con el Chico de la Tienda en el lobby.
	El precio que se muestra es informativo: el servidor usa SIEMPRE su propio catálogo.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("MemeGame")
local GameConfig = require(Shared.Config.GameConfig)
local MemeCatalog = require(Shared.Config.MemeCatalog)
local Util = require(Shared.Shared.Util)

local ShopPanel = {}

local RED = Color3.fromRGB(218, 32, 40)
local YELLOW = Color3.fromRGB(255, 196, 0)
local WHITE = Color3.fromRGB(250, 250, 250)

function ShopPanel.Init(app)
	local UI, State = app.UI, app.State
	local T = UI.Theme

	local panel, content, close = UI.panel(app.Gui, "ShopPanel", "🛒 " .. GameConfig.ShopName, Vector2.new(800, 530), RED)
	panel.BackgroundColor3 = WHITE
	app.RegisterPanel("Shop", panel, close)
	local header = panel:FindFirstChild("Header")
	UI.new("Frame", { Name = "YellowStripe", Size = UDim2.new(1, 0, 0, 8), Position = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = YELLOW, BorderSizePixel = 0, Parent = header })
	UI.label({ Text = "abierto 24/7 · ¿le redondeamos? 🧾", AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(260, 24),
		Position = UDim2.new(1, -60, 0, 18), TextColor3 = YELLOW, Parent = header }, { MaxSize = 18 })

	local balance = UI.label({ Name = "Balance", Text = "", Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 2),
		TextColor3 = RED, Font = T.FontTitle, Parent = content }, { Stroke = false, MaxSize = 22 })

	local scroll = UI.new("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 1, -34), CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 8, ScrollBarImageColor3 = RED, Parent = content })
	UI.padding(scroll, 6)
	UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(172, 250), CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = scroll })

	local cards = {}
	for _, meme in ipairs(MemeCatalog.List) do
		if meme.InShop then
			local rarity = MemeCatalog.Rarities[meme.Rarity]
			local card = UI.new("Frame", { Name = meme.Id, BackgroundColor3 = WHITE, LayoutOrder = meme.Value, Parent = scroll })
			UI.corner(card, 14)
			UI.stroke(card, 3, RED)
			local band = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = rarity.Color, Parent = card })
			UI.corner(band, 14)
			UI.label({ Text = rarity.Name, Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 2), Font = T.FontTitle, Parent = band }, { MaxSize = 16 })
			UI.memeIcon(meme.Id, { Size = UDim2.fromOffset(100, 100), Position = UDim2.fromOffset(36, 28), Parent = card })
			UI.label({ Text = meme.Name, Size = UDim2.new(1, -12, 0, 24), Position = UDim2.fromOffset(6, 132), TextColor3 = T.Stroke,
				Parent = card }, { Stroke = false, MaxSize = 18 })
			local owned = UI.label({ Name = "Owned", Text = "", Size = UDim2.new(1, -12, 0, 16), Position = UDim2.fromOffset(6, 156),
				TextColor3 = Color3.fromRGB(90, 90, 110), Font = T.FontBody, Parent = card }, { Stroke = false, MaxSize = 13 })
			local priceTag = UI.new("Frame", { Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 174), BackgroundColor3 = YELLOW, Parent = card })
			UI.corner(priceTag, 8)
			UI.label({ Text = ("%s %s %s"):format(GameConfig.CurrencyEmoji, Util.formatNumber(meme.Value), GameConfig.CurrencyName),
				Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 2), TextColor3 = T.Stroke, Font = T.FontTitle, Parent = priceTag },
				{ Stroke = false, MaxSize = 18 })
			local buy = UI.button({ Size = UDim2.new(1, -20, 0, 38), Position = UDim2.fromOffset(10, 206), Parent = card },
				{ Color = RED, Text = "COMPRAR", TextSize = 22, Radius = 10 })
			buy.Activated:Connect(function()
				local ok = State.Request("BuyMeme", meme.Id)
				if ok then
					UI.pop(card, 1.15)
					UI.playSound("Purchase")
					app.Confetti()
				else
					UI.shake(card)
				end
			end)
			card.MouseEnter:Connect(function()
				app.Tooltip(meme.Description)
			end)
			card.MouseLeave:Connect(function()
				app.Tooltip(nil)
			end)
			cards[meme.Id] = { Owned = owned, Buy = buy, Price = meme.Value }
		end
	end

	local function render(data)
		if not data then
			return
		end
		balance.Text = ("Tu saldo: %s %s %s"):format(GameConfig.CurrencyEmoji, Util.formatNumber(data.MemeCoin), GameConfig.CurrencyName)
		for id, c in pairs(cards) do
			local n = data.OwnedMemes[id] or 0
			c.Owned.Text = n > 0 and ("Tienes x%d"):format(n) or "No lo tienes"
			c.Buy.BackgroundColor3 = data.MemeCoin >= c.Price and RED or Color3.fromRGB(150, 140, 140)
		end
	end
	State.DataChanged:Connect(render)
	if State.Data then
		render(State.Data)
	end
end

return ShopPanel

--[[
	MemeGame • TradePanel (ModuleScript, cliente)
	1) Lista de jugadores del servidor → ENVIAR SOLICITUD.
	2) El otro jugador recibe una invitación (ACEPTAR / RECHAZAR).
	3) Ventana de intercambio: TU OFERTA ↔ OFERTA DEL OTRO JUGADOR, tu inventario para añadir memes,
	   y ACEPTAR / CANCELAR. El servidor valida todo y solo completa si los dos aceptan.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("MemeGame")
local GameConfig = require(Shared.Config.GameConfig)
local MemeCatalog = require(Shared.Config.MemeCatalog)
local Remotes = require(Shared.Shared.Remotes)

local TradePanel = {}

local player = Players.LocalPlayer
local PURPLE = Color3.fromRGB(185, 90, 255)

function TradePanel.Init(app)
	local UI, State = app.UI, app.State
	local T = UI.Theme

	local panel, content, close = UI.panel(app.Gui, "TradePanel", "🤝 INTERCAMBIO", Vector2.new(820, 540), PURPLE)
	app.RegisterPanel("Trade", panel, close)

	local session = nil -- estado del servidor
	local myOffer: { [string]: number } = {}

	-- ================================================= vista 1: elegir jugador
	local pickView = UI.new("Frame", { Name = "PickView", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = content })
	UI.label({ Text = "Elige con quién quieres intercambiar memes:", Size = UDim2.new(1, 0, 0, 30), Parent = pickView }, { MaxSize = 22 })
	local playerList = UI.new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 1, -40), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 8, Parent = pickView })
	UI.list(playerList, Enum.FillDirection.Vertical, 8)
	local alone = UI.label({ Text = "No hay nadie más en el servidor 😢\n(En Studio: Prueba → Clientes y servidores → 2 jugadores)",
		Size = UDim2.new(1, 0, 0, 70), TextColor3 = T.TextDim, Visible = false, Parent = playerList }, { MaxSize = 20 })

	local function renderPlayers()
		for _, c in ipairs(playerList:GetChildren()) do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		local count = 0
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player then
				count += 1
				local row = UI.new("Frame", { Name = other.Name, Size = UDim2.new(1, -16, 0, 60), BackgroundColor3 = T.PanelLight, LayoutOrder = count, Parent = playerList })
				UI.corner(row, 12)
				UI.stroke(row, 2)
				local img = UI.new("ImageLabel", { Size = UDim2.fromOffset(48, 48), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = T.PanelDark, Parent = row })
				UI.corner(img, 24)
				task.spawn(function()
					local ok, thumb = pcall(function()
						return Players:GetUserThumbnailAsync(other.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
					end)
					if ok then
						img.Image = thumb
					end
				end)
				UI.label({ Text = other.DisplayName .. "  (@" .. other.Name .. ")", Size = UDim2.new(1, -300, 0, 30), Position = UDim2.fromOffset(64, 15),
					TextXAlignment = Enum.TextXAlignment.Left, Parent = row }, { MaxSize = 22 })
				local send = UI.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(210, 44), Parent = row },
					{ Color = PURPLE, Text = "ENVIAR SOLICITUD", TextSize = 20 })
				send.Activated:Connect(function()
					State.Request("TradeRequest", other.UserId)
				end)
			end
		end
		alone.Visible = count == 0
	end
	Players.PlayerAdded:Connect(renderPlayers)
	Players.PlayerRemoving:Connect(function()
		task.defer(renderPlayers)
	end)
	renderPlayers()

	-- ================================================= vista 2: intercambio
	local tradeView = UI.new("Frame", { Name = "TradeView", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = content })
	local function offerBox(title: string, x: number)
		local box = UI.new("Frame", { BackgroundColor3 = T.PanelDark, Position = UDim2.new(x, x > 0 and 6 or 0, 0, 0),
			Size = UDim2.new(0.5, -6, 0, 210), Parent = tradeView })
		UI.corner(box, 14)
		local stroke = UI.stroke(box, 3)
		local titleLbl = UI.label({ Text = title, Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 6), Font = T.FontTitle,
			TextXAlignment = Enum.TextXAlignment.Left, Parent = box }, { MaxSize = 22 })
		local status = UI.label({ Text = "", AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(140, 24), Position = UDim2.new(1, -10, 0, 8),
			TextColor3 = T.Success, Parent = box }, { MaxSize = 18 })
		local grid = UI.new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 40),
			Size = UDim2.new(1, -16, 1, -48), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, Parent = box })
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(84, 100), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
		return { Box = box, Stroke = stroke, Title = titleLbl, Status = status, Grid = grid }
	end
	local mine = offerBox("TU OFERTA", 0)
	local theirs = offerBox("OFERTA DEL OTRO", 0.5)

	UI.label({ Text = "TU INVENTARIO (toca un meme para añadirlo a tu oferta)", Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 218),
		TextColor3 = T.TextDim, TextXAlignment = Enum.TextXAlignment.Left, Parent = tradeView }, { MaxSize = 16 })
	local invStrip = UI.new("ScrollingFrame", { BackgroundColor3 = T.PanelDark, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 242),
		Size = UDim2.new(1, 0, 0, 120), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.X, Parent = tradeView })
	UI.corner(invStrip, 12)
	UI.padding(invStrip, 8)
	UI.list(invStrip, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

	local acceptBtn = UI.button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, -8, 1, -2), Size = UDim2.fromOffset(240, 54), Parent = tradeView },
		{ Color = T.Success, Text = "✅ ACEPTAR", TextSize = 28, Font = T.FontTitle })
	local cancelBtn = UI.button({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, 8, 1, -2), Size = UDim2.fromOffset(240, 54), Parent = tradeView },
		{ Color = T.Danger, Text = "❌ CANCELAR", TextSize = 28, Font = T.FontTitle })
	acceptBtn.Activated:Connect(function()
		State.Request("TradeAccept")
	end)
	cancelBtn.Activated:Connect(function()
		State.Request("TradeCancel")
	end)

	local function sendOffer()
		State.Request("TradeSetOffer", myOffer)
	end

	local function offerCell(parent, id: string, qty: number, order: number, onClick: (() -> ())?)
		local cell = UI.new("TextButton", { Name = id, Text = "", AutoButtonColor = false, BackgroundColor3 = T.PanelLight, LayoutOrder = order,
			Size = UDim2.fromOffset(84, 100), Parent = parent })
		UI.corner(cell, 10)
		UI.stroke(cell, 2, MemeCatalog.GetRarity(id).Color)
		UI.memeIcon(id, { Size = UDim2.fromOffset(60, 60), Position = UDim2.fromOffset(12, 4), Parent = cell })
		local meme = MemeCatalog.Get(id)
		UI.label({ Text = meme and meme.Name or id, Size = UDim2.new(1, -6, 0, 18), Position = UDim2.fromOffset(3, 64), Parent = cell }, { MaxSize = 12 })
		UI.label({ Text = "x" .. qty, Size = UDim2.new(1, -6, 0, 16), Position = UDim2.fromOffset(3, 82), TextColor3 = T.Primary, Font = T.FontTitle, Parent = cell }, { MaxSize = 14 })
		if onClick then
			cell.Activated:Connect(onClick)
		end
		return cell
	end

	local function clear(frame)
		for _, c in ipairs(frame:GetChildren()) do
			if c:IsA("GuiButton") then
				c:Destroy()
			end
		end
	end

	local function render()
		local inSession = session ~= nil
		pickView.Visible = not inSession
		tradeView.Visible = inSession
		if not inSession then
			renderPlayers()
			return
		end
		theirs.Title.Text = "OFERTA DE " .. string.upper(session.Partner)
		mine.Status.Text = session.MyAccepted and "✅ ACEPTADO" or ""
		theirs.Status.Text = session.TheirAccepted and "✅ ACEPTADO" or "esperando..."
		theirs.Status.TextColor3 = session.TheirAccepted and T.Success or T.TextDim
		mine.Stroke.Color = session.MyAccepted and T.Success or T.Stroke
		theirs.Stroke.Color = session.TheirAccepted and T.Success or T.Stroke
		acceptBtn.BackgroundColor3 = session.MyAccepted and Color3.fromRGB(120, 140, 120) or T.Success

		clear(mine.Grid)
		clear(theirs.Grid)
		clear(invStrip)
		local order = 0
		for id, qty in pairs(session.MyOffer or {}) do
			order += 1
			offerCell(mine.Grid, id, qty, order, function()
				-- quitar uno de la oferta
				myOffer[id] = (myOffer[id] or 0) - 1
				if myOffer[id] <= 0 then
					myOffer[id] = nil
				end
				sendOffer()
			end)
		end
		order = 0
		for id, qty in pairs(session.TheirOffer or {}) do
			order += 1
			offerCell(theirs.Grid, id, qty, order, nil)
		end
		local data = State.Data
		if data then
			local ids = {}
			for id in pairs(data.OwnedMemes) do
				table.insert(ids, id)
			end
			MemeCatalog.Sort(ids)
			for i, id in ipairs(ids) do
				local available = data.OwnedMemes[id] - (myOffer[id] or 0)
				if available > 0 then
					offerCell(invStrip, id, available, i, function()
						local distinct = 0
						for _ in pairs(myOffer) do
							distinct += 1
						end
						if not myOffer[id] and distinct >= GameConfig.Trade.MaxItemsPerSide then
							State.Notify:Fire(("Máximo %d memes distintos por oferta"):format(GameConfig.Trade.MaxItemsPerSide), "Error")
							return
						end
						myOffer[id] = (myOffer[id] or 0) + 1
						sendOffer()
					end)
				end
			end
		end
	end

	Remotes.Get("TradeState").OnClientEvent:Connect(function(state)
		local wasOpen = session ~= nil
		session = state
		if state then
			myOffer = table.clone(state.MyOffer or {})
			if not wasOpen then
				app.OpenPanel("Trade")
			end
		else
			myOffer = {}
		end
		render()
	end)
	State.DataChanged:Connect(function()
		if session then
			render()
		end
	end)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then
			render()
		elseif session then
			-- cerrar la ventana durante un intercambio lo cancela
			State.Request("TradeCancel")
		end
	end)

	-- ================================================= invitación entrante
	Remotes.Get("TradeInvite").OnClientEvent:Connect(function(invite)
		local card = UI.new("Frame", { Name = "TradeInvite", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -150),
			Size = UDim2.fromOffset(320, 130), BackgroundColor3 = T.Panel, Parent = app.Gui })
		UI.responsive(card)
		UI.corner(card, 16)
		UI.stroke(card, 4, PURPLE)
		UI.label({ Text = "🤝 " .. invite.FromName .. " quiere intercambiar contigo", Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 8), Parent = card }, { MaxSize = 22 })
		local yes = UI.button({ Size = UDim2.new(0.5, -15, 0, 46), Position = UDim2.new(0, 10, 1, -56), Parent = card }, { Color = T.Success, Text = "ACEPTAR", TextSize = 22 })
		local no = UI.button({ Size = UDim2.new(0.5, -15, 0, 46), Position = UDim2.new(0.5, 5, 1, -56), Parent = card }, { Color = T.Danger, Text = "RECHAZAR", TextSize = 22 })
		UI.pop(card, 0.5)
		local done = false
		local function respond(accept: boolean)
			if done then
				return
			end
			done = true
			card:Destroy()
			State.Request("TradeRespond", invite.FromUserId, accept)
		end
		yes.Activated:Connect(function()
			respond(true)
		end)
		no.Activated:Connect(function()
			respond(false)
		end)
		task.delay(invite.Timeout or 20, function()
			if not done then
				done = true
				card:Destroy()
			end
		end)
	end)
end

return TradePanel

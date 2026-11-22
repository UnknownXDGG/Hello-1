local NovaUI = (function()
--[[
    NovaUI  v1.0.0
    Premium glass UI library for Roblox (Luau) - mobile + PC, executor friendly.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local StatsService = game:GetService("Stats")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local HapticService = game:GetService("HapticService")
local LocalPlayer = Players.LocalPlayer

local NovaUI = { Version = "1.0.0", Flags = {} }

-- ========== VIBRATION HELPER (throttled, can be switched off in Settings) ==========
NovaUI.Haptics = true
local lastVib = 0
local function vibrate()
	local now = os.clock()
	if now - lastVib < 0.12 then
		return
	end
	lastVib = now
	if NovaUI.Sound then
		NovaUI.Sound("click", 0.22)
	end
	if not NovaUI.Haptics or not UserInputService.TouchEnabled then
		return
	end
	pcall(function()
		for _, it in ipairs({ Enum.UserInputType.Touch, Enum.UserInputType.Gamepad1 }) do
			if HapticService:IsMotorSupported(it, Enum.VibrationMotor.Small) then
				HapticService:SetMotor(it, Enum.VibrationMotor.Small, 1)
				task.delay(0.08, function()
					pcall(HapticService.SetMotor, HapticService, it, Enum.VibrationMotor.Small, 0)
				end)
				return
			end
		end
	end)
end

------------------------------------------------------------------------
-- Themes
------------------------------------------------------------------------
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local THEMES = {
	Midnight = { Accent = rgb(92, 124, 255), Panel = rgb(26, 30, 48), Card = rgb(11, 13, 24), Raised = rgb(42, 47, 76), Sub = rgb(150, 158, 192) },
	Crimson = { Accent = rgb(255, 64, 84), Panel = rgb(36, 22, 28), Card = rgb(18, 9, 13), Raised = rgb(58, 34, 43), Sub = rgb(196, 150, 158) },
	Ocean = { Accent = rgb(28, 200, 235), Panel = rgb(18, 32, 46), Card = rgb(7, 16, 26), Raised = rgb(30, 55, 74), Sub = rgb(140, 178, 196) },
	Violet = { Accent = rgb(170, 90, 255), Panel = rgb(31, 22, 48), Card = rgb(14, 8, 27), Raised = rgb(52, 37, 80), Sub = rgb(170, 148, 198) },
	Emerald = { Accent = rgb(36, 214, 130), Panel = rgb(18, 35, 31), Card = rgb(7, 18, 15), Raised = rgb(30, 58, 49), Sub = rgb(140, 190, 172) },
	Mono = { Accent = rgb(236, 236, 242), Panel = rgb(31, 31, 36), Card = rgb(10, 10, 12), Raised = rgb(52, 52, 58), Sub = rgb(162, 162, 170), OnAccent = rgb(14, 14, 18) },
	Blackhole = { Accent = rgb(150, 70, 255), Panel = rgb(6, 3, 12), Card = rgb(2, 1, 5), Raised = rgb(24, 14, 42), Sub = rgb(140, 118, 186), Text = rgb(232, 220, 255), Stroke = rgb(96, 56, 170), OnAccent = rgb(255, 255, 255) },
}
local THEME_ORDER = { "Blackhole", "Midnight", "Crimson", "Ocean", "Violet", "Emerald", "Mono" }

for _, t in pairs(THEMES) do
	t.Text = t.Text or rgb(244, 246, 255)
	t.Stroke = t.Stroke or rgb(255, 255, 255)
	t.OnAccent = t.OnAccent or rgb(255, 255, 255)
	t.AccentHover = t.Accent:Lerp(rgb(255, 255, 255), 0.18)
end

local State = { Theme = "Blackhole", PanelAlpha = 0.16 }
local Theme = THEMES.Blackhole

NovaUI.Themes = THEMES

NovaUI.Icons = {
	home = "⌂", user = "☺", users = "☻", settings = "⚙", grid = "▦", chat = "✉",
	bolt = "⚡", eye = "◉", shield = "⛨", star = "★", wifi = "≋", clock = "◷",
	check = "✓", chevron = "›", search = "⌕", plus = "+", minus = "–", close = "✕",
	palette = "◐", cube = "⬢", server = "▤", game = "◈", refresh = "↻", sun = "☀",
	feature = "☺", dot = "●",
}

------------------------------------------------------------------------
-- Core helpers
------------------------------------------------------------------------
local Binds, Conns = {}, {}
local GuiRoot = nil

local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(Conns, c)
	return c
end

local function tween(inst, t, props, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function apply(inst, props, instant)
	if instant then
		for k, v in pairs(props) do
			inst[k] = v
		end
	else
		tween(inst, 0.25, props)
	end
end

local function bind(inst, fn)
	table.insert(Binds, { inst = inst, fn = fn })
	fn(true)
end

local function refresh(instant)
	for i = #Binds, 1, -1 do
		local b = Binds[i]
		if GuiRoot and b.inst:IsDescendantOf(GuiRoot) then
			b.fn(instant)
		else
			table.remove(Binds, i)
		end
	end
end

local function paint(inst, prop, key)
	bind(inst, function(instant)
		apply(inst, { [prop] = Theme[key] }, instant)
	end)
end

local function panelPaint(inst)
	bind(inst, function(instant)
		apply(inst, { BackgroundColor3 = Theme.Panel, BackgroundTransparency = State.PanelAlpha }, instant)
	end)
end

local BOXES = { Frame = true, TextButton = true, TextLabel = true, TextBox = true, ScrollingFrame = true, ImageLabel = true, ImageButton = true }

local function new(class, props, parent)
	local o = Instance.new(class)
	if BOXES[class] then
		o.BorderSizePixel = 0
	end
	for k, v in pairs(props or {}) do
		o[k] = v
	end
	if parent then
		o.Parent = parent
	end
	return o
end

local function corner(p, r)
	return new("UICorner", { CornerRadius = UDim.new(0, r) }, p)
end

local function pad(p, l, t, r, b)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t),
		PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b),
	}, p)
end

local function list(p, gap, dir, ha, va)
	return new("UIListLayout", {
		Padding = UDim.new(0, gap or 0),
		FillDirection = dir or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = ha or Enum.HorizontalAlignment.Left,
		VerticalAlignment = va or Enum.VerticalAlignment.Top,
	}, p)
end

local function stroke(p, alpha, key)
	local s = new("UIStroke", { Thickness = 1, Transparency = alpha or 0.88, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
	paint(s, "Color", key or "Stroke")
	return s
end

local BOLD = Enum.Font.GothamBold
local MED = Enum.Font.GothamMedium
local LEFT, CENTER, RIGHT = Enum.TextXAlignment.Left, Enum.TextXAlignment.Center, Enum.TextXAlignment.Right
local AX, AY = Enum.AutomaticSize.X, Enum.AutomaticSize.Y

local function label(parent, props, colorKey)
	local p = {
		BackgroundTransparency = 1, Font = MED, TextSize = 14,
		TextXAlignment = LEFT, TextYAlignment = Enum.TextYAlignment.Center, Text = "",
	}
	for k, v in pairs(props) do
		p[k] = v
	end
	local l = new("TextLabel", p, parent)
	if colorKey ~= false then
		paint(l, "TextColor3", colorKey or "Text")
	end
	return l
end

------------------------------------------------------------------------
-- Image assets (icons + blackhole parts). Written to the executor workspace once,
-- then loaded with getcustomasset. Falls back to glyphs / plain shapes if unsupported.
------------------------------------------------------------------------
local ICON_ALIAS = { feature = "sliders", dot = "record", exploits = "flame", commands = "terminal" }
local ASSET_VER = "v5"
local assetCache = {}
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local b64map

local function b64decode(s)
	for _, f in ipairs({
		function() return crypt and crypt.base64decode end,
		function() return crypt and crypt.base64 and crypt.base64.decode end,
		function() return base64_decode end,
		function() return base64 and base64.decode end,
		function() return syn and syn.crypt and syn.crypt.base64 and syn.crypt.base64.decode end,
	}) do
		local okf, fn = pcall(f)
		if okf and type(fn) == "function" then
			local ok, r = pcall(fn, s)
			if ok and type(r) == "string" and #r > 16 then
				return r
			end
		end
	end
	if not b64map then
		b64map = {}
		for i = 1, 64 do
			b64map[B64:byte(i)] = i - 1
		end
	end
	local out, n = {}, 0
	local buf, bits = 0, 0
	for i = 1, #s do
		local v = b64map[s:byte(i)]
		if v then
			buf = buf * 64 + v
			bits = bits + 6
			if bits >= 8 then
				bits = bits - 8
				local div = 2 ^ bits
				local byte = math.floor(buf / div)
				buf = buf - byte * div
				n = n + 1
				out[n] = string.char(byte)
			end
		end
	end
	return table.concat(out)
end

function NovaUI.Asset(name)
	local c = assetCache[name]
	if c ~= nil then
		return c or nil
	end
	local url = false
	local data = YADSAN_ASSETS and YADSAN_ASSETS[name]
	if data and writefile and getcustomasset then
		pcall(function()
			pcall(makefolder, "YADSAN_HUB")
			pcall(makefolder, "YADSAN_HUB/assets")
			local path = "YADSAN_HUB/assets/" .. name .. "_" .. ASSET_VER .. ".png"
			if not (isfile and isfile(path)) then
				local bin = b64decode(data)
				if not bin or #bin < 16 then
					return
				end
				writefile(path, bin)
			end
			local u = getcustomasset(path)
			if type(u) == "string" and u ~= "" then
				url = u
			end
		end)
	end
	assetCache[name] = url
	return url or nil
end

local function icon(parent, name, size, colorKey, props)
	local key = ICON_ALIAS[name] or name
	local asset = (type(name) == "string" and (name:find("rbxasset") or name:find("http"))) and name or NovaUI.Asset(key)
	local o
	if asset then
		o = new("ImageLabel", { BackgroundTransparency = 1, Image = asset, Size = UDim2.fromOffset(size + 3, size + 3) }, parent)
		if colorKey then
			paint(o, "ImageColor3", colorKey)
		end
	else
		local v = NovaUI.Icons[name] or NovaUI.Icons[key] or "●"
		o = label(parent, {
			Text = tostring(v), TextSize = size, Font = BOLD, TextXAlignment = CENTER,
			Size = UDim2.fromOffset(size + 4, size + 4),
		}, colorKey)
	end
	for k, val in pairs(props or {}) do
		o[k] = val
	end
	return o
end

NovaUI.Sounds = true
local sndCache = {}
function NovaUI.Sound(name, vol, life, force)
	if not NovaUI.Sounds and not force then
		return
	end
	local url = sndCache[name]
	if url == nil then
		url = false
		local data = YADSAN_SOUNDS and YADSAN_SOUNDS[name]
		if data and writefile and getcustomasset then
			pcall(function()
				pcall(makefolder, "YADSAN_HUB")
				pcall(makefolder, "YADSAN_HUB/assets")
				local path = "YADSAN_HUB/assets/snd_" .. name .. "_" .. ASSET_VER .. ".wav"
				if not (isfile and isfile(path)) then
					local bin = b64decode(data)
					if not bin then
						return
					end
					writefile(path, bin)
				end
				local u = getcustomasset(path)
				if type(u) == "string" and u ~= "" then
					url = u
				end
			end)
		end
		sndCache[name] = url
	end
	if not url then
		return
	end
	local snd
	pcall(function()
		local s = Instance.new("Sound")
		s.SoundId = url
		s.Volume = vol or 0.5
		s.Parent = game:GetService("SoundService")
		s:Play()
		snd = s
		task.delay(life or 4, function()
			s:Destroy()
		end)
	end)
	return snd
end

-- Animated blackhole (accretion disk + photon ring + glow). Used by the orb and the intro.
function NovaUI.MakeBlackhole(parent, size, cfg)
	cfg = cfg or {}
	local accent = cfg.Color or Theme.Accent
	local half = Vector2.new(0.5, 0.5)
	local holder = new("Frame", {
		BackgroundTransparency = 1, AnchorPoint = half, Position = cfg.Position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size), ZIndex = cfg.ZIndex or 1,
	}, parent)
	local aGlow, aBack, aFront, aRing = NovaUI.Asset("bh_glow"), NovaUI.Asset("bh_back"), NovaUI.Asset("bh_front"), NovaUI.Asset("bh_ring")
	local fancy = aGlow and aBack and aFront and aRing
	local disk = new("Frame", {
		BackgroundTransparency = 1, AnchorPoint = half, Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size * 1.5, size * 0.75), Rotation = -16, ZIndex = 2,
	}, holder)
	local glow, ring, back, front
	local function img(par, asset, w, h, z, tint)
		return new("ImageLabel", {
			BackgroundTransparency = 1, AnchorPoint = half, Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(w, h), Image = asset, ZIndex = z, ImageColor3 = tint or Color3.new(1, 1, 1),
		}, par)
	end
	if fancy then
		glow = img(holder, aGlow, size * 2.1, size * 2.1, 1, accent)
		glow.ImageTransparency = 0.5
		back = img(disk, aBack, size * 1.5, size * 0.75, 1)
	else
		glow = new("Frame", { BackgroundColor3 = accent, BackgroundTransparency = 0.82, AnchorPoint = half, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size * 1.3, size * 1.3), ZIndex = 1 }, holder)
		corner(glow, size)
	end
	local core = new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0), AnchorPoint = half, Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size * 0.56, size * 0.56), ZIndex = 2,
	}, disk)
	corner(core, size)
	if fancy then
		ring = img(disk, aRing, size * 0.76, size * 0.76, 3)
		front = img(disk, aFront, size * 1.5, size * 0.75, 4)
	else
		ring = new("Frame", { BackgroundTransparency = 1, AnchorPoint = half, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size * 0.66, size * 0.66), ZIndex = 3 }, disk)
		corner(ring, size)
		new("UIStroke", { Thickness = 3, Color = Color3.fromRGB(235, 215, 255), Transparency = 0.1 }, ring)
		front = new("Frame", { BackgroundTransparency = 1, AnchorPoint = half, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), ZIndex = 4 }, disk)
		corner(front, size)
		local st = new("UIStroke", { Thickness = 3, Color = accent, Transparency = 0.15 }, front)
		new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 60)), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, accent) }) }, st)
	end
	if cfg.Bind and fancy then
		bind(glow, function()
			glow.ImageColor3 = Theme.Accent
		end)
	end
	-- flowing light along the accretion disk
	local function flow(img)
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 95, 110)),
			ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 95, 110)),
		})
		g.Parent = img
		return g
	end
	local gBack, gFront
	if fancy then
		gBack, gFront = flow(back), flow(front)
	end
	-- orbiting matter
	local bits = {}
	if cfg.Particles ~= false then
		local rnd = Random.new()
		for i = 1, cfg.ParticleCount or 14 do
			local d = Instance.new("Frame")
			local sz = rnd:NextInteger(2, 4)
			d.Size = UDim2.fromOffset(sz, sz)
			d.AnchorPoint = half
			d.BorderSizePixel = 0
			d.BackgroundColor3 = (i % 3 == 0) and Color3.fromRGB(255, 190, 120) or ((i % 3 == 1) and Color3.new(1, 1, 1) or Color3.fromRGB(215, 170, 255))
			d.BackgroundTransparency = 0.15
			d.ZIndex = 1
			d.Parent = disk
			Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
			bits[i] = { f = d, a = rnd:NextNumber() * math.pi * 2, r = 0.55 + rnd:NextNumber() * 0.5, front = false }
		end
	end
	local coreStroke = new("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1), Transparency = 1 }, core)
	local wTarget, wb = cfg.White and 1 or 0, cfg.White and 1 or 0
	local boost = 0
	local t0 = math.random() * 10
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not holder.Parent then
			conn:Disconnect()
			return
		end
		local t = os.clock() + t0
		wb = wb + (wTarget - wb) * math.min(1, dt * 4.5)
		boost = boost * math.max(0, 1 - dt * 2.2)
		core.BackgroundColor3 = Color3.new(wb, wb, wb)
		coreStroke.Transparency = 1 - wb * 0.85
		ring.Rotation = (ring.Rotation + dt * (28 + boost * 220 * (wTarget == 1 and 1 or -1))) % 360
		disk.Rotation = -16 + math.sin(t * 0.7) * 3
		if fancy then
			glow.ImageColor3 = accent:Lerp(Color3.new(1, 1, 1), wb)
			glow.ImageTransparency = math.max(0, 0.46 - wb * 0.2 - boost * 0.3) + 0.1 * math.sin(t * 1.5)
			gBack.Offset = Vector2.new((t * 0.32) % 2 - 1, 0)
			gFront.Offset = Vector2.new((t * 0.32 + 1) % 2 - 1, 0)
			local k = 1 + 0.035 * math.sin(t * 2.1)
			ring.Size = UDim2.fromOffset(size * 0.76 * k, size * 0.76 * k)
		else
			glow.BackgroundTransparency = 0.8 + 0.06 * math.sin(t * 1.5)
		end
		for _, p in ipairs(bits) do
			p.a = p.a + dt * (1.1 + boost * 3) / (p.r ^ 1.5)
			if wb > 0.5 then
				p.r = p.r + dt * 0.22
				if p.r > 1.45 then p.r = 0.45 end
			else
				p.r = p.r - dt * 0.1
				if p.r < 0.45 then p.r = 1.35 end
			end
			local sn = math.sin(p.a)
			p.f.Position = UDim2.fromScale(0.5 + math.cos(p.a) * 0.46 * p.r, 0.5 + sn * 0.205 * p.r)
			local fr = sn > 0
			if fr ~= p.front then
				p.front = fr
				p.f.ZIndex = fr and 5 or 1
			end
		end
	end)
	local api = { Glow = glow, Disk = disk, Core = core, Ring = ring }
	function api.SetWhite(on, instant)
		wTarget = on and 1 or 0
		if instant then
			wb = wTarget
		end
	end
	function api.Boost(v)
		boost = v or 1
	end
	function api.IsWhite()
		return wTarget == 1
	end
	return holder, api
end

local function fire(cb, ...)
	-- Trigger vibration on callback
	vibrate()
	if type(cb) ~= "function" then
		return
	end
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = pcall(cb, table.unpack(args, 1, args.n))
		if not ok then
			warn("[NovaUI] callback error: " .. tostring(err))
		end
	end)
end

local function isPress(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

local function isMove(i)
	return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
end

local function btnStyle(btn, base, hov)
	paint(btn, "BackgroundColor3", base)
	btn.MouseEnter:Connect(function()
		tween(btn, 0.15, { BackgroundColor3 = Theme[hov] })
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, 0.15, { BackgroundColor3 = Theme[base] })
	end)
end

local function draggable(area, scroller, update)
	local dragging = false
	area.InputBegan:Connect(function(i)
		if isPress(i) then
			dragging = true
			if scroller then
				scroller.ScrollingEnabled = false
			end
			update(i.Position)
		end
	end)
	connect(UserInputService.InputChanged, function(i)
		if dragging and isMove(i) then
			update(i.Position)
		end
	end)
	connect(UserInputService.InputEnded, function(i)
		if dragging and isPress(i) then
			dragging = false
			if scroller then
				scroller.ScrollingEnabled = true
			end
		end
	end)
end

local ThumbCache = {}
local function loadThumb(userId, img)
	if ThumbCache[userId] then
		img.Image = ThumbCache[userId]
		return
	end
	task.spawn(function()
		local ok, url = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and url then
			ThumbCache[userId] = url
			if img.Parent then
				img.Image = url
			end
		end
	end)
end

local function getHumanoid()
	local c = LocalPlayer.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function getPing()
	local ok, v = pcall(function()
		return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	return ok and math.floor(v) or 0
end

local function formatTime(sec)
	sec = math.floor(sec)
	local h, m, s = math.floor(sec / 3600), math.floor((sec % 3600) / 60), sec % 60
	if h > 0 then
		return string.format("%dh %dm", h, m)
	end
	return string.format("%dm %02ds", m, s)
end

------------------------------------------------------------------------
-- Config encode / decode
------------------------------------------------------------------------
local function encode(v)
	local t = typeof(v)
	if t == "Color3" then
		return { __t = "Color3", r = v.R, g = v.G, b = v.B }
	elseif t == "EnumItem" then
		return { __t = "Enum", name = v.Name }
	end
	return v
end

local function decode(v)
	if type(v) == "table" and v.__t == "Color3" then
		return Color3.new(v.r, v.g, v.b)
	elseif type(v) == "table" and v.__t == "Enum" then
		return v.name
	end
	return v
end

------------------------------------------------------------------------
-- Classes
------------------------------------------------------------------------
local Window = {}
Window.__index = Window
local Tab = {}
Tab.__index = Tab
local Section = {}
Section.__index = Section

------------------------------------------------------------------------
-- Section elements
------------------------------------------------------------------------
function Section:_next()
	self._order = self._order + 1
	return self._order
end

function Section:_row(h, clickable)
	local r = new(clickable and "TextButton" or "Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, h), LayoutOrder = self:_next(),
	}, self.Body)
	if clickable then
		r.Text = ""
		r.AutoButtonColor = false
	end
	return r
end

function Section:_flag(flag, obj, value)
	if not flag then
		return
	end
	NovaUI.Flags[flag] = value
	self.Window._setters[flag] = function(v)
		obj:Set(v)
	end
end

function Section:Label(text)
	local l = label(self.Body, {
		Text = text or "", TextSize = 13, TextWrapped = true, AutomaticSize = AY,
		Size = UDim2.new(1, 0, 0, 0), LayoutOrder = self:_next(),
	}, "Sub")
	return { Set = function(_, t) l.Text = t end }
end

function Section:Paragraph(cfg)
	local f = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, LayoutOrder = self:_next() }, self.Body)
	list(f, 2)
	label(f, { Text = cfg.Title or "", Font = BOLD, TextSize = 14, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1 })
	label(f, { Text = cfg.Content or "", TextSize = 13, TextWrapped = true, AutomaticSize = AY, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2 }, "Sub")
end

function Section:Divider()
	local d = new("Frame", { Size = UDim2.new(1, 0, 0, 1), LayoutOrder = self:_next(), BackgroundTransparency = 0.9 }, self.Body)
	paint(d, "BackgroundColor3", "Stroke")
end

function Section:Toggle(cfg)
	local state = cfg.Default == true
	local desc = cfg.Description
	local r = self:_row(desc and 50 or 40, true)
	local x = 0
	if cfg.Icon then
		icon(r, cfg.Icon, 20, "Sub", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0) })
		x = 38
	end
	label(r, {
		Text = cfg.Title or "Toggle", Font = BOLD, TextSize = 15, TextTruncate = Enum.TextTruncate.AtEnd,
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, x, 0.5, desc and -9 or 0),
		Size = UDim2.new(1, -x - 64, 0, 20),
	})
	if desc then
		label(r, {
			Text = desc, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd,
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, x, 0.5, 11),
			Size = UDim2.new(1, -x - 64, 0, 16),
		}, "Sub")
	end
	local sw = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(52, 30) }, r)
	corner(sw, 15)
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(24, 24),
		Position = UDim2.new(0, 3, 0.5, 0), BackgroundColor3 = rgb(255, 255, 255),
	}, sw)
	corner(knob, 12)

	local function render(instant)
		apply(sw, { BackgroundColor3 = state and Theme.Accent or Theme.Raised }, instant)
		local pos = UDim2.new(0, state and 25 or 3, 0.5, 0)
		if instant then
			knob.Position = pos
		else
			tween(knob, 0.2, { Position = pos }, Enum.EasingStyle.Quad)
		end
	end
	bind(sw, render)

	local obj = {}
	function obj:Set(v, silent)
		state = v == true
		render(false)
		if cfg.Flag then
			NovaUI.Flags[cfg.Flag] = state
		end
		if not silent then
			fire(cfg.Callback, state)
		end
	end
	function obj:Get()
		return state
	end
	r.MouseButton1Click:Connect(function()
		obj:Set(not state)
	end)
	self:_flag(cfg.Flag, obj, state)
	if state then
		task.defer(fire, cfg.Callback, state)
	end
	return obj
end

function Section:Button(cfg)
	local primary = cfg.Style == "Primary"
	local b = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 44), LayoutOrder = self:_next(), Text = cfg.Title or "Button",
		Font = BOLD, TextSize = 15, AutoButtonColor = false,
	}, self.Body)
	corner(b, 12)
	btnStyle(b, primary and "Accent" or "Card", primary and "AccentHover" or "Raised")
	paint(b, "TextColor3", primary and "OnAccent" or "Text")
	b.MouseButton1Click:Connect(function()
		fire(cfg.Callback)
	end)
	return { SetText = function(_, t) b.Text = t end }
end

function Section:Actions(items, cols)
	cols = cols or 2
	local c = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, LayoutOrder = self:_next() }, self.Body)
	new("UIGridLayout", {
		CellSize = UDim2.new(1 / cols, -(8 * (cols - 1)) / cols, 0, 58),
		CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder,
	}, c)
	local out = {}
	for idx, it in ipairs(items) do
		local state = it.Default == true
		local t = new("TextButton", { Text = "", AutoButtonColor = false, LayoutOrder = idx }, c)
		corner(t, 14)
		btnStyle(t, "Card", "Raised")
		stroke(t, 0.93)
		local x = 12
		if it.Icon then
			icon(t, it.Icon, 15, "Text", { Position = UDim2.new(0, 11, 0, 9) })
			x = 33
		end
		label(t, { Text = it.Title or "Action", Font = BOLD, TextSize = 13, Position = UDim2.new(0, x, 0, 8), Size = UDim2.new(1, -x - 6, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd })
		local d = label(t, { Text = it.Description or (it.Toggle and "Off" or ""), TextSize = 11, Position = UDim2.new(0, 12, 0, 32), Size = UDim2.new(1, -18, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd }, false)
		local function render(instant)
			apply(d, { TextColor3 = (it.Toggle and state) and Theme.Accent or Theme.Sub }, instant)
		end
		bind(d, render)
		local obj = {}
		function obj:Set(v, silent)
			state = v == true
			if it.Toggle then
				d.Text = state and "On" or "Off"
			end
			render(false)
			if it.Flag then
				NovaUI.Flags[it.Flag] = state
			end
			if not silent then
				fire(it.Callback, state)
			end
		end
		function obj:Get()
			return state
		end
		t.MouseButton1Click:Connect(function()
			if it.Toggle then
				obj:Set(not state)
			else
				fire(it.Callback)
			end
		end)
		if it.Toggle then
			self:_flag(it.Flag, obj, state)
			d.Text = state and "On" or "Off"
			render(true)
		end
		out[it.Title or idx] = obj
	end
	return out
end

function Section:Slider(cfg)
	local min, max, inc = cfg.Min or 0, cfg.Max or 100, cfg.Increment or 1
	local value = math.clamp(cfg.Default or min, min, max)
	local suffix = cfg.Suffix or ""
	local dec = tostring(inc):match("%.(%d+)")
	dec = dec and #dec or 0
	local fmt = "%." .. dec .. "f"
	local r = self:_row(56)
	label(r, { Text = cfg.Title or "Slider", Font = BOLD, TextSize = 15, Size = UDim2.new(1, -100, 0, 20) })
	local vl = label(r, { Font = BOLD, TextSize = 14, TextXAlignment = RIGHT, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 100, 0, 20) }, "Sub")
	local track = new("Frame", { Position = UDim2.new(0, 0, 0, 36), Size = UDim2.new(1, 0, 0, 8) }, r)
	corner(track, 4)
	paint(track, "BackgroundColor3", "Raised")
	local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0) }, track)
	corner(fill, 4)
	paint(fill, "BackgroundColor3", "Accent")
	local knob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(18, 18), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = rgb(255, 255, 255) }, track)
	corner(knob, 9)
	local hit = new("TextButton", { BackgroundTransparency = 1, Text = "", Position = UDim2.new(0, -8, 0, 26), Size = UDim2.new(1, 16, 0, 28) }, r)

	local function render()
		local a = (value - min) / math.max(max - min, 1e-9)
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, 0, 0.5, 0)
		vl.Text = fmt:format(value) .. suffix
	end
	local obj = {}
	function obj:Set(v, silent)
		v = min + math.floor((v - min) / inc + 0.5) * inc
		v = tonumber(fmt:format(math.clamp(v, min, max)))
		if v == value and not silent then
			return
		end
		value = v
		render()
		if cfg.Flag then
			NovaUI.Flags[cfg.Flag] = value
		end
		if not silent then
			fire(cfg.Callback, value)
		end
	end
	function obj:Get()
		return value
	end
	draggable(hit, self.Scroller, function(pos)
		local a = math.clamp((pos.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		obj:Set(min + a * (max - min))
	end)
	render()
	self:_flag(cfg.Flag, obj, value)
	return obj
end

function Section:Input(cfg)
	local box = new("TextBox", {
		Size = UDim2.new(1, 0, 0, 44), LayoutOrder = self:_next(), Text = cfg.Default or "",
		PlaceholderText = cfg.Placeholder or cfg.Title or "Type here", ClearTextOnFocus = false,
		Font = BOLD, TextSize = 14, TextXAlignment = CENTER,
	}, self.Body)
	corner(box, 12)
	paint(box, "BackgroundColor3", "Card")
	paint(box, "TextColor3", "Text")
	paint(box, "PlaceholderColor3", "Sub")
	stroke(box, 0.93)
	local obj = {}
	function obj:Set(v, silent)
		box.Text = tostring(v)
		if cfg.Flag then
			NovaUI.Flags[cfg.Flag] = box.Text
		end
		if not silent then
			fire(cfg.Callback, box.Text)
		end
	end
	function obj:Get()
		return box.Text
	end
	box.FocusLost:Connect(function(enter)
		if cfg.Numeric then
			local n = tonumber(box.Text)
			if not n then
				box.Text = ""
				return
			end
		end
		if enter or cfg.OnBlur ~= false then
			obj:Set(box.Text)
		end
	end)
	self:_flag(cfg.Flag, obj, box.Text)
	return obj
end

function Section:Dropdown(cfg)
	local multi = cfg.Multi == true
	local options = cfg.Options or {}
	local selected
	if multi then
		selected = {}
		for _, v in ipairs(cfg.Default or {}) do
			selected[v] = true
		end
	else
		selected = cfg.Default
	end
	local open = false
	local styles = {}

	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, LayoutOrder = self:_next() }, self.Body)
	list(holder, 6)
	local head = new("TextButton", { Size = UDim2.new(1, 0, 0, 44), Text = "", AutoButtonColor = false, LayoutOrder = 1 }, holder)
	corner(head, 12)
	btnStyle(head, "Card", "Raised")
	stroke(head, 0.93)
	label(head, { Text = cfg.Title or "Dropdown", Font = BOLD, TextSize = 14, Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(0.45, -14, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
	local vl = label(head, { TextSize = 13, TextXAlignment = RIGHT, Position = UDim2.new(0.45, 0, 0, 0), Size = UDim2.new(0.55, -34, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd }, "Sub")
	local chev = label(head, { Text = "›", Font = BOLD, TextSize = 22, TextXAlignment = CENTER, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(20, 24), Rotation = 90 }, "Sub")
	local box = new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 0), Visible = false, BackgroundTransparency = 1, ScrollBarThickness = 2,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = AY, LayoutOrder = 2, ClipsDescendants = true,
	}, holder)
	list(box, 4)

	local function display()
		if multi then
			local t = {}
			for _, o in ipairs(options) do
				if selected[o] then
					table.insert(t, tostring(o))
				end
			end
			return #t > 0 and table.concat(t, ", ") or "None"
		end
		return selected ~= nil and tostring(selected) or "None"
	end
	local function value()
		if multi then
			local t = {}
			for _, o in ipairs(options) do
				if selected[o] then
					table.insert(t, o)
				end
			end
			return t
		end
		return selected
	end
	local function restyle()
		for _, f in ipairs(styles) do
			f(false)
		end
		vl.Text = display()
	end
	local obj = {}
	local function commit(silent)
		if cfg.Flag then
			NovaUI.Flags[cfg.Flag] = value()
		end
		restyle()
		if not silent then
			fire(cfg.Callback, value())
		end
	end
	local function build()
		styles = {}
		for _, c in ipairs(box:GetChildren()) do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		box.Size = UDim2.new(1, 0, 0, math.min(#options * 40, 180))
		for i, o in ipairs(options) do
			local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 36), Text = "", AutoButtonColor = false, LayoutOrder = i }, box)
			corner(b, 10)
			local t = label(b, { Text = tostring(o), TextSize = 14, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -44, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd }, false)
			local ck = label(b, { Text = "✓", Font = BOLD, TextSize = 15, TextXAlignment = RIGHT, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.new(0, 20, 1, 0) }, false)
			local function style(instant)
				local on
				if multi then
					on = selected[o] == true
				else
					on = selected == o
				end
				apply(b, { BackgroundColor3 = on and Theme.Accent or Theme.Card, BackgroundTransparency = on and 0.65 or 0.3 }, instant)
				apply(t, { TextColor3 = on and Theme.Text or Theme.Sub }, instant)
				apply(ck, { TextColor3 = Theme.Text }, instant)
				ck.Visible = on
			end
			table.insert(styles, style)
			bind(b, style)
			b.MouseButton1Click:Connect(function()
				if multi then
					selected[o] = not selected[o] or nil
				else
					selected = o
					open = false
					box.Visible = false
					tween(chev, 0.2, { Rotation = 90 })
				end
				commit(false)
			end)
		end
	end
	function obj:Set(v, silent)
		if multi then
			selected = {}
			for _, k in ipairs(type(v) == "table" and v or {}) do
				selected[k] = true
			end
		else
			selected = v
		end
		commit(silent)
	end
	function obj:Get()
		return value()
	end
	function obj:Refresh(newOptions)
		options = newOptions or {}
		build()
		restyle()
	end
	head.MouseButton1Click:Connect(function()
		open = not open
		box.Visible = open
		tween(chev, 0.2, { Rotation = open and 270 or 90 })
	end)
	build()
	restyle()
	self:_flag(cfg.Flag, obj, value())
	return obj
end

function Section:Keybind(cfg)
	local key = cfg.Default
	local listening = false
	local r = self:_row(40)
	label(r, { Text = cfg.Title or "Keybind", Font = BOLD, TextSize = 15, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, -100, 0, 20) })
	local kb = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(90, 30), Text = "", AutoButtonColor = false }, r)
	corner(kb, 9)
	btnStyle(kb, "Card", "Raised")
	stroke(kb, 0.9)
	local txt = label(kb, { Font = BOLD, TextSize = 13, TextXAlignment = CENTER, Size = UDim2.fromScale(1, 1) })
	local function render()
		txt.Text = listening and "..." or (key and key.Name or "None")
	end
	local obj = {}
	function obj:Set(v, silent)
		if type(v) == "string" then
			local ok, e = pcall(function()
				return Enum.KeyCode[v]
			end)
			v = ok and e or nil
		end
		key = v
		listening = false
		render()
		if cfg.Flag then
			NovaUI.Flags[cfg.Flag] = key
		end
		if not silent then
			fire(cfg.OnChange, key)
		end
	end
	function obj:Get()
		return key
	end
	kb.MouseButton1Click:Connect(function()
		listening = true
		render()
	end)
	connect(UserInputService.InputBegan, function(i, gp)
		if listening then
			if i.UserInputType == Enum.UserInputType.Keyboard then
				if i.KeyCode == Enum.KeyCode.Escape or i.KeyCode == Enum.KeyCode.Backspace then
					obj:Set(nil)
				else
					obj:Set(i.KeyCode)
				end
			end
			return
		end
		if key and not gp and i.KeyCode == key then
			fire(cfg.Callback, key)
		end
	end)
	render()
	self:_flag(cfg.Flag, obj, key)
	return obj
end

function Section:ColorPicker(cfg)
	local h, s, v = (cfg.Default or Color3.new(1, 1, 1)):ToHSV()
	local open = false
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, LayoutOrder = self:_next() }, self.Body)
	list(holder, 8)
	local head = new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 1 }, holder)
	label(head, { Text = cfg.Title or "Color", Font = BOLD, TextSize = 15, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, -60, 0, 20) })
	local swatch = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(44, 26) }, head)
	corner(swatch, 8)
	stroke(swatch, 0.7)

	local panel = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 132), Visible = false, LayoutOrder = 2 }, holder)
	local sv = new("Frame", { Size = UDim2.new(1, 0, 0, 100) }, panel)
	corner(sv, 10)
	local white = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(255, 255, 255) }, sv)
	corner(white, 10)
	new("UIGradient", { Transparency = NumberSequence.new(0, 1) }, white)
	local black = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(0, 0, 0) }, sv)
	corner(black, 10)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }, black)
	local cur = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = rgb(255, 255, 255), ZIndex = 3 }, sv)
	corner(cur, 7)
	new("UIStroke", { Thickness = 2, Color = rgb(0, 0, 0), Transparency = 0.3 }, cur)

	local hue = new("Frame", { Position = UDim2.new(0, 0, 0, 112), Size = UDim2.new(1, 0, 0, 16), BackgroundColor3 = rgb(255, 255, 255) }, panel)
	corner(hue, 8)
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rgb(255, 0, 0)), ColorSequenceKeypoint.new(1 / 6, rgb(255, 255, 0)),
			ColorSequenceKeypoint.new(2 / 6, rgb(0, 255, 0)), ColorSequenceKeypoint.new(3 / 6, rgb(0, 255, 255)),
			ColorSequenceKeypoint.new(4 / 6, rgb(0, 0, 255)), ColorSequenceKeypoint.new(5 / 6, rgb(255, 0, 255)),
			ColorSequenceKeypoint.new(1, rgb(255, 0, 0)),
		}),
	}, hue)
	local hcur = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 22), BackgroundColor3 = rgb(255, 255, 255), ZIndex = 3 }, hue)
	corner(hcur, 3)
	new("UIStroke", { Thickness = 1.5, Color = rgb(0, 0, 0), Transparency = 0.3 }, hcur)

	local obj = {}
	local function render()
		local c = Color3.fromHSV(h, s, v)
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		swatch.BackgroundColor3 = c
		cur.Position = UDim2.fromScale(s, 1 - v)
		hcur.Position = UDim2.fromScale(h, 0.5)
		return c
	end
	local function changed(silent)
		local c = render()
		if cfg.Flag then
			NovaUI.Flags[cfg.Flag] = c
		end
		if not silent then
			fire(cfg.Callback, c)
		end
	end
	function obj:Set(c, silent)
		if typeof(c) == "Color3" then
			h, s, v = c:ToHSV()
			changed(silent)
		end
	end
	function obj:Get()
		return Color3.fromHSV(h, s, v)
	end
	draggable(sv, self.Scroller, function(pos)
		s = math.clamp((pos.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
		v = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
		changed(false)
	end)
	draggable(hue, self.Scroller, function(pos)
		h = math.clamp((pos.X - hue.AbsolutePosition.X) / math.max(hue.AbsoluteSize.X, 1), 0, 1)
		changed(false)
	end)
	head.MouseButton1Click:Connect(function()
		open = not open
		panel.Visible = open
	end)
	render()
	self:_flag(cfg.Flag, obj, Color3.fromHSV(h, s, v))
	return obj
end

function Section:Stats(items)
	local r = self:_row(54)
	local n = #items
	for i, it in ipairs(items) do
		local c = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1 / n, 0, 1, 0), Position = UDim2.new((i - 1) / n, 0, 0, 0) }, r)
		local val = label(c, { Text = "-", Font = BOLD, TextSize = 20, Size = UDim2.new(1, 0, 0, 26) })
		label(c, { Text = string.upper(it.Label or ""), Font = BOLD, TextSize = 11, Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(1, 0, 0, 16) }, "Sub")
		local function tick()
			val.Text = tostring(it.Get())
		end
		pcall(tick)
		table.insert(self.Window._tickers, tick)
	end
end

function Section:ServerInfo()
	self:Stats({
		{ Label = "Players", Get = function() return #Players:GetPlayers() .. "/" .. Players.MaxPlayers end },
		{ Label = "Ping", Get = function() return getPing() .. "ms" end },
		{ Label = "Uptime", Get = function() return formatTime(workspace.DistributedGameTime) end },
	})
end

function Section:GameCard()
	local win = self.Window
	local MarketplaceService = game:GetService("MarketplaceService")
	local r = self:_row(176)
	local card = new("Frame", { Size = UDim2.fromScale(1, 1) }, r)
	corner(card, 14)
	paint(card, "BackgroundColor3", "Card")
	stroke(card, 0.9)
	local img = new("ImageLabel", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(92, 92), ScaleType = Enum.ScaleType.Crop }, card)
	corner(img, 12)
	paint(img, "BackgroundColor3", "Raised")
	pcall(function()
		img.Image = "rbxthumb://type=GameIcon&id=" .. tostring(game.GameId) .. "&w=150&h=150"
	end)
	local nameL = label(card, { Text = "Loading...", Font = BOLD, TextSize = 15, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(112, 10), Size = UDim2.new(1, -122, 0, 38) })
	local byL = label(card, { Text = "Place " .. tostring(game.PlaceId), TextSize = 12, Position = UDim2.fromOffset(112, 50), Size = UDim2.new(1, -122, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd }, "Sub")
	local plL = label(card, { Text = "", Font = BOLD, TextSize = 13, Position = UDim2.fromOffset(112, 70), Size = UDim2.new(1, -122, 0, 16) }, "Accent")
	local pgL = label(card, { Text = "", TextSize = 12, Position = UDim2.fromOffset(112, 88), Size = UDim2.new(1, -122, 0, 16) }, "Sub")
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(game.PlaceId)
		end)
		if ok and info and card.Parent then
			nameL.Text = info.Name or "Unknown game"
			if info.Creator and info.Creator.Name then
				byL.Text = "by " .. info.Creator.Name
			end
		elseif card.Parent then
			nameL.Text = "Unknown game"
		end
	end)
	table.insert(win._tickers, function()
		plL.Text = #Players:GetPlayers() .. "/" .. Players.MaxPlayers .. " players online"
		pgL.Text = getPing() .. " ms   |   " .. formatTime(workspace.DistributedGameTime)
	end)
	local function mini(text, x, w, cb)
		local b = new("TextButton", { Position = UDim2.new(x, x == 0 and 10 or 4, 0, 114), Size = UDim2.new(w, -14, 0, 52), Text = text, Font = BOLD, TextSize = 14, AutoButtonColor = false }, card)
		corner(b, 12)
		btnStyle(b, "Raised", "Card")
		paint(b, "TextColor3", "Text")
		b.MouseButton1Click:Connect(function()
			fire(cb)
		end)
	end
	mini("Copy Job ID", 0, 0.5, function()
		if setclipboard then
			setclipboard(game.JobId)
		end
		win:Notify({ Title = "Copied", Content = "Job ID copied." })
	end)
	mini("Rejoin", 0.5, 0.5, function()
		pcall(function()
			if #Players:GetPlayers() <= 1 then
				LocalPlayer:Kick("\nRejoining...")
				task.wait()
				TeleportService:Teleport(game.PlaceId, LocalPlayer)
			else
				TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
			end
		end)
	end)
end

function Section:PlayerList(cfg)
	cfg = cfg or {}
	local selected = nil
	local height = cfg.Height or 300
	local frame = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height + 52), LayoutOrder = self:_next() }, self.Body)
	local search = new("TextBox", {
		Size = UDim2.new(1, 0, 0, 44), Text = "", PlaceholderText = "Search players", ClearTextOnFocus = false,
		Font = MED, TextSize = 15, TextXAlignment = LEFT,
	}, frame)
	corner(search, 12)
	pad(search, 14, 0, 14, 0)
	paint(search, "BackgroundColor3", "Card")
	paint(search, "TextColor3", "Text")
	paint(search, "PlaceholderColor3", "Sub")
	stroke(search, 0.93)
	local scroll = new("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0, 52), Size = UDim2.new(1, 0, 1, -52), BackgroundTransparency = 1,
		ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = AY, ClipsDescendants = true,
	}, frame)
	list(scroll, 8)

	local obj = {}
	local styles = {}
	local function restyle()
		for _, f in ipairs(styles) do
			f(false)
		end
	end
	local function rebuild()
		styles = {}
		for _, c in ipairs(scroll:GetChildren()) do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		local q = string.lower(search.Text)
		local plist = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if (cfg.IncludeSelf or p ~= LocalPlayer)
				and (q == "" or string.find(string.lower(p.Name), q, 1, true) or string.find(string.lower(p.DisplayName), q, 1, true)) then
				table.insert(plist, p)
			end
		end
		table.sort(plist, function(a, b)
			return string.lower(a.DisplayName) < string.lower(b.DisplayName)
		end)
		search.PlaceholderText = ("Search %d players"):format(#Players:GetPlayers() - (cfg.IncludeSelf and 0 or 1))
		for i, p in ipairs(plist) do
			local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 60), Text = "", AutoButtonColor = false, LayoutOrder = i }, scroll)
			corner(b, 14)
			local img = new("ImageLabel", { Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, 10, 0.5, -22), BackgroundTransparency = 0 }, b)
			corner(img, 22)
			paint(img, "BackgroundColor3", "Raised")
			loadThumb(p.UserId, img)
			local n1 = label(b, { Text = p.DisplayName, Font = BOLD, TextSize = 15, Position = UDim2.new(0, 64, 0, 10), Size = UDim2.new(1, -100, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd }, false)
			local n2 = label(b, { Text = "@" .. p.Name, TextSize = 12, Position = UDim2.new(0, 64, 0, 31), Size = UDim2.new(1, -100, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd }, false)
			local ch = label(b, { Text = "›", Font = BOLD, TextSize = 22, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(16, 24), TextXAlignment = CENTER }, false)
			local function style(instant)
				local on = selected == p
				apply(b, { BackgroundColor3 = on and Theme.Accent or Theme.Card, BackgroundTransparency = on and 0.15 or 0.2 }, instant)
				apply(n1, { TextColor3 = on and Theme.OnAccent or Theme.Text }, instant)
				apply(n2, { TextColor3 = on and Theme.OnAccent or Theme.Sub }, instant)
				apply(ch, { TextColor3 = on and Theme.OnAccent or Theme.Sub }, instant)
			end
			table.insert(styles, style)
			bind(b, style)
			b.MouseButton1Click:Connect(function()
				selected = p
				restyle()
				fire(cfg.Callback, p)
			end)
		end
	end
	function obj:Get()
		return selected
	end
	function obj:Refresh()
		rebuild()
	end
	search:GetPropertyChangedSignal("Text"):Connect(rebuild)
	connect(Players.PlayerAdded, function()
		task.defer(rebuild)
	end)
	connect(Players.PlayerRemoving, function(p)
		if selected == p then
			selected = nil
			fire(cfg.Callback, nil)
		end
		task.defer(rebuild)
	end)
	rebuild()
	return obj
end

function Section:PlayerInfo(cfg)
	cfg = cfg or {}
	local range = cfg.Range or 60
	local player = nil
	local f = self:_row(104)
	local img = new("ImageLabel", { Size = UDim2.fromOffset(100, 100) }, f)
	corner(img, 14)
	paint(img, "BackgroundColor3", "Raised")
	local name = label(f, { Text = "No player selected", Font = BOLD, TextSize = 18, Position = UDim2.new(0, 116, 0, 4), Size = UDim2.new(1, -116, 0, 24), TextTruncate = Enum.TextTruncate.AtEnd })
	local user = label(f, { Text = "Pick someone from the list", TextSize = 12, Position = UDim2.new(0, 116, 0, 30), Size = UDim2.new(1, -116, 0, 16) }, "Sub")
	local age = label(f, { Text = "", TextSize = 12, Position = UDim2.new(0, 116, 0, 54), Size = UDim2.new(1, -116, 0, 16) }, "Sub")
	local rng = label(f, { Text = "", Font = BOLD, TextSize = 13, Position = UDim2.new(0, 116, 0, 74), Size = UDim2.new(1, -116, 0, 18) }, false)
	rng.TextColor3 = Theme.Accent

	local function tick()
		if not player or not player.Parent then
			return
		end
		local a = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		local b = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if a and b and (a.Position - b.Position).Magnitude <= range then
			rng.Text = "In range"
			rng.TextColor3 = rgb(70, 220, 130)
		else
			rng.Text = "Not in range"
			rng.TextColor3 = Theme.Accent
		end
	end
	table.insert(self.Window._tickers, tick)

	local obj = {}
	function obj:Set(p)
		player = p
		if p then
			name.Text = p.DisplayName
			user.Text = "@" .. p.Name
			age.Text = ("Account age: %dy %dd"):format(math.floor(p.AccountAge / 365), p.AccountAge % 365)
			img.Image = ""
			loadThumb(p.UserId, img)
			tick()
		else
			name.Text = "No player selected"
			user.Text = "Pick someone from the list"
			age.Text, rng.Text, img.Image = "", "", ""
		end
	end
	function obj:Get()
		return player
	end
	return obj
end

function Section:ThemePicker()
	local win = self.Window
	local c = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, LayoutOrder = self:_next() }, self.Body)
	new("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 118), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, c)
	local checks = {}
	for i, name in ipairs(THEME_ORDER) do
		local th = THEMES[name]
		local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = th.Card, LayoutOrder = i }, c)
		corner(b, 14)
		local st = new("UIStroke", { Color = th.Accent, Thickness = 1, Transparency = 0.85, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
		local bar = new("Frame", { Position = UDim2.fromOffset(12, 14), Size = UDim2.fromOffset(54, 8), BackgroundColor3 = th.Text, BackgroundTransparency = 0.15 }, b)
		corner(bar, 4)
		local pill = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(30, 14), BackgroundColor3 = th.Accent }, b)
		corner(pill, 7)
		local big = new("Frame", { Position = UDim2.fromOffset(12, 32), Size = UDim2.fromOffset(70, 16), BackgroundColor3 = th.Accent }, b)
		corner(big, 8)
		local tr = new("Frame", { Position = UDim2.new(0, 12, 0, 58), Size = UDim2.new(1, -24, 0, 8), BackgroundColor3 = th.Raised }, b)
		corner(tr, 4)
		local fl = new("Frame", { Size = UDim2.new(0.4, 0, 1, 0), BackgroundColor3 = th.Accent }, tr)
		corner(fl, 4)
		label(b, { Text = name, Font = BOLD, TextSize = 14, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -10), Size = UDim2.new(1, -44, 0, 18) }, false).TextColor3 = th.Text
		local ck = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -10), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = th.Accent, Visible = false }, b)
		corner(ck, 11)
		label(ck, { Text = "✓", Font = BOLD, TextSize = 13, TextXAlignment = CENTER, Size = UDim2.fromScale(1, 1) }, false).TextColor3 = th.OnAccent
		checks[name] = { ck = ck, st = st }
		b.MouseButton1Click:Connect(function()
			win:SetTheme(name)
			vibrate()
		end)
	end
	local function render()
		for name, o in pairs(checks) do
			local on = State.Theme == name
			o.ck.Visible = on
			o.st.Thickness = on and 2 or 1
			o.st.Transparency = on and 0 or 0.85
		end
	end
	table.insert(win._themeListeners, render)
	win._setters.Theme = function(v)
		win:SetTheme(v)
	end
	NovaUI.Flags.Theme = State.Theme
	render()
end

------------------------------------------------------------------------
-- Tab
------------------------------------------------------------------------
function Tab:Section(cfg)
	cfg = cfg or {}
	local side = (cfg.Side == "Right") and self.Right or self.Left
	self._n = self._n + 1
	local card = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, LayoutOrder = self._n }, side)
	corner(card, 18)
	panelPaint(card)
	stroke(card, 0.9)
	pad(card, 14, 12, 14, 14)
	list(card, 8)
	local s = setmetatable({ Window = self.Window, Tab = self, Body = card, Scroller = side, _order = 0 }, Section)
	if cfg.Title then
		local head = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 0 }, card)
		local x = 0
		if cfg.Icon then
			icon(head, cfg.Icon, 17, "Sub", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0) })
			x = 28
		end
		label(head, { Text = cfg.Title, Font = BOLD, TextSize = 16, Position = UDim2.new(0, x, 0, 0), Size = UDim2.new(1, -x, 1, 0) })
	end
	return s
end

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------
function Window:SetTheme(name)
	if not THEMES[name] then
		return
	end
	State.Theme = name
	Theme = THEMES[name]
	NovaUI.Flags.Theme = name
	refresh(false)
	for _, f in ipairs(self._themeListeners) do
		f()
	end
end

function Window:SetPanelAlpha(a)
	State.PanelAlpha = math.clamp(a, 0, 0.9)
	refresh(false)
end

NovaUI.Animations = true
function Window:SetVisible(v, instant)
	local main, sc = self._main, self._mainScale
	self.Visible = v
	self._animSeq = (self._animSeq or 0) + 1
	local seq = self._animSeq
	if self._onVis then
		pcall(self._onVis, v, instant)
	end
	if instant or not NovaUI.Animations or not self._orb or not sc then
		main.AnchorPoint, main.Position = Vector2.new(0, 0), UDim2.new()
		if sc then
			sc.Scale = 1
		end
		main.Visible = v
		return
	end
	local orb, root = self._orb, self._root
	if root.AbsoluteSize.X > 0 then
		local c = orb.AbsolutePosition + orb.AbsoluteSize / 2
		local fx = (c.X - root.AbsolutePosition.X) / root.AbsoluteSize.X
		local fy = (c.Y - root.AbsolutePosition.Y) / root.AbsoluteSize.Y
		main.AnchorPoint = Vector2.new(fx, fy)
		main.Position = UDim2.fromScale(fx, fy)
	end
	if v then
		sc.Scale = 0.01
		main.Visible = true
		tween(sc, 0.75, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		task.delay(0.8, function()
			if self._animSeq == seq then
				main.AnchorPoint, main.Position = Vector2.new(0, 0), UDim2.new()
			end
		end)
	else
		tween(sc, 0.6, { Scale = 0.01 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.delay(0.62, function()
			if self._animSeq == seq then
				main.Visible = false
			end
		end)
	end
	if self._orbFx then
		pcall(self._orbFx, v)
	end
end

function Window:Toggle()
	if NovaUI.HoldOpen then
		return
	end
	self:SetVisible(not self.Visible)
end

function Window:Reveal()
	NovaUI.HoldOpen = false
	if self._orb then
		self._orb.Visible = true
	end
	self:SetVisible(true)
end

function Window:Notify(cfg)
	cfg = cfg or {}
	local dur = cfg.Duration or 4
	table.insert(self._log, { Title = cfg.Title, Content = cfg.Content })
	if #self._log > 20 then
		table.remove(self._log, 1)
	end
	if not cfg._replay then
		self._unread = self._unread + 1
		self._badge.Visible = true
		self._badgeText.Text = self._unread > 9 and "9+" or tostring(self._unread)
	end
	self._toastId = self._toastId + 1
	local wrap = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, LayoutOrder = self._toastId }, self._toasts)
	local toast = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, Position = UDim2.new(1, 60, 0, 0) }, wrap)
	corner(toast, 16)
	panelPaint(toast)
	toast.BackgroundTransparency = 0.05
	stroke(toast, 0.85)
	pad(toast, 16, 12, 14, 12)
	list(toast, 3)
	label(toast, { Text = cfg.Title or "Notification", Font = BOLD, TextSize = 15, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1 })
	if cfg.Content then
		label(toast, { Text = cfg.Content, TextSize = 13, TextWrapped = true, AutomaticSize = AY, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2 }, "Sub")
	end
	local bar = new("Frame", { Size = UDim2.new(1, 0, 0, 3), LayoutOrder = 3 }, toast)
	corner(bar, 2)
	paint(bar, "BackgroundColor3", "Accent")
	NovaUI.Sound("ping", 0.3)
	tween(toast, 0.35, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Quint)
	tween(bar, dur, { Size = UDim2.new(0, 0, 0, 3) }, Enum.EasingStyle.Linear)
	task.delay(dur, function()
		if toast.Parent then
			tween(toast, 0.3, { Position = UDim2.new(1, 60, 0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			task.wait(0.35)
			wrap:Destroy()
		end
	end)
end

function Window:AddStepper(cfg)
	local min, max, step = cfg.Min or 0, cfg.Max or 100, cfg.Step or 1
	local value = math.clamp(cfg.Default or min, min, max)
	local dec = tostring(step):match("%.(%d+)")
	dec = dec and #dec or 0
	local fmt = "%." .. dec .. "f"
	local f = new("Frame", { Size = UDim2.fromOffset(176, 58), LayoutOrder = #self._steppers:GetChildren() }, self._steppers)
	corner(f, 29)
	panelPaint(f)
	stroke(f, 0.88)
	local obj = { Touched = false }
	local vl
	local function set(v, silent)
		v = tonumber(fmt:format(math.clamp(v, min, max)))
		value = v
		vl.Text = fmt:format(v)
		if not silent then
			obj.Touched = true
			fire(cfg.Callback, v)
		end
	end
	local function holdBtn(text, x, delta)
		local b = new("TextButton", {
			BackgroundTransparency = 1, Text = text, Font = BOLD, TextSize = 24, AutoButtonColor = false,
			Position = UDim2.new(x, 0, 0, 0), Size = UDim2.new(0, 48, 1, 0), AnchorPoint = Vector2.new(x, 0),
		}, f)
		paint(b, "TextColor3", "Text")
		local token = 0
		b.InputBegan:Connect(function(i)
			if isPress(i) then
				token = token + 1
				vibrate()
				local my = token
				set(value + delta)
				task.delay(0.4, function()
					while token == my and b.Parent do
						set(value + delta)
						task.wait(0.06)
					end
				end)
				local c
				c = i:GetPropertyChangedSignal("UserInputState"):Connect(function()
					if i.UserInputState == Enum.UserInputState.End then
						token = token + 1
						c:Disconnect()
					end
				end)
			end
		end)
	end
	holdBtn("–", 0, -step)
	holdBtn("+", 1, step)
	label(f, { Text = string.upper(cfg.Name or "VALUE"), Font = BOLD, TextSize = 10, TextXAlignment = CENTER, Position = UDim2.new(0.5, -40, 0, 9), Size = UDim2.fromOffset(80, 14) }, "Sub")
	vl = label(f, { Font = BOLD, TextSize = 19, TextXAlignment = CENTER, Position = UDim2.new(0.5, -40, 0, 24), Size = UDim2.fromOffset(80, 24) })
	vl.Text = fmt:format(value)
	function obj:Set(v, silent)
		set(v, silent)
	end
	function obj:Get()
		return value
	end
	return obj
end

function Window:CreateTab(cfg)
	cfg = cfg or {}
	local tab = setmetatable({ Window = self, Name = cfg.Name or "Tab", _n = 0, _active = false }, Tab)
	local btn = new("TextButton", { Size = UDim2.new(0, 0, 0, 44), AutomaticSize = AX, Text = "", AutoButtonColor = false, LayoutOrder = #self.Tabs + 1 }, self._dock)
	corner(btn, 22)
	list(btn, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	pad(btn, 13, 0, 13, 0)
	local ic = icon(btn, cfg.Icon or "star", 18, false)
	ic.LayoutOrder = 1
	local nm = label(btn, { Text = tab.Name, Font = BOLD, TextSize = 15, AutomaticSize = AX, Size = UDim2.new(0, 0, 1, 0), Visible = false, LayoutOrder = 2 }, "Text")
	local prop = ic:IsA("ImageLabel") and "ImageColor3" or "TextColor3"
	local function render(instant)
		local on = tab._active
		apply(btn, { BackgroundColor3 = on and Theme.Accent or Theme.Raised, BackgroundTransparency = on and 0.3 or 0.55 }, instant)
		apply(ic, { [prop] = on and Theme.Text or Theme.Sub }, instant)
		nm.Visible = on
	end
	bind(btn, render)
	tab._render = render

	tab.Page = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, self._main)
	local function column(anchorX, posX)
		local s = new("ScrollingFrame", {
			BackgroundTransparency = 1, ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = AY,
			ClipsDescendants = true, AnchorPoint = Vector2.new(anchorX, 0),
			Position = UDim2.new(anchorX, posX, 0, 150), Size = UDim2.new(0.27, 0, 1, -244),
		}, tab.Page)
		new("UISizeConstraint", { MinSize = Vector2.new(300, 0), MaxSize = Vector2.new(440, 99999) }, s)
		list(s, 12)
		pad(s, 0, 0, 0, 10)
		return s
	end
	tab.Left = column(0, 16)
	tab.Right = column(1, -16)
	btn.MouseButton1Click:Connect(function()
		vibrate()
		self:_select(tab)
	end)
	table.insert(self.Tabs, tab)
	if #self.Tabs == 1 then
		self:_select(tab, true)
	end
	return tab
end

function Window:SelectTab(name)
	for _, t in ipairs(self.Tabs) do
		if t.Name == name then
			self:_select(t)
			return
		end
	end
end

function Window:_select(tab, instant)
	for _, t in ipairs(self.Tabs) do
		local on = t == tab
		t._active = on
		t.Page.Visible = on
		t._render(instant == true)
	end
	if not instant then
		tab.Left.Position = UDim2.new(0, -30, 0, 150)
		tab.Right.Position = UDim2.new(1, 30, 0, 150)
		tween(tab.Left, 0.35, { Position = UDim2.new(0, 16, 0, 150) }, Enum.EasingStyle.Quint)
		tween(tab.Right, 0.35, { Position = UDim2.new(1, -16, 0, 150) }, Enum.EasingStyle.Quint)
	end
end

function Window:SaveConfig(name)
	if not writefile then
		return false, "writefile not supported"
	end
	pcall(makefolder, self.Folder)
	local data = {}
	for k, v in pairs(NovaUI.Flags) do
		data[k] = encode(v)
	end
	local ok, err = pcall(writefile, self.Folder .. "/" .. name .. ".json", HttpService:JSONEncode(data))
	return ok, err
end

function Window:LoadConfig(name)
	if not (readfile and isfile) then
		return false, "readfile not supported"
	end
	local path = self.Folder .. "/" .. name .. ".json"
	if not isfile(path) then
		return false, "config not found"
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(path))
	end)
	if not ok then
		return false, "bad config file"
	end
	for flag, raw in pairs(data) do
		local setter = self._setters[flag]
		if setter then
			pcall(setter, decode(raw))
		end
	end
	return true
end

function Window:AutoLoad()
	if isfile and readfile then
		local p = self.Folder .. "/autoload.txt"
		if isfile(p) then
			local n = readfile(p)
			if n and n ~= "" then
				return self:LoadConfig(n)
			end
		end
	end
end

function Window:Destroy()
	for _, c in ipairs(Conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	Conns = {}
	Binds = {}
	if self.Gui then
		self.Gui:Destroy()
	end
	GuiRoot = nil
	if NovaUI._window == self then
		NovaUI._window = nil
	end
end

function Window:CreateSettingsTab(cfg)
	cfg = cfg or {}
	local win = self
	local tab = self:CreateTab({ Name = "Settings", Icon = "settings" })

	local themes = tab:Section({ Title = "Themes", Icon = "palette", Side = "Left" })
	themes:ThemePicker()

	local ui = tab:Section({ Title = "Interface", Icon = "settings", Side = "Left" })
	ui:Slider({ Title = "Panel transparency", Min = 0, Max = 60, Default = math.floor(State.PanelAlpha * 100 + 0.5), Suffix = "%", Flag = "PanelAlpha", Callback = function(v) win:SetPanelAlpha(v / 100) end })
	ui:Keybind({ Title = "Toggle menu", Default = self.ToggleKey, Flag = "ToggleKey", OnChange = function(k) if k then win.ToggleKey = k end end })

	local cf = tab:Section({ Title = "Configs", Icon = "server", Side = "Left" })
	local cname = cf:Input({ Placeholder = "Config name", Default = "default" })
	cf:Actions({
		{ Title = "Save", Description = "Write config", Icon = "check", Callback = function()
			local ok, err = win:SaveConfig(cname:Get())
			win:Notify({ Title = ok and "Config saved" or "Save failed", Content = ok and cname:Get() or tostring(err) })
		end },
		{ Title = "Load", Description = "Apply config", Icon = "refresh", Callback = function()
			local ok, err = win:LoadConfig(cname:Get())
			win:Notify({ Title = ok and "Config loaded" or "Load failed", Content = ok and cname:Get() or tostring(err) })
		end },
	})
	cf:Toggle({ Title = "Auto-load this config", Description = "Runs on next execute", Callback = function(v)
		if writefile and v then
			pcall(makefolder, win.Folder)
			pcall(writefile, win.Folder .. "/autoload.txt", cname:Get())
		elseif writefile then
			pcall(writefile, win.Folder .. "/autoload.txt", "")
		end
	end })

	local launch = tab:Section({ Title = "Auto-launch", Icon = "bolt", Side = "Right" })
	launch:Toggle({ Title = "Auto relaunch", Description = "Re-run script after teleport", Flag = "AutoRelaunch", Callback = function(v)
		if v and queue_on_teleport and cfg.RelaunchScript then
			pcall(queue_on_teleport, cfg.RelaunchScript)
		end
	end })

	local util = tab:Section({ Title = "Utilities", Icon = "settings", Side = "Right" })
	local afkConn
	util:Toggle({ Title = "Anti-AFK", Description = "Stops the idle kick", Icon = "shield", Flag = "AntiAFK", Callback = function(v)
		if afkConn then
			afkConn:Disconnect()
			afkConn = nil
		end
		if v then
			local vu = game:GetService("VirtualUser")
			afkConn = LocalPlayer.Idled:Connect(function()
				pcall(function()
					vu:CaptureController()
					vu:ClickButton2(Vector2.new())
				end)
			end)
		end
	end })
	util:Toggle({ Title = "FPS counter", Description = "Shown in the top bar", Icon = "bolt", Default = true, Flag = "ShowFPS", Callback = function(v)
		if win._fpsItem then
			win._fpsItem.Visible = v
		end
	end })
	local rejoinConn
	util:Toggle({ Title = "Auto-rejoin", Description = "Rejoin after a kick or disconnect", Icon = "refresh", Flag = "AutoRejoin", Callback = function(v)
		if rejoinConn then
			rejoinConn:Disconnect()
			rejoinConn = nil
		end
		if v then
			pcall(function()
				local overlay = game:GetService("CoreGui"):WaitForChild("RobloxPromptGui", 5).promptOverlay
				rejoinConn = overlay.ChildAdded:Connect(function(c)
					if c.Name == "ErrorPrompt" then
						task.wait(2)
						TeleportService:Teleport(game.PlaceId, LocalPlayer)
					end
				end)
			end)
		end
	end })
	local saved
	util:Toggle({ Title = "Lower graphics", Description = "Less lag: no shadows or effects", Icon = "cube", Flag = "LowGfx", Callback = function(v)
		pcall(function()
			if v then
				saved = { q = settings().Rendering.QualityLevel, s = Lighting.GlobalShadows, fx = {} }
				settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
				Lighting.GlobalShadows = false
				for _, e in ipairs(Lighting:GetChildren()) do
					if e:IsA("PostEffect") or e:IsA("BloomEffect") or e:IsA("BlurEffect") or e:IsA("SunRaysEffect") or e:IsA("DepthOfFieldEffect") then
						table.insert(saved.fx, { e, e.Enabled })
						e.Enabled = false
					end
				end
			elseif saved then
				settings().Rendering.QualityLevel = saved.q
				Lighting.GlobalShadows = saved.s
				for _, p in ipairs(saved.fx) do
					p[1].Enabled = p[2]
				end
			end
		end)
	end })
	local oldVol
	util:Toggle({ Title = "Mute game audio", Description = "Silence the whole game", Icon = "eye", Flag = "MuteAudio", Callback = function(v)
		pcall(function()
			local gs = UserSettings():GetService("UserGameSettings")
			if v then
				oldVol = gs.MasterVolume
				gs.MasterVolume = 0
			else
				gs.MasterVolume = oldVol or 1
			end
		end)
	end })

	local srv = tab:Section({ Title = "This server", Icon = "server", Side = "Right" })
	srv:ServerInfo()
	srv:Actions({
		{ Title = "Rejoin", Description = "Same server", Icon = "refresh", Callback = function()
			pcall(function()
				if #Players:GetPlayers() <= 1 then
					LocalPlayer:Kick("\nRejoining...")
					task.wait()
					TeleportService:Teleport(game.PlaceId, LocalPlayer)
				else
					TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
				end
			end)
		end },
		{ Title = "Server hop", Description = "Find a new server", Icon = "server", Callback = function()
			win:Notify({ Title = "Server hop", Content = "Searching for a server..." })
			local ok, res = pcall(function()
				return HttpService:JSONDecode(game:HttpGet(("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)))
			end)
			if ok and res and res.data then
				for _, s in ipairs(res.data) do
					if s.id ~= game.JobId and s.playing and s.maxPlayers and s.playing < s.maxPlayers then
						TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
						return
					end
				end
			end
			win:Notify({ Title = "Server hop failed", Content = "No free server found." })
		end },
	})

	local game_ = tab:Section({ Title = "Game", Icon = "game", Side = "Right" })
	if cfg.Discord then
		game_:Button({ Title = "Join Discord", Style = "Primary", Callback = function()
			if setclipboard then
				setclipboard(cfg.Discord)
			end
			win:Notify({ Title = "Discord", Content = "Invite link copied to clipboard." })
		end })
	end
	game_:Label("Place " .. tostring(game.PlaceId))
	game_:Actions({
		{ Title = "Copy link", Icon = "game", Callback = function()
			if setclipboard then
				setclipboard(("roblox://placeId=%d&gameInstanceId=%s"):format(game.PlaceId, game.JobId))
			end
			win:Notify({ Title = "Copied", Content = "Join link copied." })
		end },
		{ Title = "Job ID", Icon = "server", Callback = function()
			if setclipboard then
				setclipboard(game.JobId)
			end
			win:Notify({ Title = "Copied", Content = "Job ID copied." })
		end },
	})
	return tab
end

------------------------------------------------------------------------
-- CreateWindow
------------------------------------------------------------------------
function NovaUI:CreateWindow(cfg)
	cfg = cfg or {}
	if NovaUI._window then
		NovaUI._window:Destroy()
	end
	Binds = {}
	if cfg.Theme and THEMES[cfg.Theme] then
		State.Theme = cfg.Theme
		Theme = THEMES[cfg.Theme]
	end
	NovaUI.Flags = {}
	NovaUI.Flags.Theme = State.Theme

	local win = setmetatable({
		Tabs = {}, Name = cfg.Name or "NOVA", Folder = cfg.Folder or "NovaUI",
		ToggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift, Visible = true,
		_setters = {}, _tickers = {}, _themeListeners = {}, _log = {}, _unread = 0, _toastId = 0,
	}, Window)
	NovaUI._window = win

	local gui = new("ScreenGui", { Name = "NovaUI_" .. HttpService:GenerateGUID(false):sub(1, 6), ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999 })
	if syn and syn.protect_gui then
		pcall(syn.protect_gui, gui)
	end
	local parent
	local okHui, hui = pcall(function()
		return gethui and gethui()
	end)
	if okHui and hui then
		parent = hui
	else
		local okCore = pcall(function()
			gui.Parent = game:GetService("CoreGui")
		end)
		if okCore and gui.Parent then
			parent = game:GetService("CoreGui")
		else
			parent = LocalPlayer:WaitForChild("PlayerGui")
		end
	end
	gui.Parent = parent
	GuiRoot = gui
	win.Gui = gui

	local root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
	local uiScale = new("UIScale", {}, root)
	local function relayout()
		local sz = gui.AbsoluteSize
		local s
		if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
			s = math.clamp(sz.Y / 660, 0.5, 1.6)
		else
			s = math.clamp(sz.Y / 820, 0.75, 1.2)
		end
		uiScale.Scale = s
		root.Size = UDim2.fromOffset(sz.X / s, sz.Y / s)
	end
	relayout()
	connect(gui:GetPropertyChangedSignal("AbsoluteSize"), relayout)

	local main = new("Frame", { Name = "Main", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, root)
	win._main = main
	win._root = root
	win._mainScale = new("UIScale", {}, main)
	-- ===== ambient blackholes in the corners / sides (decoration only: never takes touch input) =====
	-- lives in its own full-screen ScreenGui so the holes sit in the REAL screen corners (not the notch-safe area)
	pcall(function()
		local old = parent:FindFirstChild("NovaAmbient")
		if old then old:Destroy() end
	end)
	local ambGui = new("ScreenGui", { Name = "NovaAmbient", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 998, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, parent)
	pcall(function()
		ambGui.ScreenInsets = Enum.ScreenInsets.None
	end)
	local ambient = new("Frame", { Name = "Ambient", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 0, Active = false }, ambGui)
	win._ambient, win._ambGui = ambient, ambGui
	do
		local spots = {
			{ 0, 0, 260, 0.5 }, { 1, 0, 260, 0.5 }, { 0, 1, 260, 0.5 }, { 1, 1, 260, 0.5 },
			{ 0, 0.5, 120, 0.5 }, { 1, 0.5, 120, 0.5 },
		}
		for _, sp in ipairs(spots) do
			local h = NovaUI.MakeBlackhole(ambient, sp[3], { Position = UDim2.fromScale(sp[1], sp[2]), ParticleCount = 6, ZIndex = 0, Bind = true })
			h.Active = false
		end
		-- energy lines running along the screen edges
		local function line(pos, size, rot)
			local f = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Position = pos, Size = size, ZIndex = 0, BackgroundTransparency = 0.35, Active = false }, ambient)
			local g = new("UIGradient", { Rotation = rot, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }), Color = ColorSequence.new(Theme.Accent, Color3.fromRGB(235, 215, 255)) }, f)
			task.spawn(function()
				local t = math.random() * 3
				while f.Parent do
					t = t + 0.03
					g.Offset = rot == 0 and Vector2.new((t * 0.35) % 2 - 1, 0) or Vector2.new(0, (t * 0.35) % 2 - 1)
					task.wait(0.03)
				end
			end)
		end
		line(UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 2), 0)
		line(UDim2.new(0, 0, 1, -2), UDim2.new(1, 0, 0, 2), 0)
		line(UDim2.new(0, 0, 0, 0), UDim2.new(0, 2, 1, 0), 90)
		line(UDim2.new(1, -2, 0, 0), UDim2.new(0, 2, 1, 0), 90)
	end


	local function pill(w, h, anchorX, posX, posY)
		local f = new("Frame", { AnchorPoint = Vector2.new(anchorX, 0), Position = UDim2.new(anchorX, posX, 0, posY), Size = UDim2.fromOffset(w, h) }, main)
		corner(f, h / 2)
		panelPaint(f)
		stroke(f, 0.88)
		return f
	end

	local prof = pill(310, 56, 0, 16, 12)
	local av = new("ImageLabel", { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(40, 40) }, prof)
	corner(av, 20)
	paint(av, "BackgroundColor3", "Raised")
	loadThumb(LocalPlayer.UserId, av)
	label(prof, { Text = "Welcome back, " .. LocalPlayer.DisplayName, Font = BOLD, TextSize = 14, Position = UDim2.fromOffset(58, 9), Size = UDim2.new(1, -66, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
	local hour = tonumber(os.date("%H"))
	local greet = hour < 12 and "Morning light, make it a good one" or (hour < 18 and "Good afternoon, stay sharp" or "Good evening, enjoy the session")
	label(prof, { Text = cfg.Subtitle or greet, TextSize = 12, Position = UDim2.fromOffset(58, 28), Size = UDim2.new(1, -66, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd }, "Sub")

	local chat = pill(56, 56, 0, 336, 12)
	local chatBtn = new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1) }, chat)
	icon(chatBtn, "chat", 22, "Text", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	local badge = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 6), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = rgb(255, 92, 110), Visible = false, ZIndex = 5 }, chat)
	corner(badge, 11)
	win._badge = badge
	win._badgeText = label(badge, { Font = BOLD, TextSize = 11, TextXAlignment = CENTER, Size = UDim2.fromScale(1, 1), ZIndex = 6 }, false)
	win._badgeText.TextColor3 = rgb(255, 255, 255)
	chatBtn.MouseButton1Click:Connect(function()
		vibrate()
		win._unread = 0
		badge.Visible = false
		local start = math.max(1, #win._log - 2)
		local copy = {}
		for i = start, #win._log do
			table.insert(copy, win._log[i])
		end
		for _, n in ipairs(copy) do
			win:Notify({ Title = n.Title, Content = n.Content, Duration = 3, _replay = true })
		end
		fire(cfg.OnChat)
	end)

	local grid = pill(56, 56, 0, 400, 12)
	local gridBtn = new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1) }, grid)
	icon(gridBtn, "grid", 22, "Text", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	gridBtn.MouseButton1Click:Connect(function()
		vibrate()
		win:Toggle()
	end)

	local stats = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(0, 56), AutomaticSize = AX }, main)
	corner(stats, 28)
	panelPaint(stats)
	stroke(stats, 0.88)
	list(stats, 20, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	pad(stats, 22, 0, 22, 0)
	local function statItem(ic, order)
		local it = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = AX, LayoutOrder = order }, stats)
		list(it, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
		icon(it, ic, 15, "Accent")
		local t = label(it, { Font = BOLD, TextSize = 15, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = AX, LayoutOrder = 2 })
		return it, t
	end
	local _, plT = statItem("users", 1)
	local _, pgT = statItem("wifi", 2)
	local fpsItem, fpsT = statItem("bolt", 3)
	win._fpsItem = fpsItem
	local frames, last = 0, os.clock()
	connect(RunService.Heartbeat, function()
		frames = frames + 1
		local n = os.clock()
		if n - last >= 0.5 then
			fpsT.Text = tostring(math.floor(frames / (n - last) + 0.5))
			frames, last = 0, n
		end
	end)
	table.insert(win._tickers, function()
		plT.Text = #Players:GetPlayers() .. "/" .. Players.MaxPlayers
		pgT.Text = getPing() .. "ms"
	end)
	plT.Text, pgT.Text, fpsT.Text = "-/-", "0ms", "60"

	local clock = pill(128, 56, 1, -16, 12)
	icon(clock, "sun", 20, "Accent", { Position = UDim2.fromOffset(14, 16) })
	local timeL = label(clock, { Font = BOLD, TextSize = 17, Position = UDim2.fromOffset(46, 8), Size = UDim2.new(1, -52, 0, 22) })
	local dateL = label(clock, { TextSize = 12, Position = UDim2.fromOffset(46, 29), Size = UDim2.new(1, -52, 0, 16) }, "Sub")
	table.insert(win._tickers, function()
		timeL.Text = os.date("%H:%M")
		dateL.Text = os.date("%a %d")
	end)
	timeL.Text, dateL.Text = os.date("%H:%M"), os.date("%a %d")

	local exec = pill(158, 56, 1, -154, 12)
	local dot = new("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(36, 36) }, exec)
	corner(dot, 18)
	paint(dot, "BackgroundColor3", "Accent")
	icon(dot, "settings", 18, "OnAccent", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	local exName = "Unknown"
	pcall(function()
		exName = identifyexecutor and (identifyexecutor()) or "Unknown"
	end)
	label(exec, { Text = tostring(exName), Font = BOLD, TextSize = 14, Position = UDim2.fromOffset(54, 9), Size = UDim2.new(1, -60, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
	label(exec, { Text = "Executor", TextSize = 12, Position = UDim2.fromOffset(54, 28), Size = UDim2.new(1, -60, 0, 16) }, "Sub")

	local st = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 80), Size = UDim2.fromOffset(0, 58), AutomaticSize = AX, BackgroundTransparency = 1 }, main)
	list(st, 10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center)
	win._steppers = st

	local dock = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(0, 60), AutomaticSize = AX }, main)
	corner(dock, 30)
	panelPaint(dock)
	stroke(dock, 0.88)
	list(dock, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	pad(dock, 8, 0, 8, 0)
	win._dock = dock

	local toasts = new("Frame", { Name = "Toasts", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 80), Size = UDim2.fromOffset(300, 0), AutomaticSize = AY, ZIndex = 50 }, root)
	list(toasts, 8, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Right)
	win._toasts = toasts

	-- ========== YADSAN ORB: whitehole while the hub is open, blackhole while it is minimised ==========
	local orb = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 222), Size = UDim2.fromOffset(150, 150),
		Text = "", AutoButtonColor = false, ZIndex = 60, BackgroundTransparency = 1,
	}, root)
	local bhHolder, bhApi = NovaUI.MakeBlackhole(orb, 118, { Bind = true, ZIndex = 1, White = true })
	win._orb, win._bh = orb, bhApi
	local bhScale = new("UIScale", {}, bhHolder)
	local hovering = false
	orb.MouseEnter:Connect(function()
		hovering = true
		tween(bhScale, 0.25, { Scale = 1.1 }, Enum.EasingStyle.Back)
	end)
	orb.MouseLeave:Connect(function()
		hovering = false
		tween(bhScale, 0.25, { Scale = 1 })
	end)
	orb.InputBegan:Connect(function(i)
		if isPress(i) then
			tween(bhScale, 0.1, { Scale = 0.88 })
		end
	end)
	orb.InputEnded:Connect(function(i)
		if isPress(i) then
			tween(bhScale, 0.35, { Scale = hovering and 1.1 or 1 }, Enum.EasingStyle.Back)
		end
	end)

	-- pulse rings (go outward when white, inward when black)
	local pulses = {}
	for k = 1, 2 do
		local r = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(118, 118), ZIndex = 1 }, orb)
		corner(r, 200)
		local st = new("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1), Transparency = 1 }, r)
		pulses[k] = { f = r, s = st }
	end

	-- YADSAN lettering, one label per letter so it can shimmer
	local letters = {}
	local letterRow = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(76, 22), ZIndex = 10 }, orb)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 0) }, letterRow)
	local word = string.upper(cfg.OrbText or "yadsan")
	for i = 1, #word do
		letters[i] = new("TextLabel", {
			BackgroundTransparency = 1, Text = word:sub(i, i), Font = Enum.Font.GothamBlack, TextSize = 15, Size = UDim2.fromOffset(14, 22),
			TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.35, TextStrokeColor3 = Color3.new(0, 0, 0), ZIndex = 10, LayoutOrder = i,
		}, letterRow)
	end
	local lastWhite = nil
	connect(RunService.Heartbeat, function()
		if not orb.Parent or not orb.Visible then
			return
		end
		local t = os.clock()
		local white = bhApi.IsWhite()
		bhHolder.Position = UDim2.new(0.5, 0, 0.5, math.sin(t * 1.6) * 3)
		for i, l in ipairs(letters) do
			local w = 0.5 + 0.5 * math.sin(t * 2.2 - i * 0.8)
			if white then
				l.TextColor3 = Color3.fromRGB(8, 4, 20):Lerp(Theme.Accent, w * 0.55)
				l.TextStrokeColor3 = Color3.new(1, 1, 1)
				l.TextStrokeTransparency = 0.5
			else
				l.TextColor3 = Color3.fromRGB(235, 220, 255):Lerp(Theme.Accent, w * 0.5)
				l.TextStrokeColor3 = Color3.new(0, 0, 0)
				l.TextStrokeTransparency = 0.25
			end
			l.Position = UDim2.fromOffset(0, math.sin(t * 2.2 - i * 0.8) * 1.2)
		end
		for k, p in ipairs(pulses) do
			local ph = (t * 0.55 + k * 0.5) % 1
			local sz = white and (118 * (0.85 + ph * 0.7)) or (118 * (1.55 - ph * 0.7))
			p.f.Size = UDim2.fromOffset(sz, sz)
			p.s.Color = white and Color3.new(1, 1, 1) or Theme.Accent
			p.s.Transparency = 0.25 + 0.75 * (white and ph or (1 - ph))
		end
	end)

	-- background blur while the hub is open (blurs the game world, never the GUI)
	NovaUI.Blur = true
	local blur = Instance.new("BlurEffect")
	blur.Name = "YadsanBlur"
	blur.Size = 0
	blur.Enabled = true
	pcall(function()
		blur.Parent = game:GetService("Lighting")
	end)
	local function blurTo(on)
		tween(blur, on and 0.6 or 0.4, { Size = (on and NovaUI.Blur) and 20 or 0 }, Enum.EasingStyle.Quad)
	end
	win._blurTo = blurTo
	gui.AncestryChanged:Connect(function()
		if not gui.Parent then
			pcall(function() blur:Destroy() end)
			pcall(function() win._ambGui:Destroy() end)
		end
	end)
	win._onVis = function(v)
		bhApi.SetWhite(v)
		bhApi.Boost(1)
		blurTo(v)
		if win._ambGui then
			win._ambGui.Enabled = v
		end
	end
	-- particles that get sucked into / burst out of the orb
	win._orbFx = function(opening)
		NovaUI.Sound(opening and "burst" or "suck", 0.55, 3)
		local sc = uiScale.Scale
		local oc = (orb.AbsolutePosition + orb.AbsoluteSize / 2 - root.AbsolutePosition) / sc
		local rnd = Random.new()
		for _ = 1, 26 do
			local ang = rnd:NextNumber() * math.pi * 2
			local dist = rnd:NextNumber(140, 420)
			local far = oc + Vector2.new(math.cos(ang), math.sin(ang)) * dist
			local a, b = opening and oc or far, opening and far or oc
			local sz = rnd:NextInteger(3, 7)
			local d = new("Frame", {
				BackgroundColor3 = (rnd:NextNumber() > 0.5) and Color3.new(1, 1, 1) or Theme.Accent, BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(a.X, a.Y), Size = UDim2.fromOffset(sz, sz), ZIndex = 58,
				BackgroundTransparency = opening and 0 or 0.6,
			}, root)
			corner(d, 8)
			local dur = rnd:NextNumber(0.45, 0.75)
			tween(d, dur, { Position = UDim2.fromOffset(b.X, b.Y), BackgroundTransparency = opening and 1 or 0 }, Enum.EasingStyle.Quint, opening and Enum.EasingDirection.Out or Enum.EasingDirection.In)
			task.delay(dur + 0.05, function()
				d:Destroy()
			end)
		end
		local ring = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(oc.X, oc.Y), Size = UDim2.fromOffset(opening and 80 or 520, opening and 80 or 520), ZIndex = 57 }, root)
		corner(ring, 600)
		local rs = new("UIStroke", { Thickness = 3, Color = opening and Color3.new(1, 1, 1) or Theme.Accent, Transparency = opening and 0.1 or 0.9 }, ring)
		tween(ring, 0.65, { Size = UDim2.fromOffset(opening and 560 or 60, opening and 560 or 60) }, Enum.EasingStyle.Quint, opening and Enum.EasingDirection.Out or Enum.EasingDirection.In)
		tween(rs, 0.65, { Transparency = opening and 1 or 0.1 })
		task.delay(0.7, function()
			ring:Destroy()
		end)
	end
	if NovaUI.HoldOpen then
		orb.Visible = false
		main.Visible = false
		win.Visible = false
		if win._ambGui then
			win._ambGui.Enabled = false
		end
	end

	local dragging, moved, startIn, startPos = false, false, nil, nil
	orb.InputBegan:Connect(function(i)
		if isPress(i) then
			dragging, moved, startIn, startPos = true, false, i.Position, orb.Position
		end
	end)
	connect(UserInputService.InputChanged, function(i)
		if dragging and isMove(i) then
			local d = i.Position - startIn
			if d.Magnitude > 6 then
				moved = true
			end
			if moved then
				orb.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X / uiScale.Scale, startPos.Y.Scale, startPos.Y.Offset + d.Y / uiScale.Scale)
			end
		end
	end)
	connect(UserInputService.InputEnded, function(i)
		if dragging and isPress(i) then
			dragging = false
			if not moved then
				vibrate()
				win:Toggle()
			end
		end
	end)

	connect(UserInputService.InputBegan, function(i, gp)
		if not gp and win.ToggleKey and i.KeyCode == win.ToggleKey then
			win:Toggle()
		end
	end)

	task.spawn(function()
		while gui.Parent do
			for _, f in ipairs(win._tickers) do
				pcall(f)
			end
			task.wait(1)
		end
	end)

	if cfg.QuickControls ~= false then
		local hum = getHumanoid()
		local speed = win:AddStepper({ Name = "Speed", Min = 0, Max = 1000, Step = 2, Default = hum and hum.WalkSpeed or 16, Callback = function(v)
			local h = getHumanoid()
			if h then
				h.WalkSpeed = v
			end
		end })
		local usePower = hum == nil or hum.UseJumpPower
		local jump = win:AddStepper({ Name = "Jump", Min = 0, Max = 500, Step = usePower and 5 or 1, Default = hum and (usePower and hum.JumpPower or hum.JumpHeight) or 50, Callback = function(v)
			local h = getHumanoid()
			if h then
				if h.UseJumpPower then
					h.JumpPower = v
				else
					h.JumpHeight = v
				end
			end
		end })
		local cam = workspace.CurrentCamera
		local fov = win:AddStepper({ Name = "FOV", Min = 30, Max = 120, Step = 1, Default = cam and cam.FieldOfView or 70, Callback = function(v)
			if workspace.CurrentCamera then
				workspace.CurrentCamera.FieldOfView = v
			end
		end })
		win.Speed, win.Jump, win.FOV = speed, jump, fov
		connect(LocalPlayer.CharacterAdded, function(c)
			local h = c:WaitForChild("Humanoid", 10)
			task.wait(0.5)
			if h then
				if speed.Touched then
					h.WalkSpeed = speed:Get()
				end
				if jump.Touched then
					if h.UseJumpPower then
						h.JumpPower = jump:Get()
					else
						h.JumpHeight = jump:Get()
					end
				end
			end
		end)
	end

	return win
end

return NovaUI
end)()


--[[
    YADSAN HUB  -  FINAL VERSION (English only)
    Blackhole theme + intro, Bigger Blackhole orb, fixed Resizer, Touch Vibration.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local RS = game:GetService("ReplicatedStorage")
local lp = Players.LocalPlayer

-- ========== INTRO: two black holes merge into a white hole, YADSAN appears letter by letter, loading, white-hole release ==========
local introGui
NovaUI.HoldOpen = true
task.spawn(function()
	local TweenService = game:GetService("TweenService")
	local T0, skipped, revealed, sfx = nil, false, false, nil
	local function reveal()
		if revealed then return end
		revealed = true
		task.spawn(function()
			local waited = 0
			while not (NovaUI._window and NovaUI.HubReady) and waited < 25 do
				task.wait(0.1)
				waited = waited + 0.1
			end
			NovaUI.HoldOpen = false
			local w = NovaUI._window
			if w then
				pcall(function() w:Reveal() end)
			end
		end)
	end
	local okIntro, errIntro = pcall(function()
		local parent
		local okHui, hui = pcall(function() return gethui and gethui() end)
		if okHui and hui then
			parent = hui
		else
			local okCore = pcall(function() return game:GetService("CoreGui").Name end)
			parent = okCore and game:GetService("CoreGui") or lp:WaitForChild("PlayerGui")
		end
		local gui = Instance.new("ScreenGui")
		gui.Name = "YadsanIntro"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 1000000
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = parent
		introGui = gui
		task.delay(16, function()
			if gui.Parent then gui:Destroy() end
		end)

		local vp = gui.AbsoluteSize
		if vp.X < 10 then vp = Vector2.new(800, 600) end
		local k = math.clamp(vp.Y / 600, 0.6, 1.6)
		local ACC = Color3.fromRGB(150, 70, 255)
		local HOT = Color3.fromRGB(235, 215, 255)
		local rng = Random.new()

		local bg = Instance.new("TextButton")
		bg.Text, bg.AutoButtonColor, bg.BorderSizePixel = "", false, 0
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(1, 0, 4)
		bg.Parent = gui
		local stage = Instance.new("CanvasGroup")
		stage.BackgroundTransparency = 1
		stage.Size = UDim2.fromScale(1, 1)
		stage.ZIndex = 2
		stage.Parent = bg
		local shakeBox = Instance.new("Frame")
		shakeBox.BackgroundTransparency = 1
		shakeBox.Size = UDim2.fromScale(1, 1)
		shakeBox.Parent = stage
		local flash = Instance.new("Frame")
		flash.BackgroundColor3 = Color3.new(1, 1, 1)
		flash.BorderSizePixel = 0
		flash.Size = UDim2.fromScale(1, 1)
		flash.BackgroundTransparency = 1
		flash.ZIndex = 20
		flash.Parent = bg
		local vig = Instance.new("Frame")
		vig.BackgroundColor3 = ACC
		vig.BorderSizePixel = 0
		vig.Size = UDim2.fromScale(1, 1)
		vig.BackgroundTransparency = 1
		vig.ZIndex = 1
		vig.Parent = bg
		local vg = Instance.new("UIGradient")
		vg.Rotation = 90
		vg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 0.7) })
		vg.Parent = vig

		-- stars that get pulled toward the hole
		local stars, phase = {}, "pull"
		for i = 1, 80 do
			local s = Instance.new("Frame")
			s.BorderSizePixel = 0
			s.BackgroundColor3 = rng:NextNumber() > 0.65 and Color3.fromRGB(200, 170, 255) or Color3.new(1, 1, 1)
			s.AnchorPoint = Vector2.new(0.5, 0.5)
			s.ZIndex = 2
			s.Parent = shakeBox
			stars[i] = { f = s, a = rng:NextNumber() * math.pi * 2, r = rng:NextNumber(0.1, 1), v = rng:NextNumber(0.04, 0.12), s = rng:NextNumber(1, 3) }
		end
		local pull = 0
		local starConn = RunService.Heartbeat:Connect(function(dt)
			local cx, cy = vp.X / 2, vp.Y / 2
			local R = math.max(vp.X, vp.Y) * 0.62
			for _, st in ipairs(stars) do
				st.r = st.r - dt * st.v * (1 + pull * 4) * (0.4 + (1 - st.r) * 1.4)
				if st.r < 0.045 then
					st.r = rng:NextNumber(0.85, 1.05)
					st.a = rng:NextNumber() * math.pi * 2
				end
				st.a = st.a + dt * 0.25 * (1 - st.r) * (1 + pull)
				local x, y = cx + math.cos(st.a) * st.r * R, cy + math.sin(st.a) * st.r * R * 0.8
				st.f.Position = UDim2.fromOffset(x, y)
				local sz = math.max(1, st.s * (0.4 + st.r) * k)
				st.f.Size = UDim2.fromOffset(sz * (1 + pull * 1.5 * (1 - st.r)), sz)
				st.f.Rotation = math.deg(st.a)
				st.f.BackgroundTransparency = math.clamp(0.1 + st.r * 0.5, 0, 0.9)
			end
		end)

		local shakeMag = 0
		-- ===== two black holes =====
		local holeSize = 300 * k
		local hA, apiA = NovaUI.MakeBlackhole(shakeBox, holeSize, { Color = Color3.fromRGB(160, 80, 255), ZIndex = 5, ParticleCount = 14 })
		local hB, apiB = NovaUI.MakeBlackhole(shakeBox, holeSize, { Color = Color3.fromRGB(70, 180, 255), ZIndex = 5, ParticleCount = 14 })
		apiA.SetWhite(false, true)
		apiB.SetWhite(false, true)
		local sA, sB = Instance.new("UIScale"), Instance.new("UIScale")
		sA.Scale, sB.Scale = 0.001, 0.001
		sA.Parent, sB.Parent = hA, hB
		local function scaleTo(sc, v, t, style, dir)
			TweenService:Create(sc, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), { Scale = v }):Play()
		end
		local orbit = { on = false, t = 0 }
		local theta0 = rng:NextNumber() * math.pi * 2
		local orbitConn = RunService.Heartbeat:Connect(function()
			if not orbit.on or not T0 then return end
			local u = math.clamp((os.clock() - T0 - 0.45) / 3.1, 0, 1)
			local R = vp.X * 0.27 * (1 - u ^ 1.7)
			local th = theta0 + math.pi * 2 * (0.7 * u + 4.3 * u ^ 2.3)
			local x, y = math.cos(th) * R, math.sin(th) * R * 0.5
			hA.Position = UDim2.new(0.5, x, 0.5, y)
			hB.Position = UDim2.new(0.5, -x, 0.5, -y)
			local sc = 0.16 + 0.46 * u
			sA.Scale, sB.Scale = sc, sc
			pull = 0.15 + u * 1.9
			shakeMag = u * u * 7 * k
		end)

		-- ===== letters M O N K Z (dark fill + white outline so they read on the white hole and on black) =====
		local word = "YADSAN"
		local letters = {}
		local spacing, lsz = 76 * k, 92 * k
		for i = 1, #word do
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Text = word:sub(i, i)
			l.Font = Enum.Font.GothamBlack
			l.TextSize = lsz
			l.TextColor3 = Color3.fromRGB(22, 8, 52)
			l.TextTransparency = 1
			l.AnchorPoint = Vector2.new(0.5, 0.5)
			l.Position = UDim2.new(0.5, (i - 3) * spacing, 0.5, -26 * k)
			l.Size = UDim2.fromOffset(lsz, lsz)
			l.ZIndex = 12
			l.Parent = shakeBox
			local st = Instance.new("UIStroke")
			st.Thickness = 3.5
			st.Color = Color3.new(1, 1, 1)
			st.Transparency = 1
			st.Parent = l
			local sc = Instance.new("UIScale")
			sc.Scale = 0.2
			sc.Parent = l
			letters[i] = { l = l, st = st, sc = sc, x = (i - 3) * spacing }
		end
		local function showLetter(i)
			local L = letters[i]
			TweenService:Create(L.l, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, L.x, 0.5, 0), TextTransparency = 0 }):Play()
			TweenService:Create(L.st, TweenInfo.new(0.3), { Transparency = 0 }):Play()
			TweenService:Create(L.sc, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		local function allTogether()
			for _, L in ipairs(letters) do
				L.l.TextColor3 = Color3.new(1, 1, 1)
				L.st.Color = Color3.fromRGB(150, 80, 255)
				L.st.Thickness = 7
				L.sc.Scale = 1.3
				TweenService:Create(L.sc, TweenInfo.new(0.7, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 }):Play()
				TweenService:Create(L.l, TweenInfo.new(0.9), { TextColor3 = Color3.fromRGB(22, 8, 52) }):Play()
				TweenService:Create(L.st, TweenInfo.new(0.9), { Color = Color3.new(1, 1, 1), Thickness = 3.5 }):Play()
			end
		end
		-- gentle float once they are all there
		local floating = false
		local floatConn = RunService.Heartbeat:Connect(function()
			if not floating then return end
			local t = os.clock()
			for i, L in ipairs(letters) do
				L.l.Position = UDim2.new(0.5, L.x, 0.5, math.sin(t * 2 + i * 0.7) * 4 * k)
			end
		end)

		-- ===== loading UI =====
		local function uiLabel(txtc, size, font, y)
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Font = font
			l.Text = txtc
			l.TextSize = size * k
			l.TextColor3 = HOT
			l.TextTransparency = 1
			l.AnchorPoint = Vector2.new(0.5, 0.5)
			l.Position = UDim2.new(0.5, 0, 0.5, y * k)
			l.Size = UDim2.fromOffset(360 * k, size * 1.5 * k)
			l.ZIndex = 12
			l.Parent = shakeBox
			return l
		end
		local loadL = uiLabel("L O A D I N G", 17, Enum.Font.GothamBold, 218)
		local pctL = uiLabel("0%", 12, Enum.Font.Code, 262)
		local barBg = Instance.new("Frame")
		barBg.BackgroundColor3 = Color3.fromRGB(34, 20, 64)
		barBg.BorderSizePixel = 0
		barBg.AnchorPoint = Vector2.new(0.5, 0.5)
		barBg.Position = UDim2.new(0.5, 0, 0.5, 240 * k)
		barBg.Size = UDim2.fromOffset(280 * k, 5 * k)
		barBg.BackgroundTransparency = 1
		barBg.ZIndex = 12
		barBg.Parent = shakeBox
		Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)
		local barFill = Instance.new("Frame")
		barFill.BackgroundColor3 = Color3.new(1, 1, 1)
		barFill.BorderSizePixel = 0
		barFill.Size = UDim2.fromScale(0, 1)
		barFill.ZIndex = 13
		barFill.Parent = barBg
		Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)
		local barGrad = Instance.new("UIGradient")
		barGrad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 200, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 110, 255)) })
		barGrad.Parent = barFill

		-- shake driver
		local shakeConn = RunService.Heartbeat:Connect(function()
			if shakeMag > 0.05 then
				shakeBox.Position = UDim2.fromOffset(rng:NextNumber(-shakeMag, shakeMag), rng:NextNumber(-shakeMag, shakeMag))
			else
				shakeBox.Position = UDim2.new()
			end
		end)
		local function bump(mag, dur)
			task.spawn(function()
				local steps = math.max(1, math.floor(dur / 0.03))
				for i = 1, steps do
					if not gui.Parent then return end
					shakeMag = math.max(shakeMag, mag * (1 - i / steps))
					task.wait(0.03)
				end
			end)
		end
		local function alive() return gui.Parent ~= nil end
		local function at(tm)
			while gui.Parent and os.clock() - T0 < tm do RunService.Heartbeat:Wait() end
			return alive()
		end
		local function shock(delay, size, thick)
			task.delay(delay, function()
				if not gui.Parent then return end
				local r = Instance.new("Frame")
				r.BackgroundTransparency = 1
				r.AnchorPoint = Vector2.new(0.5, 0.5)
				r.Position = UDim2.fromScale(0.5, 0.5)
				r.Size = UDim2.fromOffset(40 * k, 40 * k)
				r.ZIndex = 14
				r.Parent = shakeBox
				Instance.new("UICorner", r).CornerRadius = UDim.new(1, 0)
				local s = Instance.new("UIStroke")
				s.Thickness = thick
				s.Color = Color3.new(1, 1, 1)
				s.Transparency = 0
				s.Parent = r
				TweenService:Create(r, TweenInfo.new(1.1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(size * k, size * k) }):Play()
				TweenService:Create(s, TweenInfo.new(1.1, Enum.EasingStyle.Quad), { Transparency = 1, Thickness = 0.5 }):Play()
				task.delay(1.2, function() r:Destroy() end)
			end)
		end
		local function sparks(n)
			for _ = 1, n do
				local ang = rng:NextNumber() * math.pi * 2
				local dist = rng:NextNumber(200, 700) * k
				local d = Instance.new("Frame")
				d.BorderSizePixel = 0
				d.BackgroundColor3 = rng:NextNumber() > 0.5 and Color3.new(1, 1, 1) or HOT
				d.AnchorPoint = Vector2.new(0.5, 0.5)
				d.Position = UDim2.fromScale(0.5, 0.5)
				local sz = rng:NextInteger(2, 6)
				d.Size = UDim2.fromOffset(sz * 2, sz)
				d.Rotation = math.deg(ang)
				d.ZIndex = 15
				d.Parent = shakeBox
				local dur = rng:NextNumber(0.5, 1.2)
				TweenService:Create(d, TweenInfo.new(dur, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, math.cos(ang) * dist, 0.5, math.sin(ang) * dist), BackgroundTransparency = 1 }):Play()
				task.delay(dur + 0.05, function() d:Destroy() end)
			end
		end

		local function cleanup(fade)
			for _, c in ipairs({ starConn, orbitConn, floatConn, shakeConn }) do pcall(function() c:Disconnect() end) end
			if gui.Parent then gui:Destroy() end
		end

		-- ===== play =====
		local sndA = NovaUI.Sound("intro_a", 0.9, 10, true)
		T0 = os.clock()
		TweenService:Create(vig, TweenInfo.new(3), { BackgroundTransparency = 0.88 }):Play()
		-- 0.0 - 3.6 : two holes open and spiral into each other
		if not at(0.1) then return end
		orbit.on = true
		pull = 0.15
		for _, hb in ipairs({ 0.5, 1.3, 2.0, 2.55, 2.95, 3.25 }) do
			task.delay(math.max(0, hb - (os.clock() - T0)), function()
				if not alive() or not orbit.on then return end
				apiA.Boost(0.9)
				apiB.Boost(0.9)
				vig.BackgroundTransparency = 0.72
				TweenService:Create(vig, TweenInfo.new(0.45), { BackgroundTransparency = 0.88 }):Play()
				bump(3, 0.28)
			end)
		end
		-- 3.6 : they merge into one white hole
		if not at(3.58) then return end
		orbit.on = false
		pull = 0.4
		shakeMag = 0
		hA.Position, hB.Position = UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		scaleTo(sB, 0.001, 0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		sA.Scale = 0.7
		scaleTo(sA, 1.25, 1.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		apiA.SetWhite(true, false)
		apiA.Boost(2)
		flash.BackgroundTransparency = 0.1
		TweenService:Create(flash, TweenInfo.new(1.0, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
		bump(18 * k, 0.6)
		shock(0, 1400, 6)
		shock(0.14, 1000, 4)
		shock(0.3, 760, 3)
		sparks(40)
		-- 3.95 - 5.35 : M O N K Z one by one
		for i = 1, #letters do
			if not at(3.95 + 0.35 * (i - 1) - 0.05) then return end
			showLetter(i)
			apiA.Boost(1.1)
			bump(5, 0.2)
			shock(0.04, 520, 2)
		end
		-- 5.75 : all five together
		if not at(5.75) then return end
		allTogether()
		apiA.Boost(2)
		flash.BackgroundTransparency = 0.8
		TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		bump(10 * k, 0.4)
		shock(0, 900, 4)
		sparks(26)
		floating = true
		-- 5.95+ : LOADING (finishes when the hub is really ready, at least 2.5 s)
		if not at(5.95) then return end
		for _, o in ipairs({ loadL, pctL }) do TweenService:Create(o, TweenInfo.new(0.5), { TextTransparency = 0.05 }):Play() end
		TweenService:Create(barBg, TweenInfo.new(0.4), { BackgroundTransparency = 0.1 }):Play()
		local lt0, hum = os.clock(), nil
		local dots = { "L O A D I N G", "L O A D I N G .", "L O A D I N G . .", "L O A D I N G . . ." }
		local shown = 0
		while alive() do
			local el = os.clock() - lt0
			local p = math.clamp(el / 2.6, 0, 1)
			local ready = NovaUI._window and NovaUI.HubReady
			if not ready then p = math.min(p, 0.96) end
			if p > shown then shown = p end
			barFill.Size = UDim2.fromScale(shown, 1)
			pctL.Text = math.floor(shown * 100 + 0.5) .. "%"
			loadL.Text = dots[(math.floor(el * 3) % 4) + 1]
			barGrad.Offset = Vector2.new(math.sin(os.clock() * 3) * 0.3, 0)
			if os.clock() - T0 > 8.5 and not hum then
				hum = NovaUI.Sound("intro_hum", 0.6, 60, true)
				if hum then hum.Looped = true end
			end
			if shown >= 1 or el > 22 then break end
			RunService.Heartbeat:Wait()
		end
		if not alive() then return end
		pctL.Text = "100%"
		loadL.Text = "R E A D Y"
		-- ===== release: collapse, silence, white hole birth =====
		local tb = os.clock()
		if hum then pcall(function() hum:Destroy() end) end
		pcall(function() if sndA then sndA:Destroy() end end)
		NovaUI.Sound("intro_b", 0.95, 8, true)
		floating = false
		for _, o in ipairs({ loadL, pctL }) do TweenService:Create(o, TweenInfo.new(0.25), { TextTransparency = 1 }):Play() end
		TweenService:Create(barBg, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
		barFill.BackgroundTransparency = 1
		for _, L in ipairs(letters) do
			TweenService:Create(L.sc, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Scale = 0.001 }):Play()
			TweenService:Create(L.l, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
		end
		apiA.SetWhite(false, false)
		scaleTo(sA, 0.12, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		pull = 3
		bump(8 * k, 0.3)
		while alive() and os.clock() - tb < 0.3 do RunService.Heartbeat:Wait() end
		TweenService:Create(stage, TweenInfo.new(0.18), { GroupTransparency = 1 }):Play()
		vig.BackgroundTransparency = 1
		while alive() and os.clock() - tb < 0.5 do RunService.Heartbeat:Wait() end
		if not alive() then return end
		-- BOOM: the white hole is born
		stage.GroupTransparency = 0
		pull = 0
		for _, L in ipairs(letters) do L.l.TextTransparency = 1 L.st.Transparency = 1 end
		apiA.SetWhite(true, true)
		apiA.Boost(2.5)
		sA.Scale = 0.3
		scaleTo(sA, 1.7, 1.0, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		flash.BackgroundTransparency = 0
		TweenService:Create(flash, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
		bump(26 * k, 0.7)
		shock(0, 1700, 7)
		shock(0.12, 1200, 5)
		shock(0.26, 900, 3)
		sparks(54)
		reveal()
		while alive() and os.clock() - tb < 1.5 do RunService.Heartbeat:Wait() end
		TweenService:Create(stage, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { GroupTransparency = 1 }):Play()
		TweenService:Create(bg, TweenInfo.new(1.1, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
		while alive() and os.clock() - tb < 2.9 do RunService.Heartbeat:Wait() end
		cleanup(false)
	end)
	if not okIntro then
		warn("[YADSAN] intro error: " .. tostring(errIntro))
		if introGui then pcall(function() introGui:Destroy() end) end
		reveal()
	elseif not revealed then
		reveal()
	end
end)


local Window = NovaUI:CreateWindow({
	Name = "YADSAN HUB",
	Theme = "Blackhole",
	OrbText = "yadsan",
	Folder = "YADSAN_HUB",
})

------------------------------------------------------------------------
-- helpers
------------------------------------------------------------------------
local function notify(title, content)
	Window:Notify({ Title = title, Content = content })
end

local function getHum()
	local c = lp.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
	local c = lp.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local L = {}
local function startLoop(name, event, fn)
	if L[name] then
		L[name]:Disconnect()
	end
	L[name] = event:Connect(fn)
end
local function stopLoop(name)
	if L[name] then
		L[name]:Disconnect()
		L[name] = nil
	end
end

local net
task.spawn(function()
	pcall(function()
		local m = RS:WaitForChild("Modules", 10)
		local core = m:WaitForChild("Core", 10)
		net = require(core:WaitForChild("Net", 10))
	end)
end)

------------------------------------------------------------------------
-- movement
------------------------------------------------------------------------
local flying, flySpeed = false, 60
local flyBV, flyBG

local function stopFly()
	stopLoop("fly")
	if flyBV then flyBV:Destroy() flyBV = nil end
	if flyBG then flyBG:Destroy() flyBG = nil end
	local h = getHum()
	if h then
		h.PlatformStand = false
	end
end

local function startFly()
	stopFly()
	local root, h = getRoot(), getHum()
	if not root or not h then
		return
	end
	flyBV = Instance.new("BodyVelocity")
	flyBV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
	flyBV.Velocity = Vector3.zero
	flyBV.Parent = root
	flyBG = Instance.new("BodyGyro")
	flyBG.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
	flyBG.P = 1e4
	flyBG.CFrame = root.CFrame
	flyBG.Parent = root
	h.PlatformStand = true
	startLoop("fly", RunService.RenderStepped, function()
		local cam = workspace.CurrentCamera
		if not cam or not root.Parent then
			return
		end
		local look = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
		local right = Vector3.new(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z)
		if look.Magnitude > 0 then look = look.Unit end
		if right.Magnitude > 0 then right = right.Unit end
		local dir = h.MoveDirection
		local fwd, side = dir:Dot(look), dir:Dot(right)
		local vel = (cam.CFrame.LookVector * fwd + cam.CFrame.RightVector * side) * flySpeed
		if UIS:IsKeyDown(Enum.KeyCode.Space) then
			vel = vel + Vector3.new(0, flySpeed, 0)
		end
		if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
			vel = vel - Vector3.new(0, flySpeed, 0)
		end
		flyBV.Velocity = vel
		flyBG.CFrame = CFrame.new(root.Position, root.Position + cam.CFrame.LookVector)
	end)
end

------------------------------------------------------------------------
-- world
------------------------------------------------------------------------
local lightSaved
local function nightOn()
	if not lightSaved then
		lightSaved = {
			Brightness = Lighting.Brightness, FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows,
			Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
		}
	end
	startLoop("night", RunService.Heartbeat, function()
		Lighting.Brightness = 2
		Lighting.FogEnd = 1e6
		Lighting.GlobalShadows = false
		Lighting.Ambient = Color3.fromRGB(190, 190, 190)
		Lighting.OutdoorAmbient = Color3.fromRGB(190, 190, 190)
	end)
end
local function nightOff()
	stopLoop("night")
	if lightSaved then
		for k, v in pairs(lightSaved) do
			Lighting[k] = v
		end
		lightSaved = nil
	end
end

local fpsSaved
local function fpsOn()
	fpsSaved = { shadows = Lighting.GlobalShadows, items = {} }
	Lighting.GlobalShadows = false
	task.spawn(function()
		local n = 0
		for _, o in ipairs(workspace:GetDescendants()) do
			if o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Smoke") or o:IsA("Fire") or o:IsA("Sparkles") or o:IsA("Beam") then
				if o.Enabled and fpsSaved then
					table.insert(fpsSaved.items, o)
					o.Enabled = false
				end
			end
			n = n + 1
			if n % 400 == 0 then
				task.wait()
			end
		end
	end)
	for _, e in ipairs(Lighting:GetChildren()) do
		if e:IsA("PostEffect") and e.Enabled then
			table.insert(fpsSaved.items, e)
			e.Enabled = false
		end
	end
end
local function fpsOff()
	if fpsSaved then
		Lighting.GlobalShadows = fpsSaved.shadows
		for _, o in ipairs(fpsSaved.items) do
			pcall(function() o.Enabled = true end)
		end
		fpsSaved = nil
	end
end

local streetLights, streetOrig = {}, {}
local function collectStreetLights()
	streetLights, streetOrig = {}, {}
	local n = 0
	for _, o in ipairs(workspace:GetDescendants()) do
		if o:IsA("Light") then
			local p, hit = o, false
			for _ = 1, 3 do
				if not p then break end
				local nm = p.Name:lower()
				if nm:find("light") or nm:find("lamp") or nm:find("street") then
					hit = true
					break
				end
				p = p.Parent
			end
			if hit then
				table.insert(streetLights, o)
				streetOrig[o] = o.Color
			end
		end
		n = n + 1
		if n % 400 == 0 then
			task.wait()
		end
	end
end

------------------------------------------------------------------------
-- character
------------------------------------------------------------------------
local rgbSkin, rgbTool, rgbLights = false, false, false
local skinSaved, toolSaved = nil, {}
local hue = 0

local BODY_PROPS = { "HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3" }

RunService.Heartbeat:Connect(function(dt)
	if not (rgbSkin or rgbTool or rgbLights) then
		return
	end
	hue = (hue + dt * 0.25) % 1
	local col = Color3.fromHSV(hue, 1, 1)
	local c = lp.Character
	if c and rgbSkin then
		local bc = c:FindFirstChildOfClass("BodyColors")
		if bc then
			if not skinSaved then
				skinSaved = {}
				for _, k in ipairs(BODY_PROPS) do
					skinSaved[k] = bc[k]
				end
			end
			for _, k in ipairs(BODY_PROPS) do
				bc[k] = col
			end
		end
	end
	if c and rgbTool then
		local tool = c:FindFirstChildOfClass("Tool")
		if tool then
			for _, p in ipairs(tool:GetDescendants()) do
				if p:IsA("BasePart") then
					if not toolSaved[p] then
						toolSaved[p] = p.Color
					end
					p.Color = col
				end
			end
		end
	end
	if rgbLights then
		for _, l in ipairs(streetLights) do
			if l.Parent then
				l.Color = col
			end
		end
	end
end)

local function restoreSkin()
	local c = lp.Character
	local bc = c and c:FindFirstChildOfClass("BodyColors")
	if bc and skinSaved then
		for k, v in pairs(skinSaved) do
			bc[k] = v
		end
	end
	skinSaved = nil
end
local function restoreTool()
	for p, col in pairs(toolSaved) do
		if p.Parent then
			p.Color = col
		end
	end
	toolSaved = {}
end
local function restoreLights()
	for l, col in pairs(streetOrig) do
		if l.Parent then
			l.Color = col
		end
	end
end

local flash = false
task.spawn(function()
	local on = false
	while true do
		task.wait(0.35)
		if flash then
			on = not on
			local c = lp.Character
			if c then
				for _, p in ipairs(c:GetDescendants()) do
					if p:IsA("BasePart") then
						p.LocalTransparencyModifier = on and 1 or 0
					end
				end
			end
		else
			on = false
		end
	end
end)

local espOn, espColor, espHL = false, Color3.fromRGB(92, 124, 255), {}
local function espClear(p)
	if espHL[p] then
		espHL[p]:Destroy()
		espHL[p] = nil
	end
end
local function espAdd(p)
	espClear(p)
	if p == lp or not espOn or not p.Character then
		return
	end
	local h = Instance.new("Highlight")
	h.FillColor = espColor
	h.OutlineColor = Color3.new(1, 1, 1)
	h.FillTransparency = 0.55
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = p.Character
	espHL[p] = h
end
local function hookPlayer(p)
	p.CharacterAdded:Connect(function()
		task.wait(0.6)
		espAdd(p)
	end)
end
for _, p in ipairs(Players:GetPlayers()) do
	hookPlayer(p)
end
Players.PlayerAdded:Connect(hookPlayer)
Players.PlayerRemoving:Connect(espClear)

local antiInvis = false
task.spawn(function()
	while true do
		task.wait(0.5)
		if antiInvis then
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= lp and p.Character then
					for _, part in ipairs(p.Character:GetChildren()) do
						if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency > 0.9 then
							part.Transparency = 0
						end
					end
				end
			end
		end
	end
end)

local spawnCF
lp.CharacterAdded:Connect(function(c)
	if flying then
		task.wait(1)
		startFly()
	end
	if spawnCF then
		local r = c:WaitForChild("HumanoidRootPart", 8)
		task.wait(0.5)
		if r and r.Parent then
			c:PivotTo(spawnCF)
		end
	end
end)

------------------------------------------------------------------------
-- body size + outfit
------------------------------------------------------------------------
local function myDesc()
	local h = getHum()
	return h and h:GetAppliedDescription()
end

local PART_PROPS = { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }
local ANIM_PROPS = { "IdleAnimation", "WalkAnimation", "RunAnimation", "JumpAnimation", "FallAnimation", "ClimbAnimation", "SwimAnimation" }

------------------------------------------------------------------------
-- OUTFIT CORE
-- Fast path: ONE batched "wear_outfit_from_desc" call (same as Flames Hub) + skin_tone + body_scale + age.
-- Fallback: the game's own "code" remote per missing item (parallel, 0.02s apart).
------------------------------------------------------------------------
local applySize -- resizer, defined in the next block
NovaUI.Stat = NovaUI.Stat or function() end
local copyReport = {}
local captureItems, captureSkin, captureScale, wearItems
do
	local BODY_PROPS = { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }
	-- { description property, code type }
	local CLOTH_PROPS = { { "Pants", "Pants" }, { "Shirt", "Shirt" }, { "GraphicTShirt", "TShirt" }, { "Face", "Face" } }
	local wearBusy = false

	local function idKey(n)
		return ("%.0f"):format(tonumber(n) or 0)
	end

	local function accBase(a)
		local t = a.AccessoryType
		return (typeof(t) == "EnumItem") and t.Name or tostring(t)
	end

	function captureItems(desc)
		local items = {}
		local function add(id, ty, kind, extra)
			id = tonumber(id)
			if id and id ~= 0 then
				local it = { id = id, type = ty, kind = kind }
				if extra then
					for k, v in pairs(extra) do
						it[k] = v
					end
				end
				items[#items + 1] = it
			end
		end
		local ok, accs = pcall(function()
			return desc:GetAccessories(true)
		end)
		if ok and type(accs) == "table" then
			for _, a in ipairs(accs) do
				local base = accBase(a)
				add(a.AssetId, base:find("Accessory") and base or (base .. "Accessory"), "acc", {
					atype = base:gsub("Accessory$", ""), layered = a.IsLayered and true or false, order = a.Order or 0, puff = a.Puffiness or 0,
				})
			end
		end
		for _, c in ipairs(CLOTH_PROPS) do
			add(desc[c[1]], c[2], "cloth", { prop = c[1] })
		end
		for _, k in ipairs(ANIM_PROPS) do
			add(desc[k], k, "anim", { prop = k })
		end
		for _, k in ipairs(BODY_PROPS) do
			add(desc[k], k, "body", { prop = k })
		end
		return items
	end

	local function avgColors(getter)
		local r, g, b, n = 0, 0, 0, 0
		for _, k in ipairs({ "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }) do
			local ok, c = pcall(getter, k)
			if ok and typeof(c) == "Color3" then
				r, g, b, n = r + c.R, g + c.G, b + c.B, n + 1
			end
		end
		if n > 0 then
			return { r / n, g / n, b / n }
		end
	end

	function captureSkin(desc, char)
		local bc = char and char:FindFirstChildOfClass("BodyColors")
		if bc then
			local s = avgColors(function(k)
				return bc[k .. "Color3"]
			end)
			if s then
				return s
			end
		end
		return avgColors(function(k)
			return desc[k .. "Color"]
		end)
	end

	function captureScale(desc)
		local function g(k, d)
			local ok, v = pcall(function()
				return desc[k]
			end)
			return (ok and tonumber(v)) or d
		end
		return { g("HeightScale", 1), g("WidthScale", 1), g("HeadScale", 1), g("DepthScale", g("WidthScale", 1)), g("BodyTypeScale", 0), g("ProportionScale", 0) }
	end

	local function wornSet()
		local d = myDesc()
		if not d then
			return nil
		end
		local s = {}
		local ok, accs = pcall(function()
			return d:GetAccessories(true)
		end)
		if ok and type(accs) == "table" then
			for _, a in ipairs(accs) do
				s["acc" .. idKey(a.AssetId)] = true
			end
		end
		for _, c in ipairs(CLOTH_PROPS) do
			s[c[2] .. idKey(d[c[1]])] = true
		end
		for _, k in ipairs(ANIM_PROPS) do
			s[k .. idKey(d[k])] = true
		end
		for _, k in ipairs(BODY_PROPS) do
			s[k .. idKey(d[k])] = true
		end
		return s
	end

	local function isWorn(s, it)
		if it.kind == "acc" then
			return s["acc" .. idKey(it.id)] == true
		end
		return s[it.type .. idKey(it.id)] == true
	end

	local function zeroProps()
		local p = {}
		for _, k in ipairs({ "Shirt", "Pants", "GraphicTShirt", "Face", "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg",
			"WalkAnimation", "RunAnimation", "JumpAnimation", "FallAnimation", "ClimbAnimation", "IdleAnimation", "SwimAnimation" }) do
			p[k] = 0
		end
		p.HeightScale, p.HeadScale, p.WidthScale, p.DepthScale, p.ProportionScale, p.BodyTypeScale = 1, 1, 1, 1, 0, 0
		return p
	end

	local function clearOutfit()
		if not net then
			return
		end
		local function slot(t, layered, order)
			return { Rotation = "  ", Position = "  ", Scale = "1 1 1", AccessoryType = t, IsLayered = layered, AssetId = 0, Order = order, Puffiness = 0 }
		end
		local accs = { slot("Hair", false), slot("Face", false), slot("Hat", false), slot("Shirt", true, 1), slot("DressSkirt", true, 2), slot("RightShoe", true, 3), slot("LeftShoe", true, 4) }
		pcall(function()
			net.send("wear_outfit_from_desc", { accessories = accs, properties = zeroProps() })
		end)
		task.wait(0.2)
	end

	local function buildBatch(items, scale)
		local accs, props = {}, zeroProps()
		for _, it in ipairs(items) do
			if it.kind == "acc" then
				accs[#accs + 1] = {
					Rotation = "  ", Position = "  ", Scale = "1 1 1", IsLayered = it.layered or false,
					AccessoryType = it.atype or tostring(it.type):gsub("Accessory$", ""), AssetId = it.id, Order = it.order or 0, Puffiness = it.puff or 0,
				}
			elseif it.prop then
				props[it.prop] = it.id
			end
		end
		if scale then
			props.HeightScale, props.WidthScale, props.HeadScale = scale[1] or 1, scale[2] or 1, scale[3] or 1
			props.DepthScale = scale[4] or scale[2] or 1
			props.BodyTypeScale, props.ProportionScale = scale[5] or 0, scale[6] or 0
		end
		return { accessories = accs, properties = props }
	end

	-- items = { {id=, type=, kind=, ...}, ... }, skin = {r, g, b} or nil, onProgress(i, n) optional,
	-- extra = { scale = {h, w, head, depth, bodytype, proportion}, age = number }  (if scale is nil your own size is kept)
	function wearItems(items, skin, who, onProgress, extra)
		if wearBusy then
			return false, "Already busy, wait a moment"
		end
		if not net then
			return false, "Game network module not found (this only works inside Life Together RP)"
		end
		if type(items) ~= "table" or #items == 0 then
			return false, "Nothing to wear (empty outfit)"
		end
		extra = extra or {}
		if NovaUI.beforeWear then pcall(NovaUI.beforeWear) end
		wearBusy = true
		copyReport = { "Target: " .. tostring(who), "Items: " .. #items }
		local t0 = os.clock()
		local scale = extra.scale
		if not scale then
			local prev = myDesc()
			if prev then
				scale = captureScale(prev)
			end
		end
		local failedCalls = 0
		local verified, missing = false, {}
		local okRun, errRun = pcall(function()
			clearOutfit()
			-- 1) ONE batched call with the whole outfit
			pcall(function()
				net.send("wear_outfit_from_desc", buildBatch(items, scale))
			end)
			task.wait(0.25)
			local function check()
				local s = wornSet()
				if not s then
					return nil
				end
				local miss = {}
				for _, it in ipairs(items) do
					if not isWorn(s, it) then
						miss[#miss + 1] = it
					end
				end
				return miss
			end
			missing = check()
			verified = missing ~= nil
			missing = missing or {}
			copyReport[#copyReport + 1] = ("batch: %d/%d applied"):format(#items - #missing, #items)
			if onProgress then
				pcall(onProgress, #items - #missing, #items)
			end
			-- 2) anything the batch did not apply goes through the "code" remote (parallel, 0.02s apart)
			if #missing > 0 then
				local done = 0
				local missList = missing
				for _, it in ipairs(missList) do
					task.spawn(function()
						local okc, res = pcall(function()
							return net.get("code", it.id, it.type)
						end)
						if not okc or res == false then
							failedCalls = failedCalls + 1
							copyReport[#copyReport + 1] = ("code %s %s -> %s"):format(it.type, idKey(it.id), okc and "false" or tostring(res))
						end
						done = done + 1
					end)
					task.wait(0.02)
				end
				local w0 = os.clock()
				while done < #missList and os.clock() - w0 < 4 do
					task.wait(0.03)
				end
				task.wait(0.3)
				missing = check() or missing
			end
		end)
		if not okRun then
			copyReport[#copyReport + 1] = "run error: " .. tostring(errRun)
		end
		for _, it in ipairs(missing) do
			copyReport[#copyReport + 1] = ("missing: %s %s"):format(it.type, idKey(it.id))
		end

		-- skin colour + body scale + age (sent last so nothing overwrites them)
		if skin then
			pcall(function()
				net.send("skin_tone", Color3.new(skin[1], skin[2], skin[3]))
			end)
			task.wait(0.03)
			pcall(function()
				net.send("skin_tone", skin[1], skin[2], skin[3])
			end)
		end
		if scale and extra.scale then
			local h = math.clamp(math.floor((scale[1] or 1) * 100 + 0.5), 90, 105)
			local w = math.clamp(math.floor((scale[2] or 1) * 100 + 0.5), 70, 100)
			pcall(function()
				net.send("body_scale", "HeightScale", h)
			end)
			task.wait(0.05)
			pcall(function()
				net.send("body_scale", "WidthScale", w)
			end)
		end
		if extra.age then
			pcall(function()
				net.get("age", extra.age)
			end)
		end
		wearBusy = false

		local worn = verified and (#items - #missing) or #items
		local detail = ("%d/%d items worn in %.2fs"):format(worn, #items, os.clock() - t0)
		if not verified then
			detail = ("%d items sent (could not verify)"):format(#items)
		end
		copyReport[#copyReport + 1] = detail
		if verified and worn == 0 then
			return false, "Server did not apply any item (" .. failedCalls .. " call errors) - use Exploits > Copy fit report"
		end
		NovaUI.Stat("copies")
		return true, detail
	end
end


local function avgSkin(hum)
	local bc = hum and hum.Parent and hum.Parent:FindFirstChildOfClass("BodyColors")
	if not bc then
		return nil
	end
	local cols = { bc.HeadColor3, bc.TorsoColor3, bc.LeftArmColor3, bc.RightArmColor3, bc.LeftLegColor3, bc.RightLegColor3 }
	local r, g, b = 0, 0, 0
	for _, c in ipairs(cols) do
		r, g, b = r + c.R, g + c.G, b + c.B
	end
	return Color3.new(r / 6, g / 6, b / 6)
end

local function sendOutfit(outfit, skin)
	local ok, err = pcall(function()
		net.send("wear_outfit_from_desc", outfit)
	end)
	if not ok then
		return false, err
	end
	if skin then
		task.wait(0.03)
		pcall(function()
			net.send("skin_tone", skin)
		end)
	end
	return true
end

-- ========== RESIZER (per the AUTH0R re-sizer: full description + new scales through wear_outfit_from_desc) ==========
local function serializeDesc(d)
	local P = {}
	for _, k in ipairs({ "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "Face", "Shirt", "Pants", "GraphicTShirt",
		"RunAnimation", "WalkAnimation", "JumpAnimation", "FallAnimation", "ClimbAnimation", "IdleAnimation", "SwimAnimation" }) do
		P[k] = d[k] or 0
	end
	for _, k in ipairs({ "HeightScale", "WidthScale", "DepthScale", "HeadScale" }) do
		P[k] = d[k] or 1
	end
	P.BodyTypeScale = d.BodyTypeScale or 0
	P.ProportionScale = d.ProportionScale or 0
	local out = { accessories = {}, properties = P }
	pcall(function()
		for _, a in ipairs(d:GetAccessories(true)) do
			out.accessories[#out.accessories + 1] = {
				Rotation = "0 0 0", Position = "0 0 0", Scale = "1 1 1", IsLayered = a.IsLayered,
				AccessoryType = a.AccessoryType.Name, AssetId = a.AssetId, Order = a.Order or 0, Puffiness = a.Puffiness or 0,
			}
		end
	end)
	return out
end

function applySize(hs, ws, hds, skinOverride, ds)
	hds = hds or hs
	ds = ds or ws
	local h = getHum()
	if not h then
		return false, "Character not found"
	end
	local localOk = false
	for name, v in pairs({ BodyHeightScale = hs, BodyWidthScale = ws, BodyDepthScale = ds, HeadScale = hds }) do
		local o = h:FindFirstChild(name)
		if o and o:IsA("NumberValue") then
			o.Value = v
			localOk = true
		end
	end
	if net then
		local skin = avgSkin(h)
		local skinF
		if type(skinOverride) == "table" then
			skin = Color3.new(skinOverride[1], skinOverride[2], skinOverride[3])
			skinF = skinOverride
		end
		local okd, d = pcall(function()
			return h:GetAppliedDescription()
		end)
		if okd and d then
			local data = serializeDesc(d)
			data.properties.HeightScale = hs
			data.properties.WidthScale = ws
			data.properties.DepthScale = ds
			data.properties.HeadScale = hds
			local ok = pcall(function()
				net.send("wear_outfit_from_desc", data)
			end)
			if ok then
				task.wait(0.15)
				if skin then
					pcall(function()
						net.send("skin_tone", skin)
					end)
				end
				if skinF then
					task.wait(0.05)
					pcall(function()
						net.send("skin_tone", skinF[1], skinF[2], skinF[3])
					end)
				end
				return true, string.format("H=%.1f W=%.1f Head=%.1f", hs, ws, hds)
			end
		end
	end
	if localOk then
		return true, "Size applied (local only)"
	end
	return false, "Could not apply: Net module and scale values not found"
end

-- the AUTH0R auto formulas
local function autoW(s)
	if s <= 1 then return 1 end
	return math.max(1, math.floor(1 + (s - 1) * 1.34 + 0.5))
end
local function autoHead(s)
	if s <= 1 then return 1 end
	return math.max(1, math.floor(s + 0.5))
end

local sizeH, sizeW, sizeHead = 1, 1, 1

------------------------------------------------------------------------
-- avatar tools
------------------------------------------------------------------------
local target
local function needTarget()
	if not target or not target.Parent then
		notify("Select a player", "Pick someone from the list first.")
		return nil
	end
	return target
end

-- ========== SYNC ANIM (rewritten) ==========
-- Mirrors every animation track the target is playing, with matching speed/weight/time.
local syncConn, syncTracks, syncChar, animateWas = nil, {}, nil, nil

local function dropSyncTracks()
	for id, t in pairs(syncTracks) do
		pcall(function()
			t:Stop(0.15)
			t:Destroy()
		end)
		syncTracks[id] = nil
	end
end

local function stopSync()
	if syncConn then
		syncConn:Disconnect()
		syncConn = nil
	end
	dropSyncTracks()
	local an = syncChar and syncChar.Parent and syncChar:FindFirstChild("Animate")
	if an and animateWas ~= nil then
		an.Disabled = animateWas
	end
	animateWas, syncChar = nil, nil
end

local function startSync(getTarget, onLost)
	stopSync()
	local acc = 0
	syncConn = RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc < 0.08 then
			return
		end
		acc = 0
		local p = getTarget()
		if not p or not p.Parent then
			stopSync()
			if onLost then
				onLost()
			end
			return
		end
		local mc = lp.Character
		local mh = getHum()
		local ma = mh and mh:FindFirstChildOfClass("Animator")
		if not (mc and ma) then
			return
		end
		if mc ~= syncChar then
			dropSyncTracks()
			syncChar = mc
			local an = mc:FindFirstChild("Animate")
			if an then
				animateWas = an.Disabled
				an.Disabled = true
			end
			for _, t in ipairs(ma:GetPlayingAnimationTracks()) do
				t:Stop(0.1)
			end
		end
		local th = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		local ta = th and th:FindFirstChildOfClass("Animator")
		if not ta then
			return
		end
		local playing = {}
		for _, tr in ipairs(ta:GetPlayingAnimationTracks()) do
			local id = tr.Animation and tr.Animation.AnimationId
			if id and id ~= "" and tr.WeightCurrent > 0.01 then
				playing[id] = true
				local mt = syncTracks[id]
				if not mt then
					local a = Instance.new("Animation")
					a.AnimationId = id
					local ok, t = pcall(function()
						return ma:LoadAnimation(a)
					end)
					if ok and t then
						local pr = tr.Priority
						t.Priority = (pr == Enum.AnimationPriority.Core or pr == Enum.AnimationPriority.Idle or pr == Enum.AnimationPriority.Movement) and Enum.AnimationPriority.Action or Enum.AnimationPriority.Action4
						t.Looped = tr.Looped
						t:Play(0.1, math.max(tr.WeightCurrent, 0.01), tr.Speed)
						pcall(function()
							t.TimePosition = tr.TimePosition
						end)
						syncTracks[id] = t
					end
				else
					if not mt.IsPlaying then
						mt:Play(0.1, math.max(tr.WeightCurrent, 0.01), tr.Speed)
					end
					mt:AdjustSpeed(tr.Speed)
					mt:AdjustWeight(math.max(tr.WeightCurrent, 0.01), 0.1)
					if math.abs(mt.TimePosition - tr.TimePosition) > 0.35 then
						pcall(function()
							mt.TimePosition = tr.TimePosition
						end)
					end
				end
			end
		end
		for id, t in pairs(syncTracks) do
			if not playing[id] then
				pcall(function()
					t:Stop(0.15)
					t:Destroy()
				end)
				syncTracks[id] = nil
			end
		end
	end)
end

-- ========== FIT COPIER (code remote, same method as the original working copier) ==========
local function optedOut(p)
	local function flag(o)
		local ok, v = pcall(function()
			return o:GetAttribute("hide_view_outfit")
		end)
		return ok and v == true
	end
	if flag(p) or (p.Character and flag(p.Character)) then
		return true
	end
	local ok, bio = pcall(function()
		return p:GetAttribute("bio")
	end)
	if ok and type(bio) == "string" then
		local b = bio:lower()
		if b:find("anti%s*%-?%s*steal") or b:find("anti%s*%-?%s*copy") or b:find("no%s*copy") then
			return true
		end
	end
	return false
end

local function copyAvatar(p)
	if p and optedOut(p) then
		return false, p.DisplayName .. " hides their outfit (privacy setting), not copied"
	end
	if not p or not p.Character then
		return false, "Target character not loaded"
	end
	local th = p.Character:FindFirstChildOfClass("Humanoid") or p.Character:WaitForChild("Humanoid", 3)
	if not th then
		return false, "Target Humanoid not found"
	end
	local okd, td = pcall(function()
		return th:GetAppliedDescription()
	end)
	if not okd or not td then
		return false, "Could not read their outfit"
	end
	return wearItems(captureItems(td), captureSkin(td, p.Character), p.Name, nil, { scale = captureScale(td), age = p:GetAttribute("age") })
end

------------------------------------------------------------------------
-- STAFF TITLES (winged swirl title like the MKnight/24H script, matched by USERNAME)
-- Only people running YADSAN HUB see these.
------------------------------------------------------------------------
local roleOf
do
local TAGS = {
	theredauth0r = { title = "HUB ADMIN", colors = { Color3.fromRGB(255, 150, 150), Color3.fromRGB(150, 24, 60) } },
	supermonkxscripts = { title = "HUB OWNER", colors = { Color3.new(1, 1, 1), Color3.fromRGB(125, 201, 245) } },
}
local titleGui = Instance.new("ScreenGui")
titleGui.Name = "YadsanTitles"
titleGui.ResetOnSpawn = false
titleGui.Parent = Window.Gui.Parent
local titleAnims, titleBoards = {}, {}
RunService.RenderStepped:Connect(function()
	local t = os.clock() * 60
	for i = #titleAnims, 1, -1 do
		local a = titleAnims[i]
		if not a.board.Parent then
			table.remove(titleAnims, i)
		else
			local s, c = math.sin(t / 20), math.cos(t / 20)
			a.left.Rotation = 180 - 10 * s
			a.right.Rotation = 10 * s
			a.lt.Rotation, a.lm.Rotation, a.lb.Rotation = 120 + 7 * c, 90 + 7 * c, 60 + 7 * c
			a.rt.Rotation, a.rm.Rotation, a.rb.Rotation = 120 - 7 * c, 90 - 7 * c, 60 - 7 * c
			a.swirl.Rotation = -t
			a.spin.Rotation = t * 2
			a.whoG.Rotation = 180 + t / 1.125
			a.titleG.Rotation = -t / 1.125
		end
	end
end)

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function sarpanch(o)
	pcall(function()
		o.FontFace = Font.new("rbxasset://fonts/families/Sarpanch.json")
	end)
end

local function buildBoard(name, info)
	local col = info.colors[1]
	local seq = ColorSequence.new(info.colors[1], info.colors[2])
	local half = Vector2.new(0.5, 0.5)
	local bb = mk("BillboardGui", { AlwaysOnTop = true, StudsOffsetWorldSpace = Vector3.new(0, 5, 0), Size = UDim2.new(8.75, 0, 8.75, 0), ResetOnSpawn = false }, titleGui)
	local main = mk("Frame", { AnchorPoint = half, Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0 }, bb)
	local a = { board = bb }
	local function side(posX, isLeft)
		local fr = mk("Frame", { ZIndex = -2, AnchorPoint = half, Size = UDim2.fromScale(0.5, 0.5), Position = UDim2.fromScale(posX, 0.5), Rotation = isLeft and 180 or 0, BackgroundTransparency = 1, BorderSizePixel = 0 }, main)
		local wings = mk("Frame", { ZIndex = -1, AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0 }, fr)
		local function arm(rot, px, py)
			local im = mk("ImageLabel", { BorderSizePixel = 0, ImageColor3 = col, AnchorPoint = Vector2.new(1, 0.5), Image = "rbxassetid://14221272033", Size = UDim2.fromScale(0.5, 1), BackgroundTransparency = 1, Rotation = rot, Position = UDim2.fromScale(px, py) }, wings)
			mk("UIGradient", { Rotation = -90, Color = seq }, im)
			return im
		end
		local m, t, b = arm(90, 0.75, 0.5), arm(120, 0.8, 0.15), arm(60, 0.8, 0.85)
		return fr, t, m, b
	end
	a.left, a.lt, a.lm, a.lb = side(0.4, true)
	a.right, a.rt, a.rm, a.rb = side(0.6, false)
	local infoF = mk("Frame", { BorderSizePixel = 0, AnchorPoint = half, Size = UDim2.fromScale(0.35, 0.35), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1 }, main)
	a.swirl = mk("ImageLabel", { ZIndex = 4, BorderSizePixel = 0, ScaleType = Enum.ScaleType.Fit, ImageColor3 = col, AnchorPoint = half, Image = "rbxassetid://12363692920", Size = UDim2.fromScale(1.15, 1.15), BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0.5) }, infoF)
	local who = mk("TextLabel", { TextWrapped = true, ZIndex = 5, BorderSizePixel = 0, TextScaled = true, TextColor3 = col, BackgroundTransparency = 1, AnchorPoint = half, Size = UDim2.fromScale(1.25, 0.35), Position = UDim2.fromScale(0.5, 0.25), Text = name }, infoF)
	sarpanch(who)
	a.whoG = mk("UIGradient", { Color = seq }, who)
	mk("UIStroke", {}, who)
	local ttl = mk("TextLabel", { TextWrapped = true, ZIndex = 5, BorderSizePixel = 0, TextScaled = true, TextColor3 = col, BackgroundTransparency = 1, AnchorPoint = half, Size = UDim2.fromScale(1.25, 0.35), Position = UDim2.fromScale(0.5, 0.675), Text = info.title }, infoF)
	sarpanch(ttl)
	a.titleG = mk("UIGradient", { Color = seq }, ttl)
	mk("UIStroke", {}, ttl)
	mk("ImageLabel", { ZIndex = 3, BorderSizePixel = 0, ScaleType = Enum.ScaleType.Fit, ImageColor3 = col, ResampleMode = Enum.ResamplerMode.Pixelated, AnchorPoint = half, Image = "rbxassetid://13273852131", Size = UDim2.fromScale(1.25, 1.25), BackgroundTransparency = 1, Rotation = 45, Position = UDim2.fromScale(0.5, 0.5) }, infoF)
	a.spin = mk("ImageLabel", { BorderSizePixel = 0, ScaleType = Enum.ScaleType.Fit, ImageColor3 = col, AnchorPoint = half, Image = "rbxassetid://9563796105", Size = UDim2.fromScale(1.25, 1.25), BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0.5) }, infoF)
	mk("ImageLabel", { ZIndex = 2, BorderSizePixel = 0, ImageColor3 = col, ResampleMode = Enum.ResamplerMode.Pixelated, AnchorPoint = half, Image = "rbxassetid://108982568848492", Size = UDim2.fromScale(2, 1.4), BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0.5) }, infoF)
	titleAnims[#titleAnims + 1] = a
	return bb
end

local function tagPlayer(p)
	local info = TAGS[p.Name:lower()]
	if not info or titleBoards[p] then
		return
	end
	local bb = buildBoard(p.Name, info)
	titleBoards[p] = bb
	local function attach(c)
		local hrp = c:WaitForChild("HumanoidRootPart", 10)
		if hrp and bb.Parent then
			bb.Adornee = hrp
		end
	end
	if p.Character then
		task.spawn(attach, p.Character)
	end
	p.CharacterAdded:Connect(function(c)
		task.spawn(attach, c)
	end)
end
for _, p in ipairs(Players:GetPlayers()) do
	tagPlayer(p)
end
Players.PlayerAdded:Connect(tagPlayer)
Players.PlayerRemoving:Connect(function(p)
	local bb = titleBoards[p]
	if bb then
		bb:Destroy()
		titleBoards[p] = nil
	end
end)
roleOf = function(name)
	local i = TAGS[tostring(name):lower()]
	if not i then
		return nil
	end
	return i.title:find("OWNER") and "OWNER" or "ADMIN"
end
end
local espToggle
------------------------------------------------------------------------
-- feature switches (used by the Home tiles and by commands)
------------------------------------------------------------------------
local runCommand
local function setFly(v)
	flying = v
	if v then startFly() else stopFly() end
end
local function setNoclip(v)
	if v then
		startLoop("noclip", RunService.Stepped, function()
			local c = lp.Character
			if c then
				for _, p in ipairs(c:GetDescendants()) do
					if p:IsA("BasePart") then
						p.CanCollide = false
					end
				end
			end
		end)
	else
		stopLoop("noclip")
	end
end
local function setInfJump(v)
	stopLoop("infjump")
	if v then
		L.infjump = UIS.JumpRequest:Connect(function()
			local h = getHum()
			if h then
				h:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end)
	end
end
local function setAntiFling(v)
	if v then
		startLoop("antifling", RunService.Stepped, function()
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= lp and p.Character then
					for _, part in ipairs(p.Character:GetChildren()) do
						if part:IsA("BasePart") then
							part.CanCollide = false
						end
					end
				end
			end
			local r = getRoot()
			if r and r.AssemblyLinearVelocity.Magnitude > 250 then
				r.AssemblyLinearVelocity = Vector3.zero
				r.AssemblyAngularVelocity = Vector3.zero
			end
		end)
	else
		stopLoop("antifling")
	end
end
local function setNight(v)
	if v then nightOn() else nightOff() end
end
local function setFps(v)
	if v then fpsOn() else fpsOff() end
end

------------------------------------------------------------------------
-- HOME  (Hub Interface + game card)
------------------------------------------------------------------------
local Home = Window:CreateTab({ Name = "Home", Icon = "home" })

local hubSec = Home:Section({ Title = "Hub Interface", Icon = "grid", Side = "Left" })
local tiles = hubSec:Actions({
	{ Title = "Fly", Description = "Off", Icon = "plane", Toggle = true, Flag = "Fly", Callback = setFly },
	{ Title = "Noclip", Description = "Off", Icon = "ghost", Toggle = true, Flag = "Noclip", Callback = setNoclip },
	{ Title = "Infinite Jump", Description = "Off", Icon = "feather", Toggle = true, Flag = "InfJump", Callback = setInfJump },
	{ Title = "Anti Fling", Description = "Off", Icon = "shield", Toggle = true, Flag = "AntiFling", Callback = setAntiFling },
	{ Title = "Night Vision", Description = "Off", Icon = "moon", Toggle = true, Flag = "NightVision", Callback = setNight },
	{ Title = "FPS Boost", Description = "Off", Icon = "cpu", Toggle = true, Flag = "FPSBoost", Callback = setFps },
})

local move = Home:Section({ Title = "Movement", Icon = "bolt", Side = "Left" })
move:Slider({ Title = "Fly speed", Min = 10, Max = 200, Default = 60, Increment = 5, Flag = "FlySpeed", Callback = function(v) flySpeed = v end })
move:Keybind({ Title = "Fly key", Default = Enum.KeyCode.F, Flag = "FlyKey", Callback = function() tiles["Fly"]:Set(not tiles["Fly"]:Get()) end })

local gameSec = Home:Section({ Title = "Now Playing", Icon = "game", Side = "Right" })
gameSec:GameCard()

local world = Home:Section({ Title = "World", Icon = "sun", Side = "Right" })
world:Slider({ Title = "Time of day", Min = 0, Max = 24, Default = math.floor(Lighting.ClockTime), Increment = 1, Suffix = "h", Flag = "ClockTime", Callback = function(v)
	Lighting.ClockTime = v
end })

local quick = Home:Section({ Title = "Quick Commands", Icon = "terminal", Side = "Left" })
quick:Actions({
	{ Title = "Commands", Description = "Open tab", Icon = "terminal", Callback = function() Window:SelectTab("Commands") end },
	{ Title = "Fullbright", Description = "Light up", Icon = "sun", Callback = function() runCommand("fullbright") end },
	{ Title = "Reset", Description = "Respawn", Icon = "refresh", Callback = function() runCommand("reset") end },
	{ Title = "Rejoin", Description = "Same server", Icon = "door", Callback = function() runCommand("rejoin") end },
})

------------------------------------------------------------------------
-- HOME hero card (centre column, only when the window is wide enough)
------------------------------------------------------------------------
do
	local hero = Instance.new("Frame")
	hero.Name = "Hero"
	hero.AnchorPoint = Vector2.new(0.5, 0)
	hero.Position = UDim2.new(0.5, 0, 0, 318)
	hero.Size = UDim2.fromOffset(280, 236)
	hero.BackgroundColor3 = Color3.fromRGB(14, 8, 26)
	hero.BackgroundTransparency = 0.25
	hero.Visible = false
	hero.Parent = Home.Page
	Instance.new("UICorner", hero).CornerRadius = UDim.new(0, 18)
	local hs = Instance.new("UIStroke")
	hs.Color = Color3.fromRGB(150, 70, 255)
	hs.Transparency = 0.55
	hs.Parent = hero
	local hg = Instance.new("UIGradient")
	hg.Rotation = 90
	hg.Color = ColorSequence.new(Color3.fromRGB(30, 14, 56), Color3.fromRGB(8, 4, 16))
	hg.Parent = hero
	local av = Instance.new("ImageLabel")
	av.Size = UDim2.fromOffset(96, 96)
	av.AnchorPoint = Vector2.new(0.5, 0)
	av.Position = UDim2.new(0.5, 0, 0, 14)
	av.BackgroundColor3 = Color3.fromRGB(24, 14, 42)
	av.Parent = hero
	Instance.new("UICorner", av).CornerRadius = UDim.new(1, 0)
	local avs = Instance.new("UIStroke")
	avs.Color = Color3.fromRGB(190, 130, 255)
	avs.Thickness = 2
	avs.Parent = av
	task.spawn(function()
		local ok, url = pcall(function()
			return Players:GetUserThumbnailAsync(lp.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok then av.Image = url end
	end)
	local function lbl(text, y, size, color, font)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.new(0.5, 0, 0, y)
		l.Size = UDim2.new(1, -24, 0, size + 4)
		l.Font = font or Enum.Font.GothamMedium
		l.TextSize = size
		l.TextColor3 = color
		l.Text = text
		l.TextTruncate = Enum.TextTruncate.AtEnd
		l.Parent = hero
		return l
	end
	lbl(lp.DisplayName, 120, 18, Color3.fromRGB(240, 228, 255), Enum.Font.GothamBold)
	lbl("@" .. lp.Name, 143, 12, Color3.fromRGB(140, 118, 186))
	local role = roleOf(lp.Name) or "MEMBER"
	local rc = role == "OWNER" and Color3.fromRGB(255, 202, 74) or (role == "ADMIN" and Color3.fromRGB(255, 96, 96) or Color3.fromRGB(190, 130, 255))
	lbl(role, 166, 13, rc, Enum.Font.GothamBlack)
	local exec = "Unknown executor"
	pcall(function() exec = identifyexecutor() end)
	lbl(tostring(exec) .. "  |  " .. #Players:GetPlayers() .. " online", 192, 12, Color3.fromRGB(140, 118, 186))
	local function fit()
		local sc = 1
		pcall(function() sc = Window._main.Parent:FindFirstChildOfClass("UIScale").Scale end)
		hero.Visible = (Window._main.AbsoluteSize.X / sc) >= 960
	end
	Window._main:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
end

------------------------------------------------------------------------
-- ambient starfield behind the whole window (cheap tween loops)
------------------------------------------------------------------------
do
	local TS = game:GetService("TweenService")
	local layer = Instance.new("Frame")
	layer.Name = "YadsanStars"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.new(1, -24, 1, -24)
	layer.Position = UDim2.fromOffset(12, 12)
	layer.ClipsDescendants = true
	layer.ZIndex = 0
	layer.Active = false
	layer.Parent = Window._main
	local rnd = Random.new()
	for i = 1, 44 do
		local s = Instance.new("Frame")
		local sz = rnd:NextInteger(1, 3)
		s.Size = UDim2.fromOffset(sz, sz)
		local x, y = rnd:NextNumber(), rnd:NextNumber()
		s.Position = UDim2.fromScale(x, y)
		s.BackgroundColor3 = (i % 4 == 0) and Color3.fromRGB(200, 160, 255) or Color3.new(1, 1, 1)
		s.BackgroundTransparency = rnd:NextNumber(0.55, 0.9)
		s.BorderSizePixel = 0
		s.ZIndex = 0
		s.Parent = layer
		TS:Create(s, TweenInfo.new(rnd:NextNumber(1.2, 3.2), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, rnd:NextNumber(0, 2)), { BackgroundTransparency = 0.97 }):Play()
		TS:Create(s, TweenInfo.new(rnd:NextNumber(9, 20), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.fromScale(math.clamp(x + rnd:NextNumber(-0.05, 0.05), 0, 1), math.clamp(y + rnd:NextNumber(-0.08, 0.08), 0, 1)) }):Play()
	end
end


------------------------------------------------------------------------
-- AVATAR
------------------------------------------------------------------------
local Avatar = Window:CreateTab({ Name = "Avatar", Icon = "user" })

local pinfo
local listSec = Avatar:Section({ Title = "Avatar Copying", Side = "Left" })
listSec:PlayerList({ Height = 330, Callback = function(p)
	target = p
	if pinfo then
		pinfo:Set(p)
	end
end })

local actSec = Avatar:Section({ Side = "Right" })
pinfo = actSec:PlayerInfo({ Range = 60 })

local act
local syncing = false
local hideOn = false
task.spawn(function()
	while true do
		task.wait(0.3)
		if hideOn and target and target.Character then
			for _, p in ipairs(target.Character:GetDescendants()) do
				if p:IsA("BasePart") then
					p.LocalTransparencyModifier = 1
				end
			end
		end
	end
end)
act = actSec:Actions({
	{ Title = "Copy Avatar", Description = "Wear their look", Icon = "user", Callback = function()
		local p = needTarget()
		if not p then return end
		task.spawn(function()
			local ok, d = copyAvatar(p)
			notify(ok and "Copy Avatar" or "Copy Avatar failed", ok and ("Copied " .. p.DisplayName .. ": " .. tostring(d)) or tostring(d))
		end)
	end },
	{ Title = "Sync Anim", Description = "Off", Icon = "game", Toggle = true, Callback = function(v)
		if v then
			if not needTarget() then
				act["Sync Anim"]:Set(false, true)
				return
			end
			startSync(function() return target end, function() act["Sync Anim"]:Set(false, true) end)
		else
			stopSync()
		end
	end },
	{ Title = "Spectate", Description = "Off", Icon = "eye", Toggle = true, Callback = function(v)
		local cam = workspace.CurrentCamera
		if v then
			local p = needTarget()
			local th = p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if not th then
				act["Spectate"]:Set(false, true)
				return
			end
			cam.CameraSubject = th
		else
			local h = getHum()
			if h then
				cam.CameraSubject = h
			end
		end
	end },
	{ Title = "Hide", Description = "Off", Icon = "eye", Toggle = true, Callback = function(v)
		hideOn = v
		if v then
			if not needTarget() then
				hideOn = false
				act["Hide"]:Set(false, true)
			end
		else
			local c = target and target.Character
			if c then
				for _, p in ipairs(c:GetDescendants()) do
					if p:IsA("BasePart") then
						p.LocalTransparencyModifier = 0
					end
				end
			end
		end
	end },
	{ Title = "Go To", Description = "Teleport next to them", Icon = "bolt", Callback = function()
		local p = needTarget()
		local tr = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		local r = getRoot()
		if tr and r then
			r.CFrame = tr.CFrame * CFrame.new(0, 0, 3)
		end
	end },
	{ Title = "Copy Emote", Description = "Mimic them for 8s", Icon = "star", Callback = function()
		local p = needTarget()
		if not p then return end
		act["Sync Anim"]:Set(true)
		task.delay(8, function()
			act["Sync Anim"]:Set(false)
		end)
	end },
	{ Title = "Stop Anim", Description = "Stop copied anims", Icon = "close", Callback = function()
		act["Sync Anim"]:Set(false)
	end },
})

------------------------------------------------------------------------
-- FEATURES
------------------------------------------------------------------------
local Features = Window:CreateTab({ Name = "Features", Icon = "feature" })

local char = Features:Section({ Title = "Character", Icon = "user", Side = "Left" })
char:Toggle({ Title = "RGB Skin", Description = "Cycle your skin tone (only you see it)", Icon = "palette", Flag = "RGBSkin", Callback = function(v)
	rgbSkin = v
	if not v then restoreSkin() end
end })
char:Toggle({ Title = "RGB Tool", Description = "Cycle your tool color (only you see it)", Icon = "palette", Flag = "RGBTool", Callback = function(v)
	rgbTool = v
	if not v then restoreTool() end
end })
char:Toggle({ Title = "Flash Invisible", Description = "Blink your character (only you see it)", Icon = "eye", Flag = "FlashInvis", Callback = function(v)
	flash = v
	if not v then
		local c = lp.Character
		if c then
			for _, p in ipairs(c:GetDescendants()) do
				if p:IsA("BasePart") then
					p.LocalTransparencyModifier = 0
				end
			end
		end
	end
end })

local body = Features:Section({ Title = "Body Size", Icon = "settings", Side = "Left" })
local autoScale = true
local function sizeNote(ok, msg, label)
	notify(ok and "Body Size" or "Body Size failed", ok and (label or msg) or tostring(msg))
end
local function applyHeight(hh, label)
	local ww, hd = sizeW, sizeHead
	if autoScale then
		ww, hd = autoW(hh), autoHead(hh)
	end
	task.spawn(function()
		local ok, e = applySize(hh, ww, hd)
		sizeNote(ok, e, label or string.format("H %s  W %s  Head %s", hh, ww, hd))
	end)
end
body:Toggle({ Title = "Auto width + head", Description = "Width/head follow height (AUTH0R formula)", Icon = "ruler", Default = true, Flag = "SizeAuto", Callback = function(v)
	autoScale = v
end })
body:Input({ Placeholder = "Height (0.1 - 10000), type & enter", Numeric = true, Callback = function(t)
	local n = tonumber(t)
	if not n then return end
	n = math.clamp(n, 0.1, 10000)
	sizeH = n
	applyHeight(n)
end })
body:Slider({ Title = "Height", Min = 0.1, Max = 100, Default = 1, Increment = 0.1, Suffix = "x", Flag = "SizeH", Callback = function(v) sizeH = v end })
body:Slider({ Title = "Width", Min = 0.1, Max = 100, Default = 1, Increment = 0.1, Suffix = "x", Flag = "SizeW", Callback = function(v) sizeW = v end })
body:Slider({ Title = "Head", Min = 0.1, Max = 100, Default = 1, Increment = 0.1, Suffix = "x", Flag = "SizeHead", Callback = function(v) sizeHead = v end })
body:Button({ Title = "Apply size", Style = "Primary", Callback = function()
	applyHeight(sizeH)
end })
body:Button({ Title = "Reset size", Callback = function()
	task.spawn(function()
		local ok, e = applySize(1, 1, 1)
		sizeNote(ok, e, "Back to normal")
	end)
end })

local SIZE_PRESETS = {
	{ "Normal", 1, 1, 1, "user" }, { "Tall", 3, 4, 3, "ruler" }, { "Giant", 6, 8, 6, "stand" }, { "Titan", 15, 20, 15, "flame" },
	{ "Mega", 30, 40, 30, "rocket" }, { "Short", 0.6, 1, 0.8, "minus" }, { "Custom 59", 59, 79, 59, "star" }, { "Big Head", 1, 1, 3, "eye" },
	{ "Small Head", 3, 4, 1, "eye" }, { "Chonky", 2, 4, 2, "user" }, { "Wide", 1, 5, 1, "ruler" },
}
local presetActs = {}
for _, p in ipairs(SIZE_PRESETS) do
	presetActs[#presetActs + 1] = { Title = p[1], Description = string.format("H%s W%s Hd%s", p[2], p[3], p[4]), Icon = p[5], Callback = function()
		task.spawn(function()
			local ok, e = applySize(p[2], p[3], p[4])
			sizeNote(ok, e, p[1])
		end)
	end }
end
body:Actions(presetActs)


local util = Features:Section({ Title = "Utility", Icon = "settings", Side = "Right" })
espToggle = util:Toggle({ Title = "Player ESP", Description = "Highlight everyone through walls", Icon = "eye", Flag = "ESP", Callback = function(v)
	espOn = v
	for _, p in ipairs(Players:GetPlayers()) do
		if v then espAdd(p) else espClear(p) end
	end
end })
util:ColorPicker({ Title = "ESP color", Default = espColor, Flag = "ESPColor", Callback = function(c)
	espColor = c
	for _, h in pairs(espHL) do
		h.FillColor = c
	end
end })
util:Toggle({ Title = "Anti Invisible Players", Description = "See invisible players", Icon = "eye", Flag = "AntiInvis", Callback = function(v) antiInvis = v end })
util:Toggle({ Title = "RGB Street Lights", Description = "Cycle the street lights (only you see it)", Icon = "palette", Flag = "RGBLights", Callback = function(v)
	if v then
		task.spawn(function()
			collectStreetLights()
			rgbLights = true
		end)
	else
		rgbLights = false
		restoreLights()
	end
end })
util:Button({ Title = "Set SpawnPoint", Callback = function()
	local r = getRoot()
	if r then
		spawnCF = r.CFrame
		notify("Spawn", "Spawn point saved. You will respawn here.")
	end
end })
util:Button({ Title = "Clear SpawnPoint", Callback = function()
	spawnCF = nil
	notify("Spawn", "Spawn point cleared.")
end })

------------------------------------------------------------------------
-- MORE FEATURES (Novoline-style)
------------------------------------------------------------------------
local function cmdToggle(on, off)
	return function(v) runCommand(v and on or off) end
end
local vis = Features:Section({ Title = "Visuals & Camera", Icon = "eye", Side = "Left" })
vis:Actions({
	{ Title = "Freecam", Description = "Off", Icon = "camera", Toggle = true, Callback = cmdToggle("freecam", "unfreecam") },
	{ Title = "X-Ray", Description = "Off", Icon = "scan", Toggle = true, Callback = cmdToggle("xray", "unxray") },
	{ Title = "Fullbright", Description = "Tap", Icon = "sun", Callback = function() runCommand("fullbright") end },
	{ Title = "No Fog", Description = "Tap", Icon = "cloud", Callback = function() runCommand("nofog") end },
})
vis:Slider({ Title = "Max zoom", Min = 10, Max = 2000, Default = 128, Increment = 10, Flag = "MaxZoom", Callback = function(v) lp.CameraMaxZoomDistance = v end })
vis:Slider({ Title = "Brightness", Min = 0, Max = 10, Default = 2, Increment = 0.5, Flag = "Bright", Callback = function(v) Lighting.Brightness = v end })

local mov = Features:Section({ Title = "Movement+", Icon = "run", Side = "Right" })
mov:Actions({
	{ Title = "Airwalk", Description = "Off", Icon = "feather", Toggle = true, Callback = cmdToggle("airwalk", "unairwalk") },
	{ Title = "Spin", Description = "Off", Icon = "refresh", Toggle = true, Callback = cmdToggle("spin 12", "unspin") },
	{ Title = "Anti AFK", Description = "Off", Icon = "clock", Toggle = true, Callback = cmdToggle("antiafk", "unantiafk") },
	{ Title = "Anti Sit", Description = "Off", Icon = "lock", Toggle = true, Callback = cmdToggle("antisit", "enablesit") },
	{ Title = "Click TP", Description = "Get tool", Icon = "mouse", Callback = function() runCommand("clicktp") end },
	{ Title = "Float", Description = "No gravity", Icon = "wind", Toggle = true, Callback = function(v) workspace.Gravity = v and 0 or 196.2 end },
})
mov:Slider({ Title = "Gravity", Min = 0, Max = 400, Default = 196, Increment = 4, Flag = "Gravity", Callback = function(v) workspace.Gravity = v end })
mov:Slider({ Title = "Hip height", Min = 0, Max = 50, Default = 0, Increment = 0.5, Flag = "HipHeight", Callback = function(v) local h = getHum() if h then h.HipHeight = v end end })

local wp = Features:Section({ Title = "Waypoints", Icon = "map", Side = "Left" })
local wpName = wp:Input({ Placeholder = "Waypoint name" })
wp:Actions({
	{ Title = "Save here", Description = "Current spot", Icon = "save", Callback = function() runCommand("setwaypoint " .. tostring(wpName:Get() or ""):gsub("%s", "_")) end },
	{ Title = "Teleport", Description = "To name", Icon = "move", Callback = function() runCommand("gotowaypoint " .. tostring(wpName:Get() or ""):gsub("%s", "_")) end },
	{ Title = "List", Description = "All saved", Icon = "list", Callback = function() runCommand("waypoints") end },
	{ Title = "Delete", Description = "By name", Icon = "trash", Callback = function() runCommand("deletewaypoint " .. tostring(wpName:Get() or ""):gsub("%s", "_")) end },
})

------------------------------------------------------------------------
-- EXPLOITS
------------------------------------------------------------------------
local Dev = Window:CreateTab({ Name = "Exploits", Icon = "flame" })
local logSec = Dev:Section({ Title = "Net Logger", Icon = "server", Side = "Left" })
local logHow = Dev:Section({ Title = "How to use", Side = "Right" })
logHow:Paragraph({
	Title = "For missing features",
	Content = "1) Turn Logger ON.\n2) Use the game's own buttons once for that action (Lock Home, Spawn Vehicle, Block Calls, Rainbow Vehicle etc.).\n3) Press Copy log and paste it back. That reveals the exact remote calls.",
})

local logLines, logOn, logHooked = {}, false, false
local HttpService = game:GetService("HttpService")
local rec = { on = false, calls = {}, last = 0 }
local replaying = false

local function ser(v, d)
	d = d or 0
	local t = typeof(v)
	if t == "string" then
		return string.format("%q", v)
	elseif t == "Instance" then
		return "<" .. v.ClassName .. " " .. v:GetFullName() .. ">"
	elseif t == "table" then
		if d >= 2 then
			return "{...}"
		end
		local parts, n = {}, 0
		for k, x in pairs(v) do
			n = n + 1
			if n > 12 then
				table.insert(parts, "...")
				break
			end
			table.insert(parts, "[" .. ser(k, d + 1) .. "]=" .. ser(x, d + 1))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end

local function record(kind, name, ...)
	local args = table.pack(...)
	local parts = {}
	for i = 1, args.n do
		parts[i] = ser(args[i])
	end
	local line = ("net.%s(%s%s)"):format(kind, ser(name), #parts > 0 and (", " .. table.concat(parts, ", ")) or "")
	table.insert(logLines, line)
	if #logLines > 300 then
		table.remove(logLines, 1)
	end
	print("[YADSAN NetLog] " .. line)
end

local function capture(kind, name, ...)
	local now = os.clock()
	table.insert(rec.calls, { kind = kind, name = name, args = table.pack(...), dt = rec.last > 0 and (now - rec.last) or 0 })
	rec.last = now
end

local function hookNet()
	if logHooked then
		return true
	end
	if not net then
		return false
	end
	local origSend, origGet = net.send, net.get
	if type(origSend) ~= "function" or type(origGet) ~= "function" then
		return false
	end
	net.send = function(name, ...)
		if not replaying then
			if logOn then
				pcall(record, "send", name, ...)
			end
			if rec.on then
				pcall(capture, "send", name, ...)
			end
		end
		return origSend(name, ...)
	end
	net.get = function(name, ...)
		if not replaying then
			if logOn then
				pcall(record, "get", name, ...)
			end
			if rec.on then
				pcall(capture, "get", name, ...)
			end
		end
		return origGet(name, ...)
	end
	logHooked = true
	return true
end

logSec:Toggle({ Title = "Net Logger", Description = "Record the game's remote calls", Icon = "server", Callback = function(v)
	if v and not hookNet() then
		notify("Net Logger", "Game Net module not found.")
		logOn = false
		return
	end
	logOn = v
end })
logSec:Button({ Title = "Copy log", Style = "Primary", Callback = function()
	if #logLines == 0 then
		notify("Net Logger", "Log is empty.")
		return
	end
	if setclipboard then
		setclipboard(table.concat(logLines, "\n"))
		notify("Net Logger", #logLines .. " lines copied to clipboard.")
	else
		notify("Net Logger", "setclipboard not supported. Check console (F9).")
	end
end })
logSec:Button({ Title = "Clear log", Callback = function()
	logLines = {}
	notify("Net Logger", "Log cleared.")
end })
logSec:Button({ Title = "Copy fit report", Callback = function()
	if #copyReport == 0 then
		notify("Fit report", "Run Copy Avatar first.")
		return
	end
	if setclipboard then
		setclipboard(table.concat(copyReport, "\n"))
		notify("Fit report", "Copied. Paste it to the developer if Copy Avatar fails.")
	else
		notify("Fit report", table.concat(copyReport, " | "))
	end
end })

do

------------------------------------------------------------------------
-- ACTION RECORDER
------------------------------------------------------------------------
local ACTION_FOLDER = "YADSAN_HUB"
local ACTION_FILE = ACTION_FOLDER .. "/actions.json"
local actions, actionOrder = {}, {}

local myActs = Home:Section({ Title = "My Actions", Icon = "star", Side = "Right" })
myActs:Label("Record in the Exploits tab to create buttons here.")

local function enc(v)
	local t = typeof(v)
	if t == "string" or t == "number" or t == "boolean" then
		return v
	elseif t == "nil" then
		return { __t = "N" }
	elseif t == "Vector3" then
		return { __t = "V3", x = v.X, y = v.Y, z = v.Z }
	elseif t == "CFrame" then
		return { __t = "CF", c = { v:GetComponents() } }
	elseif t == "Color3" then
		return { __t = "C3", r = v.R, g = v.G, b = v.B }
	elseif t == "EnumItem" then
		return { __t = "E", s = tostring(v) }
	elseif t == "Instance" then
		return { __t = "I", p = v:GetFullName() }
	elseif t == "table" then
		local list = {}
		for k, x in pairs(v) do
			local ek, ex = enc(k), enc(x)
			if ek == nil or ex == nil then
				return nil
			end
			table.insert(list, { ek, ex })
		end
		return { __t = "T", p = list }
	end
	return nil
end

local function resolvePath(path)
	local cur = game
	for part in string.gmatch(path, "[^%.]+") do
		cur = cur and cur:FindFirstChild(part)
	end
	return cur
end

local function dec(v)
	if type(v) ~= "table" then
		return v
	end
	local t = v.__t
	if t == "N" then
		return nil
	elseif t == "V3" then
		return Vector3.new(v.x, v.y, v.z)
	elseif t == "CF" then
		return CFrame.new(table.unpack(v.c))
	elseif t == "C3" then
		return Color3.new(v.r, v.g, v.b)
	elseif t == "E" then
		local _, b, c = string.match(v.s, "^(%w+)%.(%w+)%.(%w+)$")
		if b then
			local ok, e = pcall(function()
				return Enum[b][c]
			end)
			if ok then
				return e
			end
		end
		return nil
	elseif t == "I" then
		return resolvePath(v.p)
	elseif t == "T" then
		local out = {}
		for _, pr in ipairs(v.p) do
			local k = dec(pr[1])
			if k ~= nil then
				out[k] = dec(pr[2])
			end
		end
		return out
	end
	return v
end

local function buildJson(name, calls)
	local jc = {}
	for _, c in ipairs(calls) do
		local ja = {}
		for i = 1, c.args.n do
			local e = enc(c.args[i])
			if e == nil then
				return nil
			end
			ja[i] = e
		end
		table.insert(jc, { k = c.kind, n = c.name, a = ja, an = c.args.n, d = c.dt })
	end
	return { name = name, calls = jc }
end

local function saveActions()
	if not (writefile and makefolder) then
		return
	end
	local list = {}
	for _, name in ipairs(actionOrder) do
		local a = actions[name]
		if a and a.json then
			table.insert(list, a.json)
		end
	end
	pcall(makefolder, ACTION_FOLDER)
	pcall(writefile, ACTION_FILE, HttpService:JSONEncode(list))
end

local function replay(a)
	if not net then
		notify("Action", "Game Net module not found.")
		return
	end
	task.spawn(function()
		replaying = true
		for _, c in ipairs(a.calls) do
			task.wait(math.min(c.dt or 0, 0.5))
			local f = (c.kind == "get") and net.get or net.send
			local ok, err = pcall(f, c.name, table.unpack(c.args, 1, c.args.n))
			if not ok then
				notify("Action failed", tostring(err))
				break
			end
		end
		replaying = false
	end)
end

local function addAction(name, calls, json)
	local isNew = actions[name] == nil
	actions[name] = { calls = calls, json = json }
	if isNew then
		table.insert(actionOrder, name)
		myActs:Button({ Title = name, Callback = function()
			local a = actions[name]
			if a then
				replay(a)
			else
				notify("Action", "This action has been deleted.")
			end
		end })
	end
end

local function loadActions()
	if not (readfile and isfile and isfile(ACTION_FILE)) then
		return
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(ACTION_FILE))
	end)
	if not ok or type(data) ~= "table" then
		return
	end
	for _, j in ipairs(data) do
		local calls = {}
		for _, c in ipairs(j.calls) do
			local args = { n = c.an }
			for i = 1, c.an do
				args[i] = dec(c.a[i])
			end
			table.insert(calls, { kind = c.k, name = c.n, args = args, dt = c.d })
		end
		addAction(j.name, calls, j)
	end
end

local recSec = Dev:Section({ Title = "Action Recorder", Icon = "star", Side = "Left" })
recSec:Paragraph({
	Title = "Turn a game action into a hub button",
	Content = "1) Type an action name (e.g. Lock Home).\n2) Turn Record ON.\n3) Use the game's own button once for that action.\n4) Turn Record OFF. A button appears in Home tab's My Actions.",
})
local actName = recSec:Input({ Placeholder = "Action name (e.g. Lock Home)" })
local recToggle
recToggle = recSec:Toggle({ Title = "Record action", Description = "Turn ON, then press the game button", Icon = "game", Callback = function(v)
	if v then
		if not hookNet() then
			notify("Recorder", "Game Net module not found.")
			recToggle:Set(false, true)
			return
		end
		rec.calls, rec.last, rec.on = {}, 0, true
		notify("Recording", "Press the game button now, then turn Record OFF.")
		return
	end
	rec.on = false
	local n = #rec.calls
	if n == 0 then
		notify("Recorder", "No calls recorded. Maybe this action doesn't use a server call.")
		return
	end
	local name = actName:Get()
	if name == "" then
		name = "Action " .. (#actionOrder + 1)
	end
	local json = buildJson(name, rec.calls)
	addAction(name, rec.calls, json)
	saveActions()
	local names = {}
	for i = 1, math.min(n, 5) do
		names[#names + 1] = tostring(rec.calls[i].name)
	end
	notify("Saved: " .. name, n .. " call(s): " .. table.concat(names, ", ") .. (json and "" or "  (session only)"))
end })
recSec:Label("Tip: If more than 1-2 calls appear, background calls were captured too. Re-record by pressing the button and turning OFF quickly.")

loadActions()
end

------------------------------------------------------------------------
-- COMMANDS  (everything here only affects YOUR character / client)
------------------------------------------------------------------------
local Commands = Window:CreateTab({ Name = "Commands", Icon = "terminal" })

local function findPlayer(q)
	q = tostring(q or ""):lower()
	if q == "" then
		return nil
	end
	if q == "me" then
		return lp
	end
	local part
	for _, p in ipairs(Players:GetPlayers()) do
		local n, d = p.Name:lower(), p.DisplayName:lower()
		if n == q or d == q then
			return p
		end
		if not part and (n:sub(1, #q) == q or d:sub(1, #q) == q) then
			part = p
		end
	end
	if part then
		return part
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():find(q, 1, true) or p.DisplayName:lower():find(q, 1, true) then
			return p
		end
	end
	return nil
end

local cmdOut
local CMD, CMD_ORDER = {}, {}
local function defCmd(name, usage, desc, fn)
	CMD[name] = { usage = usage, desc = desc, fn = fn }
	table.insert(CMD_ORDER, name)
end
local function alias(a, name)
	CMD[a] = CMD[name]
end

local spinConn
local clickTpTool

defCmd("fly", "fly [speed]", "Toggle flying", function(a)
	if tonumber(a[1]) then
		flySpeed = tonumber(a[1])
	end
	tiles["Fly"]:Set(true)
	return "Fly on"
end)
defCmd("unfly", "unfly", "Stop flying", function() tiles["Fly"]:Set(false) return "Fly off" end)
defCmd("noclip", "noclip", "Walk through walls", function() tiles["Noclip"]:Set(true) return "Noclip on" end)
defCmd("clip", "clip", "Turn noclip off", function() tiles["Noclip"]:Set(false) return "Noclip off" end)
defCmd("infjump", "infjump", "Infinite jump on", function() tiles["Infinite Jump"]:Set(true) return "Infinite jump on" end)
defCmd("uninfjump", "uninfjump", "Infinite jump off", function() tiles["Infinite Jump"]:Set(false) return "Infinite jump off" end)
defCmd("night", "night", "Night vision on", function() tiles["Night Vision"]:Set(true) return "Night vision on" end)
defCmd("unnight", "unnight", "Night vision off", function() tiles["Night Vision"]:Set(false) return "Night vision off" end)
defCmd("fps", "fps", "Toggle FPS boost", function() local t = tiles["FPS Boost"] t:Set(not t:Get()) return "FPS boost " .. (t:Get() and "on" or "off") end)
defCmd("antifling", "antifling", "Toggle anti fling", function() local t = tiles["Anti Fling"] t:Set(not t:Get()) return "Anti fling " .. (t:Get() and "on" or "off") end)
defCmd("speed", "speed <n>", "Set walk speed", function(a)
	local n = tonumber(a[1])
	if not n then return "Usage: speed <number>" end
	Window.Speed:Set(n)
	return "Speed " .. n
end)
defCmd("jump", "jump <n>", "Set jump power", function(a)
	local n = tonumber(a[1])
	if not n then return "Usage: jump <number>" end
	Window.Jump:Set(n)
	return "Jump " .. n
end)
defCmd("fov", "fov <n>", "Set field of view", function(a)
	local n = tonumber(a[1])
	if not n then return "Usage: fov <number>" end
	Window.FOV:Set(n)
	return "FOV " .. n
end)
defCmd("gravity", "gravity <n>", "Set gravity (196.2 = normal)", function(a)
	local n = tonumber(a[1])
	if not n then return "Usage: gravity <number>" end
	workspace.Gravity = n
	return "Gravity " .. n
end)
defCmd("time", "time <0-24>", "Set time of day", function(a)
	local n = tonumber(a[1])
	if not n then return "Usage: time <0-24>" end
	Lighting.ClockTime = n
	return "Time " .. n
end)
defCmd("esp", "esp", "Player ESP on", function() espToggle:Set(true) return "ESP on" end)
defCmd("unesp", "unesp", "Player ESP off", function() espToggle:Set(false) return "ESP off" end)
defCmd("goto", "goto <player>", "Teleport next to a player", function(a)
	local p = findPlayer(a[1])
	local tr = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	local r = getRoot()
	if not (tr and r) then return "Player not found" end
	r.CFrame = tr.CFrame * CFrame.new(0, 0, 3)
	return "Teleported to " .. p.DisplayName
end)
defCmd("view", "view <player>", "Spectate a player", function(a)
	local p = findPlayer(a[1])
	local th = p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if not th then return "Player not found" end
	workspace.CurrentCamera.CameraSubject = th
	return "Viewing " .. p.DisplayName
end)
defCmd("unview", "unview", "Stop spectating", function()
	local h = getHum()
	if h then workspace.CurrentCamera.CameraSubject = h end
	return "Camera back to you"
end)
defCmd("copy", "copy <player>", "Copy a player's outfit (Fit Copier)", function(a)
	local p = findPlayer(a[1])
	if not p then return "Player not found" end
	task.spawn(function()
		local ok, d = copyAvatar(p)
		notify(ok and "Copy Avatar" or "Copy Avatar failed", ok and ("Copied " .. p.DisplayName .. ": " .. tostring(d)) or tostring(d))
	end)
	return "Copying " .. p.DisplayName .. "..."
end)
defCmd("sync", "sync <player>", "Mirror a player's animations", function(a)
	local p = findPlayer(a[1])
	if not p then return "Player not found" end
	target = p
	act["Sync Anim"]:Set(true)
	return "Syncing with " .. p.DisplayName
end)
defCmd("unsync", "unsync", "Stop animation sync", function() act["Sync Anim"]:Set(false) return "Sync stopped" end)
defCmd("size", "size <n>", "Set body scale (0.1 - 10000)", function(a)
	local n = tonumber(a[1])
	if not n then return "Usage: size <number>" end
	n = math.clamp(n, 0.1, 10000)
	local ok, e = applySize(n, autoW(n), autoHead(n))
	return ok and ("Size " .. n) or tostring(e)
end)
defCmd("resetsize", "resetsize", "Back to normal size", function() local ok, e = applySize(1, 1, 1) return ok and "Size reset" or tostring(e) end)
defCmd("sit", "sit", "Sit down", function() local h = getHum() if h then h.Sit = true end return "Sat down" end)
defCmd("reset", "reset", "Respawn your character", function() local h = getHum() if h then h.Health = 0 end return "Resetting..." end)
defCmd("spin", "spin [speed]", "Spin your character", function(a)
	if spinConn then spinConn:Disconnect() end
	local sp = tonumber(a[1]) or 10
	spinConn = RunService.Heartbeat:Connect(function()
		local r = getRoot()
		if r then r.CFrame = r.CFrame * CFrame.Angles(0, math.rad(sp), 0) end
	end)
	return "Spinning"
end)
defCmd("unspin", "unspin", "Stop spinning", function() if spinConn then spinConn:Disconnect() spinConn = nil end return "Stopped" end)
defCmd("clicktp", "clicktp", "Get a tool: click to teleport", function()
	if clickTpTool and clickTpTool.Parent then return "You already have it" end
	clickTpTool = Instance.new("Tool")
	clickTpTool.Name = "Click TP"
	clickTpTool.RequiresHandle = false
	clickTpTool.Parent = lp:FindFirstChildOfClass("Backpack")
	clickTpTool.Activated:Connect(function()
		local m = lp:GetMouse()
		local r = getRoot()
		if r and m.Hit then r.CFrame = CFrame.new(m.Hit.Position + Vector3.new(0, 3, 0)) end
	end)
	return "Click TP tool added to your backpack"
end)
defCmd("rejoin", "rejoin", "Rejoin this server", function()
	pcall(function()
		if #Players:GetPlayers() <= 1 then
			lp:Kick("\nRejoining...")
			task.wait()
			game:GetService("TeleportService"):Teleport(game.PlaceId, lp)
		else
			game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, lp)
		end
	end)
	return "Rejoining..."
end)
defCmd("cmds", "cmds", "List all commands", function()
	local t = {}
	for _, n in ipairs(CMD_ORDER) do t[#t + 1] = CMD[n].usage end
	return table.concat(t, ", ")
end)
-- ===== extra commands (names follow Novoline's list; self/client only) =====
local wps = {}
local afkConn2
local loops = {}
local function loopProp(name, setter)
	if loops[name] then loops[name]:Disconnect() end
	loops[name] = RunService.Heartbeat:Connect(setter)
end
local function stopLoopProp(name)
	if loops[name] then loops[name]:Disconnect() loops[name] = nil end
end
local function num(a, usage)
	local n = tonumber(a[1])
	if not n then error("Usage: " .. usage, 0) end
	return n
end

defCmd("antiafk", "antiafk", "Prevent AFK kick", function()
	if afkConn2 then afkConn2:Disconnect() end
	afkConn2 = lp.Idled:Connect(function()
		pcall(function()
			local vu = game:GetService("VirtualUser")
			vu:CaptureController()
			vu:ClickButton2(Vector2.new())
		end)
	end)
	return "Anti-AFK on"
end)
defCmd("unantiafk", "unantiafk", "Disable anti-AFK", function() if afkConn2 then afkConn2:Disconnect() afkConn2 = nil end return "Anti-AFK off" end)
defCmd("brightness", "brightness <n>", "Set lighting brightness", function(a) Lighting.Brightness = num(a, "brightness <n>") return "Brightness set" end)
defCmd("loopbrightness", "loopbrightness <n>", "Lock lighting brightness", function(a)
	local n = num(a, "loopbrightness <n>")
	loopProp("bright", function() Lighting.Brightness = n end)
	return "Brightness locked"
end)
defCmd("unloopbrightness", "unloopbrightness", "Unlock brightness", function() stopLoopProp("bright") return "Unlocked" end)
defCmd("fullbright", "fullbright", "Maximize lighting", function()
	Lighting.Brightness = 2
	Lighting.ClockTime = 14
	Lighting.FogEnd = 1e6
	Lighting.GlobalShadows = false
	Lighting.Ambient = Color3.fromRGB(200, 200, 200)
	Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
	return "Fullbright"
end)
defCmd("nofog", "nofog", "Remove fog", function()
	Lighting.FogEnd = 1e6
	for _, e in ipairs(Lighting:GetChildren()) do
		if e:IsA("Atmosphere") then e.Density = 0 end
	end
	return "Fog removed"
end)
defCmd("loopnofog", "loopnofog", "Keep fog removed", function()
	loopProp("fog", function() Lighting.FogEnd = 1e6 end)
	return "Fog locked off"
end)
defCmd("unloopnofog", "unloopnofog", "Stop keeping fog off", function() stopLoopProp("fog") return "Done" end)
defCmd("loopnoeffect", "loopnoeffect", "Keep post effects disabled", function()
	loopProp("fx", function()
		for _, e in ipairs(Lighting:GetChildren()) do
			if e:IsA("PostEffect") then e.Enabled = false end
		end
	end)
	return "Effects locked off"
end)
defCmd("unloopnoeffect", "unloopnoeffect", "Stop keeping effects off", function() stopLoopProp("fx") return "Done" end)
defCmd("nogravity", "nogravity", "Float (zero gravity)", function() workspace.Gravity = 0 return "Gravity 0" end)
defCmd("hipheight", "hipheight <n>", "Set hip height", function(a)
	local h = getHum()
	if h then h.HipHeight = num(a, "hipheight <n>") end
	return "Hip height set"
end)
defCmd("loopws", "loopws <n>", "Lock walkspeed", function(a)
	local n = num(a, "loopws <n>")
	loopProp("ws", function() local h = getHum() if h then h.WalkSpeed = n end end)
	return "Walkspeed locked " .. n
end)
defCmd("unloopws", "unloopws", "Unlock walkspeed", function() stopLoopProp("ws") return "Unlocked" end)
defCmd("loopjp", "loopjp <n>", "Lock jump power", function(a)
	local n = num(a, "loopjp <n>")
	loopProp("jp", function()
		local h = getHum()
		if h then
			if h.UseJumpPower then h.JumpPower = n else h.JumpHeight = n end
		end
	end)
	return "Jump locked " .. n
end)
defCmd("unloopjp", "unloopjp", "Unlock jump", function() stopLoopProp("jp") return "Unlocked" end)
defCmd("maxzoom", "maxzoom <n>", "Set max camera zoom", function(a) lp.CameraMaxZoomDistance = num(a, "maxzoom <n>") return "Max zoom set" end)
defCmd("freeze", "freeze", "Anchor your character (client)", function()
	local c = lp.Character
	if c then for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = true end end end
	return "Frozen"
end)
defCmd("unfreeze", "unfreeze", "Unanchor your character", function()
	local c = lp.Character
	if c then for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = false end end end
	return "Unfrozen"
end)
defCmd("airwalk", "airwalk", "Walk on air", function()
	local plat
	loopProp("air", function()
		local r = getRoot()
		if not r then return end
		if not plat then
			plat = Instance.new("Part")
			plat.Size = Vector3.new(8, 1, 8)
			plat.Anchored = true
			plat.Transparency = 1
			plat.Parent = workspace
			loops.airPlat = plat
		end
		local y = r.Position.Y - 3.5
		if UIS:IsKeyDown(Enum.KeyCode.Space) then plat.CFrame = CFrame.new(r.Position.X, y + 1, r.Position.Z) else plat.CFrame = CFrame.new(r.Position.X, y, r.Position.Z) end
	end)
	return "Airwalk on"
end)
defCmd("unairwalk", "unairwalk", "Disable airwalk", function()
	stopLoopProp("air")
	if loops.airPlat then loops.airPlat:Destroy() loops.airPlat = nil end
	return "Airwalk off"
end)
local function antiSit(v)
	local h = getHum()
	if h then h:SetStateEnabled(Enum.HumanoidStateType.Seated, not v) end
end
defCmd("antisit", "antisit", "Prevent being sat in a seat", function() antiSit(true) return "Anti-sit on" end)
defCmd("disablesit", "disablesit", "Prevent sitting", function() antiSit(true) return "Sitting disabled" end)
defCmd("enablesit", "enablesit", "Re-enable sitting", function() antiSit(false) return "Sitting enabled" end)
defCmd("unequiptools", "unequiptools", "Unequip held tools", function() local h = getHum() if h then h:UnequipTools() end return "Done" end)
defCmd("ping", "ping", "Show your ping", function() return math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) .. " ms" end)
defCmd("copyuser", "copyuser <player>", "Copy a player's username", function(a)
	local p = findPlayer(a[1])
	if not p then return "Player not found" end
	if setclipboard then setclipboard(p.Name) end
	return "Copied " .. p.Name
end)
defCmd("join", "join <jobId>", "Join a server by Job ID", function(a)
	if not a[1] then return "Usage: join <jobId>" end
	game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, a[1], lp)
	return "Joining..."
end)
defCmd("setwaypoint", "setwaypoint <name>", "Save your position", function(a)
	local r = getRoot()
	if not (r and a[1]) then return "Usage: setwaypoint <name>" end
	wps[a[1]:lower()] = r.CFrame
	return "Saved " .. a[1]
end)
defCmd("gotowaypoint", "gotowaypoint <name>", "Teleport to a waypoint", function(a)
	local r, cf = getRoot(), a[1] and wps[a[1]:lower()]
	if not (r and cf) then return "Waypoint not found" end
	r.CFrame = cf
	return "Teleported"
end)
defCmd("deletewaypoint", "deletewaypoint <name>", "Delete a waypoint", function(a) if a[1] then wps[a[1]:lower()] = nil end return "Deleted" end)
defCmd("waypoints", "waypoints", "List waypoints", function()
	local t = {}
	for k in pairs(wps) do t[#t + 1] = k end
	return #t == 0 and "No waypoints" or table.concat(t, ", ")
end)
defCmd("volume", "volume <0-10>", "Set master volume", function(a)
	pcall(function() UserSettings():GetService("UserGameSettings").MasterVolume = num(a, "volume <0-10>") / 10 end)
	return "Volume set"
end)
local xrayParts = {}
defCmd("xray", "xray", "See through walls (client)", function()
	for _, o in ipairs(workspace:GetDescendants()) do
		if o:IsA("BasePart") and not (lp.Character and o:IsDescendantOf(lp.Character)) and not o.Parent:FindFirstChildOfClass("Humanoid") and o.Transparency < 0.5 then
			xrayParts[o] = o.Transparency
			o.LocalTransparencyModifier = 0.6
		end
	end
	return "X-ray on"
end)
defCmd("unxray", "unxray", "Disable x-ray", function()
	for o in pairs(xrayParts) do pcall(function() o.LocalTransparencyModifier = 0 end) end
	xrayParts = {}
	return "X-ray off"
end)
defCmd("iy", "iy", "Load Infinite Yield", function()
	task.spawn(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))() end)
	return "Loading Infinite Yield..."
end)
alias("unnoclip", "clip")
alias("lockws", "loopws")

-- ===== freecam + local hide (client only) =====
local fc = { on = false, speed = 50, yaw = 0, pitch = 0, conns = {} }
local function fcStop()
	if not fc.on then return end
	fc.on = false
	for _, c in ipairs(fc.conns) do c:Disconnect() end
	fc.conns = {}
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	local h, r = getHum(), getRoot()
	if h then cam.CameraSubject = h end
	if r then r.Anchored = false end
end
local function fcStart()
	if fc.on then return end
	local cam, r = workspace.CurrentCamera, getRoot()
	if not r then error("Character not found", 0) end
	fc.on = true
	local look = cam.CFrame.LookVector
	fc.yaw, fc.pitch = math.atan2(-look.X, -look.Z), math.asin(look.Y)
	local pos = cam.CFrame.Position
	cam.CameraType = Enum.CameraType.Scriptable
	r.Anchored = true
	local rmb = false
	table.insert(fc.conns, UIS.InputBegan:Connect(function(i, gp)
		if i.UserInputType == Enum.UserInputType.MouseButton2 then rmb = true end
	end))
	table.insert(fc.conns, UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton2 then rmb = false end
	end))
	table.insert(fc.conns, UIS.InputChanged:Connect(function(i, gp)
		local d
		if i.UserInputType == Enum.UserInputType.MouseMovement and rmb then d = i.Delta
		elseif i.UserInputType == Enum.UserInputType.Touch and not gp then d = i.Delta end
		if d then
			fc.yaw = fc.yaw - d.X * 0.004
			fc.pitch = math.clamp(fc.pitch - d.Y * 0.004, -1.5, 1.5)
		end
	end))
	table.insert(fc.conns, RunService.RenderStepped:Connect(function(dt)
		local rot = CFrame.Angles(0, fc.yaw, 0) * CFrame.Angles(fc.pitch, 0, 0)
		local move = Vector3.zero
		local h = getHum()
		if h then
			local md = h.MoveDirection
			if md.Magnitude > 0 then
				local flat = CFrame.Angles(0, fc.yaw, 0)
				local c = workspace.CurrentCamera.CFrame
				move = flat:VectorToWorldSpace(Vector3.new(md:Dot(c.RightVector), 0, -md:Dot(Vector3.new(c.LookVector.X, 0, c.LookVector.Z).Unit))) 
			end
		end
		if UIS:IsKeyDown(Enum.KeyCode.W) then move = move + rot.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.S) then move = move - rot.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.D) then move = move + rot.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.A) then move = move - rot.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.E) or UIS:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.yAxis end
		if UIS:IsKeyDown(Enum.KeyCode.Q) or UIS:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.yAxis end
		pos = pos + move * fc.speed * dt
		workspace.CurrentCamera.CFrame = CFrame.new(pos) * rot
	end))
	fc.setPos = function(p) pos = p end
end
defCmd("freecam", "freecam", "Free camera (WASD/QE, right-drag or touch-drag to look)", function() fcStart() return "Freecam on" end)
defCmd("unfreecam", "unfreecam", "Exit freecam", function() fcStop() return "Freecam off" end)
defCmd("fcspeed", "fcspeed <n>", "Freecam speed", function(a) fc.speed = num(a, "fcspeed <n>") return "Freecam speed " .. fc.speed end)
defCmd("fcgoto", "fcgoto <player>", "Move freecam to a player", function(a)
	local p = findPlayer(a[1])
	local tr = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not tr then return "Player not found" end
	if not fc.on then fcStart() end
	fc.setPos(tr.Position + Vector3.new(0, 4, 8))
	return "Freecam at " .. p.DisplayName
end)
local hiddenLoop = {}
defCmd("hide", "hide <player>", "Hide a player on your screen only", function(a)
	local p = findPlayer(a[1])
	if not p then return "Player not found" end
	hiddenLoop[p] = true
	return "Hiding " .. p.DisplayName .. " (only you)"
end)
alias("loopdelete", "hide")
defCmd("unhide", "unhide <player>", "Show a hidden player again", function(a)
	local p = findPlayer(a[1])
	if not p then return "Player not found" end
	hiddenLoop[p] = nil
	if p.Character then
		for _, o in ipairs(p.Character:GetDescendants()) do
			if o:IsA("BasePart") then o.LocalTransparencyModifier = 0 end
		end
	end
	return "Showing " .. p.DisplayName
end)
RunService.RenderStepped:Connect(function()
	for p in pairs(hiddenLoop) do
		if p.Parent and p.Character then
			for _, o in ipairs(p.Character:GetDescendants()) do
				if o:IsA("BasePart") then o.LocalTransparencyModifier = 1 end
			end
		else
			hiddenLoop[p] = nil
		end
	end
end)

alias("tp", "goto")
alias("spectate", "view")
alias("walkspeed", "speed")
alias("ws", "speed")
alias("jp", "jump")
alias("respawn", "reset")
alias("fit", "copy")

function runCommand(line)
	line = tostring(line or ""):gsub("^%s*[;/!:]?%s*", "")
	if line == "" then return end
	local args = {}
	for w in line:gmatch("%S+") do args[#args + 1] = w end
	local name = table.remove(args, 1):lower()
	local c = CMD[name]
	local msg
	if not c then
		msg = "Unknown command: " .. name .. "  (try: cmds)"
	else
		local ok, r = pcall(c.fn, args)
		msg = ok and tostring(r or "Done") or ("Error: " .. tostring(r))
	end
	if cmdOut then cmdOut:Set(msg) end
	notify("Command", msg)
end

local runSec = Commands:Section({ Title = "Command bar", Icon = "terminal", Side = "Left" })
local cmdInput = runSec:Input({ Placeholder = "e.g. speed 80, goto name, fly", OnBlur = false, Callback = function(t)
	runCommand(t)
end })
runSec:Button({ Title = "Run", Style = "Primary", Callback = function()
	runCommand(cmdInput:Get())
end })
cmdOut = runSec:Label("Result shows here.")
runSec:Actions({
	{ Title = "Reset", Description = "Respawn", Icon = "refresh", Callback = function() runCommand("reset") end },
	{ Title = "Sit", Description = "Sit down", Icon = "stand", Callback = function() runCommand("sit") end },
	{ Title = "Click TP", Description = "Get tool", Icon = "mouse", Callback = function() runCommand("clicktp") end },
	{ Title = "Rejoin", Description = "Same server", Icon = "door", Callback = function() runCommand("rejoin") end },
})

local listSecC = Commands:Section({ Title = "All commands", Icon = "list", Side = "Right" })
local lines = {}
for _, n in ipairs(CMD_ORDER) do
	lines[#lines + 1] = CMD[n].usage .. "  -  " .. CMD[n].desc
end
listSecC:Paragraph({ Title = "Type in the bar, press Enter", Content = table.concat(lines, "\n") })
listSecC:Label("Player names can be partial (e.g. 'man' finds 'Manas'). 'me' means you.")

;(function()
------------------------------------------------------------------------
-- FIT SAVER: every fit is its own file  YADSAN_HUB/fits/<name>.json  in your executor workspace
-- file = { name, file, saved, by, from, count, codes = {asset ids}, items = {{id,type,kind}}, skin = {r,g,b}, scale = {h,w,head} }
------------------------------------------------------------------------
local FIT_DIR = "YADSAN_HUB/fits"
local FitStore = { fits = {}, listeners = {} }
do
	local function mkdirs()
		pcall(function()
			if makefolder then
				pcall(makefolder, "YADSAN_HUB")
				pcall(makefolder, FIT_DIR)
			end
		end)
	end
	local function fileSafe(name)
		local s = tostring(name):gsub("[^%w%-_ ]", ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", "_")
		if s == "" then
			s = "fit"
		end
		return s:sub(1, 40)
	end
	local function fire()
		for _, f in ipairs(FitStore.listeners) do
			pcall(f)
		end
	end
	function FitStore.onChange(f)
		FitStore.listeners[#FitStore.listeners + 1] = f
	end
	function FitStore.names()
		local n = {}
		for k in pairs(FitStore.fits) do
			n[#n + 1] = k
		end
		table.sort(n, function(a, b)
			return (FitStore.fits[a].saved or 0) > (FitStore.fits[b].saved or 0)
		end)
		return n
	end
	function FitStore.get(name)
		return FitStore.fits[name]
	end
	local function write(data)
		mkdirs()
		local ok, err = pcall(function()
			writefile(FIT_DIR .. "/" .. data.file .. ".json", HttpService:JSONEncode(data))
		end)
		return ok, err
	end
	function FitStore.save(name, desc, byName, fromName, char)
		name = tostring(name):gsub("^%s+", ""):gsub("%s+$", ""):sub(1, 28)
		if name == "" then
			name = "Fit " .. os.date("%H:%M:%S")
		end
		local items = captureItems(desc)
		if #items == 0 then
			return false, "No items found on that avatar"
		end
		local codes = {}
		for i, it in ipairs(items) do
			codes[i] = it.id
		end
		local sk = captureSkin(desc, char or lp.Character)
		local data = {
			name = name, file = fileSafe(name), saved = os.time(), by = byName, from = fromName or byName,
			count = #items, codes = codes, items = items, skin = sk,
			scale = captureScale(desc),
		}
		local old = FitStore.fits[name]
		FitStore.fits[name] = data
		local ok, err = write(data)
		fire()
		if not ok then
			return true, ("Saved in memory (file write failed: %s)"):format(tostring(err)), data
		end
		if name ~= "_previous_fit" then NovaUI.Stat("saves") end
		return true, (old and "Overwrote " or "Saved ") .. name .. " -> " .. FIT_DIR .. "/" .. data.file .. ".json", data
	end
	function FitStore.delete(name)
		local d = FitStore.fits[name]
		if not d then
			return false
		end
		FitStore.fits[name] = nil
		pcall(function()
			if delfile then
				delfile(FIT_DIR .. "/" .. d.file .. ".json")
			end
		end)
		fire()
		return true
	end
	function FitStore.wear(name, onProgress)
		local d = FitStore.fits[name]
		if not d then
			return false, "Fit not found"
		end
		return wearItems(d.items, d.skin, "saved:" .. name, onProgress, { scale = d.scale })
	end
	function FitStore.copyIds(name)
		local d = FitStore.fits[name]
		if d and setclipboard then
			local t = {}
			for _, c in ipairs(d.codes) do
				t[#t + 1] = ("%.0f"):format(c)
			end
			pcall(setclipboard, table.concat(t, ", "))
			return true
		end
		return false
	end
	NovaUI.beforeWear = function()
		local h = getHum()
		local d = h and h:GetAppliedDescription()
		if d then pcall(FitStore.save, "_previous_fit", d, lp.Name, lp.Name, lp.Character) end
	end
	function FitStore.saveMine()
		local h = getHum()
		local d = h and h:GetAppliedDescription()
		return d
	end

	-- load existing files (+ migrate the old single fits.json once)
	mkdirs()
	pcall(function()
		if listfiles then
			for _, path in ipairs(listfiles(FIT_DIR)) do
				if tostring(path):lower():match("%.json$") then
					local ok, data = pcall(function()
						return HttpService:JSONDecode(readfile(path))
					end)
					if ok and type(data) == "table" and data.name and type(data.items) == "table" then
						data.file = data.file or fileSafe(data.name)
						FitStore.fits[data.name] = data
					end
				end
			end
		end
	end)
	pcall(function()
		local OLD = "YADSAN_HUB/fits.json"
		if isfile and isfile(OLD) then
			local old = HttpService:JSONDecode(readfile(OLD))
			for name, d in pairs(old) do
				if type(d) == "table" and not FitStore.fits[name] then
					local items = {}
					for _, a in ipairs(d.acc or {}) do
						local t = tostring(a.AccessoryType or "Hat")
						if not t:find("Accessory") then
							t = t .. "Accessory"
						end
						items[#items + 1] = { id = a.AssetId, type = t, kind = "acc" }
					end
					local p = d.props or {}
					for _, c in ipairs({ { "Pants", "Pants" }, { "Shirt", "Shirt" }, { "GraphicTShirt", "TShirt" }, { "Face", "Face" } }) do
						if tonumber(p[c[1]]) and p[c[1]] ~= 0 then
							items[#items + 1] = { id = p[c[1]], type = c[2], kind = "cloth" }
						end
					end
					for _, k in ipairs(ANIM_PROPS) do
						if tonumber(p[k]) and p[k] ~= 0 then
							items[#items + 1] = { id = p[k], type = k, kind = "anim" }
						end
					end
					if #items > 0 then
						local codes = {}
						for i, it in ipairs(items) do
							codes[i] = it.id
						end
						local data = { name = name, file = fileSafe(name), saved = os.time(), by = "migrated", count = #items, codes = codes, items = items, skin = d.skin }
						FitStore.fits[name] = data
						write(data)
					end
				end
			end
			pcall(function()
				writefile("YADSAN_HUB/fits.json.migrated", readfile(OLD))
				if delfile then
					delfile(OLD)
				end
			end)
		end
	end)
end

-- hub (Avatar tab) UI
local fitSec = Avatar:Section({ Title = "Fit Saver", Icon = "save", Side = "Right" })
local fitName = fitSec:Input({ Placeholder = "Fit name" })
local fitRows = {}
local function fitNameOrDefault(prefix)
	local n = tostring(fitName:Get() or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if n == "" then
		n = prefix .. " " .. os.date("%H:%M:%S")
	end
	return n:sub(1, 28)
end
local function rebuildFitRows()
	for _, r in ipairs(fitRows) do
		pcall(function()
			r:Destroy()
		end)
	end
	fitRows = {}
	for _, name in ipairs(FitStore.names()) do
		local before = {}
		for _, c in ipairs(fitSec.Body:GetChildren()) do
			before[c] = true
		end
		fitSec:Actions({
			{ Title = name, Description = (FitStore.get(name).count or 0) .. " items - tap to wear", Icon = "shirt", Callback = function()
				task.spawn(function()
					notify("Fit Saver", "Wearing " .. name .. "...")
					local ok, d = FitStore.wear(name)
					notify(ok and "Fit worn" or "Fit failed", ok and (name .. ": " .. tostring(d)) or tostring(d))
				end)
			end },
			{ Title = "Delete", Description = name, Icon = "trash", Callback = function()
				FitStore.delete(name)
				notify("Fit Saver", "Deleted " .. name)
			end },
		})
		for _, c in ipairs(fitSec.Body:GetChildren()) do
			if c:IsA("GuiObject") and not before[c] then
				fitRows[#fitRows + 1] = c
			end
		end
	end
end
fitSec:Actions({
	{ Title = "Save my fit", Description = "Current outfit", Icon = "save", Callback = function()
		local d = FitStore.saveMine()
		if not d then notify("Fit Saver", "Character not loaded") return end
		local ok, msg = FitStore.save(fitNameOrDefault("My fit"), d, lp.Name)
		notify("Fit Saver", tostring(msg))
	end },
	{ Title = "Save selected", Description = "Their outfit", Icon = "userplus", Callback = function()
		local p = needTarget()
		local th = p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		local d = th and th:GetAppliedDescription()
		if not d then return end
		local ok, msg = FitStore.save(fitNameOrDefault(p.DisplayName), d, lp.Name, p.Name, p.Character)
		notify("Fit Saver", tostring(msg))
	end },
})
FitStore.onChange(rebuildFitRows)
rebuildFitRows()
------------------------------------------------------------------------
-- HUB CHAT: a messenger only for YADSAN HUB users (separate from the game's own Messages app).
-- Default relay: the free public ntfy.sh service (no setup). Optional: your own Firebase Realtime DB.
-- NOTE: the relay is public and has rate limits - do not share secrets here.
------------------------------------------------------------------------
local HubChat = { msgs = {}, listeners = {}, status = "starting", uiOpen = false, mode = "ntfy", scope = "g", presence = {} }
do
	local NTFY = "https://ntfy.sh/yadsanhub-lt-7f3a9c2e51d84b60a1"
	local CHAT_FILE = "YADSAN_HUB/chat_url.txt"
	local fbUrl = tostring(YADSAN_CHAT_SERVER or ""):gsub("%s+", ""):gsub("/+$", "")
	pcall(function()
		if fbUrl == "" and isfile and isfile(CHAT_FILE) then
			fbUrl = readfile(CHAT_FILE):gsub("%s+", ""):gsub("/+$", "")
		end
	end)
	if fbUrl ~= "" then
		HubChat.mode = "firebase"
	end
	local httpReq = (syn and syn.request) or http_request or request
	local seen, pending, lastId = {}, {}, nil
	local firstPoll, activeUntil, backoff = true, 0, 0
	local bucket, bucketT = 40, os.clock()

	local function clean(s, n)
		s = tostring(s or ""):gsub("%c", " "):gsub("^%s+", ""):gsub("%s+$", "")
		return s:sub(1, n)
	end
	local function fire()
		for _, f in ipairs(HubChat.listeners) do
			pcall(f, HubChat.msgs)
		end
	end
	function HubChat.onUpdate(f)
		HubChat.listeners[#HubChat.listeners + 1] = f
	end
	function HubChat.setUiOpen(v)
		HubChat.uiOpen = v and true or false
		if v then
			activeUntil = os.clock() + 60
		end
	end
	local function take(n)
		local now = os.clock()
		bucket = math.min(40, bucket + (now - bucketT) * 0.1)
		bucketT = now
		if bucket >= n then
			bucket = bucket - n
			return true
		end
		return false
	end
	local function request(opt)
		if httpReq then
			local ok, r = pcall(httpReq, opt)
			if ok and type(r) == "table" then
				return r.StatusCode or (r.Success and 200) or 0, r.Body or ""
			end
			return 0, tostring(r)
		end
		if opt.Method == "GET" then
			local ok, b = pcall(function()
				return game:HttpGet(opt.Url)
			end)
			return ok and 200 or 0, ok and b or tostring(b)
		end
		return 0, "no http function"
	end
	local function addMsg(e)
		table.insert(HubChat.msgs, e)
		table.sort(HubChat.msgs, function(a, b)
			return (a.t or 0) < (b.t or 0)
		end)
		while #HubChat.msgs > 80 do
			table.remove(HubChat.msgs, 1)
		end
	end

	-- hub profile (name + status) and friends list, saved in the executor folder
	local PROF_FILE, FR_FILE = "YADSAN_HUB/hub_profile.json", "YADSAN_HUB/friends.json"
	HubChat.me = { hn = "", st = "" }
	HubChat.staffMute = {}
	HubChat.fr = { friends = {}, incoming = {}, outgoing = {}, ctl = {} }
	pcall(function()
		if isfile and isfile(PROF_FILE) then
			local d = HttpService:JSONDecode(readfile(PROF_FILE))
			if type(d) == "table" then
				HubChat.me.hn = tostring(d.hn or ""):sub(1, 20)
				HubChat.me.st = tostring(d.st or ""):sub(1, 40)
			end
		end
		if isfile and isfile(FR_FILE) then
			local d = HttpService:JSONDecode(readfile(FR_FILE))
			if type(d) == "table" then
				for _, k in ipairs({ "friends", "incoming", "outgoing", "ctl" }) do
					if type(d[k]) == "table" then HubChat.fr[k] = d[k] end
				end
			end
		end
	end)
	local function saveJson(path, t)
		pcall(function()
			pcall(makefolder, "YADSAN_HUB")
			writefile(path, HttpService:JSONEncode(t))
		end)
	end
	function HubChat.myName()
		return (HubChat.me.hn ~= "") and HubChat.me.hn or lp.DisplayName
	end
	function HubChat.setProfile(hn, st)
		hn = tostring(hn or ""):gsub("[%c]", ""):gsub("^%s+", ""):gsub("%s+$", ""):sub(1, 20)
		HubChat.me.hn = hn
		HubChat.me.st = tostring(st or ""):gsub("[%c]", ""):sub(1, 40)
		saveJson(PROF_FILE, HubChat.me)
		pcall(function() HubChat.ping() end)
	end
	local function myLevel()
		local ok, lv = pcall(function() return NovaUI.Profile.level() end)
		return ok and tonumber(lv) or 1
	end
	local function fireFr()
		saveJson(FR_FILE, HubChat.fr)
		for _, f in ipairs(HubChat.listeners) do pcall(f) end
	end
	local function ingest(key, raw)
		local okd, m = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if not okd or type(m) ~= "table" then
			return
		end
		if type(m.n) ~= "string" or type(m.m) ~= "string" then
			return
		end
		local uid = (type(m.i) == "string" and m.i ~= "") and m.i or key
		if seen[uid] then
			return
		end
		seen[uid] = true
		local who = clean(m.n, 30)
		if who ~= lp.Name or m.c == "p" then
			HubChat.presence[who] = { d = clean(m.d or m.n, 30), u = tonumber(m.u), t = tonumber(m.t) or os.time(), s = tostring(m.s or ""), st = clean(m.st or "", 40), lv = tonumber(m.lv) or 1 }
		end
		if m.c == "p" then return end
		-- staff control messages (announcements / chat mute), only trusted when sent by the owner or an admin
		if m.c == "s" then
			local sf = HubChat.STAFF and HubChat.STAFF[who:lower()]
			if sf and sf.uid and tonumber(m.u) == sf.uid then
				if m.a == "mute" and type(m.to) == "string" then
					HubChat.staffMute[m.to] = true
					if m.to == lp.Name and not firstPoll then notify("Hub Chat", "Staff muted you in Hub Chat") end
				elseif m.a == "unm" and type(m.to) == "string" then
					HubChat.staffMute[m.to] = nil
				elseif m.a == "ann" then
					if not firstPoll and os.time() - (tonumber(m.t) or 0) < 300 then
						NovaUI.Sound("ping", 0.7)
						notify("ANNOUNCEMENT - " .. (sf.title or "STAFF"), clean(m.m, 200))
					end
					m.c = "g"
					m.m = "[ANNOUNCEMENT] " .. clean(m.m, 180)
				else
					return
				end
				if m.a ~= "ann" then return end
			else
				return
			end
		end
		if HubChat.staffMute[who] and not (HubChat.STAFF and HubChat.STAFF[who:lower()]) then return end
		if HubChat.fr.friends[who] then
			HubChat.fr.friends[who].d = clean(m.d or m.n, 30)
			HubChat.fr.friends[who].u = tonumber(m.u) or HubChat.fr.friends[who].u
		end
		if m.c == "f" then
			-- friend control message (request / accept / decline / remove) addressed to me
			if m.to == lp.Name and who ~= lp.Name then
				local ts = tonumber(m.t) or os.time()
				local fr = HubChat.fr
				if (fr.ctl[who] or 0) < ts then
					fr.ctl[who] = ts
					local info = { d = clean(m.d or m.n, 30), u = tonumber(m.u) }
					if m.a == "req" then
						if fr.friends[who] then
							HubChat.post({ c = "f", to = who, a = "acc", m = "." })
						else
							fr.incoming[who] = { d = info.d, u = info.u, t = ts }
							if not firstPoll then
								NovaUI.Sound("ping", 0.4)
								notify("Friend request", info.d .. " wants to be your friend (Hub Chat > Friends)")
							end
						end
					elseif m.a == "acc" then
						fr.friends[who] = info
						fr.incoming[who], fr.outgoing[who] = nil, nil
						if not firstPoll then notify("Friends", info.d .. " accepted your request") end
					elseif m.a == "dec" then
						fr.outgoing[who] = nil
					elseif m.a == "rem" then
						fr.friends[who] = nil
					end
					fireFr()
				end
			end
			return
		end
		if m.c == "d" and not (m.to == lp.Name or who == lp.Name) then return end
		local mine = m.n == lp.Name
		local e = { id = uid, n = clean(m.n, 30), d = clean(m.d or m.n, 30), m = clean(m.m, 200), t = tonumber(m.t) or os.time(), mine = mine, state = "ok", u = tonumber(m.u), c = (m.c == "l" or m.c == "d") and m.c or "g", s = tostring(m.s or ""), to = (m.c == "d") and tostring(m.to or "") or nil, st = clean(m.st or "", 40), lv = tonumber(m.lv) or 1 }
		if e.m == "" then
			return
		end
		local p = pending[uid]
		if p then
			p.state = "ok"
			p.t = e.t
			pending[uid] = nil
		else
			addMsg(e)
			if not firstPoll and not mine and HubChat.visible(e, "any") then
				activeUntil = os.clock() + 45
				local low = tostring(e.m):lower()
				if low:find("@" .. lp.Name:lower(), 1, true) or low:find("@" .. lp.DisplayName:lower(), 1, true) then
					NovaUI.Sound("ping", 0.5)
					notify("You were mentioned by " .. e.d, e.m)
				elseif not HubChat.uiOpen and not HubChat.muted then
					NovaUI.Sound("ping", 0.3)
					notify("Hub Chat - " .. e.d, e.m)
				end
			end
		end
	end
	local function poll()
		if not take(0.12) then
			return
		end
		if HubChat.mode == "ntfy" then
			local since = lastId or "3h"
			local code, body = request({ Url = NTFY .. "/json?poll=1&since=" .. since, Method = "GET" })
			if code == 429 then
				backoff = math.min(60, math.max(10, backoff * 2))
				HubChat.status = "rate limited, slowing down"
				return
			end
			if code ~= 200 then
				HubChat.status = "offline (" .. tostring(code) .. ")"
				backoff = math.min(30, backoff + 5)
				return
			end
			backoff = 0
			HubChat.status = "online"
			for line in tostring(body):gmatch("[^\r\n]+") do
				local ok, o = pcall(function()
					return HttpService:JSONDecode(line)
				end)
				if ok and type(o) == "table" and o.event == "message" and type(o.message) == "string" then
					lastId = o.id or lastId
					ingest(o.id, o.message)
				end
			end
		else
			local code, body = request({ Url = fbUrl .. '/yadsanchat.json?orderBy=%22$key%22&limitToLast=40', Method = "GET" })
			if code ~= 200 then
				HubChat.status = "offline (" .. tostring(code) .. ")"
				backoff = math.min(30, backoff + 5)
				return
			end
			backoff = 0
			HubChat.status = "online"
			local ok, data = pcall(function()
				return HttpService:JSONDecode(body)
			end)
			if ok and type(data) == "table" then
				local keys = {}
				for k in pairs(data) do
					keys[#keys + 1] = k
				end
				table.sort(keys)
				for _, k in ipairs(keys) do
					if type(data[k]) == "table" then
						ingest(k, HttpService:JSONEncode(data[k]))
					end
				end
			end
		end
		firstPoll = false
		fire()
	end
	-- chat history saved in the executor folder
	local HIST = "YADSAN_HUB/chat_history.json"
	local histT = 0
	pcall(function()
		if isfile and isfile(HIST) then
			local d = HttpService:JSONDecode(readfile(HIST))
			if type(d) == "table" then
				for _, m in ipairs(d) do
					if type(m) == "table" and type(m.n) == "string" and type(m.m) == "string" and type(m.id) == "string" then
						seen[m.id] = true
						table.insert(HubChat.msgs, { id = m.id, n = m.n, d = m.d or m.n, m = m.m, t = tonumber(m.t) or 0, mine = m.n == lp.Name, state = "ok", u = tonumber(m.u), c = (m.c == "l" or m.c == "d") and m.c or "g", s = tostring(m.s or ""), to = m.to, st = m.st, lv = tonumber(m.lv) or 1 })
					end
				end
			end
		end
	end)
	task.spawn(function()
		local lastN, lastId = -1, nil
		while true do
			task.wait(8)
			local n, l = #HubChat.msgs, HubChat.msgs[#HubChat.msgs]
			if n ~= lastN or (l and l.id) ~= lastId then
				lastN, lastId = n, l and l.id
				pcall(function()
					local out = {}
					for _, m in ipairs(HubChat.msgs) do
						if m.state == "ok" then out[#out + 1] = { id = m.id, n = m.n, d = m.d, m = m.m, t = m.t, u = m.u, c = m.c, s = m.s, to = m.to, st = m.st, lv = m.lv } end
					end
					pcall(makefolder, "YADSAN_HUB")
					writefile(HIST, HttpService:JSONEncode(out))
				end)
			end
		end
	end)
	local lastSend = 0
	function HubChat.send(text, scope, to)
		if HubChat.staffMute[lp.Name] then return false, "You are muted by staff" end
		scope = scope or HubChat.scope
		scope = (scope == "d" and to) and "d" or (scope == "l" and "l" or "g")
		text = clean(text, 200)
		if text == "" then
			return false, "empty"
		end
		if os.clock() - lastSend < 1.2 then
			return false, "Slow down a little"
		end
		if not httpReq then
			return false, "Your executor has no http request function"
		end
		if not take(3) then
			return false, "Too many messages, wait a bit"
		end
		lastSend = os.clock()
		activeUntil = os.clock() + 45
		local uid = HttpService:GenerateGUID(false)
		local e = { id = uid, n = lp.Name, d = HubChat.myName(), m = text, t = os.time(), mine = true, state = "sending", u = lp.UserId, c = scope, s = game.JobId, to = (scope == "d") and to or nil, st = HubChat.me.st, lv = myLevel() }
		pending[uid] = e
		addMsg(e)
		fire()
		NovaUI.Stat("msgs")
		task.spawn(function()
			local payload = HttpService:JSONEncode({ n = lp.Name, d = HubChat.myName(), t = os.time(), m = text, i = uid, u = lp.UserId, c = scope, s = game.JobId, to = e.to, st = HubChat.me.st, lv = e.lv })
			local code
			if HubChat.mode == "ntfy" then
				code = request({ Url = NTFY, Method = "POST", Headers = { ["Content-Type"] = "text/plain" }, Body = payload })
			else
				code = request({ Url = fbUrl .. "/yadsanchat.json", Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = payload })
			end
			if code ~= 200 then
				e.state = "failed"
				pending[uid] = nil
				seen[uid] = true
				fire()
			else
				task.delay(2, function()
					if pending[uid] then
						pending[uid].state = "ok"
						pending[uid] = nil
					end
					fire()
				end)
				task.defer(poll)
			end
		end)
		return true
	end
	-- scope "g" = global chat, "l" = this server only, "any" = anything this client may see
	function HubChat.visible(m, scope)
		scope = scope or HubChat.scope
		if m.c == "d" then return scope == "any" end
		local isLocal = m.c == "l"
		if isLocal and m.s ~= game.JobId then return false end
		if scope == "l" then return isLocal end
		if scope == "g" then return not isLocal end
		return true
	end
	function HubChat.list(scope)
		local out = {}
		for _, m in ipairs(HubChat.msgs) do
			if HubChat.visible(m, scope) then out[#out + 1] = m end
		end
		return out
	end
	-- tiny "I'm online" ping (not shown as a message): used for the staff user list
	function HubChat.ping()
		if not httpReq or not take(2) then return end
		local payload = HttpService:JSONEncode({ n = lp.Name, d = HubChat.myName(), t = os.time(), m = ".", i = HttpService:GenerateGUID(false), u = lp.UserId, c = "p", s = game.JobId, st = HubChat.me.st, lv = myLevel() })
		if HubChat.mode == "ntfy" then
			request({ Url = NTFY, Method = "POST", Headers = { ["Content-Type"] = "text/plain" }, Body = payload })
		else
			request({ Url = fbUrl .. "/yadsanchat.json", Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = payload })
		end
		HubChat.presence[lp.Name] = { d = HubChat.myName(), u = lp.UserId, t = os.time(), s = game.JobId, st = HubChat.me.st, lv = myLevel() }
	end
	task.spawn(function()
		task.wait(6)
		while true do
			pcall(HubChat.ping)
			task.wait(600)
		end
	end)
	function HubChat.allUsers()
		local u, now = {}, os.time()
		for n, v in pairs(HubChat.presence) do
			if now - v.t < 2400 then u[n] = { n = n, d = v.d, u = v.u, t = v.t, s = v.s } end
		end
		for _, m in ipairs(HubChat.msgs) do
			if now - (m.t or 0) < 2400 and (not u[m.n] or u[m.n].t < m.t) then u[m.n] = { n = m.n, d = m.d, u = m.u, t = m.t, s = m.s } end
		end
		local out = {}
		for _, v in pairs(u) do out[#out + 1] = v end
		table.sort(out, function(a, b) return a.t > b.t end)
		return out
	end
	-- generic post (friend control etc.)
	function HubChat.post(t)
		if not httpReq or not take(2) then return false end
		t.n, t.d, t.t, t.i, t.u, t.s = lp.Name, HubChat.myName(), os.time(), HttpService:GenerateGUID(false), lp.UserId, game.JobId
		t.st, t.lv = HubChat.me.st, myLevel()
		seen[t.i] = true
		task.spawn(function()
			local payload = HttpService:JSONEncode(t)
			pcall(function()
				if HubChat.mode == "ntfy" then
					request({ Url = NTFY, Method = "POST", Headers = { ["Content-Type"] = "text/plain" }, Body = payload })
				else
					request({ Url = fbUrl .. "/yadsanchat.json", Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = payload })
				end
			end)
		end)
		return true
	end
	function HubChat.isFriend(n) return HubChat.fr.friends[n] ~= nil end
	function HubChat.request(n, d, u)
		if n == lp.Name or HubChat.isFriend(n) then return false end
		HubChat.fr.outgoing[n] = os.time()
		HubChat.post({ c = "f", to = n, a = "req", m = "." })
		fireFr()
		return true
	end
	function HubChat.accept(n)
		local inc = HubChat.fr.incoming[n]
		HubChat.fr.friends[n] = { d = inc and inc.d or n, u = inc and inc.u }
		HubChat.fr.incoming[n], HubChat.fr.outgoing[n] = nil, nil
		HubChat.post({ c = "f", to = n, a = "acc", m = "." })
		fireFr()
	end
	function HubChat.decline(n)
		HubChat.fr.incoming[n] = nil
		HubChat.post({ c = "f", to = n, a = "dec", m = "." })
		fireFr()
	end
	function HubChat.unfriend(n)
		HubChat.fr.friends[n] = nil
		HubChat.post({ c = "f", to = n, a = "rem", m = "." })
		fireFr()
	end
	function HubChat.online(n)
		local p = HubChat.presence[n]
		return p ~= nil and os.time() - (p.t or 0) < 1200
	end
	function HubChat.dm(n)
		local out = {}
		for _, m in ipairs(HubChat.msgs) do
			if m.c == "d" and ((m.mine and m.to == n) or (not m.mine and m.n == n)) then out[#out + 1] = m end
		end
		return out
	end
	function HubChat.joinFriend(n)
		local p = HubChat.presence[n]
		if not p or not p.s or p.s == "" then return false, "No server info for " .. n .. " yet (they appear after they chat or open the hub)" end
		if p.s == game.JobId then return false, n .. " is already in your server" end
		local ok, err = pcall(function() game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, p.s, lp) end)
		return ok, ok and ("Joining " .. n) or tostring(err)
	end
	function HubChat.users(scope)
		local u, now = {}, os.time()
		for _, m in ipairs(HubChat.msgs) do
			if now - (m.t or 0) < 900 and (scope ~= "l" or Players:FindFirstChild(m.n)) then
				u[m.n] = { d = m.d, t = m.t, u = m.u }
			end
		end
		local out = {}
		for n, v in pairs(u) do
			out[#out + 1] = { n = n, d = v.d, t = v.t, u = v.u }
		end
		table.sort(out, function(a, b)
			return a.t > b.t
		end)
		return out
	end
	function HubChat.setServer(u)
		u = tostring(u or ""):gsub("%s+", ""):gsub("/+$", "")
		if u == "" then
			HubChat.mode, fbUrl = "ntfy", ""
			pcall(function()
				if delfile and isfile and isfile(CHAT_FILE) then
					delfile(CHAT_FILE)
				end
			end)
		else
			if not u:match("^https://") then
				return false
			end
			HubChat.mode, fbUrl = "firebase", u
			pcall(function()
				pcall(makefolder, "YADSAN_HUB")
				writefile(CHAT_FILE, u)
			end)
		end
		seen, pending, lastId, firstPoll = {}, {}, nil, true
		HubChat.msgs = {}
		return true
	end
	HubChat.poll = poll
	function HubChat.announce(text)
		text = clean(text, 180)
		if text == "" then return false end
		return HubChat.post({ c = "s", a = "ann", m = text })
	end
	function HubChat.mute(name, on)
		name = tostring(name or ""):gsub("%s+", "")
		if name == "" then return false end
		HubChat.staffMute[name] = on and true or nil
		return HubChat.post({ c = "s", a = on and "mute" or "unm", to = name, m = "." })
	end
	NovaUI.HubChat = HubChat
	-- owner / admin recognition: matched by username AND the real userId (resolved from the name)
	HubChat.STAFF = {
		supermonkxscripts = { real = "supermonkxscripts", title = "OWNER", a = Color3.fromRGB(255, 226, 120), b = Color3.fromRGB(255, 150, 30) },
		theredauth0r = { real = "TheRedAuth0r", title = "ADMIN", a = Color3.fromRGB(255, 214, 90), b = Color3.fromRGB(255, 110, 60) },
	}
	function HubChat.staffOf(name, uid)
		local s = HubChat.STAFF[tostring(name or ""):lower()]
		if s and s.uid and tonumber(uid) == s.uid then
			return s
		end
		return nil
	end
	task.spawn(function()
		for _, s in pairs(HubChat.STAFF) do
			local ok, id = pcall(function()
				return Players:GetUserIdFromNameAsync(s.real)
			end)
			if ok and type(id) == "number" then
				s.uid = id
			end
		end
		fire()
	end)
	task.spawn(function()
		task.wait(1)
		local wsAlive = 0
		local wsStarted = false
		-- realtime push through a websocket (ntfy supports it); polling stays as a slow safety net
		local function startWs()
			if wsStarted then return end
			wsStarted = true
			task.spawn(function()
				while true do
					local WS = WebSocket
					if HubChat.mode == "ntfy" and WS and WS.connect then
						local url = NTFY:gsub("^https://", "wss://"):gsub("^http://", "ws://") .. "/ws?since=" .. tostring(lastId or "20s")
						local ok, sock = pcall(WS.connect, url)
						if ok and sock then
							local closed = false
							sock.OnMessage:Connect(function(msg)
								local okj, o = pcall(function() return HttpService:JSONDecode(msg) end)
								if okj and type(o) == "table" then
									wsAlive = os.clock()
									if o.event == "message" and type(o.message) == "string" then
										lastId = o.id or lastId
										pcall(ingest, o.id, o.message)
										HubChat.status = "online (live)"
										fire()
									end
								end
							end)
							sock.OnClose:Connect(function() closed = true end)
							wsAlive = os.clock()
							while not closed and HubChat.mode == "ntfy" and os.clock() - wsAlive < 90 do task.wait(2) end
							pcall(function() sock:Close() end)
							wsAlive = 0
						end
					end
					task.wait(4)
				end
			end)
		end
		while true do
			pcall(poll)
			startWs()
			local live = os.clock() - wsAlive < 60
			local wait = live and 20 or ((os.clock() < activeUntil or HubChat.uiOpen) and 3 or 6)
			task.wait(wait + backoff)
		end
	end)
end

local function chatText(maxN)
	local out = {}
	local L = HubChat.list("g")
	local from = math.max(1, #L - (maxN or 25) + 1)
	for i = from, #L do
		local m = L[i]
		out[#out + 1] = ((HubChat.staffOf(m.n, m.u) and ("[" .. HubChat.staffOf(m.n, m.u).title .. "] ") or "") .. (m.mine and "You" or m.d)) .. (m.state == "sending" and " (sending)" or m.state == "failed" and " (FAILED)" or "") .. ": " .. m.m
	end
	return #out == 0 and "No messages yet. Say hi!" or table.concat(out, "\n")
end

local Chat = Window:CreateTab({ Name = "Chat", Icon = "chat" })
local chatBox = Chat:Section({ Title = "Hub Chat (YADSAN users only)", Icon = "chat", Side = "Left" })
local chatLog = chatBox:Label("Connecting...")
local chatMsg
chatMsg = chatBox:Input({ Placeholder = "Type a message and press Enter", OnBlur = false, Callback = function(t)
	local ok, e = HubChat.send(t)
	if not ok and e ~= "empty" then notify("Chat", tostring(e)) end
	task.defer(function() chatMsg:Set("", true) end)
end })
chatBox:Button({ Title = "Send", Style = "Primary", Callback = function()
	local ok, e = HubChat.send(chatMsg:Get())
	if not ok and e ~= "empty" then notify("Chat", tostring(e)) end
	chatMsg:Set("", true)
end })
local chatUsers = chatBox:Label("Active: nobody yet")
HubChat.onUpdate(function()
	chatLog:Set(chatText(25))
	local u = HubChat.users()
	local names = {}
	for _, x in ipairs(u) do names[#names + 1] = x.d end
	chatUsers:Set("Active (15 min): " .. (#names == 0 and "nobody yet" or table.concat(names, ", ")) .. "  |  " .. HubChat.status)
end)
local chatSet = Chat:Section({ Title = "Server", Icon = "settings", Side = "Right" })
chatSet:Paragraph({ Title = "How it works", Content = "Works out of the box through the free public ntfy.sh relay: every YADSAN HUB user is in one chat. It is NOT private and has rate limits, so don't share secrets. For a private chat, paste your own Firebase Realtime Database URL below (everyone must use the same one). Leave empty and Save to go back to the default." })
local urlIn = chatSet:Input({ Placeholder = "https://your-db.firebaseio.com (optional)" })
chatSet:Button({ Title = "Save server", Style = "Primary", Callback = function()
	local ok = HubChat.setServer(urlIn:Get())
	notify("Chat", ok and "Server saved, reconnecting..." or "URL must start with https://")
end })
do
------------------------------------------------------------------------
-- PHONE APPS: Hub Chat + Fit Saver run INSIDE the Life Together phone screen (overlay on the phone)
------------------------------------------------------------------------
local appGuiParent = Window.Gui.Parent
local TS = game:GetService("TweenService")
local TH = { good = Color3.fromRGB(90, 220, 150), bad = Color3.fromRGB(255, 100, 120) }
local THEMES = {
	{ name = "Purple", h = 0.75, s = 1 }, { name = "Crimson", h = 0.98, s = 1 }, { name = "Rose", h = 0.9, s = 0.85 },
	{ name = "Ocean", h = 0.56, s = 1 }, { name = "Emerald", h = 0.4, s = 0.9 }, { name = "Gold", h = 0.12, s = 1 },
	{ name = "Sunset", h = 0.04, s = 0.9 }, { name = "Mono", h = 0, s = 0 },
}
local function applyThemeData(t)
	local h, s = t.h, t.s
	local function c(sat, val)
		return Color3.fromHSV(h, math.clamp(sat * s, 0, 1), val)
	end
	TH.name = t.name
	TH.acc, TH.bg, TH.bar = c(0.72, 0.95), c(0.6, 0.09), c(0.6, 0.14)
	TH.card, TH.card2 = c(0.55, 0.22), c(0.5, 0.31)
	TH.bgTop, TH.bgBot = c(0.6, 0.17), c(0.55, 0.07)
	TH.hdrA, TH.hdrB = c(0.75, 0.62), c(0.7, 0.24)
	TH.bubA, TH.bubB = c(0.7, 1), c(0.8, 0.78)
	TH.cardA, TH.cardB = c(0.5, 0.32), c(0.55, 0.2)
	TH.text, TH.dim = Color3.fromHSV(h, 0.06 * s, 1), c(0.25, 0.8)
end
do
	local saved
	pcall(function()
		if isfile and isfile("YADSAN_HUB/app_theme.txt") then saved = readfile("YADSAN_HUB/app_theme.txt"):gsub("%s+", "") end
	end)
	local pick = THEMES[1]
	for _, t in ipairs(THEMES) do
		if t.name == saved then pick = t end
	end
	applyThemeData(pick)
end
local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do
		o[k] = v
	end
	if parent then
		if o:IsA("GuiObject") and (props == nil or props.ZIndex == nil) and parent:IsA("GuiObject") then
			o.ZIndex = parent.ZIndex + 1
		end
		o.Parent = parent
	end
	return o
end
local function round(o, r)
	return mk("UICorner", { CornerRadius = UDim.new(0, r or 10) }, o)
end
local function pad(o, l, r, t, b)
	return mk("UIPadding", { PaddingLeft = UDim.new(0, l), PaddingRight = UDim.new(0, r or l), PaddingTop = UDim.new(0, t or l), PaddingBottom = UDim.new(0, b or t or l) }, o)
end
local function txt(parent, text, size, color, font, props)
	local p = { BackgroundTransparency = 1, Text = text, TextSize = size or 13, TextColor3 = color or TH.text, Font = font or Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left }
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return mk("TextLabel", p, parent)
end
local function btn(parent, text, accent, props)
	local p = { Text = text, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = TH.text, AutoButtonColor = true, BackgroundColor3 = accent and TH.acc or TH.card2, BorderSizePixel = 0 }
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	local b = mk("TextButton", p, parent)
	round(b, 9)
	return b
end
local function shown(o)
	while o and o ~= game do
		if o:IsA("GuiObject") and not o.Visible then return false end
		if o:IsA("ScreenGui") and not o.Enabled then return false end
		o = o.Parent
	end
	return true
end
local function phoneGui()
	local pg = lp:FindFirstChildOfClass("PlayerGui")
	return pg and pg:FindFirstChild("Phone")
end
local function overlayHost()
	local o = phoneGui()
	for _, n in ipairs({ "PhoneHome", "MasterFrame" }) do
		o = o and o:FindFirstChild(n)
	end
	if not o then return nil end
	local h = o:FindFirstChild("Holder")
	if h and not (h:FindFirstChildWhichIsA("UIListLayout") or h:FindFirstChildWhichIsA("UIGridLayout")) then
		return h, o
	end
	return o, o
end

-- manual fit of the app inside the phone screen (saved in YADSAN_HUB/app_fit.json)
NovaUI.AppFit = { l = 0, r = 0, t = 0, b = 0, whole = false }
pcall(function()
	if isfile and isfile("YADSAN_HUB/app_fit.json") then
		local d = HttpService:JSONDecode(readfile("YADSAN_HUB/app_fit.json"))
		for _, k in ipairs({ "l", "r", "t", "b" }) do
			if type(d[k]) == "number" then NovaUI.AppFit[k] = math.clamp(d[k], -30, 60) end
		end
		NovaUI.AppFit.whole = d.whole == true
	end
end)
local function saveFit()
	pcall(function()
		pcall(makefolder, "YADSAN_HUB")
		writefile("YADSAN_HUB/app_fit.json", HttpService:JSONEncode(NovaUI.AppFit))
	end)
end
local current
local closeApp
function closeApp(instant)
	local c = current
	if not c then return end
	current = nil
	c.alive = false
	for _, e in ipairs(c.stack) do
		if e.onClose then pcall(e.onClose) end
	end
	pcall(c.def.onClose)
	if instant or not c.overlay.Parent then
		pcall(function() c.overlay:Destroy() end)
		return
	end
	pcall(function() TS:Create(c.scaler, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Position = UDim2.fromScale(0, 1) }):Play() end)
	task.delay(0.25, function() pcall(function() c.overlay:Destroy() end) end)
end

local function openApp(def, opts)
	opts = opts or {}
	if current then
		local same = current.def == def
		closeApp(true)
		if same and not opts.reopen then return end
	end
	local host, mf = overlayHost()
	if not host or host.AbsoluteSize.X < 20 or not shown(host) then
		notify("Phone", "Open your phone first, then tap the app.")
		return
	end
	-- CanvasGroup clips its children to the rounded corners (a plain Frame cannot), so nothing pokes out of the phone
	local FI = NovaUI.AppFit
	if FI.whole and mf then host = mf end
	local overlay = mk("CanvasGroup", { Name = "YadsanAppOverlay", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(FI.l, FI.t), Size = UDim2.new(1, -(FI.l + FI.r), 1, -(FI.t + FI.b)), Active = true, ZIndex = 100 }, host)
	local hc = host:FindFirstChildOfClass("UICorner") or (mf and mf:FindFirstChildOfClass("UICorner"))
	local rad = math.clamp(math.floor(math.min(host.AbsoluteSize.X, host.AbsoluteSize.Y) * 0.13), 18, 46)
	if hc and hc.CornerRadius.Offset > rad then rad = hc.CornerRadius.Offset end
	mk("UICorner", { CornerRadius = UDim.new(0, rad) }, overlay)
	local DW = 300
	local scaler = mk("Frame", { Name = "Scaler", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromOffset(DW, 600), Position = UDim2.fromScale(0, 1) }, overlay)
	mk("UIGradient", { Rotation = 90, Color = ColorSequence.new(TH.bgTop, TH.bgBot) }, scaler)
	local us = mk("UIScale", {}, scaler)
	local function fit()
		local a = overlay.AbsoluteSize
		if a.X < 10 then return end
		us.Scale = 1
		local m = scaler.AbsoluteSize.X
		if m < 1 then m = DW end
		us.Scale = a.X / m
		scaler.Size = UDim2.fromOffset(DW, DW * a.Y / a.X)
	end
	fit()
	overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

	local ctx = { startTab = opts.tab, alive = true, def = def, overlay = overlay, scaler = scaler, stack = {}, DW = DW }
	local header = mk("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 50) }, scaler)
	mk("UIGradient", { Rotation = 0, Color = ColorSequence.new(TH.hdrA, TH.hdrB) }, header)
	mk("Frame", { BackgroundColor3 = TH.acc, BackgroundTransparency = 0.55, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1) }, header)
	local backB = mk("TextButton", { Text = "‹", Font = Enum.Font.GothamBold, TextSize = 30, TextColor3 = TH.text, BackgroundTransparency = 1, Size = UDim2.fromOffset(40, 50) }, header)
	local titleL = txt(header, def.title, 16, TH.text, Enum.Font.GothamBlack, { Position = UDim2.fromOffset(40, 6), Size = UDim2.new(1, -120, 0, 20) })
	local subL = txt(header, "", 10, TH.text, Enum.Font.Gotham, { Position = UDim2.fromOffset(40, 26), Size = UDim2.new(1, -120, 0, 14) })
	local function ctx_setSub(t) subL.Text = t end
	local right = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.new(1, -78, 0, 0), Size = UDim2.fromOffset(74, 50) }, header)
	mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4) }, right)
	local content = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -72), ClipsDescendants = true }, scaler)
	local homeBar = mk("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = TH.bar, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -22), Size = UDim2.new(1, 0, 0, 22) }, scaler)
	local pill = mk("Frame", { BackgroundColor3 = TH.dim, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(84, 5) }, homeBar)
	round(pill, 3)
	homeBar.MouseButton1Click:Connect(function() closeApp() end)

	local function setRight(build)
		for _, c in ipairs(right:GetChildren()) do
			if c:IsA("GuiObject") then c:Destroy() end
		end
		if build then build(right) end
	end
	ctx.setSub = ctx_setSub
	function ctx.push(title, build, rightBuild)
		local top = ctx.stack[#ctx.stack]
		local view = mk("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Position = (#ctx.stack == 0) and UDim2.fromScale(0, 0) or UDim2.fromScale(1, 0) }, content)
		local entry = { view = view, title = title, rightBuild = rightBuild }
		ctx.stack[#ctx.stack + 1] = entry
		entry.onClose = build(view, entry)
		titleL.Text = title
		setRight(rightBuild)
		if top then
			TS:Create(top.view, TweenInfo.new(0.22, Enum.EasingStyle.Quint), { Position = UDim2.fromScale(-0.3, 0) }):Play()
			TS:Create(view, TweenInfo.new(0.22, Enum.EasingStyle.Quint), { Position = UDim2.fromScale(0, 0) }):Play()
		end
	end
	function ctx.pop()
		if #ctx.stack <= 1 then return false end
		local e = table.remove(ctx.stack)
		if e.onClose then pcall(e.onClose) end
		local prev = ctx.stack[#ctx.stack]
		TS:Create(e.view, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Position = UDim2.fromScale(1, 0) }):Play()
		TS:Create(prev.view, TweenInfo.new(0.2, Enum.EasingStyle.Quint), { Position = UDim2.fromScale(0, 0) }):Play()
		task.delay(0.22, function() pcall(function() e.view:Destroy() end) end)
		titleL.Text = prev.title
		setRight(prev.rightBuild)
		return true
	end
	function ctx.back()
		if not ctx.pop() then closeApp() end
	end
	backB.MouseButton1Click:Connect(ctx.back)
	current = ctx
	def.build(ctx)
	if opts.instant then
		scaler.Position = UDim2.fromScale(0, 0)
	else
		TS:Create(scaler, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0, 0) }):Play()
	end
end

------------------------------------------------------------------------
-- Hub Chat app
------------------------------------------------------------------------
local function dropListener(list, fn)
	for i, f in ipairs(list) do
		if f == fn then table.remove(list, i) break end
	end
end
local function reopen(def, tab)
	closeApp(true)
	openApp(def, { tab = tab, reopen = true, instant = true })
end
local function setTheme(t, def, tab)
	applyThemeData(t)
	pcall(function()
		pcall(makefolder, "YADSAN_HUB")
		writefile("YADSAN_HUB/app_theme.txt", t.name)
	end)
	reopen(def, tab)
end
local function scrollList(body)
	local sf = mk("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ScrollBarThickness = 2, ScrollBarImageColor3 = TH.acc, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, body)
	mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, sf)
	pad(sf, 10, 10, 6, 12)
	return sf
end
local function pfp(parent, name, disp, uid, size, ring)
	local pl = Players:FindFirstChild(tostring(name))
	uid = tonumber(uid) or (pl and pl.UserId)
	local f
	if uid then
		f = mk("ImageLabel", { BackgroundColor3 = TH.card2, BorderSizePixel = 0, Size = UDim2.fromOffset(size, size), Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=100&h=100"):format(uid) }, parent)
	else
		local hue = (#tostring(name) * 37) % 100 / 100
		f = mk("TextLabel", { BackgroundColor3 = Color3.fromHSV(0.7 + hue * 0.2, 0.55, 0.7), BorderSizePixel = 0, Size = UDim2.fromOffset(size, size), Text = tostring(disp or name):sub(1, 1):upper(), Font = Enum.Font.GothamBlack, TextSize = size * 0.5, TextColor3 = Color3.new(1, 1, 1) }, parent)
	end
	round(f, size)
	if ring then
		local st = mk("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1) }, f)
		mk("UIGradient", { Color = ColorSequence.new(ring.a, ring.b) }, st)
	end
	return f
end
local function goldName(parent, text, st, props)
	local p = { Size = UDim2.new(0, 0, 0, 14), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Left }
	for k, v in pairs(props or {}) do p[k] = v end
	local l = txt(parent, text, 11, Color3.new(1, 1, 1), Enum.Font.GothamBlack, p)
	if st then
		mk("UIGradient", { Color = ColorSequence.new(st.a, st.b) }, l)
	else
		l.TextColor3 = Color3.fromHSV(0, 0, 0.82)
		l.Font = Enum.Font.GothamBold
	end
	return l
end
local function titlePill(parent, st, order)
	local pill = mk("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.new(0, 0, 0, 13), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order or 2 }, parent)
	round(pill, 7)
	mk("UIGradient", { Color = ColorSequence.new(st.a, st.b) }, pill)
	local l = txt(pill, st.title, 8, Color3.fromRGB(25, 10, 30), Enum.Font.GothamBlack, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Center })
	pad(l, 6, 6, 0, 0)
	return pill
end

-- tabs with a content body; every page builder may return a cleanup function
local function tabbed(ctx, view, names, builders, start)
	local bar = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40) }, view)
	mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center }, bar)
	pad(bar, 10, 10, 5, 3)
	local body = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -40), ClipsDescendants = true }, view)
	local btns, cleanup, active = {}, nil, nil
	local api = { body = body }
	function api.select(n)
		if cleanup then pcall(cleanup) cleanup = nil end
		for _, c in ipairs(body:GetChildren()) do c:Destroy() end
		active = n
		for k, b in pairs(btns) do
			b.BackgroundColor3 = (k == n) and TH.acc or TH.card
		end
		cleanup = builders[n](body, api)
	end
	function api.current() return active end
	function api.close() if cleanup then pcall(cleanup) cleanup = nil end end
	for _, n in ipairs(names) do
		local b = btn(bar, n, false, { Size = UDim2.new(1 / #names, -5, 1, 0), BackgroundColor3 = TH.card, TextSize = 12 })
		btns[n] = b
		b.MouseButton1Click:Connect(function() if active ~= n then api.select(n) end end)
	end
	api.select(start and builders[start] and start or names[1])
	return api
end

local function settingsPage(body, def, tabName, extra)
	local sf = scrollList(body)
	txt(sf, "APP THEME", 11, TH.dim, Enum.Font.GothamBold, { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 1 })
	local grid = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 }, sf)
	mk("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 54), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	for i, t in ipairs(THEMES) do
		local b = mk("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, LayoutOrder = i }, grid)
		round(b, 12)
		mk("UIGradient", { Rotation = 25, Color = ColorSequence.new(Color3.fromHSV(t.h, 0.75 * t.s, 0.72), Color3.fromHSV(t.h, 0.7 * t.s, 0.22)) }, b)
		if TH.name == t.name then
			mk("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1) }, b)
		end
		txt(b, t.name, 13, Color3.new(1, 1, 1), Enum.Font.GothamBold, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0) })
		if TH.name == t.name then
			txt(b, "ACTIVE", 8, Color3.new(1, 1, 1), Enum.Font.GothamBlack, { Position = UDim2.new(1, -52, 0, 6), Size = UDim2.fromOffset(46, 10), TextXAlignment = Enum.TextXAlignment.Right })
		end
		b.MouseButton1Click:Connect(function() setTheme(t, def, tabName) end)
	end
	txt(sf, "SCREEN FIT (if the app does not match your phone)", 11, TH.dim, Enum.Font.GothamBold, { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 20 })
	local FIT = NovaUI.AppFit
	for i, d in ipairs({ { "l", "Left" }, { "r", "Right" }, { "t", "Top" }, { "b", "Bottom" } }) do
		local row = mk("Frame", { BackgroundColor3 = TH.card, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 20 + i }, sf)
		round(row, 12)
		txt(row, d[2] .. " edge", 12, TH.text, Enum.Font.GothamMedium, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -150, 1, 0) })
		local val = txt(row, tostring(FIT[d[1]]), 12, TH.acc, Enum.Font.GothamBold, { Position = UDim2.new(1, -96, 0, 0), Size = UDim2.fromOffset(40, 40), TextXAlignment = Enum.TextXAlignment.Center })
		local mi = btn(row, "-", false, { Position = UDim2.new(1, -136, 0.5, -14), Size = UDim2.fromOffset(34, 28), TextSize = 16 })
		local pl = btn(row, "+", false, { Position = UDim2.new(1, -50, 0.5, -14), Size = UDim2.fromOffset(34, 28), TextSize = 16 })
		local function bump(dv)
			FIT[d[1]] = math.clamp(FIT[d[1]] + dv, -30, 60)
			val.Text = tostring(FIT[d[1]])
			saveFit()
		end
		mi.MouseButton1Click:Connect(function() bump(-2) end)
		pl.MouseButton1Click:Connect(function() bump(2) end)
	end
	local wr = mk("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = TH.card, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 26 }, sf)
	round(wr, 12)
	txt(wr, "Use the whole phone frame", 12, TH.text, Enum.Font.GothamMedium, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -90, 1, 0) })
	local wb = btn(wr, FIT.whole and "ON" or "OFF", FIT.whole, { Position = UDim2.new(1, -62, 0.5, -14), Size = UDim2.fromOffset(52, 28), TextSize = 12 })
	wb.MouseButton1Click:Connect(function()
		FIT.whole = not FIT.whole
		wb.Text = FIT.whole and "ON" or "OFF"
		saveFit()
	end)
	txt(sf, "Changes apply the next time you open an app.", 10, TH.dim, Enum.Font.Gotham, { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 27 })
	if extra then extra(sf) end
end

------------------------------------------------------------------------
-- Hub Chat app  (tabs: Chat / People / Settings)
------------------------------------------------------------------------
local ChatApp = { id = "Chat", title = "Hub Chat", icon = "chat" }
local profileCard
local function scopeBar(parent, onChange)
	local bar = mk("Frame", { BackgroundColor3 = TH.card, BorderSizePixel = 0, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 30) }, parent)
	round(bar, 15)
	local bs = {}
	local function paint()
		for k, b in pairs(bs) do
			b.BackgroundColor3 = (HubChat.scope == k) and TH.acc or TH.card
			b.BackgroundTransparency = (HubChat.scope == k) and 0 or 1
		end
	end
	for i, d in ipairs({ { "g", "Global" }, { "l", "Local server" } }) do
		local b = btn(bar, d[2], false, { Position = UDim2.new((i - 1) / 2, 2, 0, 2), Size = UDim2.new(0.5, -4, 1, -4), TextSize = 11 })
		round(b, 13)
		bs[d[1]] = b
		b.MouseButton1Click:Connect(function()
			if HubChat.scope ~= d[1] then HubChat.scope = d[1] paint() onChange() end
		end)
	end
	paint()
	return bar
end
local function chatPage(ctx, body)
	local anim = {}
	local animConn = game:GetService("RunService").Heartbeat:Connect(function()
		local t = os.clock()
		for g, kind in pairs(anim) do
			if g.Parent then
				if kind == 1 then g.Rotation = (t * 80) % 360 else g.Offset = Vector2.new(math.sin(t * 1.6) * 0.5, 0) end
			else
				anim[g] = nil
			end
		end
	end)
	local sf = mk("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 1, -86), ScrollBarThickness = 2, ScrollBarImageColor3 = TH.acc, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, body)
	mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, sf)
	pad(sf, 10, 10, 8, 8)
	local lastSig
	local function render(force)
		local msgs = HubChat.list(HubChat.scope)
		local users = HubChat.users(HubChat.scope)
		ctx.setSub((HubChat.scope == "l" and "this server" or "global") .. "  -  " .. #users .. " online  -  " .. tostring(HubChat.status))
		local last = msgs[#msgs]
		local bad = 0
		for _, m in ipairs(msgs) do if m.state ~= "ok" then bad = bad + 1 end end
		local sig = HubChat.scope .. #msgs .. ":" .. (last and last.id or "") .. ":" .. bad .. ":" .. tostring(HubChat.STAFF.supermonkxscripts.uid) .. tostring(HubChat.STAFF.theredauth0r.uid)
		if not force and sig == lastSig then return end
		lastSig = sig
		for _, c in ipairs(sf:GetChildren()) do
			if c:IsA("GuiObject") then c:Destroy() end
		end
		if #msgs == 0 then
			local e = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 170), LayoutOrder = 1 }, sf)
			local ring = mk("Frame", { BackgroundColor3 = TH.card, BorderSizePixel = 0, Size = UDim2.fromOffset(70, 70), Position = UDim2.new(0.5, -35, 0, 24) }, e)
			round(ring, 35)
			mk("UIStroke", { Color = TH.acc, Thickness = 2, Transparency = 0.2 }, ring)
			txt(ring, "M", 34, TH.acc, Enum.Font.GothamBlack, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
			txt(e, "No messages yet", 15, TH.text, Enum.Font.GothamBold, { Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center })
			txt(e, HubChat.scope == "l" and "Only people in this server see local messages" or "Say hi to everyone using YADSAN HUB", 11, TH.dim, Enum.Font.Gotham, { Position = UDim2.fromOffset(0, 126), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center })
		end
		local first = math.max(1, #msgs - 39)
		local holes = 0
		for i = #msgs, first, -1 do
			local m = msgs[i]
			if HubChat.staffOf(m.n, m.u) then holes = holes + 1 end
		end
		local holeBudget = 8
		for i = first, #msgs do
			local m, prev, nxt = msgs[i], msgs[i - 1], msgs[i + 1]
			if i == first then prev = nil end
			local st = HubChat.staffOf(m.n, m.u)
			local newGroup = not prev or prev.n ~= m.n or (m.t - (prev.t or 0)) > 180
			local lastInGroup = not nxt or nxt.n ~= m.n or (nxt.t - m.t) > 180
			local row = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i + 1 }, sf)
			mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = m.mine and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left }, row)
			local function avatarSlot(order)
				local slot = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(28, 28), LayoutOrder = order }, row)
				if lastInGroup then
					pfp(slot, m.n, m.d, m.u, 28, st)
					local hit = mk("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = slot.ZIndex + 6 }, slot)
					hit.MouseButton1Click:Connect(function() ctx.push(m.d, function(v) profileCard(ctx, v, m.n) end) end)
				end
			end
			if not m.mine then avatarSlot(1) end
			local col = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 }, row)
			mk("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), HorizontalAlignment = m.mine and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left }, col)
			if newGroup and (not m.mine or st) then
				local nrow = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, 14), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1 }, col)
				mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, nrow)
				local gl = goldName(nrow, (st and "★ " or "") .. m.d, st, { LayoutOrder = 1 })
				if st then local ug = gl:FindFirstChildOfClass("UIGradient") if ug then anim[ug] = 2 end end
				if st then titlePill(nrow, st, 2) end
			end
			local b = mk("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(0, 0, 0, 0), LayoutOrder = 2, ClipsDescendants = true }, col)
			round(b, 14)
			mk("UISizeConstraint", { MaxSize = Vector2.new(190, math.huge) }, b)
			local textZ = b.ZIndex + 4
			if st then
				b.BackgroundColor3 = Color3.fromRGB(8, 4, 16)
				local gs = mk("UIStroke", { Thickness = 1.6, Color = Color3.new(1, 1, 1) }, b)
				anim[mk("UIGradient", { Color = ColorSequence.new(st.a, st.b) }, gs)] = 1
				mk("UIGradient", { Rotation = 25, Color = ColorSequence.new(Color3.fromRGB(46, 20, 62), Color3.fromRGB(58, 36, 10)) }, b)
				b.BackgroundColor3 = Color3.new(1, 1, 1)
				if holeBudget > 0 and #msgs - i < 14 then
					holeBudget = holeBudget - 1
					local fx = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = b.ZIndex + 1 }, b)
					pcall(function()
						NovaUI.MakeBlackhole(fx, 96, { Position = UDim2.new(1, -8, 0.5, 0), ParticleCount = 5, ZIndex = fx.ZIndex + 1 })
						NovaUI.MakeBlackhole(fx, 70, { Position = UDim2.new(0, 4, 0.5, 0), ParticleCount = 4, ZIndex = fx.ZIndex + 1 })
					end)
				end
			elseif m.mine then
				mk("UIGradient", { Rotation = 35, Color = ColorSequence.new(TH.bubA, TH.bubB) }, b)
			else
				b.BackgroundColor3 = TH.card
				mk("UIStroke", { Color = TH.acc, Transparency = 0.8, Thickness = 1 }, b)
			end
			local tl = mk("TextLabel", { BackgroundTransparency = 1, Text = m.m, TextWrapped = true, TextSize = 13, Font = st and Enum.Font.GothamBold or Enum.Font.GothamMedium, TextColor3 = st and Color3.fromRGB(255, 240, 200) or Color3.new(1, 1, 1), AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(0, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = textZ }, b)
			pad(tl, 11, 11, 7, 7)
			mk("UISizeConstraint", { MaxSize = Vector2.new(190, math.huge) }, tl)
			if lastInGroup or m.state ~= "ok" then
				local meta = os.date("%H:%M", m.t or os.time())
				if m.state == "sending" then meta = "sending..." elseif m.state == "failed" then meta = "failed to send" end
				txt(col, meta, 9, m.state == "failed" and TH.bad or TH.dim, Enum.Font.Gotham, { Size = UDim2.new(0, 0, 0, 11), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 3 })
			end
			if m.mine then
				local slot = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(28, 28), LayoutOrder = 3 }, row)
				if lastInGroup then pfp(slot, m.n, m.d, m.u or lp.UserId, 28, st) end
			end
		end
		task.defer(function()
			if sf.Parent then sf.CanvasPosition = Vector2.new(0, 1e6) end
		end)
	end
	local box
	scopeBar(body, function()
		if box then box.PlaceholderText = (HubChat.scope == "l") and "Message this server..." or "Message everyone..." end
		render(true)
	end)
	local bar = mk("Frame", { BackgroundColor3 = TH.bar, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -48), Size = UDim2.new(1, 0, 0, 48) }, body)
	box = mk("TextBox", { PlaceholderText = (HubChat.scope == "l") and "Message this server..." or "Message everyone...", Text = "", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = TH.text, PlaceholderColor3 = TH.dim, BackgroundColor3 = TH.card2, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -78, 0, 36) }, bar)
	round(box, 18)
	pad(box, 12, 8, 0, 0)
	local send = btn(bar, "Send", true, { Position = UDim2.new(1, -66, 0, 6), Size = UDim2.fromOffset(58, 36), BackgroundColor3 = TH.acc })
	round(send, 18)
	local function go()
		local ok, e = HubChat.send(box.Text, HubChat.scope)
		if ok then
			box.Text = ""
		elseif e ~= "empty" then
			notify("Chat", tostring(e))
		end
	end
	send.MouseButton1Click:Connect(go)
	box.FocusLost:Connect(function(enter) if enter then go() end end)
	local fn = function()
		if ctx.alive and body.Parent then render(false) end
	end
	table.insert(HubChat.listeners, fn)
	HubChat.setUiOpen(true)
	render(true)
	task.spawn(function() pcall(HubChat.poll) end)
	return function()
		pcall(function() animConn:Disconnect() end)
		dropListener(HubChat.listeners, fn)
		HubChat.setUiOpen(false)
	end
end
local function staffInfo(n, u) return HubChat.staffOf(n, u) end
local function nameOk(hn)
	if hn == "" then return true end
	if #hn < 2 then return false, "Name must be at least 2 characters" end
	local low = hn:lower():gsub("[%s_%.%-]", "")
	if low:find("supermonkx") or low:find("redauth0r") or low:find("owner") or low:find("admin") then
		if not HubChat.staffOf(lp.Name, lp.UserId) then return false, "That name is reserved" end
	end
	return true
end
local function infoOf(n)
	local p = HubChat.presence[n] or {}
	local f = HubChat.fr.friends[n] or {}
	return { n = n, d = p.d or f.d or n, u = p.u or f.u, st = p.st or "", lv = p.lv or 1, s = p.s, t = p.t }
end
local function pill(parent, text, col, order)
	local f = mk("Frame", { BackgroundColor3 = col, BorderSizePixel = 0, Size = UDim2.new(0, 0, 0, 13), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order or 3 }, parent)
	round(f, 7)
	local l = txt(f, text, 8, Color3.fromRGB(20, 8, 30), Enum.Font.GothamBlack, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Center })
	pad(l, 6, 6, 0, 0)
	return f
end

-- one conversation (direct messages)
local function dmView(ctx, view, name)
	local info = infoOf(name)
	local sf = mk("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, -48), ScrollBarThickness = 2, ScrollBarImageColor3 = TH.acc, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, view)
	mk("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, sf)
	pad(sf, 10, 10, 8, 8)
	local lastSig
	local function render()
		local list = HubChat.dm(name)
		local last = list[#list]
		local sig = #list .. ":" .. (last and last.id or "") .. (last and last.state or "")
		if sig == lastSig then return end
		lastSig = sig
		for _, c in ipairs(sf:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
		txt(sf, "Direct messages use the shared YADSAN HUB relay. Anyone technical can read them, so never share passwords.", 9, TH.dim, Enum.Font.Gotham, { Size = UDim2.new(1, 0, 0, 26), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 0 })
		for i, m in ipairs(list) do
			local row = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i }, sf)
			mk("UIListLayout", { HorizontalAlignment = m.mine and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, row)
			local b = mk("Frame", { BackgroundColor3 = m.mine and Color3.new(1, 1, 1) or TH.card, BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(0, 0, 0, 0), LayoutOrder = 1 }, row)
			round(b, 14)
			mk("UISizeConstraint", { MaxSize = Vector2.new(200, math.huge) }, b)
			if m.mine then mk("UIGradient", { Rotation = 35, Color = ColorSequence.new(TH.bubA, TH.bubB) }, b) end
			local tl = mk("TextLabel", { BackgroundTransparency = 1, Text = m.m, TextWrapped = true, TextSize = 13, Font = Enum.Font.GothamMedium, TextColor3 = Color3.new(1, 1, 1), AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(0, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = b.ZIndex + 2 }, b)
			pad(tl, 11, 11, 7, 7)
			mk("UISizeConstraint", { MaxSize = Vector2.new(200, math.huge) }, tl)
			txt(row, (m.state == "failed" and "failed" or os.date("%H:%M", m.t or os.time())), 9, m.state == "failed" and TH.bad or TH.dim, Enum.Font.Gotham, { Size = UDim2.new(0, 0, 0, 11), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2 })
		end
		task.defer(function() if sf.Parent then sf.CanvasPosition = Vector2.new(0, 1e6) end end)
	end
	local bar = mk("Frame", { BackgroundColor3 = TH.bar, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -48), Size = UDim2.new(1, 0, 0, 48) }, view)
	local box = mk("TextBox", { PlaceholderText = "Message " .. info.d .. "...", Text = "", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = TH.text, PlaceholderColor3 = TH.dim, BackgroundColor3 = TH.card2, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -78, 0, 36) }, bar)
	round(box, 18)
	pad(box, 12, 8, 0, 0)
	local send = btn(bar, "Send", true, { Position = UDim2.new(1, -66, 0, 6), Size = UDim2.fromOffset(58, 36), BackgroundColor3 = TH.acc })
	round(send, 18)
	local function go()
		local ok, e = HubChat.send(box.Text, "d", name)
		if ok then box.Text = "" elseif e ~= "empty" then notify("Chat", tostring(e)) end
	end
	send.MouseButton1Click:Connect(go)
	box.FocusLost:Connect(function(enter) if enter then go() end end)
	local fn = function() if ctx.alive and view.Parent then render() end end
	table.insert(HubChat.listeners, fn)
	render()
	return function() dropListener(HubChat.listeners, fn) end
end

-- profile card of another hub user
function profileCard(ctx, view, name)
	local sf = scrollList(view)
	local info = infoOf(name)
	local st = staffInfo(name, info.u)
	local card = mk("Frame", { BackgroundColor3 = st and Color3.fromRGB(14, 8, 22) or TH.card, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 170), LayoutOrder = 1, ClipsDescendants = true }, sf)
	round(card, 16)
	if st then
		local gs = mk("UIStroke", { Thickness = 1.6, Color = Color3.new(1, 1, 1) }, card)
		mk("UIGradient", { Color = ColorSequence.new(st.a, st.b) }, gs)
		pcall(function() NovaUI.MakeBlackhole(card, 150, { Position = UDim2.new(0.5, 0, 0.3, 0), ParticleCount = 6, ZIndex = card.ZIndex + 1 }) end)
	end
	local av = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(72, 72), ZIndex = card.ZIndex + 3 }, card)
	pfp(av, name, info.d, info.u, 72, st or { a = TH.acc, b = TH.bubB })
	local nrow = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 90), Size = UDim2.new(1, 0, 0, 18), ZIndex = card.ZIndex + 3 }, card)
	mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, nrow)
	goldName(nrow, (st and "★ " or "") .. info.d, st, { LayoutOrder = 1, TextSize = 15, Size = UDim2.new(0, 0, 0, 18) })
	if st then titlePill(nrow, st, 2) end
	txt(card, "@" .. name .. "   -   Level " .. tostring(info.lv), 11, TH.dim, Enum.Font.GothamMedium, { Position = UDim2.fromOffset(0, 112), Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = card.ZIndex + 3 })
	txt(card, info.st ~= "" and ('"' .. info.st .. '"') or "No status set", 11, TH.text, Enum.Font.Gotham, { Position = UDim2.fromOffset(10, 130), Size = UDim2.new(1, -20, 0, 28), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = card.ZIndex + 3 })
	local acts = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 }, sf)
	mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, acts)
	local function act(text, primary, fn, order)
		local b = btn(acts, text, primary, { Size = UDim2.new(1, 0, 0, 40), LayoutOrder = order })
		b.MouseButton1Click:Connect(fn)
		return b
	end
	local isF = HubChat.isFriend(name)
	if name ~= lp.Name then
		if isF then
			act("Message", true, function() ctx.push(info.d, function(v) return dmView(ctx, v, name) end) end, 1)
			act("Join their server", false, function()
				local ok, msg = HubChat.joinFriend(name)
				notify(ok and "Join" or "Cannot join", tostring(msg))
			end, 2)
			local rm = act("Remove friend", false, function() end, 3)
			rm.TextColor3 = TH.bad
			rm.MouseButton1Click:Connect(function()
				if rm.Text == "Sure?" then HubChat.unfriend(name) ctx.back() else rm.Text = "Sure?" task.delay(2, function() pcall(function() rm.Text = "Remove friend" end) end) end
			end)
		elseif HubChat.fr.incoming[name] then
			act("Accept friend request", true, function() HubChat.accept(name) ctx.back() end, 1)
			act("Decline", false, function() HubChat.decline(name) ctx.back() end, 2)
		elseif HubChat.fr.outgoing[name] then
			act("Request sent", false, function() end, 1)
		else
			act("Add friend", true, function()
				HubChat.request(name)
				notify("Friends", "Request sent to " .. info.d)
				ctx.back()
			end, 1)
		end
	end
end

local function friendRow(ctx, parent, name, order, sub)
	local info = infoOf(name)
	local st = staffInfo(name, info.u)
	local row = mk("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = st and Color3.fromRGB(14, 8, 22) or TH.card, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = order, ClipsDescendants = true }, parent)
	round(row, 12)
	if st then
		local gs = mk("UIStroke", { Thickness = 1.3, Color = Color3.new(1, 1, 1) }, row)
		mk("UIGradient", { Color = ColorSequence.new(st.a, st.b) }, gs)
	end
	local av = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 9), Size = UDim2.fromOffset(34, 34), ZIndex = row.ZIndex + 2 }, row)
	pfp(av, name, info.d, info.u, 34, st)
	local dot = mk("Frame", { BackgroundColor3 = HubChat.online(name) and Color3.fromRGB(70, 220, 120) or Color3.fromRGB(110, 110, 120), BorderSizePixel = 0, Position = UDim2.fromOffset(34, 34), Size = UDim2.fromOffset(11, 11), ZIndex = row.ZIndex + 4 }, row)
	round(dot, 6)
	mk("UIStroke", { Color = TH.card, Thickness = 2 }, dot)
	local nm = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(54, 8), Size = UDim2.new(1, -70, 0, 16), ZIndex = row.ZIndex + 2 }, row)
	mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, nm)
	goldName(nm, (st and "★ " or "") .. info.d, st, { LayoutOrder = 1, TextSize = 13 })
	if st then titlePill(nm, st, 2) end
	pill(nm, "LV " .. tostring(info.lv), Color3.fromRGB(190, 160, 255), 3)
	txt(row, sub or (info.st ~= "" and info.st or ("@" .. name)), 10, TH.dim, Enum.Font.Gotham, { Position = UDim2.fromOffset(54, 27), Size = UDim2.new(1, -70, 0, 14), ZIndex = row.ZIndex + 2, TextTruncate = Enum.TextTruncate.AtEnd })
	row.MouseButton1Click:Connect(function()
		ctx.push(info.d, function(v) profileCard(ctx, v, name) end)
	end)
	return row
end

local function friendsPage(ctx, body)
	local holder = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, body)
	local function build()
		for _, c in ipairs(holder:GetChildren()) do c:Destroy() end
		local sf = scrollList(holder)
		local fr = HubChat.fr
		local nInc = 0
		for _ in pairs(fr.incoming) do nInc = nInc + 1 end
		local nFr = 0
		for _ in pairs(fr.friends) do nFr = nFr + 1 end
		ctx.setSub(nFr .. " friends  -  " .. nInc .. " requests")
		local order = 0
		local function nextO() order = order + 1 return order end
		-- add by username
		local addRow = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = nextO() }, sf)
		local box = mk("TextBox", { PlaceholderText = "Add friend by username...", Text = "", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = TH.text, PlaceholderColor3 = TH.dim, BackgroundColor3 = TH.card, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -70, 1, 0) }, addRow)
		round(box, 18)
		pad(box, 14, 8, 0, 0)
		local addB = btn(addRow, "Add", true, { Position = UDim2.new(1, -62, 0, 0), Size = UDim2.fromOffset(62, 36) })
		round(addB, 18)
		local function doAdd()
			local n = box.Text:gsub("[%s@]", "")
			if n == "" then return end
			local canon = n
			for name in pairs(HubChat.presence) do if name:lower() == n:lower() then canon = name end end
			if canon:lower() == lp.Name:lower() then notify("Friends", "That is you") return end
			HubChat.request(canon)
			box.Text = ""
			notify("Friends", "Request sent to " .. canon .. " (works if they use YADSAN HUB)")
		end
		addB.MouseButton1Click:Connect(doAdd)
		box.FocusLost:Connect(function(enter) if enter then doAdd() end end)
		if nInc > 0 then
			txt(sf, "FRIEND REQUESTS", 11, TH.dim, Enum.Font.GothamBold, { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = nextO() })
			for n in pairs(fr.incoming) do friendRow(ctx, sf, n, nextO(), "wants to be your friend - tap to answer") end
		end
		txt(sf, "FRIENDS", 11, TH.dim, Enum.Font.GothamBold, { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = nextO() })
		local names = {}
		for n in pairs(fr.friends) do names[#names + 1] = n end
		table.sort(names, function(a, b)
			local oa, ob = HubChat.online(a) and 1 or 0, HubChat.online(b) and 1 or 0
			if oa ~= ob then return oa > ob end
			return a:lower() < b:lower()
		end)
		if #names == 0 then
			txt(sf, "No friends yet. Tap someone in the list below, or add a username above.", 11, TH.dim, Enum.Font.Gotham, { Size = UDim2.new(1, 0, 0, 30), TextWrapped = true, LayoutOrder = nextO() })
		end
		for _, n in ipairs(names) do friendRow(ctx, sf, n, nextO()) end
		txt(sf, "ONLINE NOW (HUB USERS)", 11, TH.dim, Enum.Font.GothamBold, { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = nextO() })
		local cnt = 0
		for _, u in ipairs(HubChat.allUsers()) do
			if u.n ~= lp.Name and not fr.friends[u.n] and not fr.incoming[u.n] and cnt < 25 then
				cnt = cnt + 1
				friendRow(ctx, sf, u.n, nextO())
			end
		end
		if cnt == 0 then
			txt(sf, "Nobody else seen yet.", 11, TH.dim, Enum.Font.Gotham, { Size = UDim2.new(1, 0, 0, 20), LayoutOrder = nextO() })
		end
	end
	build()
	local lastSig = ""
	local fn = function()
		if not (ctx.alive and holder.Parent) then return end
		local sig = HttpService:JSONEncode({ HubChat.fr.friends, HubChat.fr.incoming, #HubChat.allUsers() })
		if sig ~= lastSig then lastSig = sig build() end
	end
	table.insert(HubChat.listeners, fn)
	return function() dropListener(HubChat.listeners, fn) end
end

local function myProfilePage(ctx, body)
	ctx.setSub("how other hub users see you")
	local sf = scrollList(body)
	local st = staffInfo(lp.Name, lp.UserId)
	local card = mk("Frame", { BackgroundColor3 = st and Color3.fromRGB(14, 8, 22) or TH.card, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 150), LayoutOrder = 1, ClipsDescendants = true }, sf)
	round(card, 16)
	if st then
		local gs = mk("UIStroke", { Thickness = 1.6, Color = Color3.new(1, 1, 1) }, card)
		mk("UIGradient", { Color = ColorSequence.new(st.a, st.b) }, gs)
	end
	local av = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(72, 72), ZIndex = card.ZIndex + 2 }, card)
	pfp(av, lp.Name, lp.DisplayName, lp.UserId, 72, st or { a = TH.acc, b = TH.bubB })
	local nameL = txt(card, HubChat.myName(), 16, TH.text, Enum.Font.GothamBlack, { Position = UDim2.fromOffset(0, 90), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = card.ZIndex + 2 })
	local lv = 1
	pcall(function() lv = NovaUI.Profile.level() end)
	local nFr = 0
	for _ in pairs(HubChat.fr.friends) do nFr = nFr + 1 end
	txt(card, "@" .. lp.Name .. "   -   Level " .. lv .. "   -   " .. nFr .. " friends", 11, TH.dim, Enum.Font.GothamMedium, { Position = UDim2.fromOffset(0, 112), Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = card.ZIndex + 2 })
	txt(card, (HubChat.me.st ~= "") and ('"' .. HubChat.me.st .. '"') or "No status set", 11, TH.text, Enum.Font.Gotham, { Position = UDim2.fromOffset(10, 128), Size = UDim2.new(1, -20, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = card.ZIndex + 2 })
	txt(sf, "YOUR HUB NAME", 11, TH.dim, Enum.Font.GothamBold, { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2 })
	local nb = mk("TextBox", { Text = HubChat.me.hn, PlaceholderText = "Shown in chat (empty = " .. lp.DisplayName .. ")", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = TH.text, PlaceholderColor3 = TH.dim, BackgroundColor3 = TH.card, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 3 }, sf)
	round(nb, 12)
	pad(nb, 12, 8, 0, 0)
	txt(sf, "STATUS", 11, TH.dim, Enum.Font.GothamBold, { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 4 })
	local sb = mk("TextBox", { Text = HubChat.me.st, PlaceholderText = "What are you up to?", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = TH.text, PlaceholderColor3 = TH.dim, BackgroundColor3 = TH.card, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 5 }, sf)
	round(sb, 12)
	pad(sb, 12, 8, 0, 0)
	local save = btn(sf, "Save profile", true, { Size = UDim2.new(1, 0, 0, 42), LayoutOrder = 6 })
	save.MouseButton1Click:Connect(function()
		local hn = nb.Text:gsub("[%c]", ""):gsub("^%s+", ""):gsub("%s+$", "")
		local ok, why = nameOk(hn)
		if not ok then notify("Profile", why) return end
		HubChat.setProfile(hn, sb.Text)
		nameL.Text = HubChat.myName()
		notify("Profile", "Saved. Other hub users will see it.")
	end)
	txt(sf, "Your profile picture is your Roblox avatar headshot. Name and status are saved in YADSAN_HUB/hub_profile.json.", 10, TH.dim, Enum.Font.Gotham, { Size = UDim2.new(1, 0, 0, 30), TextWrapped = true, LayoutOrder = 7 })
end

function ChatApp.build(ctx)
	ctx.push("Hub Chat", function(view)
		local t = tabbed(ctx, view, { "Chat", "Friends", "Profile", "Settings" }, {
			Chat = function(body) return chatPage(ctx, body) end,
			Friends = function(body) return friendsPage(ctx, body) end,
			Profile = function(body) return myProfilePage(ctx, body) end,
			Settings = function(body)
				ctx.setSub("make the app yours")
				settingsPage(body, ChatApp, "Settings", function(sf)
					txt(sf, "CHAT", 11, TH.dim, Enum.Font.GothamBold, { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 10 })
					local row = mk("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = TH.card, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 11 }, sf)
					round(row, 12)
					txt(row, "New message sound", 13, TH.text, Enum.Font.GothamMedium, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -90, 1, 0) })
					local pillB = btn(row, HubChat.muted and "OFF" or "ON", not HubChat.muted, { Position = UDim2.new(1, -62, 0.5, -14), Size = UDim2.fromOffset(52, 28), TextSize = 12, BackgroundColor3 = HubChat.muted and TH.card2 or TH.acc })
					pillB.MouseButton1Click:Connect(function()
						HubChat.muted = not HubChat.muted
						pillB.Text = HubChat.muted and "OFF" or "ON"
						pillB.BackgroundColor3 = HubChat.muted and TH.card2 or TH.acc
					end)
				end)
				return nil
			end,
		}, ctx.startTab)
		return function() t.close() end
	end)
end

------------------------------------------------------------------------
-- Fit Saver app
------------------------------------------------------------------------
local FitApp = { id = "Fits", title = "Fit Saver", icon = "shirt" }
function FitApp.build(ctx)
	ctx.push("Fit Saver", function(view)
		ctx.setSub("your outfits, saved as files")
		local tabBar = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38) }, view)
		mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center }, tabBar)
		pad(tabBar, 10, 10, 4, 2)
		local body = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 1, -38), ClipsDescendants = true }, view)
		local tabs, active = {}, nil
		local select
		local nameBox
		local function scroller()
			for _, c in ipairs(body:GetChildren()) do c:Destroy() end
			local sf = mk("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ScrollBarThickness = 2, ScrollBarImageColor3 = TH.acc, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, body)
			mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, sf)
			pad(sf, 10, 10, 6, 10)
			return sf
		end
		local function thumb(parent, id, x, size)
			local img = mk("ImageLabel", { BackgroundColor3 = TH.card2, BorderSizePixel = 0, Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(size, size), Image = ("rbxthumb://type=Asset&id=%.0f&w=150&h=150"):format(id), ScaleType = Enum.ScaleType.Fit }, parent)
			round(img, 6)
			return img
		end
		local FAVF = "YADSAN_HUB/fit_favs.txt"
		local favs = {}
		pcall(function()
			if isfile and isfile(FAVF) then
				for n in readfile(FAVF):gmatch("[^\r\n]+") do favs[n] = true end
			end
		end)
		local function saveFavs()
			pcall(function()
				pcall(makefolder, "YADSAN_HUB")
				local t = {}
				for n in pairs(favs) do t[#t + 1] = n end
				writefile(FAVF, table.concat(t, "\n"))
			end)
		end
		local function savedTab()
			local sf = scroller()
			local names = FitStore.names()
			table.sort(names, function(a, b)
				if (favs[a] and 1 or 0) ~= (favs[b] and 1 or 0) then return favs[a] end
				return a:lower() < b:lower()
			end)
			local search = mk("TextBox", { PlaceholderText = "Search fits (" .. #names .. ")", Text = "", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = TH.text, PlaceholderColor3 = TH.dim, BackgroundColor3 = TH.card, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 0 }, sf)
			round(search, 16)
			pad(search, 14, 10, 0, 0)
			local cards = {}
			if #names == 0 then
				txt(sf, "No saved fits yet.\nUse the Save tab to save your outfit, or the Players tab to save someone else's.", 12, TH.dim, Enum.Font.GothamMedium, { Size = UDim2.new(1, 0, 0, 70), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1 })
			end
			for i, name in ipairs(names) do
				local d = FitStore.get(name)
				local fav = favs[name]
				local card = mk("Frame", { BackgroundColor3 = TH.card, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 150), LayoutOrder = i }, sf)
				cards[name] = card
				round(card, 14)
				local cs = mk("UIStroke", { Color = fav and Color3.fromRGB(255, 200, 70) or TH.acc, Transparency = fav and 0.1 or 0.7, Thickness = fav and 1.6 or 1 }, card)
				mk("UIGradient", { Rotation = 90, Color = ColorSequence.new(TH.cardA, TH.cardB) }, card)
				txt(card, name, 14, fav and Color3.fromRGB(255, 222, 130) or TH.text, Enum.Font.GothamBold, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -56, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
				local star = btn(card, fav and "*" or "+", false, { Position = UDim2.new(1, -40, 0, 4), Size = UDim2.fromOffset(30, 24), TextSize = 16, BackgroundColor3 = fav and Color3.fromRGB(255, 190, 60) or TH.card2, TextColor3 = fav and Color3.fromRGB(40, 20, 0) or TH.text })
				star.MouseButton1Click:Connect(function()
					favs[name] = (not favs[name]) or nil
					saveFavs()
					select("Saved")
				end)
				txt(card, (d.count or 0) .. " items  -  from " .. tostring(d.from or d.by or "?") .. "  -  " .. os.date("%d %b", d.saved or os.time()), 10, TH.dim, Enum.Font.Gotham, { Position = UDim2.fromOffset(10, 25), Size = UDim2.new(1, -20, 0, 12) })
				local strip = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 44), Size = UDim2.new(1, -20, 0, 42) }, card)
				local nT = 0
				for _, it in ipairs(d.items or {}) do
					if it.kind == "acc" and nT < 6 then
						thumb(strip, it.id, nT * 46, 42)
						nT = nT + 1
					end
				end
				local wear = btn(card, "Wear", true, { Position = UDim2.fromOffset(10, 96), Size = UDim2.new(0.42, -10, 0, 40) })
				local ids = btn(card, "Copy IDs", false, { Position = UDim2.new(0.42, 2, 0, 96), Size = UDim2.new(0.34, -4, 0, 40), TextSize = 11 })
				local del = btn(card, "Delete", false, { Position = UDim2.new(0.76, 2, 0, 96), Size = UDim2.new(0.24, -12, 0, 40), TextSize = 11, TextColor3 = TH.bad })
				local busy = false
				wear.MouseButton1Click:Connect(function()
					if busy then return end
					busy = true
					task.spawn(function()
						local ok, msg = FitStore.wear(name, function(a, n) pcall(function() wear.Text = a .. "/" .. n end) end)
						pcall(function() wear.Text = "Wear" end)
						busy = false
						notify(ok and "Fit worn" or "Fit failed", ok and (name .. ": " .. tostring(msg)) or tostring(msg))
					end)
				end)
				ids.MouseButton1Click:Connect(function()
					notify("Fit Saver", FitStore.copyIds(name) and "Item IDs copied" or "Clipboard not available")
				end)
				del.MouseButton1Click:Connect(function()
					if del.Text == "Sure?" then
						favs[name] = nil
						FitStore.delete(name)
					else
						del.Text = "Sure?"
						task.delay(2, function() pcall(function() del.Text = "Delete" end) end)
					end
				end)
			end
			search:GetPropertyChangedSignal("Text"):Connect(function()
				local q = search.Text:lower()
				for n, c in pairs(cards) do
					c.Visible = q == "" or n:lower():find(q, 1, true) ~= nil
				end
			end)
		end
		local function saveTab()
			local sf = scroller()
			local card = mk("Frame", { BackgroundColor3 = TH.card, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 150), LayoutOrder = 1 }, sf)
			round(card, 12)
			txt(card, "Save your current outfit", 14, TH.text, Enum.Font.GothamBold, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 18) })
			nameBox = mk("TextBox", { PlaceholderText = "Fit name", Text = "", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = TH.text, PlaceholderColor3 = TH.dim, BackgroundColor3 = TH.card2, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 36) }, card)
			round(nameBox, 9)
			pad(nameBox, 10, 8, 0, 0)
			local save = btn(card, "Save my fit", true, { Position = UDim2.fromOffset(12, 78), Size = UDim2.new(1, -24, 0, 36) })
			txt(card, "Saved as YADSAN_HUB/fits/<name>.json in your executor folder", 10, TH.dim, Enum.Font.Gotham, { Position = UDim2.fromOffset(12, 120), Size = UDim2.new(1, -24, 0, 24), TextWrapped = true })
			save.MouseButton1Click:Connect(function()
				local d = FitStore.saveMine()
				if not d then notify("Fit Saver", "Character not loaded") return end
				local n = tostring(nameBox.Text):gsub("^%s+", ""):gsub("%s+$", "")
				local ok, msg = FitStore.save(n ~= "" and n or ("My fit " .. os.date("%H:%M:%S")), d, lp.Name)
				notify("Fit Saver", tostring(msg))
				if ok then nameBox.Text = "" end
			end)
		end
		local function playersTab()
			local sf = scroller()
			local any = false
			for i, p in ipairs(Players:GetPlayers()) do
				if p ~= lp then
					any = true
					local row = mk("Frame", { BackgroundColor3 = TH.card, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = i }, sf)
					round(row, 12)
					local av = mk("ImageLabel", { BackgroundColor3 = TH.card2, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(36, 36), Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=100&h=100"):format(p.UserId) }, row)
					round(av, 18)
					txt(row, p.DisplayName, 13, TH.text, Enum.Font.GothamBold, { Position = UDim2.fromOffset(52, 6), Size = UDim2.new(1, -170, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
					txt(row, "@" .. p.Name, 10, TH.dim, Enum.Font.Gotham, { Position = UDim2.fromOffset(52, 24), Size = UDim2.new(1, -170, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd })
					local cp = btn(row, "Copy", true, { Position = UDim2.new(1, -110, 0, 10), Size = UDim2.fromOffset(52, 32), TextSize = 12 })
					local sv = btn(row, "Save", false, { Position = UDim2.new(1, -54, 0, 10), Size = UDim2.fromOffset(46, 32), TextSize = 12 })
					cp.MouseButton1Click:Connect(function()
						task.spawn(function()
							cp.Text = "..."
							local ok, d = copyAvatar(p)
							pcall(function() cp.Text = "Copy" end)
							notify(ok and "Copy Avatar" or "Copy Avatar failed", ok and (p.DisplayName .. ": " .. tostring(d)) or tostring(d))
						end)
					end)
					sv.MouseButton1Click:Connect(function()
						local th = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
						local okd, d = pcall(function() return th and th:GetAppliedDescription() end)
						if not okd or not d then notify("Fit Saver", "Could not read their outfit") return end
						if optedOut(p) then notify("Fit Saver", p.DisplayName .. " hides their outfit") return end
						local ok, msg = FitStore.save(p.DisplayName, d, lp.Name, p.Name, p.Character)
						notify("Fit Saver", tostring(msg))
					end)
				end
			end
			if not any then
				txt(sf, "Nobody else is in the server.", 13, TH.dim, Enum.Font.GothamMedium, { Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Center })
			end
		end
		local pages = { Saved = savedTab, Save = saveTab, Players = playersTab, Settings = function()
			for _, c in ipairs(body:GetChildren()) do c:Destroy() end
			ctx.setSub("make the app yours")
			settingsPage(body, FitApp, "Settings")
		end }
		function select(n)
			active = n
			for k, b in pairs(tabs) do
				b.BackgroundColor3 = (k == n) and TH.acc or TH.card
			end
			pages[n]()
		end
		for _, n in ipairs({ "Saved", "Save", "Players", "Settings" }) do
			local b = btn(tabBar, n, false, { Size = UDim2.new(1 / 4, -5, 1, 0), BackgroundColor3 = TH.card, TextSize = 12 })
			tabs[n] = b
			b.MouseButton1Click:Connect(function() select(n) end)
		end
		local fn = function()
			if ctx.alive and view.Parent and active == "Saved" then select("Saved") end
		end
		FitStore.onChange(fn)
		select(ctx.startTab or (#FitStore.names() > 0 and "Saved" or "Save"))
		return function() dropListener(FitStore.listeners, fn) end
	end)
end

------------------------------------------------------------------------
-- Music: search (Deezer = 30s previews, no key; Jamendo = full indie songs, free client_id) and play in-game.
-- Tracks are cached in YADSAN_HUB/music/ and played from there with getcustomasset. Only you hear it.
------------------------------------------------------------------------
local Music = { queue = {}, idx = 0, state = "idle", vol = 0.6, listeners = {}, favs = {}, recent = {}, lists = {}, note = "", shuffle = false, rep = 0, eq = 1, sleepAt = nil, covers = {} }
local MUSIC_EQ = {
	{ "Flat", 0, 0, 0 }, { "Bass boost", 8, 0, -2 }, { "Vocal", -4, 6, 2 }, { "Treble", -3, 0, 8 }, { "Party", 6, -2, 6 },
}
do
	-- NOTE: the chat module has its own local "request" (returns code, body), so use the executor's real function
	local genv = (getgenv and getgenv()) or {}
	local httpReq = (syn and syn.request) or http_request or genv.http_request or genv.request or (http and http.request) or (fluxus and fluxus.request)
	local DIR, FAVF, JID = "YADSAN_HUB/music", "YADSAN_HUB/music_favs.json", "YADSAN_HUB/jamendo_id.txt"
	local RECF, LISTF, SETF = "YADSAN_HUB/music_recent.json", "YADSAN_HUB/music_lists.json", "YADSAN_HUB/music_set.json"
	local function jload(f, def)
		local v = def
		pcall(function()
			if isfile and isfile(f) then
				local d = HttpService:JSONDecode(readfile(f))
				if type(d) == "table" then v = d end
			end
		end)
		return v
	end
	local function jsave(f, v)
		pcall(function()
			pcall(makefolder, "YADSAN_HUB")
			writefile(f, HttpService:JSONEncode(v))
		end)
	end
	Music.favs, Music.recent, Music.lists = jload(FAVF, {}), jload(RECF, {}), jload(LISTF, {})
	local st0 = jload(SETF, {})
	if type(st0.vol) == "number" then Music.vol = math.clamp(st0.vol, 0, 1) end
	if type(st0.eq) == "number" and MUSIC_EQ[st0.eq] then Music.eq = st0.eq end
	if st0.shuffle == true then Music.shuffle = true end
	if type(st0.rep) == "number" then Music.rep = st0.rep % 3 end
	local function saveSet() jsave(SETF, { vol = Music.vol, eq = Music.eq, shuffle = Music.shuffle, rep = Music.rep }) end
	local sound = Instance.new("Sound")
	sound.Name = "YadsanMusic"
	sound.Volume = Music.vol
	sound.Parent = game:GetService("SoundService")
	Music.sound = sound
	local eqfx = Instance.new("EqualizerSoundEffect")
	eqfx.Parent = sound
	local function applyEq()
		local e = MUSIC_EQ[Music.eq]
		eqfx.LowGain, eqfx.MidGain, eqfx.HighGain = e[2], e[3], e[4]
	end
	applyEq()
	local function fire() for _, f in ipairs(Music.listeners) do pcall(f) end end
	Music.fire = fire
	Music.lastErr = ""
	local function get(url)
		Music.lastErr = ""
		if httpReq then
			local ok, r = pcall(httpReq, { Url = url, Method = "GET" })
			if ok and type(r) == "table" then
				if (r.StatusCode == 200 or r.Success) and r.Body and #r.Body > 0 then return r.Body end
				Music.lastErr = "HTTP " .. tostring(r.StatusCode)
			else
				Music.lastErr = tostring(r):sub(1, 60)
			end
		else
			Music.lastErr = "no request function"
		end
		local ok, body = pcall(function() return game:HttpGet(url) end)
		if ok and type(body) == "string" and #body > 0 then return body end
		if not ok then Music.lastErr = Music.lastErr .. " / " .. tostring(body):sub(1, 60) end
		return nil
	end
	function Music.check()
		local out = {}
		out[#out + 1] = "request fn: " .. (httpReq and "yes" or "NO") .. "  |  HttpGet: yes"
		out[#out + 1] = "getcustomasset: " .. ((getcustomasset and "yes") or "NO") .. "  writefile: " .. ((writefile and "yes") or "NO")
		local b = get("https://api.deezer.com/search?q=arijit&limit=1")
		out[#out + 1] = "Deezer search: " .. (b and "OK" or ("FAILED (" .. Music.lastErr .. ")"))
		local url
		pcall(function() url = HttpService:JSONDecode(b).data[1].preview end)
		if url then
			local mp = get(url)
			out[#out + 1] = "Preview download: " .. (mp and (#mp .. " bytes OK") or ("FAILED (" .. Music.lastErr .. ")"))
		end
		return table.concat(out, "\n")
	end
	function Music.jamendoId()
		local v = (YADSAN_JAMENDO_ID and tostring(YADSAN_JAMENDO_ID)) or ""
		pcall(function()
			if v == "" and isfile and isfile(JID) then v = readfile(JID):gsub("%s+", "") end
		end)
		return v
	end
	function Music.setJamendoId(v)
		pcall(function()
			pcall(makefolder, "YADSAN_HUB")
			writefile(JID, tostring(v or ""):gsub("%s+", ""))
		end)
	end
	local function dz(t)
		return { src = "dz", id = tostring(t.id), title = t.title, artist = t.artist and t.artist.name or "?", url = t.preview, note = "30s preview", cover = t.album and (t.album.cover_medium or t.album.cover) or nil, dur = 30 }
	end
	function Music.search(q)
		local out, errs = {}, {}
		local enc = HttpService:UrlEncode(q)
		local body = get("https://api.deezer.com/search?q=" .. enc .. "&limit=25")
		if body then
			pcall(function()
				for _, t in ipairs(HttpService:JSONDecode(body).data or {}) do
					if t.preview and t.preview ~= "" then out[#out + 1] = dz(t) end
				end
			end)
		else
			errs[#errs + 1] = "Deezer not reachable (" .. Music.lastErr .. ")"
		end
		local jid = Music.jamendoId()
		if jid ~= "" then
			local jb = get("https://api.jamendo.com/v3.0/tracks/?client_id=" .. jid .. "&format=json&limit=15&audioformat=mp31&search=" .. enc)
			if jb then
				pcall(function()
					for _, t in ipairs(HttpService:JSONDecode(jb).results or {}) do
						if t.audio and t.audio ~= "" then
							out[#out + 1] = { src = "jm", id = tostring(t.id), title = t.name, artist = t.artist_name or "?", url = t.audio, note = "full song", cover = t.image, dur = tonumber(t.duration) }
						end
					end
				end)
			else
				errs[#errs + 1] = "Jamendo not reachable (check client id)"
			end
		end
		return out, errs
	end
	-- recommended mix: a few songs from several popular searches, interleaved
	function Music.forYou()
		if Music._fy and os.clock() - (Music._fyT or 0) < 1800 then return Music._fy end
		local qs = { "bollywood hits", "arijit singh", "punjabi songs", "english pop hits", "rap hits", "lofi hindi", "romantic hindi songs", "edm party" }
		local res, pending = {}, #qs
		for i, q in ipairs(qs) do
			task.spawn(function()
				local ok, l = pcall(Music.search, q)
				res[i] = ok and l or {}
				pending = pending - 1
			end)
		end
		local t0 = os.clock()
		while pending > 0 and os.clock() - t0 < 14 do task.wait(0.1) end
		local out, seen = {}, {}
		for r = 1, 5 do
			for i = 1, #qs do
				local t = res[i] and res[i][r]
				if t and not seen[t.src .. t.id] then
					seen[t.src .. t.id] = true
					out[#out + 1] = t
				end
			end
		end
		if #out == 0 then out = Music.chart() end
		if #out > 0 then Music._fy, Music._fyT = out, os.clock() end
		return out
	end
	function Music.chart()
		local out = {}
		local body = get("https://api.deezer.com/chart/0/tracks?limit=30")
		if body then
			pcall(function()
				for _, t in ipairs(HttpService:JSONDecode(body).data or {}) do
					if t.preview and t.preview ~= "" then out[#out + 1] = dz(t) end
				end
			end)
		end
		return out
	end
	-- cover art: downloaded once, shown through getcustomasset
	function Music.cover(t, cb)
		if not (t and t.cover and getcustomasset and writefile and isfile) then return end
		local key = t.src .. "_" .. t.id
		if Music.covers[key] then return cb(Music.covers[key]) end
		task.spawn(function()
			pcall(makefolder, "YADSAN_HUB")
			pcall(makefolder, DIR)
			local path = ("%s/c_%s.jpg"):format(DIR, key:gsub("[^%w_]", ""))
			if not isfile(path) then
				local b = get(t.cover)
				if not b then return end
				pcall(writefile, path, b)
			end
			local ok, a = pcall(getcustomasset, path)
			if ok then
				Music.covers[key] = a
				cb(a)
			end
		end)
	end
	local function same(a, b) return a.src == b.src and a.id == b.id end
	local function slim(t) return { src = t.src, id = t.id, title = t.title, artist = t.artist, url = t.url, note = t.note, cover = t.cover, dur = t.dur } end
	function Music.isFav(t)
		for _, f in ipairs(Music.favs) do if same(f, t) then return true end end
		return false
	end
	function Music.toggleFav(t)
		for i, f in ipairs(Music.favs) do
			if same(f, t) then
				table.remove(Music.favs, i)
				jsave(FAVF, Music.favs)
				fire()
				return false
			end
		end
		Music.favs[#Music.favs + 1] = slim(t)
		jsave(FAVF, Music.favs)
		fire()
		return true
	end
	-- playlists: Music.lists = { { name = "...", tracks = { ... } } }
	function Music.newList(name)
		name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", ""):sub(1, 24)
		if name == "" then return nil end
		for _, l in ipairs(Music.lists) do if l.name:lower() == name:lower() then return l end end
		local l = { name = name, tracks = {} }
		Music.lists[#Music.lists + 1] = l
		jsave(LISTF, Music.lists)
		return l
	end
	function Music.addToList(l, t)
		for _, x in ipairs(l.tracks) do if same(x, t) then return false end end
		l.tracks[#l.tracks + 1] = slim(t)
		jsave(LISTF, Music.lists)
		return true
	end
	function Music.delList(l)
		for i, x in ipairs(Music.lists) do if x == l then table.remove(Music.lists, i) end end
		jsave(LISTF, Music.lists)
	end
	local function pushRecent(t)
		for i, r in ipairs(Music.recent) do if same(r, t) then table.remove(Music.recent, i) break end end
		table.insert(Music.recent, 1, slim(t))
		while #Music.recent > 30 do table.remove(Music.recent) end
		jsave(RECF, Music.recent)
	end
	local token = 0
	function Music.play(list, i)
		Music.queue, Music.idx = list, i
		local t = list[i]
		if not t then return end
		token = token + 1
		local my = token
		sound:Stop()
		Music.state, Music.note = "loading", ""
		pushRecent(t)
		fire()
		task.spawn(function()
			if not (getcustomasset and writefile and isfile) then
				Music.state, Music.note = "error", "This executor has no getcustomasset/writefile"
				return fire()
			end
			pcall(makefolder, "YADSAN_HUB")
			pcall(makefolder, DIR)
			local path = ("%s/%s_%s.mp3"):format(DIR, t.src, t.id:gsub("[^%w]", ""))
			if not isfile(path) then
				local body = get(t.url)
				if not body then
					Music.state, Music.note = "error", "Download failed (" .. Music.lastErr .. ")"
					return fire()
				end
				pcall(writefile, path, body)
			end
			if my ~= token then return end
			local ok, asset = pcall(getcustomasset, path)
			if not ok then
				Music.state, Music.note = "error", "getcustomasset failed"
				return fire()
			end
			sound.SoundId = asset
			local w0 = os.clock()
			while not sound.IsLoaded and os.clock() - w0 < 8 and my == token do task.wait(0.1) end
			if my ~= token then return end
			if not sound.IsLoaded then
				Music.state, Music.note = "error", "Audio would not load in this executor"
				return fire()
			end
			sound:Play()
			Music.state = "playing"
			fire()
		end)
	end
	function Music.toggle()
		if Music.state == "playing" then sound:Pause() Music.state = "paused"
		elseif Music.state == "paused" then sound:Resume() Music.state = "playing"
		elseif Music.idx > 0 then Music.play(Music.queue, Music.idx) end
		fire()
	end
	function Music.step(d, auto)
		local n = #Music.queue
		if n == 0 then return end
		local i = Music.idx + d
		if Music.shuffle and n > 1 then
			repeat i = math.random(1, n) until i ~= Music.idx
		elseif i > n then i = 1 elseif i < 1 then i = n end
		Music.play(Music.queue, i)
	end
	function Music.stop() token = token + 1 sound:Stop() Music.state = "idle" fire() end
	function Music.setVol(v) Music.vol = math.clamp(v, 0, 1) sound.Volume = Music.vol saveSet() fire() end
	function Music.seek(f)
		if sound.TimeLength > 0 then sound.TimePosition = math.clamp(f, 0, 1) * sound.TimeLength end
	end
	function Music.toggleShuffle() Music.shuffle = not Music.shuffle saveSet() fire() end
	function Music.cycleRepeat() Music.rep = (Music.rep + 1) % 3 saveSet() fire() end
	function Music.cycleEq() Music.eq = Music.eq % #MUSIC_EQ + 1 applyEq() saveSet() fire() return MUSIC_EQ[Music.eq][1] end
	local stok = 0
	function Music.setSleep(min)
		stok = stok + 1
		local my = stok
		if not min then Music.sleepAt = nil return fire() end
		Music.sleepAt = os.clock() + min * 60
		task.delay(min * 60, function()
			if my == stok then Music.sleepAt = nil Music.stop() notify("Music", "Sleep timer: music stopped") end
		end)
		fire()
	end
	function Music.clearCache()
		local n = 0
		pcall(function()
			for _, f in ipairs(listfiles(DIR)) do
				if delfile then pcall(delfile, f) n = n + 1 end
			end
		end)
		Music.covers = {}
		return n
	end
	sound.Ended:Connect(function()
		if Music.state ~= "playing" then return end
		if Music.rep == 2 then
			sound.TimePosition = 0
			sound:Play()
		elseif Music.rep == 0 and not Music.shuffle and Music.idx >= #Music.queue then
			Music.state = "paused"
			fire()
		else
			Music.step(1, true)
		end
	end)
end
local function fmtTime(s)
	s = math.max(0, math.floor(s or 0))
	return ("%d:%02d"):format(s // 60, s % 60)
end
-- horizontal slider / seek bar: tap or drag
local function slider(parent, props, onSet)
	local bg = mk("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = TH.card2, BorderSizePixel = 0 }, parent)
	for k, v in pairs(props) do bg[k] = v end
	round(bg, 8)
	local fill = mk("Frame", { BackgroundColor3 = TH.acc, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) }, bg)
	round(fill, 8)
	local knob = mk("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(12, 12) }, bg)
	round(knob, 6)
	local UIS = game:GetService("UserInputService")
	local drag = false
	local function upd(x)
		local f = math.clamp((x - bg.AbsolutePosition.X) / math.max(1, bg.AbsoluteSize.X), 0, 1)
		onSet(f)
	end
	bg.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			drag = true
			upd(i.Position.X)
		end
	end)
	local c1 = UIS.InputChanged:Connect(function(i)
		if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then upd(i.Position.X) end
	end)
	local c2 = UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = false end
	end)
	bg.Destroying:Connect(function() c1:Disconnect() c2:Disconnect() end)
	return function(f)
		fill.Size = UDim2.fromScale(f, 1)
		knob.Position = UDim2.fromScale(f, 0.5)
	end, bg
end

local MusicApp = { id = "Music", title = "Music", icon = "music" }
local function trackRow(parent, list, i, order, onAfter)
	local t = list[i]
	local row = mk("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = TH.card, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 54), LayoutOrder = order }, parent)
	round(row, 12)
	local cur = Music.queue[Music.idx]
	local isCur = cur and cur.src == t.src and cur.id == t.id
	if isCur then mk("UIStroke", { Color = TH.acc, Thickness = 1.5 }, row) end
	local art = mk("ImageLabel", { BackgroundColor3 = TH.card2, BorderSizePixel = 0, Position = UDim2.fromOffset(7, 7), Size = UDim2.fromOffset(40, 40), ScaleType = Enum.ScaleType.Crop }, row)
	round(art, 8)
	local ph = txt(art, isCur and ">" or tostring(i), 13, TH.dim, Enum.Font.GothamBold, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	if t.cover then Music.cover(t, function(a) if art.Parent then art.Image = a ph.Visible = false end end) end
	txt(row, t.title, 13, TH.text, Enum.Font.GothamBold, { Position = UDim2.fromOffset(56, 8), Size = UDim2.new(1, -108, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
	txt(row, t.artist .. "  -  " .. (t.note or ""), 10, TH.dim, Enum.Font.Gotham, { Position = UDim2.fromOffset(56, 28), Size = UDim2.new(1, -108, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd })
	local function favStyle(b, on)
		b.Text = on and "<3" or "+"
		b.BackgroundColor3 = on and Color3.fromRGB(255, 90, 140) or TH.card2
		b.TextColor3 = on and Color3.new(1, 1, 1) or TH.text
	end
	local star = btn(row, "+", false, { Position = UDim2.new(1, -44, 0.5, -14), Size = UDim2.fromOffset(34, 28), TextSize = 13 })
	round(star, 14)
	favStyle(star, Music.isFav(t))
	star.MouseButton1Click:Connect(function()
		favStyle(star, Music.toggleFav(t))
		if onAfter then onAfter() end
	end)
	row.MouseButton1Click:Connect(function() Music.play(list, i) end)
end
local function musicList(body, list, emptyText, header)
	local sf = scrollList(body)
	if header then header(sf) end
	if #list == 0 then txt(sf, emptyText, 12, TH.dim, Enum.Font.Gotham, { Size = UDim2.new(1, 0, 0, 40), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2 }) end
	for i = 1, #list do trackRow(sf, list, i, i + 10) end
	return sf
end
local function chip(parent, text, on, order)
	local c = btn(parent, text, on, { Size = UDim2.new(0, 0, 0, 28), AutomaticSize = Enum.AutomaticSize.X, TextSize = 11, LayoutOrder = order })
	round(c, 14)
	pad(c, 12, 12, 0, 0)
	return c
end

function MusicApp.build(ctx)
	ctx.push("Music", function(view)
		local main = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -64) }, view)
		-- mini player (tap the song to open Now Playing)
		local player = mk("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = TH.bar, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -64), Size = UDim2.new(1, 0, 0, 64) }, view)
		mk("UIStroke", { Color = TH.acc, Thickness = 1, Transparency = 0.6 }, player)
		local miniArt = mk("ImageLabel", { BackgroundColor3 = TH.card2, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 10), Size = UDim2.fromOffset(44, 44), ScaleType = Enum.ScaleType.Crop }, player)
		round(miniArt, 10)
		local miniNote = txt(miniArt, "~", 18, TH.dim, Enum.Font.GothamBlack, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
		local mTitle = txt(player, "Nothing playing", 12, TH.text, Enum.Font.GothamBold, { Position = UDim2.fromOffset(60, 8), Size = UDim2.new(1, -170, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd })
		local mSub = txt(player, "Pick a song", 10, TH.dim, Enum.Font.Gotham, { Position = UDim2.fromOffset(60, 25), Size = UDim2.new(1, -170, 0, 12), TextTruncate = Enum.TextTruncate.AtEnd })
		local setMini = slider(player, { Position = UDim2.fromOffset(60, 44), Size = UDim2.new(1, -170, 0, 5) }, function(f) Music.seek(f) end)
		local function pbtn(text, x, w)
			local b = btn(player, text, false, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, x, 0.5, 0), Size = UDim2.fromOffset(w, 32), TextSize = 12 })
			round(b, 16)
			return b
		end
		local mNext, mPlay, mPrev = pbtn(">>", -8, 34), pbtn("Play", -46, 50), pbtn("<<", -100, 34)

		-- ===== Now Playing page =====
		local np = mk("Frame", { BackgroundColor3 = TH.bgTop or TH.card, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 50 }, view)
		mk("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromHSV(TH.h or 0.75, 0.55, 0.30), Color3.fromRGB(8, 6, 16)) }, np)
		local npBack = btn(np, "v", false, { Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(34, 28), TextSize = 14 })
		round(npBack, 14)
		txt(np, "NOW PLAYING", 10, TH.dim, Enum.Font.GothamBold, { Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Center })
		local cover = mk("ImageLabel", { BackgroundColor3 = TH.card2, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.fromOffset(120, 120), ScaleType = Enum.ScaleType.Crop }, np)
		round(cover, 18)
		mk("UIStroke", { Color = TH.acc, Thickness = 2, Transparency = 0.3 }, cover)
		local coverNote = txt(cover, "~", 42, TH.dim, Enum.Font.GothamBlack, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
		local nTitle = txt(np, "Nothing playing", 16, TH.text, Enum.Font.GothamBlack, { Position = UDim2.fromOffset(14, 170), Size = UDim2.new(1, -28, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd })
		local nSub = txt(np, "", 11, TH.dim, Enum.Font.Gotham, { Position = UDim2.fromOffset(14, 192), Size = UDim2.new(1, -28, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd })
		local setSeek = slider(np, { Position = UDim2.fromOffset(18, 216), Size = UDim2.new(1, -36, 0, 8) }, function(f) Music.seek(f) end)
		local tCur = txt(np, "0:00", 10, TH.dim, Enum.Font.Gotham, { Position = UDim2.fromOffset(18, 226), Size = UDim2.fromOffset(50, 12) })
		local tEnd = txt(np, "0:00", 10, TH.dim, Enum.Font.Gotham, { Position = UDim2.new(1, -68, 0, 226), Size = UDim2.fromOffset(50, 12), TextXAlignment = Enum.TextXAlignment.Right })
		local row1 = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 244), Size = UDim2.new(1, 0, 0, 46) }, np)
		mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10) }, row1)
		local function rb(text, w, h, acc)
			local b = btn(row1, text, acc, { Size = UDim2.fromOffset(w, h), TextSize = 13 })
			round(b, h)
			return b
		end
		local bShuf, bPrev, bPlay, bNext, bRep = rb("Shuf", 44, 34), rb("<<", 44, 38), rb("Play", 70, 46, true), rb(">>", 44, 38), rb("Rep", 44, 34)
		local row2 = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 296), Size = UDim2.new(1, 0, 0, 34) }, np)
		mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6) }, row2)
		local function cb(text)
			local b = btn(row2, text, false, { Size = UDim2.new(0, 0, 0, 28), AutomaticSize = Enum.AutomaticSize.X, TextSize = 10 })
			round(b, 14)
			pad(b, 9, 9, 0, 0)
			return b
		end
		local bFav, bEq, bSleep, bList, bShare = cb("Like"), cb("EQ: Flat"), cb("Sleep: off"), cb("+ List"), cb("Share")
		txt(np, "VOLUME", 9, TH.dim, Enum.Font.GothamBold, { Position = UDim2.fromOffset(18, 336), Size = UDim2.fromOffset(60, 12) })
		local setVol = slider(np, { Position = UDim2.fromOffset(18, 350), Size = UDim2.new(1, -36, 0, 8) }, function(f) Music.setVol(f) end)
		local npMsg = txt(np, "", 10, TH.acc, Enum.Font.GothamBold, { Position = UDim2.fromOffset(14, 364), Size = UDim2.new(1, -28, 0, 14), TextXAlignment = Enum.TextXAlignment.Center })

		local function openNP() np.Visible = true end
		player.MouseButton1Click:Connect(openNP)
		npBack.MouseButton1Click:Connect(function() np.Visible = false end)
		local function togglePlay() if Music.idx == 0 then notify("Music", "Pick a song first") else Music.toggle() end end
		mPlay.MouseButton1Click:Connect(togglePlay)
		bPlay.MouseButton1Click:Connect(togglePlay)
		mNext.MouseButton1Click:Connect(function() Music.step(1) end)
		bNext.MouseButton1Click:Connect(function() Music.step(1) end)
		mPrev.MouseButton1Click:Connect(function() Music.step(-1) end)
		bPrev.MouseButton1Click:Connect(function() Music.step(-1) end)
		bShuf.MouseButton1Click:Connect(Music.toggleShuffle)
		bRep.MouseButton1Click:Connect(Music.cycleRepeat)
		bFav.MouseButton1Click:Connect(function() local t = Music.queue[Music.idx] if t then Music.toggleFav(t) end end)
		bEq.MouseButton1Click:Connect(function() Music.cycleEq() end)
		local sleepSteps, sleepI = { false, 15, 30, 60 }, 1
		bSleep.MouseButton1Click:Connect(function()
			sleepI = sleepI % #sleepSteps + 1
			Music.setSleep(sleepSteps[sleepI] or nil)
		end)
		bList.MouseButton1Click:Connect(function()
			local t = Music.queue[Music.idx]
			if not t then return end
			local l = Music.lists[1] or Music.newList("My Playlist")
			npMsg.Text = Music.addToList(l, t) and ("Added to " .. l.name) or ("Already in " .. l.name)
		end)
		bShare.MouseButton1Click:Connect(function()
			local t = Music.queue[Music.idx]
			local HC = NovaUI.HubChat
			if not (t and HC) then return end
			local ok, why = HC.send("Now playing on YADSAN Music: " .. t.title .. " - " .. t.artist, "g")
			npMsg.Text = ok and "Shared to Hub chat" or tostring(why or "Could not share")
		end)

		local lastCoverKey
		local function refresh()
			local t = Music.queue[Music.idx]
			local st = Music.state
			mTitle.Text = t and t.title or "Nothing playing"
			mSub.Text = t and (t.artist .. "  -  " .. (st == "loading" and "loading..." or st == "error" and Music.note or (t.note or ""))) or "Pick a song"
			nTitle.Text = t and t.title or "Nothing playing"
			nSub.Text = t and (t.artist .. "  -  " .. (st == "loading" and "loading..." or st == "error" and Music.note or (t.note or ""))) or "Discover or search a song"
			local pt = (st == "playing") and "Pause" or "Play"
			mPlay.Text, bPlay.Text = pt, pt
			local on = function(b, v) b.BackgroundColor3 = v and TH.acc or TH.card2 end
			on(bShuf, Music.shuffle)
			on(bRep, Music.rep > 0)
			bRep.Text = Music.rep == 2 and "R1" or "Rep"
			bEq.Text = "EQ: " .. MUSIC_EQ[Music.eq][1]
			bSleep.Text = Music.sleepAt and ("Sleep: " .. math.max(1, math.ceil((Music.sleepAt - os.clock()) / 60)) .. "m") or "Sleep: off"
			bFav.Text = (t and Music.isFav(t)) and "Liked" or "Like"
			bFav.BackgroundColor3 = (t and Music.isFav(t)) and Color3.fromRGB(255, 90, 140) or TH.card2
			setVol(Music.vol)
			local key = t and (t.src .. t.id)
			if key ~= lastCoverKey then
				lastCoverKey = key
				cover.Image, miniArt.Image = "", ""
				coverNote.Visible, miniNote.Visible = true, true
				if t then
					Music.cover(t, function(a)
						if lastCoverKey == key and cover.Parent then
							cover.Image, miniArt.Image = a, a
							coverNote.Visible, miniNote.Visible = false, false
						end
					end)
				end
			end
		end
		table.insert(Music.listeners, refresh)
		local conn = game:GetService("RunService").Heartbeat:Connect(function()
			local s = Music.sound
			local f = (s.TimeLength > 0) and math.clamp(s.TimePosition / s.TimeLength, 0, 1) or 0
			setMini(f)
			if np.Visible then
				setSeek(f)
				tCur.Text, tEnd.Text = fmtTime(s.TimePosition), fmtTime(s.TimeLength)
			end
		end)
		refresh()

		local cache = { results = {}, err = "", chart = nil, genre = nil }
		local tabsObj = tabbed(ctx, main, { "Discover", "Search", "Library", "Settings" }, {
			Discover = function(body)
				ctx.setSub("charts and moods")
				local top = mk("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 36), CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X }, body)
				mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center }, top)
				pad(top, 10, 10, 4, 4)
				local res = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 1, -38) }, body)
				local moods = { { "For You", nil, true }, { "Top charts", nil }, { "Bollywood", "bollywood hits" }, { "Punjabi", "punjabi hits" }, { "Lofi", "lofi chill" }, { "Hip Hop", "hip hop" }, { "Romantic", "romantic hindi" }, { "Gym", "workout" }, { "Retro", "old hindi songs" }, { "Phonk", "phonk" } }
				local chips, token2 = {}, 0
				local function load(i)
					token2 = token2 + 1
					local my = token2
					cache.genre = i
					for j, c in pairs(chips) do c.BackgroundColor3 = (j == i) and TH.acc or TH.card2 end
					for _, c in ipairs(res:GetChildren()) do c:Destroy() end
					txt(res, "Loading...", 12, TH.dim, Enum.Font.Gotham, { Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Center })
					task.spawn(function()
						local list
						if moods[i][3] then list = Music.forYou() elseif moods[i][2] then list = (Music.search(moods[i][2])) else list = Music.chart() end
						if my ~= token2 or not res.Parent then return end
						for _, c in ipairs(res:GetChildren()) do c:Destroy() end
						musicList(res, list, "Could not load. Check your connection.", function(sf)
							if #list > 0 then
								local pa = btn(sf, "Play all", true, { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 1 })
								round(pa, 17)
								pa.MouseButton1Click:Connect(function() Music.play(list, 1) end)
							end
						end)
					end)
				end
				for i, m in ipairs(moods) do
					local c = chip(top, m[1], false, i)
					chips[i] = c
					c.MouseButton1Click:Connect(function() load(i) end)
				end
				load(cache.genre or 1)
			end,
			Search = function(body)
				ctx.setSub("Deezer" .. (Music.jamendoId() ~= "" and " + Jamendo" or ""))
				local bar = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40) }, body)
				local box = mk("TextBox", { PlaceholderText = "Search song or artist...", Text = "", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = TH.text, PlaceholderColor3 = TH.dim, BackgroundColor3 = TH.card, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -90, 0, 34) }, bar)
				round(box, 17)
				pad(box, 14, 8, 0, 0)
				local go = btn(bar, "Search", true, { Position = UDim2.new(1, -72, 0, 4), Size = UDim2.fromOffset(64, 34), TextSize = 12 })
				round(go, 17)
				local res = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 1, -42) }, body)
				local function show(list, msg)
					for _, c in ipairs(res:GetChildren()) do c:Destroy() end
					musicList(res, list, msg)
				end
				show(cache.results, cache.err ~= "" and cache.err or "Type a song or artist and press Search.")
				local busy = false
				local function doSearch()
					local q = box.Text:gsub("^%s+", ""):gsub("%s+$", "")
					if q == "" or busy then return end
					busy = true
					go.Text = "..."
					task.spawn(function()
						local list, errs = Music.search(q)
						cache.results, cache.err = list, (#list == 0) and (#errs > 0 and table.concat(errs, ", ") or "No results") or ""
						busy = false
						pcall(function() go.Text = "Search" end)
						if res.Parent then show(list, cache.err) end
					end)
				end
				go.MouseButton1Click:Connect(doSearch)
				box.FocusLost:Connect(function(enter) if enter then doSearch() end end)
			end,
			Library = function(body)
				ctx.setSub("your music")
				local top = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36) }, body)
				mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center }, top)
				pad(top, 10, 10, 4, 4)
				local res = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 1, -38) }, body)
				local names, chips, openList = { "Liked", "Recent", "Playlists" }, {}, nil
				local show
				show = function(i)
					cache.lib = i
					for j, c in pairs(chips) do c.BackgroundColor3 = (j == i) and TH.acc or TH.card2 end
					for _, c in ipairs(res:GetChildren()) do c:Destroy() end
					if i == 1 then
						musicList(res, Music.favs, "No liked songs yet. Tap + on a song.", function(sf)
							if #Music.favs > 0 then
								local pa = btn(sf, "Play all", true, { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 1 })
								round(pa, 17)
								pa.MouseButton1Click:Connect(function() Music.play(Music.favs, 1) end)
							end
						end)
					elseif i == 2 then
						musicList(res, Music.recent, "Songs you play will show up here.", function(sf)
							if #Music.recent > 0 then
								local pa = btn(sf, "Play all", true, { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 1 })
								round(pa, 17)
								pa.MouseButton1Click:Connect(function() Music.play(Music.recent, 1) end)
							end
						end)
					else
						if openList then
							local l = openList
							musicList(res, l.tracks, "Empty. Open Now Playing and press + List.", function(sf)
								local bk = btn(sf, "< All playlists", false, { Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 1 })
								bk.MouseButton1Click:Connect(function() openList = nil show(3) end)
								if #l.tracks > 0 then
									local pa = btn(sf, "Play all", true, { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 2 })
									round(pa, 17)
									pa.MouseButton1Click:Connect(function() Music.play(l.tracks, 1) end)
								end
								local dl = btn(sf, "Delete playlist", false, { Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 3, TextColor3 = TH.bad })
								dl.MouseButton1Click:Connect(function() Music.delList(l) openList = nil show(3) end)
							end)
						else
							local sf = scrollList(res)
							local box = mk("TextBox", { PlaceholderText = "New playlist name (Enter)", Text = "", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = TH.text, PlaceholderColor3 = TH.dim, BackgroundColor3 = TH.card, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 1 }, sf)
							round(box, 17)
							pad(box, 14, 8, 0, 0)
							box.FocusLost:Connect(function(enter)
								if enter and Music.newList(box.Text) then show(3) end
							end)
							if #Music.lists == 0 then txt(sf, "No playlists yet. Create one above, then add songs from Now Playing.", 11, TH.dim, Enum.Font.Gotham, { Size = UDim2.new(1, 0, 0, 36), TextWrapped = true, LayoutOrder = 2 }) end
							for k, l in ipairs(Music.lists) do
								local r = btn(sf, l.name .. "   (" .. #l.tracks .. ")", false, { Size = UDim2.new(1, 0, 0, 42), LayoutOrder = 10 + k, TextXAlignment = Enum.TextXAlignment.Left })
								round(r, 12)
								pad(r, 14, 8, 0, 0)
								r.MouseButton1Click:Connect(function() openList = l show(3) end)
							end
						end
					end
				end
				for i, n in ipairs(names) do
					local c = chip(top, n, false, i)
					chips[i] = c
					c.MouseButton1Click:Connect(function() openList = nil show(i) end)
				end
				show(cache.lib or 1)
			end,
			Settings = function(body)
				ctx.setSub("make the app yours")
				settingsPage(body, MusicApp, "Settings", function(sf)
					txt(sf, "MUSIC SOURCES", 11, TH.dim, Enum.Font.GothamBold, { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 10 })
					txt(sf, "Deezer works with no setup (30 second previews). For full songs add a free Jamendo client id (developer.jamendo.com).", 10, TH.dim, Enum.Font.Gotham, { Size = UDim2.new(1, 0, 0, 40), TextWrapped = true, LayoutOrder = 11 })
					local jb = mk("TextBox", { Text = Music.jamendoId(), PlaceholderText = "Jamendo client id (Enter to save)", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = TH.text, PlaceholderColor3 = TH.dim, BackgroundColor3 = TH.card, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 12 }, sf)
					round(jb, 12)
					pad(jb, 12, 8, 0, 0)
					jb.FocusLost:Connect(function() Music.setJamendoId(jb.Text) notify("Music", "Jamendo id saved") end)
					local chk = btn(sf, "Run music check", true, { Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 14 })
					local chkOut = txt(sf, "Tap to test internet, Deezer and audio support.", 10, TH.dim, Enum.Font.Gotham, { Size = UDim2.new(1, 0, 0, 60), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 15 })
					chk.MouseButton1Click:Connect(function()
						chkOut.Text = "Checking..."
						task.spawn(function() local r = Music.check() if chkOut.Parent then chkOut.Text = r end end)
					end)
					local cc = btn(sf, "Clear downloaded songs", false, { Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 13 })
					cc.MouseButton1Click:Connect(function() notify("Music", Music.clearCache() .. " cached songs removed") end)
				end)
			end,
		}, ctx.startTab)
		return function()
			tabsObj.close()
			conn:Disconnect()
			for i, f in ipairs(Music.listeners) do if f == refresh then table.remove(Music.listeners, i) break end end
		end
	end)
end

local PHONE_APPS = {
	{ id = "Chat", title = "Hub Chat", icon = "chat", open = function() openApp(ChatApp) end },
	{ id = "Fits", title = "Fit Saver", icon = "shirt", open = function() openApp(FitApp) end },
	{ id = "Music", title = "Music", icon = "music", takeover = true, open = function() openApp(MusicApp) end },
}

------------------------------------------------------------------------
-- phone navigation: the phone's own home / back buttons close the app (best effort),
-- plus our own back chevron and home bar inside the app.
------------------------------------------------------------------------
local hooked = setmetatable({}, { __mode = "k" })
local function navName(n)
	n = n:lower()
	if n:find("background") or n:find("backdrop") then return false end
	return n == "home" or n == "homebutton" or n == "home_button" or n == "homebtn" or n == "back" or n == "backbutton" or n == "back_button" or n == "backbtn" or n == "goback" or n == "gohome" or n == "closeapp" or n == "exitapp"
end
local function hookNav()
	local ph = phoneGui()
	if not ph then return end
	for _, d in ipairs(ph:GetDescendants()) do
		if d:IsA("GuiButton") and not hooked[d] and not d:FindFirstAncestor("YadsanAppOverlay") and not d.Name:find("YadsanApp") and navName(d.Name) then
			hooked[d] = true
			d.Activated:Connect(function()
				if current then closeApp() end
			end)
		end
	end
end
task.spawn(function()
	while true do
		task.wait(2)
		pcall(hookNav)
	end
end)
UIS.InputBegan:Connect(function(i)
	if not current then return end
	if i.UserInputType ~= Enum.UserInputType.Touch and i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	pcall(function()
		local ph, ov = phoneGui(), current.overlay
		if not ph or not ov.Parent then return end
		local pos = i.Position
		local function inside(x, y)
			local p, s = ov.AbsolutePosition, ov.AbsoluteSize
			return x >= p.X and x <= p.X + s.X and y >= p.Y and y <= p.Y + s.Y
		end
		local inset = game:GetService("GuiService"):GetGuiInset()
		if inside(pos.X, pos.Y) or inside(pos.X, pos.Y + inset.Y) then return end
		local pg = lp:FindFirstChildOfClass("PlayerGui")
		for _, o in ipairs(pg:GetGuiObjectsAtPosition(pos.X, pos.Y)) do
			if o:IsA("GuiButton") and o:IsDescendantOf(ph) and not o:IsDescendantOf(ov) and not o.Name:find("YadsanApp") then
				closeApp()
				return
			end
		end
	end)
end)
task.spawn(function()
	while true do
		task.wait(0.4)
		if current then
			local host = overlayHost()
			if not current.overlay.Parent or not host or not shown(host) then closeApp(true) end
		end
	end
end)

-- ===== inject app icons into the game's phone =====
local function isOurs(o)
	local g = o:FindFirstAncestorWhichIsA("ScreenGui")
	return g ~= nil and (g == Window.Gui or g.Name:find("Yadsan") ~= nil)
end
local function clickable(o)
	if o:IsA("GuiButton") then return o end
	for _, d in ipairs(o:GetDescendants()) do
		if d:IsA("GuiButton") then return d end
	end
	return nil
end
local APP_WORDS = { avatar = 1, vehicles = 1, lifesnap = 1, misc = 1, family = 1, store = 1, items = 1, settings = 1, home = 1, shop = 1, cars = 1 }
local function hasLayout(o)
	return o:FindFirstChildWhichIsA("UIGridLayout") ~= nil or o:FindFirstChildWhichIsA("UIListLayout") ~= nil or o:FindFirstChildWhichIsA("UIPageLayout") ~= nil
end
-- find the phone's app grid by looking for the known app names (Avatar, Vehicles, Family...) and climbing to the layout parent
local lastHost
local function getPhoneHost()
	if lastHost and lastHost.Parent and lastHost.AbsoluteSize.X > 10 then return lastHost end
	local pg = lp:FindFirstChildOfClass("PlayerGui")
	if not pg then return nil end
	local votes = {}
	for _, d in ipairs(pg:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			local t = tostring(d.Text):lower():gsub("^%s+", ""):gsub("%s+$", "")
			if APP_WORDS[t] and not isOurs(d) then
				local node = d
				while node.Parent and node.Parent ~= pg do
					local par = node.Parent
					if par:IsA("GuiObject") and hasLayout(par) then
						votes[par] = (votes[par] or 0) + 1
						break
					end
					node = par
				end
			end
		end
	end
	local best, bn = nil, 0
	for h, n in pairs(votes) do
		if n > bn and h.AbsoluteSize.X > 10 then best, bn = h, n end
	end
	if not best then
		-- hand-placed grid: the parent that holds several children that each contain an app label
		local cnt = {}
		for _, d in ipairs(pg:GetDescendants()) do
			if (d:IsA("TextLabel") or d:IsA("TextButton")) and APP_WORDS[tostring(d.Text):lower()] and not isOurs(d) then
				local node = d
				for _ = 1, 4 do
					if node.Parent and node.Parent ~= pg then
						node = node.Parent
						if node.Parent and node.Parent:IsA("GuiObject") then cnt[node.Parent] = (cnt[node.Parent] or 0) + 1 end
					end
				end
			end
		end
		for h, n in pairs(cnt) do
			if n > bn and n >= 4 and h.AbsoluteSize.X > 10 then best, bn = h, n end
		end
	end
	if not best then
		local o = pg
		for _, n in ipairs({ "Phone", "PhoneHome", "MasterFrame", "Holder", "AppsHolder" }) do
			o = o and o:FindFirstChild(n)
		end
		best = o
	end
	lastHost = best
	return best
end

-- the unlabelled "?" tile (the one that asks to join a group): we put the Music app in its place
local function unlabeled(c)
	for _, d in ipairs(c:GetDescendants()) do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text:gsub("%s", "") ~= "" and d.Text ~= "?" then return false end
	end
	if (c:IsA("TextButton") or c:IsA("TextLabel")) and c.Text:gsub("%s", "") ~= "" and c.Text ~= "?" then return false end
	return true
end
local function findQuestionTile(host)
	local best, bs = nil, 0
	for _, c in ipairs(host:GetChildren()) do
		if c:IsA("GuiObject") and not c.Name:find("YadsanApp") and c.AbsoluteSize.X > 8 and clickable(c) then
			local nm, sc = c.Name:lower(), 0
			if unlabeled(c) then sc = sc + 2 end
			if nm:find("group") or nm:find("join") or nm:find("lock") or nm:find("question") or nm:find("soon") or nm:find("unknown") then sc = sc + 3 end
			for _, d in ipairs(c:GetDescendants()) do
				if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text == "?" then sc = sc + 3 break end
			end
			if sc >= 2 then
				sc = sc + (c.LayoutOrder or 0) / 1e6 + (c.AbsolutePosition.Y * 1e-4)
				if sc > bs then best, bs = c, sc end
			end
		end
	end
	return best
end

local function allImages(c)
	local t = {}
	if c:IsA("ImageLabel") or c:IsA("ImageButton") then t[#t + 1] = c end
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("ImageLabel") or d:IsA("ImageButton") then t[#t + 1] = d end
	end
	return t
end

-- find a free spot in a hand-placed grid of app frames
local function placeInFreeSlot(host, clone, template)
	local lay = host:FindFirstChildWhichIsA("UIGridLayout") or host:FindFirstChildWhichIsA("UIListLayout")
	if lay then
		clone.LayoutOrder = 99990
		return true
	end
	local hp, hs = host.AbsolutePosition, host.AbsoluteSize
	local items = {}
	for _, c in ipairs(host:GetChildren()) do
		if c:IsA("GuiObject") and c ~= clone and c.Visible then
			local rx, ry = c.AbsolutePosition.X - hp.X, c.AbsolutePosition.Y - hp.Y
			if rx >= -2 and ry >= -2 and rx + c.AbsoluteSize.X <= hs.X + 2 and ry + c.AbsoluteSize.Y <= hs.Y + 2 and c.AbsoluteSize.X > 4 then
				items[#items + 1] = { x = math.floor(rx / 4 + 0.5) * 4, y = math.floor(ry / 4 + 0.5) * 4 }
			end
		end
	end
	local xs, ys, occ, seenX, seenY = {}, {}, {}, {}, {}
	for _, it in ipairs(items) do
		if not seenX[it.x] then seenX[it.x] = true xs[#xs + 1] = it.x end
		if not seenY[it.y] then seenY[it.y] = true ys[#ys + 1] = it.y end
		occ[it.x .. "," .. it.y] = true
	end
	table.sort(xs)
	table.sort(ys)
	if #xs == 0 or #ys == 0 then return false end
	local tx, ty = nil, nil
	for _, y in ipairs(ys) do
		for _, x in ipairs(xs) do
			if not occ[x .. "," .. y] then tx, ty = x, y break end
		end
		if tx then break end
	end
	if not tx then
		local step = #ys >= 2 and (ys[#ys] - ys[#ys - 1]) or (template.AbsoluteSize.Y + 12)
		tx, ty = xs[1], ys[#ys] + step
	end
	local trx, try = template.AbsolutePosition.X - hp.X, template.AbsolutePosition.Y - hp.Y
	clone.Position = template.Position + UDim2.fromScale((tx - trx) / hs.X, (ty - try) / hs.Y)
	return true
end

local function styleClone(c, app)
	-- text: first label gets our title, the rest are hidden
	local first = true
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			if d.Text ~= "" then
				if first then d.Text = app.title first = false else d.Text = "" end
			end
		end
	end
	if c:IsA("TextButton") and c.Text ~= "" and first then c.Text = app.title end
	-- icon: keep the biggest image as the tile, hide the other glyphs, then draw ours
	local imgs = allImages(c)
	table.sort(imgs, function(a, b) return a.AbsoluteSize.X * a.AbsoluteSize.Y > b.AbsoluteSize.X * b.AbsoluteSize.Y end)
	local tile = imgs[1]
	for i = 2, #imgs do imgs[i].Visible = false end
	if tile then
		tile.Image = ""
		tile.BackgroundTransparency = 0
		tile.BackgroundColor3 = Color3.new(1, 1, 1)
		local uc = tile:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", tile)
		uc.CornerRadius = UDim.new(0.28, 0)
		for _, o in ipairs(tile:GetChildren()) do
			if o:IsA("UIGradient") or o:IsA("UIStroke") then o:Destroy() end
		end
		local ug = Instance.new("UIGradient")
		ug.Rotation = 55
		ug.Color = ColorSequence.new(Color3.fromHSV(TH.h or 0.75, 0.7, 0.85), Color3.fromHSV(TH.h or 0.75, 0.85, 0.28))
		ug.Parent = tile
		local us2 = Instance.new("UIStroke")
		us2.Thickness = 1.5
		us2.Transparency = 0.35
		us2.Color = Color3.new(1, 1, 1)
		us2.Parent = tile
		local asset = NovaUI.Asset(app.icon)
		local g = Instance.new("ImageLabel")
		g.BackgroundTransparency = 1
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Position = UDim2.fromScale(0.5, 0.5)
		g.Size = UDim2.fromScale(0.62, 0.62)
		g.ZIndex = tile.ZIndex + 2
		if asset then
			g.Image = asset
			g.ImageColor3 = Color3.new(1, 1, 1)
		end
		g.Parent = tile
		if not asset then
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, 1)
			t.Font = Enum.Font.GothamBlack
			t.TextScaled = true
			t.TextColor3 = Color3.fromRGB(220, 180, 255)
			t.Text = app.id == "Chat" and "C" or "F"
			t.ZIndex = tile.ZIndex + 2
			t.Parent = tile
		end
	end
end

local function injectApp(host, app)
	local existing = host:FindFirstChild("YadsanApp_" .. app.id)
	if existing then
		if app.takeover and app._slot and app._slot.Parent then
			if app._slot.Visible then app._slot.Visible = false end
		end
		return true
	end
	if host.AbsoluteSize.X < 10 then return false end
	local slot = nil
	if app.takeover then slot = findQuestionTile(host) end
	local template = host:FindFirstChild("Tools")
	if not (template and template:IsA("GuiObject") and clickable(template)) then
		template = nil
		for _, c in ipairs(host:GetChildren()) do
			if c:IsA("GuiObject") and not c.Name:find("YadsanApp") and c ~= slot and c.Name ~= "Misc" and clickable(c) and not unlabeled(c) then template = c break end
		end
	end
	if not template then return false end
	local c = template:Clone()
	c.Name = "YadsanApp_" .. app.id
	c.Visible = true
	-- strip everything the game could use to hook this clone to its own app (tags, attributes, scripts)
	local CS = game:GetService("CollectionService")
	local function strip(o)
		pcall(function()
			for _, tg in ipairs(CS:GetTags(o)) do CS:RemoveTag(o, tg) end
			for k in pairs(o:GetAttributes()) do o:SetAttribute(k, nil) end
		end)
		if o:IsA("LocalScript") or o:IsA("Script") or o:IsA("ModuleScript") then
			o:Destroy()
			return
		end
		if o:IsA("GuiButton") then
			pcall(function() o.Interactable = false end)
			pcall(function() o.Active = false end)
		end
		for _, d in ipairs(o:GetChildren()) do strip(d) end
	end
	strip(c)
	c.Parent = host
	if slot then
		c.LayoutOrder = slot.LayoutOrder
		c.Position, c.Size, c.AnchorPoint = slot.Position, slot.Size, slot.AnchorPoint
		c.ZIndex = slot.ZIndex
		slot.Visible = false
		app._slot = slot
	elseif not placeInFreeSlot(host, c, template) then
		c:Destroy()
		return false
	end
	styleClone(c, app)
	-- our own click catcher on top (the cloned buttons are disabled, so the game's Items app cannot open)
	local catcher = Instance.new("TextButton")
	catcher.Name = "YadsanAppCatcher"
	catcher.Text = ""
	catcher.BackgroundTransparency = 1
	catcher.AutoButtonColor = false
	catcher.Size = UDim2.fromScale(1, 1)
	catcher.ZIndex = 200
	catcher.Active = true
	catcher.Parent = c
	local fired = 0
	local function go()
		if os.clock() - fired < 0.3 then return end
		fired = os.clock()
		app.open()
	end
	catcher.Activated:Connect(go)
	return true
end
NovaUI.PhoneApps, NovaUI.Music, NovaUI.FitStore = PHONE_APPS, Music, FitStore
local phoneState = { host = false, told = false, t0 = os.clock() }
local function installPhoneApps(silent)
	local host = getPhoneHost()
	if not host then
		if not silent then notify("Phone apps", "Phone not found. Open your phone once, then press Install again.") end
		return false
	end
	local ok = true
	for _, app in ipairs(PHONE_APPS) do ok = injectApp(host, app) and ok end
	if ok and not phoneState.told then
		phoneState.told = true
		local took = PHONE_APPS[3]._slot and "Music replaced the '?' tile" or "Music added in a free slot"
		notify("Phone apps", "Added to your phone. " .. took .. ".")
	end
	if ok and not silent then notify("Phone apps", "Hub Chat and Fit Saver added to your phone home screen.") end
	if not ok and not silent then notify("Phone apps", "Could not place the icons. Use 'Copy phone scan report' and send it.") end
	return ok
end
task.spawn(function()
	while true do
		task.wait(3)
		pcall(installPhoneApps, true)
		if not phoneState.told and not phoneState.warned and os.clock() - phoneState.t0 > 90 then
			phoneState.warned = true
			notify("Phone apps", "Phone grid not found yet. Open your phone home screen, or use the floating M button to open Music / Chat / Fits.")
		end
	end
end)

local phoneSec = Dev:Section({ Title = "Phone apps", Icon = "chat", Side = "Right" })
phoneSec:Button({ Title = "Install apps in phone", Style = "Primary", Callback = function() installPhoneApps(false) end })
phoneSec:Button({ Title = "Open Hub Chat app", Callback = function() PHONE_APPS[1].open() end })
phoneSec:Button({ Title = "Copy screen-edge UI scan", Callback = function()
	local out, pg = {}, lp:FindFirstChild("PlayerGui")
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1600, 720)
	for _, d in ipairs(pg and pg:GetDescendants() or {}) do
		if d:IsA("GuiObject") and d.Visible and d.AbsoluteSize.X > 6 and d.AbsoluteSize.Y > 6 and d.AbsoluteSize.X < 400 and (d.AbsolutePosition.X < 60 or d.AbsolutePosition.X + d.AbsoluteSize.X > vp.X - 60) then
			out[#out + 1] = ("%s [%s] pos %d,%d size %d,%d %s"):format(d:GetFullName():gsub("^Players%.[^.]+%.PlayerGui%.", ""), d.ClassName, d.AbsolutePosition.X, d.AbsolutePosition.Y, d.AbsoluteSize.X, d.AbsoluteSize.Y, (d:IsA("TextLabel") or d:IsA("TextButton")) and ("text=" .. d.Text) or "")
			if #out >= 80 then break end
		end
	end
	pcall(function() setclipboard(table.concat(out, "\n")) end)
	notify("Scan", #out .. " edge elements copied")
end })
phoneSec:Button({ Title = "Open Fit Saver app", Callback = function() PHONE_APPS[2].open() end })
phoneSec:Button({ Title = "Copy phone UI map", Callback = function()
	local ph = phoneGui()
	if not ph then notify("Phone map", "Phone UI not found. Open the phone first.") return end
	local lines = {}
	local function walk(o, d)
		if d > 5 or #lines > 450 then return end
		for _, c in ipairs(o:GetChildren()) do
			if c:IsA("GuiObject") or c:IsA("ScreenGui") or c:IsA("Folder") then
				if not (c.Name:find("YadsanApp")) then
					local extra = ""
					if c:IsA("GuiButton") then extra = extra .. " [BTN]" end
					if c:IsA("GuiObject") then extra = extra .. (c.Visible and "" or " hidden") .. (" %dx%d"):format(c.AbsoluteSize.X, c.AbsoluteSize.Y) end
					if c:IsA("TextLabel") or c:IsA("TextButton") then extra = extra .. ' "' .. tostring(c.Text):sub(1, 18) .. '"' end
					lines[#lines + 1] = string.rep("  ", d) .. c.Name .. ":" .. c.ClassName .. extra
					walk(c, d + 1)
				end
			end
		end
	end
	lines[1] = "Phone"
	walk(ph, 1)
	if setclipboard then setclipboard(table.concat(lines, "\n")) end
	notify("Phone map", #lines .. " lines copied to clipboard.")
end })
phoneSec:Label("Open the phone once, then press Install. Apps open inside the phone screen; its back/home buttons (or our own) close them.")

defCmd("chatapp", "chatapp", "Open Hub Chat in the phone", function() PHONE_APPS[1].open() return "Chat app" end)
defCmd("musicapp", "musicapp", "Open the Music app", function() PHONE_APPS[3].open() return "Music app" end)
defCmd("fitapp", "fitapp", "Open Fit Saver in the phone", function() PHONE_APPS[2].open() return "Fit app" end)
end
end)()
;(function()
------------------------------------------------------------------------
-- LIFE RP tab: Life Together specific features (remotes taken from the Flames Hub script).
-- Only features that affect your own character / car / home / phone. Nothing that targets other players.
------------------------------------------------------------------------
local Life = Window:CreateTab({ Name = "Life RP", Icon = "flame" })
local function send(...)
	if not net then notify("Life RP", "Game network not found (are you in Life Together RP?)") return false end
	local a = table.pack(...)
	local ok, e = pcall(function() return net.send(table.unpack(a, 1, a.n)) end)
	return ok
end
local function get(...)
	if not net then return false end
	local a = table.pack(...)
	local ok, r = pcall(function() return net.get(table.unpack(a, 1, a.n)) end)
	return ok, r
end
local running = {}
local function startLoop(key, interval, fn)
	if running[key] then return end
	running[key] = true
	task.spawn(function()
		while running[key] do
			pcall(fn)
			task.wait(interval)
		end
	end)
end
local function stopLoop(key)
	running[key] = nil
end

local function myVehicle()
	local vf = workspace:FindFirstChild("Vehicles")
	if not vf then return nil end
	for _, v in ipairs(vf:GetChildren()) do
		local o = v:FindFirstChild("owner") or v:FindFirstChild("owner", true)
		if o and o.Value == lp then return v end
	end
end
local function myPlot()
	local plotInst, plotObj
	pcall(function()
		local mods = require(game:GetService("ReplicatedStorage"):FindFirstChild("Modules", true))
		for _, m in pairs(mods) do
			if type(m) == "table" then
				local okc, objs = pcall(function() return m.class and m.class.objects end)
				if okc and type(objs) == "table" then
					for _, plot in pairs(objs) do
						if type(plot) == "table" and plot.states and plot.states.owner and plot.instance then
							local okg, owner = pcall(function() return plot.states.owner.get() end)
							if okg and owner == lp then
								plotInst, plotObj = plot.instance, plot
								return
							end
						end
					end
				end
			end
		end
	end)
	return plotInst, plotObj
end
local function plotLocked(plotObj)
	local ok, v = pcall(function() return plotObj.states.locked.get() end)
	if ok then return v end
end

-- ===== Profile =====
local prof = Life:Section({ Title = "Profile", Icon = "user", Side = "Left" })
prof:Input({ Placeholder = "Roleplay name (press Enter)", Callback = function(t)
	if t and t ~= "" then send("roleplay_name", tostring(t)) notify("Life RP", "Roleplay name set") end
end })
prof:Input({ Placeholder = "Bio (press Enter)", Callback = function(t)
	if t and t ~= "" then send("bio", tostring(t)) notify("Life RP", "Bio set") end
end })
local MARK = "`~ YADSAN Anti Stealer Is Enabled ~`"
local prevBio
prof:Toggle({ Title = "Anti Outfit Copier", Description = "Hides your outfit and marks your bio so copiers skip you", Icon = "shield", Default = false, Flag = "AntiCopy", Callback = function(v)
	if v then
		prevBio = lp:GetAttribute("bio")
		send("hide_view_outfit", true)
		send("bio", MARK)
		startLoop("anticopy", 0.5, function()
			if lp:GetAttribute("hide_view_outfit") == false then send("hide_view_outfit", true) end
			if lp:GetAttribute("bio") ~= MARK then send("bio", MARK) end
		end)
	else
		stopLoop("anticopy")
		if type(prevBio) == "string" and prevBio ~= MARK then send("bio", prevBio) end
	end
end })
prof:Toggle({ Title = "Hide my name", Icon = "eye", Default = false, Flag = "HideName", Callback = function(v) send("hide_name", v) end })
prof:Toggle({ Title = "Hide other names", Icon = "eye", Default = false, Flag = "HideOthers", Callback = function(v) send("hide_other_names", v) end })
prof:Toggle({ Title = "Hide map icon", Icon = "eye", Default = false, Flag = "HideMapIcon", Callback = function(v) send("hide_map_icon", v) end })

-- ===== Jobs =====
local jobs = Life:Section({ Title = "Job", Icon = "star", Side = "Left" })
local jobActs = {}
for _, j in ipairs({ "Police", "Firefighter", "Baker", "Pizza Worker", "Barista", "Doctor" }) do
	jobActs[#jobActs + 1] = { Title = j, Description = "Set job", Icon = "star", Callback = function()
		send("job", j)
		notify("Life RP", "Job: " .. j)
	end }
end
jobs:Actions(jobActs)

-- ===== Phone =====
local ph = Life:Section({ Title = "Phone", Icon = "chat", Side = "Left" })
ph:Toggle({ Title = "Rainbow phone", Icon = "sparkles", Default = false, Flag = "RainbowPhone", Callback = function(v)
	if v then
		local h = 0
		startLoop("rphone", 0.15, function()
			h = (h + 0.04) % 1
			send("phone_color", Color3.fromHSV(h, 1, 1))
		end)
	else
		stopLoop("rphone")
		task.wait(0.2)
		send("phone_color", Color3.new(1, 1, 1))
	end
end })
local PCOL = { { "Red", Color3.fromRGB(255, 60, 60) }, { "Blue", Color3.fromRGB(60, 120, 255) }, { "Green", Color3.fromRGB(60, 220, 110) }, { "Pink", Color3.fromRGB(255, 120, 200) }, { "Purple", Color3.fromRGB(150, 70, 255) }, { "White", Color3.new(1, 1, 1) } }
local pAct = {}
for _, c in ipairs(PCOL) do
	pAct[#pAct + 1] = { Title = c[1], Description = "Phone color", Icon = "star", Callback = function() send("phone_color", c[2]) end }
end
ph:Actions(pAct)

-- ===== Vehicle =====
local veh = Life:Section({ Title = "Vehicle", Icon = "rocket", Side = "Right" })
local vname = "Monster Truck"
veh:Input({ Placeholder = "Vehicle name (e.g. Monster Truck)", Callback = function(t) if t and t ~= "" then vname = t end end })
veh:Button({ Title = "Spawn vehicle", Style = "Primary", Callback = function()
	get("spawn_vehicle", vname)
end })
veh:Button({ Title = "Despawn my vehicle", Callback = function()
	local v = myVehicle()
	if v then get("spawn_vehicle", v.Name) else notify("Vehicle", "You have no vehicle out") end
end })
veh:Button({ Title = "Lock / unlock my car", Callback = function()
	local v = myVehicle()
	if v then get("lock_vehicle", v) notify("Vehicle", v:GetAttribute("locked") and "Unlocking..." or "Locking...") else notify("Vehicle", "You have no vehicle out") end
end })
veh:Toggle({ Title = "Auto lock my car", Icon = "shield", Default = false, Flag = "AutoLockCar", Callback = function(v)
	if v then
		startLoop("autolockcar", 1, function()
			local car = myVehicle()
			if car and car:GetAttribute("locked") ~= true then get("lock_vehicle", car) end
		end)
	else
		stopLoop("autolockcar")
	end
end })
veh:Toggle({ Title = "Rainbow car", Icon = "sparkles", Default = false, Flag = "RainbowCar", Callback = function(v)
	if v then
		local h = 0
		startLoop("rcar", 0.15, function()
			local car = myVehicle()
			if not car then return end
			h = (h + 0.04) % 1
			send("vehicle_color", Color3.fromHSV(h, 1, 1), car)
		end)
	else
		stopLoop("rcar")
	end
end })
local VCOL = { { "Red", Color3.fromRGB(230, 40, 40) }, { "Blue", Color3.fromRGB(40, 100, 240) }, { "Black", Color3.fromRGB(15, 15, 15) }, { "White", Color3.new(1, 1, 1) }, { "Gold", Color3.fromRGB(240, 190, 40) }, { "Purple", Color3.fromRGB(140, 60, 240) } }
local vAct = {}
for _, c in ipairs(VCOL) do
	vAct[#vAct + 1] = { Title = c[1], Description = "Car color", Icon = "star", Callback = function()
		local car = myVehicle()
		if car then send("vehicle_color", c[2], car) else notify("Vehicle", "You have no vehicle out") end
	end }
end
veh:Actions(vAct)
veh:Button({ Title = "Bring my car to me", Callback = function()
	local car, root = myVehicle(), lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	if car and root then pcall(function() car:PivotTo(root.CFrame * CFrame.new(0, 3, -9)) end) else notify("Vehicle", "No vehicle or character") end
end })
veh:Button({ Title = "Go to my car", Callback = function()
	local car, root = myVehicle(), lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	if car and root then pcall(function() root.CFrame = car:GetPivot() * CFrame.new(0, 5, 0) end) else notify("Vehicle", "No vehicle or character") end
end })

-- ===== Home =====
local home = Life:Section({ Title = "Home", Icon = "settings", Side = "Right" })
home:Button({ Title = "Lock my home", Callback = function()
	local inst, obj = myPlot()
	if not inst then notify("Home", "Could not find your home plot") return end
	if plotLocked(obj) ~= true then send("lock_home", inst) end
	notify("Home", "Home locked")
end })
home:Button({ Title = "Unlock my home", Callback = function()
	local inst, obj = myPlot()
	if not inst then notify("Home", "Could not find your home plot") return end
	if plotLocked(obj) ~= false then send("lock_home", inst) end
	notify("Home", "Home unlocked")
end })
home:Toggle({ Title = "Auto lock my home", Icon = "shield", Default = false, Flag = "AutoLockHome", Callback = function(v)
	if v then
		startLoop("autolockhome", 1.5, function()
			local inst, obj = myPlot()
			if inst and plotLocked(obj) == false then send("lock_home", inst) end
		end)
	else
		stopLoop("autolockhome")
	end
end })

-- ===== Private server (owner only) =====
local ps = Life:Section({ Title = "Private server (owner only)", Icon = "settings", Side = "Right" })
ps:Toggle({ Title = "Stop time", Icon = "eye", Default = false, Flag = "StopTime", Callback = function(v) send("time_toggle", v) end })
ps:Input({ Placeholder = "Set time number, press Enter", Numeric = true, Callback = function(t)
	local n = tonumber(t)
	if n then send("change_time", n) end
end })
ps:Label("These only work if you own the private server.")
end)()
;(function()
------------------------------------------------------------------------
-- SPAWN BANNER: big "YADSAN HUB" billboard + Owner / Admin cards above the spawn (client side: script users see it).
-- Tap / click any panel for a burst effect.
------------------------------------------------------------------------
local PLAYERS = game:GetService("Players")
local STAFF = {
	{ name = "supermonkxscripts", title = "OWNER", colA = Color3.fromRGB(255, 214, 90), colB = Color3.fromRGB(255, 140, 30) },
	{ name = "TheRedAuth0r", title = "ADMIN", colA = Color3.fromRGB(255, 120, 130), colB = Color3.fromRGB(190, 30, 70), x = 38 },
}
local parts, conn, base = {}, nil, CFrame.new()
local ACC = Color3.fromRGB(170, 100, 255)

-- returns floor point + flat look direction of the spawn closest to you (or a spot near you if none is close)
local function findSpawnCF()
	local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	local best, bd
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("SpawnLocation") then
			local dist = root and (d.Position - root.Position).Magnitude or 0
			if not bd or dist < bd then best, bd = d, dist end
		end
	end
	if best and (not root or bd < 600) then
		local look = Vector3.new(best.CFrame.LookVector.X, 0, best.CFrame.LookVector.Z)
		if look.Magnitude < 0.1 then look = Vector3.new(0, 0, -1) end
		NovaUI.BannerDist = bd
		return Vector3.new(best.Position.X, best.Position.Y + best.Size.Y / 2, best.Position.Z), look.Unit
	end
	if root then
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if look.Magnitude < 0.1 then look = Vector3.new(0, 0, -1) end
		NovaUI.BannerDist = 0
		return Vector3.new(root.Position.X, root.Position.Y - 3, root.Position.Z), look.Unit
	end
end

-- local profile: level / days of use / account date, saved in the executor folder (YADSAN_HUB/profile.json)
local DISCORD = "https://discord.gg/gZGJFyWUU"
local Profile = { xp = 0, days = 0, minutes = 0 }
local PF = "YADSAN_HUB/profile.json"
local function profSave()
	pcall(function()
		pcall(makefolder, "YADSAN_HUB")
		writefile(PF, HttpService:JSONEncode({ xp = Profile.xp, days = Profile.days, minutes = Profile.minutes, first = Profile.first, last = Profile.last, streak = Profile.streak, best = Profile.best, copies = Profile.copies, saves = Profile.saves, msgs = Profile.msgs }))
	end)
end
function Profile.level()
	local xp = Profile.xp or 0
	local lv = math.floor(math.sqrt(xp / 40)) + 1
	local lo, hi = 40 * (lv - 1) ^ 2, 40 * lv ^ 2
	return lv, math.clamp((xp - lo) / (hi - lo), 0, 1), xp, hi
end
function Profile.age()
	local a = lp.AccountAge
	return type(a) == "number" and a or 0
end
function Profile.joined()
	return os.date("%d %b %Y", os.time() - Profile.age() * 86400)
end
do
	pcall(function()
		if isfile and isfile(PF) then
			local d = HttpService:JSONDecode(readfile(PF))
			if type(d) == "table" then
				for _, k in ipairs({ "xp", "days", "minutes", "first", "last", "streak", "best", "copies", "saves", "msgs" }) do
					if d[k] ~= nil then Profile[k] = d[k] end
				end
			end
		end
	end)
	Profile.first = tonumber(Profile.first) or os.time()
	local today = os.date("%Y-%m-%d")
	if Profile.last ~= today then
		local yesterday = os.date("%Y-%m-%d", os.time() - 86400)
		Profile.streak = (Profile.last == yesterday) and ((tonumber(Profile.streak) or 0) + 1) or 1
		Profile.best = math.max(tonumber(Profile.best) or 0, Profile.streak)
		Profile.days = (tonumber(Profile.days) or 0) + 1
		Profile.xp = (tonumber(Profile.xp) or 0) + 25
		Profile.last = today
	end
	profSave()
	task.spawn(function()
		while true do
			task.wait(60)
			Profile.xp = Profile.xp + 1
			Profile.minutes = (Profile.minutes or 0) + 1
			profSave()
		end
	end)
end
NovaUI.Profile = Profile
function NovaUI.Stat(k)
	Profile[k] = (tonumber(Profile[k]) or 0) + 1
	profSave()
end
function Profile.achievements()
	local lv = Profile.level()
	local list = {
		{ "First fit copied", (Profile.copies or 0) >= 1 }, { "Fit collector (5 fits saved)", (Profile.saves or 0) >= 5 },
		{ "Chatterbox (25 messages)", (Profile.msgs or 0) >= 25 }, { "Regular (7 days)", (Profile.days or 0) >= 7 },
		{ "3-day streak", (Profile.best or 0) >= 3 }, { "Level 5", lv >= 5 }, { "Level 10", lv >= 10 },
	}
	local out = {}
	for _, a in ipairs(list) do out[#out + 1] = (a[2] and "[x] " or "[ ] ") .. a[1] end
	return table.concat(out, "\n")
end
-- player-made banner settings (YADSAN_HUB/banner.json)
local PALETTES = {
	{ name = "Violet", a = Color3.fromRGB(170, 100, 255), b = Color3.fromRGB(90, 200, 255), bg1 = Color3.fromRGB(44, 16, 88), bg2 = Color3.fromRGB(6, 3, 14) },
	{ name = "Sunset", a = Color3.fromRGB(255, 150, 70), b = Color3.fromRGB(255, 70, 130), bg1 = Color3.fromRGB(90, 28, 40), bg2 = Color3.fromRGB(16, 4, 10) },
	{ name = "Ocean", a = Color3.fromRGB(70, 200, 255), b = Color3.fromRGB(60, 110, 255), bg1 = Color3.fromRGB(12, 44, 90), bg2 = Color3.fromRGB(3, 6, 18) },
	{ name = "Emerald", a = Color3.fromRGB(90, 255, 170), b = Color3.fromRGB(40, 170, 110), bg1 = Color3.fromRGB(10, 70, 50), bg2 = Color3.fromRGB(3, 12, 10) },
	{ name = "Rose", a = Color3.fromRGB(255, 130, 200), b = Color3.fromRGB(200, 80, 255), bg1 = Color3.fromRGB(88, 20, 70), bg2 = Color3.fromRGB(14, 3, 14) },
	{ name = "Gold", a = Color3.fromRGB(255, 226, 120), b = Color3.fromRGB(255, 150, 30), bg1 = Color3.fromRGB(80, 54, 8), bg2 = Color3.fromRGB(14, 9, 3) },
}
local BF = "YADSAN_HUB/banner.json"
local BCFG = { pal = 1, title = "", tag = "" }
pcall(function()
	if isfile and isfile(BF) then
		local d = HttpService:JSONDecode(readfile(BF))
		if type(d) == "table" then
			BCFG.pal = math.clamp(tonumber(d.pal) or 1, 1, #PALETTES)
			BCFG.title = tostring(d.title or ""):sub(1, 24)
			BCFG.tag = tostring(d.tag or ""):sub(1, 40)
		end
	end
end)
local function bcfgSave()
	pcall(function()
		pcall(makefolder, "YADSAN_HUB")
		writefile(BF, HttpService:JSONEncode(BCFG))
	end)
end
local function copyDiscord()
	local ok = pcall(function() setclipboard(DISCORD) end)
	notify("Discord", ok and "Invite link copied!" or DISCORD)
end

local function newFace(part, face)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "YadsanBannerFace"
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40 * (part:GetAttribute("refW") or 48) / math.max(part.Size.X, 1)
	sg.LightInfluence = 0
	sg.Adornee = part
	sg.ResetOnSpawn = false
	sg.Parent = part
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.new(1, 1, 1)
	bg.BorderSizePixel = 0
	bg.ClipsDescendants = true
	bg.Parent = sg
	local bgg = Instance.new("UIGradient")
	bgg.Color = ColorSequence.new(Color3.fromRGB(44, 16, 88), Color3.fromRGB(6, 3, 14))
	bgg.Rotation = 35
	bgg.Parent = bg
	local st = Instance.new("UIStroke")
	st.Thickness = 10
	st.Color = Color3.new(1, 1, 1)
	st.Parent = bg
	local sg2 = Instance.new("UIGradient")
	sg2.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 60, 255)), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 60, 255)) })
	sg2.Parent = st
	return { sg = sg, bg = bg, bgg = bgg, sg2 = sg2 }
end
local function label(parent, text, font, color, pos, size)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = font
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = color
	l.Position = pos
	l.Size = size
	l.Parent = parent
	return l
end

local function mainFace(part, face)
	local f = newFace(part, face)
	for _, x in ipairs({ 0.09, 0.91 }) do
		pcall(function()
			NovaUI.MakeBlackhole(f.bg, 440, { Position = UDim2.fromScale(x, 0.5), ParticleCount = 10 })
		end)
	end
	local title = label(f.bg, "YADSAN HUB", Enum.Font.GothamBlack, Color3.new(1, 1, 1), UDim2.fromScale(0.15, 0.12), UDim2.fromScale(0.7, 0.55))
	title.TextStrokeTransparency = 0.5
	title.TextStrokeColor3 = Color3.fromRGB(110, 40, 230)
	local tg = Instance.new("UIGradient")
	tg.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(190, 140, 255)), ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)) })
	tg.Parent = title
	f.tscale = Instance.new("UIScale")
	f.tscale.Parent = title
	f.tg = tg
	f.live = label(f.bg, "L I F E   T O G E T H E R   R P   -   S C R I P T   U S E R S", Enum.Font.GothamBold, Color3.fromRGB(200, 170, 255), UDim2.fromScale(0.15, 0.68), UDim2.fromScale(0.7, 0.12))
	for _, y in ipairs({ 0.045, 0.955 }) do
		local ln = Instance.new("Frame")
		ln.AnchorPoint = Vector2.new(0.5, 0.5)
		ln.Position = UDim2.fromScale(0.5, y)
		ln.Size = UDim2.fromScale(0.86, 0.012)
		ln.BorderSizePixel = 0
		ln.BackgroundColor3 = Color3.new(1, 1, 1)
		ln.Parent = f.bg
		local lg = Instance.new("UIGradient")
		lg.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 40, 160)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 150, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 40, 160)) })
		lg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.1), NumberSequenceKeypoint.new(0.8, 0.1), NumberSequenceKeypoint.new(1, 1) })
		lg.Parent = ln
	end
	-- light sweep across the whole banner
	local shine = Instance.new("Frame")
	shine.AnchorPoint = Vector2.new(0.5, 0.5)
	shine.Size = UDim2.fromScale(0.12, 1.6)
	shine.Position = UDim2.fromScale(-0.2, 0.5)
	shine.Rotation = 18
	shine.BorderSizePixel = 0
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.88
	shine.ZIndex = 20
	shine.Parent = f.bg
	f.shine = shine
	label(f.bg, "TAP TO COPY DISCORD INVITE   -   discord.gg/gZGJFyWUU", Enum.Font.GothamBold, Color3.fromRGB(150, 160, 255), UDim2.fromScale(0.2, 0.83), UDim2.fromScale(0.6, 0.09))
	return f
end

-- ===== BLACK HOLE banner: animated accretion disc, spiralling particles, wavy glowing "YADSAN HUB" =====
local function holeFace(part, face)
	part.Transparency = 1
	local f = newFace(part, face)
	f.sg.AlwaysOnTop = false
	f.bg.BackgroundTransparency = 1
	f.bg.ClipsDescendants = false
	for _, o in ipairs(f.bg:GetChildren()) do if o:IsA("UIStroke") or o:IsA("UIGradient") then o:Destroy() end end
	f.bgg, f.sg2 = Instance.new("UIGradient"), Instance.new("UIGradient") -- dummies for the shared animation loop
	local root = f.bg
	local H = Vector2.new(0.5, 0.5)
	local function box(parent, cx, cy, w, h, z)
		local o = Instance.new("Frame")
		o.AnchorPoint = H
		o.Position = UDim2.fromScale(cx, cy)
		o.Size = UDim2.fromScale(w, h)
		o.BackgroundTransparency = 1
		o.BorderSizePixel = 0
		o.ZIndex = z or 1
		o.Parent = parent
		return o
	end
	local function circle(o) Instance.new("UICorner", o).CornerRadius = UDim.new(1, 0) return o end
	local function ring(parent, cx, cy, w, h, thick, cols, tr, z)
		local o = circle(box(parent, cx, cy, w, h, z))
		local s = Instance.new("UIStroke")
		s.Thickness = thick
		s.Color = Color3.new(1, 1, 1)
		s.Transparency = tr or 0
		s.Parent = o
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(cols)
		g.Parent = s
		return o, g, s
	end
	local function seq(...)
		local t, n = {}, select("#", ...)
		for i = 1, n do t[i] = ColorSequenceKeypoint.new((i - 1) / (n - 1), (select(i, ...))) end
		return t
	end
	local C = Color3.fromRGB
	local grads = {}
	-- soft halo
	local halos = {}
	for i, sz in ipairs({ 1.0, 0.88, 0.76, 0.64 }) do
		local h = circle(box(root, 0.5, 0.5, sz, sz, 1))
		h.BackgroundColor3 = i < 3 and C(110, 50, 230) or C(255, 120, 60)
		h.BackgroundTransparency = 0.93 - i * 0.012
		halos[#halos + 1] = h
	end
	-- outer slow rings
	local _, g1 = ring(root, 0.5, 0.5, 0.96, 0.96, 5, seq(C(150, 90, 255), C(20, 10, 60), C(90, 220, 255), C(20, 10, 60), C(150, 90, 255)), 0.25, 2)
	local _, g2 = ring(root, 0.5, 0.5, 0.84, 0.84, 3, seq(C(255, 160, 80), C(30, 10, 40), C(255, 90, 170), C(30, 10, 40), C(255, 160, 80)), 0.45, 2)
	grads[#grads + 1] = { g1, 40 }
	grads[#grads + 1] = { g2, -70 }
	-- back half of the accretion disc (behind the hole)
	local discCols = seq(C(255, 245, 200), C(255, 160, 50), C(230, 60, 160), C(110, 50, 230), C(60, 200, 255), C(255, 160, 50), C(255, 245, 200))
	local hotCols = seq(C(255, 255, 255), C(255, 220, 140), C(255, 120, 80), C(255, 255, 255), C(255, 220, 140), C(255, 255, 255))
	local function disc(parent, yc, hs, z)
		local _, a = ring(parent, 0.5, yc, 0.98, 0.30 * hs, 54, discCols, 0.05, z)
		local _, b = ring(parent, 0.5, yc, 0.70, 0.215 * hs, 24, hotCols, 0.0, z + 1)
		grads[#grads + 1] = { a, 55 }
		grads[#grads + 1] = { b, -95 }
	end
	disc(root, 0.5, 1, 3)
	-- the hole
	local hole = circle(box(root, 0.5, 0.5, 0.40, 0.40, 6))
	hole.BackgroundColor3 = C(0, 0, 0)
	hole.BackgroundTransparency = 0
	local _, g3 = ring(root, 0.5, 0.5, 0.405, 0.405, 9, seq(C(255, 255, 255), C(180, 120, 255), C(255, 190, 120), C(255, 255, 255)), 0, 7)
	local _, g4 = ring(root, 0.5, 0.5, 0.44, 0.44, 3, seq(C(120, 220, 255), C(255, 255, 255), C(200, 100, 255), C(120, 220, 255)), 0.4, 7)
	grads[#grads + 1] = { g3, 120 }
	grads[#grads + 1] = { g4, -160 }
	-- front half of the disc: lower half only (passes in front of the hole)
	local clip = Instance.new("Frame")
	clip.BackgroundTransparency = 1
	clip.BorderSizePixel = 0
	clip.ClipsDescendants = true
	clip.Position = UDim2.fromScale(0, 0.5)
	clip.Size = UDim2.fromScale(1, 0.5)
	clip.ZIndex = 9
	clip.Parent = root
	disc(clip, 0, 2, 9)
	-- star dust
	local stars = {}
	for i = 1, 34 do
		local s = circle(box(root, math.random(), math.random(), 0.006 + math.random() * 0.006, 0.006 + math.random() * 0.006, 4))
		s.BackgroundColor3 = Color3.new(1, 1, 1)
		stars[i] = { o = s, p = math.random() * 6.28, sp = 1 + math.random() * 3 }
	end
	-- particles spiralling into the hole
	local dots = {}
	for i = 1, 44 do
		local d = circle(box(root, 0.5, 0.5, 0.012, 0.012, 11))
		d.BackgroundColor3 = Color3.fromHSV(0.05 + math.random() * 0.75, 0.55, 1)
		d.BorderSizePixel = 0
		dots[i] = { o = d, a = math.random() * 6.28, r = 0.22 + math.random() * 0.28, v = 0.5 + math.random() * 0.9 }
	end
	-- title: every letter floats on its own wave
	local word = "YADSAN HUB"
	local letters = {}
	local tgroup = box(root, 0.5, 0.5, 1, 1, 20)
	local tscale = Instance.new("UIScale")
	tscale.Parent = tgroup
	for i = 1, #word do
		local ch = word:sub(i, i)
		if ch ~= " " then
			local l = Instance.new("TextLabel")
			l.AnchorPoint = H
			l.BackgroundTransparency = 1
			l.Position = UDim2.fromScale(0.5 + (i - 5) * 0.088, 0.5)
			l.Size = UDim2.fromScale(0.092, 0.17)
			l.Font = Enum.Font.GothamBlack
			l.Text = ch
			l.TextScaled = true
			l.TextColor3 = Color3.new(1, 1, 1)
			l.ZIndex = 21
			l.Parent = tgroup
			local st = Instance.new("UIStroke")
			st.Thickness = 7
			st.Color = C(60, 20, 150)
			st.Parent = l
			letters[#letters + 1] = { o = l, st = st, i = i }
		end
	end
	local sub = label(root, "TAP TO COPY DISCORD INVITE", Enum.Font.GothamBold, C(210, 190, 255), UDim2.fromScale(0.25, 0.77), UDim2.fromScale(0.5, 0.035))
	sub.ZIndex = 22
	local live = label(root, "SCRIPT USERS ONLINE", Enum.Font.GothamBold, C(150, 160, 255), UDim2.fromScale(0.3, 0.815), UDim2.fromScale(0.4, 0.026))
	live.ZIndex = 22
	-- relativistic jets (top and bottom) + periodic gravity ripple
	local jets = {}
	for i, dir in ipairs({ -1, 1 }) do
		local j = box(root, 0.5, 0.5 + dir * 0.27, 0.035, 0.46, 5)
		j.BackgroundTransparency = 0
		j.BackgroundColor3 = C(255, 255, 255)
		local jg = Instance.new("UIGradient")
		jg.Rotation = 90
		jg.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C(150, 210, 255)), ColorSequenceKeypoint.new(1, C(190, 110, 255)) })
		jg.Transparency = NumberSequence.new(dir == -1 and { NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 0.6), NumberSequenceKeypoint.new(1, 0.25) } or { NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.45, 0.6), NumberSequenceKeypoint.new(1, 1) })
		jg.Parent = j
		jets[i] = j
	end
	local ripples = {}
	for i = 1, 2 do
		local r = circle(box(root, 0.5, 0.5, 0.4, 0.4, 3))
		local rs = Instance.new("UIStroke")
		rs.Thickness = 6
		rs.Color = C(190, 150, 255)
		rs.Transparency = 1
		rs.Parent = r
		ripples[i] = { o = r, s = rs, ph = (i - 1) * 0.5 }
	end
	-- click shockwave
	local shock = circle(box(root, 0.5, 0.5, 0.3, 0.3, 25))
	shock.Visible = false
	local shs = Instance.new("UIStroke")
	shs.Thickness = 14
	shs.Color = C(255, 255, 255)
	shs.Parent = shock
	function f.shockFn()
		shock.Visible = true
		shock.Size = UDim2.fromScale(0.3, 0.3)
		shs.Transparency = 0
		TweenService:Create(shock, TweenInfo.new(0.9, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1.15, 1.15) }):Play()
		TweenService:Create(shs, TweenInfo.new(0.9), { Transparency = 1 }):Play()
		f.boost = 1
	end
	local nextLive = 0
	function f.tick(t, dt)
		local boost = f.boost or 0
		for _, g in ipairs(grads) do g[1].Rotation = (t * (g[2] * (1 + boost * 3))) % 360 end
		for i, h in ipairs(halos) do
			local k = 1 + math.sin(t * 1.3 + i) * 0.02
			h.Size = UDim2.fromScale(({ 1.0, 0.88, 0.76, 0.64 })[i] * k, ({ 1.0, 0.88, 0.76, 0.64 })[i] * k)
		end
		for _, s in ipairs(stars) do s.o.BackgroundTransparency = 0.25 + (math.sin(t * s.sp + s.p) + 1) * 0.37 end
		for _, d in ipairs(dots) do
			d.a = d.a + dt * d.v * (1.2 + (0.5 - d.r) * 5)
			d.r = d.r - dt * 0.018 * d.v
			if d.r < 0.205 then d.r = 0.5 d.a = math.random() * 6.28 end
			local x, y = math.cos(d.a) * d.r, math.sin(d.a) * d.r * 0.30
			d.o.Position = UDim2.fromScale(0.5 + x, 0.5 + y)
			local behind = y < 0 and math.abs(x) < 0.2
			d.o.Visible = not behind
			local sz = 0.006 + (d.r - 0.2) * 0.03
			d.o.Size = UDim2.fromScale(sz, sz)
		end
		tscale.Scale = 1 + math.sin(t * 1.5) * 0.015 + boost * 0.08
		for _, L in ipairs(letters) do
			local ph = t * 2.2 + L.i * 0.55
			L.o.Position = UDim2.fromScale(0.5 + (L.i - 5) * 0.088, 0.5 + math.sin(ph) * 0.014)
			L.o.Rotation = math.sin(ph * 0.8) * 3
			local hue = 0.74 + math.sin(t * 0.9 + L.i * 0.45) * 0.12
			L.o.TextColor3 = Color3.fromHSV(hue, 0.18 + (math.sin(ph) + 1) * 0.12, 1)
			L.st.Color = Color3.fromHSV(hue, 0.85, 0.55)
			L.st.Thickness = 7 + math.sin(ph) * 2
		end
		for i, j in ipairs(jets) do
			j.Size = UDim2.fromScale(0.03 + math.sin(t * 3 + i) * 0.008 + boost * 0.02, 0.44 + math.sin(t * 1.7 + i * 2) * 0.05 + boost * 0.12)
		end
		for _, r in ipairs(ripples) do
			local p = ((t * 0.16) + r.ph) % 1
			r.o.Size = UDim2.fromScale(0.42 + p * 0.62, 0.42 + p * 0.62)
			r.s.Transparency = 0.35 + p * 0.65
			r.s.Thickness = 7 * (1 - p) + 1
		end
		sub.TextTransparency = 0.15 + (math.sin(t * 2.4) + 1) * 0.2
		if t > nextLive then
			nextLive = t + 2
			pcall(function()
				local HC, M = NovaUI.HubChat, NovaUI.Music
				local n = HC and #HC.allUsers() or 0
				local tr = M and M.state == "playing" and M.queue[M.idx]
				live.Text = ("%d SCRIPT USERS ONLINE"):format(math.max(1, n)) .. (tr and ("  -  NOW PLAYING: " .. tr.title:upper():sub(1, 26)) or "")
			end)
		end
	end
	return f
end

local function staffFace(part, face, who)
	local f = newFace(part, face)
	pcall(function()
		NovaUI.MakeBlackhole(f.bg, 760, { Position = UDim2.fromScale(0.5, 0.36), ParticleCount = 10 })
	end)
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.36)
	ring.Size = UDim2.fromScale(0.62, 0.52)
	ring.BackgroundColor3 = Color3.fromRGB(12, 6, 26)
	ring.Parent = f.bg
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.Parent = ring
	Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
	local rs = Instance.new("UIStroke")
	rs.Thickness = 12
	rs.Color = Color3.new(1, 1, 1)
	rs.Parent = ring
	local rg = Instance.new("UIGradient")
	rg.Color = ColorSequence.new(who.colA, who.colB)
	rg.Parent = rs
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = who.uid and ("rbxthumb://type=AvatarHeadShot&id=%d&w=420&h=420"):format(who.uid) or ""
	img.Parent = ring
	Instance.new("UICorner", img).CornerRadius = UDim.new(1, 0)
	local nm = label(f.bg, who.name, Enum.Font.GothamBlack, Color3.new(1, 1, 1), UDim2.fromScale(0.08, 0.66), UDim2.fromScale(0.84, 0.1))
	nm.TextStrokeTransparency = 0.6
	local pill = Instance.new("Frame")
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.fromScale(0.5, 0.79)
	pill.Size = UDim2.fromScale(0.62, 0.12)
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.Parent = f.bg
	Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)
	local pg = Instance.new("UIGradient")
	pg.Color = ColorSequence.new(who.colA, who.colB)
	pg.Parent = pill
	local tl = label(pill, who.title, Enum.Font.GothamBlack, Color3.fromRGB(20, 8, 30), UDim2.fromScale(0.1, 0.12), UDim2.fromScale(0.8, 0.76))
	label(f.bg, "YADSAN HUB", Enum.Font.GothamBold, Color3.fromRGB(150, 130, 190), UDim2.fromScale(0.3, 0.925), UDim2.fromScale(0.4, 0.05))
	f.rg = rg
	f.pg = pg
	f.tscale = Instance.new("UIScale")
	f.tscale.Parent = ring
	return f
end


local function discordFace(part, face)
	local f = newFace(part, face)
	f.bgg.Color = ColorSequence.new(Color3.fromRGB(70, 82, 220), Color3.fromRGB(14, 12, 40))
	pcall(function() NovaUI.MakeBlackhole(f.bg, 200, { Position = UDim2.fromScale(0.1, 0.5), ParticleCount = 6 }) end)
	local mk = label(f.bg, "M", Enum.Font.GothamBlack, Color3.new(1, 1, 1), UDim2.fromScale(0.04, 0.2), UDim2.fromScale(0.12, 0.6))
	local t = label(f.bg, "JOIN OUR DISCORD", Enum.Font.GothamBlack, Color3.new(1, 1, 1), UDim2.fromScale(0.2, 0.1), UDim2.fromScale(0.76, 0.45))
	t.TextXAlignment = Enum.TextXAlignment.Left
	local u = label(f.bg, "discord.gg/gZGJFyWUU   -   tap to copy invite", Enum.Font.GothamBold, Color3.fromRGB(200, 205, 255), UDim2.fromScale(0.2, 0.58), UDim2.fromScale(0.76, 0.28))
	u.TextXAlignment = Enum.TextXAlignment.Left
	return f
end

local function profileFace(part, face)
	local f = newFace(part, face)
	local P = PALETTES[BCFG.pal] or PALETTES[1]
	f.bgg.Color = ColorSequence.new(P.bg1, P.bg2)
	pcall(function() NovaUI.MakeBlackhole(f.bg, 200, { Position = UDim2.fromScale(0.95, 0.5), ParticleCount = 6 }) end)
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0, 0.5)
	ring.Position = UDim2.fromScale(0.03, 0.5)
	ring.Size = UDim2.fromScale(0.7, 0.72)
	ring.BackgroundColor3 = Color3.fromRGB(12, 6, 26)
	ring.Parent = f.bg
	Instance.new("UIAspectRatioConstraint").Parent = ring
	Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
	local rs = Instance.new("UIStroke")
	rs.Thickness = 6
	rs.Color = Color3.new(1, 1, 1)
	rs.Parent = ring
	local rg = Instance.new("UIGradient")
	rg.Color = ColorSequence.new(P.a, P.b)
	rg.Parent = rs
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=420&h=420"):format(lp.UserId)
	img.Parent = ring
	Instance.new("UICorner", img).CornerRadius = UDim.new(1, 0)
	local lv, frac = Profile.level()
	local n = label(f.bg, BCFG.title ~= "" and BCFG.title or tostring(lp.DisplayName), Enum.Font.GothamBlack, Color3.new(1, 1, 1), UDim2.fromScale(0.27, 0.04), UDim2.fromScale(0.5, 0.24))
	n.TextXAlignment = Enum.TextXAlignment.Left
	local pill = Instance.new("Frame")
	pill.Position = UDim2.fromScale(0.79, 0.1)
	pill.Size = UDim2.fromScale(0.18, 0.22)
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.Parent = f.bg
	Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)
	local pg = Instance.new("UIGradient")
	pg.Color = ColorSequence.new(P.a, P.b)
	pg.Parent = pill
	label(pill, "LV " .. lv, Enum.Font.GothamBlack, Color3.fromRGB(20, 8, 30), UDim2.fromScale(0.1, 0.12), UDim2.fromScale(0.8, 0.76))
	local a = label(f.bg, "Account created  " .. Profile.joined() .. "  (" .. Profile.age() .. " days old)", Enum.Font.GothamMedium, Color3.fromRGB(210, 190, 255), UDim2.fromScale(0.27, 0.3), UDim2.fromScale(0.7, 0.16))
	a.TextXAlignment = Enum.TextXAlignment.Left
	local d = label(f.bg, Profile.days .. " days with YADSAN HUB  -  " .. math.floor((Profile.minutes or 0) / 60) .. "h played", Enum.Font.GothamMedium, Color3.fromRGB(160, 140, 200), UDim2.fromScale(0.27, 0.48), UDim2.fromScale(0.7, 0.14))
	d.TextXAlignment = Enum.TextXAlignment.Left
	if BCFG.tag ~= "" then
		local tg = label(f.bg, '"' .. BCFG.tag .. '"', Enum.Font.GothamBold, P.a, UDim2.fromScale(0.27, 0.64), UDim2.fromScale(0.7, 0.16))
		tg.TextXAlignment = Enum.TextXAlignment.Left
	end
	local bar = Instance.new("Frame")
	bar.Position = UDim2.fromScale(0.27, 0.86)
	bar.Size = UDim2.fromScale(0.7, 0.07)
	bar.BackgroundColor3 = Color3.fromRGB(30, 18, 55)
	bar.Parent = f.bg
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(math.max(frac, 0.03), 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.Parent = bar
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	local fg = Instance.new("UIGradient")
	fg.Color = ColorSequence.new(P.a, P.b)
	fg.Parent = fill
	f.rg = rg
	return f
end

-- tap / click effect: a blackhole opens on the panel and vanishes after 2 seconds
local function burst(f)
	if f.shockFn then pcall(f.shockFn) return end
	if f.holeBox and f.holeBox.Parent then return end
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromScale(1, 1)
	box.ZIndex = 18
	box.Parent = f.bg
	local sc = Instance.new("UIScale")
	sc.Scale = 0.02
	sc.Parent = box
	f.holeBox = box
	local sz = math.clamp(f.bg.AbsoluteSize.Y * 0.95, 180, 620)
	local ok, hold, api = pcall(function()
		return NovaUI.MakeBlackhole(box, sz, { Position = UDim2.fromScale(0.5, 0.5), ParticleCount = 14 })
	end)
	if ok and api then pcall(function() api.Boost(1.5) end) end
	TweenService:Create(sc, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.5, function()
		if box.Parent then
			TweenService:Create(sc, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Scale = 0.02 }):Play()
		end
	end)
	task.delay(2.05, function() box:Destroy() end)
	if f.tscale then
		f.tscale.Scale = 1.12
		TweenService:Create(f.tscale, TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	f.boost = 1
end

local faces = {}
local function destroy()
	if conn then conn:Disconnect() conn = nil end
	for _, p in ipairs(parts) do p.part:Destroy() end
	parts, faces = {}, {}
end

local function makePart(size, cf, builder, amp, refW, onClick)
	local part = Instance.new("Part")
	part.Name = "YadsanSpawnBanner"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Color3.fromRGB(10, 5, 22)
	part.Size = size
	part:SetAttribute("refW", refW)
	part.CFrame = cf
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(150, 80, 255)
	light.Range = 40
	light.Brightness = 2
	light.Parent = part
	local cd = Instance.new("ClickDetector")
	cd.MaxActivationDistance = 400
	cd.Parent = part
	local fs = { builder(part, Enum.NormalId.Front), builder(part, Enum.NormalId.Back) }
	for _, f in ipairs(fs) do faces[#faces + 1] = f end
	cd.MouseClick:Connect(function()
		pcall(function() NovaUI.Sound("burst", 0.45, 3, true) end)
		for _, f in ipairs(fs) do burst(f) end
		light.Brightness = 8
		if onClick then pcall(onClick) end
	end)
	do
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Rate = 5
		pe.Lifetime = NumberRange.new(1.5, 2.6)
		pe.Speed = NumberRange.new(0.5, 2)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.LightEmission = 1
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		pe.Color = ColorSequence.new(Color3.fromRGB(190, 140, 255), Color3.fromRGB(140, 200, 255))
		pe.Parent = part
		local full = size
		part.Size = size * 0.05
		task.delay(0.15 * #parts, function()
			if part.Parent then
				TweenService:Create(part, TweenInfo.new(1.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = full }):Play()
			end
		end)
		task.delay(0.15 * #parts + 2, function()
			if part.Parent then part.Size = full end
		end)
	end
	part.Parent = workspace
	parts[#parts + 1] = { part = part, cf = cf, amp = amp, light = light }
end

-- how far a ray from the spawn runs before it hits something solid-looking (see-through parts are skipped)
local function clearDist(origin, dir, maxD)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local ign = { lp.Character }
	for _, p in ipairs(parts) do ign[#ign + 1] = p.part end
	rp.FilterDescendantsInstances = ign
	local o, left = origin, maxD
	for _ = 1, 6 do
		local r = workspace:Raycast(o, dir * left, rp)
		if not r then return maxD end
		if r.Instance.Transparency < 0.9 and r.Instance.CanCollide then
			return maxD - left + r.Distance
		end
		ign[#ign + 1] = r.Instance
		rp.FilterDescendantsInstances = ign
		o, left = r.Position, left - r.Distance
		if left <= 1 then return maxD end
	end
	return maxD
end

local BANNER_SIZE = Vector3.new(36, 36, 0.4)
-- true when a banner box at cf touches visible parts (trees, walls, buildings) - ground right under it is ignored
local function boxBlocked(cf, floorY)
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	local ign = { lp.Character }
	for _, p in ipairs(parts) do ign[#ign + 1] = p.part end
	op.FilterDescendantsInstances = ign
	local hits = workspace:GetPartBoundsInBox(cf, BANNER_SIZE + Vector3.new(2, 2, 10), op)
	for _, h in ipairs(hits) do
		if h.Transparency < 0.9 and (h.Position.Y + h.Size.Y / 2) > floorY + 3 then return true end
	end
	return false
end
-- nothing solid/visible between the spawn and the banner
local function sightClear(from, to)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local ign = { lp.Character }
	for _, p in ipairs(parts) do ign[#ign + 1] = p.part end
	rp.FilterDescendantsInstances = ign
	local o = from
	for _ = 1, 6 do
		local r = workspace:Raycast(o, to - o, rp)
		if not r then return true end
		if r.Instance.Transparency < 0.9 then return false end
		ign[#ign + 1] = r.Instance
		rp.FilterDescendantsInstances = ign
		o = r.Position
	end
	return true
end

local function create(floor, look)
	destroy()
	if not floor then floor, look = findSpawnCF() end
	if not floor then return false end
	local up = Vector3.new(0, 1, 0)
	local right = look:Cross(up).Unit
	-- search for a spot where the big banner is not inside a tree/building and can be seen from the spawn
	local best, bestDist, bestDeg
	local eye = floor + up * 6
	for _, h in ipairs({ 22, 26, 31, 38 }) do
		for _, d in ipairs({ 42, 36, 30, 24 }) do
			for _, deg in ipairs({ 0, 25, -25, 50, -50, 80, -80, 115, -115, 180 }) do
				local rad = math.rad(deg)
				local dv = (look * math.cos(rad) + right * math.sin(rad)).Unit
				local pos = floor + dv * d + up * h
				local cf = CFrame.lookAt(pos, Vector3.new(floor.X, pos.Y, floor.Z))
				if not boxBlocked(cf, floor.Y) and sightClear(eye, pos) then
					best, bestDist, bestDeg = cf, d, deg
					break
				end
			end
			if best then break end
		end
		if best then break end
	end
	if not best then
		local pos = floor + look * 40 + up * 28
		best, bestDist, bestDeg = CFrame.lookAt(pos, Vector3.new(floor.X, pos.Y, floor.Z)), 40, 0
	end
	base = best
	local dist, lookDeg = bestDist, bestDeg
	local ok, e = pcall(makePart, BANNER_SIZE, base, holeFace, 0.6, 36, copyDiscord)
	if not ok then notify("Spawn banner", "panel error: " .. tostring(e)) end
	NovaUI.BannerInfo = ('banner %d studs from spawn at %d deg'):format(dist, lookDeg)
	local t0 = os.clock()
	conn = RunService.Heartbeat:Connect(function(dt)
		local t = os.clock() - t0
		for i, p in ipairs(parts) do
			if p.part.Parent then
				p.part.CFrame = p.cf * CFrame.new(0, math.sin(t * 0.9 + i) * p.amp, 0) * CFrame.Angles(0, 0, math.sin(t * 0.5 + i) * 0.006)
				p.light.Brightness = math.max(2 + math.sin(t * 2) * 0.6, p.light.Brightness - dt * 14)
			end
		end
		for _, f in ipairs(faces) do
			f.bgg.Rotation = 35 + math.sin(t * 0.4) * 25
			f.boost = math.max(0, (f.boost or 0) - dt * 1.2)
			if f.tick then f.tick(t, dt) end
			f.sg2.Rotation = (t * (80 + (f.boost or 0) * 700)) % 360
			if f.live and f.live.Parent and (f.liveT or 0) < t then
				f.liveT = t + 2
				pcall(function()
					local HC, M = NovaUI.HubChat, NovaUI.Music
					local n = HC and #HC.allUsers() or 0
					local tr = M and M.state == "playing" and M.queue[M.idx]
					f.live.Text = ("%d SCRIPT USERS ONLINE"):format(math.max(1, n)) .. (tr and ("   -   NOW PLAYING: " .. tr.title:upper():sub(1, 28)) or "   -   LIFE TOGETHER RP")
				end)
			end
			if f.tscale then f.tscale.Scale = 1 + math.sin(t * 1.6) * 0.018 end
			if f.shine and f.shine.Parent then f.shine.Position = UDim2.fromScale(-0.2 + ((t * 0.22) % 1.6), 0.5) end
			if f.tg then f.tg.Offset = Vector2.new(math.sin(t * 1.2) * 0.35, 0) end
			if f.rg then f.rg.Rotation = (t * 120) % 360 end
		end
	end)
	return true
end

local ProfTab = Window:CreateTab({ Name = "Profile", Icon = "user" })
NovaUI.ProfTab = ProfTab
local pS = ProfTab:Section({ Title = "Your YADSAN profile", Icon = "user", Side = "Left" })
local pLbl = pS:Label("...")
local function pRefresh()
	local lv, frac, xp, nxt = Profile.level()
	pLbl:Set(("%s (@%s)\nLevel %d  -  %d / %d XP\nAccount created: %s (%d days old)\nDays with YADSAN HUB: %d  -  streak %d (best %d)  -  time used: %dh %dm\nFits copied: %d  -  fits saved: %d  -  messages: %d\nFirst use: %s\n\n%s"):format(lp.DisplayName, lp.Name, lv, xp, nxt, Profile.joined(), Profile.age(), Profile.days or 0, Profile.streak or 1, Profile.best or 1, math.floor((Profile.minutes or 0) / 60), (Profile.minutes or 0) % 60, Profile.copies or 0, Profile.saves or 0, Profile.msgs or 0, os.date("%d %b %Y", Profile.first), Profile.achievements()))
end
pRefresh()
task.spawn(function() while true do task.wait(30) pcall(pRefresh) end end)
pS:Paragraph({ Title = "How levels work", Content = "+25 XP the first time you open the hub each day, +1 XP for every minute you use it. Everything (profile, fits, chat history, app theme) is stored in your executor's YADSAN_HUB folder." })
local dS = ProfTab:Section({ Title = "Community", Icon = "chat", Side = "Right" })
local bS = ProfTab:Section({ Title = "My banner", Icon = "star", Side = "Left" })
local function rebuildBanners()
	bcfgSave()
	if NovaUI.SpawnBanner then NovaUI.SpawnBanner.Set(false) NovaUI.SpawnBanner.Set(true) end
end
bS:Paragraph({ Title = "Make it yours", Content = "Your profile banner (below the spawn banner) can have your own title, a tagline and a colour style. Saved in YADSAN_HUB/banner.json." })
local bTitle = bS:Input({ Placeholder = "Banner title (empty = display name)", Callback = function(t) BCFG.title = tostring(t or ""):sub(1, 24) rebuildBanners() end })
local bTag = bS:Input({ Placeholder = "Tagline, e.g. Life RP legend", Callback = function(t) BCFG.tag = tostring(t or ""):sub(1, 40) rebuildBanners() end })
for i, p in ipairs(PALETTES) do
	bS:Button({ Title = "Style: " .. p.name, Callback = function() BCFG.pal = i rebuildBanners() end })
end
dS:Button({ Title = "Copy Discord invite", Style = "Primary", Callback = copyDiscord })
dS:Button({ Title = "Rebuild spawn banners", Callback = function() if NovaUI.SpawnBanner then NovaUI.SpawnBanner.Set(false) NovaUI.SpawnBanner.Set(true) end end })

-- resolve the staff avatars by username (no ids hard coded)
task.spawn(function()
	for _, who in ipairs(STAFF) do
		local ok, id = pcall(function() return PLAYERS:GetUserIdFromNameAsync(who.name) end)
		if ok and type(id) == "number" then who.uid = id end
	end
end)

NovaUI.SpawnBanner = {
	Set = function(on)
		if on then
			if #parts == 0 then create() end
		else
			destroy()
		end
	end,
	PlaceHere = function()
		local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		if not root then return false end
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if look.Magnitude < 0.1 then look = Vector3.new(0, 0, -1) end
		return create(Vector3.new(root.Position.X, root.Position.Y - 3, root.Position.Z), look.Unit)
	end,
}
task.spawn(function()
	local w = 0
	while not (lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")) and w < 20 do
		task.wait(0.5)
		w = w + 0.5
	end
	while NovaUI.HoldOpen do task.wait(0.3) end
	-- wait a moment for the staff avatars to resolve
	local t = 0
	while t < 4 and not (STAFF[1].uid and STAFF[2].uid) do task.wait(0.2) t = t + 0.2 end
	if NovaUI.SpawnBannerOn ~= false then
		local ok, err = pcall(create)
		if not ok then notify("Spawn banner", "Could not build: " .. tostring(err)) end
		if ok then
			local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
			local n, d = 0, nil
			for _, p in ipairs(parts) do
				n = n + 1
				if root then d = d or (p.part.Position - root.Position).Magnitude end
			end
			notify("Spawn banner", ("%d panels built%s"):format(n, d and (", main one " .. math.floor(d) .. " studs from you") or ""))
		end
		if ok and NovaUI.BannerDist and NovaUI.BannerDist > 60 then
			notify("Spawn banner", ("Banner is at the spawn, %d studs from you. Settings > 'Put banner in front of me' brings it here."):format(NovaUI.BannerDist))
		end
	end
end)

-- ===== staff tools: user list (staff only) and the script ban list =====
-- BAN LIST: the owner puts the raw link of a text file here (one userId or username per line, # = comment).
-- Anyone listed is shut out of the hub when it starts. This is checked by the script itself, so it only stops
-- people running the unmodified script; it cannot kick anyone from the Roblox server.
local BANLIST_URL = ""
local HC = NovaUI.HubChat
local myStaff = HC and HC.STAFF[lp.Name:lower()]
task.spawn(function()
	while true do
	if BANLIST_URL == "" or myStaff or NovaUI.Banned then return end
	local ok, body = pcall(function() return game:HttpGet(BANLIST_URL) end)
	if ok then
	for line in tostring(body):gsub("#[^\r\n]*", ""):gmatch("[^\r\n]+") do
		local id = line:match("^%s*(%d+)")
		local nm = line:match("^%s*([%w_]+)%s*$")
		if (id and tonumber(id) == lp.UserId) or (nm and nm:lower() == lp.Name:lower()) then
			NovaUI.Banned = true
			notify("YADSAN HUB", "You are banned from using this script.")
			pcall(function() NovaUI.SpawnBanner.Set(false) end)
			pcall(function() NovaUI._window:Destroy() end)
			return
		end
	end
	end
	task.wait(300)
	end
end)
if myStaff then
	local SW = Window:CreateTab({ Name = "Staff", Icon = "star" })
	local sl = SW:Section({ Title = "YADSAN HUB users online", Icon = "user", Side = "Left" })
	local lbl = sl:Label("loading...")
	local function refresh()
		local list = HC.allUsers()
		local out = { #list .. " users seen in the last 40 min" }
		for i, u in ipairs(list) do
			if i > 40 then break end
			out[#out + 1] = ("%s (@%s)  id %s  %s  %dm ago"):format(u.d, u.n, tostring(u.u or "?"), (u.s == game.JobId) and "[your server]" or "[other server]", math.floor((os.time() - u.t) / 60))
		end
		lbl:Set(table.concat(out, "\n"))
	end
	refresh()
	task.spawn(function() while true do task.wait(20) pcall(refresh) end end)
	local function exportUsers()
		pcall(function()
			pcall(makefolder, "YADSAN_HUB")
			local t = {}
			for _, u in ipairs(HC.allUsers()) do t[#t + 1] = { name = u.n, display = u.d, id = u.u, server = u.s, seen = u.t } end
			writefile("YADSAN_HUB/staff_users.json", HttpService:JSONEncode(t))
		end)
	end
	task.spawn(function() while true do task.wait(60) exportUsers() end end)
	local ps = SW:Section({ Title = "Staff powers", Icon = "star", Side = "Right" })
	ps:Paragraph({ Title = "Announce / mute", Content = "Announcement pops up for every YADSAN HUB user with a sound and lands in Global chat. Mute stops a user's messages in Hub Chat for everyone (unmute undoes it). Both only work from owner/admin accounts." })
	local annBox = ps:Input({ Placeholder = "Announcement text" })
	ps:Button({ Title = "Send announcement", Style = "Primary", Callback = function()
		local ok = HC.announce(annBox:Get())
		notify("Staff", ok and "Announcement sent" or "Could not send (empty text or slow down)")
	end })
	local muteBox = ps:Input({ Placeholder = "Roblox username to mute / unmute" })
	ps:Button({ Title = "Mute in Hub Chat", Callback = function()
		local n = tostring(muteBox:Get() or "")
		if HC.STAFF[n:lower()] then notify("Staff", "You cannot mute staff") return end
		notify("Staff", HC.mute(n, true) and (n .. " muted") or "Type a username first")
	end })
	ps:Button({ Title = "Unmute", Callback = function()
		notify("Staff", HC.mute(muteBox:Get(), false) and "Unmuted" or "Type a username first")
	end })
	ps:Button({ Title = "Copy user list to clipboard", Callback = function()
		local t = {}
		for _, u in ipairs(HC.allUsers()) do t[#t + 1] = ("%s (@%s) id %s"):format(u.d, u.n, tostring(u.u or "?")) end
		pcall(setclipboard, table.concat(t, "\n"))
		notify("Staff", #t .. " users copied")
	end })
	sl:Button({ Title = "Refresh now", Callback = function() pcall(HC.poll) refresh() end })
	sl:Button({ Title = "Copy ban-list lines (id # name)", Style = "Primary", Callback = function()
		local t = {}
		for _, u in ipairs(HC.allUsers()) do
			if not HC.STAFF[u.n:lower()] and u.u then t[#t + 1] = u.u .. "  # " .. u.n end
		end
		pcall(function() setclipboard(table.concat(t, "\n")) end)
		notify("Staff", "Copied. Paste the lines you want banned into your ban-list file.")
	end })
	local BL = "YADSAN_HUB/banlist.txt"
	local bl = SW:Section({ Title = "Ban list file", Icon = "settings", Side = "Left" })
	bl:Input({ Placeholder = "userId or username to add (Enter)", Callback = function(t)
		t = tostring(t or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if t == "" then return end
		pcall(function()
			pcall(makefolder, "YADSAN_HUB")
			local old = (isfile and isfile(BL)) and readfile(BL) or ""
			writefile(BL, old .. (old ~= "" and "\n" or "") .. t)
		end)
		notify("Staff", "Added to " .. BL)
	end })
	bl:Button({ Title = "Copy ban list file", Callback = function()
		local ok, body = pcall(function() return (isfile and isfile(BL)) and readfile(BL) or "" end)
		pcall(function() setclipboard(ok and body or "") end)
		notify("Staff", "Ban list copied. Upload it and put the raw link in BANLIST_URL.")
	end })
	local sh = SW:Section({ Title = "How banning works", Icon = "settings", Side = "Right" })
	sh:Paragraph({ Title = "Ban from the script", Content = "Put the ids you want banned in a text file online (one per line) and set BANLIST_URL at the top of the Staff block in this script to its raw link. Banned users are locked out when they start the hub. The script cannot kick anyone from the Roblox server." })
end
end)()


-- hub preferences are remembered in the executor folder (YADSAN_HUB/settings.json)
do
	local SF = "YADSAN_HUB/settings.json"
	local keys = { "Haptics", "UISounds", "UIAnim", "BGBlur", "SpawnBanner", "Ambient" }
	task.spawn(function()
		task.wait(4)
		pcall(function()
			if isfile and isfile(SF) then
				local d = HttpService:JSONDecode(readfile(SF))
				for _, k in ipairs(keys) do
					if type(d[k]) == "boolean" and Window._setters[k] and NovaUI.Flags[k] ~= d[k] then
						pcall(Window._setters[k], d[k])
					end
				end
			end
		end)
		local last = ""
		while true do
			task.wait(10)
			local t = {}
			for _, k in ipairs(keys) do t[k] = NovaUI.Flags[k] end
			local ok, enc = pcall(function() return HttpService:JSONEncode(t) end)
			if ok and enc ~= last then
				last = enc
				pcall(function()
					pcall(makefolder, "YADSAN_HUB")
					writefile(SF, enc)
				end)
			end
		end
	end)
end


-- RGB "YADSAN HUB" sign: you aim at the exact spot (e.g. the middle tube of the playground) and place it there.
-- Saved in YADSAN_HUB/sign.json and restored every time the script runs.
task.spawn(function()
	local RS = game:GetService("RunService")
	local HS = game:GetService("HttpService")
	local FILE = "YADSAN_HUB/sign.json"
	local S = { has = false, px = 0, py = 0, pz = 0, nx = 0, ny = 0, nz = 1, w = 16, roll = 0, off = 0.12 }
	pcall(function()
		if isfile and isfile(FILE) then
			local d = HS:JSONDecode(readfile(FILE))
			for k in pairs(S) do if d[k] ~= nil then S[k] = d[k] end end
		end
	end)
	local function save()
		pcall(function()
			if makefolder and not (isfolder and isfolder("YADSAN_HUB")) then makefolder("YADSAN_HUB") end
			writefile(FILE, HS:JSONEncode(S))
		end)
	end
	-- remove any older sign (the swing one)
	for _, d in ipairs(workspace:GetDescendants()) do
		if d.Name == "YadsanSwingSign" or d.Name == "YadsanRgbSign" then pcall(function() d:Destroy() end) end
	end
	local part, grad
	local function clear()
		if part then pcall(function() part:Destroy() end) end
		part, grad = nil, nil
	end
	local function build()
		clear()
		if not S.has then return end
		local pos, n = Vector3.new(S.px, S.py, S.pz), Vector3.new(S.nx, S.ny, S.nz)
		if n.Magnitude < 0.1 then n = Vector3.new(0, 0, 1) end
		n = n.Unit
		local p = Instance.new("Part")
		p.Name = "YadsanRgbSign"
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Transparency = 1
		p.Size = Vector3.new(S.w, S.w * 0.26, 0.1)
		p.CFrame = CFrame.lookAt(pos + n * S.off, pos + n * (S.off + 1)) * CFrame.Angles(0, 0, math.rad(S.roll))
		p.Parent = workspace
		part = p
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			local sg = Instance.new("SurfaceGui")
			sg.Face = face
			sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sg.PixelsPerStud = 60
			sg.LightInfluence = 0
			sg.Brightness = 2
			sg.AlwaysOnTop = false
			sg.MaxDistance = 400
			sg.Parent = p
			local plate = Instance.new("Frame")
			plate.Size = UDim2.fromScale(1, 1)
			plate.BackgroundColor3 = Color3.fromRGB(6, 4, 16)
			plate.BackgroundTransparency = 0.45
			plate.BorderSizePixel = 0
			plate.Parent = sg
			local uc = Instance.new("UICorner")
			uc.CornerRadius = UDim.new(0.22, 0)
			uc.Parent = plate
			local st = Instance.new("UIStroke")
			st.Thickness = 3
			st.Color = Color3.new(1, 1, 1)
			st.Parent = plate
			local sgr = Instance.new("UIGradient")
			local k = {}
			for i = 0, 6 do k[#k + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i % 6 / 6, 0.9, 1)) end
			k[#k] = ColorSequenceKeypoint.new(1, Color3.fromHSV(0, 0.9, 1))
			sgr.Color = ColorSequence.new(k)
			sgr.Parent = st
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(0.92, 0.7)
			t.AnchorPoint = Vector2.new(0.5, 0.5)
			t.Position = UDim2.fromScale(0.5, 0.5)
			t.Text = "YADSAN HUB"
			t.Font = Enum.Font.GothamBlack
			t.TextScaled = true
			t.TextColor3 = Color3.new(1, 1, 1)
			t.Parent = plate
			local g = Instance.new("UIGradient")
			g.Color = ColorSequence.new(k)
			g.Parent = t
			if face == Enum.NormalId.Front then grad = { g, sgr } end
			p:SetAttribute("n", (p:GetAttribute("n") or 0) + 1)
			if face == Enum.NormalId.Back then grad[3], grad[4] = g, sgr end
		end
	end
	RS.Heartbeat:Connect(function()
		if part and part.Parent and grad then
			local t = os.clock()
			local off = Vector2.new((t * 0.4) % 2 - 1, 0)
			grad[1].Offset = off
			if grad[3] then grad[3].Offset = off end
			local r = (t * 90) % 360
			grad[2].Rotation = r
			if grad[4] then grad[4].Rotation = r end
		elseif S.has and not (part and part.Parent) then
			-- streamed out / destroyed: rebuild now and then
			if (S._t or 0) < os.clock() then S._t = os.clock() + 5 build() end
		end
	end)
	build()
	if not S.has then
		task.delay(12, function()
			if not S.has then notify("RGB sign", "Go next to the middle tube, look at it, then tap the M button > 'Sign here'.") end
		end)
	end

	local function aimHit()
		local cam = workspace.CurrentCamera
		if not cam then return nil end
		local vp = cam.ViewportSize
		local ray = cam:ViewportPointToRay(vp.X / 2, vp.Y / 2)
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		local ex = {}
		if lp.Character then ex[#ex + 1] = lp.Character end
		if part then ex[#ex + 1] = part end
		rp.FilterDescendantsInstances = ex
		return workspace:Raycast(ray.Origin, ray.Direction * 400, rp)
	end
	local function placeAim()
		local hit = aimHit()
		if not hit then notify("Sign", "Nothing under the crosshair. Look at the tube from close and try again.") return end
		S.has = true
		S.px, S.py, S.pz = hit.Position.X, hit.Position.Y, hit.Position.Z
		S.nx, S.ny, S.nz = hit.Normal.X, hit.Normal.Y, hit.Normal.Z
		S.roll = 0
		build() save()
		notify("Sign", "YADSAN HUB sign placed on " .. hit.Instance.Name .. ". Adjust with Bigger / Smaller / Rotate / Out / In.")
	end
	-- first guess: nearest tube / tunnel / pipe shaped part around you
	local function placeNearest()
		local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local best, bd
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "YadsanRgbSign" then
				local nm = d.Name:lower()
				local pn = d.Parent and d.Parent.Name:lower() or ""
				local c = d.Color
				local big = math.max(d.Size.X, d.Size.Y, d.Size.Z) > 6
				local blue = c.B > c.R + 0.2 and c.B >= c.G
				local orange = c.R > 0.78 and c.G > 0.3 and c.G < 0.68 and c.B < 0.35
				if nm:find("tube") or nm:find("tunnel") or nm:find("pipe") or pn:find("tube") or pn:find("tunnel") or (big and d.CanCollide and (blue or orange)) then
					local dist = (d.Position - root.Position).Magnitude
					if dist < 150 and (not bd or dist < bd) then best, bd = d, dist end
				end
			end
		end
		if not best then notify("Sign", "No tube found by name. Use 'Place sign where I look' instead.") return end
		local toMe = root.Position - best.Position
		local dir = best.CFrame:VectorToWorldSpace(Vector3.new(0, 0, 1))
		local pick = Vector3.new(0, 0, 1)
		for _, v in ipairs({ best.CFrame.RightVector, -best.CFrame.RightVector, best.CFrame.LookVector, -best.CFrame.LookVector }) do
			if v:Dot(toMe) > pick:Dot(toMe) or pick == Vector3.new(0, 0, 1) then if math.abs(v.Y) < 0.5 then pick = v end end
		end
		local half = math.max(best.Size.X, best.Size.Z) / 2
		S.has = true
		S.px, S.py, S.pz = best.Position.X + pick.X * half, best.Position.Y, best.Position.Z + pick.Z * half
		S.nx, S.ny, S.nz = pick.X, 0, pick.Z
		build() save()
		notify("Sign", "Sign placed on " .. best.Name .. ". Not right? Look at the tube and press 'Place sign where I look'.")
	end
	local ProfTab = NovaUI.ProfTab
	NovaUI.PlaceSign = placeAim
	local sS = ProfTab:Section({ Title = "RGB YADSAN HUB sign", Icon = "star", Side = "Right" })
	sS:Paragraph({ Title = "Put it exactly on the tube", Content = "Stand near the blue/orange middle tube, point the camera so the crosshair (screen centre) is on the tube, then press Place. Saved for next time." })
	sS:Button({ Title = "Place sign where I look", Style = "Primary", Callback = placeAim })
	sS:Button({ Title = "Auto-guess nearest tube", Callback = placeNearest })
	sS:Button({ Title = "Bigger", Callback = function() if S.has then S.w = math.min(60, S.w * 1.15) build() save() end end })
	sS:Button({ Title = "Smaller", Callback = function() if S.has then S.w = math.max(3, S.w / 1.15) build() save() end end })
	sS:Button({ Title = "Rotate 90 degrees", Callback = function() if S.has then S.roll = (S.roll + 90) % 360 build() save() end end })
	sS:Button({ Title = "Move out", Callback = function() if S.has then S.off = S.off + 0.15 build() save() end end })
	sS:Button({ Title = "Move in", Callback = function() if S.has then S.off = math.max(0.02, S.off - 0.15) build() save() end end })
	sS:Button({ Title = "Remove sign", Callback = function() S.has = false clear() save() notify("Sign", "Sign removed.") end })
	defCmd("sign", "sign", "Place the RGB sign where you look", function() placeAim() return "sign" end)
end)

-- floating launcher: always-available way to open the apps + music controls (works even if the phone icons are hidden)
task.spawn(function()
	task.wait(3)
	local UIS = game:GetService("UserInputService")
	local TS = game:GetService("TweenService")
	local RS = game:GetService("RunService")
	local gui = Instance.new("ScreenGui")
	gui.Name = "YadsanLauncher"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = Window.Gui.Parent
	local function mk(c, p, par)
		local o = Instance.new(c)
		for k, v in pairs(p) do o[k] = v end
		o.Parent = par
		return o
	end
	local function corner(o, r) mk("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
	local pos0 = UDim2.new(0, 10, 0.5, -20)
	local FS = 46
	local fab = mk("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromOffset(FS, FS), Position = pos0 }, gui)
	local fcore = mk("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(FS, FS) }, fab)
	corner(fcore, FS)
	local function fring(size, thick, cols, tr)
		local r = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(size, size) }, fcore)
		corner(r, 200)
		local st = mk("UIStroke", { Thickness = thick, Color = Color3.new(1, 1, 1), Transparency = tr or 0 }, r)
		return mk("UIGradient", { Color = cols }, st)
	end
	local function fseq(...)
		local t, n = {}, select("#", ...)
		for i = 1, n do t[i] = ColorSequenceKeypoint.new((i - 1) / (n - 1), (select(i, ...))) end
		return ColorSequence.new(t)
	end
	local fg1 = fring(1.0, 3, fseq(Color3.fromRGB(120, 210, 255), Color3.fromRGB(180, 90, 255), Color3.fromRGB(255, 170, 110), Color3.fromRGB(120, 210, 255)))
	local fg2 = fring(0.72, 2, fseq(Color3.new(1, 1, 1), Color3.fromRGB(110, 60, 220), Color3.new(1, 1, 1)), 0.3)
	local fhole = mk("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.5) }, fcore)
	corner(fhole, 100)
	local fm = mk("TextLabel", { BackgroundTransparency = 1, Text = "M", Font = Enum.Font.GothamBlack, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = 5 }, fcore)
	mk("UIStroke", { Thickness = 1.5, Color = Color3.fromRGB(130, 70, 240) }, fm)
	local fdisc = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.45, 0.28), ZIndex = 4 }, fcore)
	corner(fdisc, 40)
	local fds = mk("UIStroke", { Thickness = 2.5, Color = Color3.new(1, 1, 1), Transparency = 0.15 }, fdisc)
	local fgd = mk("UIGradient", { Color = fseq(Color3.fromRGB(255, 230, 160), Color3.fromRGB(255, 110, 70), Color3.fromRGB(190, 80, 255), Color3.fromRGB(255, 230, 160)) }, fds)
	local panel = mk("Frame", { BackgroundColor3 = Color3.fromRGB(14, 10, 28), BackgroundTransparency = 0.08, Size = UDim2.fromOffset(190, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, BorderSizePixel = 0 }, gui)
	corner(panel, 14)
	mk("UIStroke", { Color = Color3.fromRGB(150, 100, 240), Thickness = 1.5, Transparency = 0.3 }, panel)
	mk("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, panel)
	mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, panel)
	local function row(h, order)
		return mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, h), LayoutOrder = order }, panel)
	end
	local function button(par, text, size, pos, fn, accent)
		local b = mk("TextButton", { Text = text, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = true, BackgroundColor3 = accent and Color3.fromRGB(110, 60, 220) or Color3.fromRGB(38, 28, 66), Size = size, Position = pos, BorderSizePixel = 0 }, par)
		corner(b, 9)
		b.MouseButton1Click:Connect(function() pcall(fn) end)
		return b
	end
	local function openApp(i)
		local apps = NovaUI.PhoneApps
		if apps and apps[i] then
			panel.Visible = false
			apps[i].open()
		end
	end
	local r1 = row(30, 1)
	button(r1, "Chat", UDim2.new(0.33, -3, 1, 0), UDim2.fromScale(0, 0), function() openApp(1) end)
	button(r1, "Fits", UDim2.new(0.33, -3, 1, 0), UDim2.fromScale(0.335, 0), function() openApp(2) end)
	button(r1, "Music", UDim2.new(0.33, -3, 1, 0), UDim2.fromScale(0.67, 0), function() openApp(3) end, true)
	local song = mk("TextLabel", { BackgroundTransparency = 1, Text = "Nothing playing", Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Color3.fromRGB(200, 180, 255), TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2 }, panel)
	local r2 = row(30, 3)
	button(r2, "<<", UDim2.new(0.25, -3, 1, 0), UDim2.fromScale(0, 0), function() NovaUI.Music.step(-1) end)
	local pp = button(r2, "Play", UDim2.new(0.5, -3, 1, 0), UDim2.fromScale(0.25, 0), function() NovaUI.Music.toggle() end, true)
	button(r2, ">>", UDim2.new(0.25, -3, 1, 0), UDim2.fromScale(0.75, 0), function() NovaUI.Music.step(1) end)
	local r3 = row(30, 4)
	button(r3, "Random fit", UDim2.new(0.5, -3, 1, 0), UDim2.fromScale(0, 0), function()
		local FS = NovaUI.FitStore
		local names = FS and FS.names() or {}
		if #names == 0 then notify("Fit Saver", "No saved fits yet") return end
		local n = names[math.random(1, #names)]
		notify("Fit Saver", "Wearing " .. n .. "...")
		task.spawn(function() FS.wear(n) end)
	end)
	button(r3, "Sign here", UDim2.new(0.5, -3, 1, 0), UDim2.fromScale(0.5, 0), function() if NovaUI.PlaceSign then NovaUI.PlaceSign() end end)
	-- open / close + drag
	local dragging, moved, startIn, startPos = false, false, nil, nil
	fab.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, moved, startIn, startPos = true, false, i.Position, fab.Position
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - startIn
			if d.Magnitude > 6 then moved = true end
			if moved then fab.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			if not moved then panel.Visible = not panel.Visible end
		end
	end)
	RS.Heartbeat:Connect(function()
		panel.Position = UDim2.new(fab.Position.X.Scale, fab.Position.X.Offset + 52, fab.Position.Y.Scale, fab.Position.Y.Offset)
		local sp = os.clock() * 110
		fg1.Rotation, fg2.Rotation, fgd.Rotation = sp % 360, (-sp * 1.5) % 360, (sp * 0.6) % 360
		local pz = 1 + math.sin(os.clock() * 2.2) * 0.03
		fcore.Size = UDim2.fromOffset(FS * pz, FS * pz)
		if panel.Visible then
			local M = NovaUI.Music
			local t = M and M.queue[M.idx]
			song.Text = t and (t.title .. " - " .. t.artist) or "Nothing playing"
			pp.Text = (M and M.state == "playing") and "Pause" or "Play"
		end
	end)
end)

-- ===== floating MUSIC black hole button + standalone music window (search, categories, play) =====
task.spawn(function()
	task.wait(3.5)
	local UIS = game:GetService("UserInputService")
	local RS = game:GetService("RunService")
	local TS = game:GetService("TweenService")
	local C = Color3.fromRGB
	local gui = Instance.new("ScreenGui")
	gui.Name = "YadsanMusicWin"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 52
	gui.Parent = Window.Gui.Parent
	local function mk(c, p, par)
		local o = Instance.new(c)
		for k, v in pairs(p) do o[k] = v end
		o.Parent = par
		return o
	end
	local function corner(o, r) return mk("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
	local function seq(...)
		local t, n = {}, select("#", ...)
		for i = 1, n do t[i] = ColorSequenceKeypoint.new((i - 1) / (n - 1), (select(i, ...))) end
		return ColorSequence.new(t)
	end
	local function label(par, text, size, col, font, props)
		local p = { BackgroundTransparency = 1, Text = text, TextSize = size, TextColor3 = col, Font = font or Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left }
		for k, v in pairs(props or {}) do p[k] = v end
		return mk("TextLabel", p, par)
	end
	local function button(par, text, props, accent)
		local p = { Text = text, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = true, BackgroundColor3 = accent and C(112, 60, 225) or C(38, 28, 66), BorderSizePixel = 0 }
		for k, v in pairs(props or {}) do p[k] = v end
		local b = mk("TextButton", p, par)
		corner(b, 10)
		return b
	end
	local vp = gui.AbsoluteSize
	if vp.X < 50 then vp = Vector2.new(800, 400) end
	-- ---------------- floating black hole button ----------------
	local BS = 58
	local fab = mk("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromOffset(BS, BS + 14), Position = UDim2.new(0, 8, 0.5, 34) }, gui)
	local core = mk("Frame", { BackgroundColor3 = C(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromOffset(BS, BS), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0) }, fab)
	corner(core, BS)
	local function ringOn(par, size, thick, cols, tr)
		local r = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(size, size) }, par)
		corner(r, 200)
		local s = mk("UIStroke", { Thickness = thick, Color = Color3.new(1, 1, 1), Transparency = tr or 0 }, r)
		local g = mk("UIGradient", { Color = cols }, s)
		return r, g
	end
	local _, rg1 = ringOn(core, 1.0, 3, seq(C(255, 190, 110), C(190, 90, 255), C(70, 200, 255), C(255, 190, 110)))
	local _, rg2 = ringOn(core, 0.74, 2, seq(C(255, 255, 255), C(120, 60, 220), C(255, 255, 255)), 0.3)
	local hole = mk("Frame", { BackgroundColor3 = C(0, 0, 0), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.5) }, core)
	corner(hole, 100)
	local note = label(core, "~", 22, C(255, 255, 255), Enum.Font.GothamBlack, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
	mk("UIStroke", { Thickness = 1.5, Color = C(150, 80, 255) }, note)
	local disc = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.45, 0.3), ZIndex = 4 }, core)
	corner(disc, 40)
	local ds = mk("UIStroke", { Thickness = 3, Color = Color3.new(1, 1, 1), Transparency = 0.15 }, disc)
	local dg = mk("UIGradient", { Color = seq(C(255, 230, 160), C(255, 110, 70), C(190, 80, 255), C(255, 230, 160)) }, ds)
	local tag = label(fab, "MUSIC", 11, C(255, 255, 255), Enum.Font.GothamBlack, { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, BS + 1), TextXAlignment = Enum.TextXAlignment.Center })
	mk("UIStroke", { Thickness = 1.5, Color = C(90, 30, 190) }, tag)

	-- ---------------- window ----------------
	local W = math.min(360, vp.X - 16)
	local H = math.min(450, vp.Y - 16)
	local win = mk("Frame", { BackgroundColor3 = C(11, 8, 22), Size = UDim2.fromOffset(W, H), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Visible = false, BorderSizePixel = 0, ClipsDescendants = true }, gui)
	corner(win, 16)
	mk("UIStroke", { Thickness = 2, Color = C(150, 100, 255), Transparency = 0.25 }, win)
	mk("UIGradient", { Rotation = 90, Color = seq(C(36, 18, 78), C(9, 6, 18)) }, win)
	local head = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36) }, win)
	label(head, "MUSIC", 16, C(255, 255, 255), Enum.Font.GothamBlack, { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -60, 1, 0) })
	local closeB = button(head, "X", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(28, 26), TextSize = 12 })
	closeB.MouseButton1Click:Connect(function() win.Visible = false end)
	-- search row
	local sBox = mk("TextBox", { PlaceholderText = "Search any song or artist...", Text = "", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Color3.new(1, 1, 1), PlaceholderColor3 = C(150, 140, 190), BackgroundColor3 = C(28, 20, 52), BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(10, 38), Size = UDim2.new(1, -90, 0, 32) }, win)
	corner(sBox, 16)
	mk("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 8) }, sBox)
	local sGo = button(win, "Search", { Position = UDim2.new(1, -74, 0, 38), Size = UDim2.fromOffset(64, 32), TextSize = 12 }, true)
	corner(sGo, 16)
	-- category chips
	local chipBar = mk("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 0, 34), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X }, win)
	mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center }, chipBar)
	mk("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, chipBar)
	-- results
	local PLAYER_H = 92
	local resBox = mk("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 110), Size = UDim2.new(1, 0, 1, -(110 + PLAYER_H)), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = C(150, 100, 255) }, win)
	mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, resBox)
	mk("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }, resBox)
	-- now playing bar
	local bar = mk("Frame", { BackgroundColor3 = C(18, 12, 36), BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -PLAYER_H), Size = UDim2.new(1, 0, 0, PLAYER_H) }, win)
	mk("UIStroke", { Thickness = 1, Color = C(150, 100, 255), Transparency = 0.6 }, bar)
	local nArt = mk("ImageLabel", { BackgroundColor3 = C(34, 24, 62), BorderSizePixel = 0, Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(40, 40), ScaleType = Enum.ScaleType.Crop }, bar)
	corner(nArt, 8)
	local nTitle = label(bar, "Nothing playing", 13, Color3.new(1, 1, 1), Enum.Font.GothamBold, { Position = UDim2.fromOffset(58, 8), Size = UDim2.new(1, -140, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
	local nSub = label(bar, "Pick a song above", 10, C(170, 160, 210), Enum.Font.Gotham, { Position = UDim2.fromOffset(58, 28), Size = UDim2.new(1, -140, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd })
	-- equalizer visualizer
	local vbars = {}
	for i = 1, 12 do
		local vb = mk("Frame", { BackgroundColor3 = Color3.fromHSV(0.72 + i * 0.012, 0.6, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(1, -78 + (i - 1) * 6, 0, 46), Size = UDim2.fromOffset(4, 4) }, bar)
		corner(vb, 2)
		vbars[i] = { f = vb, ph = math.random() * 6.28, sp = 5 + math.random() * 6 }
	end
	-- seek bar
	local seekBg = mk("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C(40, 30, 72), BorderSizePixel = 0, Position = UDim2.fromOffset(10, 54), Size = UDim2.new(1, -20, 0, 7) }, bar)
	corner(seekBg, 4)
	local seekFill = mk("Frame", { BackgroundColor3 = C(170, 110, 255), BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) }, seekBg)
	corner(seekFill, 4)
	local drag = false
	local function seekTo(x)
		local M = NovaUI.Music
		if M then M.seek(math.clamp((x - seekBg.AbsolutePosition.X) / math.max(1, seekBg.AbsoluteSize.X), 0, 1)) end
	end
	seekBg.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = true seekTo(i.Position.X) end
	end)
	UIS.InputChanged:Connect(function(i)
		if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then seekTo(i.Position.X) end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = false end
	end)
	local bPrev = button(bar, "<<", { Position = UDim2.fromOffset(10, 64), Size = UDim2.fromOffset(40, 24), TextSize = 12 })
	local bPlay = button(bar, "Play", { Position = UDim2.fromOffset(56, 64), Size = UDim2.fromOffset(64, 24), TextSize = 12 }, true)
	local bNext = button(bar, ">>", { Position = UDim2.fromOffset(126, 64), Size = UDim2.fromOffset(40, 24), TextSize = 12 })
	local bShuf = button(bar, "Shuf", { Position = UDim2.fromOffset(172, 64), Size = UDim2.fromOffset(44, 24), TextSize = 11 })
	local bVm = button(bar, "-", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -54, 0, 64), Size = UDim2.fromOffset(30, 24), TextSize = 13 })
	local bVp = button(bar, "+", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 64), Size = UDim2.fromOffset(30, 24), TextSize = 13 })
	local volTxt = label(bar, "60%", 10, C(170, 160, 210), Enum.Font.GothamBold, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -44, 0, 64), Size = UDim2.fromOffset(10, 24), TextXAlignment = Enum.TextXAlignment.Center })
	volTxt.Visible = false
	local function M() return NovaUI.Music end
	bPrev.MouseButton1Click:Connect(function() M().step(-1) end)
	bNext.MouseButton1Click:Connect(function() M().step(1) end)
	bPlay.MouseButton1Click:Connect(function() if M().idx == 0 then notify("Music", "Pick a song first") else M().toggle() end end)
	bShuf.MouseButton1Click:Connect(function() M().toggleShuffle() end)
	bVm.MouseButton1Click:Connect(function() M().setVol(M().vol - 0.1) end)
	bVp.MouseButton1Click:Connect(function() M().setVol(M().vol + 0.1) end)

	-- ---------------- results list ----------------
	local curList = {}
	local token = 0
	local function clearRes()
		for _, c in ipairs(resBox:GetChildren()) do
			if c:IsA("GuiObject") then c:Destroy() end
		end
	end
	local function message(text)
		clearRes()
		label(resBox, text, 12, C(170, 160, 210), Enum.Font.Gotham, { Size = UDim2.new(1, 0, 0, 60), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center })
	end
	local function render(list)
		clearRes()
		curList = list
		local Mu = M()
		for i, t in ipairs(list) do
			local row = mk("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C(26, 19, 50), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = i }, resBox)
			corner(row, 12)
			local cur = Mu.queue[Mu.idx]
			if cur and cur.src == t.src and cur.id == t.id then mk("UIStroke", { Color = C(170, 110, 255), Thickness = 1.5 }, row) end
			local art = mk("ImageLabel", { BackgroundColor3 = C(40, 30, 72), BorderSizePixel = 0, Position = UDim2.fromOffset(7, 6), Size = UDim2.fromOffset(40, 40), ScaleType = Enum.ScaleType.Crop }, row)
			corner(art, 8)
			local num = label(art, tostring(i), 12, C(160, 150, 200), Enum.Font.GothamBold, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
			if t.cover then Mu.cover(t, function(a) if art.Parent then art.Image = a num.Visible = false end end) end
			label(row, t.title, 13, Color3.new(1, 1, 1), Enum.Font.GothamBold, { Position = UDim2.fromOffset(56, 7), Size = UDim2.new(1, -112, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
			label(row, t.artist .. "  -  " .. (t.note or ""), 10, C(160, 150, 200), Enum.Font.Gotham, { Position = UDim2.fromOffset(56, 27), Size = UDim2.new(1, -112, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd })
			local fav = button(row, Mu.isFav(t) and "<3" or "+", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(34, 28), TextSize = 12 })
			corner(fav, 14)
			fav.BackgroundColor3 = Mu.isFav(t) and C(255, 90, 140) or C(38, 28, 66)
			fav.MouseButton1Click:Connect(function()
				local on = Mu.toggleFav(t)
				fav.Text = on and "<3" or "+"
				fav.BackgroundColor3 = on and C(255, 90, 140) or C(38, 28, 66)
			end)
			row.MouseButton1Click:Connect(function()
				Mu.play(list, i)
				render(list)
			end)
		end
	end
	local function runQuery(q, isChart, favs, fy)
		token = token + 1
		local my = token
		message("Searching...")
		task.spawn(function()
			local Mu = M()
			local list, errs = {}, {}
			if favs then list = Mu.favs
			elseif fy then list = Mu.forYou()
			elseif isChart then list = Mu.chart()
			else list, errs = Mu.search(q) end
			if my ~= token then return end
			if #list == 0 then
				message((#errs > 0 and table.concat(errs, ", ") or "No results found") .. "\nTry another word, or check your internet.")
			else
				render(list)
			end
		end)
	end
	local cats = {
		{ "For You", nil, false, false, true }, { "Trending", nil, true }, { "Hindi", "hindi songs" }, { "Bollywood", "bollywood hits" }, { "English", "english pop hits" }, { "Rap", "rap hits" },
		{ "Hip Hop", "hip hop" }, { "Desi Hip Hop", "desi hip hop" }, { "Punjabi", "punjabi songs" }, { "Romantic", "romantic hindi songs" }, { "Sad", "sad hindi songs" },
		{ "Lofi", "lofi chill" }, { "Pop", "pop hits" }, { "Rock", "rock classics" }, { "EDM", "edm party" }, { "Gym", "workout motivation" }, { "Retro", "old hindi songs" },
		{ "Arijit Singh", "arijit singh" }, { "Badshah", "badshah" }, { "Diljit", "diljit dosanjh" }, { "Phonk", "phonk" }, { "Liked", nil, false, true },
	}
	local chipBtns = {}
	local function pick(i)
		for j, b in ipairs(chipBtns) do b.BackgroundColor3 = (j == i) and C(112, 60, 225) or C(38, 28, 66) end
		local c = cats[i]
		runQuery(c[2], c[3], c[4], c[5])
	end
	for i, c in ipairs(cats) do
		local b = button(chipBar, c[1], { Size = UDim2.new(0, 0, 0, 26), AutomaticSize = Enum.AutomaticSize.X, TextSize = 11, LayoutOrder = i })
		corner(b, 13)
		mk("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, b)
		chipBtns[i] = b
		b.MouseButton1Click:Connect(function() pick(i) end)
	end
	local function doSearch()
		local q = sBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
		if q == "" then return end
		for _, b in ipairs(chipBtns) do b.BackgroundColor3 = C(38, 28, 66) end
		runQuery(q)
	end
	sGo.MouseButton1Click:Connect(doSearch)
	sBox.FocusLost:Connect(function(enter) if enter then doSearch() end end)

	-- ---------------- open / drag / live updates ----------------
	local firstOpen = true
	local function toggle()
		win.Visible = not win.Visible
		if win.Visible and firstOpen then
			firstOpen = false
			pick(1)
		end
	end
	local dragging, moved, startIn, startPos = false, false, nil, nil
	fab.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, moved, startIn, startPos = true, false, i.Position, fab.Position
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - startIn
			if d.Magnitude > 6 then moved = true end
			if moved then fab.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			if not moved then toggle() end
		end
	end)
	-- drag the window by its header
	local wd, wStart, wPos = false, nil, nil
	head.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then wd, wStart, wPos = true, i.Position, win.Position end
	end)
	UIS.InputChanged:Connect(function(i)
		if wd and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - wStart
			win.Position = UDim2.new(wPos.X.Scale, wPos.X.Offset + d.X, wPos.Y.Scale, wPos.Y.Offset + d.Y)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then wd = false end
	end)
	local lastKey
	local function refresh()
		local Mu = M()
		if not Mu then return end
		local t = Mu.queue[Mu.idx]
		local st = Mu.state
		nTitle.Text = t and t.title or "Nothing playing"
		nSub.Text = t and (t.artist .. "  -  " .. (st == "loading" and "loading..." or st == "error" and Mu.note or (t.note or ""))) or "Pick a song above"
		bPlay.Text = (st == "playing") and "Pause" or "Play"
		bShuf.BackgroundColor3 = Mu.shuffle and C(112, 60, 225) or C(38, 28, 66)
		local key = t and (t.src .. t.id)
		if key ~= lastKey then
			lastKey = key
			nArt.Image = ""
			if t then Mu.cover(t, function(a) if lastKey == key then nArt.Image = a end end) end
			if win.Visible and #curList > 0 then render(curList) end
		end
	end
	task.spawn(function()
		while not NovaUI.Music do task.wait(0.5) end
		table.insert(NovaUI.Music.listeners, refresh)
		refresh()
	end)
	local spin = 0
	RS.Heartbeat:Connect(function(dt)
		local Mu = NovaUI.Music
		local playing = Mu and Mu.state == "playing"
		spin = spin + dt * (playing and 260 or 70)
		rg1.Rotation = spin % 360
		rg2.Rotation = (-spin * 1.4) % 360
		dg.Rotation = (spin * 0.6) % 360
		local pulse = 1 + math.sin(os.clock() * (playing and 6 or 2)) * (playing and 0.06 or 0.02)
		core.Size = UDim2.fromOffset(BS * pulse, BS * pulse)
		if Mu and win.Visible then
			local lv = (Mu.state == "playing") and math.clamp(Mu.sound.PlaybackLoudness / 450, 0.05, 1) or 0
			for _, v in ipairs(vbars) do
				local h = 3 + (lv * 30) * (0.45 + 0.55 * math.abs(math.sin(os.clock() * v.sp + v.ph)))
				v.f.Size = UDim2.fromOffset(4, h)
			end
			local s = Mu.sound
			seekFill.Size = UDim2.fromScale((s.TimeLength > 0) and math.clamp(s.TimePosition / s.TimeLength, 0, 1) or 0, 1)
		end
	end)
end)
------------------------------------------------------------------------
-- SETTINGS
------------------------------------------------------------------------
local settingsTab = Window:CreateSettingsTab({ Discord = "https://discord.gg/yourinvite" })
local hubPref = settingsTab:Section({ Title = "Hub", Icon = "sparkles", Side = "Left" })
hubPref:Toggle({ Title = "Touch vibration", Description = "Haptic tick when you tap things (phones)", Icon = "bolt", Default = true, Flag = "Haptics", Callback = function(v)
	NovaUI.Haptics = v
end })

hubPref:Toggle({ Title = "UI sounds", Description = "Clicks, chat ping and intro sound", Icon = "volume", Default = true, Flag = "UISounds", Callback = function(v)
	NovaUI.Sounds = v
end })

hubPref:Toggle({ Title = "Open/close animation", Description = "Hub is sucked into the orb and bursts back out", Icon = "sparkles", Default = true, Flag = "UIAnim", Callback = function(v)
	NovaUI.Animations = v
end })
hubPref:Toggle({ Title = "Background blur", Description = "Blur the game behind the open hub", Icon = "eye", Default = true, Flag = "BGBlur", Callback = function(v)
	NovaUI.Blur = v
	if Window._blurTo then Window._blurTo(Window.Visible) end
end })
hubPref:Toggle({ Title = "Spawn banner", Description = "Big YADSAN HUB billboard at the spawn (only you see it)", Icon = "sparkles", Default = true, Flag = "SpawnBanner", Callback = function(v)
	NovaUI.SpawnBannerOn = v
	if NovaUI.SpawnBanner then NovaUI.SpawnBanner.Set(v) end
end })
hubPref:Button({ Title = "Put banner in front of me", Callback = function()
	if NovaUI.SpawnBanner then NovaUI.SpawnBanner.PlaceHere() end
end })
hubPref:Toggle({ Title = "Corner blackholes", Description = "Animated blackholes in the corners and sides", Icon = "sparkles", Default = true, Flag = "Ambient", Callback = function(v)
	if Window._ambient then Window._ambient.Visible = v end
end })

NovaUI.HubReady = true
task.spawn(function()
	while NovaUI.HoldOpen do task.wait(0.2) end
	task.wait(1.4)
Window:Notify({ Title = "YADSAN HUB loaded", Content = "RightShift or tap the blackhole to hide/show.", Duration = 5 })
end)

-- NAHUALHUB v2.3 | Vuelo + ESP + Hitbox + Aim + Jugadores (TP) | Halloween | UI personalizable | Solara
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

-- ========== ESTADO ==========
local vivo = true
local introTerminada = false
local menuAbierto = false
local flying = false
local espEnabled = false
local hitboxEnabled = false
local ignorarEquipo = false
local speed = 50
local hitboxSize = 10
local selected = nil
local spectating = false
local bordeAnimado = true
local escalaUI = 1
local sonidoOn = true
local sonidoVol = 0.5
local reproducir = function(_) end   -- se define en SONIDOS

local espCache = {}
local hitboxOriginal = {}
local conns = {}
local binds = {}          -- KeyCode -> objeto de toggle
local escuchando = nil    -- estado de "esperando tecla"
local teclaOcultar = Enum.KeyCode.RightShift

local teclasBloqueadas = {
    [Enum.KeyCode.W] = true, [Enum.KeyCode.A] = true, [Enum.KeyCode.S] = true, [Enum.KeyCode.D] = true,
    [Enum.KeyCode.Space] = true, [Enum.KeyCode.LeftControl] = true, [Enum.KeyCode.Unknown] = true,
}

-- ========== TEMAS ==========
local Temas = {
    {n = "Halloween", accent = Color3.fromRGB(255, 125, 25), accent2 = Color3.fromRGB(150, 70, 255),
        fondo = Color3.fromRGB(12, 8, 20), fondo2 = Color3.fromRGB(46, 18, 36), panel = Color3.fromRGB(28, 20, 38),
        panel2 = Color3.fromRGB(44, 30, 56), off = Color3.fromRGB(78, 60, 92)},
    {n = "Medianoche", accent = Color3.fromRGB(138, 92, 255), accent2 = Color3.fromRGB(0, 200, 255),
        fondo = Color3.fromRGB(14, 14, 24), fondo2 = Color3.fromRGB(26, 16, 44), panel = Color3.fromRGB(27, 27, 42),
        panel2 = Color3.fromRGB(40, 40, 62), off = Color3.fromRGB(65, 65, 90)},
    {n = "Calabaza", accent = Color3.fromRGB(255, 140, 40), accent2 = Color3.fromRGB(170, 80, 255),
        fondo = Color3.fromRGB(16, 11, 24), fondo2 = Color3.fromRGB(38, 16, 38), panel = Color3.fromRGB(30, 22, 40),
        panel2 = Color3.fromRGB(46, 33, 58), off = Color3.fromRGB(72, 58, 88)},
    {n = "Neón", accent = Color3.fromRGB(50, 255, 140), accent2 = Color3.fromRGB(0, 200, 255),
        fondo = Color3.fromRGB(8, 15, 15), fondo2 = Color3.fromRGB(8, 32, 30), panel = Color3.fromRGB(16, 30, 30),
        panel2 = Color3.fromRGB(24, 46, 46), off = Color3.fromRGB(40, 70, 66)},
    {n = "Sangre", accent = Color3.fromRGB(255, 70, 90), accent2 = Color3.fromRGB(255, 130, 180),
        fondo = Color3.fromRGB(18, 9, 11), fondo2 = Color3.fromRGB(40, 12, 20), panel = Color3.fromRGB(32, 20, 24),
        panel2 = Color3.fromRGB(50, 28, 34), off = Color3.fromRGB(82, 50, 58)},
    {n = "Océano", accent = Color3.fromRGB(60, 140, 255), accent2 = Color3.fromRGB(0, 230, 220),
        fondo = Color3.fromRGB(9, 13, 24), fondo2 = Color3.fromRGB(12, 26, 48), panel = Color3.fromRGB(20, 28, 44),
        panel2 = Color3.fromRGB(30, 42, 66), off = Color3.fromRGB(50, 70, 100)},
}

local T = {
    texto = Color3.fromRGB(235, 235, 245),
    sub = Color3.fromRGB(150, 150, 178),
    rojo = Color3.fromRGB(255, 85, 100),
    verde = Color3.fromRGB(60, 220, 120),
}
local function cargarTema(tm)
    for _, k in ipairs({"accent", "accent2", "fondo", "fondo2", "panel", "panel2", "off"}) do T[k] = tm[k] end
end
cargarTema(Temas[1])

-- Colores por función (fijos, para distinguir cada opción de un vistazo)
local C = {
    cielo = Color3.fromRGB(70, 190, 255),
    menta = Color3.fromRGB(90, 240, 190),
    rojo = Color3.fromRGB(255, 85, 100),
    naranja = Color3.fromRGB(255, 150, 50),
    amarillo = Color3.fromRGB(255, 215, 70),
    verde = Color3.fromRGB(90, 230, 120),
    morado = Color3.fromRGB(185, 100, 255),
    rosa = Color3.fromRGB(255, 110, 200),
    azul = Color3.fromRGB(100, 140, 255),
    gris = Color3.fromRGB(150, 170, 205),
}

-- Registro para que los colores cambien en vivo
local temaRegs, temaFns = {}, {}
local function tema(obj, prop, key)
    obj[prop] = T[key]
    temaRegs[#temaRegs + 1] = {obj, prop, key}
    return obj
end
local function onTema(fn)
    temaFns[#temaFns + 1] = fn
    fn()
end
local function aplicarTema()
    for _, r in ipairs(temaRegs) do
        pcall(function() r[1][r[2]] = T[r[3]] end)
    end
    for _, fn in ipairs(temaFns) do pcall(fn) end
end

-- ========== HELPERS ==========
local function new(clase, props, hijos)
    local o = Instance.new(clase)
    local tm
    for k, v in pairs(props or {}) do
        if k == "__t" then tm = v
        elseif k ~= "Parent" then o[k] = v end
    end
    if tm then
        for p, key in pairs(tm) do tema(o, p, key) end
    end
    for _, h in ipairs(hijos or {}) do h.Parent = o end
    if props and props.Parent then o.Parent = props.Parent end
    return o
end

local function corner(r) return new("UICorner", {CornerRadius = UDim.new(0, r)}) end

local function stroke(color, grosor, transp)
    local s = Instance.new("UIStroke")
    s.Thickness = grosor or 1
    s.Transparency = transp or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    if type(color) == "string" then tema(s, "Color", color) else s.Color = color end
    return s
end

local function grad(parent, k1, k2, rot, k3)
    local g = Instance.new("UIGradient")
    g.Rotation = rot or 0
    onTema(function()
        if k3 then
            g.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, T[k1]),
                ColorSequenceKeypoint.new(0.5, T[k2]),
                ColorSequenceKeypoint.new(1, T[k3]),
            })
        else
            g.Color = ColorSequence.new(T[k1], T[k2])
        end
    end)
    g.Parent = parent
    return g
end

local function tween(o, t, props)
    local tw = TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end
local function tweenEx(o, info, props)
    local tw = TweenService:Create(o, info, props)
    tw:Play()
    return tw
end

local function nombreTecla(k)
    local n = k.Name
    n = (string.gsub(n, "Left", "L"))
    n = (string.gsub(n, "Right", "R"))
    if #n > 5 then n = string.sub(n, 1, 5) end
    return n
end

-- Onda al hacer clic
local function ripple(visual, x)
    if not visual.Parent then return end
    x = x or (visual.AbsolutePosition.X + visual.AbsoluteSize.X / 2)
    local rel = x - visual.AbsolutePosition.X
    local d = math.max(visual.AbsoluteSize.X, 40) * 1.8
    local c = new("Frame", {
        Size = UDim2.new(0, 0, 0, 0), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, rel, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.8, BorderSizePixel = 0, Parent = visual,
    }, {new("UICorner", {CornerRadius = UDim.new(1, 0)})})
    tweenEx(c, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, d, 0, d), BackgroundTransparency = 1,
    })
    task.delay(0.6, function() c:Destroy() end)
end

-- Efectos de botón: brillo, escala, "hundir" y ripple
local function efecto(btn, visual, op)
    op = op or {}
    visual = visual or btn
    local sc = visual:FindFirstChildOfClass("UIScale") or new("UIScale", {Scale = 1, Parent = visual})
    local st, bt, base
    if not op.sinGlow then
        st = visual:FindFirstChildOfClass("UIStroke")
        if not st then
            st = stroke("accent2", 1.4, 1)
            st.Parent = visual
        end
        bt = st.Transparency
    end
    local hov = op.hover or 1.02
    if not op.sinRipple then visual.ClipsDescendants = true end

    btn.MouseEnter:Connect(function()
        tween(sc, 0.15, {Scale = hov})
        if st then
            base = st.Color
            tween(st, 0.15, {Transparency = math.min(bt, 0.25), Color = op.glow or T.accent2})
        end
    end)
    btn.MouseLeave:Connect(function()
        tween(sc, 0.15, {Scale = 1})
        if st then tween(st, 0.2, {Transparency = bt, Color = base or st.Color}) end
    end)
    if btn:IsA("GuiButton") then
        btn.MouseButton1Down:Connect(function(x)
            tween(sc, 0.08, {Scale = 0.96})
            if not op.sinSonido then reproducir("click") end
            if not op.sinRipple then ripple(visual, x) end
        end)
        btn.MouseButton1Up:Connect(function() tween(sc, 0.12, {Scale = hov}) end)
    end
end

-- Lluvia reutilizable
local function crearLluvia(parent, cantidad, cfg)
    cfg = cfg or {}
    local layer = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ClipsDescendants = true, Parent = parent})
    local drops = {}
    for i = 1, cantidad do
        local len = math.random(cfg.minLen or 10, cfg.maxLen or 24)
        local tr = (cfg.tmin or 0.6) + math.random() * ((cfg.tmax or 0.9) - (cfg.tmin or 0.6))
        local c = math.random()
        local f = new("Frame", {
            Size = UDim2.new(0, cfg.ancho or 1, 0, len), BorderSizePixel = 0,
            BackgroundColor3 = T.accent2:Lerp(T.accent, c), BackgroundTransparency = tr, Parent = layer,
        })
        drops[i] = {f = f, x = math.random(), y = math.random() * 500, v = math.random(cfg.vmin or 200, cfg.vmax or 400), len = len, c = c}
    end
    if cfg.tema then
        onTema(function()
            for _, d in ipairs(drops) do d.f.BackgroundColor3 = T.accent2:Lerp(T.accent, d.c) end
        end)
    end
    local conn = RunService.Heartbeat:Connect(function(dt)
        if cfg.activo and not cfg.activo() then return end
        local H = layer.AbsoluteSize.Y
        if H <= 0 then H = 400 end
        for _, d in ipairs(drops) do
            d.y = d.y + d.v * dt
            if d.y > H + d.len then
                d.y = -d.len
                d.x = math.random()
            end
            d.f.Position = UDim2.new(d.x, 0, 0, d.y)
        end
    end)
    conns[#conns + 1] = conn
    return layer, conn
end

-- Burbujas flotantes de fondo
local function crearBurbujas(parent, cantidad, cfg)
    cfg = cfg or {}
    local layer = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ClipsDescendants = true, Parent = parent})
    local bubs = {}
    for i = 1, cantidad do
        local sz = math.random(cfg.minS or 8, cfg.maxS or 28)
        local c = math.random()
        local col = T.accent2:Lerp(T.accent, c)
        local f = new("Frame", {
            Size = UDim2.new(0, sz, 0, sz), BackgroundColor3 = col, BackgroundTransparency = 0.86,
            BorderSizePixel = 0, Parent = layer,
        }, {new("UICorner", {CornerRadius = UDim.new(1, 0)})})
        local st = Instance.new("UIStroke")
        st.Thickness = 1
        st.Transparency = 0.5
        st.Color = col
        st.Parent = f
        new("Frame", {
            Size = UDim2.new(0, math.max(2, sz * 0.25), 0, math.max(2, sz * 0.25)), Position = UDim2.new(0.2, 0, 0.16, 0),
            BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = f,
        }, {new("UICorner", {CornerRadius = UDim.new(1, 0)})})
        bubs[i] = {f = f, st = st, x = math.random(), y = math.random() * 400, v = math.random(18, 48),
            amp = math.random(6, 18), fase = math.random() * 6.28, vel = math.random(8, 20) / 10, c = c, s = sz}
    end
    onTema(function()
        for _, b in ipairs(bubs) do
            local col = T.accent2:Lerp(T.accent, b.c)
            b.f.BackgroundColor3 = col
            b.st.Color = col
        end
    end)
    local conn = RunService.Heartbeat:Connect(function(dt)
        if not parent.Visible then return end
        local H = layer.AbsoluteSize.Y
        if H <= 0 then H = 380 end
        local t = tick()
        for _, b in ipairs(bubs) do
            b.y = b.y - b.v * dt
            if b.y < -b.s then
                b.y = H + b.s
                b.x = math.random()
            end
            b.f.Position = UDim2.new(b.x, math.sin(t * b.vel + b.fase) * b.amp, 0, b.y)
        end
    end)
    conns[#conns + 1] = conn
    return layer, conn
end

-- Burbujitas que salen al activar una opción
local function burbujasPop(parent, x, y, color, n)
    for _ = 1, n do
        local sz = math.random(5, 10)
        local b = new("Frame", {
            Size = UDim2.new(0, sz, 0, sz), Position = UDim2.new(0, x, 0, y), AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = color, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 6, Parent = parent,
        }, {new("UICorner", {CornerRadius = UDim.new(1, 0)})})
        tweenEx(b, TweenInfo.new(0.5 + math.random() * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, x + math.random(-26, 26), 0, y - math.random(10, 26)),
            BackgroundTransparency = 1, Size = UDim2.new(0, sz + 5, 0, sz + 5),
        })
        task.delay(1, function() b:Destroy() end)
    end
end

-- ========== GUI BASE ==========
local guiParent = (gethui and gethui()) or CoreGui
for _, n in ipairs({"NahualHub", "NahualIntro", "NahualAimFOV", "NahualESP"}) do
    if guiParent:FindFirstChild(n) then guiParent[n]:Destroy() end
end
if CoreGui:FindFirstChild("NahualFlyGUI") then CoreGui.NahualFlyGUI:Destroy() end

local ScreenGui = new("ScreenGui", {Name = "NahualHub", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = guiParent})

-- Notificaciones
local function notificar(texto)
    local t = new("TextLabel", {
        Size = UDim2.new(0, 300, 0, 38), Position = UDim2.new(0.5, -150, 1, 10),
        Text = texto, Font = Enum.Font.GothamMedium, TextSize = 12, ZIndex = 20,
        __t = {BackgroundColor3 = "panel", TextColor3 = "texto"}, Parent = ScreenGui,
    }, {corner(10), stroke("accent", 1.3, 0.2)})
    tweenEx(t, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, -150, 1, -66)})
    task.delay(2.3, function()
        if t.Parent then
            tween(t, 0.3, {Position = UDim2.new(0.5, -150, 1, 10)})
            task.wait(0.35)
            t:Destroy()
        end
    end)
end

-- ========== SONIDOS ==========
local candidatosSonido = {
    "rbxasset://sounds/electronicpingshort.wav",
    "rbxasset://sounds/clickfast.wav",
    "rbxassetid://421058925",
    "rbxassetid://6042053626",
}
local sonidosObj = {}
for i, id in ipairs(candidatosSonido) do
    local snd = Instance.new("Sound")
    snd.Name = "NahualSnd" .. i
    snd.SoundId = id
    snd.Volume = sonidoVol
    snd.Parent = ScreenGui
    sonidosObj[i] = snd
end
reproducir = function(tipo)
    if not sonidoOn then return end
    pcall(function()
        local elegido
        for _, snd in ipairs(sonidosObj) do
            if snd.IsLoaded then elegido = snd break end
        end
        elegido = elegido or sonidosObj[1]
        elegido.Volume = sonidoVol
        elegido.PlaybackSpeed = (tipo == "on" and 1.3) or (tipo == "off" and 0.8) or 1
        elegido.TimePosition = 0
        elegido:Play()
    end)
end

-- ========== VENTANA PRINCIPAL ==========
local ANCHO, ALTO, HH, SIDE = 660, 420, 46, 180

local Main = new("Frame", {
    Size = UDim2.new(0, ANCHO, 0, ALTO), AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1),
    ClipsDescendants = true, Visible = false, Parent = ScreenGui,
}, {corner(18)})
grad(Main, "fondo", "fondo2", 90)
local MainScale = new("UIScale", {Scale = 1, Parent = Main})

-- Imagen de fondo opcional (se configura en Apariencia)
local FondoImg = new("ImageLabel", {
    Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Image = "", ImageTransparency = 0.6,
    ScaleType = Enum.ScaleType.Crop, Parent = Main,
}, {corner(18)})

-- Borde con degradado giratorio
local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 2
MainStroke.Transparency = 0.1
MainStroke.Color = Color3.new(1, 1, 1)
MainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
MainStroke.Parent = Main
local MainGrad = grad(MainStroke, "accent", "accent2", 0, "accent")
conns[#conns + 1] = RunService.Heartbeat:Connect(function(dt)
    if bordeAnimado and Main.Visible then MainGrad.Rotation = (MainGrad.Rotation + 70 * dt) % 360 end
end)

-- Burbujas flotantes de fondo (detrás de todo el contenido)
local MenuBubbles = crearBurbujas(Main, 22, {})
MenuBubbles.Position = UDim2.new(0, 0, 0, HH)
MenuBubbles.Size = UDim2.new(1, 0, 1, -HH)

-- Decoración de Halloween
local HLayer = new("Frame", {
    Size = UDim2.new(1, 0, 1, -HH), Position = UDim2.new(0, 0, 0, HH), BackgroundTransparency = 1,
    ClipsDescendants = true, Parent = Main,
})
local lunaCol = Color3.fromRGB(255, 226, 150)
local Luna = new("Frame", {
    Size = UDim2.new(0, 120, 0, 120), Position = UDim2.new(1, -150, 0, -26), BackgroundColor3 = lunaCol,
    BackgroundTransparency = 0.88, BorderSizePixel = 0, Parent = HLayer,
}, {new("UICorner", {CornerRadius = UDim.new(1, 0)}), stroke(lunaCol, 2, 0.8)})
for _, cr in ipairs({{0.25, 0.3, 22}, {0.58, 0.22, 14}, {0.5, 0.6, 26}, {0.2, 0.65, 12}}) do
    new("Frame", {
        Size = UDim2.new(0, cr[3], 0, cr[3]), Position = UDim2.new(cr[1], 0, cr[2], 0), BackgroundColor3 = lunaCol,
        BackgroundTransparency = 0.93, BorderSizePixel = 0, Parent = Luna,
    }, {new("UICorner", {CornerRadius = UDim.new(1, 0)})})
end

local deco = {}
local function agregarDeco(emoji, tipo, tam, tr, xs, y0)
    local l = new("TextLabel", {
        Size = UDim2.new(0, tam + 10, 0, tam + 10), BackgroundTransparency = 1, Text = emoji,
        TextSize = tam, TextTransparency = tr, Parent = HLayer,
    })
    deco[#deco + 1] = {l = l, tipo = tipo, x = xs, by = y0, fase = math.random() * 6.28, v = math.random(14, 30)}
end
agregarDeco("🦇", "murcielago", 22, 0.4, 0.10, 60)
agregarDeco("🦇", "murcielago", 16, 0.5, 0.60, 150)
agregarDeco("🦇", "murcielago", 18, 0.45, 0.90, 250)
agregarDeco("👻", "fantasma", 26, 0.5, 0.35, 300)
agregarDeco("👻", "fantasma", 20, 0.55, 0.75, 220)
agregarDeco("🎃", "calabaza", 28, 0.4, 0.28, 330)
agregarDeco("🎃", "calabaza", 22, 0.5, 0.68, 336)
agregarDeco("🎃", "calabaza", 30, 0.4, 0.93, 328)
do
    local tela = new("TextLabel", {
        Size = UDim2.new(0, 56, 0, 56), Position = UDim2.new(1, -56, 1, -56), BackgroundTransparency = 1,
        Text = "🕸", TextSize = 46, TextTransparency = 0.45, Parent = HLayer,
    })
end

conns[#conns + 1] = RunService.Heartbeat:Connect(function(dt)
    if not Main.Visible or not HLayer.Visible then return end
    local t = tick()
    for _, d in ipairs(deco) do
        if d.tipo == "murcielago" then
            d.x = d.x + (d.v / ANCHO) * dt * 1.4
            if d.x > 1.05 then d.x = -0.1 end
            d.l.Position = UDim2.new(d.x, 0, 0, d.by + math.sin(t * 2.2 + d.fase) * 16)
        elseif d.tipo == "fantasma" then
            d.by = d.by - d.v * 0.5 * dt
            if d.by < -30 then d.by = 380 end
            d.l.Position = UDim2.new(d.x, math.sin(t * 1.3 + d.fase) * 14, 0, d.by)
        elseif d.tipo == "calabaza" then
            d.l.Position = UDim2.new(d.x, 0, 0, d.by + math.sin(t * 1.6 + d.fase) * 4)
            d.l.Rotation = math.sin(t * 1.2 + d.fase) * 8
        end
    end
end)

-- ---------- Encabezado ----------
local Header = new("Frame", {Size = UDim2.new(1, 0, 0, HH), BackgroundTransparency = 1, Parent = Main})
new("Frame", {
    Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BorderSizePixel = 0,
    BackgroundTransparency = 0.75, __t = {BackgroundColor3 = "accent"}, Parent = Header,
})

local Logo = new("Frame", {Size = UDim2.new(0, 32, 0, 32), Position = UDim2.new(0, 12, 0.5, -16), BackgroundColor3 = Color3.new(1, 1, 1), Parent = Header}, {corner(9)})
grad(Logo, "accent", "accent2", 45)
new("TextLabel", {
    Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "N", TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBlack, TextSize = 18, Parent = Logo,
})
new("TextLabel", {
    Size = UDim2.new(0, 100, 0, 20), Position = UDim2.new(0, 52, 0, 6), BackgroundTransparency = 1,
    Text = "NahualHub", Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left,
    __t = {TextColor3 = "texto"}, Parent = Header,
})
local SubLbl = new("TextLabel", {
    Size = UDim2.new(0, 120, 0, 14), Position = UDim2.new(0, 52, 0, 26), BackgroundTransparency = 1,
    Text = "Ocultar: RightShift", Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
    __t = {TextColor3 = "sub"}, Parent = Header,
})
local Badge = new("Frame", {Size = UDim2.new(0, 42, 0, 20), Position = UDim2.new(0, 150, 0.5, -10), __t = {BackgroundColor3 = "accent"}, Parent = Header}, {corner(6)})
new("TextLabel", {
    Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "v2.3", TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold, TextSize = 11, Parent = Badge,
})

-- Píldora "online"
local Pill = new("Frame", {
    Size = UDim2.new(0, 112, 0, 26), Position = UDim2.new(0.5, -56, 0.5, -13), BackgroundTransparency = 0.1,
    __t = {BackgroundColor3 = "panel"}, Parent = Header,
}, {corner(13), stroke("off", 1, 0.3)})
new("Frame", {Size = UDim2.new(0, 8, 0, 8), Position = UDim2.new(0, 12, 0.5, -4), BackgroundColor3 = T.verde, Parent = Pill}, {corner(4)})
local OnlineLbl = new("TextLabel", {
    Size = UDim2.new(1, -30, 1, 0), Position = UDim2.new(0, 28, 0, 0), BackgroundTransparency = 1, Text = "1 online",
    Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
    __t = {TextColor3 = "texto"}, Parent = Pill,
})
local function actualizarOnline()
    OnlineLbl.Text = #Players:GetPlayers() .. " online"
end
actualizarOnline()
conns[#conns + 1] = Players.PlayerAdded:Connect(actualizarOnline)
conns[#conns + 1] = Players.PlayerRemoving:Connect(function() task.defer(actualizarOnline) end)

-- Botones de la derecha
local aplicarPreset
local temaIdx = 1
local TemaBtn = new("TextButton", {
    Size = UDim2.new(0, 74, 0, 26), Position = UDim2.new(1, -152, 0.5, -13), Text = "Tema",
    Font = Enum.Font.GothamMedium, TextSize = 12, AutoButtonColor = false,
    __t = {BackgroundColor3 = "panel2", TextColor3 = "texto"}, Parent = Header,
}, {corner(8), stroke("off", 1, 0.3)})
efecto(TemaBtn, TemaBtn, {hover = 1.06, sinRipple = true})
TemaBtn.MouseButton1Click:Connect(function()
    temaIdx = temaIdx % #Temas + 1
    aplicarPreset(temaIdx)
end)

local MinBtn = new("TextButton", {
    Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(1, -68, 0.5, -13), Text = "-",
    Font = Enum.Font.GothamBold, TextSize = 16, AutoButtonColor = false,
    __t = {BackgroundColor3 = "panel2", TextColor3 = "texto"}, Parent = Header,
}, {corner(8), stroke("off", 1, 0.3)})
local CloseBtn = new("TextButton", {
    Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(1, -36, 0.5, -13), BackgroundColor3 = T.rojo,
    Text = "X", TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 12,
    AutoButtonColor = false, Parent = Header,
}, {corner(8)})
efecto(MinBtn, MinBtn, {hover = 1.1, sinRipple = true})
efecto(CloseBtn, CloseBtn, {hover = 1.1, sinRipple = true})

-- Arañita colgando del encabezado
local hilo = new("Frame", {
    Size = UDim2.new(0, 1, 0, 22), Position = UDim2.new(0, 440, 0, 0), BackgroundColor3 = Color3.fromRGB(210, 210, 225),
    BackgroundTransparency = 0.45, BorderSizePixel = 0, Parent = Header,
})
local arana = new("TextLabel", {
    Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(0, 428, 0, 20), BackgroundTransparency = 1,
    Text = "🕷", TextSize = 17, Parent = Header,
})
conns[#conns + 1] = RunService.Heartbeat:Connect(function()
    if Main.Visible and hilo.Visible then
        local h = 24 + (math.sin(tick() * 1.3) + 1) * 7
        hilo.Size = UDim2.new(0, 1, 0, h)
        arana.Position = UDim2.new(0, 428, 0, h - 3)
    end
end)

-- Arrastrar ventana (PC y móvil)
do
    local dragging, dragStart, startPos
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
        end
    end)
    conns[#conns + 1] = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    conns[#conns + 1] = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- Minimizar
local minimizado = false
MinBtn.MouseButton1Click:Connect(function()
    minimizado = not minimizado
    local d = (ALTO - HH) / 2 * escalaUI
    local p = Main.Position
    tween(Main, 0.25, {
        Size = UDim2.new(0, ANCHO, 0, minimizado and HH or ALTO),
        Position = UDim2.new(p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset + (minimizado and -d or d)),
    })
end)

-- ---------- Cuerpo ----------
local Body = new("Frame", {Size = UDim2.new(1, 0, 1, -HH), Position = UDim2.new(0, 0, 0, HH), BackgroundTransparency = 1, Parent = Main})

local Sidebar = new("Frame", {Size = UDim2.new(0, SIDE, 1, 0), BackgroundTransparency = 1, Parent = Body})
new("Frame", {
    Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BorderSizePixel = 0,
    BackgroundTransparency = 0.8, __t = {BackgroundColor3 = "accent"}, Parent = Sidebar,
})

local Search = new("TextBox", {
    Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0, 10, 0, 10), BackgroundTransparency = 0.15,
    Text = "", PlaceholderText = "Buscar...", ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    __t = {BackgroundColor3 = "panel", TextColor3 = "texto", PlaceholderColor3 = "sub"}, Parent = Sidebar,
}, {corner(8), new("UIPadding", {PaddingLeft = UDim.new(0, 10)})})
do
    local sStroke = stroke("off", 1, 0.35)
    sStroke.Parent = Search
    Search.Focused:Connect(function() tween(sStroke, 0.2, {Transparency = 0, Color = T.accent2}) end)
    Search.FocusLost:Connect(function() tween(sStroke, 0.2, {Transparency = 0.35, Color = T.off}) end)
end

local SideScroll = new("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, -48), Position = UDim2.new(0, 0, 0, 48), BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 2, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0),
    __t = {ScrollBarImageColor3 = "accent"}, Parent = Sidebar,
}, {
    new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}),
    new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10)}),
})

local Content = new("Frame", {Size = UDim2.new(1, -SIDE, 1, 0), Position = UDim2.new(0, SIDE, 0, 0), BackgroundTransparency = 1, Parent = Body})

-- ========== MOSTRAR / OCULTAR / TECLAS ==========
local function mostrarMenu()
    Main.Visible = true
    MainScale.Scale = 0.88 * escalaUI
    tweenEx(MainScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = escalaUI})
end

local function ocultarMenu()
    tween(MainScale, 0.2, {Scale = 0.9 * escalaUI})
    task.delay(0.2, function()
        if not menuAbierto then Main.Visible = false end
    end)
end

local function alternarMenu()
    if not introTerminada or not vivo then return end
    menuAbierto = not menuAbierto
    if menuAbierto then mostrarMenu() else ocultarMenu() end
end

-- No se usa gameProcessed: Roblox marca RightShift como procesado (bloqueo de cámara)
conns[#conns + 1] = UserInputService.InputBegan:Connect(function(input)
    if escuchando then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            local e = escuchando
            escuchando = nil
            local k = input.KeyCode
            if k == Enum.KeyCode.Escape then
                e.cancelar("Cambio cancelado")
            elseif (k == Enum.KeyCode.Backspace or k == Enum.KeyCode.Delete) and e.limpiar then
                e.limpiar()
            elseif teclasBloqueadas[k] then
                e.cancelar("Esa tecla se usa para volar, elige otra")
            else
                e.asignar(k)
            end
        end
        return
    end
    if UserInputService:GetFocusedTextBox() then return end
    local k = input.KeyCode
    if k == teclaOcultar then
        alternarMenu()
    elseif binds[k] and introTerminada then
        binds[k].toggle()
    end
end)

-- Botón flotante
local FloatBtn = new("TextButton", {
    Size = UDim2.new(0, 38, 0, 38), Position = UDim2.new(0, 12, 0.5, -19), Text = "N", TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBlack, TextSize = 16, AutoButtonColor = false, ZIndex = 10, Visible = false,
    __t = {BackgroundColor3 = "accent"}, Parent = ScreenGui,
}, {corner(19), stroke("accent2", 1.5, 0.1)})
efecto(FloatBtn, FloatBtn, {hover = 1.12, sinRipple = true})
FloatBtn.MouseButton1Click:Connect(alternarMenu)

-- ========== CATEGORÍAS, PESTAÑAS Y BÚSQUEDA ==========
local pages, tabObjs, paginaBase, ordenPaginas = {}, {}, {}, {}
local paginaActiva = nil
local cats, catOrden = {}, 0
local feats, headersBusq = {}, {}
local paginaActual = ""

local function getCat(nombre)
    if cats[nombre] then return cats[nombre] end
    catOrden = catOrden + 1
    local header = new("TextButton", {Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = catOrden * 10, Parent = SideScroll})
    new("TextLabel", {
        Size = UDim2.new(1, -24, 1, 0), Position = UDim2.new(0, 4, 0, 0), BackgroundTransparency = 1, Text = nombre,
        Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        __t = {TextColor3 = "sub"}, Parent = header,
    })
    local chev = new("TextLabel", {
        Size = UDim2.new(0, 16, 1, 0), Position = UDim2.new(1, -18, 0, 0), BackgroundTransparency = 1, Text = "v",
        Font = Enum.Font.GothamBold, TextSize = 11, __t = {TextColor3 = "sub"}, Parent = header,
    })
    local cont = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
        LayoutOrder = catOrden * 10 + 1, Parent = SideScroll,
    }, {new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder})})
    local abierto = true
    header.MouseButton1Click:Connect(function()
        abierto = not abierto
        cont.Visible = abierto
        chev.Text = abierto and "v" or ">"
    end)
    cats[nombre] = {header = header, cont = cont, paginas = {}}
    return cats[nombre]
end

local activos = {}             -- pagina -> cantidad de opciones activadas
local colorPagina = C.gris
local PALETA = {C.cielo, C.naranja, C.verde, C.morado, C.amarillo, C.rosa, C.menta, C.azul, C.rojo}
local paletaIdx = 0

-- Siguiente color de la paleta, distinto al color de la pestaña
local function colorSiguiente()
    for _ = 1, #PALETA do
        paletaIdx = paletaIdx % #PALETA + 1
        local c = PALETA[paletaIdx]
        if c ~= colorPagina then return c end
    end
    return C.gris
end

local function actualizarBadge(pagina)
    local o = tabObjs[pagina]
    if o and o.badge then
        local n = activos[pagina] or 0
        o.badge.Visible = n > 0
        o.badgeLbl.Text = tostring(n)
    end
end

local function estilizarTabs()
    for n, o in pairs(tabObjs) do
        local a = (n == paginaActiva)
        tween(o.btn, 0.2, {BackgroundColor3 = o.color, BackgroundTransparency = a and 0.8 or 1, TextColor3 = a and T.texto or o.color:Lerp(T.sub, 0.5)})
        tween(o.st, 0.2, {Color = o.color, Transparency = a and 0.3 or 1})
        tween(o.bar, 0.2, {BackgroundColor3 = o.color, BackgroundTransparency = a and 0 or 0.45})
    end
end

local function seleccionar(nombre)
    paginaActiva = nombre
    for n, p in pairs(pages) do
        if n == nombre then
            if not p.Visible then
                local base = paginaBase[n]
                p.Position = base + UDim2.new(0, 0, 0, 14)
                p.Visible = true
                tween(p, 0.25, {Position = base})
            end
        else
            p.Visible = false
        end
    end
    estilizarTabs()
end

local function crearTab(categoria, nombre, scroll, color, conBadge)
    color = color or C.gris
    colorPagina = color
    local c = getCat(categoria)
    table.insert(c.paginas, nombre)
    table.insert(ordenPaginas, nombre)
    paginaActual = nombre

    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = color, BackgroundTransparency = 1, Text = nombre,
        TextColor3 = T.sub, Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false, LayoutOrder = #ordenPaginas, Parent = c.cont,
    }, {corner(14), new("UIPadding", {PaddingLeft = UDim.new(0, 18)})})
    local st = stroke(color, 1.4, 1)
    st.Parent = btn

    local bar = new("Frame", {
        Size = UDim2.new(0, 3, 0, 18), Position = UDim2.new(0, -18, 0.5, -9), BackgroundColor3 = color,
        BackgroundTransparency = 0.45, BorderSizePixel = 0, Parent = btn,
    }, {new("UICorner", {CornerRadius = UDim.new(0, 2)})})

    -- Badge con la cantidad de opciones activas (como en la referencia)
    local badge, badgeLbl
    if conBadge then
        badge = new("Frame", {
            Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(1, -22, 0.5, -10), BackgroundColor3 = color,
            BorderSizePixel = 0, Visible = false, Parent = btn,
        }, {new("UICorner", {CornerRadius = UDim.new(1, 0)})})
        badgeLbl = new("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "0", TextColor3 = Color3.new(1, 1, 1),
            Font = Enum.Font.GothamBold, TextSize = 11, Parent = badge,
        })
    end

    tabObjs[nombre] = {btn = btn, st = st, bar = bar, color = color, badge = badge, badgeLbl = badgeLbl}
    efecto(btn, btn, {hover = 1.02, sinGlow = true})

    local page
    if scroll then
        page = new("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
            AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0), Visible = false,
            ScrollBarImageColor3 = color, Parent = Content,
        }, {
            new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}),
            new("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14), PaddingBottom = UDim.new(0, 12)}),
        })
    else
        page = new("Frame", {Size = UDim2.new(1, -26, 1, -24), Position = UDim2.new(0, 12, 0, 12), BackgroundTransparency = 1, Visible = false, Parent = Content})
    end
    pages[nombre] = page
    paginaBase[nombre] = page.Position
    btn.MouseButton1Click:Connect(function() seleccionar(nombre) end)
    return page
end

local function aplicarBusqueda()
    local q = string.lower(Search.Text)
    q = (string.gsub(q, "^%s+", ""))
    q = (string.gsub(q, "%s+$", ""))
    local cnt = {}
    for _, f in ipairs(feats) do
        local m = (q == "") or (string.find(f.texto, q, 1, true) ~= nil)
        if f.row then f.row.Visible = m end
        if m then cnt[f.page] = (cnt[f.page] or 0) + 1 end
    end
    for _, h in ipairs(headersBusq) do h.Visible = (q == "") end
    for n, o in pairs(tabObjs) do
        o.btn.Visible = (q == "") or ((cnt[n] or 0) > 0)
    end
    for _, c in pairs(cats) do
        local alguna = false
        for _, n in ipairs(c.paginas) do
            if tabObjs[n].btn.Visible then alguna = true break end
        end
        c.header.Visible = alguna
        c.cont.Visible = alguna and c.cont.Visible
    end
    if q ~= "" and (cnt[paginaActiva] or 0) == 0 then
        for _, n in ipairs(ordenPaginas) do
            if (cnt[n] or 0) > 0 then seleccionar(n) break end
        end
    end
end
Search:GetPropertyChangedSignal("Text"):Connect(aplicarBusqueda)

local function registrar(row, titulo, desc)
    feats[#feats + 1] = {row = row, texto = string.lower(titulo .. " " .. (desc or "")), page = paginaActual}
end

-- ========== COMPONENTES (estilo burbuja, un color por opción) ==========
local function mezclar(c, a) return c:Lerp(Color3.new(1, 1, 1), a) end

local function crearSeccion(parent, texto)
    local l = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Text = string.upper(texto), Font = Enum.Font.GothamBold,
        TextSize = 11, TextColor3 = colorPagina, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
    })
    headersBusq[#headersBusq + 1] = l
    return l
end

local function crearNota(parent, texto, alto)
    local l = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, alto or 34), BackgroundTransparency = 1, Text = texto, Font = Enum.Font.Gotham,
        TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        __t = {TextColor3 = "sub"}, Parent = parent,
    })
    headersBusq[#headersBusq + 1] = l
    return l
end

-- Tarjeta con esquinas redondas, borde y franja del color de su opción
local function crearCard(parent, titulo, desc, alto, color)
    color = color or colorSiguiente()
    local tieneDesc = desc and desc ~= ""
    local card = new("Frame", {
        Size = UDim2.new(1, 0, 0, alto or 58), BackgroundTransparency = 0.2, __t = {BackgroundColor3 = "panel"}, Parent = parent,
    }, {corner(14)})
    local st = stroke(color, 1.5, 0.55)
    st.Parent = card

    -- franja de color (identifica la opción)
    new("Frame", {
        Size = UDim2.new(0, 4, 1, -22), Position = UDim2.new(0, 8, 0, 11), BackgroundColor3 = color,
        BorderSizePixel = 0, Parent = card,
    }, {corner(2)})

    new("TextLabel", {
        Size = UDim2.new(1, -190, 0, 18), Position = UDim2.new(0, 22, 0, 9), BackgroundTransparency = 1, Text = titulo,
        Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, __t = {TextColor3 = "texto"}, Parent = card,
    })
    if tieneDesc then
        new("TextLabel", {
            Size = UDim2.new(1, -190, 0, 16), Position = UDim2.new(0, 22, 0, 30), BackgroundTransparency = 1, Text = desc,
            Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, __t = {TextColor3 = "sub"}, Parent = card,
        })
    end
    registrar(card, titulo, desc)
    return card, color
end

local function crearToggle(parent, titulo, desc, callback, op)
    op = op or {}
    local card, col = crearCard(parent, titulo, desc, 58, op.color)
    local pg = paginaActual
    local estado = false
    local obj = {titulo = titulo}

    local sw = new("Frame", {Size = UDim2.new(0, 44, 0, 22), Position = UDim2.new(1, -58, 0.5, -11), BackgroundColor3 = T.off, Parent = card}, {corner(11)})
    local glow = stroke(col, 1.5, 1)
    glow.Parent = sw
    local knob = new("Frame", {Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(0, 3, 0.5, -8), BackgroundColor3 = Color3.new(1, 1, 1), Parent = sw}, {corner(8)})
    local btn = new("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", Parent = card})

    local function set(v, silencioso)
        local antes = estado
        estado = v
        if antes ~= v then
            activos[pg] = (activos[pg] or 0) + (v and 1 or -1)
            actualizarBadge(pg)
        end
        tween(sw, 0.2, {BackgroundColor3 = v and col or T.off})
        tween(glow, 0.2, {Transparency = v and 0.3 or 1})
        tweenEx(knob, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = v and UDim2.new(0, 25, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
        })
        if not silencioso then
            reproducir(v and "on" or "off")
            local sc = card:FindFirstChildOfClass("UIScale")
            if sc then
                sc.Scale = 1.04
                tweenEx(sc, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
            end
            local x = (sw.AbsolutePosition.X - card.AbsolutePosition.X + sw.AbsoluteSize.X / 2) / escalaUI
            burbujasPop(card, x, 29, v and col or T.off, v and 9 or 4)
            callback(v)
        end
    end
    onTema(function() sw.BackgroundColor3 = estado and col or T.off end)

    obj.set = set
    obj.get = function() return estado end
    obj.toggle = function()
        set(not estado)
        notificar(titulo .. (estado and ":  ON" or ":  OFF"))
    end
    btn.MouseButton1Click:Connect(function() set(not estado) end)
    efecto(btn, card, {hover = 1.01, glow = col, sinSonido = true})

    -- Botón de atajo de teclado
    if not op.sinBind then
        local bb = new("TextButton", {
            Size = UDim2.new(0, 36, 0, 28), Position = UDim2.new(1, -104, 0.5, -14), BackgroundTransparency = 0.1,
            Text = "—", Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false, ZIndex = 3,
            __t = {BackgroundColor3 = "panel2"}, Parent = card,
        }, {corner(10)})
        efecto(bb, bb, {hover = 1.08, sinRipple = true, sinGlow = true})
        local function etiqueta()
            bb.Text = obj.key and nombreTecla(obj.key) or "—"
            bb.TextColor3 = obj.key and col or T.sub
        end
        onTema(etiqueta)
        obj.quitar = function()
            if obj.key then binds[obj.key] = nil end
            obj.key = nil
            etiqueta()
        end
        bb.MouseButton1Click:Connect(function()
            if escuchando then return end
            bb.Text = "..."
            bb.TextColor3 = Color3.fromRGB(255, 200, 80)
            escuchando = {
                cancelar = function(msg) etiqueta(); if msg then notificar(msg) end end,
                limpiar = function() obj.quitar(); notificar("Atajo quitado: " .. titulo) end,
                asignar = function(k)
                    if k == teclaOcultar then
                        etiqueta()
                        notificar("Esa tecla oculta el menú, elige otra")
                        return
                    end
                    if binds[k] and binds[k] ~= obj then binds[k].quitar() end
                    if obj.key then binds[obj.key] = nil end
                    obj.key = k
                    binds[k] = obj
                    etiqueta()
                    notificar(titulo .. ": atajo " .. k.Name)
                end,
            }
        end)
    end

    if op.inicial then set(true, true) end
    return obj
end

local function crearSlider(parent, titulo, min, max, def, paso, callback, sufijo, color)
    local card, col = crearCard(parent, titulo, "", 62, color)
    efecto(card, card, {hover = 1.01, sinRipple = true, glow = col})
    local valor = new("TextLabel", {
        Size = UDim2.new(0, 80, 0, 18), Position = UDim2.new(1, -94, 0, 9), BackgroundTransparency = 1, Text = "",
        Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = col, TextXAlignment = Enum.TextXAlignment.Right, Parent = card,
    })
    local hit = new("Frame", {Size = UDim2.new(1, -44, 0, 22), Position = UDim2.new(0, 22, 0, 33), BackgroundTransparency = 1, Parent = card})
    local track = new("Frame", {Size = UDim2.new(1, 0, 0, 8), Position = UDim2.new(0, 0, 0.5, -4), __t = {BackgroundColor3 = "off"}, Parent = hit}, {corner(4)})
    local fill = new("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track}, {
        corner(4),
        new("UIGradient", {Color = ColorSequence.new(col, mezclar(col, 0.4))}),
    })
    local knob = new("Frame", {
        Size = UDim2.new(0, 16, 0, 16), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = track,
    }, {corner(8), stroke(col, 2.5, 0.1)})

    local function set(v, silencioso)
        v = math.clamp(v, min, max)
        local rel = (v - min) / (max - min)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, 0, 0.5, 0)
        valor.Text = tostring(v) .. (sufijo or "")
        if not silencioso then callback(v) end
    end
    local function desdeX(x)
        local rel = math.clamp((x - hit.AbsolutePosition.X) / hit.AbsoluteSize.X, 0, 1)
        local v = math.floor((min + (max - min) * rel) / paso + 0.5) * paso
        set(math.clamp(v, min, max))
    end

    local dragging = false
    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            tweenEx(knob, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 21, 0, 21)})
            desdeX(input.Position.X)
        end
    end)
    conns[#conns + 1] = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            desdeX(input.Position.X)
        end
    end)
    conns[#conns + 1] = UserInputService.InputEnded:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            tween(knob, 0.15, {Size = UDim2.new(0, 16, 0, 16)})
        end
    end)
    set(def)
    return set
end

local function crearAccion(parent, titulo, desc, textoBtn, callback, color)
    local card, col = crearCard(parent, titulo, desc, 58, color)
    local b = new("TextButton", {
        Size = UDim2.new(0, 124, 0, 28), Position = UDim2.new(1, -138, 0.5, -14), Text = textoBtn,
        Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false, TextColor3 = col,
        __t = {BackgroundColor3 = "panel2"}, Parent = card,
    }, {corner(10), stroke(col, 1, 0.6)})
    efecto(b, b, {hover = 1.05, sinGlow = true})
    b.MouseButton1Click:Connect(callback)
    return b
end

-- Selector de varias opciones (botones tipo burbuja)
local function crearSelector(parent, titulo, desc, opciones, def, callback, color)
    local card, col = crearCard(parent, titulo, desc, 88, color)
    local fila = new("Frame", {Size = UDim2.new(1, -28, 0, 28), Position = UDim2.new(0, 14, 0, 52), BackgroundTransparency = 1, Parent = card}, {
        new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}),
    })
    local n = #opciones
    local botones = {}
    local sel = def
    local function pintar()
        for i, b in ipairs(botones) do
            local a = (i == sel)
            tween(b, 0.2, {BackgroundColor3 = a and col or T.panel2, TextColor3 = a and Color3.new(1, 1, 1) or T.sub})
        end
    end
    for i, nombre in ipairs(opciones) do
        local b = new("TextButton", {
            Size = UDim2.new(1 / n, -(6 * (n - 1)) / n, 1, 0), BackgroundColor3 = T.panel2, Text = nombre,
            TextColor3 = T.sub, Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false, LayoutOrder = i, Parent = fila,
        }, {corner(10)})
        efecto(b, b, {hover = 1.04, sinGlow = true})
        b.MouseButton1Click:Connect(function()
            sel = i
            pintar()
            callback(nombre, i)
        end)
        botones[i] = b
    end
    onTema(pintar)
    return function(i) sel = i; pintar() end
end

-- ========== LÓGICA: VUELO ==========
local function detenerVuelo()
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hum then hum.PlatformStand = false; hum.AutoRotate = true end
        if hrp then hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end
    end
end

-- ========== LÓGICA: ESP (box, skeleton, vida, nombre, distancia, tracers, chams) ==========
local espOpt = {box = true, skel = true, hp = true, name = true, dist = true, tool = false, tracer = false, chams = false}
local espMaxDist = 2000
local espIgnoreTeam = false
local espObjs = {}

local EspGui = new("ScreenGui", {
    Name = "NahualESP", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 40,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = guiParent,
})

local R15 = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}
local R6 = {
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"}, {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
}

local function nuevaLinea(parent)
    return new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        Visible = false, Parent = parent,
    })
end

local function setLinea(f, a, b, grosor, color)
    local d = b - a
    f.Size = UDim2.new(0, d.Magnitude, 0, grosor)
    f.Position = UDim2.new(0, (a.X + b.X) / 2, 0, (a.Y + b.Y) / 2)
    f.Rotation = math.deg(math.atan2(d.Y, d.X))
    f.BackgroundColor3 = color
    f.Visible = true
end

local function crearEspObj(p)
    local folder = new("Folder", {Name = p.Name, Parent = EspGui})
    local o = {folder = folder, bones = {}}
    o.box = new("Frame", {BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, Parent = folder})
    o.boxStroke = stroke(Color3.new(1, 1, 1), 1.5, 0)
    o.boxStroke.Parent = o.box
    o.hpBg = new("Frame", {BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, Visible = false, Parent = folder})
    o.hpFill = new("Frame", {
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(90, 230, 120), BorderSizePixel = 0, Parent = o.hpBg,
    })
    o.name = new("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(0, 160, 0, 14), BackgroundTransparency = 1,
        TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 12, TextStrokeTransparency = 0.4,
        Visible = false, Parent = folder,
    })
    o.info = new("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 160, 0, 14), BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(230, 230, 240), Font = Enum.Font.GothamMedium, TextSize = 11, TextStrokeTransparency = 0.4,
        Visible = false, Parent = folder,
    })
    o.tracer = nuevaLinea(folder)
    for i = 1, 14 do o.bones[i] = nuevaLinea(folder) end
    return o
end

local function ocultarEsp(o)
    o.box.Visible = false
    o.hpBg.Visible = false
    o.name.Visible = false
    o.info.Visible = false
    o.tracer.Visible = false
    for _, b in ipairs(o.bones) do b.Visible = false end
end

local function quitarEspJugador(p)
    quitarEspJugador(p)
    if espObjs[p] then espObjs[p].folder:Destroy(); espObjs[p] = nil end
end

local function limpiarESP()
    for _, hl in pairs(espCache) do
        if hl then hl:Destroy() end
    end
    espCache = {}
    for _, o in pairs(espObjs) do o.folder:Destroy() end
    espObjs = {}
end

local function pasoESP()
    if not espEnabled then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local o = espObjs[p]
            local char = p.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local head = char and char:FindFirstChild("Head")
            local valido = false
            local dist = 0
            if hum and hrp and head and hum.Health > 0 then
                valido = true
                if espIgnoreTeam and p.Team and p.Team == LocalPlayer.Team then valido = false end
                dist = (hrp.Position - cam.CFrame.Position).Magnitude
                if dist > espMaxDist then valido = false end
            end

            -- Chams (resaltado a través de paredes)
            local hl = espCache[p]
            if valido and espOpt.chams then
                if not hl or not hl.Parent or hl.Adornee ~= char then
                    if hl then hl:Destroy() end
                    hl = Instance.new("Highlight")
                    hl.Name = "NahualHighlight"
                    hl.Adornee = char
                    hl.FillColor = T.accent
                    hl.OutlineColor = T.accent2
                    hl.FillTransparency = 0.5
                    hl.OutlineTransparency = 0
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Parent = char
                    espCache[p] = hl
                end
            elseif hl then
                hl:Destroy()
                espCache[p] = nil
            end

            if not valido then
                if o then ocultarEsp(o) end
            else
                if not o then
                    o = crearEspObj(p)
                    espObjs[p] = o
                end
                local top = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 0.7, 0))
                local bot = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                if top.Z <= 0 or bot.Z <= 0 then
                    ocultarEsp(o)
                else
                    local h = math.max(math.abs(bot.Y - top.Y), 8)
                    local w = h * 0.55
                    local cx = (top.X + bot.X) / 2
                    local y0 = math.min(top.Y, bot.Y)
                    local x0 = cx - w / 2
                    local col = (p.Team and p.TeamColor.Color) or T.accent2

                    -- Box
                    o.box.Visible = espOpt.box
                    if espOpt.box then
                        o.box.Position = UDim2.new(0, x0, 0, y0)
                        o.box.Size = UDim2.new(0, w, 0, h)
                        o.boxStroke.Color = col
                    end

                    -- Barra de vida
                    o.hpBg.Visible = espOpt.hp
                    if espOpt.hp then
                        local f = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                        o.hpBg.Position = UDim2.new(0, x0 - 6, 0, y0)
                        o.hpBg.Size = UDim2.new(0, 3, 0, h)
                        o.hpFill.Size = UDim2.new(1, 0, f, 0)
                        o.hpFill.BackgroundColor3 = Color3.fromRGB(255, 70, 70):Lerp(Color3.fromRGB(90, 230, 120), f)
                    end

                    -- Nombre
                    o.name.Visible = espOpt.name
                    if espOpt.name then
                        o.name.Position = UDim2.new(0, cx, 0, y0 - 2)
                        o.name.Text = p.DisplayName
                    end

                    -- Distancia y herramienta
                    local partes = {}
                    if espOpt.dist then partes[#partes + 1] = "[" .. math.floor(dist) .. "m]" end
                    if espOpt.tool then
                        local tl = char:FindFirstChildOfClass("Tool")
                        if tl then partes[#partes + 1] = tl.Name end
                    end
                    if #partes > 0 then
                        o.info.Visible = true
                        o.info.Position = UDim2.new(0, cx, 0, y0 + h + 2)
                        o.info.Text = table.concat(partes, "  ")
                    else
                        o.info.Visible = false
                    end

                    -- Línea (tracer)
                    if espOpt.tracer then
                        setLinea(o.tracer, Vector2.new(vp.X / 2, vp.Y), Vector2.new(cx, y0 + h), 1.2, col)
                    else
                        o.tracer.Visible = false
                    end

                    -- Skeleton
                    local rig = char:FindFirstChild("UpperTorso") and R15 or R6
                    for i, b in ipairs(o.bones) do
                        local par = espOpt.skel and rig[i]
                        local dibujado = false
                        if par then
                            local pa, pb = char:FindFirstChild(par[1]), char:FindFirstChild(par[2])
                            if pa and pb then
                                local va = cam:WorldToViewportPoint(pa.Position)
                                local vb = cam:WorldToViewportPoint(pb.Position)
                                if va.Z > 0 and vb.Z > 0 then
                                    setLinea(b, Vector2.new(va.X, va.Y), Vector2.new(vb.X, vb.Y), 1.5, Color3.new(1, 1, 1))
                                    dibujado = true
                                end
                            end
                        end
                        if not dibujado then b.Visible = false end
                    end
                end
            end
        end
    end
end

onTema(function()
    for _, hl in pairs(espCache) do
        if hl then hl.FillColor = T.accent; hl.OutlineColor = T.accent2 end
    end
end)

-- ========== LÓGICA: HITBOX ==========
local function restaurarHitbox(player)
    local d = hitboxOriginal[player]
    if d and d.hrp and d.hrp.Parent then
        d.hrp.Size = d.Size
        d.hrp.Transparency = d.Transparency
        d.hrp.CanCollide = d.CanCollide
    end
    hitboxOriginal[player] = nil
end

local function restaurarTodosHitbox()
    for p in pairs(hitboxOriginal) do restaurarHitbox(p) end
    hitboxOriginal = {}
end

local function aplicarHitbox(player)
    if player == LocalPlayer then return end
    if ignorarEquipo and player.Team and player.Team == LocalPlayer.Team then
        restaurarHitbox(player)
        return
    end
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local d = hitboxOriginal[player]
    if not d or d.hrp ~= hrp then
        hitboxOriginal[player] = {hrp = hrp, Size = hrp.Size, Transparency = hrp.Transparency, CanCollide = hrp.CanCollide}
    end
    hrp.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
    hrp.Transparency = 0.7
    hrp.CanCollide = false
end

-- ========== LÓGICA: AIM ASSIST ==========
local aimEnabled = false
local aimActIdx = 1          -- 1 clic der., 2 clic izq., 3 Shift, 4 siempre
local aimModo = 2             -- 1 = Mouse (mueve el cursor), 2 = Primera persona (mueve la cámara)
local aimAuto = false         -- elegir el modo según la cámara
local aimAcumX, aimAcumY = 0, 0
local avisoMmr = false
local aimFOV = 120
local aimSmooth = 8
local aimPartIdx = 1
local aimTeam = true
local aimWall = true
local aimShowFOV = false
local aimTarget = nil

local AimGui = new("ScreenGui", {
    Name = "NahualAimFOV", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 50,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = guiParent,
})
local FovCircle = new("Frame", {
    Size = UDim2.new(0, aimFOV * 2, 0, aimFOV * 2), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.morado, BackgroundTransparency = 0.93,
    Visible = false, Parent = AimGui,
}, {new("UICorner", {CornerRadius = UDim.new(1, 0)})})
local fovStroke = stroke(C.morado, 2, 0)
fovStroke.Parent = FovCircle

local aimPartes = {{"Head"}, {"UpperTorso", "Torso"}, {"HumanoidRootPart"}}

local function obtenerParte(char)
    for _, n in ipairs(aimPartes[aimPartIdx]) do
        local p = char:FindFirstChild(n)
        if p then return p end
    end
    return char:FindFirstChild("HumanoidRootPart")
end

local function mejorObjetivo(cam, mouse)
    local mejor, mejorDist
    local miChar = LocalPlayer.Character
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = miChar and {miChar} or {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local char = p.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and not (aimTeam and p.Team and p.Team == LocalPlayer.Team) then
                local parte = obtenerParte(char)
                if parte then
                    local v, enPantalla = cam:WorldToViewportPoint(parte.Position)
                    if enPantalla then
                        local d = (Vector2.new(v.X, v.Y) - mouse).Magnitude
                        if d <= aimFOV and (not mejorDist or d < mejorDist) then
                            local visible = true
                            if aimWall then
                                local origen = cam.CFrame.Position
                                local r = workspace:Raycast(origen, parte.Position - origen, params)
                                if r and not r.Instance:IsDescendantOf(char) then visible = false end
                            end
                            if visible then mejor, mejorDist = parte, d end
                        end
                    end
                end
            end
        end
    end
    return mejor
end

-- ¿Está presionada la tecla/botón de activación?
local function aimActivo()
    if aimActIdx == 1 then
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    elseif aimActIdx == 2 then
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    elseif aimActIdx == 3 then
        return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
    end
    return true
end

-- Modo efectivo: manual o automático según la cámara
local function modoEfectivo(cam)
    if not aimAuto then return aimModo end
    local ch = LocalPlayer.Character
    local head = ch and ch:FindFirstChild("Head")
    local fp = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
        or (head ~= nil and (cam.CFrame.Position - head.Position).Magnitude < 1.6)
    return fp and 2 or 1
end

-- Mueve el cursor con la función del executor (mousemoverel)
local function moverMouse(dx, dy)
    local f = mousemoverel or (getgenv and getgenv().mousemoverel)
    if type(f) ~= "function" then return false end
    return (pcall(f, dx, dy))
end

local function pasoAim(dt)
    local cam = workspace.CurrentCamera
    local mouse = UserInputService:GetMouseLocation()
    if not aimEnabled or not cam then aimTarget = nil return end
    if not aimActivo() then
        aimTarget = nil
        aimAcumX, aimAcumY = 0, 0
        fovStroke.Color = C.morado
        return
    end

    local parte = mejorObjetivo(cam, mouse)
    aimTarget = parte
    fovStroke.Color = parte and C.verde or C.morado
    if not parte then
        aimAcumX, aimAcumY = 0, 0
        return
    end

    local alpha = aimSmooth <= 1 and 1 or (1 - (1 - 1 / aimSmooth) ^ (dt * 60))
    alpha = math.clamp(alpha, 0, 1)
    local modo = modoEfectivo(cam)

    if modo == 1 then
        -- MODO MOUSE: el cursor se desplaza hacia el objetivo
        local v = cam:WorldToViewportPoint(parte.Position)
        aimAcumX = aimAcumX + (v.X - mouse.X) * alpha
        aimAcumY = aimAcumY + (v.Y - mouse.Y) * alpha
        local ix = aimAcumX >= 0 and math.floor(aimAcumX) or math.ceil(aimAcumX)
        local iy = aimAcumY >= 0 and math.floor(aimAcumY) or math.ceil(aimAcumY)
        if ix ~= 0 or iy ~= 0 then
            aimAcumX = aimAcumX - ix
            aimAcumY = aimAcumY - iy
            if not moverMouse(ix, iy) then
                -- Tu executor no tiene mousemoverel: se usa la cámara
                if not avisoMmr then
                    avisoMmr = true
                    notificar("Tu executor no soporta mover el cursor, usando la cámara")
                end
                local deseado = CFrame.lookAt(cam.CFrame.Position, parte.Position)
                cam.CFrame = cam.CFrame:Lerp(deseado, alpha)
            end
        end
    else
        -- MODO PRIMERA PERSONA: la cámara apunta al objetivo
        aimAcumX, aimAcumY = 0, 0
        local deseado = CFrame.lookAt(cam.CFrame.Position, parte.Position)
        cam.CFrame = cam.CFrame:Lerp(deseado, alpha)
    end
end

-- El círculo FOV se actualiza aparte, para que siempre se vea al activarlo
local function actualizarFOV()
    local m = UserInputService:GetMouseLocation()
    FovCircle.Position = UDim2.new(0, m.X, 0, m.Y)
    FovCircle.Size = UDim2.new(0, aimFOV * 2, 0, aimFOV * 2)
    FovCircle.Visible = aimShowFOV
end
conns[#conns + 1] = RunService.RenderStepped:Connect(function() pcall(actualizarFOV) end)

pcall(function() RunService:UnbindFromRenderStep("NahualAim") end)
RunService:BindToRenderStep("NahualAim", Enum.RenderPriority.Camera.Value + 1, function(dt)
    pcall(pasoAim, dt)
end)

-- ========== PÁGINA: VUELO ==========
local pMov = crearTab("MOVIMIENTO", "Vuelo", true, C.cielo, true)
crearSeccion(pMov, "Vuelo")
local flyObj = crearToggle(pMov, "Vuelo", "Vuela hacia donde mira la cámara (WASD, Espacio, Ctrl).", function(v)
    flying = v
    if not v then detenerVuelo() end
end, {color = C.cielo})
crearSlider(pMov, "Velocidad de vuelo", 10, 200, speed, 5, function(v) speed = v end, nil, C.menta)
crearNota(pMov, "Cada opción tiene su propio color. Usa el cuadro junto al switch para asignar una tecla de atajo.")

-- ========== PÁGINA: HITBOX ==========
local pCom = crearTab("COMBATE", "Hitbox", true, C.rojo, true)
crearSeccion(pCom, "Hitbox")
crearToggle(pCom, "Hitbox expandido", "Agranda el HumanoidRootPart de los demás jugadores.", function(v)
    hitboxEnabled = v
    if not v then restaurarTodosHitbox() end
end, {color = C.rojo})
crearSlider(pCom, "Tamaño del hitbox", 2, 50, hitboxSize, 2, function(v) hitboxSize = v end, nil, C.naranja)
crearToggle(pCom, "Ignorar mi equipo", "No modifica a los jugadores de tu equipo.", function(v) ignorarEquipo = v end, {sinBind = true, color = C.amarillo})
crearNota(pCom, "Es del lado del cliente: el efecto depende de cómo valide los golpes el servidor.")

-- ========== PÁGINA: AIM ==========
local pAim = crearTab("COMBATE", "Aim", true, C.morado, true)
crearSeccion(pAim, "Aim Assist")
crearToggle(pAim, "Aim Assist", "Apunta suavemente al jugador más cercano a tu mira.", function(v)
    aimEnabled = v
    if not v then aimTarget = nil end
end, {color = C.morado})
crearSelector(pAim, "Modo de aim", "Mouse mueve el cursor; Primera persona mueve la cámara.", {"Mouse", "Primera persona"}, 2, function(_, i) aimModo = i end, C.rojo)
crearToggle(pAim, "Modo automático", "Elige el modo según tu cámara (cursor libre o primera persona).", function(v) aimAuto = v end, {sinBind = true, color = C.menta})
crearSelector(pAim, "Activar con", "Qué mantener presionado para apuntar.", {"Clic der.", "Clic izq.", "Shift", "Siempre"}, 1, function(_, i) aimActIdx = i end, C.rosa)
crearSelector(pAim, "Parte objetivo", "A qué parte del cuerpo apunta.", {"Cabeza", "Torso", "Cuerpo"}, 1, function(_, i) aimPartIdx = i end, C.naranja)
crearSlider(pAim, "Radio del FOV", 40, 400, aimFOV, 10, function(v)
    aimFOV = v
    FovCircle.Size = UDim2.new(0, v * 2, 0, v * 2)
end, " px", C.amarillo)
crearSlider(pAim, "Suavidad (más alto = más lento)", 1, 30, aimSmooth, 1, function(v) aimSmooth = v end, nil, C.menta)
crearSeccion(pAim, "Filtros")
crearToggle(pAim, "Mostrar círculo FOV", "Dibuja el área donde el aim busca objetivos.", function(v) aimShowFOV = v; FovCircle.Visible = v end, {sinBind = true, color = C.cielo})
crearToggle(pAim, "Ignorar mi equipo", "No apunta a jugadores de tu equipo.", function(v) aimTeam = v end, {sinBind = true, inicial = true, color = C.verde})
crearToggle(pAim, "No apuntar tras paredes", "Solo apunta a jugadores que puedes ver.", function(v) aimWall = v end, {sinBind = true, inicial = true, color = C.azul})
crearNota(pAim, "El círculo se pone verde cuando hay un objetivo fijado. En modo Mouse usa Clic izq., Shift o Siempre: con clic derecho Roblox bloquea el cursor. Mover el cursor requiere que tu executor tenga mousemoverel.", 58)

-- ========== PÁGINA: ESP ==========
local pVis = crearTab("VISUAL", "ESP", true, C.verde, true)
crearSeccion(pVis, "ESP")
crearToggle(pVis, "ESP", "Activa el ESP con las opciones de abajo.", function(v)
    espEnabled = v
    if not v then limpiarESP() end
end, {color = C.verde})
crearSeccion(pVis, "Elementos")
crearToggle(pVis, "Box", "Caja alrededor del jugador.", function(v) espOpt.box = v end, {sinBind = true, inicial = true, color = C.cielo})
crearToggle(pVis, "Skeleton", "Dibuja los huesos del personaje.", function(v) espOpt.skel = v end, {sinBind = true, inicial = true, color = C.rosa})
crearToggle(pVis, "Barra de vida", "Barra al costado con la salud.", function(v) espOpt.hp = v end, {sinBind = true, inicial = true, color = C.rojo})
crearToggle(pVis, "Nombre", "Nombre sobre la caja.", function(v) espOpt.name = v end, {sinBind = true, inicial = true, color = C.amarillo})
crearToggle(pVis, "Distancia", "Distancia al jugador en studs.", function(v) espOpt.dist = v end, {sinBind = true, inicial = true, color = C.naranja})
crearToggle(pVis, "Herramienta", "Muestra qué lleva en la mano.", function(v) espOpt.tool = v end, {sinBind = true, color = C.menta})
crearToggle(pVis, "Líneas (tracers)", "Línea desde abajo de la pantalla hasta el jugador.", function(v) espOpt.tracer = v end, {sinBind = true, color = C.azul})
crearToggle(pVis, "Chams", "Resalta el cuerpo a través de las paredes.", function(v) espOpt.chams = v end, {sinBind = true, color = C.morado})
crearSeccion(pVis, "Filtros")
crearSlider(pVis, "Distancia máxima", 100, 5000, espMaxDist, 100, function(v) espMaxDist = v end, " m", C.amarillo)
crearToggle(pVis, "Ignorar mi equipo", "No dibuja a los jugadores de tu equipo.", function(v) espIgnoreTeam = v end, {sinBind = true, color = C.verde})

-- ========== PÁGINA: JUGADORES ==========
local pJug = crearTab("JUGADORES", "Jugadores", false, C.amarillo)
feats[#feats + 1] = {texto = "jugadores teletransportar tp observar spectate lista informacion", page = "Jugadores"}

local Left = new("Frame", {Size = UDim2.new(0.4, 0, 1, 0), BackgroundTransparency = 1, Parent = pJug})
local PSearch = new("TextBox", {
    Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 0.15, Text = "", PlaceholderText = "Buscar jugador...",
    Font = Enum.Font.Gotham, TextSize = 12, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
    __t = {BackgroundColor3 = "panel", TextColor3 = "texto", PlaceholderColor3 = "sub"}, Parent = Left,
}, {corner(8), new("UIPadding", {PaddingLeft = UDim.new(0, 10)}), stroke("off", 1, 0.35)})

local List = new("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, -36), Position = UDim2.new(0, 0, 0, 36), BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0),
    __t = {ScrollBarImageColor3 = "accent"}, Parent = Left,
}, {new("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.Name})})

local Right = new("Frame", {
    Size = UDim2.new(0.6, -10, 1, 0), Position = UDim2.new(0.4, 10, 0, 0), BackgroundTransparency = 0.15,
    __t = {BackgroundColor3 = "panel"}, Parent = pJug,
}, {corner(10), stroke("off", 1, 0.35)})

local Avatar = new("ImageLabel", {
    Size = UDim2.new(0, 56, 0, 56), Position = UDim2.new(0, 10, 0, 10), Image = "",
    __t = {BackgroundColor3 = "panel2"}, Parent = Right,
}, {corner(28), stroke("accent", 1.5, 0.2)})

local NombreLbl = new("TextLabel", {
    Size = UDim2.new(1, -84, 0, 22), Position = UDim2.new(0, 76, 0, 14), BackgroundTransparency = 1,
    Text = "Selecciona un jugador", Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd, __t = {TextColor3 = "texto"}, Parent = Right,
})
local DisplayLbl = new("TextLabel", {
    Size = UDim2.new(1, -84, 0, 18), Position = UDim2.new(0, 76, 0, 36), BackgroundTransparency = 1, Text = "",
    Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd, __t = {TextColor3 = "sub"}, Parent = Right,
})

local infoLabels = {}
local campos = {"ID de usuario", "Edad de cuenta", "Equipo", "Vida", "Distancia", "Posición", "Herramienta", "Velocidad"}
for i, nombre in ipairs(campos) do
    local y = 78 + (i - 1) * 22
    new("TextLabel", {
        Size = UDim2.new(0.4, 0, 0, 18), Position = UDim2.new(0, 12, 0, y), BackgroundTransparency = 1, Text = nombre,
        Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        __t = {TextColor3 = "sub"}, Parent = Right,
    })
    infoLabels[nombre] = new("TextLabel", {
        Size = UDim2.new(0.6, -20, 0, 18), Position = UDim2.new(0.4, 6, 0, y), BackgroundTransparency = 1, Text = "-",
        Font = Enum.Font.GothamMedium, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, __t = {TextColor3 = "texto"}, Parent = Right,
    })
end

local TPBtn = new("TextButton", {
    Size = UDim2.new(0.5, -15, 0, 34), Position = UDim2.new(0, 10, 1, -44), Text = "Teletransportar",
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false,
    __t = {BackgroundColor3 = "accent"}, Parent = Right,
}, {corner(8)})
local SpecBtn = new("TextButton", {
    Size = UDim2.new(0.5, -15, 0, 34), Position = UDim2.new(0.5, 5, 1, -44), Text = "Observar",
    Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false,
    __t = {BackgroundColor3 = "panel2", TextColor3 = "texto"}, Parent = Right,
}, {corner(8)})
efecto(TPBtn, TPBtn, {hover = 1.04})
efecto(SpecBtn, SpecBtn, {hover = 1.04})

local function dejarDeObservar()
    spectating = false
    SpecBtn.Text = "Observar"
    tween(SpecBtn, 0.2, {BackgroundColor3 = T.panel2})
    local cam = workspace.CurrentCamera
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if cam and hum then cam.CameraSubject = hum end
end

SpecBtn.MouseButton1Click:Connect(function()
    if spectating then dejarDeObservar() return end
    if not selected then notificar("Selecciona un jugador primero") return end
    local char = selected.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then notificar("El jugador no tiene personaje") return end
    workspace.CurrentCamera.CameraSubject = hum
    spectating = true
    SpecBtn.Text = "Dejar de observar"
    tween(SpecBtn, 0.2, {BackgroundColor3 = T.rojo})
end)

TPBtn.MouseButton1Click:Connect(function()
    if not selected or not selected.Parent then notificar("Selecciona un jugador primero") return end
    local miChar = LocalPlayer.Character
    local miHrp = miChar and miChar:FindFirstChild("HumanoidRootPart")
    local suChar = selected.Character
    local suHrp = suChar and suChar:FindFirstChild("HumanoidRootPart")
    if not miHrp then notificar("Tu personaje no está listo") return end
    if not suHrp then notificar("El jugador no tiene personaje") return end
    miHrp.CFrame = suHrp.CFrame * CFrame.new(0, 0, 4)
    notificar("Teletransportado a " .. selected.Name)
end)

local function seleccionarJugador(p)
    selected = p
    if spectating then dejarDeObservar() end
    NombreLbl.Text = "@" .. p.Name
    DisplayLbl.Text = p.DisplayName
    Avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. p.UserId .. "&w=150&h=150"
    for _, b in ipairs(List:GetChildren()) do
        if b:IsA("TextButton") then
            tween(b, 0.15, {BackgroundColor3 = (b.Name == p.Name) and T.accent or T.panel})
        end
    end
end

local function refrescarLista()
    for _, c in ipairs(List:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local filtro = string.lower(PSearch.Text)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local coincide = filtro == "" or string.find(string.lower(p.Name), filtro, 1, true) or string.find(string.lower(p.DisplayName), filtro, 1, true)
            if coincide then
                local b = new("TextButton", {
                    Name = p.Name, Size = UDim2.new(1, -4, 0, 34), BackgroundColor3 = (selected == p) and T.accent or T.panel,
                    BackgroundTransparency = 0.15, Text = "", AutoButtonColor = false, Parent = List,
                }, {corner(8), stroke("off", 1, 0.4)})
                new("ImageLabel", {
                    Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(0, 6, 0.5, -12), BackgroundColor3 = T.panel2,
                    Image = "rbxthumb://type=AvatarHeadShot&id=" .. p.UserId .. "&w=48&h=48", Parent = b,
                }, {corner(12)})
                new("TextLabel", {
                    Size = UDim2.new(1, -40, 1, 0), Position = UDim2.new(0, 36, 0, 0), BackgroundTransparency = 1,
                    Text = p.DisplayName, TextColor3 = T.texto, Font = Enum.Font.GothamMedium, TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = b,
                })
                efecto(b, b, {hover = 1.02})
                b.MouseButton1Click:Connect(function() seleccionarJugador(p) end)
            end
        end
    end
end
PSearch:GetPropertyChangedSignal("Text"):Connect(refrescarLista)
onTema(refrescarLista)

local function limpiarInfo()
    NombreLbl.Text = "Selecciona un jugador"
    DisplayLbl.Text = ""
    Avatar.Image = ""
    for _, l in pairs(infoLabels) do l.Text = "-" end
end

local function actualizarInfo()
    if not selected then return end
    if not selected.Parent then
        selected = nil
        limpiarInfo()
        return
    end
    local char = selected.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local miHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    infoLabels["ID de usuario"].Text = tostring(selected.UserId)
    infoLabels["Edad de cuenta"].Text = selected.AccountAge .. " días"
    infoLabels["Equipo"].Text = selected.Team and selected.Team.Name or "Sin equipo"
    infoLabels["Vida"].Text = hum and (math.floor(hum.Health) .. " / " .. math.floor(hum.MaxHealth)) or "-"
    infoLabels["Posición"].Text = hrp and string.format("%d, %d, %d", hrp.Position.X, hrp.Position.Y, hrp.Position.Z) or "-"
    if hrp and miHrp then
        infoLabels["Distancia"].Text = math.floor((hrp.Position - miHrp.Position).Magnitude) .. " studs"
    else
        infoLabels["Distancia"].Text = "-"
    end
    local tool = char and char:FindFirstChildOfClass("Tool")
    infoLabels["Herramienta"].Text = tool and tool.Name or "Ninguna"
    infoLabels["Velocidad"].Text = hum and (math.floor(hum.WalkSpeed) .. " WalkSpeed") or "-"
end

task.spawn(function()
    while vivo do
        pcall(actualizarInfo)
        task.wait(0.3)
    end
end)

conns[#conns + 1] = Players.PlayerAdded:Connect(refrescarLista)
conns[#conns + 1] = Players.PlayerRemoving:Connect(function(p)
    if espCache[p] then espCache[p]:Destroy(); espCache[p] = nil end
    hitboxOriginal[p] = nil
    if selected == p then
        if spectating then dejarDeObservar() end
        selected = nil
        limpiarInfo()
    end
    task.defer(refrescarLista)
end)

-- ========== PÁGINA: APARIENCIA (personalizar el GUI) ==========
local pApa = crearTab("GENERAL", "Apariencia", true, C.rosa)
local ss = {}                               -- setters de sliders
local cv = {pr = 255, pg = 125, pb = 25, sr = 150, sg = 70, sb = 255}

local function actualizarColores()
    T.accent = Color3.fromRGB(cv.pr, cv.pg, cv.pb)
    T.accent2 = Color3.fromRGB(cv.sr, cv.sg, cv.sb)
    aplicarTema()
end

aplicarPreset = function(i)
    temaIdx = i
    local tm = Temas[i]
    cargarTema(tm)
    cv.pr, cv.pg, cv.pb = math.floor(tm.accent.R * 255 + 0.5), math.floor(tm.accent.G * 255 + 0.5), math.floor(tm.accent.B * 255 + 0.5)
    cv.sr, cv.sg, cv.sb = math.floor(tm.accent2.R * 255 + 0.5), math.floor(tm.accent2.G * 255 + 0.5), math.floor(tm.accent2.B * 255 + 0.5)
    for k, setter in pairs(ss) do
        if cv[k] then setter(cv[k], true) end
    end
    aplicarTema()
    notificar("Tema: " .. tm.n)
end

crearSeccion(pApa, "Temas")
do
    local card = crearCard(pApa, "Temas predefinidos", "Elige un estilo base y ajústalo debajo.", 94)
    for i, tm in ipairs(Temas) do
        local b = new("TextButton", {
            Size = UDim2.new(0, 78, 0, 28), Position = UDim2.new(0, 14 + (i - 1) * 82, 0, 56), BackgroundColor3 = Color3.new(1, 1, 1),
            Text = tm.n, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false,
            TextStrokeTransparency = 0.5, Parent = card,
        }, {
            corner(8),
            new("UIGradient", {Color = ColorSequence.new(tm.accent, tm.accent2), Rotation = 20}),
        })
        efecto(b, b, {hover = 1.06, sinGlow = true})
        b.MouseButton1Click:Connect(function() aplicarPreset(i) end)
    end
end

crearSeccion(pApa, "Colores")
ss.pr = crearSlider(pApa, "Color principal - Rojo", 0, 255, cv.pr, 1, function(v) cv.pr = v; actualizarColores() end, nil, Color3.fromRGB(255, 90, 90))
ss.pg = crearSlider(pApa, "Color principal - Verde", 0, 255, cv.pg, 1, function(v) cv.pg = v; actualizarColores() end, nil, Color3.fromRGB(90, 230, 120))
ss.pb = crearSlider(pApa, "Color principal - Azul", 0, 255, cv.pb, 1, function(v) cv.pb = v; actualizarColores() end, nil, Color3.fromRGB(100, 140, 255))
ss.sr = crearSlider(pApa, "Color secundario - Rojo", 0, 255, cv.sr, 1, function(v) cv.sr = v; actualizarColores() end, nil, Color3.fromRGB(255, 90, 90))
ss.sg = crearSlider(pApa, "Color secundario - Verde", 0, 255, cv.sg, 1, function(v) cv.sg = v; actualizarColores() end, nil, Color3.fromRGB(90, 230, 120))
ss.sb = crearSlider(pApa, "Color secundario - Azul", 0, 255, cv.sb, 1, function(v) cv.sb = v; actualizarColores() end, nil, Color3.fromRGB(100, 140, 255))

crearSeccion(pApa, "Ventana")
local setTransp = crearSlider(pApa, "Transparencia de la ventana", 0, 60, 0, 1, function(v) Main.BackgroundTransparency = v / 100 end, "%")
local setEscala = crearSlider(pApa, "Tamaño del menú", 70, 130, 100, 5, function(v)
    escalaUI = v / 100
    if Main.Visible then tween(MainScale, 0.2, {Scale = escalaUI}) end
end, "%")
crearToggle(pApa, "Borde animado", "El borde de la ventana gira con degradado.", function(v) bordeAnimado = v end, {sinBind = true, inicial = true})
crearToggle(pApa, "Burbujas flotantes", "Burbujas animadas detrás del contenido.", function(v) MenuBubbles.Visible = v end, {sinBind = true, inicial = true})
crearToggle(pApa, "Decoración de Halloween", "Luna, murciélagos, fantasmas, calabazas y una araña.", function(v)
    HLayer.Visible = v
    hilo.Visible = v
    arana.Visible = v
end, {sinBind = true, inicial = true})

crearSeccion(pApa, "Imagen de fondo")
do
    local card = crearCard(pApa, "Imagen de fondo", "Pega el ID de una imagen de Roblox y pulsa Aplicar.", 94)
    local box = new("TextBox", {
        Size = UDim2.new(1, -140, 0, 28), Position = UDim2.new(0, 14, 0, 56), BackgroundTransparency = 0.1, Text = "",
        PlaceholderText = "ID (solo números)", ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        __t = {BackgroundColor3 = "panel2", TextColor3 = "texto", PlaceholderColor3 = "sub"}, Parent = card,
    }, {corner(7), new("UIPadding", {PaddingLeft = UDim.new(0, 8)})})
    local ap = new("TextButton", {
        Size = UDim2.new(0, 108, 0, 28), Position = UDim2.new(1, -122, 0, 56), Text = "Aplicar",
        Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false,
        __t = {BackgroundColor3 = "accent"}, Parent = card,
    }, {corner(7)})
    ap.TextColor3 = Color3.new(1, 1, 1)
    efecto(ap, ap, {hover = 1.05})
    ap.MouseButton1Click:Connect(function()
        local txt = (string.gsub(box.Text, "%s", ""))
        if txt == "" then
            FondoImg.Image = ""
            notificar("Imagen de fondo quitada")
        elseif string.match(txt, "^%d+$") then
            FondoImg.Image = "rbxassetid://" .. txt
            notificar("Imagen aplicada (usa el ID de la imagen, no del decal)")
        else
            FondoImg.Image = txt
            notificar("Imagen aplicada")
        end
    end)
end
crearSlider(pApa, "Visibilidad de la imagen", 5, 100, 40, 5, function(v) FondoImg.ImageTransparency = 1 - v / 100 end, "%")

crearSeccion(pApa, "Restablecer")
crearAccion(pApa, "Restablecer apariencia", "Vuelve al tema, tamaño y transparencia originales.", "Restablecer", function()
    aplicarPreset(1)
    setTransp(0)
    setEscala(100)
    FondoImg.Image = ""
end)

-- ========== PÁGINA: AJUSTES ==========
local pAju = crearTab("GENERAL", "Ajustes", true, C.gris)
crearSeccion(pAju, "Atajos")

local KeyBtn
local function refrescarKeyBtn()
    if KeyBtn then
        KeyBtn.Text = "[ " .. teclaOcultar.Name .. " ]"
        KeyBtn.TextColor3 = T.accent2
    end
    SubLbl.Text = "Ocultar: " .. teclaOcultar.Name
end

KeyBtn = crearAccion(pAju, "Tecla para ocultar el menú", "Haz clic y presiona la nueva tecla (Esc cancela).", "[ RightShift ]", function()
    if escuchando then return end
    KeyBtn.Text = "Presiona una tecla..."
    KeyBtn.TextColor3 = Color3.fromRGB(255, 200, 80)
    escuchando = {
        cancelar = function(msg) refrescarKeyBtn(); if msg then notificar(msg) end end,
        asignar = function(k)
            if binds[k] then
                refrescarKeyBtn()
                notificar("Esa tecla ya es el atajo de " .. binds[k].titulo)
                return
            end
            teclaOcultar = k
            refrescarKeyBtn()
            notificar("Tecla para ocultar: " .. k.Name)
        end,
    }
end)
onTema(refrescarKeyBtn)

crearAccion(pAju, "Restablecer tecla de ocultar", "Vuelve a usar RightShift.", "Restablecer", function()
    escuchando = nil
    teclaOcultar = Enum.KeyCode.RightShift
    refrescarKeyBtn()
    notificar("Tecla para ocultar: RightShift")
end)

crearAccion(pAju, "Quitar todos los atajos", "Borra las teclas asignadas a las funciones.", "Quitar todos", function()
    for _, o in pairs(binds) do
        if o and o.quitar then o.quitar() end
    end
    binds = {}
    notificar("Atajos eliminados")
end)

crearSeccion(pAju, "Sonido")
crearToggle(pAju, "Sonidos de clic", "Suena al hacer clic en una opción.", function(v) sonidoOn = v end, {sinBind = true, inicial = true, color = C.cielo})
crearSlider(pAju, "Volumen", 0, 100, 50, 5, function(v) sonidoVol = v / 100 end, "%", C.menta)

crearSeccion(pAju, "Acerca de")
crearNota(pAju, "NAHUALHUB v2.3  •  Premium Edition\nEl botón flotante N abre o cierra el menú. Personaliza colores y tamaño en GENERAL > Apariencia.", 40)

-- ========== BUCLES ==========
onTema(estilizarTabs)

conns[#conns + 1] = RunService.Heartbeat:Connect(function()
    if hitboxEnabled then
        for _, p in ipairs(Players:GetPlayers()) do aplicarHitbox(p) end
    end
end)

conns[#conns + 1] = RunService.RenderStepped:Connect(function()
    pcall(pasoESP)
end)

conns[#conns + 1] = RunService.RenderStepped:Connect(function()
    if not flying then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    local cam = workspace.CurrentCamera
    if not (hrp and hum and cam) then return end

    hum.PlatformStand = true
    local look = cam.CFrame.LookVector
    local right = cam.CFrame.RightVector
    local mover = Vector3.new(0, 0, 0)
    local velocidad = Vector3.new(0, 0, 0)

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then mover = mover + look end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then mover = mover - look end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then mover = mover + right end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then mover = mover - right end
    if mover.Magnitude > 0 then velocidad = mover.Unit * speed end

    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        velocidad = velocidad + Vector3.new(0, speed, 0)
    elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        velocidad = velocidad - Vector3.new(0, speed, 0)
    end

    hrp.AssemblyLinearVelocity = velocidad
    hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + look)
end)

conns[#conns + 1] = LocalPlayer.CharacterAdded:Connect(function()
    flying = false
    flyObj.set(false, true)
    spectating = false
    SpecBtn.Text = "Observar"
    SpecBtn.BackgroundColor3 = T.panel2
end)

-- ========== CERRAR ==========
CloseBtn.MouseButton1Click:Connect(function()
    vivo = false
    flying = false
    espEnabled = false
    hitboxEnabled = false
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    limpiarESP()
    restaurarTodosHitbox()
    if spectating then dejarDeObservar() end
    detenerVuelo()
    pcall(function() RunService:UnbindFromRenderStep("NahualAim") end)
    AimGui:Destroy()
    EspGui:Destroy()
    ScreenGui:Destroy()
end)

-- ========== INTRO: LETRAS APARECIENDO + BARRA NEÓN ==========
local function desvanecer(root, t)
    local info = TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("TextLabel") then
            TweenService:Create(d, info, {TextTransparency = 1}):Play()
        elseif d:IsA("UIStroke") then
            TweenService:Create(d, info, {Transparency = 1}):Play()
        elseif d:IsA("Frame") then
            TweenService:Create(d, info, {BackgroundTransparency = 1}):Play()
        end
    end
    TweenService:Create(root, info, {BackgroundTransparency = 1}):Play()
end

local function correrIntro()
    local IntroGui = new("ScreenGui", {
        Name = "NahualIntro", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = guiParent,
    })
    local Root = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = IntroGui}, {
        new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(5, 5, 12), Color3.fromRGB(24, 12, 44)), Rotation = 90}),
    })

    local _, rainConn = crearLluvia(Root, 60, {minLen = 12, maxLen = 30, vmin = 500, vmax = 900, tmin = 0.7, tmax = 0.92, ancho = 1})

    -- Texto que se escribe letra por letra
    local texto = "NAHUALHUB"
    local ancho = 46
    local total = ancho * #texto
    local cont = new("Frame", {
        Size = UDim2.new(0, total, 0, 64), Position = UDim2.new(0.5, -total / 2, 0.5, -90),
        BackgroundTransparency = 1, Parent = Root,
    })
    local slots = {}
    for i = 1, #texto do
        local col = T.accent2:Lerp(T.accent, (i - 1) / (#texto - 1))
        local l = new("TextLabel", {
            Size = UDim2.new(0, ancho, 0, 64), Position = UDim2.new(0, (i - 1) * ancho, 0, 0), BackgroundTransparency = 1,
            Text = "", TextColor3 = col, Font = Enum.Font.GothamBlack, TextSize = 54, Parent = cont,
        })
        local s = Instance.new("UIStroke")
        s.Color = col
        s.Thickness = 2
        s.Transparency = 0.55
        s.Parent = l
        slots[i] = l
    end

    -- Cursor parpadeante
    local caret = new("Frame", {
        Size = UDim2.new(0, 4, 0, 50), Position = UDim2.new(0, 4, 0, 7), BackgroundColor3 = T.accent2,
        BorderSizePixel = 0, Parent = cont,
    }, {stroke(T.accent2, 2, 0.5)})
    local escribiendo = true
    task.spawn(function()
        while escribiendo and caret.Parent do
            caret.BackgroundTransparency = 0
            task.wait(0.25)
            caret.BackgroundTransparency = 1
            task.wait(0.2)
        end
    end)

    local simbolos = {"#", "$", "%", "&", "@", "!", "?", "/", "<", ">", "*", "+"}
    for i = 1, #texto do
        caret.Position = UDim2.new(0, (i - 1) * ancho + 6, 0, 7)
        for _ = 1, 3 do
            slots[i].Text = simbolos[math.random(#simbolos)]
            task.wait(0.04)
        end
        slots[i].Text = string.sub(texto, i, i)
        task.wait(0.09)
    end
    caret.Position = UDim2.new(0, total + 2, 0, 7)
    task.wait(0.35)
    escribiendo = false
    caret:Destroy()

    -- Subtítulo
    local sub = new("TextLabel", {
        Size = UDim2.new(0, 420, 0, 20), Position = UDim2.new(0.5, -210, 0.5, -14), BackgroundTransparency = 1,
        Text = "P R E M I U M    E D I T I O N", TextColor3 = T.sub, Font = Enum.Font.GothamMedium,
        TextSize = 12, TextTransparency = 1, Parent = Root,
    })
    tween(sub, 0.6, {TextTransparency = 0})

    -- Barra neón de carga
    local BW = 380
    local estado = new("TextLabel", {
        Size = UDim2.new(0, 260, 0, 16), Position = UDim2.new(0.5, -BW / 2, 0.5, 34), BackgroundTransparency = 1,
        Text = "Iniciando módulos...", TextColor3 = T.sub, Font = Enum.Font.Gotham, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = Root,
    })
    local pct = new("TextLabel", {
        Size = UDim2.new(0, 60, 0, 16), Position = UDim2.new(0.5, BW / 2 - 60, 0.5, 34), BackgroundTransparency = 1,
        Text = "0%", TextColor3 = T.accent2, Font = Enum.Font.GothamBold, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right, Parent = Root,
    })
    local barraFondo = new("Frame", {
        Size = UDim2.new(0, BW, 0, 8), Position = UDim2.new(0.5, -BW / 2, 0.5, 56), BackgroundColor3 = Color3.fromRGB(30, 28, 48),
        BorderSizePixel = 0, Parent = Root,
    }, {corner(4), stroke(Color3.fromRGB(70, 66, 110), 1, 0.4)})
    local halo = new("Frame", {
        Size = UDim2.new(0, 0, 0, 22), Position = UDim2.new(0, 0, 0.5, -11), BackgroundColor3 = T.accent2,
        BackgroundTransparency = 0.78, BorderSizePixel = 0, Parent = barraFondo,
    }, {corner(11)})
    local fill = new("Frame", {
        Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = barraFondo,
    }, {
        corner(4),
        new("UIGradient", {Color = ColorSequence.new(T.accent, T.accent2)}),
        stroke(T.accent2, 1.5, 0.3),
    })
    local punta = new("Frame", {
        Size = UDim2.new(0, 12, 0, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = barraFondo,
    }, {corner(6), stroke(T.accent2, 3, 0.35)})

    local pasos = {
        {0, "Iniciando módulos..."}, {22, "Cargando interfaz..."}, {50, "Preparando funciones..."},
        {75, "Aplicando tema..."}, {94, "Casi listo..."},
    }
    local dur = 2.6
    local t0 = tick()
    while true do
        local t = math.clamp((tick() - t0) / dur, 0, 1)
        local p = t * t * (3 - 2 * t)
        local px = math.floor(BW * p)
        fill.Size = UDim2.new(0, px, 1, 0)
        halo.Size = UDim2.new(0, px, 0, 22)
        punta.Position = UDim2.new(0, px, 0.5, 0)
        local num = math.floor(p * 100)
        pct.Text = num .. "%"
        for _, s in ipairs(pasos) do
            if num >= s[1] then estado.Text = s[2] end
        end
        if t >= 1 then break end
        RunService.RenderStepped:Wait()
    end
    estado.Text = "¡Listo!"
    estado.TextColor3 = T.verde
    task.wait(0.6)

    desvanecer(Root, 0.6)
    task.wait(0.7)
    pcall(function() rainConn:Disconnect() end)
    IntroGui:Destroy()
end

task.spawn(function()
    seleccionar("Vuelo")
    local ok, err = pcall(correrIntro)
    if not ok then
        warn("[NAHUALHUB] Error en la intro: " .. tostring(err))
        local g = guiParent:FindFirstChild("NahualIntro")
        if g then g:Destroy() end
    end
    if not vivo then return end
    introTerminada = true
    menuAbierto = true
    FloatBtn.Visible = true
    refrescarLista()
    mostrarMenu()
    notificar("Personaliza el menú en GENERAL > Apariencia")
end)
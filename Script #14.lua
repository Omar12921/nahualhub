-- NAHUALHUB v2.7 | Vuelo + ESP + Hitbox + Aim + Autoshot + Jugadores (TP) | Halloween | Marco RGB |
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
local escalaAuto = 100
local sonidoOn = true
local sonidoVol = 0.5
local reproducir = function(_) end   -- se define en SONIDOS

local cargando = false                -- true mientras se aplica una configuración
local idioma = "es"
local regToggles, regSliders, regSel = {}, {}, {}

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

-- Colores fijos solo para el círculo FOV del aim (no son parte del menú)
local C = {
    verde = Color3.fromRGB(90, 230, 120),
    morado = Color3.fromRGB(185, 100, 255),
}

local BLANCO = Color3.new(1, 1, 1)

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

-- corner = esquina plana (máx. 8) | bubble = burbuja real (solo botones de la izquierda)
local function corner(r) return new("UICorner", {CornerRadius = UDim.new(0, math.min(r, 8))}) end
local function bubble(r) return new("UICorner", {CornerRadius = UDim.new(0, r)}) end
local function redondo() return new("UICorner", {CornerRadius = UDim.new(1, 0)}) end

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

-- Reflejo de burbuja (línea de brillo arriba)
local function brillo(parent, transp, margen)
    margen = margen or 16
    return new("Frame", {
        Size = UDim2.new(1, -margen * 2, 0, 2), Position = UDim2.new(0, margen, 0, 3), BackgroundColor3 = BLANCO,
        BackgroundTransparency = transp or 0.85, BorderSizePixel = 0, Parent = parent,
    }, {corner(1)})
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
        Position = UDim2.new(0, rel, 0.5, 0), BackgroundColor3 = BLANCO,
        BackgroundTransparency = 0.8, BorderSizePixel = 0, Parent = visual,
    }, {redondo()})
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
            tween(st, 0.15, {Transparency = math.min(bt, 0.2), Color = op.glow or T.accent2})
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

-- Burbujitas que salen al activar una opción (desactivado)
local function burbujasPop(parent, x, y, color, n)
    do return end
    for _ = 1, n do
        local sz = math.random(5, 10)
        local b = new("Frame", {
            Size = UDim2.new(0, sz, 0, sz), Position = UDim2.new(0, x, 0, y), AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = color, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 6, Parent = parent,
        }, {redondo()})
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

-- ========== IDIOMA (Español / English) ==========
local Trad = {
    ["Tema"]="Theme", ["Buscar..."]="Search...", ["Buscar jugador..."]="Search player...",
    ["MOVIMIENTO"]="MOVEMENT", ["COMBATE"]="COMBAT", ["JUGADORES"]="PLAYERS",
    ["Vuelo"]="Fly", ["Jugadores"]="Players", ["Apariencia"]="Appearance", ["Ajustes"]="Settings",
    ["Velocidad de vuelo"]="Fly speed",
    ["Vuela hacia donde mira la cámara (WASD, Espacio, Ctrl)."]="Fly toward where the camera looks (WASD, Space, Ctrl).",
    ["Usa el cuadro junto al switch para asignar una tecla de atajo a cada opción."]="Use the box next to the switch to assign a hotkey to each option.",
    ["Hitbox expandido"]="Expanded hitbox", ["Agranda el HumanoidRootPart de los demás jugadores."]="Enlarges other players' HumanoidRootPart.",
    ["Tamaño del hitbox"]="Hitbox size", ["Ignorar mi equipo"]="Ignore my team",
    ["No modifica a los jugadores de tu equipo."]="Does not modify your teammates.",
    ["Es del lado del cliente: el efecto depende de cómo valide los golpes el servidor."]="Client-side only: the effect depends on how the server validates hits.",
    ["Apunta suavemente al jugador más cercano a tu mira."]="Smoothly aims at the player closest to your crosshair.",
    ["Modo de apuntado"]="Aim mode", ["Modo de aim"]="Aim mode",
    ["Mouse mueve el cursor; Primera persona mueve la cámara."]="Mouse moves the cursor; First person moves the camera.",
    ["Primera persona"]="First person", ["Modo automático"]="Auto mode",
    ["Elige el modo según tu cámara (cursor libre o primera persona)."]="Picks the mode based on your camera (free cursor or first person).",
    ["Activar con"]="Activate with", ["Qué mantener presionado para apuntar."]="What to hold to aim.",
    ["Clic der."]="R. click", ["Clic izq."]="L. click", ["Siempre"]="Always",
    ["Objetivo"]="Target", ["Parte objetivo"]="Target part", ["A qué parte del cuerpo apunta."]="Which body part it aims at.",
    ["Cabeza"]="Head", ["Cuerpo"]="Body", ["Radio del FOV"]="FOV radius",
    ["Suavidad (más alto = más lento)"]="Smoothness (higher = slower)", ["Filtros"]="Filters",
    ["Rango máximo (studs)"]="Max range (studs)", ["Rango máximo"]="Max range",
    ["Mostrar círculo FOV"]="Show FOV circle", ["Dibuja el área donde el aim busca objetivos."]="Draws the area where aim looks for targets.",
    ["No apunta a jugadores de tu equipo."]="Doesn't aim at your teammates.",
    ["No apuntar tras paredes"]="Don't aim through walls", ["Solo apunta a jugadores que puedes ver."]="Only aims at players you can see.",
    ["El círculo se pone verde cuando hay un objetivo fijado. En modo Mouse usa Clic izq., Shift o Siempre: con clic derecho Roblox bloquea el cursor. Mover el cursor requiere que tu executor tenga mousemoverel."]="The circle turns green when a target is locked. In Mouse mode use L. click, Shift or Always: Roblox locks the cursor with right click. Moving the cursor requires your executor to have mousemoverel.",
    ["Dispara solo al detectar un enemigo. No mueve el mouse ni la cámara."]="Fires only when an enemy is detected. Doesn't move the mouse or camera.",
    ["Radio de detección"]="Detection radius", ["Retardo entre disparos"]="Delay between shots",
    ["Método de disparo"]="Fire method", ["Click usa mouse1click; Activate usa Tool:Activate()."]="Click uses mouse1click; Activate uses Tool:Activate().",
    ["Bala directa"]="Direct bullet",
    ["Detectar en toda la pantalla"]="Detect on whole screen",
    ["Detecta enemigos en cualquier parte de la pantalla, no solo cerca del cursor."]="Detects enemies anywhere on screen, not just near the cursor.",
    ["Al disparar, la bala va directo al enemigo detectado (sin mover cámara ni mouse)."]="When firing, the bullet goes straight to the detected enemy (no camera or mouse movement).",
    ["Funciona solo con una herramienta (arma) equipada. Dispara cuando hay un enemigo dentro del radio alrededor de tu mira. Respeta los filtros de equipo y paredes de la pestaña Aim."]="Only works with a tool (weapon) equipped. Fires when an enemy is inside the radius around your crosshair. Respects the team and wall filters from the Aim tab.",
    ["Dispara solo cuando tu mira está sobre un enemigo."]="Fires only when your crosshair is over an enemy.",
    ["Solo con arma equipada"]="Only with weapon equipped", ["No dispara si no llevas una herramienta."]="Doesn't fire without a tool.",
    ["No dispara a jugadores de tu equipo."]="Doesn't fire at your teammates.",
    ["Retardo de reacción"]="Reaction delay", ["Intervalo entre disparos"]="Interval between shots",
    ["Usa el método de disparo elegido en Autoshot. Dispara hacia donde apunta el cursor (o el centro en primera persona)."]="Uses the fire method chosen in Autoshot. Fires where the cursor points (or the center in first person).",
    ["Activa el ESP con las opciones de abajo."]="Enables ESP with the options below.", ["Elementos"]="Elements",
    ["Caja alrededor del jugador."]="Box around the player.", ["Dibuja los huesos del personaje."]="Draws the character's bones.",
    ["Barra de vida"]="Health bar", ["Barra al costado con la salud."]="Side bar showing health.",
    ["Nombre"]="Name", ["Nombre sobre la caja."]="Name above the box.", ["Distancia"]="Distance",
    ["Distancia al jugador en studs."]="Distance to the player in studs.", ["Herramienta"]="Tool",
    ["Muestra qué lleva en la mano."]="Shows what they're holding.", ["Líneas (tracers)"]="Lines (tracers)",
    ["Línea desde abajo de la pantalla hasta el jugador."]="Line from the bottom of the screen to the player.",
    ["Resalta el cuerpo a través de las paredes."]="Highlights the body through walls.", ["Distancia máxima"]="Max distance",
    ["No dibuja a los jugadores de tu equipo."]="Doesn't draw your teammates.",
    ["Selecciona un jugador"]="Select a player", ["ID de usuario"]="User ID", ["Edad de cuenta"]="Account age",
    ["Equipo"]="Team", ["Vida"]="Health", ["Posición"]="Position", ["Velocidad"]="Speed",
    ["Sin equipo"]="No team", ["Ninguna"]="None",
    ["Teletransportar"]="Teleport", ["Observar"]="Spectate", ["Dejar de observar"]="Stop spectating",
    ["Temas"]="Themes", ["Temas predefinidos"]="Preset themes", ["Elige un estilo base y ajústalo debajo."]="Pick a base style and tweak it below.",
    ["Medianoche"]="Midnight", ["Calabaza"]="Pumpkin", ["Neón"]="Neon", ["Sangre"]="Blood", ["Océano"]="Ocean",
    ["Colores"]="Colors", ["Color principal - Rojo"]="Main color - Red", ["Color principal - Verde"]="Main color - Green",
    ["Color principal - Azul"]="Main color - Blue", ["Color secundario - Rojo"]="Secondary color - Red",
    ["Color secundario - Verde"]="Secondary color - Green", ["Color secundario - Azul"]="Secondary color - Blue",
    ["Ventana"]="Window", ["Transparencia de la ventana"]="Window transparency", ["Tamaño del menú"]="Menu size",
    ["Borde RGB animado"]="Animated RGB border", ["El borde de la ventana gira con colores RGB."]="The window border spins with RGB colors.",
    ["Decoración de Halloween"]="Halloween decoration", ["Luna, murciélagos, fantasmas, calabazas y una araña."]="Moon, bats, ghosts, pumpkins and a spider.",
    ["Imagen de fondo"]="Background image", ["Pega el ID de una imagen de Roblox y pulsa Aplicar."]="Paste a Roblox image ID and press Apply.",
    ["ID (solo números)"]="ID (numbers only)", ["Aplicar"]="Apply", ["Visibilidad de la imagen"]="Image visibility",
    ["Restablecer"]="Reset", ["Restablecer apariencia"]="Reset appearance",
    ["Vuelve al tema, tamaño y transparencia originales."]="Back to the original theme, size and transparency.",
    ["Atajos"]="Shortcuts", ["Tecla para ocultar el menú"]="Key to hide the menu",
    ["Haz clic y presiona la nueva tecla (Esc cancela)."]="Click and press the new key (Esc cancels).",
    ["Presiona una tecla..."]="Press a key...", ["Restablecer tecla de ocultar"]="Reset hide key",
    ["Vuelve a usar RightShift."]="Goes back to RightShift.", ["Quitar todos los atajos"]="Remove all shortcuts",
    ["Borra las teclas asignadas a las funciones."]="Clears the keys assigned to features.", ["Quitar todos"]="Remove all",
    ["Sonido"]="Sound", ["Sonidos de clic"]="Click sounds", ["Suena al hacer clic en una opción."]="Plays when you click an option.",
    ["Volumen"]="Volume", ["Acerca de"]="About",
    ["NAHUALHUB v2.7  •  Premium Edition\nEl botón flotante N abre o cierra el menú. Personaliza colores y tamaño en GENERAL > Apariencia."]="NAHUALHUB v2.7  •  Premium Edition\nThe floating N button opens or closes the menu. Customize colors and size in GENERAL > Appearance.",
    -- idioma y configuración
    ["Idioma"]="Language", ["Cambia el idioma del menú."]="Changes the menu language.",
    ["Configuración"]="Config", ["Nombre de la configuración"]="Config name",
    ["Escribe un nombre y pulsa Guardar."]="Type a name and press Save.", ["Nombre (ej. Mi config)"]="Name (e.g. My config)",
    ["Guardar configuración"]="Save config", ["Guarda todas tus opciones actuales con ese nombre."]="Saves all your current options under that name.",
    ["Guardar"]="Save", ["Configuraciones guardadas"]="Saved configs", ["Toca una para seleccionarla."]="Tap one to select it.",
    ["Cargar configuración"]="Load config", ["Aplica la configuración seleccionada (o el nombre escrito)."]="Applies the selected config (or the typed name).",
    ["Cargar"]="Load", ["Eliminar configuración"]="Delete config", ["Borra la configuración seleccionada."]="Deletes the selected config.",
    ["Eliminar"]="Delete",
    -- notificaciones
    ["Cambio cancelado"]="Change cancelled", ["Esa tecla se usa para volar, elige otra"]="That key is used for flying, pick another",
    ["Esa tecla oculta el menú, elige otra"]="That key hides the menu, pick another",
    ["Selecciona un jugador primero"]="Select a player first", ["El jugador no tiene personaje"]="The player has no character",
    ["Tu personaje no está listo"]="Your character isn't ready", ["Imagen de fondo quitada"]="Background image removed",
    ["Imagen aplicada (usa el ID de la imagen, no del decal)"]="Image applied (use the image ID, not the decal's)",
    ["Imagen aplicada"]="Image applied", ["Atajos eliminados"]="Shortcuts removed",
    ["Personaliza el menú en GENERAL > Apariencia"]="Customize the menu in GENERAL > Appearance",
    ["Tu executor no soporta mover el cursor, usando la cámara"]="Your executor can't move the cursor, using the camera",
    ["Escribe un nombre para la configuración"]="Type a name for the config",
    ["Elige o escribe una configuración"]="Pick or type a config", ["No se encontró la configuración"]="Config not found",
}
local TradUp = {}
for k, v in pairs(Trad) do TradUp[string.upper(k)] = string.upper(v) end

local prefijos = {
    {"Ocultar: ", "Hide: "}, {"Teletransportado a ", "Teleported to "}, {"Tema: ", "Theme: "},
    {"Atajo quitado: ", "Shortcut removed: "}, {"Tecla para ocultar: ", "Hide key: "},
    {"Esa tecla ya es el atajo de ", "That key is already the shortcut for "},
    {"Configuración guardada: ", "Config saved: "}, {"Configuración cargada: ", "Config loaded: "},
    {"Configuración eliminada: ", "Config deleted: "},
}
local function trad(s)
    local r = Trad[s] or TradUp[s]
    if r then return r end
    for _, p in ipairs(prefijos) do
        if string.sub(s, 1, #p[1]) == p[1] then return p[2] .. string.sub(s, #p[1] + 1) end
    end
    local a, b = string.match(s, "^(.-):  (O[NF]+)$")
    if a then return trad(a) .. ":  " .. b end
    a, b = string.match(s, "^(.-): atajo (.+)$")
    if a then return trad(a) .. ": shortcut " .. b end
    a = string.match(s, "^(%d+) días$")
    if a then return a .. " days" end
    return s
end

local origES, origPH = {}, {}
local function ponerTexto(o)
    if o:IsA("TextBox") then
        local ph = origPH[o]
        if not ph then ph = o.PlaceholderText; origPH[o] = ph end
        o.PlaceholderText = (idioma == "en") and trad(ph) or ph
    elseif o:IsA("TextLabel") or o:IsA("TextButton") then
        local es = origES[o]
        if not es then
            es = o.Text
            origES[o] = es
            o:GetPropertyChangedSignal("Text"):Connect(function()
                local esperado = (idioma == "en") and trad(origES[o]) or origES[o]
                if o.Text == esperado then return end   -- fue nuestro propio cambio
                origES[o] = o.Text
                if idioma == "en" then ponerTexto(o) end
            end)
        end
        o.Text = (idioma == "en") and trad(es) or es
    end
end
local function setIdioma(l)
    idioma = l
    for _, o in ipairs(ScreenGui:GetDescendants()) do ponerTexto(o) end
end
ScreenGui.DescendantAdded:Connect(ponerTexto)

-- Notificaciones
local function notificar(texto)
    local t = new("TextLabel", {
        Size = UDim2.new(0, 300, 0, 38), Position = UDim2.new(0.5, -150, 1, 10),
        Text = texto, Font = Enum.Font.GothamMedium, TextSize = 12, ZIndex = 20,
        __t = {BackgroundColor3 = "panel", TextColor3 = "texto"}, Parent = ScreenGui,
    }, {corner(19), stroke("accent", 1.3, 0.2)})
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
do
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
    if not sonidoOn or cargando then return end
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

end

-- ========== VENTANA PRINCIPAL ==========
local ANCHO, ALTO, HH, SIDE = 660, 420, 46, 180

local Main = new("Frame", {
    Size = UDim2.new(0, ANCHO, 0, ALTO), AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundColor3 = BLANCO,
    ClipsDescendants = true, Visible = false, Parent = ScreenGui,
}, {corner(18)})
grad(Main, "fondo", "fondo2", 90)
local MainScale = new("UIScale", {Scale = 1, Parent = Main})

-- Imagen de fondo opcional (vacía por defecto; se configura en Apariencia)
local FondoImg = new("ImageLabel", {
    Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Image = "", ImageTransparency = 0.6,
    ScaleType = Enum.ScaleType.Crop, Parent = Main,
}, {corner(18)})

-- Borde RGB con degradado giratorio
local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 2
MainStroke.Transparency = 0.1
MainStroke.Color = BLANCO
MainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
MainStroke.Parent = Main
local MainGrad = Instance.new("UIGradient")
MainGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
    ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
    ColorSequenceKeypoint.new(0.34, Color3.fromRGB(0, 255, 0)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
    ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
    ColorSequenceKeypoint.new(0.84, Color3.fromRGB(255, 0, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
})
MainGrad.Parent = MainStroke
conns[#conns + 1] = RunService.Heartbeat:Connect(function(dt)
    if bordeAnimado and Main.Visible then MainGrad.Rotation = (MainGrad.Rotation + 70 * dt) % 360 end
end)


-- Decoración de Halloween
local HLayer = new("Frame", {
    Size = UDim2.new(1, -SIDE, 1, -HH), Position = UDim2.new(0, SIDE, 0, HH), BackgroundTransparency = 1,
    ClipsDescendants = true, Parent = Main,
})
do
local lunaCol = Color3.fromRGB(255, 226, 150)
local Luna = new("Frame", {
    Size = UDim2.new(0, 120, 0, 120), Position = UDim2.new(1, -150, 0, -26), BackgroundColor3 = lunaCol,
    BackgroundTransparency = 0.88, BorderSizePixel = 0, Parent = HLayer,
}, {redondo(), stroke(lunaCol, 2, 0.8)})
for _, cr in ipairs({{0.25, 0.3, 22}, {0.58, 0.22, 14}, {0.5, 0.6, 26}, {0.2, 0.65, 12}}) do
    new("Frame", {
        Size = UDim2.new(0, cr[3], 0, cr[3]), Position = UDim2.new(cr[1], 0, cr[2], 0), BackgroundColor3 = lunaCol,
        BackgroundTransparency = 0.93, BorderSizePixel = 0, Parent = Luna,
    }, {redondo()})
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

end

-- ---------- Encabezado ----------
local Header = new("Frame", {Size = UDim2.new(1, 0, 0, HH), BackgroundTransparency = 1, Parent = Main})
new("Frame", {
    Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BorderSizePixel = 0,
    BackgroundTransparency = 0.75, __t = {BackgroundColor3 = "accent"}, Parent = Header,
})

do
local Logo = new("Frame", {Size = UDim2.new(0, 32, 0, 32), Position = UDim2.new(0, 12, 0.5, -16), BackgroundColor3 = BLANCO, Parent = Header}, {redondo()})
grad(Logo, "accent", "accent2", 45)
new("TextLabel", {
    Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "N", TextColor3 = BLANCO,
    Font = Enum.Font.GothamBlack, TextSize = 18, Parent = Logo,
})
new("TextLabel", {
    Size = UDim2.new(0, 100, 0, 20), Position = UDim2.new(0, 52, 0, 6), BackgroundTransparency = 1,
    Text = "NahualHub", Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left,
    __t = {TextColor3 = "texto"}, Parent = Header,
})
end

local SubLbl = new("TextLabel", {
    Size = UDim2.new(0, 120, 0, 14), Position = UDim2.new(0, 52, 0, 26), BackgroundTransparency = 1,
    Text = "Ocultar: RightShift", Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
    __t = {TextColor3 = "sub"}, Parent = Header,
})
do
local Badge = new("Frame", {Size = UDim2.new(0, 42, 0, 20), Position = UDim2.new(0, 150, 0.5, -10), __t = {BackgroundColor3 = "accent"}, Parent = Header}, {corner(10)})
new("TextLabel", {
    Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "v2.7", TextColor3 = BLANCO,
    Font = Enum.Font.GothamBold, TextSize = 11, Parent = Badge,
})

end

-- Píldora "online"
do
local Pill = new("Frame", {
    Size = UDim2.new(0, 112, 0, 26), Position = UDim2.new(0.5, -56, 0.5, -13), BackgroundTransparency = 0.1,
    __t = {BackgroundColor3 = "panel"}, Parent = Header,
}, {corner(13), stroke("accent", 1, 0.5)})
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

end

-- Botones de la derecha
local aplicarPreset
local temaIdx = 1
do
local TemaBtn = new("TextButton", {
    Size = UDim2.new(0, 74, 0, 26), Position = UDim2.new(1, -152, 0.5, -13), Text = "Tema",
    Font = Enum.Font.GothamMedium, TextSize = 12, AutoButtonColor = false,
    __t = {BackgroundColor3 = "panel2", TextColor3 = "texto"}, Parent = Header,
}, {corner(13), stroke("accent", 1, 0.5)})
efecto(TemaBtn, TemaBtn, {hover = 1.06, sinRipple = true})
TemaBtn.MouseButton1Click:Connect(function()
    temaIdx = temaIdx % #Temas + 1
    aplicarPreset(temaIdx)
end)

end

local MinBtn = new("TextButton", {
    Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(1, -68, 0.5, -13), Text = "-",
    Font = Enum.Font.GothamBold, TextSize = 16, AutoButtonColor = false,
    __t = {BackgroundColor3 = "panel2", TextColor3 = "texto"}, Parent = Header,
}, {corner(13), stroke("accent", 1, 0.5)})
local CloseBtn = new("TextButton", {
    Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(1, -36, 0.5, -13), BackgroundColor3 = T.rojo,
    Text = "X", TextColor3 = BLANCO, Font = Enum.Font.GothamBold, TextSize = 12,
    AutoButtonColor = false, Parent = Header,
}, {corner(13)})
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

-- Buscador
local Search = new("TextBox", {
    Size = UDim2.new(1, -20, 0, 32), Position = UDim2.new(0, 10, 0, 10), BackgroundTransparency = 0.15,
    Text = "", PlaceholderText = "Buscar...", ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    __t = {BackgroundColor3 = "panel", TextColor3 = "texto", PlaceholderColor3 = "sub"}, Parent = Sidebar,
}, {corner(8), new("UIPadding", {PaddingLeft = UDim.new(0, 14)})})
do
    local sStroke = stroke("accent", 1.4, 0.5)
    sStroke.Parent = Search
    Search.Focused:Connect(function() tween(sStroke, 0.2, {Transparency = 0, Color = T.accent2}) end)
    Search.FocusLost:Connect(function() tween(sStroke, 0.2, {Transparency = 0.5, Color = T.accent}) end)
end

local SideScroll = new("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, -52), Position = UDim2.new(0, 0, 0, 52), BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0),
    __t = {ScrollBarImageColor3 = "accent"}, Parent = Sidebar,
}, {
    new("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}),
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
    Size = UDim2.new(0, 38, 0, 38), Position = UDim2.new(0, 12, 0.5, -19), Text = "N", TextColor3 = BLANCO,
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
local catGrads = {}

-- Categoría: burbuja transparente con degradado animado en el borde, brillo y flecha en burbuja
local function getCat(nombre)
    if cats[nombre] then return cats[nombre] end
    catOrden = catOrden + 1

    new("Frame", {Size = UDim2.new(1, 0, 0, 4), BackgroundTransparency = 1, LayoutOrder = catOrden * 10 - 1, Parent = SideScroll})

    local header = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = BLANCO, BackgroundTransparency = 0.82, Text = "",
        AutoButtonColor = false, LayoutOrder = catOrden * 10, Parent = SideScroll,
    }, {bubble(19), stroke(BLANCO, 1.6, 0.2)})
    local g = Instance.new("UIGradient")
    g.Rotation = 0
    onTema(function()
        g.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, T.accent),
            ColorSequenceKeypoint.new(0.5, T.accent2),
            ColorSequenceKeypoint.new(1, T.accent),
        })
    end)
    g.Parent = header
    catGrads[#catGrads + 1] = g

    brillo(header, 0.88, 20)
    new("Frame", {
        Size = UDim2.new(0, 8, 0, 8), Position = UDim2.new(0, 14, 0, 9), BackgroundColor3 = BLANCO,
        BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = header,
    }, {redondo()})
    new("TextLabel", {
        Size = UDim2.new(1, -56, 1, 0), Position = UDim2.new(0, 18, 0, 1), BackgroundTransparency = 1,
        Text = string.upper(nombre), Font = Enum.Font.GothamBlack, TextSize = 12, TextColor3 = BLANCO,
        TextStrokeColor3 = Color3.new(0, 0, 0), TextStrokeTransparency = 0.75,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
    })
    local chevBg = new("Frame", {
        Size = UDim2.new(0, 22, 0, 22), Position = UDim2.new(1, -32, 0.5, -11), BackgroundColor3 = BLANCO,
        BackgroundTransparency = 0.85, BorderSizePixel = 0, Parent = header,
    }, {redondo(), stroke(BLANCO, 1, 0.4)})
    local chev = new("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "v", Font = Enum.Font.GothamBold,
        TextSize = 11, TextColor3 = BLANCO, Parent = chevBg,
    })
    efecto(header, header, {hover = 1.03, glow = BLANCO})

    local cont = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
        LayoutOrder = catOrden * 10 + 1, Parent = SideScroll,
    }, {
        new("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}),
        new("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 2), PaddingTop = UDim.new(0, 2)}),
    })
    local abierto = true
    header.MouseButton1Click:Connect(function()
        abierto = not abierto
        cont.Visible = abierto
        tween(chev, 0.2, {Rotation = abierto and 0 or -90})
    end)
    cats[nombre] = {header = header, cont = cont, paginas = {}}
    return cats[nombre]
end

-- el degradado de las categorías se mueve
conns[#conns + 1] = RunService.Heartbeat:Connect(function(dt)
    if not Main.Visible then return end
    for _, g in ipairs(catGrads) do g.Rotation = (g.Rotation + 35 * dt) % 360 end
end)

local activos = {}             -- pagina -> cantidad de opciones activadas

local function actualizarBadge(pagina)
    local o = tabObjs[pagina]
    if o and o.badge then
        local n = activos[pagina] or 0
        o.badge.Visible = n > 0
        o.badgeLbl.Text = tostring(n)
    end
end

-- Pestañas en burbuja transparente: activa = tinte del tema; inactiva = casi vacía con borde del tema
local function estilizarTabs()
    for n, o in pairs(tabObjs) do
        local a = (n == paginaActiva)
        tween(o.btn, 0.2, {
            BackgroundColor3 = a and T.accent or T.fondo, BackgroundTransparency = a and 0.55 or 0.9,
            TextColor3 = a and BLANCO or T.sub,
        })
        tween(o.st, 0.2, {Color = a and T.accent2 or T.accent, Transparency = a and 0 or 0.25})
        tween(o.gloss, 0.2, {BackgroundTransparency = a and 0.8 or 0.93})
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

local function crearTab(categoria, nombre, scroll, _color, conBadge)
    local c = getCat(categoria)
    table.insert(c.paginas, nombre)
    table.insert(ordenPaginas, nombre)
    paginaActual = nombre

    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = T.panel2, BackgroundTransparency = 0.9, Text = nombre,
        TextColor3 = T.sub, Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false, LayoutOrder = #ordenPaginas, Parent = c.cont,
    }, {bubble(18), new("UIPadding", {PaddingLeft = UDim.new(0, 18)})})
    local st = stroke(T.accent, 1.5, 0.25)
    st.Parent = btn
    local gloss = brillo(btn, 0.93, 16)

    -- Burbuja con la cantidad de opciones activas
    local badge, badgeLbl
    if conBadge then
        badge = new("Frame", {
            Size = UDim2.new(0, 22, 0, 22), Position = UDim2.new(1, -30, 0.5, -11), BackgroundColor3 = BLANCO,
            BackgroundTransparency = 0.1, BorderSizePixel = 0, Visible = false, Parent = btn,
        }, {redondo()})
        badgeLbl = new("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "0", TextColor3 = Color3.fromRGB(25, 15, 35),
            Font = Enum.Font.GothamBlack, TextSize = 11, Parent = badge,
        })
    end

    tabObjs[nombre] = {btn = btn, st = st, gloss = gloss, badge = badge, badgeLbl = badgeLbl}
    efecto(btn, btn, {hover = 1.03, sinGlow = true})

    local page
    if scroll then
        page = new("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
            AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0), Visible = false,
            __t = {ScrollBarImageColor3 = "accent"}, Parent = Content,
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

-- ========== COMPONENTES (tarjetas planas, con los colores del tema) ==========
local function crearSeccion(parent, texto)
    local l = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, TextYAlignment = Enum.TextYAlignment.Bottom,
        Text = string.upper(texto), Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        __t = {TextColor3 = "accent"}, Parent = parent,
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

-- Tarjeta plana: esquinas poco redondeadas y borde fino del tema
local function crearCard(parent, titulo, desc, alto)
    local tieneDesc = desc and desc ~= ""
    local card = new("Frame", {
        Size = UDim2.new(1, 0, 0, alto or 58), BackgroundTransparency = 0.1, __t = {BackgroundColor3 = "panel"}, Parent = parent,
    }, {corner(8)})
    local st = stroke("accent", 1, 0.75)
    st.Parent = card

    new("TextLabel", {
        Size = UDim2.new(1, -200, 0, 18), Position = UDim2.new(0, 14, 0, 9), BackgroundTransparency = 1, Text = titulo,
        Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, __t = {TextColor3 = "texto"}, Parent = card,
    })
    if tieneDesc then
        new("TextLabel", {
            Size = UDim2.new(1, -200, 0, 16), Position = UDim2.new(0, 14, 0, 30), BackgroundTransparency = 1, Text = desc,
            Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, __t = {TextColor3 = "sub"}, Parent = card,
        })
    end
    registrar(card, titulo, desc)
    return card
end

local function crearToggle(parent, titulo, desc, callback, op)
    op = op or {}
    local card = crearCard(parent, titulo, desc, 58)
    local pg = paginaActual
    local estado = false
    local obj = {titulo = titulo}
    regToggles[pg .. "/" .. titulo] = obj

    local sw = new("Frame", {Size = UDim2.new(0, 46, 0, 24), Position = UDim2.new(1, -60, 0.5, -12), BackgroundColor3 = T.off, Parent = card}, {redondo()})
    local glow = stroke("accent2", 1.5, 1)
    glow.Parent = sw
    local knob = new("Frame", {Size = UDim2.new(0, 18, 0, 18), Position = UDim2.new(0, 3, 0.5, -9), BackgroundColor3 = BLANCO, Parent = sw}, {redondo()})
    new("Frame", {
        Size = UDim2.new(0, 5, 0, 5), Position = UDim2.new(0.2, 0, 0.16, 0), BackgroundColor3 = Color3.fromRGB(200, 200, 215),
        BackgroundTransparency = 0.2, BorderSizePixel = 0, Parent = knob,
    }, {redondo()})
    local btn = new("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", Parent = card})

    local function set(v, silencioso)
        local antes = estado
        estado = v
        if antes ~= v then
            activos[pg] = (activos[pg] or 0) + (v and 1 or -1)
            actualizarBadge(pg)
        end
        tween(sw, 0.2, {BackgroundColor3 = v and T.accent or T.off})
        tween(glow, 0.2, {Transparency = v and 0.3 or 1})
        tweenEx(knob, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = v and UDim2.new(0, 25, 0.5, -9) or UDim2.new(0, 3, 0.5, -9),
        })
        if not silencioso then
            reproducir(v and "on" or "off")
            local sc = card:FindFirstChildOfClass("UIScale")
            if sc then
                sc.Scale = 1.04
                tweenEx(sc, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
            end
            local x = (sw.AbsolutePosition.X - card.AbsolutePosition.X + sw.AbsoluteSize.X / 2) / escalaUI
            burbujasPop(card, x, 29, v and T.accent or T.off, v and 9 or 4)
            callback(v)
        end
    end
    onTema(function() sw.BackgroundColor3 = estado and T.accent or T.off end)

    obj.set = set
    obj.get = function() return estado end
    obj.toggle = function()
        set(not estado)
        notificar(titulo .. (estado and ":  ON" or ":  OFF"))
    end
    btn.MouseButton1Click:Connect(function() set(not estado) end)
    efecto(btn, card, {hover = 1.01, sinSonido = true})

    -- Botón de atajo de teclado
    if not op.sinBind then
        local bb = new("TextButton", {
            Size = UDim2.new(0, 36, 0, 28), Position = UDim2.new(1, -106, 0.5, -14), BackgroundTransparency = 0.1,
            Text = "—", Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false, ZIndex = 3,
            __t = {BackgroundColor3 = "panel2"}, Parent = card,
        }, {corner(14), stroke("accent", 1, 0.65)})
        efecto(bb, bb, {hover = 1.08, sinRipple = true, sinGlow = true})
        local function etiqueta()
            bb.Text = obj.key and nombreTecla(obj.key) or "—"
            bb.TextColor3 = obj.key and T.accent or T.sub
        end
        onTema(etiqueta)
        obj.quitar = function()
            if obj.key then binds[obj.key] = nil end
            obj.key = nil
            etiqueta()
        end
        -- asigna (o quita, con nil) una tecla desde código (se usa al cargar configuraciones)
        obj.poner = function(k)
            obj.quitar()
            if k then
                if binds[k] and binds[k] ~= obj then binds[k].quitar() end
                obj.key = k
                binds[k] = obj
                etiqueta()
            end
        end
        bb.MouseButton1Click:Connect(function()
            if escuchando then return end
            bb.Text = "..."
            bb.TextColor3 = T.texto
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

local function crearSlider(parent, titulo, min, max, def, paso, callback, sufijo)
    local card = crearCard(parent, titulo, "", 62)
    efecto(card, card, {hover = 1.01, sinRipple = true})
    local valor = new("TextLabel", {
        Size = UDim2.new(0, 80, 0, 18), Position = UDim2.new(1, -94, 0, 9), BackgroundTransparency = 1, Text = "",
        Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right,
        __t = {TextColor3 = "accent"}, Parent = card,
    })
    local hit = new("Frame", {Size = UDim2.new(1, -44, 0, 22), Position = UDim2.new(0, 22, 0, 33), BackgroundTransparency = 1, Parent = card})
    local track = new("Frame", {Size = UDim2.new(1, 0, 0, 10), Position = UDim2.new(0, 0, 0.5, -5), __t = {BackgroundColor3 = "off"}, Parent = hit}, {redondo()})
    local fill = new("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = BLANCO, Parent = track}, {redondo()})
    local fillG = Instance.new("UIGradient")
    onTema(function() fillG.Color = ColorSequence.new(T.accent, T.accent2) end)
    fillG.Parent = fill
    local knob = new("Frame", {
        Size = UDim2.new(0, 18, 0, 18), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = BLANCO, ZIndex = 3, Parent = track,
    }, {redondo(), stroke("accent", 2.5, 0.1)})

    local actual = def
    local function set(v, silencioso)
        v = math.clamp(v, min, max)
        actual = v
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
            tweenEx(knob, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 23, 0, 23)})
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
            tween(knob, 0.15, {Size = UDim2.new(0, 18, 0, 18)})
        end
    end)
    set(def)
    regSliders[paginaActual .. "/" .. titulo] = {set = set, get = function() return actual end}
    return set
end

local function crearAccion(parent, titulo, desc, textoBtn, callback)
    local card = crearCard(parent, titulo, desc, 58)
    local b = new("TextButton", {
        Size = UDim2.new(0, 124, 0, 30), Position = UDim2.new(1, -138, 0.5, -15), Text = textoBtn,
        Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false,
        __t = {BackgroundColor3 = "panel2", TextColor3 = "accent"}, Parent = card,
    }, {corner(8), stroke("accent", 1.2, 0.5)})
    efecto(b, b, {hover = 1.05, sinGlow = true})
    b.MouseButton1Click:Connect(callback)
    return b
end

-- Selector de varias opciones
local function crearSelector(parent, titulo, desc, opciones, def, callback)
    local card = crearCard(parent, titulo, desc, 90)
    local fila = new("Frame", {Size = UDim2.new(1, -28, 0, 30), Position = UDim2.new(0, 14, 0, 52), BackgroundTransparency = 1, Parent = card}, {
        new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}),
    })
    local n = #opciones
    local botones = {}
    local sel = def
    local function pintar()
        for i, b in ipairs(botones) do
            local a = (i == sel)
            tween(b, 0.2, {BackgroundColor3 = a and T.accent or T.panel2, TextColor3 = a and BLANCO or T.sub})
        end
    end
    for i, nombre in ipairs(opciones) do
        local b = new("TextButton", {
            Size = UDim2.new(1 / n, -(6 * (n - 1)) / n, 1, 0), BackgroundColor3 = T.panel2, Text = nombre,
            TextColor3 = T.sub, Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false, LayoutOrder = i, Parent = fila,
        }, {corner(8), stroke("accent", 1, 0.65)})
        efecto(b, b, {hover = 1.04, sinGlow = true})
        b.MouseButton1Click:Connect(function()
            sel = i
            pintar()
            callback(nombre, i)
        end)
        botones[i] = b
    end
    onTema(pintar)
    regSel[paginaActual .. "/" .. titulo] = {
        get = function() return sel end,
        set = function(i) sel = i; pintar(); callback(opciones[i], i) end,
    }
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

local EspGui, quitarEspJugador, limpiarESP, pasoESP
do
EspGui = new("ScreenGui", {
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
        AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = BLANCO, BorderSizePixel = 0,
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
    o.boxStroke = stroke(BLANCO, 1.5, 0)
    o.boxStroke.Parent = o.box
    o.hpBg = new("Frame", {BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, Visible = false, Parent = folder})
    o.hpFill = new("Frame", {
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(90, 230, 120), BorderSizePixel = 0, Parent = o.hpBg,
    })
    o.name = new("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(0, 160, 0, 14), BackgroundTransparency = 1,
        TextColor3 = BLANCO, Font = Enum.Font.GothamBold, TextSize = 12, TextStrokeTransparency = 0.4,
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

quitarEspJugador = function(p)
    if espObjs[p] then espObjs[p].folder:Destroy(); espObjs[p] = nil end
end

limpiarESP = function()
    for _, hl in pairs(espCache) do
        if hl then hl:Destroy() end
    end
    espCache = {}
    for _, o in pairs(espObjs) do o.folder:Destroy() end
    espObjs = {}
end

pasoESP = function()
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
                                    setLinea(b, Vector2.new(va.X, va.Y), Vector2.new(vb.X, vb.Y), 1.5, BLANCO)
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

end

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

local AimGui, flyObj
do
-- ========== LÓGICA: AIM ASSIST ==========
local aimEnabled = false
local aimActIdx = 1          -- 1 clic der., 2 clic izq., 3 Shift, 4 siempre
local aimModo = 2             -- 1 = Mouse (mueve el cursor), 2 = Primera persona (mueve la cámara)
local aimAuto = false         -- elegir el modo según la cámara
local aimAcumX, aimAcumY = 0, 0
local avisoMmr = false
local aimFOV = 120
local aimRango = 300          -- distancia máxima (studs) a la que el aim busca objetivos
local aimSmooth = 8
local aimPartIdx = 1
local aimTeam = true
local aimWall = true
local aimShowFOV = false
local aimTarget = nil

AimGui = new("ScreenGui", {
    Name = "NahualAimFOV", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 50,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = guiParent,
})
local FovCircle = new("Frame", {
    Size = UDim2.new(0, aimFOV * 2, 0, aimFOV * 2), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.morado, BackgroundTransparency = 0.93,
    Visible = false, Parent = AimGui,
}, {redondo()})
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

local function mejorObjetivo(cam, mouse, fovMax, rangoMax)
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
                    if enPantalla and (parte.Position - cam.CFrame.Position).Magnitude <= (rangoMax or aimRango) then
                        local d = (Vector2.new(v.X, v.Y) - mouse).Magnitude
                        if d <= (fovMax or aimFOV) and (not mejorDist or d < mejorDist) then
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

-- ---------- Disparo ----------
local asEnabled, asFOV, asDelay = false, 250, 120
local trigEnabled, trigDelay, trigInterval, trigSoloArma, trigTeam = false, 60, 150, true, true
local disparoMetodo = 1       -- 1 = Click (mouse1click), 2 = Tool:Activate()
local ultimoDisparo = 0
local trigDesde = nil

-- ---------- Bala directa (Autoshot) ----------
-- Durante un instante tras cada disparo del Autoshot, el juego "ve" al enemigo detectado como destino
-- (Mouse.Hit / Mouse.Target / Raycast / FindPartOnRay). No mueve la cámara ni el mouse.
local asRango, asDirecto, asPantalla = 500, true, true
local silentObj, silentHasta = nil, 0
local function silentActivo()
    return silentObj ~= nil and silentObj.Parent ~= nil and tick() < silentHasta
end

pcall(function()
    if not (hookmetamethod and getnamecallmethod and checkcaller) then return end
    local nc = newcclosure or function(f) return f end
    local mouse = LocalPlayer:GetMouse()
    local inset = Vector2.new(0, 36)
    pcall(function() inset = game:GetService("GuiService"):GetGuiInset() end)

    -- Posición del objetivo en pantalla, con matemática pura (sin llamar métodos dentro del hook)
    -- devuelve: cámara, coords de viewport (GetMouseLocation / ViewportPointToRay), coords de pantalla (Mouse.X/Y / ScreenPointToRay)
    local function posObjetivo()
        local cam = workspace.CurrentCamera
        if not (cam and silentObj) then return nil end
        local rel = cam.CFrame:PointToObjectSpace(silentObj.Position)
        if rel.Z >= -0.01 then return nil end
        local vp = cam.ViewportSize
        local k = vp.Y / (2 * math.tan(math.rad(cam.FieldOfView) / 2))
        local v = Vector2.new(vp.X / 2 + (rel.X / -rel.Z) * k, vp.Y / 2 - (rel.Y / -rel.Z) * k)
        return cam, v, v - inset
    end

    local oldIndex, oldNC
    oldIndex = hookmetamethod(game, "__index", nc(function(self, key)
        if vivo and self == mouse and silentActivo() and not checkcaller() then
            if key == "Hit" then return CFrame.new(silentObj.Position)
            elseif key == "Target" then return silentObj
            elseif key == "X" or key == "Y" or key == "UnitRay" then
                local cam, _, s = posObjetivo()
                if cam then
                    if key == "X" then return math.floor(s.X) end
                    if key == "Y" then return math.floor(s.Y) end
                    local origen = cam.CFrame.Position
                    return Ray.new(origen, (silentObj.Position - origen).Unit)
                end
            end
        end
        return oldIndex(self, key)
    end))

    oldNC = hookmetamethod(game, "__namecall", nc(function(self, ...)
        if vivo and silentActivo() and not checkcaller() then
            local m = getnamecallmethod()
            if self == workspace then
                local n = select("#", ...)
                local a = {...}
                if m == "Raycast" and typeof(a[1]) == "Vector3" and typeof(a[2]) == "Vector3" then
                    local dir = silentObj.Position - a[1]
                    a[2] = dir.Unit * math.max(a[2].Magnitude, dir.Magnitude + 5)
                    return oldNC(self, table.unpack(a, 1, n))
                elseif (m == "FindPartOnRay" or m == "FindPartOnRayWithIgnoreList" or m == "FindPartOnRayWithWhitelist")
                    and typeof(a[1]) == "Ray" then
                    local r = a[1]
                    local dir = silentObj.Position - r.Origin
                    a[1] = Ray.new(r.Origin, dir.Unit * math.max(r.Direction.Magnitude, dir.Magnitude + 5))
                    return oldNC(self, table.unpack(a, 1, n))
                end
            elseif self == UserInputService and m == "GetMouseLocation" then
                local cam, v = posObjetivo()
                if cam then return v end
            elseif m == "ViewportPointToRay" or m == "ScreenPointToRay" then
                if self == workspace.CurrentCamera then
                    local cam, v, s = posObjetivo()
                    if cam then
                        local n = select("#", ...)
                        local a = {...}
                        local pt = (m == "ViewportPointToRay") and v or s
                        a[1], a[2] = pt.X, pt.Y
                        return oldNC(self, table.unpack(a, 1, n))
                    end
                end
            end
        end
        return oldNC(self, ...)
    end))
end)

local function armaEquipada()
    local ch = LocalPlayer.Character
    return ch ~= nil and ch:FindFirstChildOfClass("Tool") ~= nil
end

-- Evita disparar un clic encima del propio menú
local function cursorSobreMenu()
    if not Main.Visible then return false end
    local m = UserInputService:GetMouseLocation()
    local pos, size = Main.AbsolutePosition, Main.AbsoluteSize
    return m.X >= pos.X and m.X <= pos.X + size.X and m.Y >= pos.Y and m.Y <= pos.Y + size.Y
end

local function dispararArma()
    if cursorSobreMenu() then return false end
    if disparoMetodo == 1 then
        local f = mouse1click or (getgenv and getgenv().mouse1click)
        if type(f) == "function" then
            pcall(f)
            return true
        end
    end
    local ch = LocalPlayer.Character
    local tool = ch and ch:FindFirstChildOfClass("Tool")
    if tool then
        pcall(function() tool:Activate() end)
        return true
    end
    return false
end

-- ---------- Aim (con Autoshot) ----------
local function pasoAim(dt)
    local cam = workspace.CurrentCamera
    local mouse = UserInputService:GetMouseLocation()
    if not cam or not aimEnabled then aimTarget = nil return end
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

    local suav = aimSmooth
    local alpha = suav <= 1 and 1 or (1 - (1 - 1 / suav) ^ (dt * 60))
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

-- ---------- Autoshot: NO apunta ni mueve nada, solo dispara al detectar un enemigo ----------
local function pasoAutoshot()
    if not asEnabled or not armaEquipada() then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local m = UserInputService:GetMouseLocation()
    local objetivo = mejorObjetivo(cam, m, asPantalla and math.huge or asFOV, asRango)
    if objetivo and tick() - ultimoDisparo >= asDelay / 1000 then
        ultimoDisparo = tick()
        if asDirecto then
            silentObj = objetivo
            silentHasta = tick() + 0.3    -- solo redirige durante este disparo
        end
        dispararArma()
    end
end
conns[#conns + 1] = RunService.RenderStepped:Connect(function() pcall(pasoAutoshot) end)

-- ---------- Triggerbot ----------
local function pasoTrigger()
    if not trigEnabled then trigDesde = nil return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    if trigSoloArma and not armaEquipada() then trigDesde = nil return end

    local m = UserInputService:GetMouseLocation()
    local rayo = cam:ViewportPointToRay(m.X, m.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ch = LocalPlayer.Character
    params.FilterDescendantsInstances = ch and {ch} or {}
    local r = workspace:Raycast(rayo.Origin, rayo.Direction * 2000, params)

    local objetivo = false
    if r then
        local modelo = r.Instance:FindFirstAncestorOfClass("Model")
        local pl = modelo and Players:GetPlayerFromCharacter(modelo)
        local hum = modelo and modelo:FindFirstChildOfClass("Humanoid")
        if pl and pl ~= LocalPlayer and hum and hum.Health > 0 and not (trigTeam and pl.Team and pl.Team == LocalPlayer.Team) then
            objetivo = true
        end
    end
    if not objetivo then trigDesde = nil return end

    local t = tick()
    trigDesde = trigDesde or t
    if t - trigDesde >= trigDelay / 1000 and t - ultimoDisparo >= trigInterval / 1000 then
        ultimoDisparo = t
        dispararArma()
    end
end
conns[#conns + 1] = RunService.RenderStepped:Connect(function() pcall(pasoTrigger) end)

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
local pMov = crearTab("MOVIMIENTO", "Vuelo", true, nil, true)
crearSeccion(pMov, "Vuelo")
flyObj = crearToggle(pMov, "Vuelo", "Vuela hacia donde mira la cámara (WASD, Espacio, Ctrl).", function(v)
    flying = v
    if not v then detenerVuelo() end
end)
crearSlider(pMov, "Velocidad de vuelo", 10, 200, speed, 5, function(v) speed = v end)
crearNota(pMov, "Usa el cuadro junto al switch para asignar una tecla de atajo a cada opción.")

-- ========== PÁGINA: HITBOX ==========
local pCom = crearTab("COMBATE", "Hitbox", true, nil, true)
crearSeccion(pCom, "Hitbox")
crearToggle(pCom, "Hitbox expandido", "Agranda el HumanoidRootPart de los demás jugadores.", function(v)
    hitboxEnabled = v
    if not v then restaurarTodosHitbox() end
end)
crearSlider(pCom, "Tamaño del hitbox", 2, 50, hitboxSize, 2, function(v) hitboxSize = v end)
crearToggle(pCom, "Ignorar mi equipo", "No modifica a los jugadores de tu equipo.", function(v) ignorarEquipo = v end, {sinBind = true})
crearNota(pCom, "Es del lado del cliente: el efecto depende de cómo valide los golpes el servidor.")

-- ========== PÁGINA: AIM ==========
local pAim = crearTab("COMBATE", "Aim", true, nil, true)
crearSeccion(pAim, "Aim Assist")
crearToggle(pAim, "Aim Assist", "Apunta suavemente al jugador más cercano a tu mira.", function(v)
    aimEnabled = v
    if not v then aimTarget = nil end
end)
crearSeccion(pAim, "Modo de apuntado")
crearSelector(pAim, "Modo de aim", "Mouse mueve el cursor; Primera persona mueve la cámara.", {"Mouse", "Primera persona"}, 2, function(_, i) aimModo = i end)
crearToggle(pAim, "Modo automático", "Elige el modo según tu cámara (cursor libre o primera persona).", function(v) aimAuto = v end, {sinBind = true})
crearSelector(pAim, "Activar con", "Qué mantener presionado para apuntar.", {"Clic der.", "Clic izq.", "Shift", "Siempre"}, 1, function(_, i) aimActIdx = i end)
crearSeccion(pAim, "Objetivo")
crearSelector(pAim, "Parte objetivo", "A qué parte del cuerpo apunta.", {"Cabeza", "Torso", "Cuerpo"}, 1, function(_, i) aimPartIdx = i end)
crearSlider(pAim, "Radio del FOV", 40, 400, aimFOV, 10, function(v)
    aimFOV = v
    FovCircle.Size = UDim2.new(0, v * 2, 0, v * 2)
end, " px")
crearSlider(pAim, "Rango máximo (studs)", 20, 1000, aimRango, 10, function(v) aimRango = v end, " studs")
crearSlider(pAim, "Suavidad (más alto = más lento)", 1, 30, aimSmooth, 1, function(v) aimSmooth = v end)
crearSeccion(pAim, "Filtros")
crearToggle(pAim, "Mostrar círculo FOV", "Dibuja el área donde el aim busca objetivos.", function(v) aimShowFOV = v; FovCircle.Visible = v end, {sinBind = true})
crearToggle(pAim, "Ignorar mi equipo", "No apunta a jugadores de tu equipo.", function(v) aimTeam = v end, {sinBind = true, inicial = true})
crearToggle(pAim, "No apuntar tras paredes", "Solo apunta a jugadores que puedes ver.", function(v) aimWall = v end, {sinBind = true, inicial = true})
crearNota(pAim, "El círculo se pone verde cuando hay un objetivo fijado. En modo Mouse usa Clic izq., Shift o Siempre: con clic derecho Roblox bloquea el cursor. Mover el cursor requiere que tu executor tenga mousemoverel.", 58)

-- ========== PÁGINA: AUTOSHOT ==========
local pAS = crearTab("COMBATE", "Autoshot", true, nil, true)
crearSeccion(pAS, "Autoshot")
crearToggle(pAS, "Autoshot", "Dispara solo al detectar un enemigo. No mueve el mouse ni la cámara.", function(v) asEnabled = v end)
crearSeccion(pAS, "Ajustes")
crearSlider(pAS, "Radio de detección", 50, 600, asFOV, 10, function(v) asFOV = v end, " px")
crearSlider(pAS, "Retardo entre disparos", 50, 1000, asDelay, 10, function(v) asDelay = v end, " ms")
crearSelector(pAS, "Método de disparo", "Click usa mouse1click; Activate usa Tool:Activate().", {"Click", "Activate"}, 1, function(_, i) disparoMetodo = i end)
crearToggle(pAS, "Bala directa", "Al disparar, la bala va directo al enemigo detectado (sin mover cámara ni mouse).", function(v) asDirecto = v end, {sinBind = true, inicial = true})
crearToggle(pAS, "Detectar en toda la pantalla", "Detecta enemigos en cualquier parte de la pantalla, no solo cerca del cursor.", function(v) asPantalla = v end, {sinBind = true, inicial = true})
crearSlider(pAS, "Rango máximo", 20, 1000, asRango, 10, function(v) asRango = v end, " studs")
crearNota(pAS, "Funciona solo con una herramienta (arma) equipada. Dispara cuando hay un enemigo dentro del radio alrededor de tu mira. Respeta los filtros de equipo y paredes de la pestaña Aim.", 46)

-- ========== PÁGINA: TRIGGERBOT ==========
local pTB = crearTab("COMBATE", "Triggerbot", true, nil, true)
crearSeccion(pTB, "Triggerbot")
crearToggle(pTB, "Triggerbot", "Dispara solo cuando tu mira está sobre un enemigo.", function(v)
    trigEnabled = v
    if not v then trigDesde = nil end
end)
crearToggle(pTB, "Solo con arma equipada", "No dispara si no llevas una herramienta.", function(v) trigSoloArma = v end, {sinBind = true, inicial = true})
crearToggle(pTB, "Ignorar mi equipo", "No dispara a jugadores de tu equipo.", function(v) trigTeam = v end, {sinBind = true, inicial = true})
crearSeccion(pTB, "Ajustes")
crearSlider(pTB, "Retardo de reacción", 0, 500, trigDelay, 10, function(v) trigDelay = v end, " ms")
crearSlider(pTB, "Intervalo entre disparos", 50, 1000, trigInterval, 10, function(v) trigInterval = v end, " ms")
crearNota(pTB, "Usa el método de disparo elegido en Autoshot. Dispara hacia donde apunta el cursor (o el centro en primera persona).", 46)

end

-- ========== PÁGINA: ESP ==========
local pVis = crearTab("VISUAL", "ESP", true, nil, true)
crearSeccion(pVis, "ESP")
crearToggle(pVis, "ESP", "Activa el ESP con las opciones de abajo.", function(v)
    espEnabled = v
    if not v then limpiarESP() end
end)
crearSeccion(pVis, "Elementos")
crearToggle(pVis, "Box", "Caja alrededor del jugador.", function(v) espOpt.box = v end, {sinBind = true, inicial = true})
crearToggle(pVis, "Skeleton", "Dibuja los huesos del personaje.", function(v) espOpt.skel = v end, {sinBind = true, inicial = true})
crearToggle(pVis, "Barra de vida", "Barra al costado con la salud.", function(v) espOpt.hp = v end, {sinBind = true, inicial = true})
crearToggle(pVis, "Nombre", "Nombre sobre la caja.", function(v) espOpt.name = v end, {sinBind = true, inicial = true})
crearToggle(pVis, "Distancia", "Distancia al jugador en studs.", function(v) espOpt.dist = v end, {sinBind = true, inicial = true})
crearToggle(pVis, "Herramienta", "Muestra qué lleva en la mano.", function(v) espOpt.tool = v end, {sinBind = true})
crearToggle(pVis, "Líneas (tracers)", "Línea desde abajo de la pantalla hasta el jugador.", function(v) espOpt.tracer = v end, {sinBind = true})
crearToggle(pVis, "Chams", "Resalta el cuerpo a través de las paredes.", function(v) espOpt.chams = v end, {sinBind = true})
crearSeccion(pVis, "Filtros")
crearSlider(pVis, "Distancia máxima", 100, 5000, espMaxDist, 100, function(v) espMaxDist = v end, " m")
crearToggle(pVis, "Ignorar mi equipo", "No dibuja a los jugadores de tu equipo.", function(v) espIgnoreTeam = v end, {sinBind = true})

local SpecBtn, dejarDeObservar, refrescarLista
do
-- ========== PÁGINA: JUGADORES ==========
local pJug = crearTab("JUGADORES", "Jugadores", false, nil)
feats[#feats + 1] = {texto = "jugadores teletransportar tp observar spectate lista informacion", page = "Jugadores"}

local Left = new("Frame", {Size = UDim2.new(0.4, 0, 1, 0), BackgroundTransparency = 1, Parent = pJug})
local PSearch = new("TextBox", {
    Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 0.15, Text = "", PlaceholderText = "Buscar jugador...",
    Font = Enum.Font.Gotham, TextSize = 12, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
    __t = {BackgroundColor3 = "panel", TextColor3 = "texto", PlaceholderColor3 = "sub"}, Parent = Left,
}, {corner(8), new("UIPadding", {PaddingLeft = UDim.new(0, 14)}), stroke("accent", 1.4, 0.5)})

local List = new("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, -38), Position = UDim2.new(0, 0, 0, 38), BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0),
    __t = {ScrollBarImageColor3 = "accent"}, Parent = Left,
}, {new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.Name})})

local Right = new("Frame", {
    Size = UDim2.new(0.6, -10, 1, 0), Position = UDim2.new(0.4, 10, 0, 0), BackgroundTransparency = 0.15,
    __t = {BackgroundColor3 = "panel"}, Parent = pJug,
}, {corner(8), stroke("accent", 1, 0.6)})

local Avatar = new("ImageLabel", {
    Size = UDim2.new(0, 56, 0, 56), Position = UDim2.new(0, 12, 0, 12), Image = "",
    __t = {BackgroundColor3 = "panel2"}, Parent = Right,
}, {corner(28), stroke("accent", 1.5, 0.2)})

local NombreLbl = new("TextLabel", {
    Size = UDim2.new(1, -86, 0, 22), Position = UDim2.new(0, 78, 0, 16), BackgroundTransparency = 1,
    Text = "Selecciona un jugador", Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd, __t = {TextColor3 = "texto"}, Parent = Right,
})
local DisplayLbl = new("TextLabel", {
    Size = UDim2.new(1, -86, 0, 18), Position = UDim2.new(0, 78, 0, 38), BackgroundTransparency = 1, Text = "",
    Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd, __t = {TextColor3 = "sub"}, Parent = Right,
})

local infoLabels = {}
local campos = {"ID de usuario", "Edad de cuenta", "Equipo", "Vida", "Distancia", "Posición", "Herramienta", "Velocidad"}
for i, nombre in ipairs(campos) do
    local y = 80 + (i - 1) * 22
    new("TextLabel", {
        Size = UDim2.new(0.4, 0, 0, 18), Position = UDim2.new(0, 14, 0, y), BackgroundTransparency = 1, Text = nombre,
        Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        __t = {TextColor3 = "sub"}, Parent = Right,
    })
    infoLabels[nombre] = new("TextLabel", {
        Size = UDim2.new(0.6, -22, 0, 18), Position = UDim2.new(0.4, 6, 0, y), BackgroundTransparency = 1, Text = "-",
        Font = Enum.Font.GothamMedium, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, __t = {TextColor3 = "texto"}, Parent = Right,
    })
end

local TPBtn = new("TextButton", {
    Size = UDim2.new(0.5, -15, 0, 34), Position = UDim2.new(0, 10, 1, -44), Text = "Teletransportar",
    TextColor3 = BLANCO, Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false,
    __t = {BackgroundColor3 = "accent"}, Parent = Right,
}, {corner(8), stroke(BLANCO, 1.2, 0.6)})
SpecBtn = new("TextButton", {
    Size = UDim2.new(0.5, -15, 0, 34), Position = UDim2.new(0.5, 5, 1, -44), Text = "Observar",
    Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false,
    __t = {BackgroundColor3 = "panel2", TextColor3 = "texto"}, Parent = Right,
}, {corner(8), stroke("accent", 1.2, 0.5)})
efecto(TPBtn, TPBtn, {hover = 1.04, sinGlow = true})
efecto(SpecBtn, SpecBtn, {hover = 1.04, sinGlow = true})

dejarDeObservar = function()
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

refrescarLista = function()
    for _, c in ipairs(List:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local filtro = string.lower(PSearch.Text)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local coincide = filtro == "" or string.find(string.lower(p.Name), filtro, 1, true) or string.find(string.lower(p.DisplayName), filtro, 1, true)
            if coincide then
                local b = new("TextButton", {
                    Name = p.Name, Size = UDim2.new(1, -4, 0, 36), BackgroundColor3 = (selected == p) and T.accent or T.panel,
                    BackgroundTransparency = 0.15, Text = "", AutoButtonColor = false, Parent = List,
                }, {corner(8), stroke("accent", 1.2, 0.55)})
                new("ImageLabel", {
                    Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(0, 6, 0.5, -13), BackgroundColor3 = T.panel2,
                    Image = "rbxthumb://type=AvatarHeadShot&id=" .. p.UserId .. "&w=48&h=48", Parent = b,
                }, {corner(13)})
                new("TextLabel", {
                    Size = UDim2.new(1, -44, 1, 0), Position = UDim2.new(0, 38, 0, 0), BackgroundTransparency = 1,
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
    quitarEspJugador(p)
    hitboxOriginal[p] = nil
    if selected == p then
        if spectating then dejarDeObservar() end
        selected = nil
        limpiarInfo()
    end
    task.defer(refrescarLista)
end)

end

local setEscala
do
-- ========== PÁGINA: APARIENCIA (personalizar el GUI) ==========
local pApa = crearTab("GENERAL", "Apariencia", true, nil)
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
            Size = UDim2.new(0, 78, 0, 28), Position = UDim2.new(0, 14 + (i - 1) * 82, 0, 56), BackgroundColor3 = BLANCO,
            Text = tm.n, TextColor3 = BLANCO, Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false,
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
ss.pr = crearSlider(pApa, "Color principal - Rojo", 0, 255, cv.pr, 1, function(v) cv.pr = v; actualizarColores() end)
ss.pg = crearSlider(pApa, "Color principal - Verde", 0, 255, cv.pg, 1, function(v) cv.pg = v; actualizarColores() end)
ss.pb = crearSlider(pApa, "Color principal - Azul", 0, 255, cv.pb, 1, function(v) cv.pb = v; actualizarColores() end)
ss.sr = crearSlider(pApa, "Color secundario - Rojo", 0, 255, cv.sr, 1, function(v) cv.sr = v; actualizarColores() end)
ss.sg = crearSlider(pApa, "Color secundario - Verde", 0, 255, cv.sg, 1, function(v) cv.sg = v; actualizarColores() end)
ss.sb = crearSlider(pApa, "Color secundario - Azul", 0, 255, cv.sb, 1, function(v) cv.sb = v; actualizarColores() end)

crearSeccion(pApa, "Ventana")
local setTransp = crearSlider(pApa, "Transparencia de la ventana", 0, 60, 0, 1, function(v) Main.BackgroundTransparency = v / 100 end, "%")
setEscala = crearSlider(pApa, "Tamaño del menú", 40, 130, 100, 5, function(v)
    escalaUI = v / 100
    if Main.Visible then tween(MainScale, 0.2, {Scale = escalaUI}) end
end, "%")
crearToggle(pApa, "Borde RGB animado", "El borde de la ventana gira con colores RGB.", function(v) bordeAnimado = v end, {sinBind = true, inicial = true})
crearToggle(pApa, "Decoración de Halloween", "Luna, murciélagos, fantasmas, calabazas y una araña.", function(v)
    HLayer.Visible = v
    hilo.Visible = v
    arana.Visible = v
end, {sinBind = true, inicial = true})

crearSeccion(pApa, "Imagen de fondo")
do
    local card = crearCard(pApa, "Imagen de fondo", "Pega el ID de una imagen de Roblox y pulsa Aplicar.", 94)
    local box = new("TextBox", {
        Size = UDim2.new(1, -140, 0, 30), Position = UDim2.new(0, 14, 0, 56), BackgroundTransparency = 0.1, Text = "",
        PlaceholderText = "ID (solo números)", ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        __t = {BackgroundColor3 = "panel2", TextColor3 = "texto", PlaceholderColor3 = "sub"}, Parent = card,
    }, {corner(8), new("UIPadding", {PaddingLeft = UDim.new(0, 12)}), stroke("accent", 1, 0.6)})
    local ap = new("TextButton", {
        Size = UDim2.new(0, 108, 0, 30), Position = UDim2.new(1, -122, 0, 56), Text = "Aplicar",
        Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false,
        __t = {BackgroundColor3 = "accent"}, Parent = card,
    }, {corner(8)})
    ap.TextColor3 = BLANCO
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
    setEscala(escalaAuto)
    FondoImg.Image = ""
end)

end

do
-- ========== PÁGINA: AJUSTES ==========
local pAju = crearTab("GENERAL", "Ajustes", true, nil)
crearSeccion(pAju, "Atajos")

local KeyBtn
local function refrescarKeyBtn()
    if KeyBtn then
        KeyBtn.Text = "[ " .. teclaOcultar.Name .. " ]"
        KeyBtn.TextColor3 = T.accent
    end
    SubLbl.Text = "Ocultar: " .. teclaOcultar.Name
end

KeyBtn = crearAccion(pAju, "Tecla para ocultar el menú", "Haz clic y presiona la nueva tecla (Esc cancela).", "[ RightShift ]", function()
    if escuchando then return end
    KeyBtn.Text = "Presiona una tecla..."
    KeyBtn.TextColor3 = T.texto
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
crearToggle(pAju, "Sonidos de clic", "Suena al hacer clic en una opción.", function(v) sonidoOn = v end, {sinBind = true, inicial = true})
crearSlider(pAju, "Volumen", 0, 100, 50, 5, function(v) sonidoVol = v / 100 end, "%")

-- ---------- Idioma ----------
crearSeccion(pAju, "Idioma")
crearSelector(pAju, "Idioma", "Cambia el idioma del menú.", {"Español", "English"}, 1, function(_, i)
    setIdioma(i == 2 and "en" or "es")
end)

-- ---------- Configuraciones (guardar / cargar) ----------
crearSeccion(pAju, "Configuración")
local HttpService = game:GetService("HttpService")
local CARPETA = "NahualHub"
local memCfg = {}
if getgenv then
    getgenv().NahualCfgMem = getgenv().NahualCfgMem or {}
    memCfg = getgenv().NahualCfgMem          -- respaldo si el executor no tiene writefile
end
local indice, cfgSel = {}, nil
local refrescarCfg

local function fsOK() return type(writefile) == "function" and type(readfile) == "function" end
local function rutaCfg(n) return CARPETA .. "/" .. n .. ".json" end
local function limpiarNombre(s)
    s = string.gsub(s, "[^%w _%-]", "")
    s = string.gsub(s, "^%s+", "")
    s = string.gsub(s, "%s+$", "")
    return string.sub(s, 1, 24)
end
local function keyDe(n)
    local ok, k = pcall(function() return Enum.KeyCode[n] end)
    return ok and k or nil
end

local function guardarIndice()
    table.sort(indice)
    if fsOK() then pcall(writefile, CARPETA .. "/_indice.json", HttpService:JSONEncode(indice)) end
end
local function cargarIndice()
    indice = {}
    pcall(function()
        if fsOK() and isfile and isfile(CARPETA .. "/_indice.json") then
            local t = HttpService:JSONDecode(readfile(CARPETA .. "/_indice.json"))
            if type(t) == "table" then indice = t end
        end
    end)
    for n in pairs(memCfg) do
        if not table.find(indice, n) then table.insert(indice, n) end
    end
    table.sort(indice)
end

local function capturarConfig()
    local cfg = {tema = temaIdx, tecla = teclaOcultar.Name, toggles = {}, sliders = {}, selectores = {}, atajos = {}}
    for id, t in pairs(regToggles) do
        cfg.toggles[id] = t.get()
        if t.key then cfg.atajos[id] = t.key.Name end
    end
    for id, s in pairs(regSliders) do cfg.sliders[id] = s.get() end
    for id, s in pairs(regSel) do cfg.selectores[id] = s.get() end
    return cfg
end

local function aplicarConfig(cfg)
    cargando = true
    pcall(function()
        if cfg.tema and Temas[cfg.tema] then aplicarPreset(cfg.tema) end
        for id, v in pairs(cfg.sliders or {}) do if regSliders[id] then regSliders[id].set(v) end end
        for id, i in pairs(cfg.selectores or {}) do if regSel[id] then regSel[id].set(i) end end
        for _, t in pairs(regToggles) do if t.poner then t.poner(nil) end end
        for id, v in pairs(cfg.toggles or {}) do if regToggles[id] then regToggles[id].set(v) end end
        for id, kn in pairs(cfg.atajos or {}) do
            local t, k = regToggles[id], keyDe(kn)
            if t and t.poner and k then t.poner(k) end
        end
        local k = cfg.tecla and keyDe(cfg.tecla)
        if k and not binds[k] then teclaOcultar = k; refrescarKeyBtn() end
    end)
    cargando = false
end

local function guardarConfig(nombre)
    nombre = limpiarNombre(nombre)
    if nombre == "" then notificar("Escribe un nombre para la configuración") return end
    local json = HttpService:JSONEncode(capturarConfig())
    memCfg[nombre] = json
    if fsOK() then
        pcall(function() if makefolder and isfolder and not isfolder(CARPETA) then makefolder(CARPETA) end end)
        pcall(writefile, rutaCfg(nombre), json)
    end
    if not table.find(indice, nombre) then table.insert(indice, nombre) end
    guardarIndice()
    cfgSel = nombre
    refrescarCfg()
    notificar("Configuración guardada: " .. nombre)
end

local function leerConfig(nombre)
    local json = memCfg[nombre]
    if not json and fsOK() then
        pcall(function() if isfile and isfile(rutaCfg(nombre)) then json = readfile(rutaCfg(nombre)) end end)
    end
    if not json then return nil end
    local ok, cfg = pcall(function() return HttpService:JSONDecode(json) end)
    return ok and cfg or nil
end

local function cargarConfig(nombre)
    nombre = limpiarNombre(nombre or "")
    if nombre == "" then notificar("Elige o escribe una configuración") return end
    local cfg = leerConfig(nombre)
    if not cfg then notificar("No se encontró la configuración") return end
    aplicarConfig(cfg)
    notificar("Configuración cargada: " .. nombre)
end

local function eliminarConfig(nombre)
    nombre = limpiarNombre(nombre or "")
    local i = table.find(indice, nombre)
    if nombre == "" or not i then notificar("Elige o escribe una configuración") return end
    memCfg[nombre] = nil
    pcall(function() if delfile and isfile and isfile(rutaCfg(nombre)) then delfile(rutaCfg(nombre)) end end)
    table.remove(indice, i)
    guardarIndice()
    if cfgSel == nombre then cfgSel = nil end
    refrescarCfg()
    notificar("Configuración eliminada: " .. nombre)
end

-- Nombre
local cNombre = crearCard(pAju, "Nombre de la configuración", "Escribe un nombre y pulsa Guardar.", 94)
local cfgBox = new("TextBox", {
    Size = UDim2.new(1, -28, 0, 30), Position = UDim2.new(0, 14, 0, 56), BackgroundTransparency = 0.1, Text = "",
    PlaceholderText = "Nombre (ej. Mi config)", ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    __t = {BackgroundColor3 = "panel2", TextColor3 = "texto", PlaceholderColor3 = "sub"}, Parent = cNombre,
}, {corner(8), new("UIPadding", {PaddingLeft = UDim.new(0, 12)}), stroke("accent", 1, 0.6)})

crearAccion(pAju, "Guardar configuración", "Guarda todas tus opciones actuales con ese nombre.", "Guardar", function()
    guardarConfig(cfgBox.Text)
end)

-- Lista de configuraciones guardadas
local cLista = crearCard(pAju, "Configuraciones guardadas", "Toca una para seleccionarla.", 146)
local lista = new("ScrollingFrame", {
    Size = UDim2.new(1, -28, 0, 84), Position = UDim2.new(0, 14, 0, 52), BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0),
    __t = {ScrollBarImageColor3 = "accent"}, Parent = cLista,
}, {new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder})})

refrescarCfg = function()
    for _, c in ipairs(lista:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    for i, n in ipairs(indice) do
        local b = new("TextButton", {
            Size = UDim2.new(1, -4, 0, 26), BackgroundColor3 = (cfgSel == n) and T.accent or T.panel2,
            BackgroundTransparency = (cfgSel == n) and 0.45 or 0.3, Text = n, TextColor3 = T.texto,
            Font = Enum.Font.GothamMedium, TextSize = 12, AutoButtonColor = false, LayoutOrder = i, Parent = lista,
        }, {corner(8), stroke("accent", 1, 0.55)})
        b.MouseButton1Click:Connect(function()
            cfgSel = n
            cfgBox.Text = n
            refrescarCfg()
        end)
    end
end
cargarIndice()
onTema(refrescarCfg)

crearAccion(pAju, "Cargar configuración", "Aplica la configuración seleccionada (o el nombre escrito).", "Cargar", function()
    cargarConfig(cfgSel or cfgBox.Text)
end)
crearAccion(pAju, "Eliminar configuración", "Borra la configuración seleccionada.", "Eliminar", function()
    eliminarConfig(cfgSel or cfgBox.Text)
end)

crearSeccion(pAju, "Acerca de")
crearNota(pAju, "NAHUALHUB v2.7  •  Premium Edition\nEl botón flotante N abre o cierra el menú. Personaliza colores y tamaño en GENERAL > Apariencia.", 40)

end

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
    local naranja = Color3.fromRGB(255, 125, 25)
    local morado = Color3.fromRGB(150, 70, 255)
    local lunaCol = Color3.fromRGB(255, 226, 150)

    local IntroGui = new("ScreenGui", {
        Name = "NahualIntro", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = guiParent,
    })
    local Root = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = BLANCO, BorderSizePixel = 0, Parent = IntroGui}, {
        new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(8, 4, 16), Color3.fromRGB(58, 20, 30)), Rotation = 90}),
    })

    -- Estrellas
    local estrellas = {}
    for i = 1, 40 do
        local sz = math.random(1, 3)
        local f = new("Frame", {
            Size = UDim2.new(0, sz, 0, sz), Position = UDim2.new(math.random(), 0, math.random() * 0.7, 0),
            BackgroundColor3 = BLANCO, BackgroundTransparency = 0.5, BorderSizePixel = 0, Parent = Root,
        }, {redondo()})
        estrellas[i] = {f = f, fase = math.random() * 6.28}
    end

    -- Luna
    local Luna = new("Frame", {
        Size = UDim2.new(0, 210, 0, 210), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.4, 0),
        BackgroundColor3 = lunaCol, BackgroundTransparency = 0.86, BorderSizePixel = 0, Parent = Root,
    }, {redondo(), stroke(lunaCol, 3, 0.8)})
    for _, cr in ipairs({{0.25, 0.3, 36}, {0.6, 0.2, 22}, {0.5, 0.62, 42}, {0.2, 0.66, 20}}) do
        new("Frame", {
            Size = UDim2.new(0, cr[3], 0, cr[3]), Position = UDim2.new(cr[1], 0, cr[2], 0), BackgroundColor3 = lunaCol,
            BackgroundTransparency = 0.93, BorderSizePixel = 0, Parent = Luna,
        }, {redondo()})
    end

    -- Decoración de Halloween
    local deco = {}
    local function agregarDeco(emoji, tipo, tam, tr, x, y)
        local l = new("TextLabel", {
            Size = UDim2.new(0, tam + 12, 0, tam + 12), BackgroundTransparency = 1, Text = emoji,
            TextSize = tam, TextTransparency = tr, Parent = Root,
        })
        deco[#deco + 1] = {l = l, tipo = tipo, x = x, y = y, fase = math.random() * 6.28, v = math.random(30, 60) / 1000}
    end
    agregarDeco("🦇", "murcielago", 30, 0.15, 0.05, 0.18)
    agregarDeco("🦇", "murcielago", 22, 0.25, 0.45, 0.30)
    agregarDeco("🦇", "murcielago", 26, 0.2, 0.80, 0.12)
    agregarDeco("🦇", "murcielago", 18, 0.3, 0.30, 0.08)
    agregarDeco("👻", "fantasma", 34, 0.3, 0.12, 0.85)
    agregarDeco("👻", "fantasma", 26, 0.4, 0.85, 0.60)
    agregarDeco("👻", "fantasma", 20, 0.45, 0.62, 1.00)
    agregarDeco("🎃", "calabaza", 56, 0.05, 0.04, 0)
    agregarDeco("🎃", "calabaza", 44, 0.1, 0.90, 0)
    agregarDeco("🎃", "calabaza", 34, 0.15, 0.20, 0)
    agregarDeco("🎃", "calabaza", 38, 0.15, 0.76, 0)
    local webTL = new("TextLabel", {
        Size = UDim2.new(0, 120, 0, 120), Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1,
        Text = "🕸", TextSize = 100, TextTransparency = 0.35, Parent = Root,
    })
    local webTR = new("TextLabel", {
        Size = UDim2.new(0, 120, 0, 120), Position = UDim2.new(1, -120, 0, 0), BackgroundTransparency = 1,
        Text = "🕸", TextSize = 100, TextTransparency = 0.35, Rotation = 90, Parent = Root,
    })

    -- Araña colgando
    local hiloI = new("Frame", {
        Size = UDim2.new(0, 1, 0, 80), Position = UDim2.new(0.82, 0, 0, 0), BackgroundColor3 = Color3.fromRGB(215, 215, 230),
        BackgroundTransparency = 0.4, BorderSizePixel = 0, Parent = Root,
    })
    local aranaI = new("TextLabel", {
        Size = UDim2.new(0, 36, 0, 36), Position = UDim2.new(0.82, -18, 0, 70), BackgroundTransparency = 1,
        Text = "🕷", TextSize = 30, Parent = Root,
    })

    -- Título: las letras van apareciendo
    local texto = "NAHUALHUB"
    local ancho = 46
    local total = ancho * #texto
    local cont = new("Frame", {
        Size = UDim2.new(0, total, 0, 64), Position = UDim2.new(0.5, -total / 2, 0.5, -90),
        BackgroundTransparency = 1, Parent = Root,
    })
    local slots, contornos = {}, {}
    for i = 1, #texto do
        local col = naranja:Lerp(morado, (i - 1) / (#texto - 1))
        local l = new("TextLabel", {
            Size = UDim2.new(0, ancho, 0, 64), Position = UDim2.new(0, (i - 1) * ancho, 0, 0), BackgroundTransparency = 1,
            Text = "", TextColor3 = col, Font = Enum.Font.GothamBlack, TextSize = 54, Parent = cont,
        })
        local st = Instance.new("UIStroke")
        st.Color = col
        st.Thickness = 2
        st.Transparency = 0.55
        st.Parent = l
        slots[i] = l
        contornos[i] = st
    end

    local caret = new("Frame", {
        Size = UDim2.new(0, 4, 0, 50), Position = UDim2.new(0, 4, 0, 7), BackgroundColor3 = naranja, BorderSizePixel = 0, Parent = cont,
    }, {stroke(naranja, 2, 0.5)})

    local tituloListo = false
    local introConn
    introConn = RunService.Heartbeat:Connect(function(dt)
        local t = tick()
        for _, e in ipairs(estrellas) do
            e.f.BackgroundTransparency = 0.4 + (math.sin(t * 2 + e.fase) + 1) * 0.25
        end
        for _, d in ipairs(deco) do
            if d.tipo == "murcielago" then
                d.x = d.x + d.v * dt
                if d.x > 1.05 then d.x = -0.08 end
                d.l.Position = UDim2.new(d.x, 0, d.y, math.sin(t * 2.4 + d.fase) * 18)
            elseif d.tipo == "fantasma" then
                d.y = d.y - d.v * 0.5 * dt
                if d.y < -0.1 then d.y = 1.05 end
                d.l.Position = UDim2.new(d.x, math.sin(t * 1.4 + d.fase) * 20, d.y, 0)
            elseif d.tipo == "calabaza" then
                d.l.Position = UDim2.new(d.x, 0, 1, -90 + math.sin(t * 1.7 + d.fase) * 5)
                d.l.Rotation = math.sin(t * 1.3 + d.fase) * 7
            end
        end
        local largo = 90 + math.sin(t * 1.1) * 26
        hiloI.Size = UDim2.new(0, 1, 0, largo)
        aranaI.Position = UDim2.new(0.82, -18, 0, largo - 10)
        aranaI.Rotation = math.sin(t * 1.1) * 6
        if tituloListo then
            for i, st in ipairs(contornos) do
                st.Transparency = 0.45 + math.sin(t * 3 + i * 0.6) * 0.15
            end
        end
    end)

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
    tituloListo = true

    -- Subtítulo
    local sub = new("TextLabel", {
        Size = UDim2.new(0, 460, 0, 20), Position = UDim2.new(0.5, -230, 0.5, -14), BackgroundTransparency = 1,
        Text = "H A L L O W E E N    E D I T I O N", TextColor3 = naranja, Font = Enum.Font.GothamMedium,
        TextSize = 12, TextTransparency = 1, Parent = Root,
    })
    tween(sub, 0.6, {TextTransparency = 0})

    -- Barra neón de carga con calabaza
    local BW = 380
    local estado = new("TextLabel", {
        Size = UDim2.new(0, 260, 0, 16), Position = UDim2.new(0.5, -BW / 2, 0.5, 34), BackgroundTransparency = 1,
        Text = "Invocando módulos...", TextColor3 = T.sub, Font = Enum.Font.Gotham, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = Root,
    })
    local pct = new("TextLabel", {
        Size = UDim2.new(0, 60, 0, 16), Position = UDim2.new(0.5, BW / 2 - 60, 0.5, 34), BackgroundTransparency = 1,
        Text = "0%", TextColor3 = naranja, Font = Enum.Font.GothamBold, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right, Parent = Root,
    })
    local barraFondo = new("Frame", {
        Size = UDim2.new(0, BW, 0, 8), Position = UDim2.new(0.5, -BW / 2, 0.5, 56), BackgroundColor3 = Color3.fromRGB(36, 24, 44),
        BorderSizePixel = 0, Parent = Root,
    }, {corner(4), stroke(Color3.fromRGB(100, 70, 120), 1, 0.4)})
    local halo = new("Frame", {
        Size = UDim2.new(0, 0, 0, 22), Position = UDim2.new(0, 0, 0.5, -11), BackgroundColor3 = naranja,
        BackgroundTransparency = 0.78, BorderSizePixel = 0, Parent = barraFondo,
    }, {corner(11)})
    local fill = new("Frame", {
        Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = BLANCO, BorderSizePixel = 0, Parent = barraFondo,
    }, {
        corner(4),
        new("UIGradient", {Color = ColorSequence.new(naranja, morado)}),
        stroke(naranja, 1.5, 0.3),
    })
    local punta = new("TextLabel", {
        Size = UDim2.new(0, 28, 0, 28), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundTransparency = 1, Text = "🎃", TextSize = 22, Parent = barraFondo,
    })

    local pasos = {
        {0, "Invocando módulos..."}, {22, "Encendiendo las velas..."}, {48, "Despertando a los fantasmas..."},
        {72, "Afilando las garras..."}, {92, "Casi listo..."},
    }
    local dur = 2.8
    local t0 = tick()
    while true do
        local t = math.clamp((tick() - t0) / dur, 0, 1)
        local pr = t * t * (3 - 2 * t)
        local px = math.floor(BW * pr)
        fill.Size = UDim2.new(0, px, 1, 0)
        halo.Size = UDim2.new(0, px, 0, 22)
        punta.Position = UDim2.new(0, px, 0.5, 0)
        punta.Rotation = math.sin(tick() * 8) * 12
        local num = math.floor(pr * 100)
        pct.Text = num .. "%"
        for _, st in ipairs(pasos) do
            if num >= st[1] then estado.Text = st[2] end
        end
        if t >= 1 then break end
        RunService.RenderStepped:Wait()
    end
    estado.Text = "¡Feliz Halloween!"
    estado.TextColor3 = naranja
    task.wait(0.7)

    desvanecer(Root, 0.6)
    task.wait(0.7)
    pcall(function() introConn:Disconnect() end)
    IntroGui:Destroy()
end

task.spawn(function()
    seleccionar("Vuelo")
    -- Ajustar el tamaño del menú a pantallas pequeñas
    pcall(function()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
        local fit = math.min(1, (vp.X - 16) / ANCHO, (vp.Y - 16) / ALTO)
        if fit < 1 then
            escalaAuto = math.max(40, math.floor(fit * 20) * 5)
            setEscala(escalaAuto)
        end
    end)
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

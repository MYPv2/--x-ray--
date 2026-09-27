-- ============================================
-- X-Ray v3.3 | Optimizado + Anti-Vacío + Distancia
-- Tecla M = toggle | - y + (teclado numérico) = transparencia
-- ============================================
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- ============================================
-- CONFIGURACIÓN
-- ============================================
local CONFIG = {
    transparency      = 0.75,
    minTransparency   = 0.3,
    maxTransparency   = 0.95,
    step              = 0.05,
    batchSize         = 200,
    batchDelayMin     = 0.02,
    batchDelayMax     = 0.06,
    protectFloor      = true,
    minPartSize       = 2,
    maxParts          = 15000,
    maxDistance       = 300,
    useDistance       = true,
}

-- ============================================
-- ESTADO
-- ============================================
local xrayEnabled = false
local originalTransparency = {}
local procesadas = {}
local descendantConn = nil

-- ============================================
-- FILTROS
-- ============================================
local function esPisoSeguro(obj)
    if not CONFIG.protectFloor then return false end
    local nombre = string.lower(obj.Name)
    if string.find(nombre, "floor") or string.find(nombre, "ground")
       or string.find(nombre, "baseplate") or string.find(nombre, "terrain")
       or string.find(nombre, "spawn") or string.find(nombre, "checkpoint")
       or string.find(nombre, "safe") or string.find(nombre, "lobby") then
        return true
    end
    if obj:IsA("Terrain") then return true end
    if obj:IsA("BasePart") then
        local size = obj.Size
        local plano = (size.Y <= 3) and (size.X >= 30 or size.Z >= 30)
        if plano then return true end
    end
    return false
end

local function esParteDePersonaje(obj)
    local model = obj:FindFirstAncestorWhichIsA("Model")
    if not model then return false end
    if not model:FindFirstChildOfClass("Humanoid") then return false end
    return true
end

local function esPartePequena(obj)
    if not obj:IsA("BasePart") then return false end
    if obj:IsA("MeshPart") then return false end
    local size = obj.Size
    if size.Magnitude < CONFIG.minPartSize then return true end
    return false
end

local function estaCerca(obj)
    if not CONFIG.useDistance then return true end
    local char = LocalPlayer.Character
    if not char or not char.PrimaryPart then return true end
    local dist = (char.PrimaryPart.Position - obj.Position).Magnitude
    return dist <= CONFIG.maxDistance
end

local function puedeAplicar(obj)
    if not obj:IsA("BasePart") then return false end
    if procesadas[obj] then return false end
    if esParteDePersonaje(obj) then return false end
    if esPisoSeguro(obj) then return false end
    if esPartePequena(obj) then return false end
    if not estaCerca(obj) then return false end
    return true
end

-- ============================================
-- GUARDAR / RESTAURAR
-- ============================================
local function guardarOriginal(part)
    if not originalTransparency[part] then
        originalTransparency[part] = part.Transparency
    end
end

local function aplicarAParte(part)
    if not puedeAplicar(part) then return end
    guardarOriginal(part)
    part.Transparency = CONFIG.transparency
    procesadas[part] = true
end

local function restaurarParte(part)
    local orig = originalTransparency[part]
    if orig and part and part.Parent then
        part.Transparency = orig
    end
end

-- ============================================
-- APLICAR EN BATCHES CON DELAY RANDOMIZADO
-- ============================================
local function aplicarXRayOptimizado()
    task.spawn(function()
        local contador = 0
        local total = 0

        for _, obj in ipairs(workspace:GetDescendants()) do
            if contador >= CONFIG.maxParts then break end

            if obj:IsA("BasePart") and puedeAplicar(obj) then
                guardarOriginal(obj)
                obj.Transparency = CONFIG.transparency
                procesadas[obj] = true
                contador = contador + 1
                total = total + 1
            end

            if total >= CONFIG.batchSize then
                total = 0
                local delay = CONFIG.batchDelayMin + math.random() * (CONFIG.batchDelayMax - CONFIG.batchDelayMin)
                task.wait(delay)
            end
        end

        print("[X-Ray] ✅ Aplicado a " .. contador .. " partes")
    end)
end

-- ============================================
-- QUITAR X-RAY
-- ============================================
local function quitarXRay()
    local count = 0
    for part, _ in pairs(originalTransparency) do
        if part and part.Parent then
            part.Transparency = originalTransparency[part]
            count = count + 1
        end
    end
    originalTransparency = {}
    procesadas = {}
    print("[X-Ray] ❌ Desactivado (" .. count .. " partes restauradas)")
end

-- ============================================
-- TOGGLE
-- ============================================
local function toggleXRay()
    xrayEnabled = not xrayEnabled

    if xrayEnabled then
        aplicarXRayOptimizado()
        print("[X-Ray] ✅ ACTIVADO | Transparencia: " .. CONFIG.transparency)
        print("  Distancia máxima: " .. CONFIG.maxDistance .. " studs")

        if not descendantConn then
            descendantConn = workspace.DescendantAdded:Connect(function(obj)
                if xrayEnabled and obj:IsA("BasePart") then
                    task.wait(0.1)
                    aplicarAParte(obj)
                end
            end)
        end
    else
        quitarXRay()
        if descendantConn then
            descendantConn:Disconnect()
            descendantConn = nil
        end
    end
end

-- ============================================
-- INPUT (teclado numérico: - y +)
-- ============================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.M then
        toggleXRay()
    end

    if xrayEnabled then
        if input.KeyCode == Enum.KeyCode.KeypadMinus then
            CONFIG.transparency = math.max(CONFIG.minTransparency, CONFIG.transparency - CONFIG.step)
            for part, _ in pairs(originalTransparency) do
                if part and part.Parent then
                    part.Transparency = CONFIG.transparency
                end
            end
            print("[X-Ray] Transparencia: " .. string.format("%.2f", CONFIG.transparency))
        elseif input.KeyCode == Enum.KeyCode.KeypadPlus then
            CONFIG.transparency = math.min(CONFIG.maxTransparency, CONFIG.transparency + CONFIG.step)
            for part, _ in pairs(originalTransparency) do
                if part and part.Parent then
                    part.Transparency = CONFIG.transparency
                end
            end
            print("[X-Ray] Transparencia: " .. string.format("%.2f", CONFIG.transparency))
        end
    end
end)

-- ============================================
-- RE-APLICAR AL RESPAWNEAR
-- ============================================
LocalPlayer.CharacterAdded:Connect(function()
    if xrayEnabled then
        task.wait(1)
        aplicarXRayOptimizado()
    end
end)

-- ============================================
-- LIMPIEZA
-- ============================================
game:BindToClose(function()
    if xrayEnabled then
        quitarXRay()
    end
end)

print("[X-Ray v3.3] Cargado ✅ | M = toggle | Keypad - y + = transparencia")
print("  Delay randomizado: " .. CONFIG.batchDelayMin .. "s - " .. CONFIG.batchDelayMax .. "s")
print("  Distancia máxima: " .. CONFIG.maxDistance .. " studs")

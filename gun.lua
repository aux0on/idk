local table_insert = table.insert

local Maid = {}
Maid.__index = Maid

function Maid.new()
    return setmetatable({_tasks = {}, _destroyed = false}, Maid)
end

function Maid:GiveTask(task)
    if self._destroyed then
        self:_cleanupTask(task)
        return
    end
    table_insert(self._tasks, task)
    return task
end

function Maid:GiveTasks(...)
    for _, task in ipairs({...}) do
        self:GiveTask(task)
    end
end

function Maid:_cleanupTask(task)
    local taskType = typeof(task)
    if taskType == "RBXScriptConnection" then
        task:Disconnect()
    elseif taskType == "Instance" then
        task:Destroy()
    elseif taskType == "function" then
        task()
    elseif taskType == "table" and type(task.Destroy) == "function" then
        task:Destroy()
    end
end

function Maid:DoCleaning()
    if self._destroyed then return end
    self._destroyed = true
    for _, task in ipairs(self._tasks) do
        self:_cleanupTask(task)
    end
    self._tasks = {}
end

function Maid:Destroy()
    self:DoCleaning()
end

local RootMaid = Maid.new()
local shared = odh_shared_plugins

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local COOLDOWN_DURATION = 5
local SOUND_ID = "rbxassetid://6968135315"
local START_OFFSET = 0

local features = {
    blockAnims = false,
    equipSound = false,
}

local charData = {}
local currentSounds = {}
local lastUnequippedTime = 0

local function cleanCharacter(character)
    local data = charData[character]
    if data then
        if data.maid then
            data.maid:DoCleaning()
        end
        charData[character] = nil
    end

    local sound = currentSounds[character]
    if sound then
        sound:Stop()
        sound:Destroy()
        currentSounds[character] = nil
    end
end

local function playSound(character, soundId)
    if not features.equipSound then return end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = 1
    sound.Parent = hrp
    sound:Play()

    currentSounds[character] = sound

    sound.Ended:Once(function()
        if currentSounds[character] == sound then
            currentSounds[character] = nil
        end
        sound:Destroy()
    end)
end

local function isHoldingGun(character)
    local tool = character:FindFirstChildOfClass("Tool")
    return tool and tool.Name == "Gun"
end

local function setupGunSystem(character)
    local data = charData[character]
    if not data then
        data = { maid = Maid.new() }
        charData[character] = data
        
        data.maid:GiveTask(character.AncestryChanged:Connect(function()
            if not character.Parent then
                cleanCharacter(character)
            end
        end))
    end

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    local animator = humanoid:FindFirstChild("Animator")

    if features.blockAnims and animator then
        data.maid:GiveTask(animator.AnimationPlayed:Connect(function(track)
            local holdingGun = isHoldingGun(character)
            local timeSinceUnequip = tick() - lastUnequippedTime
            local withinCooldown = timeSinceUnequip <= COOLDOWN_DURATION

            if holdingGun or withinCooldown then
                if track.Priority == Enum.AnimationPriority.Action then
                    track:Stop()
                end
            end
        end))
    end

    if features.equipSound then
        data.maid:GiveTask(character.ChildAdded:Connect(function(child)
            if child:IsA("Tool") and child.Name == "Gun" then
                task.wait(0.05)
                playSound(character, SOUND_ID)
            end
        end))
        
        data.maid:GiveTask(character.ChildRemoved:Connect(function(child)
            if child:IsA("Tool") and child.Name == "Gun" then
                lastUnequippedTime = tick()
                task.wait(0.05)
                playSound(character, SOUND_ID)
            end
        end))
    end
end

local function onCharacterAdded(character)
    character:WaitForChild("Humanoid", 10)
    local hrp = character:WaitForChild("HumanoidRootPart", 10)
    if hrp then
        setupGunSystem(character)
    end
end

local globalMaid = Maid.new()

local function refreshSystem()
    globalMaid:DoCleaning()
    globalMaid = Maid.new()
    
    for character, data in pairs(charData) do
        cleanCharacter(character)
    end
    charData = {}
    lastUnequippedTime = 0
    
    for character, sound in pairs(currentSounds) do
        sound:Stop()
        sound:Destroy()
        currentSounds[character] = nil
    end
    
    if not features.blockAnims and not features.equipSound then
        return
    end
    
    if LocalPlayer.Character then
        setupGunSystem(LocalPlayer.Character)
    end
    
    globalMaid:GiveTask(LocalPlayer.CharacterAdded:Connect(function(character)
        onCharacterAdded(character)
    end))
end

if LocalPlayer.Character then
    onCharacterAdded(LocalPlayer.Character)
end

local section = shared.AddSection("Gun")

section:AddToggle("Disable Gun Animations", function(bool)
    features.blockAnims = bool
    refreshSystem()
end)

section:AddToggle("Enable Un/Equip Sounds", function(bool)
    features.equipSound = bool
    refreshSystem()
end)

RootMaid:GiveTask(function()
    features.blockAnims = false
    features.equipSound = false
    globalMaid:DoCleaning()
    for character, data in pairs(charData) do
        cleanCharacter(character)
    end
    charData = {}
    for character, sound in pairs(currentSounds) do
        sound:Stop()
        sound:Destroy()
        currentSounds[character] = nil
    end
end)

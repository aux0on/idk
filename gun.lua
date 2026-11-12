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
task.spawn(function()
    shared.load_from_github_url("/aux0on/CrashHandler/refs/heads/main/Prevention.lua")
end)

if shared.game_name ~= "Murder Mystery 2" then return end

local rgdp = shared.CreateTab("Ragdoll Players", "/aux0on/rgdpIcon/refs/heads/main/Untitled163_20260919034104")
local section = rgdp:AddSection("Ragdoll Players", "MM2")

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local DEFAULT_GRAVITY = 196.2
local ragdollEnabled = false

local rgdpMaid = Maid.new()

local function applyGravityToCharacter(char)
    if not ragdollEnabled then return end
    workspace.Gravity = 0
    
    local root = char:WaitForChild("HumanoidRootPart", 5)
    local hum  = char:WaitForChild("Humanoid", 5)
    if not root or not hum then return end

    local originalJumpPower = hum.JumpPower
    local originalUseJumpPower = hum.UseJumpPower

    hum.UseJumpPower = true
    hum.JumpPower = (originalJumpPower > 0 and originalJumpPower or 50) * 0.925

    local localAttachment = Instance.new("Attachment", root)
    local localForce = Instance.new("VectorForce")
    localForce.Attachment0 = localAttachment
    localForce.RelativeTo = Enum.ActuatorRelativeTo.World
    localForce.Parent = root

    rgdpMaid:GiveTask(function()
        workspace.Gravity = DEFAULT_GRAVITY
        if hum and hum.Parent then
            hum.JumpPower = originalJumpPower
            hum.UseJumpPower = originalUseJumpPower
        end
        if localForce then localForce:Destroy() end
        if localAttachment then localAttachment:Destroy() end
    end)

    rgdpMaid:GiveTask(task.spawn(function()
        while char and char.Parent and localForce do
            if hum:GetState() == Enum.HumanoidStateType.Climbing then
                localForce.Force = Vector3.zero
            else
                localForce.Force = Vector3.new(0, -root.AssemblyMass * DEFAULT_GRAVITY, 0)
            end
            task.wait()
        end
    end))
end

local function enableRagdollSystem()
    rgdpMaid:DoCleaning()
    rgdpMaid = Maid.new()

    if LocalPlayer.Character then
        applyGravityToCharacter(LocalPlayer.Character)
    end

    rgdpMaid:GiveTask(LocalPlayer.CharacterAdded:Connect(function(char)
        char:WaitForChild("HumanoidRootPart", 10)
        applyGravityToCharacter(char)
    end))
end

local function disableRagdollSystem()
    rgdpMaid:DoCleaning()
    workspace.Gravity = DEFAULT_GRAVITY
end

section:AddToggle("Enable Player Ragdolls", function(bool)
    ragdollEnabled = bool
    if ragdollEnabled then
        enableRagdollSystem()
    else
        disableRagdollSystem()
    end
end)

RootMaid:GiveTask(function()
    disableRagdollSystem()
end)

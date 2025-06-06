util.AddNetworkString("shareTimeBoomer")
util.AddNetworkString("boomer_defuse_start")
util.AddNetworkString("boomer_defuse_stop")

local SWEP = {}

SWEP.Base = "weapon_fists"
SWEP.PrintName = "Boomer"
SWEP.Spawnable = true
SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/cstrike/c_eq_fraggrenade.mdl"
SWEP.WorldModel = "models/weapons/w_eq_fraggrenade.mdl"
SWEP.HoldType = "normal"

-- don't ask. same methode on sv and cl. because fuck sh. just copy paste
function SWEP:_getAllowedTimeRange(ply)
    if ply:IsUserGroup("vip") then
        return 0, 60
    else
        return 10, 30
    end
end

function SWEP:Initialize()
    self:ResetData()
end

function SWEP:ResetData()
    self.data = {
        planted = false,
        bomb = nil,
        delay = 10
    }
    self:SetNWInt("delayToExplose", 10)
    self:SetNWBool("planted",false)
end

net.Receive("shareTimeBoomer", function(_, player)
    local wep = player:GetActiveWeapon()
    if not IsValid(wep) or not wep._getAllowedTimeRange or wep.data.planted then return end

    local delay = net.ReadUInt(6)
    local minTime, maxTime = wep:_getAllowedTimeRange(player)

    if delay < minTime or delay > maxTime then
        player:ChatPrint("Temps invalide ! (Autorisé : " .. minTime .. " à " .. maxTime .. " secondes)")
        return
    end

    wep.data.delay = delay
    wep:SetNWInt("delayToExplose", delay)
    player:ChatPrint("Délai de bombe défini à " .. delay .. "s.")
end)

function SWEP:CreateExplosion(pos, owner)
    local explosion = ents.Create("env_explosion")
    explosion:SetPos(pos)
    explosion:SetOwner(owner)
    explosion:Spawn()
    explosion:SetKeyValue("iMagnitude", "350")
    explosion:Fire("Explode", 0, 0)
end

function SWEP:ExplodeBomb()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    self:CreateExplosion(self.data.bomb:GetPos(), owner)
    self.data.bomb:Remove()
    self:ResetData()
    owner:StripWeapon(self:GetClass())
end

function SWEP:ExplodePlayer()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    self:CreateExplosion(owner:GetPos(), owner)
    owner:StripWeapon(self:GetClass())
end

function SWEP:TriggerBomb()
    if self.data.planted and IsValid(self.data.bomb) then
        timer.Simple(self.data.delay, function()
            if IsValid(self) then self:ExplodeBomb() end
        end)
    else
        timer.Simple(self.data.delay, function()
            if IsValid(self) then self:ExplodePlayer() end
        end)
    end
end

function SWEP:PrimaryAttack()
    if not IsValid(self:GetOwner()) then return end
    self:SetNWFloat("explosionStartTime", CurTime())
    self:TriggerBomb()
    self:SetNextPrimaryFire(CurTime() + 1)
end

function SWEP:CreateBombModel()
    local bomb = ents.Create("gmod_button")
    bomb:SetNWBool("isBombFromBoomer", true)
    bomb:SetNWEntity("BoomerOwner", self:GetOwner())
    if not IsValid(bomb) then return end
    bomb:SetModel("models/Items/grenadeAmmo.mdl")
    return bomb
end

function SWEP:PlaceBombOnEntity(bomb, ent)
    bomb:SetParent(ent)
    bomb:SetLocalPos(Vector(0, 0, 10))
    bomb:SetLocalAngles(Angle(0, 0, 0))
    bomb:SetSolid(SOLID_NONE)
    bomb:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    local phys = bomb:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end
end

function SWEP:PlaceBombOnGround(bomb, pos, ang)
    bomb:SetPos(pos)
    bomb:SetAngles(ang)
    bomb:Spawn()
    local phys = bomb:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end
end

function SWEP:HandleUse(bomb, owner)
    local wep = self
    function bomb:Use(activator)
        if activator == owner then
            wep:RetrieveBomb(owner)
            self:Remove()
        else
            wep:StartDefuse(self, activator)
        end
    end
end

function SWEP:RetrieveBomb(owner)
    self:ResetData()
    owner:ChatPrint("[BOOMER] Bombe récupérée.")
end

function SWEP:StartDefuse(bomb, activator)
    if bomb.DefuseInProgress then return end

    bomb.DefuseInProgress = true
    bomb.DefuseStart = CurTime()

    net.Start("boomer_defuse_start")
    net.Send(activator)
    activator:ChatPrint("[BOOMER] Désamorçage en cours...")

    local timerID = "boomer_defuse_" .. bomb:EntIndex()
    timer.Create(timerID, 0.1, 0, function()
        if not IsValid(bomb) or not IsValid(activator) or activator:GetEyeTrace().Entity ~= bomb then
            bomb.DefuseInProgress = false
            net.Start("boomer_defuse_stop") net.Send(activator)
            activator:ChatPrint("[BOOMER] Désamorçage annulé.")
            timer.Remove(timerID)
            return
        end

        if CurTime() - bomb.DefuseStart >= 5 then
            activator:StripWeapon(self:GetClass())
            activator:ChatPrint("[BOOMER] Bombe désamorcée.")
            bomb:Remove()
            self:SetNWBool("planted",false)
            bomb.DefuseInProgress = false
            net.Start("boomer_defuse_stop") net.Send(activator)
            timer.Remove(timerID)
        end
    end)
end

function SWEP:SecondaryAttack()
    if self.data.planted or not IsFirstTimePredicted() then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local tr = util.TraceLine({
        start = owner:EyePos(),
        endpos = owner:EyePos() + owner:GetAimVector() * 100,
        filter = owner
    })

    local bomb = self:CreateBombModel()
    if not IsValid(bomb) then return end

    self:HandleUse(bomb, owner)

    if IsValid(tr.Entity) and owner:GetPos():Distance(tr.Entity:GetPos()) <= 100 and tr.Entity ~= game.GetWorld() then
        self:PlaceBombOnEntity(bomb, tr.Entity)
    else
        local pos = tr.Hit and tr.HitWorld and tr.HitPos + tr.HitNormal * 5 or
            owner:GetPos() + owner:GetAimVector() * 30 + Vector(0, 0, 10)
        self:PlaceBombOnGround(bomb, pos, owner:EyeAngles())
    end

    self.data.planted = true
    self:SetNWBool("planted",true)
    self.data.bomb = bomb

    self:SetNextSecondaryFire(CurTime() + 1)
end

weapons.Register(SWEP, "boomer_weapon")
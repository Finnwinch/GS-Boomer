SWEP = {}

SWEP.Base = "weapon_fists"
SWEP.Author = "Finnwinch"
SWEP.PrintName = "Boomer"
SWEP.Spawnable = true
SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/cstrike/c_eq_fraggrenade.mdl"
SWEP.WorldModel = "models/weapons/w_eq_fraggrenade.mdl"
SWEP.HoldType = "normal"

function SWEP:_getAllowedTimeRange(ply)
    if ply:IsUserGroup("vip") then
        return 0, 60
    else
        return 10, 30
    end
end

if SERVER then include("gs_boomer/swep/sv_boomer.lua") end

if CLIENT then include("gs_boomer/swep/cl_boomer.lua") end

weapons.Register(SWEP, "boomer_weapon")
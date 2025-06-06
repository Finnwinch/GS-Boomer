local _realm = SERVER and "sv" or "cl"
if SERVER then 
    AddCSLuaFile("gs_boomer/swep/cl_boomer.lua")
    AddCSLuaFile("gs_boomer/swep/sh_builder.lua")
end
include("gs_boomer/swep/sh_builder.lua")
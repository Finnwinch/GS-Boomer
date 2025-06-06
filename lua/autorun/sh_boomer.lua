local _realm = SERVER and "sv" or "cl"
if SERVER then 
    AddCSLuaFile("boomer/cl_boomer.lua")
end
include("boomer/" .. _realm .. "_boomer.lua")
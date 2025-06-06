function SWEP:PrimaryAttack() return end
function SWEP:SecondaryAttack() return end
function SWEP:DrawWeaponSelection() end

function SWEP:ShouldDrawAmmo()
    return false
end

function SWEP:DrawHUD()
    self:DrawHUDInstructions()
    self:DrawHUDCountdown()
end

function SWEP:DrawHUDInstructions()
    local scrW, scrH = ScrW(), ScrH()
    local padding, lineHeight = 10, 20
    local width, height = 400, lineHeight * 3 + padding * 2
    local x, y = scrW - width - padding, padding
    local planted = self:GetNWBool("planted",false)
    local delay = self:GetNWInt("delayToExplose", 0)

    draw.RoundedBox(6, x, y, width, height, Color(0, 0, 0, 150))
    draw.SimpleText("Clic gauche : Exploser la bombe " .. (not planted and "sur vous" or "sur au point définie"), "DermaDefaultBold", x + padding, y + padding, Color(255, 100, 100), TEXT_ALIGN_LEFT)
    if planted then
        draw.SimpleText("Votre bombe est placer", "DermaDefaultBold", x + padding, y + padding + lineHeight, Color(100, 255, 100), TEXT_ALIGN_LEFT)
    else
        draw.SimpleText("Clic droit : Poser la bombe", "DermaDefaultBold", x + padding, y + padding + lineHeight, Color(100, 255, 100), TEXT_ALIGN_LEFT)
        draw.SimpleText("R : définir un compte à rebour " .. (delay != 0 and "(" .. tostring(delay) .. " secondes)" or ""),"DermaDefaultBold",x + padding, y + padding * 3 + lineHeight,Color(0,0,255),TEXT_ALIGN_LEFT)
    end
end

function SWEP:DrawHUDCountdown()
    local delay = self:GetNWInt("delayToExplose", 0)
    local startTime = self:GetNWFloat("explosionStartTime", 0)
    
    if delay <= 0 or startTime <= 0 then return end

    local scrW, scrH = ScrW(), ScrH()
    local padding = 20
    local baseRadius = 40
    local thickness = 6

    local timeLeft = math.max(0, (startTime + delay) - CurTime())
    local percent = 1 - (timeLeft / delay)

    local centerX = scrW - padding - baseRadius
    local centerY = scrH - padding - baseRadius
    if timeLeft <= 5 then
        local shake = math.random(-2, 2)
        centerX = centerX + shake
        centerY = centerY + shake
    end

    local scale = 1 + 0.1 * math.abs(math.sin(CurTime() * 6))
    local radius = baseRadius * scale

    draw.RoundedBox(radius, centerX - radius, centerY - radius, radius * 2, radius * 2, Color(0, 0, 0, 200))

    surface.SetDrawColor(255, 0, 0, 220)
    draw.NoTexture()
    draw.CircleArc(centerX, centerY, radius, 64, 0, percent * 360)

    local txt = string.format("%.1fs", timeLeft)
    draw.SimpleText(txt, "DermaDefaultBold", centerX, centerY, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function SWEP:GetViewModel()
    if self:GetNWBool("planted", false) then
        return self.PlantedViewModel
    end
    return self.NormalViewModel
end

function SWEP:TranslateViewModelModel(vm, model)
    if self:GetNWBool("planted", false) then
        return self.PlantedViewModel
    end
    return model
end

function draw.Circle(x, y, radius, seg)
    local cir = {}
    for i = 0, seg do
        local a = math.rad((i / seg) * -360)
        table.insert(cir, {
            x = x + math.sin(a) * radius,
            y = y + math.cos(a) * radius
        })
    end
    surface.DrawPoly(cir)
end

function draw.CircleArc(x, y, radius, seg, startAngle, endAngle)
    local cir = {}
    for i = 0, seg do
        local a = math.rad(startAngle + (i / seg) * (endAngle - startAngle))
        table.insert(cir, {
            x = x + math.cos(a) * radius,
            y = y + math.sin(a) * radius
        })
    end
    surface.DrawPoly(cir)
end



function SWEP:Reload()
    if CLIENT then
        self:OpenTimeInputPanel()
    end
end

function SWEP:OpenTimeInputPanel()
    local ply = LocalPlayer()
    local minTime, maxTime = self:_getAllowedTimeRange(ply)

    if self.TimeInputPanel and IsValid(self.TimeInputPanel) then
        self.TimeInputPanel:Remove()
    end

    local frame = vgui.Create("DFrame")
    frame:SetTitle("")
    frame:SetSize(400, 200)
    frame:Center()
    frame:MakePopup()
    frame:SetDeleteOnClose(true)
    frame.btnMaxim:SetVisible(false)
    frame.btnMinim:SetVisible(false)
    frame.btnClose:SetText("X")
    frame.btnClose:SetFont("DermaDefaultBold")
    frame.btnClose:SetTextColor(color_white)

    frame.btnClose.Paint = function(self, w, h)
        local bgColor = self:IsHovered() and Color(180, 50, 50, 200) or Color(150, 40, 40, 180)
        draw.RoundedBox(0, 0, 0, w, h, bgColor)
    end


    self.TimeInputPanel = frame

    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(40, 44, 52))
        draw.SimpleText("Définir le temps", "DermaLarge", w / 2, 20, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    local slider = vgui.Create("DNumSlider", frame)
    slider:SetPos(30, 70)
    slider:SetSize(340, 60)
    slider:SetMin(minTime)
    slider:SetMax(maxTime)
    slider:SetDecimals(0)
    slider:SetValue(minTime)
    slider:SetText("")
    slider.Label:SetVisible(false)
    slider.TextArea:SetVisible(false)
    slider.Slider:Hide()

    slider.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 10, w, 4, Color(70, 75, 85))

        local val = (self:GetValue() - minTime) / (maxTime - minTime)
        local sliderX = math.Clamp(val * (w - 16), 0, w - 16)
        draw.RoundedBox(6, sliderX, 4, 16, 16, Color(30, 130, 255))

        draw.SimpleText("Temps sélectionné : " .. math.Round(self:GetValue()) .. "s", "DermaDefaultBold", w / 2, 30, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    slider.OnMousePressed = function(self, key)
        if key == MOUSE_LEFT then
            self.Dragging = true
            self:MouseCapture(true)
        end
    end

    slider.OnMouseReleased = function(self, key)
        if key == MOUSE_LEFT then
            self.Dragging = false
            self:MouseCapture(false)
        end
    end

    slider.OnCursorMoved = function(self, x, y)
        if self.Dragging then
            local w = self:GetWide()
            local ratio = math.Clamp(x / w, 0, 1)
            local newVal = math.Round(minTime + ratio * (maxTime - minTime))
            self:SetValue(newVal)
        end
    end

    local confirmBtn = vgui.Create("DButton", frame)
    confirmBtn:SetPos(150, 145)
    confirmBtn:SetSize(100, 30)
    confirmBtn:SetText("Valider")
    confirmBtn:SetFont("DermaDefaultBold")
    confirmBtn:SetTextColor(color_white)
    confirmBtn.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, self:IsHovered() and Color(40, 170, 80) or Color(30, 150, 70))
    end
    confirmBtn.DoClick = function()
        self:HandleTimeInputConfirm(slider:GetValue(), minTime, maxTime)
        frame:Close()
    end
end




function SWEP:HandleTimeInputConfirm(entry, minTime, maxTime)
    local t = tonumber(entry)
    if not t or t < minTime or t > maxTime then
        Derma_Message("Temps invalide. Autorisé : " .. minTime .. " à " .. maxTime .. " secondes.", "Erreur", "OK")
        return
    end

    self:SetNWInt("Boomer_TimerValue", t)
    net.Start("shareTimeBoomer")
        net.WriteUInt(t, 6)
    net.SendToServer()

    if self.TimeInputPanel and IsValid(self.TimeInputPanel) then
        self.TimeInputPanel:Close()
    end
end

local defusing = false
local defuseStartTime = 0
local defuseDuration = 5

net.Receive("boomer_defuse_start", function()
    defusing = true
    defuseStartTime = CurTime()
end)

net.Receive("boomer_defuse_stop", function()
    defusing = false
end)

hook.Add("PostDrawOpaqueRenderables", "Boomer_DrawBomb3D2D", function()
        local ply = LocalPlayer()
        local tr = ply:GetEyeTrace()

        local ent = tr.Entity
        if not IsValid(ent) then return end

        if not ent:GetNWBool("isBombFromBoomer", false) then return end

        local maxDistance = 100
        local dist = ply:GetPos():Distance(ent:GetPos())
        if dist > maxDistance then return end

        local pos = ent:GetPos() + Vector(0, 0, 15)
        local ang = Angle(0, LocalPlayer():EyeAngles().y - 90, 90)

        cam.Start3D2D(pos, ang, 0.15)
            if ent:GetNWEntity("BoomerOwner") == ply then
                local text = "Appuyez sur E pour reprendre"
                local font = "DermaDefaultBold"
                surface.SetFont(font)
                local tw, th = surface.GetTextSize(text)
                local x, y = 0, 35

                local padding = 8
                draw.RoundedBox(6, x - tw/2 - padding, y - th/2 - padding/2, tw + padding * 2, th + padding, Color(0, 0, 0, 180))
    
                draw.SimpleText(text, font, x, y, Color(100, 255, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            else
                local text = "Maintenez E et fixe 5s pour désamorcer"
                local font = "DermaDefaultBold"
                surface.SetFont(font)
                local tw, th = surface.GetTextSize(text)
                local x, y = 0, 35

                local padding = 8
                draw.RoundedBox(6, x - tw/2 - padding, y - th/2 - padding/2, tw + padding * 2, th + padding, Color(0, 0, 0, 180))

                draw.SimpleText(text, font, x, y, Color(255, 255, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

        cam.End3D2D()
end)

hook.Add("HUDPaint", "Boomer_DefuseProgress", function()
    if not defusing then return end

    local elapsed = CurTime() - defuseStartTime
    local fraction = math.Clamp(elapsed / defuseDuration, 0, 1)

    local w, h = 200, 25
    local x, y = ScrW() / 2 - w / 2, ScrH() - 100

    draw.RoundedBox(4, x, y, w, h, Color(50, 50, 50, 200))
    draw.RoundedBox(4, x, y, w * fraction, h, Color(100, 255, 100, 220))
    draw.SimpleText("Désamorçage de la bombe...", "DermaDefaultBold", x + w / 2, y + h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

weapons.Register(SWEP, "boomer_weapon")
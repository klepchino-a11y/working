local closed = false

local function hardClose(reason)
    if closed then return end
    closed = true

    -- لا نعتمد على JS داخل الصفحة؛ الإغلاق الحقيقي يتم عبر نيتف فايف إم
    if SetNuiFocus then
        SetNuiFocus(false, false)
    end

    -- نضمن التحكم اليدوي باللودنق ونقفلها نهائياً
    if SetManualShutdownLoadingScreenNui then
        SetManualShutdownLoadingScreenNui(true)
    end

    if ShutdownLoadingScreenNui then
        ShutdownLoadingScreenNui()
    end

    -- فشل آمن إضافي لو كان فيه لودنق روكستار لسبب ما
    if ShutdownLoadingScreen then
        pcall(ShutdownLoadingScreen)
    end
end

-- حارس #1: أول ما يصير اللاعب Active نقفل نهائياً
CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(100)
    end
    hardClose("playerActive")
end)

-- حارس #2: لو ESX أرسل إشارة إيقاف، نقفل نهائياً
RegisterNetEvent('esx:loadingScreenOff', function()
    hardClose("esx:loadingScreenOff")
end)

-- حارس #3: لو المورد بدأ متأخر (بعد ما صار اللاعب Active)، نقفل فوراً
AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    if NetworkIsPlayerActive(PlayerId()) then
        hardClose("resourceStartLate")
    end
end)

-- حارس #4: تايم أوت 60 ثانية احتياطي
CreateThread(function()
    Wait(60000)
    hardClose("timeout60s")
end)

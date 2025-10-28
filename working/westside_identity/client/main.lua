local loadingScreenFinished = false
local nuiReady = false
local guiEnabled = false
local registrationActive = false
local pendingOpen = false
local identityFinalized = false
local loadingScreenCloseRequested = false

local onLoadingScreenCleared

-- تم حذف أى أوامر تغلق اللودنق سكرين، لم يعد هذا الملف يطفئ شاشة التحميل بنفسه.
local function requestLoadingScreenClose()
    if loadingScreenFinished or loadingScreenCloseRequested then
        return
    end
    loadingScreenCloseRequested = true
end

local function ensurePedHidden(state)
    local ped = PlayerPedId()
    if state then
        FreezeEntityPosition(ped, true)
        SetEntityVisible(ped, false, false)
        SetEntityInvincible(ped, true)
        SetEntityCollision(ped, false, false)
        ClearPedTasksImmediately(ped)
        SetEntityAlpha(ped, 0, false)
        DisplayRadar(false)
    else
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true, false)
        SetEntityInvincible(ped, false)
        SetEntityCollision(ped, true, true)
        SetEntityAlpha(ped, 255, false)
        DisplayRadar(true)
    end
end

local function openRegistration()
    if guiEnabled then return end

    requestLoadingScreenClose()

    while not loadingScreenFinished do
        Wait(100)
    end

    while not nuiReady do
        Wait(100)
    end

    guiEnabled = true
    registrationActive = true
    pendingOpen = false

    ensurePedHidden(true)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openRegistration' })
end

local function closeRegistration()
    if not guiEnabled then
        return
    end

    guiEnabled = false
    registrationActive = false

    SendNUIMessage({ action = 'closeRegistration' })
    SetNuiFocus(false, false)
    ensurePedHidden(false)
end

local function finalizeIdentityReady()
    if identityFinalized then return end
    identityFinalized = true
    pendingOpen = false
    closeRegistration()
    ensurePedHidden(false)
    TriggerEvent('westside_identity:identityReady')
end

CreateThread(function()
    while true do
        if registrationActive then
            DisableAllControlActions(0)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

onLoadingScreenCleared = function()
    loadingScreenFinished = true
    if not identityFinalized then
        pendingOpen = true
        if nuiReady then
            openRegistration()
        end
    end
end

-- يستمع الآن فقط للحدث allowOpen المرسل من esx_loadingscreen بعد إغلاق اللودنق سكرين
AddEventHandler('westside_identity:allowOpen', onLoadingScreenCleared)

AddEventHandler('esx:loadingScreenClosed', function()
    onLoadingScreenCleared()
end)

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    if pendingOpen and loadingScreenFinished then
        openRegistration()
    end
    cb({ ok = true })
end)

local function handleShowRegistration()
    requestLoadingScreenClose()
    pendingOpen = true
    identityFinalized = false
    if loadingScreenFinished and nuiReady then
        openRegistration()
    end
end

RegisterNetEvent('westside_identity:showRegisterIdentity')
AddEventHandler('westside_identity:showRegisterIdentity', handleShowRegistration)

ESX.SecureNetEvent('westside_identity:alreadyRegistered', function()
    while not loadingScreenFinished do
        Wait(100)
    end
    TriggerEvent('esx_skin:playerRegistered')
end)

ESX.SecureNetEvent('westside_identity:setPlayerData', function(data)
    SetTimeout(1, function()
        ESX.SetPlayerData('name', ('%s %s'):format(data.firstName or '', data.lastName or ''))
        ESX.SetPlayerData('firstName', data.firstName)
        ESX.SetPlayerData('lastName', data.lastName)
        ESX.SetPlayerData('dateofbirth', data.dateOfBirth)
        ESX.SetPlayerData('sex', data.sex)
        ESX.SetPlayerData('height', data.height)
        ESX.SetPlayerData('weight', data.weight)
    end)
end)

RegisterNUICallback('submitIdentity', function(data, cb)
    if not guiEnabled then
        cb({ ok = false, message = 'ui_closed' })
        return
    end

    TriggerServerEvent('westside_identity:registerIdentity', data)
    cb({ ok = true })
end)

ESX.SecureNetEvent('westside_identity:registrationComplete', function(success, message)
    if success then
        closeRegistration()
        ESX.ShowNotification('✅ تم تسجيل الهوية بنجاح')
        TriggerEvent('esx_skin:playerRegistered')
    else
        SendNUIMessage({ action = 'setError', message = message or '❌ حدث خطأ أثناء التسجيل' })
        ESX.ShowNotification(message or '❌ حدث خطأ أثناء التسجيل')
        SetNuiFocus(true, true)
        guiEnabled = true
        registrationActive = true
        ensurePedHidden(true)
    end
end)

ESX.SecureNetEvent('westside_identity:spawnPlayer', function()
    finalizeIdentityReady()
end)

RegisterCommand('westside_identity:forceClose', function()
    closeRegistration()
end, false)

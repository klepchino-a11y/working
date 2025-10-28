local thisResource = 'esx_loadingscreen'
if GetCurrentResourceName then
    thisResource = GetCurrentResourceName()
end

local didClose = false
local closeRequested = false
local spawned = false
local shouldWaitForIdentity = false
local watchdogStarted = false

local allowedResources = {
    [thisResource] = true,
    ["es_extended"] = true
}

local function debugPrint(message, origin)
    local caller = origin or 'unknown'

    if not origin and GetInvokingResource then
        local sourceResource = GetInvokingResource()
        if sourceResource ~= nil then
            caller = sourceResource
        end
    end

    print(('[esx_loadingscreen DEBUG] %s | from=%s'):format(message, caller))
end

local function isCallerAllowed(resourceName)
    if resourceName == nil or resourceName == '' then
        return true
    end

    return allowedResources[resourceName] == true
end

if GetResourceState then
    local state = GetResourceState('westside_identity')
    shouldWaitForIdentity = state == 'starting' or state == 'started'
    debugPrint(('init: westside_identity state=%s shouldWaitForIdentity=%s'):format(
        tostring(state),
        tostring(shouldWaitForIdentity)
    ), thisResource)
else
    debugPrint('init: GetResourceState unavailable', thisResource)
    shouldWaitForIdentity = true
end

local function startWatchdog()
    if watchdogStarted then
        return
    end

    watchdogStarted = true
    CreateThread(function()
        while didClose do
            Wait(500)

            ShutdownLoadingScreen()
            ShutdownLoadingScreenNui()

            if ForceLoadingScreen then
                ForceLoadingScreen(false)
            end

            SetNuiFocus(false, false)
            if SetNuiFocusKeepInput then
                SetNuiFocusKeepInput(false)
            end
        end
    end)
end

local function performShutdown()
    if didClose then
        debugPrint('performShutdown ignored; already closed')
        return
    end

    didClose = true

    debugPrint('performShutdown: notifying NUI progress 100%')
    SendNUIMessage({
        action = 'progress',
        value = 100,
        text = 'Loading complete - enjoy!'
    })

    debugPrint('performShutdown: sending NUI shutdown')
    SendNUIMessage({ action = 'shutdown' })

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    if ForceLoadingScreen then
        ForceLoadingScreen(false)
    end

    if SetLoadingScreenFadeActive then
        SetLoadingScreenFadeActive(false)
    end

    SetNuiFocus(false, false)
    if SetNuiFocusKeepInput then
        SetNuiFocusKeepInput(false)
    end

    if Config and Config.Fade then
        DoScreenFadeOut(0)
        Wait(900)
        DoScreenFadeIn(900)
    end

    if shouldWaitForIdentity then
        debugPrint("performShutdown: TriggerEvent('westside_identity:allowOpen')")
        TriggerEvent('westside_identity:allowOpen')
    end

    debugPrint("performShutdown: TriggerEvent('esx:loadingScreenClosed')")
    TriggerEvent('esx:loadingScreenClosed')

    startWatchdog()
end

local function canShutdown()
    if not closeRequested then
        return false, 'close not requested yet'
    end

    if shouldWaitForIdentity and not spawned then
        return false, 'waiting for playerSpawned'
    end

    return true
end

local function tryShutdown(reason)
    if didClose then
        debugPrint(('tryShutdown(%s) ignored; already closed'):format(reason or 'unknown'))
        return
    end

    local allowed, why = canShutdown()
    if not allowed then
        debugPrint(('tryShutdown(%s) delayed: %s'):format(reason or 'unknown', why or 'unknown'))
        return
    end

    debugPrint(('tryShutdown(%s) performing shutdown'):format(reason or 'unknown'))
    performShutdown()
end

AddEventHandler('playerSpawned', function()
    debugPrint('event playerSpawned received')

    if spawned then
        debugPrint('playerSpawned ignored; already handled')
        return
    end

    spawned = true
    tryShutdown('playerSpawned')
end)

AddEventHandler('esx:onPlayerSpawn', function()
    debugPrint('event esx:onPlayerSpawn received')
    if not spawned then
        spawned = true
        tryShutdown('esx:onPlayerSpawn')
    end
end)

local function handleCloseRequest(eventName)
    local caller = GetInvokingResource and GetInvokingResource() or nil
    debugPrint(('event %s received'):format(eventName), caller or 'nil')

    if not isCallerAllowed(caller) then
        debugPrint(('event %s ignored; disallowed resource %s'):format(eventName, tostring(caller)))
        return
    end

    if closeRequested then
        debugPrint(('event %s ignored; close already requested'):format(eventName))
        return
    end

    closeRequested = true
    tryShutdown(eventName)
end

AddEventHandler('esx:loadingScreenOff', function()
    handleCloseRequest('esx:loadingScreenOff')
end)

AddEventHandler('westside_identity:closeLoadingScreen', function()
    debugPrint('event westside_identity:closeLoadingScreen ignored; es_extended controls shutdown')
end)

RegisterNetEvent('westside_identity:identityReady', function()
    debugPrint('event westside_identity:identityReady noted')
end)

RegisterNetEvent('westside_identity:spawnPlayer', function()
    debugPrint('event westside_identity:spawnPlayer noted')
    if not spawned then
        spawned = true
        tryShutdown('westside_identity:spawnPlayer')
    end
end)

AddEventHandler('onClientResourceStart', function(resource)
    debugPrint(('event onClientResourceStart(%s)'):format(tostring(resource)))
    if resource == 'westside_identity' then
        shouldWaitForIdentity = true
        debugPrint("westside_identity started - waiting for identity", thisResource)
    end
end)

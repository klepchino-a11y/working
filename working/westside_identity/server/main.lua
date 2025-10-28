local playerIdentity, alreadyRegistered = {}, {}
local multichar = ESX.GetConfig().Multichar

local ARABIC_PATTERN = '^[ابتثجحخدذرزسشصضطظعغفقكلمنهوياةى%s]+$'
local MIN_AGE = 18

local function isLeapYear(year)
    return (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
end

local function calculateAge(day, month, year)
    local today = os.date('*t')
    local age = today.year - year
    if month > today.month or (month == today.month and day > today.day) then
        age = age - 1
    end
    return age
end

local function formatDate(day, month, year)
    if Config.DateFormat == 'MM/DD/YYYY' then
        return ('%02d/%02d/%04d'):format(month, day, year)
    elseif Config.DateFormat == 'YYYY/MM/DD' then
        return ('%04d/%02d/%02d'):format(year, month, day)
    end

    return ('%02d/%02d/%04d'):format(day, month, year)
end

local function parseDate(value)
    if type(value) ~= 'string' then return nil end

    value = value:gsub('%-', '/'):gsub('%s+', '')
    local first, second, third = value:match('^(%d+)%/(%d+)%/(%d+)$')
    if not first then return nil end

    first, second, third = tonumber(first), tonumber(second), tonumber(third)
    if not (first and second and third) then return nil end

    local day, month, year

    if first > 1900 and first <= 9999 then
        year = first
        if second > 12 and third <= 12 then
            month, day = third, second
        else
            month, day = second, third
        end
    elseif third > 1900 and third <= 9999 then
        year = third
        if first > 12 and second <= 12 then
            day, month = first, second
        elseif second > 12 and first <= 12 then
            day, month = second, first
        elseif Config.DateFormat == 'MM/DD/YYYY' then
            month, day = first, second
        else
            day, month = first, second
        end
    else
        return nil
    end

    if month < 1 or month > 12 then return nil end

    local daysInMonth = { 31, isLeapYear(year) and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if day < 1 or day > daysInMonth[month] then return nil end

    return { day = day, month = month, year = year }
end

local function sanitizeName(name)
    name = tostring(name or ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    return name
end

local function isArabicName(name)
    if name == '' then return false end
    if #name > Config.MaxNameLength then return false end
    return name:match(ARABIC_PATTERN) ~= nil
end

local function fetchIdentityFromDatabase(identifier)
    local result = MySQL.single.await(
        'SELECT firstname, lastname, dateofbirth, sex, height, firstregsiteridentifier FROM users WHERE identifier = ?',
        { identifier }
    )

    if not result then
        return nil, false
    end

    local hasRegistered = type(result.firstregsiteridentifier) == 'string' and result.firstregsiteridentifier:lower() == 'yes'
    if not hasRegistered then
        return nil, false
    end

    if not result.firstname or not result.lastname then
        return nil, true
    end

    return {
        firstName = result.firstname,
        lastName = result.lastname,
        dateOfBirth = result.dateofbirth,
        sex = result.sex,
        height = result.height,
    }, true
end

local function saveIdentityToDatabase(identifier, identity)
    return MySQL.update.await(
        'UPDATE users SET firstname = ?, lastname = ?, dateofbirth = ?, sex = ?, height = ?, firstregsiteridentifier = ? WHERE identifier = ?',
        { identity.firstName, identity.lastName, identity.dateOfBirth, identity.sex, identity.height, 'yes', identifier }
    )
end

local function setPlayerData(xPlayer, identity)
    local name = ('%s %s'):format(identity.firstName, identity.lastName)
    xPlayer.setName(name)
    xPlayer.set('firstName', identity.firstName)
    xPlayer.set('lastName', identity.lastName)
    xPlayer.set('dateofbirth', identity.dateOfBirth)
    xPlayer.set('sex', identity.sex)
    xPlayer.set('height', identity.height)

    local state = Player(xPlayer.source).state
    state:set('name', name, true)
    state:set('firstName', identity.firstName, true)
    state:set('lastName', identity.lastName, true)
    state:set('dateofbirth', identity.dateOfBirth, true)
    state:set('sex', identity.sex, true)
    state:set('height', identity.height, true)
end

local function buildIdentity(data)
    if type(data) ~= 'table' then
        return nil, 'بيانات غير صالحة'
    end

    local firstName = sanitizeName(data.firstName or data.firstname)
    local lastName = sanitizeName(data.lastName or data.lastname)
    if not isArabicName(firstName) then
        return nil, 'الاسم الأول يجب أن يكون بالحروف العربية فقط'
    end
    if not isArabicName(lastName) then
        return nil, 'الاسم الأخير يجب أن يكون بالحروف العربية فقط'
    end

    local sex = tostring(data.sex or data.gender or 'm'):lower()
    if sex ~= 'm' and sex ~= 'f' then
        return nil, 'الجنس غير صالح'
    end

    local height = tonumber(data.height)
    if not height or height < Config.MinHeight or height > Config.MaxHeight then
        return nil, ('الطول يجب أن يكون بين %s و %s سنتيمتر.'):format(Config.MinHeight, Config.MaxHeight)
    end

    local dobValue = data.dateOfBirth or data.dateofbirth or data.dob
    if not dobValue then
        return nil, 'تاريخ الميلاد مطلوب'
    end

    local parsed = parseDate(dobValue)
    if not parsed then
        return nil, 'تنسيق تاريخ الميلاد غير صحيح'
    end

    local age = calculateAge(parsed.day, parsed.month, parsed.year)
    if age < MIN_AGE or age > Config.MaxAge then
        return nil, ('العمر يجب أن يكون بين %s و %s سنة.'):format(MIN_AGE, Config.MaxAge)
    end

    local formattedDate = formatDate(parsed.day, parsed.month, parsed.year)

    return {
        firstName = firstName,
        lastName = lastName,
        dateOfBirth = formattedDate,
        sex = sex,
        height = height,
    }
end

local function handleRegistration(src, payload, cb)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then
        if cb then cb(false) end
        return
    end

    local identity, errorMessage = buildIdentity(payload)
    if not identity then
        TriggerClientEvent('westside_identity:registrationComplete', src, false, errorMessage)
        if cb then cb(false) end
        return
    end

    local identifier = xPlayer.getIdentifier()
    local success = saveIdentityToDatabase(identifier, identity)

    if success and success > 0 then
        alreadyRegistered[identifier] = true
        setPlayerData(xPlayer, identity)
        TriggerClientEvent('westside_identity:setPlayerData', src, identity)
        TriggerClientEvent('westside_identity:registrationComplete', src, true)
        TriggerClientEvent('westside_identity:alreadyRegistered', src)
        TriggerClientEvent('esx_skin:openSaveableMenu', src)
        TriggerEvent('westside_identity:completedRegistration', src, identity)
        playerIdentity[identifier] = nil
        if cb then cb(true) end
    else
        TriggerClientEvent('westside_identity:registrationComplete', src, false, 'تم حدوث خطأ أثناء حفظ الهوية')
        if cb then cb(false) end
    end
end

local function openRegistrationFor(src)
    TriggerClientEvent('westside_identity:showRegisterIdentity', src)
end

local function initialiseIdentityFor(sourceId, identifier)
    local identity, registered = fetchIdentityFromDatabase(identifier)
    if registered then
        alreadyRegistered[identifier] = true
        local xPlayer = ESX.GetPlayerFromId(sourceId)
        if identity and xPlayer then
            setPlayerData(xPlayer, identity)
        elseif identity then
            playerIdentity[identifier] = identity
        end
        if identity then
            TriggerClientEvent('westside_identity:setPlayerData', sourceId, identity)
        end
        TriggerClientEvent('westside_identity:alreadyRegistered', sourceId)
        playerIdentity[identifier] = nil
    else
        alreadyRegistered[identifier] = false
        openRegistrationFor(sourceId)
    end
end

if not multichar then
    AddEventHandler('playerConnecting', function(_, _, deferrals)
        deferrals.defer()
        local src = source
        Wait(50)

        local identifier = ESX.GetIdentifier(src)
        if not identifier then
            deferrals.done(TranslateCap('no_identifier'))
            return
        end

        local identity, registered = fetchIdentityFromDatabase(identifier)
        if registered then
            playerIdentity[identifier] = identity
        else
            playerIdentity[identifier] = nil
        end
        alreadyRegistered[identifier] = registered

        deferrals.done()
    end)
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    Wait(500)
    local xPlayers = ESX.GetExtendedPlayers()
    for i = 1, #xPlayers do
        local xPlayer = xPlayers[i]
        if xPlayer then
            local identifier = xPlayer.getIdentifier()
            initialiseIdentityFor(xPlayer.source, identifier)
        end
    end
end)

RegisterNetEvent('esx:playerLoaded', function(_, xPlayer)
    if not xPlayer then return end

    local identifier = xPlayer.getIdentifier()
    local cachedIdentity = playerIdentity[identifier]
    local identity, registered = fetchIdentityFromDatabase(identifier)

    if cachedIdentity then
        identity = cachedIdentity
        registered = true
    end

    alreadyRegistered[identifier] = registered

    if registered then
        if identity then
            setPlayerData(xPlayer, identity)
            TriggerClientEvent('westside_identity:setPlayerData', xPlayer.source, identity)
        end
        TriggerClientEvent('westside_identity:alreadyRegistered', xPlayer.source)
        playerIdentity[identifier] = nil
        return
    end
    openRegistrationFor(xPlayer.source)
end)

RegisterNetEvent('westside_identity:registerIdentity', function(payload)
    handleRegistration(source, payload)
end)

ESX.RegisterServerCallback('westside_identity:registerIdentity', function(src, cb, payload)
    handleRegistration(src, payload, cb)
end)

RegisterNetEvent('westside_identity:server:open', function(targetId)
    targetId = tonumber(targetId)
    if not targetId then return end
    if not GetPlayerName(targetId) then return end
    openRegistrationFor(targetId)
end)

exports('OpenIdentityFor', function(playerId)
    TriggerEvent('westside_identity:server:open', playerId)
end)
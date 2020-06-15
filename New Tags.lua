local module = {};

--[[
    Functions:

        - module:addTag(player, info)
        - moudle:getLastTag(player)
        - module:getTags(player)
        - module:combatReport(player)
        - module:reset()


    addTag(player, info):
        // Given an input dictionary that has keys of [TEMPLATE] (see TEMPLATE below), create a new tag for player.
        // Ex: addTag(playerA, {creator=playerB,...}
        //  This would create a tag indicating that playerB has a tag on playerA.
        RETURNS: NONE

    getLastTag(player):
        // Given a player, retrieve last tag on the player.
        // This is generally used to determine who dealt the final blow to player
        RETURNS: tag

    getTags(player):
        // Given a player, retrieve all the tags (max at SETTINGS.MAX_TAGS) that are within SETTINGS.ARCHIVE_TIME 
        //  seconds of creation.
        RETURNS: {tag1, ..., tagn}

    combatReport(player):
        // Given a player, generate a combat report:
        RETURNS: {totalDamage = 32, individual = {'12345'=20, '9999'=12}}

    reset():
        // Resets the tags and damage trackers. Use this after the game ends so module can be recycled.
        RETURNS: NONE
]] -- 




local tags = {};
local damageStats = {};

local SETTINGS = {
    MAX_TAGS = 50;
    MAX_SEARCH = 3;
    ARCHIVE_TIME = 60*2; -- Currently two minutes
};

--[[
    REQUIRED INFO:

    1. Creator - cxcharlie
    2. Creation Time - tick()
    3. Damage - 32
    4. Timeout - 30
    5. Type - Sin
    6. Type2 - Wack1
    7. Hit Part - Left Arm
]]--

-- Idea: Create a mapping of the dictionary indices to numerical ones, so we don't have to store these string values
local MAPPING = {};
local TEMPLATE = {
    'creator',  
    'creationTime',
    'damage',
    'timeout',
    'type',
    'type2',
    'hitPart'
};

for index, value in pairs(TEMPLATE) do
    MAPPING[value] = index;
end

local function createTag(info)
    if info then
        local newTag = {};
        for index, value in pairs(info) do
            newTag[MAPPING[index]] = value;
        end
        newTag[MAPPING['creationTime']] = tick();
        return newTag;
    end
end

function module:addTag(player, info)
    if tags[player] == nil then
        local newTagList = {};
        tags[player] = newTagList;
    end

    local playerTags = tags[player];

    -- Open up some space
    while (#playerTags >= SETTINGS.MAX_TAGS) do
        table.remove(playerTags, 1);
    end

    -- This helps us compress tags if they're repeat attacks within reasonable amount of time
    local pointerPos = #playerTags;
    local decrements = 0;
    local now = tick();
    while pointerPos >= 1 and decrements < SETTINGS.MAX_SEARCH do
        local current = playerTags[pointerPos];
        if current[MAPPING.creator] == info.creator and current[MAPPING.type2] == info.type2 and
                now - current[MAPPING.creationTime] < current[MAPPING.timeout] then
            info.damage = info.damage + current[MAPPING.damage];
            table.remove(playerTags, pointerPos);
            break;
         end
        decrements = decrements + 1;
        pointerPos = pointerPos - 1;
    end

    table.insert(playerTags, createTag(info));

    -- Keeping track of overall combat stats
    local dStats = damageStats[info.creator]
    if dStats == nil then
        damageStats[info.creator] = {};
        dStats = damageStats[info.creator];
        dStats[tostring(player.UserId)] = 0;
    end

    -- Increment total damage dealt
    dStats[tostring(player.UserId)] = dStats[tostring(player.UserId)] + info.damage;
end

function module:getLastTag(player)
    local tags = tags[player];
    if tags then
        local lastTag = tags[#tags];
        local info = {};
        for index, value in pairs(TEMPLATE) do
            info[value] = lastTag[index];
        end
        return info;
    end
    return nil;
end

function module:getTags(player)
    local tags = tags[player];
    if tags then
        local now = tick();
        local valid = {};
        for _, v in pairs(tags) do
            if now - v[MAPPING.creationTIme] < v[MAPPING.timeout] then
                local verbose = {};
                for index, name in pairs(MAPPING) do
                    verbose[name] = v[index];
                end
                table.insert(valid, verbose);
            end
        end
        return valid;
    end
    return nil;
end

-- Allows you to see each player's total damage inflicted on other players
function module:combatReport(player)
    local data = damageStats[player];
    if data then
        local totalDamage = 0;
        for id, damage in pairs(data) do
            totalDamage = totalDamage + damage;
        end
        local report = {};
        report.totalDamage = totalDamage;
        report.individual = data;
        return report;
    end
    return nil;
end

function module:reset()
    tags = {};
    damageStats = {};
end


return module
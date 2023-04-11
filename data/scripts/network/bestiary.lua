local START_STORAGE_ID = 1000000
local PARTY_MEMBERS_ENABLED = false

function Player.getUnlockedBestiary(self, monsterTypes)
    local count = 0
    for _, monsterType in pairs(monsterTypes) do
        local info = monsterType:getBestiaryInfo()
        if info.raceId ~= 0 then
            if self:getStorageValue(START_STORAGE_ID + info.raceId) >= info.firstUnlock then
                count = count + 1
            end
        end
    end
    return count
end

function Player.getBestiaryKills(self, raceId)
    return math.max(0, self:getStorageValue(START_STORAGE_ID + raceId))
end

function Player.addBestiaryKill(self, raceId)
    return self:setStorageValue(START_STORAGE_ID + raceId, self:getBestiaryKills(raceId) + 1)
end

function Player.getProgressStatus(self, info)
    local killAmount = self:getBestiaryKills(info.raceId)
    if killAmount == 0 then
        return 0
    elseif killAmount < info.firstUnlock then
        return 1
    elseif killAmount < info.secondUnlock then
        return 2
    elseif killAmount < info.finishUnlock then
        return 3
    end
    return 4
end

local handler = PacketHandler(0xE1)

function handler.onReceive(player)
    local bestiary = Game.getBestiary()
    local msg = NetworkMessage()
    msg:addByte(0xD5)
    msg:addU16(bestiary.classesCount)
    for className, monsterTypes in pairs(bestiary.classes) do
        msg:addString(className)
        msg:addU16(#monsterTypes)
        msg:addU16(player:getUnlockedBestiary(monsterTypes))
    end

    msg:sendToPlayer(player)
    msg:delete()
end

handler:register()

local monsterTypesByRaceId = {}
addEvent(function()
    local bestiary = Game.getBestiary()
    for _, monsterTypes in pairs(bestiary.classes) do
        for _, monsterType in pairs(monsterTypes) do
            local info = monsterType:getBestiaryInfo()
            if info.raceId ~= 0 then
                monsterTypesByRaceId[info.raceId] = monsterType
            end
        end
    end
end, 100)

local handler = PacketHandler(0xE2)

function handler.onReceive(player, msg)
    local bestiary = Game.getBestiary()
    local monsterTypes = {}
    local className = ""
    local search = msg:getByte() == 1
    if search then
        local amount = msg:getU16()
        for i = 1, amount do
            local raceId = msg:getU16()
            local monsterType = monsterTypesByRaceId[raceId]
            if monsterType and player:getBestiaryKills(raceId) > 0 then
                monsterTypes[#monsterTypes + 1] = monsterType
            end
        end
    else
        className = msg:getString()
        monsterTypes = bestiary.classes[className]
    end

    if #monsterTypes == 0 then
        return
    end

    local response = NetworkMessage()
    response:addByte(0xD6)
    response:addString(className)
    response:addU16(#monsterTypes)

    for _, monsterType in pairs(monsterTypes) do
        local info = monsterType:getBestiaryInfo()
        response:addU16(info.raceId)
        response:addU16(player:getProgressStatus(info))
    end

    response:sendToPlayer(player)
    response:delete()
end

handler:register()

local function getDifficulty(chance)
    if chance < 200 then
        return 4
    elseif chance < 1000 then
        return 3
    elseif chance < 5000 then
        return 2
    elseif chance < 25000 then
        return 1
    end
    return 0
end

local handler = PacketHandler(0xE3)

function handler.onReceive(player, msg)
    local raceId = msg:getU16()
    local monsterType = monsterTypesByRaceId[raceId]
    if not monsterType then
        return
    end

    local info = monsterType:getBestiaryInfo()
    local kills = player:getBestiaryKills(raceId)
    local progress = player:getProgressStatus(info)

    local response = NetworkMessage()
    response:addByte(0xD7)
    response:addU16(raceId)
    response:addString(info.class)
    response:addByte(progress)
    response:addU32(kills)

    response:addU16(info.firstUnlock)
    response:addU16(info.secondUnlock)
    response:addU16(info.finishUnlock)

    response:addByte(info.stars)
    response:addByte(info.occurrence)

    local loot = monsterType:getLoot()
    response:addByte(#loot)

    for _, lootItem in pairs(loot) do
        local difficulty = getDifficulty(lootItem.chance)
        local knowLoot = difficulty <= progress
        local itemType = ItemType(lootItem.itemId)
        response:addU16(knowLoot and itemType:getClientId() or 0)
        response:addByte(difficulty)
        response:addByte(0) -- 1 = event loot, 0 = normal loot
        if knowLoot then
            response:addString(itemType:getName())
            response:addByte(lootItem.maxCount > 1 and 1 or 0)
        end
    end

    if progress > 1 then
        response:addU16(info.charmPoints)
        response:addByte(monsterType:isHostile() and 2 or 1)
        response:addByte(2)
        response:addU32(monsterType:getMaxHealth())
        response:addU32(monsterType:getExperience())
        response:addU16(monsterType:getBaseSpeed())
        response:addU16(monsterType:getArmor())
    end

    if progress > 2 then
        local elements = monsterType:getElementList()
        response:addByte(#elements)
        for combatType, value in pairs(elements) do
            response:addByte(combatType)
            response:addU16(value)
        end

        response:addU16(1)
        response:addString(info.locations)
    end

    if progress > 3 then
        response:addByte(0)
        response:addByte(1)
    end

    response:sendToPlayer(player)
    response:delete()
end

handler:register()

function Player.sendBestiaryMilestoneReached(self, raceId)
    local msg = NetworkMessage()
    msg:addByte(0xD9)
    msg:addU16(raceId)
    msg:sendToPlayer(self)
    msg:delete()
    return true
end

local function addKill(player, monsterName, raceId, unlockLimits)
    local oldKills = player:getBestiaryKills()
    player:addBestiaryKill(raceId)
    local newKills = player:getBestiaryKills()
    for _, limit in pairs(unlockLimits) do
        if oldKills < limit and newKills >= limit then
            player:sendTextMessage(MESSAGE_EVENT_DEFAULT, string.format("You unlocked details for the creature %s.", monsterName))
            player:sendBestiaryMilestoneReached(raceId)
            break
        end
    end
end

local killCounter = CreatureEvent("Bestiary")

function killCounter.onKill(player, target)
    local monster = target:getMonster()
    if not monster then
        return true
    end

    local info = monster:getType():getBestiaryInfo()
    if info.raceId == 0 then
        return true
    end

    local monsterName = monster:getName()
    local unlockLimits = {info.firstUnlock, info.secondUnlock, info.finishUnlock}
    if PARTY_MEMBERS_ENABLED then
        local party = player:getParty()
        if party then
            for _, member in pairs(party:getMembers()) do
                addKill(member, monsterName, info.raceId, unlockLimits)
            end

            addKill(party:getLeader(), monsterName, info.raceId, unlockLimits)
            return true
        end
    end

    addKill(player, monsterName, info.raceId, unlockLimits)
    return true
end

killCounter:register()

local autoRegister = CreatureEvent("BestiaryLogin")

function autoRegister.onLogin(player)
    player:registerEvent("Bestiary")
    return true
end

autoRegister:register()

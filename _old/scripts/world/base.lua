stateHelper = require("stateHelper")
local BaseWorld = class("BaseWorld")

BaseWorld.defaultTimeScale = 30
BaseWorld.monthLengths = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

function BaseWorld:__init()

    self.data =
    {
        general = {
            currentMpNum = 0
        },
        fame = {
            bounty = 0,
            reputation = 0
        },
        journal = {},
        factionRanks = {},
        factionExpulsion = {},
        factionReputation = {},
        topics = {},
        kills = {},
        time = config.defaultTimeTable,
        mapExplored = {},
        customVariables = {}
    };
end

function BaseWorld:HasEntry()
    return self.hasEntry
end

function BaseWorld:EnsureTimeDataExists()

    if self.data.time == nil then
        self.data.time = config.defaultTimeTable
    end
end

function BaseWorld:IncrementDay()

    self.data.time.daysPassed = self.data.time.daysPassed + 1

    local day = self.data.time.day
    local month = self.data.time.month

    -- Is the new day higher than the number of days in the current month?
    if day + 1 > self.monthLengths[month] then

        -- Is the new month higher than the number of months in a year?
        if month + 1 > 12 then
            self.data.time.year = self.data.time.year + 1
            self.data.time.month = 1
        else
            self.data.time.month = month + 1            
        end

        self.data.time.day = 1
    else

        self.data.time.day = day + 1
    end
end

function BaseWorld:GetCurrentMpNum()
    return self.data.general.currentMpNum
end

function BaseWorld:SetCurrentMpNum(currentMpNum)
    self.data.general.currentMpNum = currentMpNum
    self:Save()
end

function BaseWorld:LoadJournal(pid)
    stateHelper:LoadJournal(pid, self)
end

function BaseWorld:LoadFactionRanks(pid)
    stateHelper:LoadFactionRanks(pid, self)
end

function BaseWorld:LoadFactionExpulsion(pid)
    stateHelper:LoadFactionExpulsion(pid, self)
end

function BaseWorld:LoadFactionReputation(pid)
    stateHelper:LoadFactionReputation(pid, self)
end

function BaseWorld:LoadTopics(pid)
    stateHelper:LoadTopics(pid, self)
end

function BaseWorld:LoadBounty(pid)
    stateHelper:LoadBounty(pid, self)
end

function BaseWorld:LoadReputation(pid)
    stateHelper:LoadReputation(pid, self)
end

function BaseWorld:LoadMap(pid)
    stateHelper:LoadMap(pid, self)
end

function BaseWorld:LoadKills(pid)

    tes3mp.InitializeKillChanges(pid)

    for refId, number in pairs(self.data.kills) do

        tes3mp.AddKill(pid, refId, number)
    end

    tes3mp.SendKillChanges(pid)
end

function BaseWorld:LoadTime(pid, sendToOthers)

    tes3mp.SetHour(self.data.time.hour)
    tes3mp.SetDay(self.data.time.day)

    -- The first month has an index of 0 in the C++ code, but
    -- table values should be intuitive and range from 1 to 12,
    -- so adjust for that by just going down by 1
    tes3mp.SetMonth(self.data.time.month - 1)

    tes3mp.SetYear(self.data.time.year)

    tes3mp.SetDaysPassed(self.data.time.daysPassed)
    tes3mp.SetTimeScale(self.data.time.timeScale)

    tes3mp.SendWorldTime(pid, sendToOthers)
end

function BaseWorld:SaveJournal(pid)
    stateHelper:SaveJournal(pid, self)
end

function BaseWorld:SaveFactionRanks(pid)
    stateHelper:SaveFactionRanks(pid, self)
end

function BaseWorld:SaveFactionExpulsion(pid)
    stateHelper:SaveFactionExpulsion(pid, self)
end

function BaseWorld:SaveFactionReputation(pid)
    stateHelper:SaveFactionReputation(pid, self)
end

function BaseWorld:SaveTopics(pid)
    stateHelper:SaveTopics(pid, self)
end

function BaseWorld:SaveBounty(pid)
    stateHelper:SaveBounty(pid, self)
end

function BaseWorld:SaveReputation(pid)
    stateHelper:SaveReputation(pid, self)
end

function BaseWorld:SaveKills(pid)

    for i = 0, tes3mp.GetKillChangesSize(pid) - 1 do

        local refId = tes3mp.GetKillRefId(pid, i)
        local number = tes3mp.GetKillNumber(pid, i)
        self.data.kills[refId] = number
    end

    self:Save()
end

function BaseWorld:SaveMapExploration(pid)
    stateHelper:SaveMapExploration(pid, self)
end

function BaseWorld:SaveMapTiles(pid)

    tes3mp.ReadLastWorldstate()

    for index = 0, tes3mp.GetMapChangesSize() - 1 do

        local cellX = tes3mp.GetMapTileCellX(index)
        local cellY = tes3mp.GetMapTileCellY(index)
        local filename = cellX .. ", " .. cellY .. ".png"

        tes3mp.SaveMapTileImageFile(index, os.getenv("MOD_DIR") .. "/map/" .. filename)
    end
end

return BaseWorld

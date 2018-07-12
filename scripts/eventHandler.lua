local eventHandler = {}

eventHandler.OnPlayerConnect = function(pid, playerName)

    WorldInstance:LoadTime(pid, false)

    tes3mp.SetDifficulty(pid, config.difficulty)
    tes3mp.SetConsoleAllowed(pid, config.allowConsole)
    tes3mp.SetBedRestAllowed(pid, config.allowBedRest)
    tes3mp.SetWildernessRestAllowed(pid, config.allowWildernessRest)
    tes3mp.SetWaitAllowed(pid, config.allowWait)
    tes3mp.SetPhysicsFramerate(pid, config.physicsFramerate)
    tes3mp.SetEnforcedLogLevel(pid, config.enforcedLogLevel)
    tes3mp.SendSettings(pid)

    tes3mp.SetPlayerCollisionState(config.enablePlayerCollision)
    tes3mp.SetActorCollisionState(config.enableActorCollision)
    tes3mp.SetPlacedObjectCollisionState(config.enablePlacedObjectCollision)
    tes3mp.UseActorCollisionForPlacedObjects(config.useActorCollisionForPlacedObjects)

    logicHandler.SendConfigCollisionOverrides(pid, false)

    Players[pid] = Player(pid, playerName)
    Players[pid].name = playerName

    local message = logicHandler.GetChatName(pid) .. " joined the server.\n"
    tes3mp.SendMessage(pid, message, true)

    message = "Welcome " .. playerName .. "\nYou have " .. tostring(config.loginTime) ..
        " seconds to"

    if Players[pid]:HasAccount() then
        message = message .. " log in.\n"
        GUI.ShowLogin(pid)
    else
        message = message .. " register.\n"
        GUI.ShowRegister(pid)
    end

    tes3mp.SendMessage(pid, message, false)

    Players[pid].loginTimerId = tes3mp.CreateTimerEx("OnLoginTimeExpiration",
        time.seconds(config.loginTime), "i", pid)
    tes3mp.StartTimer(Players[pid].loginTimerId)
end

eventHandler.OnPlayerDisconnect = function(pid)

    if Players[pid] ~= nil then

        -- Unload every cell for this player
        for index, loadedCellDescription in pairs(Players[pid].cellsLoaded) do

            logicHandler.UnloadCellForPlayer(pid, loadedCellDescription)
        end

        Players[pid]:Destroy()
        Players[pid] = nil
    end
end

eventHandler.OnGUIAction = function(pid, idGui, data)
    data = tostring(data) -- data can be numeric, but we should convert this to string

    if idGui == GUI.ID.LOGIN then
        if data == nil then
            Players[pid]:Message("Incorrect password!\n")
            GUI.ShowLogin(pid)
            return true
        end

        Players[pid]:Load()

        -- Just in case the password from the data file is a number, make sure to turn it into a string
        if tostring(Players[pid].data.login.password) ~= data then
            Players[pid]:Message("Incorrect password!\n")
            GUI.ShowLogin(pid)
            return true
        end

        -- Is this player on the banlist? If so, store their new IP and ban them
        if tableHelper.containsValue(banList.playerNames, string.lower(Players[pid].accountName)) == true then
            Players[pid]:SaveIpAddress()

            Players[pid]:Message(Players[pid].accountName .. " is banned from this server.\n")
            tes3mp.BanAddress(tes3mp.GetIP(pid))
        else
            Players[pid]:FinishLogin()
            Players[pid]:Message("You have successfully logged in.\n")
        end
    elseif idGui == GUI.ID.REGISTER then
        if data == nil then
            Players[pid]:Message("Password can not be empty\n")
            GUI.ShowRegister(pid)
            return true
        end
        Players[pid]:Registered(data)
        Players[pid]:Message("You have successfully registered.\nUse Y by default to chat or " ..
            "change it from your client config.\n")

    elseif idGui == config.customMenuIds.confiscate and Players[pid].confiscationTargetName ~= nil then

        local targetName = Players[pid].confiscationTargetName
        local targetPlayer = logicHandler.GetPlayerByName(targetName)

        -- Because the window's item index starts from 0 while the Lua table for
        -- inventories starts from 1, adjust the former here
        local inventoryItemIndex = data + 1
        local item = targetPlayer.data.inventory[inventoryItemIndex]

        if item ~= nil then
        
            table.insert(Players[pid].data.inventory, item)
            Players[pid]:LoadInventory()
            Players[pid]:LoadEquipment()

            -- If the item is equipped by the target, unequip it first
            if inventoryHelper.containsItem(targetPlayer.data.equipment, item.refId, item.charge) then
                local equipmentItemIndex = inventoryHelper.getItemIndex(targetPlayer.data.equipment,
                    item.refId, item.charge)
                targetPlayer.data.equipment[equipmentItemIndex] = nil
            end

            targetPlayer.data.inventory[inventoryItemIndex] = nil
            tableHelper.cleanNils(targetPlayer.data.inventory)

            Players[pid]:Message("You've confiscated " .. item.refId .. " from " ..
                targetName .. "\n")

            if targetPlayer:IsLoggedIn() then
                targetPlayer:LoadInventory()
                targetPlayer:LoadEquipment()
            end
        else
            Players[pid]:Message("Invalid item index\n")
        end

        targetPlayer:SetConfiscationState(false)
        targetPlayer:Save()

        Players[pid].confiscationTargetName = nil

    elseif idGui == config.customMenuIds.menuHelper and Players[pid].currentCustomMenu ~= nil then

        local buttonIndex = tonumber(data) + 1
        local buttonPressed = Players[pid].displayedMenuButtons[buttonIndex]

        local destination = menuHelper.getButtonDestination(pid, buttonPressed)

        menuHelper.processEffects(pid, destination.effects)
        menuHelper.displayMenu(pid, destination.targetMenu)

        Players[pid].previousCustomMenu = Players[pid].currentCustomMenu
        Players[pid].currentCustomMenu = destination.targetMenu
    end

    return false
end

eventHandler.OnPlayerMessage = function(pid, message)
    if message:sub(1,1) ~= '/' then return 1 end

    local cmd = (message:sub(2, #message)):split(" ")

    if cmd[1] == "register" or cmd[1] == "reg" then
        if Players[pid]:IsLoggedIn() then
            Players[pid]:Message("You are already logged in.\n")
            return false
        elseif Players[pid]:HasAccount() then
            Players[pid]:Message("You already have an account. Try \"/login password\".\n")
            return false
        elseif cmd[2] == nil then
            Players[pid]:Message("Incorrect password!\n")
            return false
        end
        Players[pid]:Registered(cmd[2])
        return false
    elseif cmd[1] == "login" then
        if Players[pid]:IsLoggedIn() then
            Players[pid]:Message("You are already logged in.\n")
            return false
        elseif not Players[pid]:HasAccount() then
            Players[pid]:Message("You do not have an account. Try \"/register password\".\n")
            return 0
        elseif cmd[2] == nil then
            Players[pid]:Message("Password cannot be empty\n")
            return false
        end
        Players[pid]:Load()
        -- Just in case the password from the data file is a number, make sure to turn it
        -- into a string
        if tostring(Players[pid].data.login.password) ~= cmd[2] then
            Players[pid]:Message("Incorrect password!\n")
            return false
        end
        Players[pid]:FinishLogin()
        return false
    end

    return true
end

eventHandler.OnPlayerDeath = function(pid)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        Players[pid]:ProcessDeath()
    end
end

eventHandler.OnDeathTimeExpiration = function(pid)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        Players[pid]:Resurrect()
    end
end

eventHandler.OnPlayerAttribute = function(pid)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        Players[pid]:SaveAttributes()
    end
end

eventHandler.OnPlayerSkill = function(pid)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        Players[pid]:SaveSkills()
    end
end

eventHandler.OnPlayerLevel = function(pid)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        Players[pid]:SaveLevel()
        Players[pid]:SaveStatsDynamic()
    end
end

eventHandler.OnPlayerShapeshift = function(pid)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        Players[pid]:SaveShapeshift()
    end
end

eventHandler.OnPlayerCellChange = function(pid)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then

        if contentFixer.ValidateCellChange(pid) then
            Players[pid]:SaveCell()
            Players[pid]:SaveStatsDynamic()
            tes3mp.LogMessage(1, "Saving player " .. pid)
            Players[pid]:Save()

            if config.shareMapExploration == true then
                WorldInstance:SaveMapExploration(pid)
            end
        else
            Players[pid].data.location.posX = tes3mp.GetPreviousCellPosX(pid)
            Players[pid].data.location.posY = tes3mp.GetPreviousCellPosY(pid)
            Players[pid].data.location.posZ = tes3mp.GetPreviousCellPosZ(pid)
            Players[pid]:LoadCell()
        end
    end
end

eventHandler.OnPlayerEndCharGen = function(pid)
    if Players[pid] ~= nil then
        Players[pid]:EndCharGen()
    end
end

eventHandler.OnPlayerEquipment = function(pid)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        Players[pid]:SaveEquipment()
    end
end

eventHandler.OnPlayerInventory = function(pid)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        Players[pid]:SaveInventory()
    end
end

eventHandler.OnPlayerSpellbook = function(pid)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then

        local action = tes3mp.GetSpellbookChangesAction(pid)

        if action == enumerations.spellbook.SET then
            Players[pid]:SetSpells()
        elseif action == enumerations.spellbook.ADD then
            Players[pid]:AddSpells()
        elseif action == enumerations.spellbook.REMOVE then
            Players[pid]:RemoveSpells()
        end
    end
end

eventHandler.OnPlayerQuickKeys = function(pid)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        Players[pid]:SaveQuickKeys()
    end
end

eventHandler.OnPlayerJournal = function(pid)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then

        if config.shareJournal == true then
            WorldInstance:SaveJournal(pid)

            -- Send this PlayerJournal packet to other players (sendToOthersPlayers is true),
            -- but skip sending it to the player we got it from (skipAttachedPlayer is true)
            tes3mp.SendJournalChanges(pid, true, true)
        else
            Players[pid]:SaveJournal()
        end
    end
end

eventHandler.OnPlayerFaction = function(pid)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then

        local action = tes3mp.GetFactionChangesAction(pid)

        if action == enumerations.faction.RANK then
            if config.shareFactionRanks == true then

                WorldInstance:SaveFactionRanks(pid)
                -- Send this PlayerFaction packet to other players (sendToOthersPlayers is true),
                -- but skip sending it to the player we got it from (skipAttachedPlayer is true)
                tes3mp.SendFactionChanges(pid, true, true)
            else
                Players[pid]:SaveFactionRanks()
            end
        elseif action == enumerations.faction.EXPULSION then
            if config.shareFactionExpulsion == true then

                WorldInstance:SaveFactionExpulsion(pid)
                -- As above, send this to everyone other than the original sender
                tes3mp.SendFactionChanges(pid, true, true)
            else
                Players[pid]:SaveFactionExpulsion()
            end
        elseif action == enumerations.faction.REPUTATION then
            if config.shareFactionReputation == true then
                WorldInstance:SaveFactionReputation(pid)

                -- As above, send this to everyone other than the original sender
                tes3mp.SendFactionChanges(pid, true, true)
            else
                Players[pid]:SaveFactionReputation()
            end
        end
    end
end

eventHandler.OnPlayerTopic = function(pid)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then

        if config.shareTopics == true then

            WorldInstance:SaveTopics(pid)
            -- Send this PlayerTopic packet to other players (sendToOthersPlayers is true),
            -- but skip sending it to the player we got it from (skipAttachedPlayer is true)
            tes3mp.SendTopicChanges(pid, true, true)
        else
            Players[pid]:SaveTopics()
        end
    end
end

eventHandler.OnPlayerBounty = function(pid)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then

        if config.shareBounty == true then
            WorldInstance:SaveBounty(pid)

            -- Bounty packets are special in that they are always sent
            -- to all players, but only affect their target player on
            -- any given client
            --
            -- To set the same bounty for each LocalPlayer, we need
            -- to separately set each player as the target and
            -- send the packet
            local bountyValue = tes3mp.GetBounty(pid)

            for playerIndex, player in pairs(Players) do
                if player.pid ~= pid then
                    tes3mp.SetBounty(player.pid, bountyValue)
                    tes3mp.SendBounty(player.pid)
                end
            end
        else
            Players[pid]:SaveBounty()
        end
    end
end

eventHandler.OnPlayerReputation = function(pid)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then

        if config.shareReputation == true then

            WorldInstance:SaveReputation(pid)
            -- Send this PlayerReputation packet to other players (sendToOthersPlayers is true),
            -- but skip sending it to the player we got it from (skipAttachedPlayer is true)
            tes3mp.SendReputation(pid, true, true)
        else
            Players[pid]:SaveReputation()
        end
    end
end

eventHandler.OnPlayerKillCount = function(pid)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        WorldInstance:SaveKills(pid)
    end
end

eventHandler.OnPlayerBook = function(pid)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        Players[pid]:AddBooks()
    end
end

eventHandler.OnPlayerMiscellaneous = function(pid)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        local changeType = tes3mp.GetMiscellaneousChangeType(pid)

        if changeType == enumerations.miscellaneous.MARK_LOCATION then
            Players[pid]:SaveMarkLocation()
        elseif changeType == enumerations.miscellaneous.SELECTED_SPELL then
            Players[pid]:SaveSelectedSpell()
        end
    end
end

eventHandler.OnCellLoad = function(pid, cellDescription)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        logicHandler.LoadCellForPlayer(pid, cellDescription)
    else
        tes3mp.LogMessage(2, "Undefined behavior: invalid player " .. pid ..
            " loaded cell " .. cellDescription)
    end
end

eventHandler.OnCellUnload = function(pid, cellDescription)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        logicHandler.UnloadCellForPlayer(pid, cellDescription)
    end
end

eventHandler.OnCellDeletion = function(cellDescription)
    logicHandler.UnloadCell(cellDescription)
end

eventHandler.OnActorList = function(pid, cellDescription)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        if LoadedCells[cellDescription] ~= nil then
            LoadedCells[cellDescription]:SaveActorList(pid)
        else
            tes3mp.LogMessage(2, "Undefined behavior: " .. logicHandler.GetChatName(pid) ..
                " sent ActorList for unloaded " .. cellDescription)
        end
    else
        tes3mp.Kick(pid)
    end
end

eventHandler.OnActorEquipment = function(pid, cellDescription)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        if LoadedCells[cellDescription] ~= nil then
            LoadedCells[cellDescription]:SaveActorEquipment(pid)
        else
            tes3mp.LogMessage(2, "Undefined behavior: " .. logicHandler.GetChatName(pid) ..
                " sent ActorEquipment for unloaded " .. cellDescription)
        end
    else
        tes3mp.Kick(pid)
    end
end

eventHandler.OnActorAI = function(pid, cellDescription)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        if LoadedCells[cellDescription] ~= nil then
            LoadedCells[cellDescription]:ProcessActorAI(pid)
        else
            tes3mp.LogMessage(2, "Undefined behavior: " .. logicHandler.GetChatName(pid) ..
                " sent ActorAI for unloaded " .. cellDescription)
        end
    else
        tes3mp.Kick(pid)
    end
end

eventHandler.OnActorDeath = function(pid, cellDescription)
    if LoadedCells[cellDescription] ~= nil then
        LoadedCells[cellDescription]:SaveActorDeath(pid)
    else
        tes3mp.LogMessage(2, "Undefined behavior: " .. logicHandler.GetChatName(pid) ..
            " sent ActorDeath for unloaded " .. cellDescription)
    end
end

eventHandler.OnActorCellChange = function(pid, cellDescription)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        if LoadedCells[cellDescription] ~= nil then
            LoadedCells[cellDescription]:SaveActorCellChanges(pid)
        else
            tes3mp.LogMessage(2, "Undefined behavior: " .. logicHandler.GetChatName(pid) ..
                " sent ActorCellChange for unloaded " .. cellDescription)
        end
    else
        tes3mp.Kick(pid)
    end
end

eventHandler.OnObjectPlace = function(pid, cellDescription)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        if LoadedCells[cellDescription] ~= nil then
            LoadedCells[cellDescription]:ProcessObjectsPlaced(pid)
        else
            tes3mp.LogMessage(2, "Undefined behavior: " .. logicHandler.GetChatName(pid) ..
                " sent ObjectPlace for unloaded " .. cellDescription)
        end
    else
        tes3mp.Kick(pid)
    end
end

eventHandler.OnObjectSpawn = function(pid, cellDescription)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        if LoadedCells[cellDescription] ~= nil then
            LoadedCells[cellDescription]:ProcessObjectsSpawned(pid)
        else
            tes3mp.LogMessage(2, "Undefined behavior: " .. logicHandler.GetChatName(pid) ..
                " sent ObjectSpawn for unloaded " .. cellDescription)
        end
    else
        tes3mp.Kick(pid)
    end
end

eventHandler.OnObjectDelete = function(pid, cellDescription)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        if LoadedCells[cellDescription] ~= nil then
            LoadedCells[cellDescription]:ProcessObjectsDeleted(pid)
        else
            tes3mp.LogMessage(2, "Undefined behavior: " .. logicHandler.GetChatName(pid) ..
                " sent ObjectDelete for unloaded " .. cellDescription)
        end
    else
        tes3mp.Kick(pid)
    end
end

eventHandler.OnObjectLock = function(pid, cellDescription)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        if LoadedCells[cellDescription] ~= nil then
            LoadedCells[cellDescription]:ProcessObjectsLocked(pid)
        else
            tes3mp.LogMessage(2, "Undefined behavior: " .. logicHandler.GetChatName(pid) ..
                " sent ObjectLock for unloaded " .. cellDescription)
        end
    end
end

eventHandler.OnObjectTrap = function(pid, cellDescription)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        if LoadedCells[cellDescription] ~= nil then
            LoadedCells[cellDescription]:ProcessObjectTrapsTriggered(pid)
        else
            tes3mp.LogMessage(2, "Undefined behavior: " .. logicHandler.GetChatName(pid) ..
                " sent ObjectTrap for unloaded " .. cellDescription)
        end
    else
        tes3mp.Kick(pid)
    end
end

eventHandler.OnObjectScale = function(pid, cellDescription)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        if LoadedCells[cellDescription] ~= nil then
            LoadedCells[cellDescription]:ProcessObjectsScaled(pid)
        else
            tes3mp.LogMessage(2, "Undefined behavior: " .. logicHandler.GetChatName(pid) ..
                " sent ObjectScale for unloaded " .. cellDescription)
        end
    else
        tes3mp.Kick(pid)
    end
end

eventHandler.OnObjectState = function(pid, cellDescription)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        local shouldUnload = false

        if LoadedCells[cellDescription] == nil then
            logicHandler.LoadCell(cellDescription)
            shouldUnload = true
        end

        LoadedCells[cellDescription]:ProcessObjectStates(pid)

        if shouldUnload == true then
            logicHandler.UnloadCell(cellDescription)
        end
    else
        tes3mp.Kick(pid)
    end
end

eventHandler.OnDoorState = function(pid, cellDescription)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        if LoadedCells[cellDescription] ~= nil then
            LoadedCells[cellDescription]:SaveDoorStates(pid)
        else
            tes3mp.LogMessage(2, "Undefined behavior: " .. logicHandler.GetChatName(pid) ..
                " sent DoorState for unloaded " .. cellDescription)
        end
    else
        tes3mp.Kick(pid)
    end
end

eventHandler.OnContainer = function(pid, cellDescription)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        if LoadedCells[cellDescription] ~= nil then
            LoadedCells[cellDescription]:ProcessContainers(pid)
        else
            tes3mp.LogMessage(2, "Undefined behavior: " .. logicHandler.GetChatName(pid) ..
                " sent Container for " .. cellDescription)
        end
    else
        tes3mp.Kick(pid)
    end
end

eventHandler.OnVideoPlay = function(pid)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then

        if config.shareVideos == true then
            tes3mp.LogMessage(2, "Sharing VideoPlay from " .. pid)

            tes3mp.ReadReceivedObjectList()

            for i = 0, tes3mp.GetObjectListSize() - 1 do
                local videoFilename = tes3mp.GetVideoFilename(i)
                tes3mp.LogAppend(2, "- videoFilename " .. videoFilename)
            end

            tes3mp.CopyReceivedObjectListToStore()

            -- Send this VideoPlay packet to other players (sendToOthersPlayers is true),
            -- but skip sending it to the player we got it from (skipAttachedPlayer is true)
            tes3mp.SendVideoPlay(true, true)
        end
    end
end

eventHandler.OnWorldMap = function(pid)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        WorldInstance:SaveMapTiles(pid)

        if config.shareMapExploration == true then
            tes3mp.CopyReceivedWorldstateToStore()

            -- Send this WorldMap packet to other players (sendToOthersPlayers is true),
            -- but skip sending it to the player we got it from (skipAttachedPlayer is true)
            tes3mp.SendWorldMap(pid, true, true)
        end
    end
end

eventHandler.OnMpNumIncrement = function(currentMpNum)
    WorldInstance:SetCurrentMpNum(currentMpNum)
end

eventHandler.OnObjectLoopTimeExpiration = function(loopIndex)
    if ObjectLoops[loopIndex] ~= nil then

        local loop = ObjectLoops[loopIndex]
        local pid = loop.targetPid
        local loopEnded = false

        if Players[pid] ~= nil and Players[pid]:IsLoggedIn() and
            Players[pid].accountName == loop.targetName then
        
            if loop.packetType == "place" or loop.packetType == "spawn" then
                logicHandler.CreateObjectAtPlayer(pid, loop.refId, loop.packetType)
            elseif loop.packetType == "console" then
                logicHandler.RunConsoleCommandOnPlayer(pid, loop.consoleCommand)
            end

            loop.count = loop.count - 1

            if loop.count > 0 then
                ObjectLoops[loopIndex] = loop
                tes3mp.RestartTimer(loop.timerId, loop.interval)
            else
                loopEnded = true
            end
        else
            loopEnded = true
        end

        if loopEnded == true then
            ObjectLoops[loopIndex] = nil
        end
    end
end

return eventHandler
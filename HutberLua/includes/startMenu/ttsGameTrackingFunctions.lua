function boolToString(value)
    if value then
        return "true"
    end
    return "false"
end

function appendQueryParam(parts, key, value)
    if value == nil then
        return
    end
    local text = tostring(value)
    if text == "" then
        return
    end
    table.insert(parts, key .. "=" .. urlEncode(text))
end

function makeTtsGameUrl(path, params)
    local parts = {}
    for _, pair in ipairs(params) do
        appendQueryParam(parts, pair[1], pair[2])
    end
    return ttsGameApiBaseUrl .. path .. "?" .. table.concat(parts, "&")
end

function getZoneCardNameByGuidVar(guidVarName)
    local zoneGuid = Global.getVar(guidVarName)
    if not zoneGuid then
        return nil
    end

    local zoneObj = getObjectFromGUID(zoneGuid)
    if not zoneObj then
        return nil
    end

    local objects = zoneObj.getObjects()
    if not objects or #objects == 0 then
        return nil
    end

    local card = objects[1]
    if not card then
        return nil
    end

    local ok, name = pcall(function()
        return card.getName()
    end)
    if not ok or not name or name == "" then
        return nil
    end

    return name
end

function joinNonEmpty(values, separator)
    local parts = {}
    for _, value in ipairs(values) do
        if value and value ~= "" then
            table.insert(parts, value)
        end
    end
    if #parts == 0 then
        return nil
    end
    return table.concat(parts, separator)
end

function getCounterValueByGuidVar(guidVarName)
    local counterGuid = Global.getVar(guidVarName)
    if not counterGuid then
        return nil
    end

    local counterObj = getObjectFromGUID(counterGuid)
    if not counterObj or not counterObj.Counter or not counterObj.Counter.getValue then
        return nil
    end

    local ok, value = pcall(function()
        return counterObj.Counter.getValue()
    end)
    if not ok then
        return nil
    end
    return value
end

function getRoundNumber()
    local round = getCounterValueByGuidVar("gameTurnCounter_GUID")
    if round == nil then
        return nil
    end
    return tonumber(round)
end

function shouldShowEndGameButton()
    local round = getRoundNumber()
    return trackedGameId ~= nil and (not endGameSubmitted) and round ~= nil and round >= 5
end

function resetTrackedResultConfirmationState()
    resultConfirmationPending = false
    resultConfirmedRed = false
    resultConfirmedBlue = false
    trackedActionArmRed = false
    trackedActionArmBlue = false
end

function clearTrackedActionArms()
    trackedActionArmRed = false
    trackedActionArmBlue = false
end

function resetTrackedEndApprovalState()
    endApprovalPending = false
    endApprovalRequestedBy = nil
end

function captureTrackedMainPlayers()
    trackedMainRedSteamId = getTrackedPlayerSteamId("Red")
    trackedMainBlueSteamId = getTrackedPlayerSteamId("Blue")
end

function hasTwoRegisteredTrackedPlayers()
    local redId = trackedMainRedSteamId or getTrackedPlayerSteamId("Red")
    local blueId = trackedMainBlueSteamId or getTrackedPlayerSteamId("Blue")
    if redId == nil or blueId == nil then
        return false
    end
    redId = tostring(redId)
    blueId = tostring(blueId)
    if redId == "" or blueId == "" then
        return false
    end
    if redId == blueId then
        return false
    end
    return true
end

function getOtherTrackedSide(side)
    if side == "Red" then
        return "Blue"
    end
    return "Red"
end

function isTrackedGameActive()
    return inGame == true and (not endGameSubmitted) and (not resultConfirmationPending)
end

function shouldShowResultConfirmationButtons()
    if isTrackedGameActive() then
        return true
    end
    if resultConfirmationPending then
        return (not resultConfirmedRed) or (not resultConfirmedBlue)
    end
    return false
end

function shouldShowRedResultConfirmButton()
    if isTrackedGameActive() then
        return true
    end
    return shouldShowResultConfirmationButtons() and (not resultConfirmedRed)
end

function shouldShowBlueResultConfirmButton()
    if isTrackedGameActive() then
        return true
    end
    return shouldShowResultConfirmationButtons() and (not resultConfirmedBlue)
end

function setTrackedActionButtonPosition(button, side)
    local round = getRoundNumber() or 0
    local source = nil
    if round >= 5 then
        source = side == "Red" and trackedActionRoundFivePosRed or trackedActionRoundFivePosBlue
    else
        source = side == "Red" and trackedActionStartPosRed or trackedActionStartPosBlue
    end
    button.position = {source[1], source[2], source[3]}
end

function setTrackedActionButtonContent(button, side)
    setTrackedActionButtonPosition(button, side)
    if isTrackedGameActive() then
        if hasTwoRegisteredTrackedPlayers() then
            if endApprovalPending then
                if endApprovalRequestedBy == side then
                    button.label = "End Requested"
                    button.tooltip = "Waiting for other player to approve."
                else
                    button.label = "Approve End Game"
                    button.tooltip = "Approve end game request."
                end
            else
                button.label = "Request End Game"
                button.tooltip = "Ask opponent to approve end game."
            end
        else
            button.label = "Finish Game"
            button.tooltip = "Click twice to confirm."
        end
        return
    end
    button.label = "Confirm Win/Loss"
    button.tooltip = side .. " player confirms final result. Click twice to confirm."
end

function createTrackedResultConfirmButtons()
    if shouldShowRedResultConfirmButton() then
        setTrackedActionButtonContent(confirmTrackedResultRedBtn, "Red")
        self.createButton(confirmTrackedResultRedBtn)
    end
    if shouldShowBlueResultConfirmButton() then
        setTrackedActionButtonContent(confirmTrackedResultBlueBtn, "Blue")
        self.createButton(confirmTrackedResultBlueBtn)
    end
end

function getTrackedPlayerIdentifier(playerColor)
    local playerRef = Player[playerColor]
    if playerRef and playerRef.steam_id and tostring(playerRef.steam_id) ~= "" then
        return tostring(playerRef.steam_id)
    end
    if playerRef and playerRef.steam_name and playerRef.steam_name ~= "" then
        return playerRef.steam_name
    end
    return string.lower(playerColor) .. "_unknown"
end

function getTrackedPlayerSteamId(playerColor)
    local playerRef = Player[playerColor]
    if playerRef and playerRef.steam_id and tostring(playerRef.steam_id) ~= "" then
        return tostring(playerRef.steam_id)
    end
    return nil
end

function getTrackedPlayerDisplayName(playerColor)
    local playerRef = Player[playerColor]
    if playerRef and playerRef.steam_name and playerRef.steam_name ~= "" then
        return playerRef.steam_name
    end
    return nil
end

function getTrackedGameType()
    if singlesMode and singlesMode ~= "" then
        return singlesMode
    end
    return gameMode
end

function getTrackedMapSize()
    if sizeData and mapSizeSelected and sizeData[mapSizeSelected] and sizeData[mapSizeSelected].name then
        return sizeData[mapSizeSelected].name
    end
    return nil
end

function getTrackedMapSelection()
    local data = Global.getTable("ttsLastLoadedMap")
    if type(data) ~= "table" then
        return nil
    end
    return data
end

function syncTrackedSessionTable()
    local context = getTrackingContext()
    local session = {}
    if trackedGameId ~= nil then
        session.gameId = trackedGameId
    end
    if context then
        session.gameType = context.gameType
        session.mapSize = context.mapSize
    end
    Global.setTable("ttsTrackedSession", session)
end

function getTrackedScoreSheetSummary()
    local scoreSheetGuid = Global.getVar("scoresheet_GUID")
    if not scoreSheetGuid then
        return nil
    end
    local scoreSheetObj = getObjectFromGUID(scoreSheetGuid)
    if not scoreSheetObj then
        return nil
    end
    local ok, summary = pcall(function()
        return scoreSheetObj.call("getMatchSummary")
    end)
    if ok and type(summary) == "table" then
        return summary
    end
    return nil
end

function getTrackingContext()
    local missionPackName = missionPackData and missionPackData.name or nil
    local mapSelection = getTrackedMapSelection()
    local deploymentCard = getZoneCardNameByGuidVar("deploymentCardZone_GUID")
    local primaryMissionCard = getZoneCardNameByGuidVar("primaryCardZone_GUID")
    local scoreSummary = getTrackedScoreSheetSummary()
    local redSecondaryCards = joinNonEmpty({
        getZoneCardNameByGuidVar("secondary11CardZone_GUID"),
        getZoneCardNameByGuidVar("secondary12CardZone_GUID")
    }, "|")
    local blueSecondaryCards = joinNonEmpty({
        getZoneCardNameByGuidVar("secondary21CardZone_GUID"),
        getZoneCardNameByGuidVar("secondary22CardZone_GUID")
    }, "|")

    return {
        missionType = missionPackName,
        missionPack = missionPackName,
        gameType = getTrackedGameType(),
        mapSize = getTrackedMapSize(),
        mapPack = mapSelection and mapSelection.mapPack or nil,
        mapName = mapSelection and mapSelection.mapName or nil,
        mapVariant = mapSelection and mapSelection.mapVariant or nil,
        mapId = mapSelection and mapSelection.mapId or nil,
        mapLayout = mapSelection and mapSelection.mapLayout or nil,
        mapKey = mapSelection and mapSelection.mapKey or nil,
        deploymentCard = deploymentCard,
        primaryMissionCard = primaryMissionCard,
        redSecondaryCards = redSecondaryCards,
        blueSecondaryCards = blueSecondaryCards,
        round = getCounterValueByGuidVar("gameTurnCounter_GUID"),
        redTotal = getCounterValueByGuidVar("redVPCounter_GUID"),
        blueTotal = getCounterValueByGuidVar("blueVPCounter_GUID"),
        redPrimary = scoreSummary and scoreSummary.red and scoreSummary.red.primary or nil,
        redSecondary = scoreSummary and scoreSummary.red and scoreSummary.red.secondary or nil,
        redChallenger = scoreSummary and scoreSummary.red and scoreSummary.red.challenger or nil,
        bluePrimary = scoreSummary and scoreSummary.blue and scoreSummary.blue.primary or nil,
        blueSecondary = scoreSummary and scoreSummary.blue and scoreSummary.blue.secondary or nil,
        blueChallenger = scoreSummary and scoreSummary.blue and scoreSummary.blue.challenger or nil
    }
end

function resetTrackedRoundValidationCache()
    trackedRoundValidationCache = {}
end

function buildTrackedSnapshotUrl(gameId, captureSource, context, roundValue)
    return makeTtsGameUrl("/snapshot", {
        {"game_id", gameId},
        {"capture_source", captureSource},
        {"round", roundValue},
        {"red_primary", context.redPrimary},
        {"red_secondary", context.redSecondary},
        {"red_challenger", context.redChallenger},
        {"red_total", context.redTotal},
        {"blue_primary", context.bluePrimary},
        {"blue_secondary", context.blueSecondary},
        {"blue_challenger", context.blueChallenger},
        {"blue_total", context.blueTotal},
        {"mission_type", context.missionType},
        {"game_type", context.gameType},
        {"map_size", context.mapSize},
        {"map_pack", context.mapPack},
        {"map_name", context.mapName},
        {"map_variant", context.mapVariant},
        {"map_id", context.mapId},
        {"map_layout", context.mapLayout},
        {"map_key", context.mapKey},
        {"deployment_card", context.deploymentCard},
        {"red_secondary_cards", context.redSecondaryCards},
        {"blue_secondary_cards", context.blueSecondaryCards}
    })
end

function buildTrackedCumulativeRoundContext(baseContext, scoreSummary, roundNo)
    if type(baseContext) ~= "table" or type(scoreSummary) ~= "table" then
        return nil
    end

    local redRounds = scoreSummary.red and scoreSummary.red.rounds or nil
    local blueRounds = scoreSummary.blue and scoreSummary.blue.rounds or nil
    if type(redRounds) ~= "table" or type(blueRounds) ~= "table" then
        return nil
    end

    local redPrimary = 0
    local redSecondary = 0
    local redChallenger = 0
    local bluePrimary = 0
    local blueSecondary = 0
    local blueChallenger = 0

    for r = 1, roundNo do
        local rr = redRounds[r] or {}
        local br = blueRounds[r] or {}

        redPrimary = redPrimary + toTrackedNumber(rr.primary, 0)
        redSecondary = redSecondary + toTrackedNumber(rr.secondary, 0)
        redChallenger = redChallenger + toTrackedNumber(rr.challenger, 0)

        bluePrimary = bluePrimary + toTrackedNumber(br.primary, 0)
        blueSecondary = blueSecondary + toTrackedNumber(br.secondary, 0)
        blueChallenger = blueChallenger + toTrackedNumber(br.challenger, 0)
    end

    if redPrimary > 50 then redPrimary = 50 end
    if redSecondary > 40 then redSecondary = 40 end
    if redChallenger > 12 then redChallenger = 12 end

    if bluePrimary > 50 then bluePrimary = 50 end
    if blueSecondary > 40 then blueSecondary = 40 end
    if blueChallenger > 12 then blueChallenger = 12 end

    local redTotal = redPrimary + redSecondary + redChallenger + 10
    local blueTotal = bluePrimary + blueSecondary + blueChallenger + 10
    if redTotal > 100 then redTotal = 100 end
    if blueTotal > 100 then blueTotal = 100 end

    local context = {
        missionType = baseContext.missionType,
        missionPack = baseContext.missionPack,
        gameType = baseContext.gameType,
        mapSize = baseContext.mapSize,
        mapPack = baseContext.mapPack,
        mapName = baseContext.mapName,
        mapVariant = baseContext.mapVariant,
        mapId = baseContext.mapId,
        mapLayout = baseContext.mapLayout,
        mapKey = baseContext.mapKey,
        deploymentCard = baseContext.deploymentCard,
        primaryMissionCard = baseContext.primaryMissionCard,
        redSecondaryCards = baseContext.redSecondaryCards,
        blueSecondaryCards = baseContext.blueSecondaryCards,
        round = roundNo,
        redTotal = redTotal,
        blueTotal = blueTotal,
        redPrimary = redPrimary,
        redSecondary = redSecondary,
        redChallenger = redChallenger,
        bluePrimary = bluePrimary,
        blueSecondary = blueSecondary,
        blueChallenger = blueChallenger
    }
    return context
end

function trackedRoundValidationSignature(context)
    return table.concat({
        tostring(context.redPrimary or ""),
        tostring(context.redSecondary or ""),
        tostring(context.redChallenger or ""),
        tostring(context.redTotal or ""),
        tostring(context.bluePrimary or ""),
        tostring(context.blueSecondary or ""),
        tostring(context.blueChallenger or ""),
        tostring(context.blueTotal or "")
    }, "|")
end

function sendTrackedRoundRevalidationSnapshots(captureSource, baseContext, mainRoundValue)
    if not trackedGameId then
        return
    end

    local scoreSummary = getTrackedScoreSheetSummary()
    if type(scoreSummary) ~= "table" then
        return
    end

    local mainRound = tonumber(mainRoundValue)
    if mainRound == nil then
        mainRound = tonumber(baseContext and baseContext.round)
    end
    if mainRound == nil then
        mainRound = tonumber(getRoundNumber())
    end
    if mainRound == nil then
        return
    end

    local highestPreviousRound = math.floor(mainRound) - 1
    if highestPreviousRound < 1 then
        return
    end

    for roundNo = 1, highestPreviousRound do
        local r = roundNo
        local roundContext = buildTrackedCumulativeRoundContext(baseContext, scoreSummary, r)
        if roundContext then
            local signature = trackedRoundValidationSignature(roundContext)
            if trackedRoundValidationCache[r] ~= signature then
                local revalidateSource = tostring(captureSource or "revalidate") .. "_revalidate"
                local revalidateUrl = buildTrackedSnapshotUrl(trackedGameId, revalidateSource, roundContext, r)
                ttsDebugLog("[ttsGame] snapshot revalidate r" .. tostring(r) .. " -> " .. revalidateUrl)
                WebRequest.get(revalidateUrl, function(response)
                    if response.is_error then
                        ttsDebugLog("[ttsGame] snapshot revalidate failed r" .. tostring(r) .. ": " .. tostring(response.error))
                        trackedRoundValidationCache[r] = nil
                        return
                    end
                    trackedRoundValidationCache[r] = signature
                    ttsDebugLog("[ttsGame] snapshot revalidate complete r" .. tostring(r))
                end)
            end
        end
    end
end

function hasTrackedRoundFiveScoresForBothPlayers(scoreSummary)
    if type(scoreSummary) ~= "table" then
        return false
    end
    local redRounds = scoreSummary.red and scoreSummary.red.rounds or nil
    local blueRounds = scoreSummary.blue and scoreSummary.blue.rounds or nil
    local redRoundFive = redRounds and redRounds[5] or nil
    local blueRoundFive = blueRounds and blueRounds[5] or nil
    if type(redRoundFive) ~= "table" or type(blueRoundFive) ~= "table" then
        return false
    end
    local redPrimary = toTrackedNumber(redRoundFive and redRoundFive.primary, 0)
    local redSecondary = toTrackedNumber(redRoundFive and redRoundFive.secondary, 0)
    local bluePrimary = toTrackedNumber(blueRoundFive and blueRoundFive.primary, 0)
    local blueSecondary = toTrackedNumber(blueRoundFive and blueRoundFive.secondary, 0)

    local redHasRoundFiveScore = redPrimary ~= 0 or redSecondary ~= 0
    local blueHasRoundFiveScore = bluePrimary ~= 0 or blueSecondary ~= 0

    return redHasRoundFiveScore and blueHasRoundFiveScore
end

function shouldAutoFinishTrackedGame()
    if trackedGameId == nil then
        return false
    end
    if endGameSubmitted or resultConfirmationPending then
        return false
    end
    if inGame ~= true then
        return false
    end
    local round = getRoundNumber() or 0
    if round < 5 then
        return false
    end
    local scoreSummary = getTrackedScoreSheetSummary()
    return hasTrackedRoundFiveScoresForBothPlayers(scoreSummary)
end

function stopTrackedAutoEndCountdown()
    if trackedAutoEndTimerId then
        Wait.stop(trackedAutoEndTimerId)
        trackedAutoEndTimerId = nil
    end
    trackedAutoEndPending = false
end

function stopTrackedAutoEndWatcher()
    if trackedAutoEndWatchTimerId then
        Wait.stop(trackedAutoEndWatchTimerId)
        trackedAutoEndWatchTimerId = nil
    end
    stopTrackedAutoEndCountdown()
end

function autoFinishTrackedGameIfPending()
    trackedAutoEndTimerId = nil
    if not trackedAutoEndPending then
        return
    end
    trackedAutoEndPending = false
    if not shouldAutoFinishTrackedGame() then
        return
    end
    ttsGameLog("Round 5 primary/secondary scores for both players were entered 2 minutes ago. Auto-finishing game now.", "Yellow")
    endTrackedGame()
end

function evaluateTrackedAutoEndState()
    if not shouldAutoFinishTrackedGame() then
        if trackedAutoEndPending then
            stopTrackedAutoEndCountdown()
            ttsDebugLog("[ttsGame] auto-end countdown cancelled")
        end
        return
    end

    if trackedAutoEndPending then
        return
    end

    trackedAutoEndPending = true
    ttsGameLog("Round 5 primary/secondary scores detected for both players. Auto-finish in 2 minutes unless finished manually.", "Yellow")
    trackedAutoEndTimerId = Wait.time(autoFinishTrackedGameIfPending, ttsAutoEndDelaySeconds)
    ttsDebugLog("[ttsGame] auto-end countdown started (" .. tostring(ttsAutoEndDelaySeconds) .. "s)")
end

function startTrackedAutoEndWatcher()
    stopTrackedAutoEndWatcher()
    trackedAutoEndWatchTimerId = Wait.time(function()
        evaluateTrackedAutoEndState()
    end, ttsAutoEndPollSeconds, -1)
    evaluateTrackedAutoEndState()
end

function stopTrackedSnapshotTimer()
    if trackedSnapshotTimerId then
        Wait.stop(trackedSnapshotTimerId)
        trackedSnapshotTimerId = nil
    end
    stopTrackedAutoEndWatcher()
end

function startTrackedSnapshotTimer()
    stopTrackedSnapshotTimer()
    if not trackedGameId then
        return
    end
    startTrackedAutoEndWatcher()
    trackedSnapshotTimerId = Wait.time(function()
        sendTrackedSnapshot("auto5m")
    end, ttsSnapshotIntervalSeconds, -1)
    ttsDebugLog("[ttsGame] snapshot timer started (" .. ttsSnapshotIntervalSeconds .. "s)")
end

function resetTrackedDiceRollerByGuidVar(guidVarName)
    local rollerGuid = Global.getVar(guidVarName)
    if not rollerGuid then
        return
    end
    local rollerObj = getObjectFromGUID(rollerGuid)
    if not rollerObj then
        return
    end
    pcall(function()
        rollerObj.call("resetRollTracking")
    end)
end

function resetTrackedDiceRollers()
    resetTrackedDiceRollerByGuidVar("redCustomDiceRoller_GUID")
    resetTrackedDiceRollerByGuidVar("blueCustomDiceRoller_GUID")
end

function getTrackedDiceRollAnalyticsByGuidVar(guidVarName)
    local rollerGuid = Global.getVar(guidVarName)
    if not rollerGuid then
        return nil
    end
    local rollerObj = getObjectFromGUID(rollerGuid)
    if not rollerObj then
        return nil
    end
    local ok, analytics = pcall(function()
        return rollerObj.call("getRollAnalytics")
    end)
    if not ok or type(analytics) ~= "table" then
        return nil
    end
    if tonumber(analytics.totalRolls) == nil then
        return nil
    end
    return analytics
end

function sendTrackedSnapshot(captureSource, roundOverride)
    if not trackedGameId then
        return
    end

    local context = getTrackingContext()
    local roundValue = roundOverride
    if roundValue == nil then
        roundValue = context.round
    end
    local url = buildTrackedSnapshotUrl(trackedGameId, captureSource, context, roundValue)

    ttsDebugLog("[ttsGame] snapshot -> " .. url)
    WebRequest.get(url, function(response)
        if response.is_error then
            ttsDebugLog("[ttsGame] snapshot failed: " .. response.error)
            return
        end
        ttsDebugLog("[ttsGame] snapshot complete")
        sendTrackedRoundRevalidationSnapshots(captureSource, context, roundValue)
    end)
end

function startTrackedGameSync()
    local redSteamId = getTrackedPlayerSteamId("Red")
    local blueSteamId = getTrackedPlayerSteamId("Blue")
    local redSteamName = redSteamId or getTrackedPlayerIdentifier("Red")
    local blueSteamName = blueSteamId or getTrackedPlayerIdentifier("Blue")
    local redDisplayName = getTrackedPlayerDisplayName("Red") or redSteamName
    local blueDisplayName = getTrackedPlayerDisplayName("Blue") or blueSteamName
    if not redSteamId or not blueSteamId then
        ttsDebugLog("[ttsGame] warning: missing steam identifiers, using fallback values")
    end

    local gameVersion = tonumber(Global.getVar("game_version_ID")) or 16
    local context = getTrackingContext()
    resetTrackedRoundValidationCache()

    local url = makeTtsGameUrl("/start", {
        {"game_version", gameVersion},
        {"red_steam_id", redSteamId},
        {"blue_steam_id", blueSteamId},
        {"red_steam_name", redSteamName},
        {"blue_steam_name", blueSteamName},
        {"red_display_name", redDisplayName},
        {"blue_display_name", blueDisplayName},
        {"mission_type", context.missionType},
        {"mission_pack", context.missionPack},
        {"game_type", context.gameType},
        {"map_size", context.mapSize},
        {"map_pack", context.mapPack},
        {"map_name", context.mapName},
        {"map_variant", context.mapVariant},
        {"map_id", context.mapId},
        {"map_layout", context.mapLayout},
        {"map_key", context.mapKey},
        {"deployment_card", context.deploymentCard},
        {"primary_mission_card", context.primaryMissionCard},
        {"red_secondary_cards", context.redSecondaryCards},
        {"blue_secondary_cards", context.blueSecondaryCards},
        {"red_player_first", boolToString(first == "Red")}
    })

    ttsDebugLog("[ttsGame] start -> " .. url)
    WebRequest.get(url, function(response)
        if response.is_error then
            ttsDebugLog("[ttsGame] start failed: " .. response.error)
            return
        end

        local ok, data = pcall(JSON.decode, response.text)
        if not ok or type(data) ~= "table" then
            ttsDebugLog("[ttsGame] start response parse failed: " .. tostring(response.text))
            return
        end

        if data.error then
            ttsDebugLog("[ttsGame] start error: " .. tostring(data.error))
            return
        end

        local game = data.game
        local gameId = game and game.gameId or nil
        if not gameId then
            ttsDebugLog("[ttsGame] start response missing gameId: " .. tostring(response.text))
            return
        end

        trackedGameId = gameId
        captureTrackedMainPlayers()
        resetTrackedEndApprovalState()
        endGameSubmitted = false
        resetTrackedResultConfirmationState()
        lastEndedTrackedGameId = nil
        syncTrackedSessionTable()
        ttsDebugLog("[ttsGame] start complete, game_id=" .. tostring(trackedGameId))
        writeMenus()
        startTrackedSnapshotTimer()
        sendTrackedSnapshot("start")
    end)
end

function toTrackedNumber(value, fallback)
    local n = tonumber(value)
    if n == nil then
        return fallback or 0
    end
    return n
end

function formatTrackedFloat(value)
    local n = tonumber(value)
    if n == nil then
        return "n/a"
    end
    return string.format("%.2f", n)
end

function formatTrackedSignedFloat(value)
    local n = tonumber(value)
    if n == nil then
        return "n/a"
    end
    return string.format("%+.2f", n)
end

function getTrackedDiceSummary(guidVarName)
    local dice = getTrackedDiceRollAnalyticsByGuidVar(guidVarName)
    if not dice then
        return nil
    end
    return {
        avg = tonumber(dice.average) or 0,
        rolls = tonumber(dice.totalRolls) or 0,
        badRate = tonumber(dice.badRollRate),
        delta = tonumber(dice.deltaFromExpected),
        bestCount = tonumber(dice.bestDiceCount),
        bestRate = tonumber(dice.bestDiceRate),
        worstCount = tonumber(dice.worstDiceCount),
        worstRate = tonumber(dice.worstDiceRate),
    }
end

function buildTrackedDiceSummaryLine(diceSummary)
    if not diceSummary then
        return nil
    end
    local parts = {
        "Dice avg " .. formatTrackedFloat(diceSummary.avg),
        tostring(diceSummary.rolls) .. " rolls",
    }
    if diceSummary.badRate ~= nil then
        table.insert(parts, "<=3 " .. formatTrackedFloat(diceSummary.badRate * 100) .. "%")
    end
    if diceSummary.bestRate ~= nil and diceSummary.bestCount ~= nil then
        table.insert(parts, "best(5-6) " .. formatTrackedFloat(diceSummary.bestRate * 100) .. "% (" .. tostring(math.floor(diceSummary.bestCount)) .. ")")
    end
    if diceSummary.worstRate ~= nil and diceSummary.worstCount ~= nil then
        table.insert(parts, "worst(1-2) " .. formatTrackedFloat(diceSummary.worstRate * 100) .. "% (" .. tostring(math.floor(diceSummary.worstCount)) .. ")")
    end
    if diceSummary.delta ~= nil then
        table.insert(parts, "delta " .. formatTrackedSignedFloat(diceSummary.delta))
    end
    return table.concat(parts, " | ")
end

function getTrackedDisplayName(side, scoreSummary)
    if scoreSummary and scoreSummary[string.lower(side)] and scoreSummary[string.lower(side)].name then
        return tostring(scoreSummary[string.lower(side)].name)
    end
    if Player[side] and Player[side].steam_name and Player[side].steam_name ~= "" then
        return Player[side].steam_name
    end
    return side
end

function getTrackedPlayerSummary(side, scoreSummary)
    local displayName = getTrackedPlayerDisplayName(side) or getTrackedDisplayName(side, scoreSummary)
    local steamId = getTrackedPlayerSteamId(side) or getTrackedPlayerIdentifier(side)
    local playerRef = Player[side]
    local seatColor = side
    if playerRef and playerRef.color and playerRef.color ~= "" then
        seatColor = playerRef.color
    end
    return {
        displayName = displayName,
        steamId = tostring(steamId),
        seatColor = seatColor,
    }
end

function printTrackedMatchSummary(context, scoreSummary)
    local redPlayer = getTrackedPlayerSummary("Red", scoreSummary)
    local bluePlayer = getTrackedPlayerSummary("Blue", scoreSummary)
    local redName = redPlayer.displayName
    local blueName = bluePlayer.displayName
    local redDice = getTrackedDiceSummary("redCustomDiceRoller_GUID")
    local blueDice = getTrackedDiceSummary("blueCustomDiceRoller_GUID")
    local redTotal = tonumber(context and context.redTotal)
    local blueTotal = tonumber(context and context.blueTotal)

    if redTotal == nil and scoreSummary and scoreSummary.red then
        redTotal = tonumber(scoreSummary.red.total)
    end
    if blueTotal == nil and scoreSummary and scoreSummary.blue then
        blueTotal = tonumber(scoreSummary.blue.total)
    end
    redTotal = redTotal or 0
    blueTotal = blueTotal or 0

    ttsGameLog("======== MATCH COMPLETE ========", "Yellow")
    ttsGameLog("Final Score: " .. tostring(redTotal) .. " - " .. tostring(blueTotal), "White")

    if redTotal > blueTotal then
        ttsGameLog("Winner: " .. redName .. " (+" .. tostring(redTotal - blueTotal) .. " VP)", redPlayer.seatColor)
    elseif blueTotal > redTotal then
        ttsGameLog("Winner: " .. blueName .. " (+" .. tostring(blueTotal - redTotal) .. " VP)", bluePlayer.seatColor)
    else
        ttsGameLog("Result: draw", "Yellow")
    end

    local missionInfo = (context and context.missionType) or "Unknown mission"
    local deploymentInfo = (context and context.deploymentCard) or "Unknown deployment"
    local roundInfo = toTrackedNumber(context and context.round, scoreSummary and scoreSummary.roundsPlayed)
    ttsGameLog(
        "Mission: " .. tostring(missionInfo) ..
        " | Deployment: " .. tostring(deploymentInfo) ..
        " | Rounds: " .. tostring(roundInfo),
        "Yellow"
    )

    ttsGameLog("----- RED PLAYER: " .. redPlayer.displayName .. " -----", redPlayer.seatColor)
    local redDiceLine = buildTrackedDiceSummaryLine(redDice)
    if redDiceLine then
        ttsGameLog(redDiceLine, "White")
    end

    ttsGameLog("----- BLUE PLAYER: " .. bluePlayer.displayName .. " -----", bluePlayer.seatColor)
    local blueDiceLine = buildTrackedDiceSummaryLine(blueDice)
    if blueDiceLine then
        ttsGameLog(blueDiceLine, "White")
    end

    if redDice and blueDice and redDice.delta ~= nil and blueDice.delta ~= nil then
        local deltaGap = redDice.delta - blueDice.delta
        if math.abs(deltaGap) < 0.25 then
            ttsGameLog("Dice luck: effectively even")
        else
            local favoredName = deltaGap > 0 and redName or blueName
            local favoredColor = deltaGap > 0 and redPlayer.seatColor or bluePlayer.seatColor
            ttsGameLog("Dice luck favored: " .. favoredName, favoredColor)
        end
    end

    if not scoreSummary or not scoreSummary.red or not scoreSummary.blue then
        return
    end

    local redPrimary = toTrackedNumber(scoreSummary.red.primary)
    local redSecondary = toTrackedNumber(scoreSummary.red.secondary)
    local redChallenger = toTrackedNumber(scoreSummary.red.challenger)
    local bluePrimary = toTrackedNumber(scoreSummary.blue.primary)
    local blueSecondary = toTrackedNumber(scoreSummary.blue.secondary)
    local blueChallenger = toTrackedNumber(scoreSummary.blue.challenger)

    ttsGameLog("Red P/S/C " .. redPrimary .. "/" .. redSecondary .. "/" .. redChallenger, "White")
    ttsGameLog("Blue P/S/C " .. bluePrimary .. "/" .. blueSecondary .. "/" .. blueChallenger, "White")

    local laneDiffs = {
        { label = "Primary", diff = redPrimary - bluePrimary },
        { label = "Secondary", diff = redSecondary - blueSecondary },
        { label = "Challenger", diff = redChallenger - blueChallenger },
    }
    local decidingLane = laneDiffs[1]
    for i = 2, #laneDiffs do
        if math.abs(laneDiffs[i].diff) > math.abs(decidingLane.diff) then
            decidingLane = laneDiffs[i]
        end
    end
    if decidingLane.diff ~= 0 then
        local sideName = decidingLane.diff > 0 and redName or blueName
        local sideColor = decidingLane.diff > 0 and redPlayer.seatColor or bluePlayer.seatColor
        ttsGameLog("Where it was won: " .. decidingLane.label .. " (" .. sideName .. " +" .. math.abs(decidingLane.diff) .. ")", sideColor)
    else
        ttsGameLog("Where it was won: even split across primary/secondary/challenger")
    end

    local redRounds = scoreSummary.red.rounds or {}
    local blueRounds = scoreSummary.blue.rounds or {}
    local maxRounds = math.max(#redRounds, #blueRounds)
    local biggestSwing = 0
    local biggestSwingRound = nil
    local leadChanges = 0
    local prevLeader = nil
    local redRoundsWon = 0
    local blueRoundsWon = 0
    local redRunning = 10
    local blueRunning = 10

    for r = 1, maxRounds do
        local redRoundTotal = toTrackedNumber(redRounds[r] and redRounds[r].total)
        local blueRoundTotal = toTrackedNumber(blueRounds[r] and blueRounds[r].total)
        local diff = redRoundTotal - blueRoundTotal
        if math.abs(diff) > math.abs(biggestSwing) then
            biggestSwing = diff
            biggestSwingRound = r
        end
        if diff > 0 then redRoundsWon = redRoundsWon + 1 end
        if diff < 0 then blueRoundsWon = blueRoundsWon + 1 end

        redRunning = redRunning + redRoundTotal
        blueRunning = blueRunning + blueRoundTotal
        local leader = nil
        if redRunning > blueRunning then leader = "Red" end
        if blueRunning > redRunning then leader = "Blue" end
        if prevLeader and leader and prevLeader ~= leader then
            leadChanges = leadChanges + 1
        end
        if leader then
            prevLeader = leader
        end
    end

    if biggestSwingRound ~= nil and biggestSwing ~= 0 then
        local swingSide = biggestSwing > 0 and redName or blueName
        local swingColor = biggestSwing > 0 and redPlayer.seatColor or bluePlayer.seatColor
        ttsGameLog("Biggest round swing: round " .. tostring(biggestSwingRound) .. " (" .. swingSide .. " +" .. tostring(math.abs(biggestSwing)) .. ")", swingColor)
    end
    ttsGameLog("Rounds won | Red: " .. tostring(redRoundsWon) .. " | Blue: " .. tostring(blueRoundsWon) .. " | Lead changes: " .. tostring(leadChanges))
end

function endTrackedGame()
    if not trackedGameId then
        ttsDebugLog("[ttsGame] end skipped: no game_id")
        return
    end
    if endGameSubmitted then
        ttsDebugLog("[ttsGame] end already submitted")
        return
    end

    local context = getTrackingContext()
    local scoreSummary = getTrackedScoreSheetSummary()
    local url = makeTtsGameUrl("/end", {
        {"game_id", trackedGameId},
        {"final_red_total", context.redTotal},
        {"final_blue_total", context.blueTotal}
    })

    endGameSubmitted = true
    stopTrackedAutoEndCountdown()
    writeMenus()
    ttsDebugLog("[ttsGame] end -> " .. url)
    WebRequest.get(url, function(response)
        if response.is_error then
            ttsDebugLog("[ttsGame] end failed: " .. response.error)
            endGameSubmitted = false
            writeMenus()
            return
        end

        local ok, data = pcall(JSON.decode, response.text)
        if ok and type(data) == "table" and data.error then
            ttsDebugLog("[ttsGame] end error: " .. tostring(data.error))
            endGameSubmitted = false
            writeMenus()
            return
        end

        ttsDebugLog("[ttsGame] end complete for game_id=" .. tostring(trackedGameId))
        printTrackedMatchSummary(context, scoreSummary)
        ttsGameLog("Red and Blue players: click Confirm Win/Loss to validate the result.")
        stopTrackedSnapshotTimer()
        lastEndedTrackedGameId = trackedGameId
        trackedGameId = nil
        resetTrackedRoundValidationCache()
        resetTrackedEndApprovalState()
        resultConfirmationPending = true
        resultConfirmedRed = false
        resultConfirmedBlue = false
        clearTrackedActionArms()
        syncTrackedSessionTable()
        writeMenus()
    end)
end

function sendTrackedResultConfirmationSnapshot(captureSource)
    local gameId = trackedGameId or lastEndedTrackedGameId
    if gameId == nil then
        return
    end
    local context = getTrackingContext()
    local url = makeTtsGameUrl("/snapshot", {
        {"game_id", gameId},
        {"capture_source", captureSource},
        {"round", context.round},
        {"red_total", context.redTotal},
        {"blue_total", context.blueTotal},
        {"game_type", context.gameType},
        {"map_size", context.mapSize},
        {"map_pack", context.mapPack},
        {"map_name", context.mapName},
        {"map_key", context.mapKey}
    })
    WebRequest.get(url, function(_response)
    end)
end

function confirmTrackedResultForSide(expectedSide, clickedSide)
    if not shouldShowResultConfirmationButtons() then
        return
    end

    if clickedSide ~= expectedSide then
        if clickedSide and clickedSide ~= "" then
            broadcastToColor("Only the " .. expectedSide .. " player can confirm this button.", clickedSide, "Yellow")
        end
        return
    end

    if isTrackedGameActive() then
        if trackedGameId == nil then
            broadcastToColor("Game tracking not ready yet. Try again in a second.", clickedSide, "Yellow")
            clearTrackedActionArms()
            return
        end

        if hasTwoRegisteredTrackedPlayers() then
            clearTrackedActionArms()
            if not endApprovalPending then
                endApprovalPending = true
                endApprovalRequestedBy = expectedSide
                local otherSide = getOtherTrackedSide(expectedSide)
                ttsGameLog(expectedSide .. " requested to end the game. " .. otherSide .. " must approve.", "Yellow")
                writeMenus()
                return
            end

            if endApprovalRequestedBy == expectedSide then
                local otherSide = getOtherTrackedSide(expectedSide)
                broadcastToColor("Waiting for " .. otherSide .. " to approve end game.", clickedSide, "Yellow")
                return
            end

            ttsGameLog(expectedSide .. " approved ending the game.", expectedSide)
            endApprovalPending = false
            endApprovalRequestedBy = nil
            endTrackedGame()
            return
        end

        local isArmed = expectedSide == "Red" and trackedActionArmRed or trackedActionArmBlue
        if not isArmed then
            clearTrackedActionArms()
            if expectedSide == "Red" then
                trackedActionArmRed = true
            else
                trackedActionArmBlue = true
            end
            broadcastToColor("Click again to confirm: finish game now.", clickedSide, "Yellow")
            return
        end
        clearTrackedActionArms()
        endTrackedGame()
        return
    end

    local isArmed = expectedSide == "Red" and trackedActionArmRed or trackedActionArmBlue
    if not isArmed then
        clearTrackedActionArms()
        if expectedSide == "Red" then
            trackedActionArmRed = true
        else
            trackedActionArmBlue = true
        end
        broadcastToColor("Click again to confirm your result.", clickedSide, "Yellow")
        return
    end
    clearTrackedActionArms()

    if expectedSide == "Red" then
        if resultConfirmedRed then
            return
        end
        resultConfirmedRed = true
    elseif expectedSide == "Blue" then
        if resultConfirmedBlue then
            return
        end
        resultConfirmedBlue = true
    end

    ttsGameLog(expectedSide .. " confirmed the final result.", expectedSide)
    sendTrackedResultConfirmationSnapshot("resultConfirm" .. expectedSide)

    if resultConfirmedRed and resultConfirmedBlue then
        resultConfirmationPending = false
        ttsGameLog("Both players confirmed the final result.", "Green")
        sendTrackedResultConfirmationSnapshot("resultConfirmBoth")
    end

    writeMenus()
end

function confirmTrackedResultRed(_obj, playerColor, _alt)
    confirmTrackedResultForSide("Red", playerColor)
end

function confirmTrackedResultBlue(_obj, playerColor, _alt)
    confirmTrackedResultForSide("Blue", playerColor)
end

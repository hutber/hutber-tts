local STATE = {
  active = false,
  gameId = nil,
  turn = "Red",
  battleRound = 1,
  phaseIndex = 1,
  phases = { "Command", "Movement", "Shooting", "Charge", "Fight" },
  redVp = 0,
  blueVp = 0,
  redCp = 0,
  blueCp = 0,
  diceCount = 10,
  mapSizeIndex = 3,
  mapTemplateIndex = 1,
  baseTableGuid = nil,
  controlBoardGuid = nil,
  spawnedMapGuids = {},
}

local TRACKING_API_BASE = "https://apistats.hutber.com/api/ttsGame"
local TRACKING_GAME_VERSION = 17
local GAME_EDITION_LABEL = "Warhammer 40k 10th Edition"
local MAX_ROUNDS = 5

local MAP_SIZES = {
  { key = "cp", label = "Combat Patrol 44x30", halfW = 22, halfH = 15 },
  { key = "inc", label = "Incursion 44x60", halfW = 22, halfH = 30 },
  { key = "sf", label = "Strike Force 44x60", halfW = 22, halfH = 30 },
  { key = "ons", label = "Onslaught 44x90", halfW = 22, halfH = 45 },
}

local MAP_TEMPLATES = {
  {
    name = "Crossfire Alleys",
    pack = "Nova Urban",
    tint = { 0.13, 0.14, 0.16 },
    lanes = {
      { x = -10, z = 0, sx = 7, sz = 22, c = { 0.27, 0.27, 0.30 } },
      { x = 10, z = 0, sx = 7, sz = 22, c = { 0.27, 0.27, 0.30 } },
      { x = 0, z = -12, sx = 12, sz = 5, c = { 0.22, 0.22, 0.25 } },
      { x = 0, z = 12, sx = 12, sz = 5, c = { 0.22, 0.22, 0.25 } },
    },
  },
  {
    name = "Deadzone Ring",
    pack = "Nova Industrial",
    tint = { 0.14, 0.13, 0.15 },
    lanes = {
      { x = -12, z = -9, sx = 7, sz = 6, c = { 0.30, 0.25, 0.20 } },
      { x = 12, z = 9, sx = 7, sz = 6, c = { 0.30, 0.25, 0.20 } },
      { x = -12, z = 9, sx = 7, sz = 6, c = { 0.30, 0.25, 0.20 } },
      { x = 12, z = -9, sx = 7, sz = 6, c = { 0.30, 0.25, 0.20 } },
      { x = 0, z = 0, sx = 8, sz = 8, c = { 0.24, 0.24, 0.28 } },
    },
  },
  {
    name = "Highline Break",
    pack = "Nova Frontier",
    tint = { 0.16, 0.14, 0.12 },
    lanes = {
      { x = 0, z = -14, sx = 16, sz = 4, c = { 0.32, 0.28, 0.18 } },
      { x = 0, z = 14, sx = 16, sz = 4, c = { 0.32, 0.28, 0.18 } },
      { x = -16, z = 0, sx = 4, sz = 10, c = { 0.25, 0.22, 0.16 } },
      { x = 16, z = 0, sx = 4, sz = 10, c = { 0.25, 0.22, 0.16 } },
    },
  },
}

local function clamp(value, low, high)
  if value < low then
    return low
  end
  if value > high then
    return high
  end
  return value
end

local function esc(text)
  if text == nil then
    return ""
  end
  local out = tostring(text)
  out = out:gsub("&", "&amp;")
  out = out:gsub("<", "&lt;")
  out = out:gsub(">", "&gt;")
  out = out:gsub('"', "&quot;")
  return out
end

local function urlencode(value)
  local text = tostring(value or "")
  text = text:gsub("\n", "\r\n")
  text = text:gsub("([^%w%-_%.~])", function(char)
    return string.format("%%%02X", string.byte(char))
  end)
  return text
end

local function buildQuery(params)
  local parts = {}
  for key, value in pairs(params) do
    if value ~= nil then
      table.insert(parts, urlencode(key) .. "=" .. urlencode(value))
    end
  end
  return table.concat(parts, "&")
end

local function phaseName()
  return STATE.phases[STATE.phaseIndex]
end

local function currentMapSize()
  return MAP_SIZES[STATE.mapSizeIndex]
end

local function currentMapTemplate()
  return MAP_TEMPLATES[STATE.mapTemplateIndex]
end

local function safeGetObject(guid)
  if not guid or guid == "" then
    return nil
  end
  return getObjectFromGUID(guid)
end

local function hasAnySpawnedObjects()
  for _, guid in ipairs(STATE.spawnedMapGuids) do
    if safeGetObject(guid) then
      return true
    end
  end
  return false
end

local function clearSpawnedMap()
  for _, guid in ipairs(STATE.spawnedMapGuids) do
    local obj = safeGetObject(guid)
    if obj then
      obj.destruct()
    end
  end
  STATE.spawnedMapGuids = {}
end

local function trackSpawned(obj)
  if obj and obj.getGUID then
    table.insert(STATE.spawnedMapGuids, obj.getGUID())
  end
end

function onNoop()
end

local function ensureBaseTable(size)
  local base = safeGetObject(STATE.baseTableGuid)
  local baseWidth = ((size.halfW * 2) + 46) * 2
  local baseDepth = ((size.halfH * 2) + 40) * 2
  local baseScale = {
    baseWidth,
    0.3,
    baseDepth,
  }
  local basePos = { 0, 0.82, 8 }

  if base then
    base.setScale(baseScale)
    base.setPositionSmooth(basePos, false, false)
    return base
  end

  base = spawnObject({
    type = "BlockSquare",
    position = basePos,
    scale = baseScale,
    sound = false,
  })
  base.setName("Nova Base Table")
  base.setDescription("Main platform for the Nova Ops board, controls, and staging areas.")
  base.setColorTint({ 0.20, 0.20, 0.22 })
  base.setLock(true)
  base.interactable = false
  STATE.baseTableGuid = base.getGUID()
  return base
end

local function ensureControlBoard(size)
  ensureBaseTable(size)

  local board = safeGetObject(STATE.controlBoardGuid)
  local boardPos = { 0, 1.06, size.halfH + 13 }

  if board then
    board.setScale({ 54, 0.4, 24 })
    board.setPositionSmooth(boardPos, false, false)
    return board
  end

  board = spawnObject({
    type = "BlockSquare",
    position = boardPos,
    scale = { 54, 0.4, 24 },
    sound = false,
  })
  board.setName("Nova Ops Command Console")
  board.setDescription("In-world controls for score, phase flow, dice, and map loading.")
  board.setColorTint({ 0.09, 0.11, 0.16 })
  board.setLock(true)
  STATE.controlBoardGuid = board.getGUID()
  return board
end

local function spawnMapTile(size, template)
  local mat = spawnObject({
    type = "BlockSquare",
    position = { 0, 0.95, 0 },
    scale = { size.halfW * 2, 0.2, size.halfH * 2 },
    sound = false,
  })
  mat.setName("Nova Battlefield")
  mat.setDescription(size.label .. " | " .. template.pack .. " | " .. template.name)
  mat.setColorTint({ template.tint[1], template.tint[2], template.tint[3] })
  mat.setLock(true)
  mat.interactable = false
  trackSpawned(mat)

  -- Side staging boards for placing miniatures before/after deployment.
  local redStaging = spawnObject({
    type = "BlockSquare",
    position = { size.halfW + 10, 0.95, 0 },
    scale = { 14, 0.2, math.max(size.halfH * 1.6, 26) },
    sound = false,
  })
  redStaging.setName("Red Staging Board")
  redStaging.setDescription("Use for model staging and reserves.")
  redStaging.setColorTint({ 0.32, 0.12, 0.12 })
  redStaging.setLock(true)
  redStaging.interactable = false
  trackSpawned(redStaging)

  local blueStaging = spawnObject({
    type = "BlockSquare",
    position = { -size.halfW - 10, 0.95, 0 },
    scale = { 14, 0.2, math.max(size.halfH * 1.6, 26) },
    sound = false,
  })
  blueStaging.setName("Blue Staging Board")
  blueStaging.setDescription("Use for model staging and reserves.")
  blueStaging.setColorTint({ 0.12, 0.16, 0.35 })
  blueStaging.setLock(true)
  blueStaging.interactable = false
  trackSpawned(blueStaging)

  local redZone = spawnObject({
    type = "BlockSquare",
    position = { 0, 0.97, size.halfH - 4 },
    scale = { size.halfW * 2 - 2, 0.1, 6 },
    sound = false,
  })
  redZone.setName("Red DZ")
  redZone.setColorTint({ 0.35, 0.12, 0.12 })
  redZone.setLock(true)
  redZone.interactable = false
  trackSpawned(redZone)

  local blueZone = spawnObject({
    type = "BlockSquare",
    position = { 0, 0.97, -size.halfH + 4 },
    scale = { size.halfW * 2 - 2, 0.1, 6 },
    sound = false,
  })
  blueZone.setName("Blue DZ")
  blueZone.setColorTint({ 0.12, 0.16, 0.35 })
  blueZone.setLock(true)
  blueZone.interactable = false
  trackSpawned(blueZone)

  local objSpacing = math.min(size.halfW - 4, 14)
  local objectives = {
    { x = -objSpacing, z = 0, n = "Objective 1" },
    { x = objSpacing, z = 0, n = "Objective 2" },
    { x = 0, z = 0, n = "Objective 3" },
    { x = -8, z = 10, n = "Objective 4" },
    { x = 8, z = -10, n = "Objective 5" },
  }

  for _, objective in ipairs(objectives) do
    local marker = spawnObject({
      type = "BlockSquare",
      position = { objective.x, 1.02, objective.z },
      scale = { 1.5, 0.1, 1.5 },
      sound = false,
    })
    marker.setName(objective.n)
    marker.setColorTint({ 0.95, 0.75, 0.15 })
    marker.setLock(true)
    marker.interactable = false
    trackSpawned(marker)
  end

  for _, lane in ipairs(template.lanes) do
    local feature = spawnObject({
      type = "BlockSquare",
      position = { lane.x, 1.01, lane.z },
      scale = { lane.sx, 0.1, lane.sz },
      sound = false,
    })
    feature.setName("Terrain Lane")
    feature.setColorTint({ lane.c[1], lane.c[2], lane.c[3] })
    feature.setLock(true)
    feature.interactable = false
    trackSpawned(feature)
  end
end

local function setRound(roundValue)
  STATE.battleRound = clamp(roundValue, 1, MAX_ROUNDS)
end

local function addCpForCurrentTurn()
  if STATE.turn == "Red" then
    STATE.redCp = STATE.redCp + 1
  else
    STATE.blueCp = STATE.blueCp + 1
  end
end

local function renderUi()
  UI.setXml("")

  local board = ensureControlBoard(currentMapSize())
  if not board then
    return
  end

  board.clearButtons()
  board.clearInputs()

  local statusText = STATE.active and "Active" or "Idle"
  local title = "NOVA OPS COMMAND DECK"
  local subtitle = GAME_EDITION_LABEL .. " | control-first UI, modular maps, cleaner scoring flow"
  local mapSize = currentMapSize().label
  local mapTemplate = currentMapTemplate().name
  local mapPack = currentMapTemplate().pack
  local BUTTON_SCALE = 0.52
  local LABEL_SCALE = 0.62
  local X_SPREAD = 0.42
  local Z_SPREAD = 0.50
  local Y_POS = 0.31

  local function p(x, z)
    return { x * X_SPREAD, Y_POS, z * Z_SPREAD }
  end

  local function addLabel(text, position, fontSize, color)
    board.createButton({
      click_function = "onNoop",
      function_owner = Global,
      label = text,
      position = position,
      width = 0,
      height = 0,
      font_size = math.max(60, math.floor((fontSize or 180) * LABEL_SCALE)),
      font_color = color or { 1, 1, 1 },
      color = { 0, 0, 0 },
      tooltip = "",
    })
  end

  local function addAction(label, clickFunction, position, width, height, fontSize, color)
    board.createButton({
      click_function = clickFunction,
      function_owner = Global,
      label = label,
      position = position,
      width = math.max(280, math.floor((width or 900) * BUTTON_SCALE)),
      height = math.max(120, math.floor((height or 320) * BUTTON_SCALE)),
      font_size = math.max(80, math.floor((fontSize or 140) * BUTTON_SCALE)),
      color = color or { 0.15, 0.18, 0.24 },
      font_color = { 0.93, 0.93, 0.93 },
      tooltip = "",
    })
  end

  addLabel(title, p(0, 8.0), 320, { 0.48, 1.0, 0.63 })
  addLabel(subtitle, p(0, 7.2), 120, { 0.68, 0.74, 0.86 })

  addLabel("Edition: 10e", p(-18, 6.3), 150, { 0.76, 0.96, 0.78 })
  addLabel("Status: " .. statusText, p(-13, 6.3), 160, { 0.9, 0.9, 0.9 })
  addLabel("Turn: " .. STATE.turn, p(-5, 6.3), 160, { 0.9, 0.9, 0.9 })
  addLabel("Round: " .. tostring(STATE.battleRound) .. "/" .. tostring(MAX_ROUNDS), p(5, 6.3), 160, { 0.9, 0.9, 0.9 })
  addLabel("Phase: " .. phaseName(), p(15, 6.3), 160, { 0.9, 0.9, 0.9 })

  addLabel("RED COMMAND", p(-14, 4.9), 190, { 1, 0.45, 0.45 })
  addLabel("VP " .. tostring(STATE.redVp), p(-14, 4.1), 180, { 1, 0.93, 0.93 })
  addAction("-1 VP", "onRedVpDown", p(-16.8, 3.2), 1200, 360, 150, { 0.24, 0.12, 0.15 })
  addAction("+1 VP", "onRedVpUp", p(-11.2, 3.2), 1200, 360, 150, { 0.24, 0.12, 0.15 })
  addLabel("CP " .. tostring(STATE.redCp), p(-14, 2.2), 180, { 1, 0.93, 0.93 })
  addAction("-1 CP", "onRedCpDown", p(-16.8, 1.3), 1200, 360, 150, { 0.24, 0.12, 0.15 })
  addAction("+1 CP", "onRedCpUp", p(-11.2, 1.3), 1200, 360, 150, { 0.24, 0.12, 0.15 })

  addLabel("BLUE COMMAND", p(0, 4.9), 190, { 0.43, 0.66, 1 })
  addLabel("VP " .. tostring(STATE.blueVp), p(0, 4.1), 180, { 0.93, 0.97, 1 })
  addAction("-1 VP", "onBlueVpDown", p(-2.8, 3.2), 1200, 360, 150, { 0.12, 0.16, 0.28 })
  addAction("+1 VP", "onBlueVpUp", p(2.8, 3.2), 1200, 360, 150, { 0.12, 0.16, 0.28 })
  addLabel("CP " .. tostring(STATE.blueCp), p(0, 2.2), 180, { 0.93, 0.97, 1 })
  addAction("-1 CP", "onBlueCpDown", p(-2.8, 1.3), 1200, 360, 150, { 0.12, 0.16, 0.28 })
  addAction("+1 CP", "onBlueCpUp", p(2.8, 1.3), 1200, 360, 150, { 0.12, 0.16, 0.28 })

  addLabel("FLOW CONTROL", p(14, 4.9), 190, { 0.83, 0.88, 1 })
  addAction("START", "onStartMatch", p(11.2, 3.2), 1200, 360, 150, { 0.11, 0.38, 0.17 })
  addAction("END", "onEndMatch", p(16.8, 3.2), 1200, 360, 150, { 0.43, 0.12, 0.12 })
  addAction("ROUND -", "onRoundDown", p(11.2, 1.3), 1200, 360, 145, { 0.18, 0.22, 0.28 })
  addAction("ROUND +", "onRoundUp", p(16.8, 1.3), 1200, 360, 145, { 0.18, 0.22, 0.28 })
  addAction("NEXT PHASE", "onNextPhase", p(14, 0.0), 2600, 360, 145, { 0.16, 0.29, 0.55 })
  addAction("SWAP TURN", "onSwapTurn", p(11.2, -1.3), 1200, 360, 135, { 0.18, 0.22, 0.28 })
  addAction("RESET", "onResetScores", p(16.8, -1.3), 1200, 360, 135, { 0.18, 0.22, 0.28 })

  addLabel("DICE ENGINE", p(-13.5, -3.5), 180, { 0.96, 0.9, 0.48 })
  addLabel("Count " .. tostring(STATE.diceCount), p(-16.7, -4.7), 160, { 0.9, 0.9, 0.9 })
  addAction("-", "onDiceCountDown", p(-13.6, -4.7), 700, 330, 200, { 0.20, 0.23, 0.30 })
  addAction("+", "onDiceCountUp", p(-11.7, -4.7), 700, 330, 200, { 0.20, 0.23, 0.30 })
  addAction("ROLL D6", "onRollDice", p(-15.0, -6.2), 1700, 380, 150, { 0.46, 0.36, 0.10 })
  addAction("ROLL + STATS", "onRollDiceVerbose", p(-11.1, -6.2), 1700, 380, 130, { 0.46, 0.36, 0.10 })

  addLabel("MAP CONTROL", p(8.8, -3.5), 180, { 0.48, 1.0, 0.63 })
  addLabel("Size: " .. mapSize, p(7.0, -4.8), 130, { 0.9, 0.9, 0.9 })
  addAction("<", "onPrevMapSize", p(12.1, -4.8), 650, 300, 170, { 0.18, 0.22, 0.28 })
  addAction(">", "onNextMapSize", p(14.0, -4.8), 650, 300, 170, { 0.18, 0.22, 0.28 })
  addLabel("Template: " .. mapTemplate, p(7.0, -6.0), 130, { 0.9, 0.9, 0.9 })
  addAction("<", "onPrevMapTemplate", p(12.1, -6.0), 650, 300, 170, { 0.18, 0.22, 0.28 })
  addAction(">", "onNextMapTemplate", p(14.0, -6.0), 650, 300, 170, { 0.18, 0.22, 0.28 })
  addLabel("Pack: " .. mapPack, p(7.0, -7.0), 120, { 0.68, 0.74, 0.86 })
  addAction("LOAD MAP", "onLoadMap", p(10.8, -7.7), 1400, 340, 130, { 0.14, 0.42, 0.20 })
  addAction("CLEAR MAP", "onClearMap", p(14.6, -7.7), 1400, 340, 130, { 0.36, 0.16, 0.16 })
end

local function announce(message)
  broadcastToAll("[NovaOps] " .. message, { 0.6, 1, 0.7 })
end

local function getPlayerIdentity(color, fallbackId, fallbackName)
  local player = Player[color]
  local steamId = fallbackId
  local displayName = fallbackName

  if player then
    if player.steam_id and tostring(player.steam_id) ~= "" then
      steamId = tostring(player.steam_id)
    end
    if player.steam_name and player.steam_name ~= "" then
      displayName = player.steam_name
    end
  end

  return steamId, displayName
end

local function requestTracking(path, params, onSuccess)
  if not WebRequest then
    return
  end
  local url = TRACKING_API_BASE .. "/" .. path .. "?" .. buildQuery(params)
  WebRequest.get(url, function(response)
    if response.is_error then
      print("[NovaOps tracking] " .. tostring(response.error))
      return
    end
    local body = nil
    if response.text and response.text ~= "" then
      body = JSON.decode(response.text)
    end
    if onSuccess then
      onSuccess(body)
    end
  end)
end

local function trackingContext()
  return {
    round = STATE.battleRound,
    red_primary = STATE.redVp,
    red_secondary = 0,
    red_challenger = 0,
    red_total = STATE.redVp,
    blue_primary = STATE.blueVp,
    blue_secondary = 0,
    blue_challenger = 0,
    blue_total = STATE.blueVp,
    mission_type = GAME_EDITION_LABEL,
    deployment_card = currentMapTemplate().name,
    mission_pack = currentMapTemplate().pack,
  }
end

local function sendTrackingStart()
  local redSteamId, redDisplayName = getPlayerIdentity("Red", "red_unknown", "Red Player")
  local blueSteamId, blueDisplayName = getPlayerIdentity("Blue", "blue_unknown", "Blue Player")

  local params = {
    game_version = TRACKING_GAME_VERSION,
    red_steam_id = redSteamId,
    blue_steam_id = blueSteamId,
    red_display_name = redDisplayName,
    blue_display_name = blueDisplayName,
    mission_type = GAME_EDITION_LABEL,
    mission_pack = currentMapTemplate().pack,
    game_type = "singles",
    map_size = currentMapSize().label,
    deployment_card = currentMapTemplate().name,
    red_player_first = STATE.turn == "Red" and "true" or "false",
  }

  requestTracking("start", params, function(body)
    if body and body.game and body.game.gameId then
      STATE.gameId = body.game.gameId
      announce("Tracking started. game_id=" .. tostring(STATE.gameId))
    end
  end)
end

local function sendTrackingSnapshot(captureSource)
  if not STATE.active or not STATE.gameId then
    return
  end

  local context = trackingContext()
  local params = {
    game_id = STATE.gameId,
    capture_source = captureSource,
    round = context.round,
    red_primary = context.red_primary,
    red_secondary = context.red_secondary,
    red_challenger = context.red_challenger,
    red_total = context.red_total,
    blue_primary = context.blue_primary,
    blue_secondary = context.blue_secondary,
    blue_challenger = context.blue_challenger,
    blue_total = context.blue_total,
    mission_type = context.mission_type,
    deployment_card = context.deployment_card,
    red_secondary_cards = "",
    blue_secondary_cards = "",
  }

  requestTracking("snapshot", params, nil)
end

local function sendTrackingEnd(captureSource)
  if not STATE.gameId then
    return
  end

  local context = trackingContext()
  local params = {
    game_id = STATE.gameId,
    capture_source = captureSource,
    round = context.round,
    red_primary = context.red_primary,
    red_secondary = context.red_secondary,
    red_challenger = context.red_challenger,
    red_total = context.red_total,
    blue_primary = context.blue_primary,
    blue_secondary = context.blue_secondary,
    blue_challenger = context.blue_challenger,
    blue_total = context.blue_total,
    mission_type = context.mission_type,
    deployment_card = context.deployment_card,
    red_secondary_cards = "",
    blue_secondary_cards = "",
  }

  requestTracking("end", params, nil)
end

local function rollDiceInternal(verbose)
  local count = clamp(STATE.diceCount, 1, 60)
  local sum = 0
  local high = 0
  local low = 7
  local success = 0
  local lowRolls = 0
  local values = {}

  for i = 1, count do
    local die = math.random(1, 6)
    sum = sum + die
    high = math.max(high, die)
    low = math.min(low, die)
    if die >= 4 then
      success = success + 1
    end
    if die <= 3 then
      lowRolls = lowRolls + 1
    end
    values[#values + 1] = die
  end

  local avg = sum / count
  local text = string.format(
    "%s rolled %dd6 | avg %.2f | >=4: %d | <=3: %d | best: %d | worst: %d",
    STATE.turn,
    count,
    avg,
    success,
    lowRolls,
    high,
    low
  )

  if verbose then
    text = text .. " | dice: " .. table.concat(values, ",")
  end

  announce(text)
end

local function saveState()
  -- Dummy function to make state changes explicit in call sites.
end

local function bumpRedVp(delta)
  STATE.redVp = clamp(STATE.redVp + delta, 0, 200)
  saveState()
  renderUi()
  sendTrackingSnapshot("scoreUpdate")
end

local function bumpBlueVp(delta)
  STATE.blueVp = clamp(STATE.blueVp + delta, 0, 200)
  saveState()
  renderUi()
  sendTrackingSnapshot("scoreUpdate")
end

local function bumpRedCp(delta)
  STATE.redCp = clamp(STATE.redCp + delta, 0, 30)
  saveState()
  renderUi()
end

local function bumpBlueCp(delta)
  STATE.blueCp = clamp(STATE.blueCp + delta, 0, 30)
  saveState()
  renderUi()
end

local function setTurn(nextTurn)
  STATE.turn = nextTurn
  renderUi()
end

local function advancePhase()
  STATE.phaseIndex = STATE.phaseIndex + 1
  if STATE.phaseIndex > #STATE.phases then
    STATE.phaseIndex = 1
    if STATE.turn == "Red" then
      STATE.turn = "Blue"
    else
      STATE.turn = "Red"
      setRound(STATE.battleRound + 1)
    end
    addCpForCurrentTurn()
  end
  saveState()
  renderUi()
  sendTrackingSnapshot("phaseChange")
end

local function resetForNewGame()
  STATE.active = true
  STATE.turn = "Red"
  STATE.battleRound = 1
  STATE.phaseIndex = 1
  STATE.redVp = 0
  STATE.blueVp = 0
  STATE.redCp = 0
  STATE.blueCp = 0
  STATE.gameId = nil
  addCpForCurrentTurn()
  saveState()
  renderUi()
end

function onLoad(saved)
  math.randomseed(os.time())

  if saved and saved ~= "" then
    local decoded = JSON.decode(saved)
    if decoded then
      STATE.active = decoded.active == true
      STATE.gameId = decoded.gameId
      STATE.turn = decoded.turn or STATE.turn
      STATE.battleRound = clamp(tonumber(decoded.battleRound or STATE.battleRound) or STATE.battleRound, 1, MAX_ROUNDS)
      STATE.phaseIndex = clamp(tonumber(decoded.phaseIndex or STATE.phaseIndex) or STATE.phaseIndex, 1, #STATE.phases)
      STATE.redVp = clamp(tonumber(decoded.redVp or STATE.redVp) or STATE.redVp, 0, 200)
      STATE.blueVp = clamp(tonumber(decoded.blueVp or STATE.blueVp) or STATE.blueVp, 0, 200)
      STATE.redCp = clamp(tonumber(decoded.redCp or STATE.redCp) or STATE.redCp, 0, 30)
      STATE.blueCp = clamp(tonumber(decoded.blueCp or STATE.blueCp) or STATE.blueCp, 0, 30)
      STATE.diceCount = clamp(tonumber(decoded.diceCount or STATE.diceCount) or STATE.diceCount, 1, 60)
      STATE.mapSizeIndex = clamp(tonumber(decoded.mapSizeIndex or STATE.mapSizeIndex) or STATE.mapSizeIndex, 1, #MAP_SIZES)
      STATE.mapTemplateIndex = clamp(tonumber(decoded.mapTemplateIndex or STATE.mapTemplateIndex) or STATE.mapTemplateIndex, 1, #MAP_TEMPLATES)
      STATE.baseTableGuid = decoded.baseTableGuid
      STATE.controlBoardGuid = decoded.controlBoardGuid
      STATE.spawnedMapGuids = decoded.spawnedMapGuids or {}
    end
  end

  if not hasAnySpawnedObjects() then
    spawnMapTile(currentMapSize(), currentMapTemplate())
    announce("Default gaming board spawned.")
  end

  renderUi()
end

function onSave()
  local payload = {
    active = STATE.active,
    gameId = STATE.gameId,
    turn = STATE.turn,
    battleRound = STATE.battleRound,
    phaseIndex = STATE.phaseIndex,
    redVp = STATE.redVp,
    blueVp = STATE.blueVp,
    redCp = STATE.redCp,
    blueCp = STATE.blueCp,
    diceCount = STATE.diceCount,
    mapSizeIndex = STATE.mapSizeIndex,
    mapTemplateIndex = STATE.mapTemplateIndex,
    baseTableGuid = STATE.baseTableGuid,
    controlBoardGuid = STATE.controlBoardGuid,
    spawnedMapGuids = STATE.spawnedMapGuids,
  }
  return JSON.encode(payload)
end

function onStartMatch(_, _)
  resetForNewGame()
  sendTrackingStart()
  announce("Match started. Red takes first command phase.")
end

function onEndMatch(_, _)
  STATE.active = false
  saveState()
  renderUi()
  local winner = "Draw"
  if STATE.redVp > STATE.blueVp then
    winner = "Red"
  elseif STATE.blueVp > STATE.redVp then
    winner = "Blue"
  end
  sendTrackingEnd("manualEnd")
  announce("Match ended. Final VP Red " .. STATE.redVp .. " - Blue " .. STATE.blueVp .. ". Winner: " .. winner .. ".")
end

function onResetScores(_, _)
  STATE.redVp = 0
  STATE.blueVp = 0
  STATE.redCp = 0
  STATE.blueCp = 0
  saveState()
  renderUi()
  announce("Scores reset to zero.")
end

function onRedVpUp(_, _)
  bumpRedVp(1)
end

function onRedVpDown(_, _)
  bumpRedVp(-1)
end

function onBlueVpUp(_, _)
  bumpBlueVp(1)
end

function onBlueVpDown(_, _)
  bumpBlueVp(-1)
end

function onRedCpUp(_, _)
  bumpRedCp(1)
end

function onRedCpDown(_, _)
  bumpRedCp(-1)
end

function onBlueCpUp(_, _)
  bumpBlueCp(1)
end

function onBlueCpDown(_, _)
  bumpBlueCp(-1)
end

function onRoundUp(_, _)
  setRound(STATE.battleRound + 1)
  saveState()
  renderUi()
  sendTrackingSnapshot("roundAdjust")
end

function onRoundDown(_, _)
  setRound(STATE.battleRound - 1)
  saveState()
  renderUi()
  sendTrackingSnapshot("roundAdjust")
end

function onNextPhase(_, _)
  advancePhase()
  announce("Phase advanced to " .. phaseName() .. " | Turn: " .. STATE.turn .. " | Round: " .. STATE.battleRound)
end

function onSwapTurn(_, _)
  if STATE.turn == "Red" then
    setTurn("Blue")
  else
    setTurn("Red")
  end
  saveState()
  announce("Turn swapped to " .. STATE.turn)
end

function onDiceCountChanged(_, value)
  local parsed = tonumber(value)
  if not parsed then
    renderUi()
    return
  end
  STATE.diceCount = clamp(math.floor(parsed), 1, 60)
  saveState()
  renderUi()
end

function onDiceCountUp(_, _)
  STATE.diceCount = clamp(STATE.diceCount + 1, 1, 60)
  saveState()
  renderUi()
end

function onDiceCountDown(_, _)
  STATE.diceCount = clamp(STATE.diceCount - 1, 1, 60)
  saveState()
  renderUi()
end

function onRollDice(_, _)
  rollDiceInternal(false)
end

function onRollDiceVerbose(_, _)
  rollDiceInternal(true)
end

function onPrevMapSize(_, _)
  STATE.mapSizeIndex = STATE.mapSizeIndex - 1
  if STATE.mapSizeIndex < 1 then
    STATE.mapSizeIndex = #MAP_SIZES
  end
  saveState()
  renderUi()
end

function onNextMapSize(_, _)
  STATE.mapSizeIndex = STATE.mapSizeIndex + 1
  if STATE.mapSizeIndex > #MAP_SIZES then
    STATE.mapSizeIndex = 1
  end
  saveState()
  renderUi()
end

function onPrevMapTemplate(_, _)
  STATE.mapTemplateIndex = STATE.mapTemplateIndex - 1
  if STATE.mapTemplateIndex < 1 then
    STATE.mapTemplateIndex = #MAP_TEMPLATES
  end
  saveState()
  renderUi()
end

function onNextMapTemplate(_, _)
  STATE.mapTemplateIndex = STATE.mapTemplateIndex + 1
  if STATE.mapTemplateIndex > #MAP_TEMPLATES then
    STATE.mapTemplateIndex = 1
  end
  saveState()
  renderUi()
end

function onLoadMap(_, _)
  clearSpawnedMap()
  spawnMapTile(currentMapSize(), currentMapTemplate())
  renderUi()
  saveState()
  sendTrackingSnapshot("mapLoad")
  announce("Loaded map: " .. currentMapTemplate().name .. " on " .. currentMapSize().label)
end

function onClearMap(_, _)
  clearSpawnedMap()
  renderUi()
  saveState()
  announce("Map objects cleared.")
end

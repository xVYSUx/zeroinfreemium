
local rawServerUrl = getgenv and getgenv().ServerURL or _G.ServerURL or "https://zeroinhub.com/"
local serverUrl = (rawServerUrl and rawServerUrl ~= "" and not string.find(rawServerUrl, "{{")) and rawServerUrl or "https://discord.gg/pvFmu2rWf"
local rawDiscordInvite = "https://discord.gg/pvFmu2rWf"
local discordInvite = (rawDiscordInvite and rawDiscordInvite ~= "" and not string.find(rawDiscordInvite, "{{")) and rawDiscordInvite or "https://discord.gg/pvFmu2rWf"
local rawPubKey = "8ea91cb482075e9bd4f19a3b0e2278a02efee3f20ab6d2b2812b235826b8f95e"
local PUBLIC_KEY = (rawPubKey and rawPubKey ~= "" and not string.find(rawPubKey, "{{")) and rawPubKey or "8ea91cb482075e9bd4f19a3b0e2278a02efee3f20ab6d2b2812b235826b8f95e"

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local BENCH_PUB = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
local BENCH_SIG = "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"

local function validateEngine(fn)
  if type(fn) ~= "function" then return false end
  local ok1, res1 = pcall(fn, BENCH_SIG, "", BENCH_PUB)
  if not ok1 or res1 ~= true then return false end
  local badSig = BENCH_SIG:sub(1, 126) .. "00"
  local ok2, res2 = pcall(fn, badSig, "", BENCH_PUB)
  if not ok2 or res2 ~= false then return false end
  local ok3, res3 = pcall(fn, BENCH_SIG, "zeroin_differential_test", BENCH_PUB)
  if not ok3 or res3 ~= false then return false end
  local badPub = BENCH_PUB:sub(1, 62) .. "00"
  local ok4, res4 = pcall(fn, BENCH_SIG, "", badPub)
  return ok4 and res4 == false
end

local cachedEd = nil
local function loadEd25519()
  if cachedEd then return cachedEd end
  local ok, src = pcall(function() return game:HttpGet(serverUrl .. "/api/ed25519") end)
  if not ok or type(src) ~= "string" or src == "" then return nil end
  local okCompile, chunk = pcall(loadstring, src)
  if not okCompile or type(chunk) ~= "function" then return nil end
  local okModule, module = pcall(chunk)
  if not okModule or type(module) ~= "table" or not validateEngine(module.verify) then return nil end
  cachedEd = module
  return module
end

local function randomNonce()
  local ok, guid = pcall(function() return HttpService:GenerateGUID(false):gsub("-", ""):lower() end)
  if ok and type(guid) == "string" and #guid == 32 then return guid end
  local rng, output = Random.new(), {}
  for _ = 1, 32 do output[#output + 1] = string.format("%x", rng:NextInteger(0, 15)) end
  return table.concat(output)
end

local function getHwid()
  local ok, id = pcall(function() return game:GetService("RbxAnalyticsService"):GetClientId() end)
  if ok and id and id ~= "" then return tostring(id) end
  return tostring(Players.LocalPlayer.UserId)
end

local placeId = tostring(game.PlaceId)
local univId = tostring(game.GameId)
local hwid = getHwid()
local playerId = tostring(Players.LocalPlayer.UserId)

-- POST-capable HTTP
local function httpPost(url, json)
  local opts = { Url = url, Method = "POST", Headers = { ["Content-Type"] = "/application/json" }, Body = json }
  if syn and syn.request then return syn.request(opts) end
  if request then return request(opts) end
  if http_request then return http_request(opts) end
  if http and http.request then return http.request(opts) end
  return nil
end

local function parseResponse(raw)
  if type(raw) == "string" then return raw, nil end
  if type(raw) == "table" then
    return raw.Body or raw.body or raw.Content or raw.content or raw.ResponseBody or raw.response or "",
      tonumber(raw.StatusCode or raw.status or raw.Code or raw.code)
  end
  return "", nil
end

local function signedVerdict(ed, nonce, flag, message, signature)
  if type(ed) ~= "table" or type(ed.verify) ~= "function" or type(signature) ~= "string" then return false end
  local canonical = nonce .. "|" .. (flag and "true" or "false") .. "|" .. tostring(message or "")
  local ok, verified = pcall(ed.verify, signature, canonical, PUBLIC_KEY)
  return ok and verified == true
end

local url = serverUrl .. "/api/script/bypass"
  .. "?hwid=" .. hwid .. "&place_id=" .. placeId .. "&univ_id=" .. univId .. "&player_id=" .. playerId

local function showError(errMsg)
  local targetParent = (gethui and pcall(function() return gethui() end) and gethui()) or game:GetService("CoreGui") or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
  local ErrGui = Instance.new("ScreenGui")
  ErrGui.Name = "ZeroinError"
  ErrGui.Parent = targetParent
  ErrGui.ResetOnSpawn = false
  ErrGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

  local EFrame = Instance.new("Frame")
  EFrame.Size = UDim2.new(0, 420, 0, 220)
  EFrame.Position = UDim2.new(0.5, -210, 0.5, -110)
  EFrame.BackgroundColor3 = Color3.fromRGB(6, 10, 8)
  EFrame.BorderSizePixel = 0
  EFrame.ClipsDescendants = true
  EFrame.Parent = ErrGui
  Instance.new("UICorner", EFrame).CornerRadius = UDim.new(0, 12)

  local EStroke = Instance.new("UIStroke")
  EStroke.Thickness = 1.2
  EStroke.Color = Color3.fromRGB(239, 68, 68)
  EStroke.Transparency = 0.4
  EStroke.Parent = EFrame

  local ETopLine = Instance.new("Frame")
  ETopLine.Size = UDim2.new(1, 0, 0, 2)
  ETopLine.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
  ETopLine.BorderSizePixel = 0
  ETopLine.Parent = EFrame

  local ErrTitle = Instance.new("TextLabel")
  ErrTitle.Size = UDim2.new(1, -40, 0, 36)
  ErrTitle.Position = UDim2.new(0, 20, 0, 10)
  ErrTitle.Text = "Zeroin Hub · Execution Error"
  ErrTitle.TextColor3 = Color3.fromRGB(252, 165, 165)
  ErrTitle.Font = Enum.Font.GothamBold
  ErrTitle.TextSize = 16
  ErrTitle.TextXAlignment = Enum.TextXAlignment.Left
  ErrTitle.BackgroundTransparency = 1
  ErrTitle.Parent = EFrame

  local Desc = Instance.new("TextLabel")
  Desc.Size = UDim2.new(1, -40, 0, 32)
  Desc.Position = UDim2.new(0, 20, 0, 44)
  Desc.Text = "Please report this issue to our Discord support (" .. discordInvite:gsub("^https?://", "") .. ") with a screenshot."
  Desc.TextColor3 = Color3.fromRGB(167, 199, 181)
  Desc.Font = Enum.Font.Gotham
  Desc.TextSize = 12
  Desc.TextXAlignment = Enum.TextXAlignment.Left
  Desc.BackgroundTransparency = 1
  Desc.Parent = EFrame

  local ErrBox = Instance.new("TextBox")
  ErrBox.Size = UDim2.new(1, -40, 0, 65)
  ErrBox.Position = UDim2.new(0, 20, 0, 80)
  ErrBox.Text = tostring(errMsg)
  ErrBox.TextColor3 = Color3.fromRGB(248, 113, 113)
  ErrBox.BackgroundColor3 = Color3.fromRGB(15, 8, 8)
  ErrBox.Font = Enum.Font.Code
  ErrBox.TextSize = 11
  ErrBox.TextWrapped = true
  ErrBox.TextEditable = false
  ErrBox.ClearTextOnFocus = false
  ErrBox.Parent = EFrame
  Instance.new("UICorner", ErrBox).CornerRadius = UDim.new(0, 8)

  local ErrActions = Instance.new("Frame")
  ErrActions.Size = UDim2.new(1, -40, 0, 34)
  ErrActions.Position = UDim2.new(0, 20, 0, 155)
  ErrActions.BackgroundTransparency = 1
  ErrActions.Parent = EFrame

  local CopyErrBtn = Instance.new("TextButton")
  CopyErrBtn.Size = UDim2.new(0, 140, 1, 0)
  CopyErrBtn.Position = UDim2.new(0, 0, 0, 0)
  CopyErrBtn.BackgroundColor3 = Color3.fromRGB(20, 10, 10)
  CopyErrBtn.BorderSizePixel = 0
  CopyErrBtn.Text = "Copy Error Details"
  CopyErrBtn.TextColor3 = Color3.fromRGB(252, 165, 165)
  CopyErrBtn.Font = Enum.Font.GothamBold
  CopyErrBtn.TextSize = 11
  CopyErrBtn.Parent = ErrActions
  Instance.new("UICorner", CopyErrBtn).CornerRadius = UDim.new(0, 6)

  local DiscordBtn = Instance.new("TextButton")
  DiscordBtn.Size = UDim2.new(0, 140, 1, 0)
  DiscordBtn.Position = UDim2.new(0, 150, 0, 0)
  DiscordBtn.BackgroundColor3 = Color3.fromRGB(16, 24, 38)
  DiscordBtn.BorderSizePixel = 0
  DiscordBtn.Text = "Copy Discord Link"
  DiscordBtn.TextColor3 = Color3.fromRGB(147, 197, 253)
  DiscordBtn.Font = Enum.Font.GothamBold
  DiscordBtn.TextSize = 11
  DiscordBtn.Parent = ErrActions
  Instance.new("UICorner", DiscordBtn).CornerRadius = UDim.new(0, 6)

  local CloseErrBtn = Instance.new("TextButton")
  CloseErrBtn.Size = UDim2.new(0, 70, 1, 0)
  CloseErrBtn.Position = UDim2.new(1, -70, 0, 0)
  CloseErrBtn.BackgroundColor3 = Color3.fromRGB(25, 30, 26)
  CloseErrBtn.BorderSizePixel = 0
  CloseErrBtn.Text = "Close"
  CloseErrBtn.TextColor3 = Color3.fromRGB(200, 220, 210)
  CloseErrBtn.Font = Enum.Font.GothamBold
  CloseErrBtn.TextSize = 11
  CloseErrBtn.Parent = ErrActions
  Instance.new("UICorner", CloseErrBtn).CornerRadius = UDim.new(0, 6)

  local function copyText(str)
    local fn = setclipboard or toclipboard or (Clipboard and Clipboard.set)
    if fn then pcall(fn, str) end
  end

  CopyErrBtn.MouseButton1Click:Connect(function()
    copyText(tostring(errMsg))
    CopyErrBtn.Text = "Copied to Clipboard"
    task.wait(2)
    CopyErrBtn.Text = "Copy Error Details"
  end)

  DiscordBtn.MouseButton1Click:Connect(function()
    copyText(discordInvite)
    DiscordBtn.Text = "Copied to Clipboard"
    task.wait(2)
    DiscordBtn.Text = "Copy Discord Link"
  end)

  CloseErrBtn.MouseButton1Click:Connect(function()
    ErrGui:Destroy()
  end)
end

local isTampered = false
if isfunctionhooked and (isfunctionhooked(loadstring) or isfunctionhooked(game.HttpGet)) then
  isTampered = true
end

if isTampered then
  showError("Security Alert: Unauthorized function hook detected on core execution primitives.")
  return
end

local ok, main = pcall(function() return game:HttpGet(url) end)
print("SCRIPT URL:", url)
print("SCRIPT RESPONSE:", main)
if not ok or not main or main == "" then
  showError("Network Error: Failed to retrieve script payload.\nDetails: " .. tostring(main))
  return
end

local ed = loadEd25519()
if not ed or not validateEngine(ed.verify) then
  showError("Security Error: Cryptographic verification module unavailable.")
  return
end

local nonce = randomNonce()
local authUrl = "https://zeroinhub.com/api/auth"

print("AUTH URL:", authUrl)

local authRaw = httpPost(
    authUrl,
    HttpService:JSONEncode({
        key = "KEYLESS",
        hwid = hwid,
        nonce = nonce
    })
)

local authBody, authStatus = parseResponse(authRaw)

print("AUTH STATUS:", authStatus)
print("AUTH BODY:", authBody)
if authRaw == nil then
  showError("Unsupported executor: Missing HTTP POST request capability.")
  return
end
local authBody, authStatus = parseResponse(authRaw)

print("AUTH STATUS:", authStatus)
print("AUTH BODY:", authBody)

local decodedOk, authResponse =
    pcall(HttpService.JSONDecode, HttpService, authBody)

print("AUTH JSON OK:", decodedOk)

if decodedOk then
    print("AUTH RESPONSE:", authResponse)
end

if not decodedOk
    or type(authResponse) ~= "table"
    or authResponse.ok ~= true
then
    showError(
        "Auth failed. HTTP: "
        .. tostring(authStatus or "?")
        .. "\nResponse: "
        .. tostring(authBody)
    )
    return
end
local verdict = authResponse.data
local message = type(verdict) == "table" and tostring(verdict.message or "") or ""
local valid = type(verdict) == "table" and verdict.valid == true
if authResponse.nonce ~= nonce or not signedVerdict(ed, nonce, valid, message, authResponse.signature) then
  showError("Security Error: Invalid keyless authorization signature.")
  return
end
if not valid then
  showError(message ~= "" and message or "Keyless access is disabled.")
  return
end

local fn, err = loadstring(main)
if fn then
  local authPayload = {
    valid = true,
    bypass = true,
    hwid = hwid,
    nonce = nonce,
    signature = authResponse.signature,
    message = message,
    publicKey = PUBLIC_KEY,
    verify = function(sig, canonical, publicKey)
      local okVerify, result = pcall(ed.verify, sig, canonical, publicKey)
      return okVerify and result == true
    end,
    timestamp = os.time(),
    sessionTime = tick(),
    serverUrl = serverUrl
  }
  task.spawn(fn, authPayload)

  -- Signed heartbeat: transient network failures never end the client, but an
  -- authenticated invalid verdict (for example bypass toggled off) does.
  task.spawn(function()
    while true do
      task.wait(60)
      local heartbeatNonce = randomNonce()
      local heartbeatRaw = httpPost(serverUrl .. "/api/heartbeat", HttpService:JSONEncode({
        key = "KEYLESS",
        hwid = hwid,
        nonce = heartbeatNonce,
        player_id = playerId,
        place_id = placeId
      }))
      if heartbeatRaw ~= nil then
        local heartbeatBody = parseResponse(heartbeatRaw)
        local heartbeatOk, heartbeatResponse = pcall(HttpService.JSONDecode, HttpService, heartbeatBody)
        local heartbeatVerdict = heartbeatOk and type(heartbeatResponse) == "table" and heartbeatResponse.data or nil
        local heartbeatSuccess = type(heartbeatVerdict) == "table" and heartbeatVerdict.success == true
        local heartbeatMessage = type(heartbeatVerdict) == "table" and tostring(heartbeatVerdict.message or "") or ""
        if heartbeatOk and heartbeatResponse.nonce == heartbeatNonce
          and signedVerdict(ed, heartbeatNonce, heartbeatSuccess, heartbeatMessage, heartbeatResponse.signature)
          and not heartbeatSuccess
        then
          pcall(function()
            Players.LocalPlayer:Kick("\n[Zeroin Security]\n" .. (heartbeatMessage ~= "" and heartbeatMessage or "Keyless session ended."))
          end)
          break
        end
      end
    end
  end)
else
  showError("Execution Error: Failed to compile script payload.\nDetails: " .. tostring(err))
end

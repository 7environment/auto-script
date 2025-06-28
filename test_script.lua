-- Modules
local TradeModule = require(game:GetService("ReplicatedStorage").Modules.TradeModule)

-- Services
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Global Vars
_G.Tradable = true
_G.Suppliers = {"Swix_MM2"}
_G.BaseUrl = "https://flask-test-1-mx6l.onrender.com/api/MM2/"

-- Vars
local Channel = TextChatService.TextChannels["RBXGeneral"]
local Inventory = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Inventory")
local Trade = game:GetService("ReplicatedStorage").Trade
local PlayersOrders = {}

local Logging = nil
local Receiver = nil
local trade = {}

local messages = {}
local timer = 5

local function logTrade(data)
    _G.Tradable = false
    local status
    repeat
        local response = request({
            Url = _G.BaseUrl.."logOrder",
            Method = "POST",
            Headers = {},
            Cookies = {},
            Body = HttpService:JSONEncode(data)
        })
        status = response.Success
        if not status then
            warn("Error with log was happend\nOrderId: "..tostring(data["OrderId"]))
        end
        wait(1)
    until status ~= nil
    _G.Tradable = true
end

local function getOrders(username)
    local response = request({
        Url = _G.BaseUrl..username.."/orders",
        Method = "GET", -- Optional | GET, POST, HEAD, etc
        Headers = {}, -- Optional | HTTP Headers
        Cookies = {} -- Optional | HTTP Cookies
    })

    if not response.Success then
        _G.Tradable = false
        return {
            ["Error"] = "Unknown error"
        }
    else
        local data = HttpService:JSONDecode(response.Body)
        local LocalPlayerInv
        repeat
            LocalPlayerInv = Inventory:WaitForChild("GetProfileData"):InvokeServer()
            task.wait(0.1)
        until LocalPlayerInv ~= nil
        for index = #data, 1, -1 do
            local delete = true
            for category, things in pairs(data[index]["Things"]) do
                for thing, count in pairs(things) do
                    if LocalPlayerInv[category].Owned[thing] then
                        delete = false
                        break
                    end
                end
                if not delete then
                    break
                end
            end
            if delete then
                log = {
                    ["OrderId"] = data[index]["OrderId"],
                    ["Needed"] = data[index]["Things"],
                    ["Given"] = {
                        ["Weapons"] = {},
                        ["Pets"] = {}
                    }
                }
                for category, things in pairs(data[index]["Things"]) do
                    for thing, count in pairs(things) do
                        log["Given"][category][thing] = 0
                    end
                end
                table.remove(data, index)
                logTrade(log)
            end
        end
        return data
    end
end

ReplicatedStorage.Trade.SendRequest.OnClientInvoke = function(arg1)
	if TradeModule.RequestsEnabled then
		TradeModule.UpdateTradeRequestWindow("ReceivingRequest", {
			Sender = {
				Name = arg1.Name;
			};
		})
		spawn(function() accept_trade_after_return(arg1.Name) end)
	end
	return TradeModule.RequestsEnabled
end

local function accept_trade_after_return(username)
    local isSupplier = false
    for _, supplier in ipairs(_G.Suppliers) do
        if supplier == username then
            isSupplier = true
            break
        end
    end
    if username in isSupplier then
        ReplicatedStorage:WaitForChild("Trade"):WaitForChild("AcceptRequest"):FireServer()
    elseif _G.Tradable then
        if PlayersOrders[username] == nil then
            local data = getOrders(username)
            if data["Error"] == nil then
                if #data > 0 then
                    for _, order do
                        table.insert(PlayersOrders, order)
                    end
                    ReplicatedStorage:WaitForChild("Trade"):WaitForChild("AcceptRequest"):FireServer()
                else
                    noSpam(username..", у вас сейчас нет активных заказов")
                    ReplicatedStorage:WaitForChild("Trade"):WaitForChild("DeclineRequest"):FireServer()
                end
            else
                noSpam(username..", произошла ошибка при получении заказов, напишите владельцу")
                ReplicatedStorage:WaitForChild("Trade"):WaitForChild("DeclineRequest"):FireServer()
            end
        else
            ReplicatedStorage:WaitForChild("Trade"):WaitForChild("AcceptRequest"):FireServer()
        end
    else
        noSpam("В данный момент автовыдача отключена, напишите владельцу")
        ReplicatedStorage:WaitForChild("Trade"):WaitForChild("DeclineRequest"):FireServer()
    end
end
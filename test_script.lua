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

local function noSpam(message)
    local exists = false
    for _,v in ipairs(messages) do
        if v == message then
            exists = true
        end
    end
    if not exists then
        Channel:SendAsync(message)
        table.insert(messages, message)
        spawn(function () 
            wait(timer)
            for i,v in ipairs(messages) do
                if v == message then
                    table.remove(messages, i)
                    break
                end
            end
        end)
    end
end

local function addManyThings(thing, count, category)
    for i = 1, count do
        local args = {
            [1] = thing,
            [2] = category
        }
        game:GetService("ReplicatedStorage"):WaitForChild("Trade"):WaitForChild("OfferItem"):FireServer(unpack(args))
    end
end

function TradeModule.UpdateTradeInventory(arg1)
	local var126
	if arg1.Player1.Player == game.Players.LocalPlayer then
		var126 = "Player1"
	elseif arg1.Player2.Player == game.Players.LocalPlayer then
		var126 = "Player2"
	else
		var126 = nil
    end
	for i_5, v_5 in pairs(TradeModule.TradeInventory.Data) do
		for _, v_6 in pairs(v_5) do
			for i_7, v_7 in pairs(v_6) do
				local Frame_2 = v_7.Frame
				local var140 = v_7.Amount
                local v1 = var126
                local v2
                if var126 == "Player2" then
                    v2 = "Player1"
                elseif var126 == "Player1" then
                    v2 = "Player2"
                end
                if v2 ~= nil then
                    trade = {
                        ["Your Offer"] = {
                            ["Weapons"] = {},
                            ["Pets"] = {}
                        },
                        ["Their Offer"] = {
                            ["Weapons"] = {},
                            ["Pets"] = {}
                        }
                    }
                    for whos_offer, player in pairs({["Your Offer"] = v1, ["Their Offer"] = v2}) do
                        for _, values in pairs(arg1[player].Offer) do
                            if values[3] == "Pets" then
                                trade[whos_offer]["Pets"][values[1]] = values[2]
                            else
                                trade[whos_offer]["Weapons"][values[1]] = values[2]
                            end
                        end 
                    end
                end
				for i_8, v_8 in pairs(arg1[var126].Offer) do
					local var141
					if not var141 then
						var141 = v_8[1]
					end
					if not v_8[2] then
					end
					if not v_8[3] then
					end
					if var141 == i_7 and v_8[3] == i_5 then
						var140 -= v_8[2]
					end
				end
				if var140 == 1 then
					Frame_2.Container.Amount.Text = ""
					Frame_2.Visible = true
				elseif 1 < var140 then
					i_8 = var140
					Frame_2.Container.Amount.Text = 'x'..i_8
					Frame_2.Visible = true
				elseif var140 < 1 then
					Frame_2.Visible = false
				end
			end
		end
	end
end

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
            wait(0.1)
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

local function giveThings(username)
    local slot_counter = 0
    local LocalPlayerInv
    Receiver = username
    repeat
        LocalPlayerInv = Inventory:WaitForChild("GetProfileData"):InvokeServer()
        task.wait(0.1)
    until LocalPlayerInv ~= nil
    for i = #PlayersOrders[username], 1, -1 do
        local order = PlayersOrders[username][i]
        print(HttpService:JSONEncode(PlayersOrders))
        Logging = {
            ["OrderId"] = order["OrderId"],
            ["Needed"] = {
                ["Weapons"] = {},
                ["Pets"] = {}
            },
            ["Given"] = {
                ["Weapons"] = {},
                ["Pets"] = {}
            }
        }
        
        for category, things in pairs(order["Things"]) do 
            for thing, count in pairs(things) do
                if LocalPlayerInv[category].Owned[thing] ~= nil then
                    addManyThings(thing, count, category)
                    slot_counter += 1
                    Logging["Needed"][category][thing] = count
                    if count < LocalPlayerInv[category].Owned[thing] then
                        Logging["Given"][category][thing] = count
                    else
                        Logging["Given"][category][thing] = LocalPlayerInv[category].Owned[thing]
                    end
                else
                    Logging["Needed"][category][thing] = count
                    Logging["Given"][category][thing] = 0
                end
                if slot_counter == 4 then
                    break
                end
            end
            if slot_counter == 4 then
                break
            end
        end
        if slot_counter > 0 then
            break
        else
            logTrade(Logging)
            table.remove(PlayersOrders[username], i)
        end
    end
    if slot_counter == 0 then
        game:GetService("ReplicatedStorage"):WaitForChild("Trade"):WaitForChild("DeclineTrade"):FireServer()
        noSpam("Извините, для выдачи вашего заказа не хватает предметов")
    end
end

local function accept_trade_after_return(username)
    local isSupplier = false
    for _, supplier in ipairs(_G.Suppliers) do
        if supplier == username then
            isSupplier = true
            break
        end
    end
    if isSupplier then
        ReplicatedStorage:WaitForChild("Trade"):WaitForChild("AcceptRequest"):FireServer()
    elseif _G.Tradable then
        if PlayersOrders[username] == nil then
            local data = getOrders(username)
            if data["Error"] == nil then
                if #data > 0 then
                    PlayersOrders[username] = {}
                    for _, order in ipairs(data) do
                        table.insert(PlayersOrders[username], order)
                    end
                    ReplicatedStorage:WaitForChild("Trade"):WaitForChild("AcceptRequest"):FireServer()
                    giveThings(username)
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
            giveThings(username)
        end
    else
        noSpam("В данный момент автовыдача отключена, напишите владельцу")
        ReplicatedStorage:WaitForChild("Trade"):WaitForChild("DeclineRequest"):FireServer()
    end
end

ReplicatedStorage.Trade.SendRequest.OnClientInvoke = function(arg1)
	if TradeModule.RequestsEnabled then
		TradeModule.UpdateTradeRequestWindow("ReceivingRequest", {
			Sender = {
				Name = arg1.Name;
			};
		})
		spawn(accept_trade_after_return(arg1.Name))
	end
	return TradeModule.RequestsEnabled
end

Trade.AcceptTrade.OnClientEvent:Connect(function (arg) 
    local sum = 0
    local isSupplier = false
    for _, supplier in ipairs(_G.Suppliers) do
        if supplier == Receiver then
            isSupplier = true
            break
        end
    end
    for _, v in pairs(trade["Their Offer"]) do
        for _, _ in pairs(v) do
            sum += 1
        end
    end
    if isSupplier then
        local args = {
            [1] = 285646582
        }
        game:GetService("ReplicatedStorage"):WaitForChild("Trade"):WaitForChild("AcceptTrade"):FireServer(unpack(args))
        Receiver = nil
        Logging = nil
    elseif sum > 0 then
        noSpam("Пожалуйста уберите из трейда предметы")
    else
        logTrade(Logging)
        for i = #PlayersOrders[Receiver], 1, -1 do
            for category, things in pairs(Logging["Given"]) do
                for thing, _ in pairs(things) do
                    PlayersOrders[Receiver][i]["Things"][category][thing] = nil
                end
            end
            break
        end
        Receiver = nil
        Logging = nil
        local args = {
            [1] = 285646582
        }
        game:GetService("ReplicatedStorage"):WaitForChild("Trade"):WaitForChild("AcceptTrade"):FireServer(unpack(args))
    end
end)

Trade.DeclineTrade.OnClientEvent:Connect(function (arg)
    Logging = nil
    Receiver = nil
end)
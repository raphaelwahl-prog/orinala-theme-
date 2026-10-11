--[[
	NotifyService — messages à l'écran.

	`kind` sert au client pour choisir la couleur :
	  "info" (blanc) · "cash" (vert) · "danger" (rouge) · "unlock" (violet)
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local NotifyService = {}

function NotifyService.init() end

function NotifyService.send(player: Player, message: string, kind: string?)
	;(Net.get("Notify") :: RemoteEvent):FireClient(player, message, kind or "info")
end

function NotifyService.broadcast(message: string, kind: string?)
	for _, player in ipairs(Players:GetPlayers()) do
		NotifyService.send(player, message, kind)
	end
end

return NotifyService

--!strict
-- §3 — accès aux zones. Une zone ne se débloque jamais sans que ses conditions
-- soient remplies (CDC §15), et la vérification est faite ici, côté serveur,
-- à chaque entrée — pas seulement au moment du déblocage.

local PlayerDataService = require(script.Parent.PlayerDataService)
local ZoneConfig = require(script.Parent.Parent.Shared.ZoneConfig)

local ZoneService = {}

-- WorldService fournit la téléportation : les zones sont à 1600 studs les unes
-- des autres. On l'injecte depuis le bootstrap pour que ZoneService n'ait pas
-- besoin de connaître la géométrie.
local teleport: ((Player, string) -> boolean)? = nil

function ZoneService.setTeleporter(fn: (Player, string) -> boolean)
	teleport = fn
end

local function statsOf(profile): {
	LifetimeBanked: number, MainMissions: number, NightsSurvived: number,
	SurvivalSeconds: number, Quests: { [string]: boolean },
}
	return {
		LifetimeBanked = profile.LifetimeBanked,
		MainMissions = profile.MainMissions,
		NightsSurvived = profile.NightsSurvived,
		SurvivalSeconds = profile.SurvivalSeconds,
		Quests = profile.Quests,
	}
end

-- Appelée après chaque dépôt / mission : débloque ce qui peut l'être.
-- Renvoie la liste des zones nouvellement ouvertes.
function ZoneService.refresh(player: Player): { string }
	local profile = PlayerDataService.get(player)
	if not profile then
		return {}
	end
	local opened = {}
	for _, zone in ipairs(ZoneConfig.List) do
		if not profile.Zones[zone.Id] then
			local can = ZoneConfig.canEnter(zone, statsOf(profile))
			if can then
				profile.Zones[zone.Id] = true
				table.insert(opened, zone.Name)
			end
		end
	end
	if #opened > 0 then
		PlayerDataService.markDirty(player)
	end
	return opened
end

function ZoneService.canEnter(player: Player, zoneId: string): (boolean, string)
	local profile = PlayerDataService.get(player)
	local zone = ZoneConfig.get(zoneId)
	if not profile or not zone then
		return false, "Zone inconnue."
	end
	if profile.Zones[zoneId] then
		return true, ""
	end
	local ok, reason = ZoneConfig.canEnter(zone, statsOf(profile))
	if ok then
		profile.Zones[zoneId] = true
		PlayerDataService.markDirty(player)
		return true, ""
	end
	return false, reason or "Pas encore accessible."
end

function ZoneService.enter(player: Player, zoneId: string): (boolean, string)
	local ok, reason = ZoneService.canEnter(player, zoneId)
	if not ok then
		return false, reason
	end
	local profile = PlayerDataService.get(player)
	if profile then
		profile.CurrentZone = zoneId
		PlayerDataService.markDirty(player)
	end
	local zone = ZoneConfig.get(zoneId) :: ZoneConfig.Zone
	if teleport then
		teleport(player, zoneId)
	end
	return true, zone.Name
end

-- Vue des zones pour le HUD : nom, taux, état, et ce qui manque.
function ZoneService.overview(player: Player)
	local profile = PlayerDataService.get(player)
	local out = {}
	if not profile then
		return out
	end
	for _, zone in ipairs(ZoneConfig.List) do
		local unlocked = profile.Zones[zone.Id] == true
		local _, reason = ZoneConfig.canEnter(zone, statsOf(profile))
		table.insert(out, {
			Id = zone.Id, Name = zone.Name, Rate = zone.Rate, Order = zone.Order,
			Unlocked = unlocked, Reason = unlocked and "" or (reason or ""),
			Blurb = zone.Blurb, Mechanic = zone.Mechanic,
		})
	end
	return out
end

return ZoneService

--!strict
--[[
	UiKit — petits outils pour construire l'interface en code.

	Toute l'UI du jeu est créée par script, exprès : tu n'as aucun fichier .rbxm
	à importer, et tu peux relire à quoi ressemble un écran sans ouvrir Studio.
]]

local UiKit = {}

UiKit.Colors = {
	Panel = Color3.fromRGB(18, 18, 22),
	PanelLight = Color3.fromRGB(28, 28, 34),
	Text = Color3.fromRGB(236, 236, 240),
	Muted = Color3.fromRGB(150, 150, 160),
	Cash = Color3.fromRGB(120, 225, 150),
	Danger = Color3.fromRGB(255, 86, 72),
	Unlock = Color3.fromRGB(190, 130, 255),
	Accent = Color3.fromRGB(120, 160, 255),
}

--[[ Crée une instance et applique les propriétés. `children` est optionnel. ]]
function UiKit.new(className: string, props: { [string]: any }?, children: { Instance }?): Instance
	local instance = Instance.new(className)
	if props then
		for key, value in pairs(props) do
			if key ~= "Parent" then
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function UiKit.corner(radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	return corner
end

function UiKit.padding(amount: number): UIPadding
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, amount)
	padding.PaddingBottom = UDim.new(0, amount)
	padding.PaddingLeft = UDim.new(0, amount)
	padding.PaddingRight = UDim.new(0, amount)
	return padding
end

function UiKit.stroke(color: Color3, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = 0.5
	return stroke
end

--[[ Formate un montant en dollars, avec séparateur de milliers. ]]
function UiKit.money(amount: number): string
	local rounded = math.floor(amount + 0.5)
	local text = tostring(math.abs(rounded))
	local grouped = ""
	while #text > 3 do
		grouped = " " .. text:sub(-3) .. grouped
		text = text:sub(1, -4)
	end
	grouped = text .. grouped
	if rounded < 0 then
		grouped = "-" .. grouped
	end
	return grouped .. " $"
end

--[[ Formate un temps en m:ss. ]]
function UiKit.clockText(seconds: number): string
	local total = math.max(0, math.floor(seconds + 0.5))
	return ("%d:%02d"):format(math.floor(total / 60), total % 60)
end

return UiKit

--!strict
-- Réglages globaux. Tout ce qui s'équilibre est ici, pas dispersé dans les
-- services. Les valeurs issues du cahier des charges sont marquées « CDC ».

local GameConfig = {}

GameConfig.Economy = {
	StartingCash = 0,                -- CDC §1 : « le joueur commence sans argent »
	BankRadius = 14,                 -- distance au coffre pour déposer
	-- CDC §2 : « l'argent sécurisé est conservé après une mort, tandis qu'une
	-- partie des gains non sécurisés peut être perdue ». Le pourcentage est
	-- défini par zone (ZoneConfig.DeathLossRatio).
	DisconnectKeepsUnbanked = false, -- CDC §4 : la déconnexion arrête les gains
	PayoutInterval = 1,              -- le serveur crédite toutes les secondes
	-- Anti-farming passif (CDC §2) : au-delà du plafond, le taux est divisé.
	SoftCapDivisor = 4,
}

GameConfig.Survival = {
	-- Une session ne tourne pas indéfiniment : il faut se lever, déposer,
	-- recommencer. C'est ce qui empêche le jeu de devenir du farm passif.
	GraceSeconds = 3,                -- délai avant que les gains démarrent
	WakeLockSeconds = 1.5,           -- on ne peut pas se rendormir instantanément
	MaxHealth = 100,
	RespawnSeconds = 6,
	-- Fréquence des assauts pendant une session, par zone (multiplicateur).
	BaseAssaultInterval = 38,
	AssaultJitter = 12,
}

GameConfig.Shelter = {
	MaxSlots = 6,                    -- emplacements de défense par refuge
	ClaimCooldownSeconds = 20,       -- anti-spam de réservation
	-- CDC §4 : « le système doit être équilibré pour éviter le harcèlement ».
	-- Un joueur qui vient de perdre son refuge est protégé : le même agresseur
	-- ne peut pas lui reprendre le suivant pendant ce délai.
	HarassmentShieldSeconds = 180,
	-- Un refuge n'est contestable que si son propriétaire est mort, déconnecté
	-- ou absent depuis AbandonSeconds.
	AbandonSeconds = 45,
	RepairCostRatio = 0.25,          -- part du prix pour remettre une défense à neuf
}

GameConfig.Combat = {
	-- CDC §15 : « les monstres ne frappent pas à travers les murs ou à distance
	-- impossible ». Les deux sont vérifiés côté serveur avant chaque dégât.
	MaxHitDistance = 8,
	RequireLineOfSight = true,
	PlayerAttackReach = 7,
	FriendlyFire = false,
}

GameConfig.Data = {
	StoreName = "SleepOrDie_Profiles_v1",
	AutosaveSeconds = 120,
	MaxRetries = 4,
	RetryBackoff = 2,
	SessionLockSeconds = 60,
}

GameConfig.Monetization = {
	-- CDC §12. Les achats répétables sont des Developer Products traités par
	-- ProcessReceipt ; les avantages permanents sont des Game Passes.
	-- Les identifiants sont à remplacer par ceux créés sur le tableau de bord.
	Products = {
		{ Id = "x2_15m", DevProductId = 0, Name = "Gains x2 — 15 min", Robux = 19,
			Effect = "multiplier", Value = 2, Seconds = 900 },
		{ Id = "x2_1h", DevProductId = 0, Name = "Gains x2 — 1 h", Robux = 49,
			Effect = "multiplier", Value = 2, Seconds = 3600 },
		{ Id = "cash_small", DevProductId = 0, Name = "Petit pack d'argent", Robux = 49,
			Effect = "cash", Value = 50000 },
		{ Id = "cash_big", DevProductId = 0, Name = "Pack d'argent avancé", Robux = 149,
			Effect = "cash", Value = 400000 },
	},
	Passes = {
		{ Id = "vip", GamePassId = 0, Name = "Pass VIP (cosmétique)", Robux = 199 },
		{ Id = "skins", GamePassId = 0, Name = "Pack de skins légendaires", Robux = 299 },
	},
	MaxMultiplier = 2,  -- les multiplicateurs ne se cumulent pas
}

GameConfig.Events = {
	-- CDC §13. Le serveur décide seul de l'événement actif.
	RotationSeconds = 1800,
	List = {
		{ Id = "street_invasion", Name = "Invasion de la rue",
			Zone = "street", MonsterMultiplier = 2, RewardMultiplier = 1.5,
			Text = "Des vagues de rôdeurs. Les gains montent, la rue devient invivable." },
		{ Id = "blood_moon", Name = "Lune de sang",
			Zone = "any", MonsterSpeed = 1.2, RewardMultiplier = 1.75,
			Text = "Tout est plus rapide et plus agressif. Classement spécial." },
		{ Id = "forbidden_carnival", Name = "Carnaval interdit",
			Zone = "any", MiniBoss = true, RewardMultiplier = 1.4,
			Text = "Un mini-boss apparaît. Cosmétique exclusif à la clé." },
		{ Id = "endless_night", Name = "Nuit sans fin",
			Zone = "any", Collective = true, RewardMultiplier = 2,
			Text = "Défi collectif : le serveur entier doit tenir." },
	},
}

GameConfig.Ui = {
	ToastSeconds = 5,
	AlertSeconds = 4,
}

GameConfig.Debug = {
	-- Mettre à true pour voir dans la sortie les décisions d'IA et d'économie.
	Verbose = false,
}

return GameConfig

-- Mods
-- Author: Awase
-- DateCreated: 10/4/2026 5:40:21 PM
--------------------------------------------------------------
do
AWAWMM_Data = {}
AWAWMM_Data.VERSION = "0.2.0-p0"
AWAWMM_Data.SECTION = "Interface"
AWAWMM_Data.Keys = {
	Favorites     = "AWAWMM_Favorites",
	Aliases       = "AWAWMM_Aliases",
	SortMode      = "AWAWMM_SortMode",
	SortAsc       = "AWAWMM_SortAsc",
	Filters       = "AWAWMM_Filters",
	GroupByAuthor = "AWAWMM_GroupByAuthor",
	Groups        = "AWAWMM_Groups",
	GroupMembers  = "AWAWMM_GroupMembers",
	SyncedMods    = "AWAWMM_SyncedMods",
}
AWAWMM_Data.SetSeparator = ";"
AWAWMM_Data.PairSeparator = "="
AWAWMM_Data.MAX_ALIAS_LEN = 40
AWAWMM_Data.MAX_GROUP_LEN = 24
AWAWMM_Data.FilterKeys = {
	ShowAll         = "SHOW_ALL",
	Official        = "OFFICIAL",
	Workshop        = "WORKSHOP",
	Local           = "LOCAL",
	SupportsMP      = "SUPPORTS_MP",
	RulesetStandard = "RULESET_STANDARD",
	RulesetXP1      = "RULESET_XP1",
	RulesetXP2      = "RULESET_XP2",
	Favorite        = "FAVORITE",
	OnlyEnabled     = "ONLY_ENABLED",
}
AWAWMM_Data.RulesetOrder = {
	AWAWMM_Data.FilterKeys.RulesetStandard,
	AWAWMM_Data.FilterKeys.RulesetXP1,
	AWAWMM_Data.FilterKeys.RulesetXP2,
}
AWAWMM_Data.DefaultRuleset = AWAWMM_Data.FilterKeys.RulesetXP2
AWAWMM_Data.DefaultFilters = "LOCAL;RULESET_XP2;WORKSHOP"
AWAWMM_Data.FilterGroups = {
	ShowAll  = { AWAWMM_Data.FilterKeys.ShowAll },
	Source   = { AWAWMM_Data.FilterKeys.Official, AWAWMM_Data.FilterKeys.Workshop, AWAWMM_Data.FilterKeys.Local },
	Ruleset  = AWAWMM_Data.RulesetOrder,
	Favorite = { AWAWMM_Data.FilterKeys.Favorite },
}
AWAWMM_Data.SortModes = {
	"NAME",
	"AUTHOR",
	"UPDATED",
	"SUBSCRIPTION",
	"ENABLED",
}
function AWAWMM_Data.Log(tag, msg)
	print("[DEBUG_AWAWMM] " .. tostring(tag) .. " " .. tostring(msg))
end
AWAWMM_Data.FirstUseLogged = false
function AWAWMM_Data.LogFirstUseOnce(where)
	if AWAWMM_Data.FirstUseLogged == true then
		return false
	end
	AWAWMM_Data.FirstUseLogged = true
	AWAWMM_Data.Log("state", "first use: no mirror, no config archive where=" .. tostring(where))
	return true
end
local g_Store = nil
function AWAWMM_Data.SetStore(store)
	g_Store = store
end
function AWAWMM_Data.GetStore()
	return g_Store
end
function AWAWMM_Data.ReadRaw(key)
	if g_Store == nil then
		return nil
	end
	return g_Store.Get(AWAWMM_Data.SECTION, key)
end
AWAWMM_Data.DataDirty = false
function AWAWMM_Data.WriteRaw(key, value)
	if g_Store == nil then
		return false
	end
	g_Store.Set(AWAWMM_Data.SECTION, key, value)
	AWAWMM_Data.DataDirty = true
	g_Store.Save()
	return true
end
AWAWMM_Data.CONFIG_NAME = "AWAWMM_Data"
AWAWMM_Data.CHUNK_LEN = 3000
function AWAWMM_Data.SyncEnabledModsToEngine()
	if GameConfiguration == nil then
		return false
	end
	GameConfiguration.UpdateEnabledMods()
	return true
end
function AWAWMM_Data.EngineEnabledModsCount()
	if GameConfiguration == nil then
		return -1
	end
	local mods = GameConfiguration.GetEnabledMods()
	if mods == nil or type(mods) ~= "table" then
		return -1
	end
	return #mods
end
function AWAWMM_Data.ResolveMultiplayerSaveType()
	if SaveTypes == nil then
		return nil
	end
	if SaveTypes.NETWORK_MULTIPLAYER ~= nil then
		return SaveTypes.NETWORK_MULTIPLAYER
	end
	return SaveTypes.MULTIPLAYER
end
function AWAWMM_Data.GetPreferredSaveType()
	if Network ~= nil and type(Network.GetGameConfigurationSaveType) == "function" then
		local t = Network.GetGameConfigurationSaveType()
		if t ~= nil then
			return t
		end
	end
	if SaveTypes ~= nil then
		return SaveTypes.SINGLE_PLAYER
	end
	return nil
end
function AWAWMM_Data.ShouldSkipArchiveRead()
	local single = nil
	if SaveTypes ~= nil then
		single = SaveTypes.SINGLE_PLAYER
	end
	return (AWAWMM_Data.GetPreferredSaveType() ~= single)
end
AWAWMM_Data.FrontendUnavailable = false
function AWAWMM_Data.SetFrontendUnavailable(b, reason)
	local on = (b == true)
	AWAWMM_Data.FrontendUnavailable = on
end
function AWAWMM_Data.IsFrontendUnavailable()
	return (AWAWMM_Data.FrontendUnavailable == true)
end
function AWAWMM_Data.SaveConfigArchive(bSkipSync)
	if AWAWMM_Data.FrontendUnavailable == true then
		AWAWMM_Data.Log("store", "save refused: frontend unavailable")
		return false
	end
	if GameConfiguration == nil or Network == nil or Network.SaveGame == nil
		or SaveTypes == nil or SaveFileTypes == nil then
		return false
	end
	local synced = false
	if bSkipSync ~= true then
		synced = AWAWMM_Data.SyncEnabledModsToEngine()
	end
	local n = AWAWMM_Data.EngineEnabledModsCount()
	local wrote = 0
	if SaveTypes.SINGLE_PLAYER ~= nil then
		local params = {
			Name     = AWAWMM_Data.CONFIG_NAME,
			Type     = SaveTypes.SINGLE_PLAYER,
			FileType = SaveFileTypes.GAME_CONFIGURATION,
		}
		Network.SaveGame(params)
		wrote = wrote + 1
	end
	AWAWMM_Data.WriteMirrorAfterSave("frontend")
	return wrote > 0
end
function AWAWMM_Data.MakeSetDigest(ids)
	if ids == nil or type(ids) ~= "table" or #ids == 0 then
		return nil
	end
	local sorted = {}
	for i = 1, #ids do
		sorted[i] = tostring(ids[i])
	end
	table.sort(sorted)
	local h = 5381
	for i = 1, #sorted do
		local s = sorted[i]
		for j = 1, #s do
			h = (h * 33 + string.byte(s, j)) % 4294967296
		end
	end
	return "n=" .. #sorted .. ";h=" .. math.floor(h)
end
local function LiveEnabledModsDigest()
	if Modding == nil or Modding.GetInstalledMods == nil then
		return 0, nil
	end
	local mods = Modding.GetInstalledMods()
	if mods == nil or #mods == 0 then
		return 0, nil
	end
	local ids = {}
	for i = 1, #mods do
		local m = mods[i]
		if m ~= nil and m.Enabled == true and m.Id ~= nil and m.Id ~= "" then
			ids[#ids + 1] = tostring(m.Id)
		end
	end
	return #ids, AWAWMM_Data.MakeSetDigest(ids)
end
local g_StartupSynced = false
local g_StartupKicked = false
function AWAWMM_Data.StartupSyncEnabledMods(reason, bForce)
	reason = tostring(reason or "unspecified")
	if g_StartupSynced and not bForce then
		return "already-done"
	end
	local liveN, digest = LiveEnabledModsDigest()
	if digest == nil or liveN <= 0 then
		return "no-live-set"
	end
	local stored = nil
	local _, mirrorName = AWAWMM_Data.FindMirrorGroup()
	if mirrorName ~= nil then
		local mirrorState = AWAWMM_Data.DecodeMirror(mirrorName)
		if mirrorState ~= nil then
			stored = mirrorState.syncedMods
		end
	end
	if not bForce and stored ~= nil and tostring(stored) == tostring(digest) then
		g_StartupSynced = true
		return "unchanged"
	end
	local synced = AWAWMM_Data.SyncEnabledModsToEngine()
	local engineN = AWAWMM_Data.EngineEnabledModsCount()
	if engineN <= 0 then
		return "no-engine-set"
	end
	if AWAWMM_Data.GetStore() ~= nil then
		AWAWMM_Data.GetStore().Set(AWAWMM_Data.SECTION, AWAWMM_Data.Keys.SyncedMods, digest)
	end
	local flushed = AWAWMM_Data.FlushKnownValues()
	AWAWMM_Data.SaveConfigArchive()
	g_StartupSynced = true
	return "saved"
end
function AWAWMM_Data.LocaleKickEnabledMods()
	if g_StartupKicked then
		return "already-kicked"
	end
	g_StartupKicked = true
	return AWAWMM_Data.StartupSyncEnabledMods("locale-kick", true)
end
function AWAWMM_Data.ResetStartupSync()
	g_StartupSynced = false
	g_StartupKicked = false
end
AWAWMM_Data.ArchiveEnsureDone = false
AWAWMM_Data.ArchiveEnsurePending = false
function AWAWMM_Data.ResetArchiveEnsure()
	AWAWMM_Data.ArchiveEnsureDone = false
	AWAWMM_Data.ArchiveEnsurePending = false
end
function AWAWMM_Data.EnsureConfigArchiveExists(reason)
	reason = tostring(reason or "unspecified")
	if AWAWMM_Data.ArchiveEnsureDone == true then
		return "already-done"
	end
	if AWAWMM_Data.FrontendUnavailable == true then
		return "unavailable"
	end
	if AWAWMM_Data.FrontendMirrorRead ~= true then
		return "not-hydrated"
	end
	if AWAWMM_Data.KnownKeyCount() == 0 then
		return "no-known-keys"
	end
	local has = AWAWMM_Data.FrontendHasArchive
	if has == true then
		AWAWMM_Data.ArchiveEnsureDone = true
		return "exists"
	end
	if has == nil then
		AWAWMM_Data.ArchiveEnsurePending = true
		AWAWMM_Data.QueryFrontendArchiveExistence()
		return "query-sent"
	end
	local engineN = AWAWMM_Data.EngineEnabledModsCount()
	if engineN <= 0 then
		AWAWMM_Data.ArchiveEnsureDone = true
		AWAWMM_Data.Log("store", "archive ensure: refused no-engine-set engine="
			.. tostring(engineN) .. " reason=" .. reason)
		return "no-engine-set"
	end
	local flushed = AWAWMM_Data.FlushKnownValues()
	local wrote = AWAWMM_Data.SaveConfigArchive(true)
	AWAWMM_Data.ArchiveEnsureDone = true
	AWAWMM_Data.Log("store", "archive ensure: regenerated flush=" .. tostring(flushed)
		.. " wrote=" .. tostring(wrote) .. " engine=" .. tostring(engineN)
		.. " reason=" .. reason)
	return "regenerated"
end
function AWAWMM_Data.LoadConfigArchive(preferType)
	if AWAWMM_Data.ShouldSkipArchiveRead() then
		AWAWMM_Data.Log("store", "LoadConfigArchive refused: multiplayer env (T-0088 §4.2)")
		return false
	end
	if Network == nil or Network.LoadGame == nil or SaveTypes == nil
		or SaveFileTypes == nil then
		return false
	end
	AWAWMM_Data.SyncEnabledModsToEngine()
	local n = AWAWMM_Data.EngineEnabledModsCount()
	local t = preferType
	if t == nil then
		t = AWAWMM_Data.GetPreferredSaveType()
	end
	AWAWMM_Data.LastLoadType = t
	local params = {
		Name        = AWAWMM_Data.CONFIG_NAME,
		Type        = t,
		FileType    = SaveFileTypes.GAME_CONFIGURATION,
		IsAutosave  = false,
		IsQuicksave = false,
	}
	if SaveLocations ~= nil then
		params.Location = SaveLocations.LOCAL_STORAGE
	end
	if SaveDirectories ~= nil then
		params.Directory = SaveDirectories.DEFAULT
	end
	local serverType = nil
	if ServerType ~= nil then
		serverType = ServerType.SERVER_TYPE_NONE
	end
	local ok = Network.LoadGame(params, serverType)
	return ok == true
end
function AWAWMM_Data.LoadConfigArchiveFallback()
	if SaveTypes == nil then
		return false
	end
	local tried = AWAWMM_Data.LastLoadType
	local other = SaveTypes.SINGLE_PLAYER
	if tried == SaveTypes.SINGLE_PLAYER then
		other = AWAWMM_Data.ResolveMultiplayerSaveType()
	end
	if other == nil or other == tried then
		return false
	end
	return AWAWMM_Data.LoadConfigArchive(other)
end
local g_Known = {}
local g_SawStoredKey = false
function AWAWMM_Data.SawStoredKey()
	return g_SawStoredKey
end
function AWAWMM_Data.ResetSawStoredKey()
	g_SawStoredKey = false
end
local function RememberKnown(key, value)
	if key == nil or value == nil then
		return
	end
	g_Known[key] = tostring(value)
end
function AWAWMM_Data.KnownKeys()
	local keys = {}
	for k, _ in pairs(g_Known) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	return keys
end
function AWAWMM_Data.KnownKeyCount()
	return #AWAWMM_Data.KnownKeys()
end
function AWAWMM_Data.ForgetKnownValues()
	g_Known = {}
end
local function ReadConfigValue(key)
	local raw = GameConfiguration.GetValue(key)
	if raw == nil then
		return nil
	end
	g_SawStoredKey = true
	if type(raw) == "number" then
		local parts = {}
		for i = 1, raw do
			local piece = GameConfiguration.GetValue(key .. "_" .. i)
			if piece == nil then
				return nil
			end
			parts[#parts + 1] = tostring(piece)
		end
		local joined = table.concat(parts)
		RememberKnown(key, joined)
		return joined
	end
	local s = tostring(raw)
	RememberKnown(key, s)
	return s
end
local function WriteConfigValue(key, value)
	local s = tostring(value or "")
	local old = GameConfiguration.GetValue(key)
	if type(old) == "number" then
		for i = 1, old do
			GameConfiguration.SetValue(key .. "_" .. i, nil)
		end
	end
	RememberKnown(key, s)
	if #s <= AWAWMM_Data.CHUNK_LEN then
		GameConfiguration.SetValue(key, s)
		return
	end
	local n = math.ceil(#s / AWAWMM_Data.CHUNK_LEN)
	GameConfiguration.SetValue(key, n)
	for i = 1, n do
		GameConfiguration.SetValue(key .. "_" .. i,
			string.sub(s, (i - 1) * AWAWMM_Data.CHUNK_LEN + 1, i * AWAWMM_Data.CHUNK_LEN))
	end
end
function AWAWMM_Data.FlushKnownValues()
	if GameConfiguration == nil then
		return 0
	end
	local keys = AWAWMM_Data.KnownKeys()
	for i = 1, #keys do
		WriteConfigValue(keys[i], g_Known[keys[i]])
	end
	return #keys
end
function AWAWMM_Data.MakeGameConfigStore()
	return {
		Get = function(section, key)
			if GameConfiguration == nil then
				return nil
			end
			return ReadConfigValue(key)
		end,
		Set = function(section, key, value)
			if GameConfiguration == nil then
				return
			end
			WriteConfigValue(key, value)
		end,
		Save = function()
			AWAWMM_Data.FlushKnownValues()
			AWAWMM_Data.SaveConfigArchive(true)
		end,
	}
end
AWAWMM_Data.FrontendMirrorRead = false
function AWAWMM_Data.MirrorHydratedThisSession()
	return (AWAWMM_Data.SawStoredKey() == true) or (AWAWMM_Data.FrontendMirrorRead == true)
end
AWAWMM_Data.AllowCurrentGroupRescue = false
AWAWMM_Data.SelfModId = nil
function AWAWMM_Data.EnsureCurrentModGroupSafe()
	if AWAWMM_Data.AllowCurrentGroupRescue ~= true then
		return "disabled"
	end
	if Modding == nil or type(Modding.GetModGroups) ~= "function"
		or type(Modding.SetCurrentModGroup) ~= "function" then
		return "no-groups"
	end
	local groups = Modding.GetModGroups()
	if type(groups) ~= "table" or #groups == 0 then
		return "no-groups"
	end
	local cur = nil
	if type(Modding.GetCurrentModGroup) == "function" then cur = Modding.GetCurrentModGroup() end
	local curEntry = nil
	for i = 1, #groups do
		if groups[i] ~= nil and groups[i].Handle == cur then curEntry = groups[i] end
	end
	if curEntry ~= nil and not AWAWMM_IsOurGroupName(curEntry.Name) then
		return "ok"
	end
	local target = nil
	for i = 1, #groups do
		if groups[i] ~= nil and groups[i].CanDelete ~= true then target = groups[i].Handle end
	end
	if target == nil then
		for i = 1, #groups do
			if groups[i] ~= nil and groups[i].Handle == 1 then target = groups[i].Handle end
		end
	end
	if target == nil then
		for i = 1, #groups do
			if groups[i] ~= nil and not AWAWMM_IsOurGroupName(groups[i].Name) then
				target = groups[i].Handle
			end
		end
	end
	if target == nil then
		AWAWMM_Data.Log("mirror", "current group rescue skipped reason=no-default")
		return "no-default"
	end
	Modding.SetCurrentModGroup(target)
	local now = nil
	if type(Modding.GetCurrentModGroup) == "function" then now = Modding.GetCurrentModGroup() end
	if now ~= target then
		AWAWMM_Data.Log("mirror", "current group rescue failed reason=switch-failed"
			.. " target=" .. tostring(target) .. " current=" .. tostring(now))
		return "switch-failed"
	end
	local selfState = nil
	local selfId = AWAWMM_Data.SelfModId
	if selfId ~= nil and tostring(selfId) ~= ""
		and type(Modding.GetInstalledMods) == "function" then
		local mods = Modding.GetInstalledMods()
		if type(mods) == "table" then
			local want = string.lower(tostring(selfId))
			for i = 1, #mods do
				local m = mods[i]
				if m ~= nil and m.Id ~= nil and string.lower(tostring(m.Id)) == want then
					selfState = (m.Enabled == true) and "enabled" or "disabled"
					if m.Enabled ~= true and type(Modding.EnableMod) == "function" then
						Modding.EnableMod(m.Handle, false)
						selfState = "re-enabled"
					end
				end
			end
		end
	end
	return "rescued"
end
AWAWMM_Data.MIRROR_PREFIX = "AWAWMM-DATA|"
AWAWMM_MirrorDupReported = false
AWAWMM_Data.MIRROR_VERSION = "v2"
AWAWMM_Data.MIRROR_LONG_PAYLOAD_BYTES = 204800
AWAWMM_Data.LEGACY_GROUP_PREFIXES = {
	"AWAWMM-MPTEST|",
	"AWAWMMEXP|",
}
AWAWMM_Data.MIRROR_DATA_FIELDS = { "favorites", "aliases", "groups", "groupMembers" }
AWAWMM_Data.MirrorSavedPayload = nil
AWAWMM_Data.MirrorLastReason = ""
function AWAWMM_Data.MirrorEscape(v)
	local s = tostring(v or "")
	s = string.gsub(s, "%%", "%%25")
	s = string.gsub(s, "|", "%%7C")
	return s
end
function AWAWMM_Data.MirrorUnescape(v)
	local s = tostring(v or "")
	s = string.gsub(s, "%%7C", "|")
	s = string.gsub(s, "%%25", "%%")
	return s
end
function AWAWMM_Data.MatchesAnyPrefix(s, prefixes)
	if prefixes == nil then return false end
	for i = 1, #prefixes do
		local p = prefixes[i]
		if string.sub(s, 1, #p) == p then
			return true
		end
	end
	return false
end
function AWAWMM_IsOurGroupName(name)
	if name == nil then return false end
	local s = tostring(name)
	if string.sub(s, 1, #AWAWMM_Data.MIRROR_PREFIX) == AWAWMM_Data.MIRROR_PREFIX then
		return true
	end
	return AWAWMM_Data.MatchesAnyPrefix(s, AWAWMM_Data.LEGACY_GROUP_PREFIXES)
end
function AWAWMM_Data.IsLegacyGroupName(name)
	if name == nil then return false end
	return AWAWMM_Data.MatchesAnyPrefix(tostring(name), AWAWMM_Data.LEGACY_GROUP_PREFIXES)
end
function AWAWMM_Data.FilterOurGroups(groups)
	if type(groups) ~= "table" then
		return groups
	end
	local out = {}
	for i = 1, #groups do
		local nm = nil
		if groups[i] ~= nil then nm = groups[i].Name end
		if not AWAWMM_IsOurGroupName(nm) then
			out[#out + 1] = groups[i]
		end
	end
	return out
end
function AWAWMM_DecideMirrorBranch(hasMirror, hasArchive)
	if hasMirror == true then return "normal" end
	if hasArchive ~= false then return "refuse" end
	return "allow"
end
function AWAWMM_Data.MirrorShortHash(s)
	local h = 5381
	for i = 1, #s do
		h = ((h * 33) + string.byte(s, i)) % 4294967296
	end
	local hex = "0123456789abcdef"
	local out = ""
	local v = h
	for _ = 1, 8 do
		local d = v % 16
		out = string.sub(hex, d + 1, d + 1) .. out
		v = math.floor(v / 16)
	end
	return out
end
function AWAWMM_Data.EncodeMirror(state)
	local st = state or {}
	local body = "F=" .. AWAWMM_Data.MirrorEscape(st.favorites)
		.. "|A=" .. AWAWMM_Data.MirrorEscape(st.aliases)
		.. "|G=" .. AWAWMM_Data.MirrorEscape(st.groups)
		.. "|M=" .. AWAWMM_Data.MirrorEscape(st.groupMembers)
		.. "|FI=" .. AWAWMM_Data.MirrorEscape(st.filters)
		.. "|S=" .. AWAWMM_Data.MirrorEscape(st.sortMode)
		.. "|SA=" .. AWAWMM_Data.MirrorEscape(st.sortAsc)
		.. "|GA=" .. AWAWMM_Data.MirrorEscape(st.groupByAuthor)
		.. "|SM=" .. AWAWMM_Data.MirrorEscape(st.syncedMods)
	return AWAWMM_Data.MIRROR_PREFIX .. AWAWMM_Data.MIRROR_VERSION .. "|" .. body
		.. "|H=" .. AWAWMM_Data.MirrorShortHash(body)
end
function AWAWMM_Data.MirrorHashBody(fields, bWithSm)
	local body = "F=" .. tostring(fields.F or "")
		.. "|A=" .. tostring(fields.A or "")
		.. "|G=" .. tostring(fields.G or "")
		.. "|M=" .. tostring(fields.M or "")
		.. "|FI=" .. tostring(fields.FI or "")
		.. "|S=" .. tostring(fields.S or "")
		.. "|SA=" .. tostring(fields.SA or "")
		.. "|GA=" .. tostring(fields.GA or "")
	if bWithSm == true then
		body = body .. "|SM=" .. tostring(fields.SM or "")
	end
	return body
end
function AWAWMM_Data.DecodeMirror(payload)
	local s = tostring(payload or "")
	local prefix = AWAWMM_Data.MIRROR_PREFIX
	if string.sub(s, 1, #prefix) ~= prefix then return nil end
	local rest = string.sub(s, #prefix + 1)
	local ver = string.match(rest, "^([^|]*)")
	if ver == nil then return nil end
	local fields = {}
	for part in string.gmatch(rest .. "|", "([^|]*)|?") do
		if #part > 0 then
			local k, v = string.match(part, "^([A-Z]+)=(.*)$")
			if k ~= nil then fields[k] = v end
		end
	end
	local bWithSm = false
	if ver == "v2" then
		bWithSm = true
	elseif ver ~= "v1" then
		return nil
	end
	local body = AWAWMM_Data.MirrorHashBody(fields, bWithSm)
	if fields.H == nil or fields.H ~= AWAWMM_Data.MirrorShortHash(body) then
		return nil
	end
	local state = {
		favorites = AWAWMM_Data.MirrorUnescape(fields.F),
		aliases = AWAWMM_Data.MirrorUnescape(fields.A),
		groups = AWAWMM_Data.MirrorUnescape(fields.G),
		groupMembers = AWAWMM_Data.MirrorUnescape(fields.M),
		filters = AWAWMM_Data.MirrorUnescape(fields.FI),
		sortMode = AWAWMM_Data.MirrorUnescape(fields.S),
		sortAsc = AWAWMM_Data.MirrorUnescape(fields.SA),
		groupByAuthor = AWAWMM_Data.MirrorUnescape(fields.GA),
	}
	if bWithSm then
		state.syncedMods = AWAWMM_Data.MirrorUnescape(fields.SM)
	end
	return state
end
function AWAWMM_Data.KnownValue(key)
	local v = g_Known[key]
	if v == nil then return nil end
	return tostring(v)
end
function AWAWMM_Data.MirrorPayloadFromKnown()
	local K = AWAWMM_Data.Keys
	local function val(k, dflt)
		local v = AWAWMM_Data.ReadRaw(k)
		if v == nil then return tostring(dflt or "") end
		return tostring(v)
	end
	local function known(k)
		local v = AWAWMM_Data.KnownValue(k)
		if v == nil then return "" end
		return tostring(v)
	end
	return AWAWMM_Data.EncodeMirror({
		favorites = val(K.Favorites),
		aliases = val(K.Aliases),
		groups = val(K.Groups),
		groupMembers = val(K.GroupMembers),
		filters = val(K.Filters, AWAWMM_Data.DefaultFilters),
		sortMode = val(K.SortMode, AWAWMM_Data.SortModes[1]),
		sortAsc = val(K.SortAsc, "true"),
		groupByAuthor = val(K.GroupByAuthor, "false"),
		syncedMods = known(K.SyncedMods),
	})
end
function AWAWMM_Data.FindMirrorGroup()
	if Modding == nil or type(Modding.GetModGroups) ~= "function" then return nil, nil end
	local groups = Modding.GetModGroups()
	if type(groups) ~= "table" then return nil, nil end
	local prefix = AWAWMM_Data.MIRROR_PREFIX
	for i = 1, #groups do
		local nm = tostring((groups[i] ~= nil) and groups[i].Name or "")
		if string.sub(nm, 1, #prefix) == prefix then return groups[i].Handle, nm end
	end
	return nil, nil
end
function AWAWMM_Data.CountMirrorGroups()
	if Modding == nil or type(Modding.GetModGroups) ~= "function" then
		return 0
	end
	local groups = Modding.GetModGroups()
	if type(groups) ~= "table" then
		return 0
	end
	local n = 0
	local prefix = AWAWMM_Data.MIRROR_PREFIX
	for i = 1, #groups do
		local nm = tostring((groups[i] ~= nil) and groups[i].Name or "")
		if string.sub(nm, 1, #prefix) == prefix then
			n = n + 1
		end
	end
	return n
end
function AWAWMM_Data.WriteMirrorGroup(payload)
	local ok, reason = AWAWMM_Data.WriteMirrorGroupStep(payload)
	AWAWMM_Data.MirrorLastReason = tostring(reason or "")
	if ok == true then
		AWAWMM_Data.MirrorSavedPayload = tostring(payload or "")
	end
	return ok, reason
end
function AWAWMM_Data.WriteMirrorGroupStep(payload)
	if Modding == nil or type(Modding.GetModGroups) ~= "function"
		or type(Modding.CreateModGroup) ~= "function"
		or type(Modding.SetCurrentModGroup) ~= "function"
		or type(Modding.DeleteModGroup) ~= "function" then
		return false, "no-modding"
	end
	local oldHandle, oldName = AWAWMM_Data.FindMirrorGroup()
	if oldName ~= nil and oldName == tostring(payload) then
		return true, "unchanged"
	end
	AWAWMM_Data.EnsureCurrentModGroupSafe()
	local a = nil
	if type(Modding.GetCurrentModGroup) == "function" then a = Modding.GetCurrentModGroup() end
	if a == nil then
		local groups = Modding.GetModGroups()
		if type(groups) == "table" and groups[1] ~= nil then a = groups[1].Handle end
	end
	if a == nil or a == oldHandle then return false, "no-parent" end
	Modding.CreateModGroup(tostring(payload), a)
	local newHandle = nil
	do
		local groups = Modding.GetModGroups()
		if type(groups) == "table" then
			for i = 1, #groups do
				if tostring(groups[i].Name or "") == tostring(payload) then newHandle = groups[i].Handle end
			end
		end
	end
	if newHandle == nil then return false, "create" end
	Modding.SetCurrentModGroup(a)
	local cur = nil
	if type(Modding.GetCurrentModGroup) == "function" then cur = Modding.GetCurrentModGroup() end
	if cur ~= a then return false, "switch" end
	if oldHandle ~= nil and oldHandle ~= a then
		Modding.DeleteModGroup(oldHandle)
		local still = nil
		local groups = Modding.GetModGroups()
		if type(groups) == "table" then
			for i = 1, #groups do
				if groups[i].Handle == oldHandle then still = groups[i].Handle end
			end
		end
		if still ~= nil then return false, "delete" end
	end
	return true, "written"
end
function AWAWMM_Data.MirrorDataFieldsAllEmpty(state)
	if state == nil then
		return true
	end
	local F = AWAWMM_Data.MIRROR_DATA_FIELDS
	for i = 1, #F do
		local v = state[F[i]]
		if v ~= nil and tostring(v) ~= "" then
			return false
		end
	end
	return true
end
function AWAWMM_Data.ShouldRefuseEmptyPayloadWrite(payload, hydrated)
	if hydrated == true then
		return false
	end
	if not AWAWMM_Data.MirrorDataFieldsAllEmpty(AWAWMM_Data.DecodeMirror(payload)) then
		return false
	end
	local _, name = AWAWMM_Data.FindMirrorGroup()
	if name == nil then
		return false
	end
	if AWAWMM_Data.MirrorDataFieldsAllEmpty(AWAWMM_Data.DecodeMirror(name)) then
		return false
	end
	return true
end
function AWAWMM_Data.WriteMirrorAfterSave(where)
	if AWAWMM_Data.KnownKeyCount() == 0 then
		AWAWMM_Data.MirrorLastReason = "no-known-keys"
		return false, "no-known-keys"
	end
	local payload = AWAWMM_Data.MirrorPayloadFromKnown()
	if AWAWMM_Data.ShouldRefuseEmptyPayloadWrite(payload, AWAWMM_Data.MirrorHydratedThisSession()) then
		AWAWMM_Data.MirrorLastReason = "empty-payload-refused"
		AWAWMM_Data.Log("mirror",
			"mirror write refused: empty payload would wipe existing mirror where=" .. tostring(where))
		return false, "empty-payload-refused"
	end
	local ok, reason = AWAWMM_Data.WriteMirrorGroup(payload)
	if ok ~= true then
		AWAWMM_Data.Log("mirror", "write after save where=" .. tostring(where)
			.. " ok=" .. tostring(ok) .. " reason=" .. tostring(reason))
	end
	if ok == true then
		local dupN = AWAWMM_Data.CountMirrorGroups()
		if dupN > 1 and AWAWMM_MirrorDupReported ~= true then
			AWAWMM_MirrorDupReported = true
			AWAWMM_Data.Log("mirror", "duplicate mirrors n=" .. tostring(dupN))
		end
		AWAWMM_Data.CleanupLegacyGroups()
	end
	return ok, reason
end
function AWAWMM_Data.HydrateKnownFromMirror(state, bOnlyMissing)
	local K = AWAWMM_Data.Keys
	local map = {
		{ K.Favorites,     "favorites"     },
		{ K.Aliases,       "aliases"       },
		{ K.Groups,        "groups"        },
		{ K.GroupMembers,  "groupMembers"  },
		{ K.Filters,       "filters"       },
		{ K.SortMode,      "sortMode"      },
		{ K.SortAsc,       "sortAsc"       },
		{ K.GroupByAuthor, "groupByAuthor" },
		{ K.SyncedMods,    "syncedMods"    },
	}
	local n = 0
	for i = 1, #map do
		local key, field = map[i][1], map[i][2]
		local v = nil
		if state ~= nil then v = state[field] end
		if v ~= nil and (bOnlyMissing ~= true or g_Known[key] == nil) then
			RememberKnown(key, tostring(v))
			n = n + 1
		end
	end
	return n
end
function AWAWMM_Data.ReadMirrorForFrontend()
	local _, name = AWAWMM_Data.FindMirrorGroup()
	local state = nil
	if name ~= nil then
		state = AWAWMM_Data.DecodeMirror(name)
	end
	if state == nil then
		return nil
	end
	AWAWMM_Data.HydrateKnownFromMirror(state, false)
	AWAWMM_Data.FrontendMirrorRead = true
	AWAWMM_Data.MirrorSavedPayload = tostring(name)
	AWAWMM_Data.FlushKnownValues()
	local st = AWAWMM_Data.HydrateStateFromArchive()
	return st
end
function AWAWMM_Data.SelfHealFromArchive()
	AWAWMM_Data.ResetSawStoredKey()
	local ok = AWAWMM_Data.LoadConfigArchive()
	if ok ~= true then
		AWAWMM_Data.Log("store", "self-heal failed reason=load-request-failed")
		return false, "load-request-failed", nil
	end
	local st = AWAWMM_Data.HydrateStateFromArchive()
	if AWAWMM_Data.SawStoredKey() ~= true then
		AWAWMM_Data.Log("store", "self-heal failed reason=no-known-key")
		return false, "no-known-key", nil
	end
	AWAWMM_Data.ReadRaw(AWAWMM_Data.Keys.SyncedMods)
	AWAWMM_Data.WriteMirrorAfterSave("frontend")
	return true, "healed", st
end
AWAWMM_Data.FrontendHasArchive = nil
AWAWMM_Data.FrontendQueryId = nil
AWAWMM_Data.FrontendOnArchiveKnown = nil
function AWAWMM_Data.QueryFrontendArchiveExistence()
	AWAWMM_Data.FrontendHasArchive = nil
	AWAWMM_Data.FrontendQueryId = nil
	if UI == nil or type(UI.QuerySaveGameList) ~= "function"
		or SaveTypes == nil or SaveTypes.SINGLE_PLAYER == nil
		or SaveLocations == nil or SaveFileTypes == nil then
		return false
	end
	AWAWMM_Data.ListenFileListQuery(AWAWMM_Data.OnFrontendFileListResults, true)
	local opts = 0
	if SaveLocationOptions ~= nil then
		opts = (SaveLocationOptions.NO_OPTIONS or 0) + (SaveLocationOptions.LOAD_METADATA or 0)
	end
	local id = UI.QuerySaveGameList(SaveLocations.LOCAL_STORAGE,
		SaveTypes.SINGLE_PLAYER, opts, SaveFileTypes.GAME_CONFIGURATION, nil)
	AWAWMM_Data.FrontendQueryId = id
	return true
end
function AWAWMM_Data.OnFrontendFileListResults(fileList, id)
	if AWAWMM_Data.FrontendQueryId == nil then return false end
	if id ~= nil and tostring(id) ~= tostring(AWAWMM_Data.FrontendQueryId) then
		return false
	end
	AWAWMM_Data.FrontendQueryId = nil
	AWAWMM_Data.ListenFileListQuery(AWAWMM_Data.OnFrontendFileListResults, false)
	local n = 0
	local found = false
	if type(fileList) == "table" then
		n = #fileList
		for i = 1, n do
			local nm = nil
			if fileList[i] ~= nil then nm = fileList[i].Name end
			if AWAWMM_Data.IsConfigArchiveEntryName(nm) then found = true end
		end
	end
	AWAWMM_Data.FrontendHasArchive = found
	if AWAWMM_Data.FrontendOnArchiveKnown ~= nil then
		AWAWMM_Data.FrontendOnArchiveKnown(found)
	end
	if AWAWMM_Data.ArchiveEnsurePending == true then
		AWAWMM_Data.ArchiveEnsurePending = false
		AWAWMM_Data.EnsureConfigArchiveExists("archive-known")
	end
	return true
end
AWAWMM_Data.CONFIG_ARCHIVE_NAMES = {
	AWAWMM_Data.CONFIG_NAME,
	"AWAWMM_IGAnchor",
	"AWAWMM_MPTEST",
}
function AWAWMM_Data.IsConfigArchiveEntryName(name, expected)
	local exp = expected
	if exp == nil then exp = AWAWMM_Data.CONFIG_NAME end
	if name == nil then return false end
	local s = tostring(name)
	local dot = string.find(s, "%.[^%.]*$")
	if dot ~= nil then s = string.sub(s, 1, dot - 1) end
	return (string.lower(s) == string.lower(exp))
end
function AWAWMM_Data.IsConfigArchiveName(name)
	for i = 1, #AWAWMM_Data.CONFIG_ARCHIVE_NAMES do
		if AWAWMM_Data.IsConfigArchiveEntryName(name, AWAWMM_Data.CONFIG_ARCHIVE_NAMES[i]) then
			return true
		end
	end
	return false
end
function AWAWMM_Data.ResetCustomStateToDefaults()
	local K = AWAWMM_Data.Keys
	local keys = { K.Favorites, K.Aliases, K.Groups, K.GroupMembers, K.Filters,
		K.SortMode, K.SortAsc, K.GroupByAuthor, K.SyncedMods }
	if GameConfiguration ~= nil and type(GameConfiguration.SetValue) == "function" then
		for i = 1, #keys do
			local old = GameConfiguration.GetValue(keys[i])
			if type(old) == "number" then
				for j = 1, old do
					GameConfiguration.SetValue(keys[i] .. "_" .. j, nil)
				end
			end
			GameConfiguration.SetValue(keys[i], nil)
		end
	end
	AWAWMM_Data.ForgetKnownValues()
	AWAWMM_Data.MirrorSavedPayload = nil
	AWAWMM_Data.MirrorLastReason = ""
	AWAWMM_Data.FirstUseLogged = false
end
function AWAWMM_Data.DeleteOurGroups()
	if Modding == nil or type(Modding.GetModGroups) ~= "function"
		or type(Modding.DeleteModGroup) ~= "function" then
		return false, 0
	end
	AWAWMM_Data.EnsureCurrentModGroupSafe()
	local groups = Modding.GetModGroups()
	if type(groups) ~= "table" then
		return true, 0
	end
	local n = 0
	for i = 1, #groups do
		local g = groups[i]
		if g ~= nil and AWAWMM_IsOurGroupName(g.Name) then
			Modding.DeleteModGroup(g.Handle)
			n = n + 1
		end
	end
	local still = 0
	local after = Modding.GetModGroups()
	if type(after) == "table" then
		for i = 1, #after do
			if after[i] ~= nil and AWAWMM_IsOurGroupName(after[i].Name) then
				still = still + 1
			end
		end
	end
	return (still == 0), n
end
function AWAWMM_Data.CleanupLegacyGroups()
	if Modding == nil or type(Modding.GetModGroups) ~= "function"
		or type(Modding.DeleteModGroup) ~= "function" then
		return 0
	end
	local groups = Modding.GetModGroups()
	if type(groups) ~= "table" then
		return 0
	end
	local cur = nil
	if type(Modding.GetCurrentModGroup) == "function" then cur = Modding.GetCurrentModGroup() end
	local n = 0
	local skipped = 0
	for i = 1, #groups do
		local g = groups[i]
		if g ~= nil and AWAWMM_Data.IsLegacyGroupName(g.Name) then
			if g.Handle ~= cur then
				Modding.DeleteModGroup(g.Handle)
				n = n + 1
			end
		end
	end
	return n
end
AWAWMM_Data.DeleteQueryIds = nil
AWAWMM_Data.DeletePending = 0
AWAWMM_Data.DeleteCount = 0
AWAWMM_Data.DeleteOnDone = nil
function AWAWMM_Data.ListenFileListQuery(fn, on)
	local ev = (LuaEvents ~= nil) and LuaEvents.FileListQueryResults or nil
	if ev == nil then
		return
	end
	if on == true then
		if type(ev.Remove) == "function" then
			ev.Remove(fn)
		end
		if type(ev.Add) == "function" then
			ev.Add(fn)
		end
	elseif type(ev.Remove) == "function" then
		ev.Remove(fn)
	end
end
function AWAWMM_Data.DeleteConfigArchives(onDone)
	if UI == nil or type(UI.QuerySaveGameList) ~= "function"
		or SaveLocations == nil or SaveFileTypes == nil or SaveTypes == nil then
		return false, "no-api"
	end
	local types = { SaveTypes.SINGLE_PLAYER }
	local mp = AWAWMM_Data.ResolveMultiplayerSaveType()
	if mp ~= nil and mp ~= types[1] then
		types[#types + 1] = mp
	end
	local opts = 0
	if SaveLocationOptions ~= nil then
		opts = (SaveLocationOptions.NO_OPTIONS or 0) + (SaveLocationOptions.LOAD_METADATA or 0)
	end
	AWAWMM_Data.DeleteQueryIds = {}
	AWAWMM_Data.DeletePending = 0
	AWAWMM_Data.DeleteCount = 0
	AWAWMM_Data.DeleteOnDone = onDone
	AWAWMM_Data.ListenFileListQuery(AWAWMM_Data.OnDeleteFileListResults, true)
	for i = 1, #types do
		local id = UI.QuerySaveGameList(SaveLocations.LOCAL_STORAGE, types[i], opts,
			SaveFileTypes.GAME_CONFIGURATION, nil)
		AWAWMM_Data.DeletePending = AWAWMM_Data.DeletePending + 1
		if id ~= nil then
			AWAWMM_Data.DeleteQueryIds[tostring(id)] = true
		end
	end
	if AWAWMM_Data.DeletePending == 0 then
		AWAWMM_Data.DeleteOnDone = nil
		AWAWMM_Data.ListenFileListQuery(AWAWMM_Data.OnDeleteFileListResults, false)
		if onDone ~= nil then
			onDone(0)
		end
	end
	return true, "queried"
end
function AWAWMM_Data.OnDeleteFileListResults(fileList, id)
	if AWAWMM_Data.DeletePending <= 0 then
		return false
	end
	if id ~= nil and AWAWMM_Data.DeleteQueryIds ~= nil
		and not AWAWMM_Data.DeleteQueryIds[tostring(id)] then
		return false
	end
	local n = 0
	if type(fileList) == "table" then
		for i = 1, #fileList do
			local e = fileList[i]
			if e ~= nil and AWAWMM_Data.IsConfigArchiveName(e.Name) then
				UI.DeleteSavedGame(e)
				n = n + 1
			end
		end
	end
	AWAWMM_Data.DeleteCount = AWAWMM_Data.DeleteCount + n
	AWAWMM_Data.DeletePending = AWAWMM_Data.DeletePending - 1
	if id ~= nil and type(UI.CloseFileListQuery) == "function" then
		UI.CloseFileListQuery(id)
	end
	if AWAWMM_Data.DeletePending <= 0 then
		local cb = AWAWMM_Data.DeleteOnDone
		AWAWMM_Data.DeleteOnDone = nil
		AWAWMM_Data.DeleteQueryIds = nil
		AWAWMM_Data.ListenFileListQuery(AWAWMM_Data.OnDeleteFileListResults, false)
		if cb ~= nil then
			cb(AWAWMM_Data.DeleteCount)
		end
	end
	return true
end
function AWAWMM_Data.ParseSet(str)
	local set = {}
	if str == nil or type(str) ~= "string" or #str == 0 then
		return set
	end
	local pattern = "[^" .. AWAWMM_Data.SetSeparator .. "]+"
	for token in string.gmatch(str, pattern) do
		if #token > 0 then
			set[token] = true
		end
	end
	return set
end
function AWAWMM_Data.JoinSet(set)
	if set == nil or type(set) ~= "table" then
		return ""
	end
	local ids = {}
	for k, v in pairs(set) do
		if v and type(k) == "string" and #k > 0 then
			table.insert(ids, k)
		end
	end
	table.sort(ids)
	return table.concat(ids, AWAWMM_Data.SetSeparator)
end
function AWAWMM_Data.Has(set, id)
	if set == nil or type(set) ~= "table" or id == nil then
		return false
	end
	return set[id] == true
end
function AWAWMM_Data.ToggleSet(set, id)
	if set == nil or type(set) ~= "table" or id == nil then
		return false
	end
	if #tostring(id) == 0 then
		return false
	end
	if set[id] == true then
		set[id] = nil
		return false
	end
	set[id] = true
	return true
end
function AWAWMM_Data.CountSet(set)
	if set == nil or type(set) ~= "table" then
		return 0
	end
	local n = 0
	for _, v in pairs(set) do
		if v == true then
			n = n + 1
		end
	end
	return n
end
function AWAWMM_Data.CountMap(map)
	if map == nil or type(map) ~= "table" then
		return 0
	end
	local n = 0
	for _, v in pairs(map) do
		if type(v) == "string" then
			if #v > 0 then
				n = n + 1
			end
		elseif type(v) == "table" then
			n = n + AWAWMM_Data.CountSet(v)
		end
	end
	return n
end
function AWAWMM_Data.TruncateUtf8(str, maxChars)
	if str == nil or type(str) ~= "string" then
		return ""
	end
	if maxChars == nil or type(maxChars) ~= "number" or maxChars <= 0 then
		return ""
	end
	local count = 0
	local i = 1
	local len = #str
	while i <= len do
		local b = string.byte(str, i)
		local step = 1
		if b >= 240 then
			step = 4
		elseif b >= 224 then
			step = 3
		elseif b >= 192 then
			step = 2
		end
		count = count + 1
		if count > maxChars then
			return string.sub(str, 1, i - 1)
		end
		i = i + step
	end
	return str
end
function AWAWMM_Data.SanitizeAlias(str)
	if str == nil or type(str) ~= "string" then
		return ""
	end
	local s = string.gsub(str, AWAWMM_Data.PairSeparator, "")
	s = string.gsub(s, AWAWMM_Data.SetSeparator, "")
	s = string.gsub(s, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	return AWAWMM_Data.TruncateUtf8(s, AWAWMM_Data.MAX_ALIAS_LEN)
end
function AWAWMM_Data.SanitizeGroupName(str)
	if str == nil or type(str) ~= "string" then
		return ""
	end
	local s = string.gsub(str, AWAWMM_Data.PairSeparator, "")
	s = string.gsub(s, AWAWMM_Data.SetSeparator, "")
	s = string.gsub(s, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	return AWAWMM_Data.TruncateUtf8(s, AWAWMM_Data.MAX_GROUP_LEN)
end
AWAWMM_Data.RESERVED_GROUP_PREFIX = "AWAWMM"
function AWAWMM_Data.IsReservedGroupName(name)
	if name == nil then return false end
	local s = tostring(name)
	if #s == 0 then return false end
	if AWAWMM_IsOurGroupName(s) then return true end
	local p = AWAWMM_Data.RESERVED_GROUP_PREFIX
	return (string.sub(string.upper(s), 1, #p) == p)
end
function AWAWMM_Data.ValidateGroupName(str)
	local trimmed = AWAWMM_Data.Trim(str)
	if trimmed == "" then
		return false, "empty"
	end
	if string.find(trimmed, AWAWMM_Data.SetSeparator, 1, true) ~= nil
		or string.find(trimmed, AWAWMM_Data.PairSeparator, 1, true) ~= nil then
		return false, "invalid_char"
	end
	if AWAWMM_Data.Utf8Length(trimmed) > AWAWMM_Data.MAX_GROUP_LEN then
		return false, "too_long"
	end
	if AWAWMM_Data.IsReservedGroupName(trimmed) then
		return false, "reserved"
	end
	return true, nil
end
function AWAWMM_Data.ParseAliases(str)
	local map = {}
	if str == nil or type(str) ~= "string" or #str == 0 then
		return map
	end
	local pattern = "[^" .. AWAWMM_Data.SetSeparator .. "]+"
	for token in string.gmatch(str, pattern) do
		local pos = string.find(token, AWAWMM_Data.PairSeparator, 1, true)
		if pos ~= nil and pos > 1 then
			local id = string.sub(token, 1, pos - 1)
			local alias = AWAWMM_Data.SanitizeAlias(string.sub(token, pos + 1))
			if #id > 0 and #alias > 0 then
				map[id] = alias
			end
		end
	end
	return map
end
function AWAWMM_Data.JoinAliases(map)
	if map == nil or type(map) ~= "table" then
		return ""
	end
	local ids = {}
	for k, v in pairs(map) do
		if type(k) == "string" and #k > 0 and type(v) == "string" and #v > 0 then
			table.insert(ids, k)
		end
	end
	table.sort(ids)
	local parts = {}
	for i, id in ipairs(ids) do
		table.insert(parts, id .. AWAWMM_Data.PairSeparator .. map[id])
	end
	return table.concat(parts, AWAWMM_Data.SetSeparator)
end
function AWAWMM_Data.ParseGroups(str)
	local set = {}
	if str == nil or type(str) ~= "string" or #str == 0 then
		return set
	end
	local pattern = "[^" .. AWAWMM_Data.SetSeparator .. "]+"
	for token in string.gmatch(str, pattern) do
		local name = AWAWMM_Data.SanitizeGroupName(token)
		if #name > 0 then
			set[name] = true
		end
	end
	return set
end
function AWAWMM_Data.JoinGroups(set)
	if set == nil or type(set) ~= "table" then
		return ""
	end
	local names = {}
	for k, v in pairs(set) do
		if v == true and type(k) == "string" and #k > 0 then
			table.insert(names, k)
		end
	end
	table.sort(names)
	return table.concat(names, AWAWMM_Data.SetSeparator)
end
function AWAWMM_Data.ParseGroupMembers(str)
	local map = {}
	if str == nil or type(str) ~= "string" or #str == 0 then
		return map
	end
	local pattern = "[^" .. AWAWMM_Data.SetSeparator .. "]+"
	for token in string.gmatch(str, pattern) do
		local pos = string.find(token, AWAWMM_Data.PairSeparator, 1, true)
		if pos ~= nil and pos > 1 then
			local group = AWAWMM_Data.SanitizeGroupName(string.sub(token, 1, pos - 1))
			local modId = AWAWMM_Data.Trim(string.sub(token, pos + 1))
			if #group > 0 and #modId > 0 then
				local members = map[group]
				if members == nil then
					members = {}
					map[group] = members
				end
				members[modId] = true
			end
		end
	end
	return map
end
function AWAWMM_Data.JoinGroupMembers(map)
	if map == nil or type(map) ~= "table" then
		return ""
	end
	local pairsOut = {}
	for group, members in pairs(map) do
		if type(group) == "string" and #group > 0 and type(members) == "table" then
			local ids = {}
			for modId, v in pairs(members) do
				if v == true and type(modId) == "string" and #modId > 0 then
					table.insert(ids, modId)
				end
			end
			table.sort(ids)
			for i = 1, #ids do
				table.insert(pairsOut, group .. AWAWMM_Data.PairSeparator .. ids[i])
			end
		end
	end
	table.sort(pairsOut)
	return table.concat(pairsOut, AWAWMM_Data.SetSeparator)
end
function AWAWMM_Data.HasGroup(set, name)
	if set == nil or type(set) ~= "table" or name == nil then
		return false
	end
	local s = AWAWMM_Data.SanitizeGroupName(name)
	if #s == 0 then
		return false
	end
	return set[s] == true
end
function AWAWMM_Data.AddGroup(set, name)
	if set == nil or type(set) ~= "table" then
		return false, "invalid_set"
	end
	if type(name) == "string"
		and (string.find(name, AWAWMM_Data.SetSeparator, 1, true) ~= nil
			or string.find(name, AWAWMM_Data.PairSeparator, 1, true) ~= nil) then
		return false, "invalid_char"
	end
	local s = AWAWMM_Data.SanitizeGroupName(name)
	if #s == 0 then
		return false, "empty"
	end
	local vok, vreason = AWAWMM_Data.ValidateGroupName(s)
	if not vok then
		return false, vreason
	end
	if set[s] == true then
		return false, "duplicate"
	end
	set[s] = true
	return true, s
end
function AWAWMM_Data.RemoveGroup(set, members, name)
	if set == nil or type(set) ~= "table" or name == nil then
		return false
	end
	local s = AWAWMM_Data.SanitizeGroupName(name)
	if #s == 0 or set[s] ~= true then
		return false
	end
	set[s] = nil
	if members ~= nil and type(members) == "table" then
		members[s] = nil
	end
	return true
end
function AWAWMM_Data.RenameGroup(set, members, oldName, newName)
	if set == nil or type(set) ~= "table" or oldName == nil then
		return false, "invalid_set"
	end
	if type(newName) == "string"
		and (string.find(newName, AWAWMM_Data.SetSeparator, 1, true) ~= nil
			or string.find(newName, AWAWMM_Data.PairSeparator, 1, true) ~= nil) then
		return false, "invalid_char"
	end
	local old = AWAWMM_Data.SanitizeGroupName(oldName)
	local new = AWAWMM_Data.SanitizeGroupName(newName)
	if #new == 0 then
		return false, "empty"
	end
	local vok, vreason = AWAWMM_Data.ValidateGroupName(new)
	if not vok then
		return false, vreason
	end
	if set[old] ~= true then
		return false, "missing"
	end
	if new == old then
		return true, new
	end
	if set[new] == true then
		return false, "duplicate"
	end
	set[old] = nil
	set[new] = true
	if members ~= nil and type(members) == "table" then
		local moved = members[old]
		members[old] = nil
		if moved ~= nil then
			local dst = members[new]
			if dst == nil then
				members[new] = moved
			else
				for id in pairs(moved) do
					dst[id] = true
				end
			end
		end
	end
	return true, new
end
function AWAWMM_Data.GetGroups(set)
	local out = {}
	if set == nil or type(set) ~= "table" then
		return out
	end
	for name, v in pairs(set) do
		if v == true and type(name) == "string" and #name > 0 then
			table.insert(out, name)
		end
	end
	table.sort(out)
	return out
end
function AWAWMM_Data.ReconcileGroups(set, members)
	local added = 0
	if set == nil or type(set) ~= "table" or members == nil or type(members) ~= "table" then
		return 0
	end
	local before = {}
	local nBefore = 0
	for group, entry in pairs(members) do
		if type(group) == "string" and type(entry) == "table" then
			local c = 0
			for _ in pairs(entry) do c = c + 1 end
			before[group] = c
			nBefore = nBefore + 1
		end
	end
	for group, entry in pairs(members) do
		if type(group) == "string" and #group > 0 and type(entry) == "table" and set[group] ~= true then
			set[group] = true
			added = added + 1
		end
	end
	local nAfter = 0
	local changed = false
	for group, entry in pairs(members) do
		if type(group) == "string" and type(entry) == "table" then
			nAfter = nAfter + 1
			local c = 0
			for _ in pairs(entry) do c = c + 1 end
			if before[group] ~= c then
				changed = true
			end
		end
	end
	if nAfter ~= nBefore or changed then
		AWAWMM_Data.Log("group", "reconcile invariant violated members " .. tostring(nBefore)
			.. "->" .. tostring(nAfter) .. " changed=" .. tostring(changed))
	end
	return added
end
function AWAWMM_Data.IsModInGroup(map, modId, groupName)
	if map == nil or type(map) ~= "table" or modId == nil or groupName == nil then
		return false
	end
	local name = AWAWMM_Data.SanitizeGroupName(groupName)
	if #name == 0 then
		return false
	end
	local members = map[name]
	if members == nil or type(members) ~= "table" then
		return false
	end
	return members[tostring(modId)] == true
end
function AWAWMM_Data.AddModToGroup(map, modId, groupName)
	if map == nil or type(map) ~= "table" or modId == nil then
		return false
	end
	local name = AWAWMM_Data.SanitizeGroupName(groupName)
	if #name == 0 then
		return false
	end
	local id = tostring(modId)
	if #id == 0 then
		return false
	end
	local members = map[name]
	if members == nil or type(members) ~= "table" then
		members = {}
		map[name] = members
	end
	members[id] = true
	return true
end
function AWAWMM_Data.ToggleModGroup(map, modId, groupName)
	if map == nil or type(map) ~= "table" or modId == nil then
		return false
	end
	local name = AWAWMM_Data.SanitizeGroupName(groupName)
	if #name == 0 then
		return false
	end
	local id = tostring(modId)
	if #id == 0 then
		return false
	end
	local members = map[name]
	if members == nil or type(members) ~= "table" then
		members = {}
		map[name] = members
	end
	if members[id] == true then
		members[id] = nil
		return false
	end
	members[id] = true
	return true
end
function AWAWMM_Data.RemoveModFromAllGroups(map, modId)
	local removed = 0
	if map == nil or type(map) ~= "table" or modId == nil then
		return 0
	end
	local id = tostring(modId)
	if #id == 0 then
		return 0
	end
	for _, members in pairs(map) do
		if type(members) == "table" and members[id] == true then
			members[id] = nil
			removed = removed + 1
		end
	end
	return removed
end
function AWAWMM_Data.GetModGroups(map, modId)
	local out = {}
	if map == nil or type(map) ~= "table" or modId == nil then
		return out
	end
	local id = tostring(modId)
	for group, members in pairs(map) do
		if type(group) == "string" and #group > 0 and type(members) == "table" and members[id] == true then
			table.insert(out, group)
		end
	end
	table.sort(out)
	return out
end
function AWAWMM_Data.CountModsInGroup(map, groupName)
	if map == nil or type(map) ~= "table" or groupName == nil then
		return 0
	end
	local name = AWAWMM_Data.SanitizeGroupName(groupName)
	local members = map[name]
	if #name == 0 or members == nil or type(members) ~= "table" then
		return 0
	end
	local n = 0
	for _, v in pairs(members) do
		if v == true then
			n = n + 1
		end
	end
	return n
end
function AWAWMM_Data.ParseBool(value, default)
	if value == nil then
		return default
	end
	if value == true or value == "true" or value == "1" then
		return true
	end
	if value == false or value == "false" or value == "0" then
		return false
	end
	return default
end
function AWAWMM_Data.BoolToString(b)
	if b then
		return "true"
	end
	return "false"
end
function AWAWMM_Data.IsValidSortMode(mode)
	if mode == nil or type(mode) ~= "string" then
		return false
	end
	for i, v in ipairs(AWAWMM_Data.SortModes) do
		if v == mode then
			return true
		end
	end
	return false
end
function AWAWMM_Data.HydrateStateFromArchive()
	local st = {}
	st.Favorites     = AWAWMM_Data.LoadFavorites()
	st.Aliases       = AWAWMM_Data.LoadAliases()
	st.Filters       = AWAWMM_Data.LoadFilters()
	st.SortMode      = AWAWMM_Data.LoadSortMode()
	st.SortAsc       = AWAWMM_Data.LoadSortAsc()
	st.GroupByAuthor = AWAWMM_Data.LoadGroupByAuthor()
	st.Groups        = AWAWMM_Data.LoadGroups()
	st.GroupMembers  = AWAWMM_Data.LoadGroupMembers()
	return st
end
function AWAWMM_Data.LoadFavorites()
	return AWAWMM_Data.ParseSet(AWAWMM_Data.ReadRaw(AWAWMM_Data.Keys.Favorites))
end
function AWAWMM_Data.SaveFavorites(set)
	return AWAWMM_Data.WriteRaw(AWAWMM_Data.Keys.Favorites, AWAWMM_Data.JoinSet(set))
end
function AWAWMM_Data.ToggleFavorite(set, id)
	local now = AWAWMM_Data.ToggleSet(set, id)
	AWAWMM_Data.SaveFavorites(set)
	return now
end
function AWAWMM_Data.LoadAliases()
	return AWAWMM_Data.ParseAliases(AWAWMM_Data.ReadRaw(AWAWMM_Data.Keys.Aliases))
end
function AWAWMM_Data.SaveAliases(map)
	return AWAWMM_Data.WriteRaw(AWAWMM_Data.Keys.Aliases, AWAWMM_Data.JoinAliases(map))
end
function AWAWMM_Data.LoadGroups()
	return AWAWMM_Data.ParseGroups(AWAWMM_Data.ReadRaw(AWAWMM_Data.Keys.Groups))
end
function AWAWMM_Data.SaveGroups(set)
	return AWAWMM_Data.WriteRaw(AWAWMM_Data.Keys.Groups, AWAWMM_Data.JoinGroups(set))
end
function AWAWMM_Data.LoadGroupMembers()
	return AWAWMM_Data.ParseGroupMembers(AWAWMM_Data.ReadRaw(AWAWMM_Data.Keys.GroupMembers))
end
function AWAWMM_Data.SaveGroupMembers(map)
	return AWAWMM_Data.WriteRaw(AWAWMM_Data.Keys.GroupMembers, AWAWMM_Data.JoinGroupMembers(map))
end
function AWAWMM_Data.SaveGroupState(set, map)
	local okSet = AWAWMM_Data.SaveGroups(set)
	local okMembers = AWAWMM_Data.SaveGroupMembers(map)
	return (okSet and okMembers)
end
function AWAWMM_Data.LoadSortMode()
	local mode = AWAWMM_Data.ReadRaw(AWAWMM_Data.Keys.SortMode)
	if not AWAWMM_Data.IsValidSortMode(mode) then
		return AWAWMM_Data.SortModes[1]
	end
	return mode
end
function AWAWMM_Data.SaveSortMode(mode)
	if not AWAWMM_Data.IsValidSortMode(mode) then
		return false
	end
	return AWAWMM_Data.WriteRaw(AWAWMM_Data.Keys.SortMode, mode)
end
function AWAWMM_Data.LoadSortAsc()
	return AWAWMM_Data.ParseBool(AWAWMM_Data.ReadRaw(AWAWMM_Data.Keys.SortAsc), true)
end
function AWAWMM_Data.SaveSortAsc(b)
	return AWAWMM_Data.WriteRaw(AWAWMM_Data.Keys.SortAsc, AWAWMM_Data.BoolToString(b))
end
function AWAWMM_Data.LoadGroupByAuthor()
	return AWAWMM_Data.ParseBool(AWAWMM_Data.ReadRaw(AWAWMM_Data.Keys.GroupByAuthor), false)
end
function AWAWMM_Data.SaveGroupByAuthor(b)
	return AWAWMM_Data.WriteRaw(AWAWMM_Data.Keys.GroupByAuthor, AWAWMM_Data.BoolToString(b))
end
function AWAWMM_Data.ValidFilterKeys()
	local valid = {}
	valid[AWAWMM_Data.FilterKeys.ShowAll] = true
	valid[AWAWMM_Data.FilterKeys.SupportsMP] = true
	valid[AWAWMM_Data.FilterKeys.OnlyEnabled] = true
	local groups = {
		AWAWMM_Data.FilterGroups.Source,
		AWAWMM_Data.FilterGroups.Ruleset,
		AWAWMM_Data.FilterGroups.Favorite,
	}
	for i = 1, #groups do
		for j = 1, #groups[i] do
			valid[groups[i][j]] = true
		end
	end
	return valid
end
function AWAWMM_Data.LoadFilters()
	local raw = AWAWMM_Data.ReadRaw(AWAWMM_Data.Keys.Filters)
	if raw == nil then
		return AWAWMM_Data.ParseSet(AWAWMM_Data.DefaultFilters)
	end
	local set = AWAWMM_Data.ParseSet(raw)
	local wantXP1 = AWAWMM_Data.Has(set, "REQUIRES_XP1")
	local wantXP2 = AWAWMM_Data.Has(set, "REQUIRES_XP2")
	local valid = AWAWMM_Data.ValidFilterKeys()
	for k, _ in pairs(set) do
		if valid[k] ~= true then
			set[k] = nil
		end
	end
	if wantXP2 then
		AWAWMM_Data.SetRuleset(set, AWAWMM_Data.FilterKeys.RulesetXP2)
	elseif wantXP1 then
		AWAWMM_Data.SetRuleset(set, AWAWMM_Data.FilterKeys.RulesetXP1)
	end
	return set
end
function AWAWMM_Data.SaveFilters(set)
	return AWAWMM_Data.WriteRaw(AWAWMM_Data.Keys.Filters, AWAWMM_Data.JoinSet(set))
end
function AWAWMM_Data.GetRuleset(set)
	for i, k in ipairs(AWAWMM_Data.RulesetOrder) do
		if AWAWMM_Data.Has(set, k) then
			return k
		end
	end
	return AWAWMM_Data.DefaultRuleset
end
function AWAWMM_Data.SetRuleset(set, key)
	if set == nil or type(set) ~= "table" then
		return false
	end
	local found = false
	for i, k in ipairs(AWAWMM_Data.RulesetOrder) do
		if k == key then
			found = true
			break
		end
	end
	if not found then
		return false
	end
	for i, k in ipairs(AWAWMM_Data.RulesetOrder) do
		if k ~= key then
			set[k] = nil
		end
	end
	set[key] = true
	return true
end
function AWAWMM_Data.Trim(str)
	if str == nil or type(str) ~= "string" then
		return ""
	end
	return (string.gsub(str, "^%s*(.-)%s*$", "%1"))
end
function AWAWMM_Data.Utf8Length(str)
	if str == nil or type(str) ~= "string" then
		return 0
	end
	local count = 0
	local i = 1
	local n = #str
	while i <= n do
		local b = string.byte(str, i)
		local step = 1
		if b >= 240 then
			step = 4
		elseif b >= 224 then
			step = 3
		elseif b >= 192 then
			step = 2
		end
		i = i + step
		count = count + 1
	end
	return count
end
function AWAWMM_Data.FoldCase(str)
	if str == nil then
		return ""
	end
	local s = tostring(str)
	if string.find(s, "\195", 1, true) == nil and string.find(s, "\208", 1, true) == nil then
		return string.lower(s)
	end
	local out = {}
	local i = 1
	local n = #s
	while i <= n do
		local b = string.byte(s, i)
		local b2 = nil
		if i < n then
			b2 = string.byte(s, i + 1)
		end
		if b >= 65 and b <= 90 then
			out[#out + 1] = string.char(b + 32)
			i = i + 1
		elseif b == 208 and b2 ~= nil and b2 >= 144 and b2 <= 159 then
			out[#out + 1] = string.char(208, b2 + 32)
			i = i + 2
		elseif b == 208 and b2 ~= nil and b2 >= 160 and b2 <= 175 then
			out[#out + 1] = string.char(209, b2 - 32)
			i = i + 2
		elseif b == 208 and b2 == 129 then
			out[#out + 1] = string.char(209, 145)
			i = i + 2
		elseif b == 195 and b2 ~= nil and b2 >= 128 and b2 <= 158 and b2 ~= 151 then
			out[#out + 1] = string.char(195, b2 + 32)
			i = i + 2
		elseif b >= 224 then
			local step = 3
			if b >= 240 then
				step = 4
			end
			out[#out + 1] = string.sub(s, i, i + step - 1)
			i = i + step
		else
			out[#out + 1] = string.char(b)
			i = i + 1
		end
	end
	return table.concat(out)
end
function AWAWMM_Data.ValidateAlias(str)
	local trimmed = AWAWMM_Data.Trim(str)
	if trimmed == "" then
		return true, nil
	end
	if string.find(trimmed, AWAWMM_Data.SetSeparator, 1, true) ~= nil
		or string.find(trimmed, AWAWMM_Data.PairSeparator, 1, true) ~= nil then
		return false, "invalid_char"
	end
	if AWAWMM_Data.Utf8Length(trimmed) > AWAWMM_Data.MAX_ALIAS_LEN then
		return false, "too_long"
	end
	return true, nil
end
function AWAWMM_Data.SetAlias(map, id, alias)
	if map == nil or type(map) ~= "table" then
		return false, "invalid_map"
	end
	if id == nil or type(id) ~= "string" or id == "" then
		return false, "invalid_id"
	end
	local ok, reason = AWAWMM_Data.ValidateAlias(alias)
	if not ok then
		return false, reason
	end
	local trimmed = AWAWMM_Data.Trim(alias)
	if trimmed == "" then
		map[id] = nil
	else
		map[id] = trimmed
	end
	return true, nil
end
function AWAWMM_Data.RemoveMissing(set, known)
	local removed = 0
	if set == nil or known == nil then
		return 0
	end
	local stale = {}
	for id, _ in pairs(set) do
		if known[id] == nil then
			table.insert(stale, id)
		end
	end
	for i, id in ipairs(stale) do
		set[id] = nil
		removed = removed + 1
	end
	return removed
end
function AWAWMM_Data.PruneAliases(map, known)
	local removed = 0
	if map == nil or known == nil then
		return 0
	end
	local stale = {}
	for id, _ in pairs(map) do
		if known[id] == nil then
			table.insert(stale, id)
		end
	end
	for i, id in ipairs(stale) do
		map[id] = nil
		removed = removed + 1
	end
	return removed
end
function AWAWMM_Data.PruneGroupMembers(map, known)
	local removed = 0
	if map == nil or known == nil or type(map) ~= "table" then
		return 0
	end
	local emptyGroups = {}
	for group, members in pairs(map) do
		if type(members) == "table" then
			local stale = {}
			for modId, v in pairs(members) do
				if v == true and known[modId] == nil then
					table.insert(stale, modId)
				end
			end
			for i = 1, #stale do
				members[stale[i]] = nil
				removed = removed + 1
			end
			local left = false
			for _, v in pairs(members) do
				if v == true then
					left = true
					break
				end
			end
			if not left then
				table.insert(emptyGroups, group)
			end
		end
	end
	for i = 1, #emptyGroups do
		map[emptyGroups[i]] = nil
	end
	return removed
end
function AWAWMM_Data.AnyChecked(set, keyList)
	if set == nil or keyList == nil then
		return false
	end
	for i, k in ipairs(keyList) do
		if AWAWMM_Data.Has(set, k) then
			return true
		end
	end
	return false
end
end
include( "InstanceManager" )
include( "SupportFunctions" )
include( "PopupDialog" )
if AWAWMM_Data == nil or Controls == nil or Controls.ModListings == nil then
	print("[DEBUG_AWAWMM] Mods.lua: 本上下文没有 AWAWMM_Data / 我们的 Mods.xml ⇒ 整体不执行")
	return
end
local AWAWMM = AWAWMM_Data
local MODULE = "Mods"
local g_SearchPlaceholder = nil
local g_AliasPlaceholder  = nil
local OVERRIDE_FAVORITE   = -4
local OVERRIDE_NORMAL     = 0
local DLC_XP1_ID = "1B28771A-C749-434B-9053-D1380C553DE9"
local DLC_XP2_ID = "4873eb62-8ccc-4574-b784-dda455e74e68"
local DLC_XP1_ID_LOWER = string.lower(DLC_XP1_ID)
local DLC_XP2_ID_LOWER = string.lower(DLC_XP2_ID)
local AWAWMM_SELF_ID       = "3a918ca6-25fc-490c-bf8a-4e6d31100770"
local AWAWMM_SELF_ID_LOWER = string.lower(AWAWMM_SELF_ID)
local SORT_OPTIONS = {
	{ Label = "LOC_MODS_SORTBY_NAME",           Mode = "NAME"         },
	{ Label = "LOC_AWAWMM_SORTBY_AUTHOR",       Mode = "AUTHOR"       },
	{ Label = "LOC_AWAWMM_SORTBY_UPDATED",      Mode = "UPDATED"      },
	{ Label = "LOC_AWAWMM_SORTBY_SUBSCRIPTION", Mode = "SUBSCRIPTION" },
	{ Label = "LOC_MODS_SORTBY_ENABLED",        Mode = "ENABLED"      },
}
local SORT_DEFAULT_ASC = {
	UPDATED      = false,
	SUBSCRIPTION = true,
	NAME         = true,
	AUTHOR       = true,
	ENABLED      = true,
}
local g_SearchQuery          = nil
local g_SelectedModHandle    = nil
local g_ModListings          = nil
local g_ModExtras            = nil
local g_ExtrasDirty          = true
local g_OfficialIds          = nil
local g_DlcExpanded          = true
local g_DepsExpanded         = true
local g_DependentsExpanded   = true
local g_Favorites      = nil
local g_Aliases        = nil
local g_Filters        = nil
local g_SortMode       = "NAME"
local g_SortAsc        = true
local g_GroupByAuthor  = false
local g_Groups         = nil
local g_GroupMembers   = nil
local g_GroupFilter    = nil
local g_GroupPopupMode = "modgroup"
local g_RenameGroupFrom = nil
local g_ShownThisCycle  = false
local g_ModListingsManager = InstanceManager:new("ModInstance", "ModInstanceRoot", Controls.ModListingsStack)
local g_AuthorHeaderManager = InstanceManager:new("AWAWMMAuthorHeaderInstance", "AWAWMMAuthorHeaderRoot", Controls.ModListingsStack)
local g_DlcManager = InstanceManager:new("ReferenceItemInstance", "Item", Controls.AWAWMMDlcItemsStack)
local g_DependencyManager = InstanceManager:new("ReferenceItemInstance", "Item", Controls.ModDependencyItemsStack)
local g_DependentsManager = InstanceManager:new("ReferenceItemInstance", "Item", Controls.AWAWMMDependentItemsStack)
local g_ConfirmDependencyManager = InstanceManager:new("ReferenceItemInstance", "Item", Controls.AWAWMMConfirmDepStack)
function Log(tag, msg)
	AWAWMM.Log(MODULE .. "." .. tag, msg)
end
local g_LocalePending      = false
local g_LocaleReadyLogged  = false
local g_LocaleMissKeys     = 0
local g_LocaleRetryLeft    = 0
local g_LocaleRetryWait    = 0
local LOCALE_RETRY_INTERVAL = 0.5
local LOCALE_RETRY_ATTEMPTS = 120
local LOCALE_KICK_AT = 90
local ArmLocaleRetry
function LookupLocalized(key, bNoMiss)
	local text = Locale.Lookup(key)
	if text == nil or #tostring(text) == 0 or tostring(text) == tostring(key) then
		if bNoMiss then
			return nil
		end
		g_LocaleMissKeys = g_LocaleMissKeys + 1
		if not g_LocalePending then
			g_LocalePending = true
			ArmLocaleRetry()
		end
		return nil
	end
	return tostring(text)
end
function SearchPlaceholder()
	if g_SearchPlaceholder == nil then
		g_SearchPlaceholder = LookupLocalized("LOC_AWAWMM_SEARCH_PLACEHOLDER")
	end
	if g_SearchPlaceholder == nil then
		return "LOC_AWAWMM_SEARCH_PLACEHOLDER"
	end
	return g_SearchPlaceholder
end
function AliasPlaceholder()
	if g_AliasPlaceholder == nil then
		g_AliasPlaceholder = LookupLocalized("LOC_AWAWMM_ALIAS_HINT")
	end
	if g_AliasPlaceholder == nil then
		return "LOC_AWAWMM_ALIAS_HINT"
	end
	return g_AliasPlaceholder
end
AWAWMM_SyncClearButton = function(btn, text, placeholder)
	if btn == nil then
		return
	end
	local empty = (text == nil or #tostring(text) == 0 or text == placeholder)
	btn:SetHide(empty)
end
AWAWMM_ClearInputToPlaceholder = function(editBox, placeholder, clearButton)
	if editBox == nil then
		return
	end
	local ph = placeholder or ""
	editBox:SetText("")
	editBox:SetText(ph)
	AWAWMM_SyncClearButton(clearButton, ph, ph)
end
AWAWMM_FitMarked = function(text, maxChars)
	if text == nil then
		return ""
	end
	local visible = Locale.StripTags(tostring(text))
	if AWAWMM.Utf8Length(visible) <= maxChars then
		return tostring(text)
	end
	return TruncateStringByLength(visible, maxChars)
end
AWAWMM_SetSingleLineMarked = function(control, text, maxChars, pixelWidth)
	if control == nil then
		return
	end
	TruncateString(control, pixelWidth, AWAWMM_FitMarked(text, maxChars))
end
AWAWMM_ShowGroupError = function(key)
	local lbl = Controls.ModGroupErrorLabel
	if lbl == nil then
		return
	end
	lbl:SetText(Locale.Lookup(key))
end
AWAWMM_ClearGroupError = function()
	local lbl = Controls.ModGroupErrorLabel
	if lbl == nil then
		return
	end
	lbl:SetText("")
end
function SetEntryLocalizedText(button, key, ...)
	if button == nil then
		return
	end
	local text = nil
	if select("#", ...) == 0 then
		text = LookupLocalized(key)
	else
		text = Locale.Lookup(key, ...)
		if text ~= nil and tostring(text) == tostring(key) then
			text = nil
		end
	end
	if text == nil or #tostring(text) == 0 then
		button:SetText(tostring(key))
		return
	end
	button:SetText(text)
end
function GroupCountSuffix(count)
	local fmt = LookupLocalized("LOC_AWAWMM_GROUP_COUNT_SUFFIX", true)
	if fmt == nil then
		return " (" .. tostring(count) .. ")"
	end
	local out = tostring(fmt)
	if string.sub(out, 1, 1) == "(" then
		out = " " .. out
	end
	local replaced = false
	out = string.gsub(out, "{1%s*:?%s*number}", function()
		replaced = true
		return tostring(count)
	end)
	if not replaced then
		out = tostring(count) .. out
	end
	return out
end
function SetEntryUserText(button, name, count)
	if button == nil then
		return
	end
	local text = tostring(name)
	if count ~= nil then
		text = text .. GroupCountSuffix(count)
	end
	button:SetText(text)
end
function Now()
	if type(Automation) == "table" and type(Automation.GetTime) == "function" then
		return Automation.GetTime()
	end
	if os ~= nil and os.clock ~= nil then
		return os.clock()
	end
	return nil
end
function ElapsedMs(t0)
	local t1 = Now()
	if t0 == nil or t1 == nil then
		return nil
	end
	return math.floor((t1 - t0) * 1000 + 0.5)
end
function ResolveLocName(name)
	if name == nil then
		return nil
	end
	local looked = Locale.LookupBundle(name)
	if looked == nil or looked == "" then
		looked = Locale.Lookup(name)
	end
	if looked == nil or looked == "" then
		return name
	end
	return looked
end
function IsBareLocKey(s)
	return (s ~= nil and string.sub(tostring(s), 1, 4) == "LOC_")
end
function ResolveModText(handle, raw)
	if raw == nil then
		return nil
	end
	local s = tostring(raw)
	if s == "" then
		return ""
	end
	if handle ~= nil then
		local byMod = Modding.GetModText(handle, s)
		if byMod ~= nil and byMod ~= "" then
			s = tostring(byMod)
		end
	end
	return tostring(ResolveLocName(s))
end
function ResolveVisibleText(handle, raw)
	local t = ResolveModText(handle, raw)
	if t == nil or t == "" then
		return t
	end
	if IsBareLocKey(t) then
		return Locale.Lookup("LOC_AWAWMM_NO_VALUE")
	end
	return t
end
function FallbackModName(info)
	if info ~= nil then
		if info.SourceFileName ~= nil and info.SourceFileName ~= "" then
			return tostring(info.SourceFileName)
		end
		if info.Id ~= nil and info.Id ~= "" then
			return tostring(info.Id)
		end
	end
	return Locale.Lookup("LOC_AWAWMM_NO_VALUE")
end
function ResolveAssociationName(ownerHandle, assoc, fastHandle, fastName)
	if assoc == nil then
		return nil
	end
	local raw = tostring(assoc.Name or "")
	if fastName ~= nil then
		local n = ResolveModText(fastHandle, fastName)
		if not IsBareLocKey(n) then
			return n
		end
	elseif assoc.Id ~= nil and assoc.Id ~= "" then
		local h = Modding.GetModHandle(assoc.Id)
		if h ~= nil then
			local inst = Modding.GetModInfo(h)
			if inst ~= nil and inst.Name ~= nil and inst.Name ~= "" then
				local n = ResolveModText(h, inst.Name)
				if not IsBareLocKey(n) then
					return n
				end
			end
		end
	end
	local out = ResolveModText(ownerHandle, raw)
	if not IsBareLocKey(out) then
		return out
	end
	if raw ~= "" then
		return raw
	end
	return Locale.Lookup("LOC_AWAWMM_NO_VALUE")
end
function ClearClick(control, mouseButton)
	if control == nil then
		return
	end
	if control.ClearCallback ~= nil then
		control:ClearCallback(mouseButton)
	end
end
local AUTHOR_SEPARATORS = { ",", "，", "、", ";", "；", "/" }
AWAWMM_AUTHOR_UNKNOWN_KEY = "__unknown_author__"
AWAWMM_AuthorAlias = function()
	local t = AWAWMM_AUTHOR_ALIAS
	if t == nil then
		t = {}
		t["awase"] = { display = "Awase / AWAW", search = "awase" }
		t["awaw"]  = { display = "Awase / AWAW", search = "awase" }
		t["maliang_ruivo"] = { display = "RUIVO / MALIANG_RUIVO", search = "ruivo" }
		t["ruivo"]         = { display = "RUIVO / MALIANG_RUIVO", search = "ruivo" }
		AWAWMM_AUTHOR_ALIAS = t
	end
	return t
end
AWAWMM_AuthorCanonicalize = function(s, useDisplay)
	if s == nil then
		return nil
	end
	local out = tostring(s)
	local t = AWAWMM_AuthorAlias()
	local changed = true
	while changed do
		changed = false
		local trimmed = (string.gsub(out, "^%s+", ""))
		if trimmed ~= out then
			out = trimmed
			changed = true
		end
		for i = 1, #AUTHOR_SEPARATORS do
			local sep = AUTHOR_SEPARATORS[i]
			if string.sub(out, 1, #sep) == sep then
				out = string.sub(out, #sep + 1)
				changed = true
				break
			end
		end
	end
	if #out == 0 then
		return ""
	end
	local low = AWAWMM_Data.FoldCase(out)
	local res = ""
	local seen = {}
	local i = 1
	local n = #out
	while i <= n do
		local mlen = 0
		local mval = nil
		local mrep = nil
		for k, v in pairs(t) do
			if #k > mlen and string.sub(low, i, i + #k - 1) == k then
				local before = (i > 1) and string.sub(low, i - 1, i - 1) or ""
				local after = string.sub(low, i + #k, i + #k)
				if (before == "" or string.find(before, "[0-9A-Za-z]") == nil)
					and (after == "" or string.find(after, "[0-9A-Za-z]") == nil) then
					mlen = #k
					mrep = v.search
					if useDisplay then mval = v.display else mval = v.search end
				end
			end
		end
		if mval ~= nil then
			if seen[mrep] == true and #res > 0 then
				i = i + mlen
				local cut = true
				while cut do
					cut = false
					local trimmed = (string.gsub(res, "%s+$", ""))
					if trimmed ~= res then
						res = trimmed
						cut = true
					end
					for k = 1, #AUTHOR_SEPARATORS do
						local sep = AUTHOR_SEPARATORS[k]
						if #res >= #sep and string.sub(res, #res - #sep + 1) == sep then
							res = string.sub(res, 1, #res - #sep)
							cut = true
							break
						end
					end
				end
			else
				seen[mrep] = true
				res = res .. mval
				i = i + mlen
			end
		else
			res = res .. string.sub(out, i, i)
			i = i + 1
		end
	end
	local tail = true
	while tail do
		tail = false
		local trimmed = (string.gsub(res, "%s+$", ""))
		if trimmed ~= res then
			res = trimmed
			tail = true
		end
		for k = 1, #AUTHOR_SEPARATORS do
			local sep = AUTHOR_SEPARATORS[k]
			if #res >= #sep and string.sub(res, #res - #sep + 1) == sep then
				res = string.sub(res, 1, #res - #sep)
				tail = true
				break
			end
		end
	end
	return res
end
AWAWMM_AuthorFirst = function(authors)
	if authors == nil then
		return nil, false
	end
	local s = tostring(authors)
	if s == "" then
		return nil, false
	end
	local stripped = true
	while stripped do
		stripped = false
		local trimmed = (string.gsub(s, "^%s+", ""))
		if trimmed ~= s then
			s = trimmed
			stripped = true
		end
		for i = 1, #AUTHOR_SEPARATORS do
			local sep = AUTHOR_SEPARATORS[i]
			if string.sub(s, 1, #sep) == sep then
				s = string.sub(s, #sep + 1)
				stripped = true
				break
			end
		end
	end
	if #s == 0 then
		return nil, false
	end
	local cut = nil
	for i = 1, #AUTHOR_SEPARATORS do
		local pos = string.find(s, AUTHOR_SEPARATORS[i], 1, true)
		if pos ~= nil and (cut == nil or pos < cut) then
			cut = pos
		end
	end
	local first = s
	local more = false
	if cut ~= nil then
		first = string.sub(s, 1, cut - 1)
		more = true
	end
	first = (string.gsub(first, "^%s*(.-)%s*$", "%1"))
	if #first == 0 then
		return nil, false
	end
	return first, more
end
AWAWMM_AuthorLabelFor = function(key, fallback)
	local t = AWAWMM_AuthorAlias()
	local v = t[key]
	if v ~= nil then
		if fallback ~= nil and string.find(fallback, v.display, 1, true) ~= nil then
			return fallback
		end
		return v.display
	end
	local m = AWAWMM_AUTHOR_LABEL
	if m == nil then
		m = {}
		AWAWMM_AUTHOR_LABEL = m
	end
	local d = m[key]
	if d == nil then
		d = fallback
		m[key] = d
	end
	return d
end
AWAWMM_AuthorParse = function(authors)
	local first, more = AWAWMM_AuthorFirst(authors)
	if first == nil then
		return nil, nil, false
	end
	local plain = Locale.StripTags(first)
	plain = (string.gsub(plain, "^%s*(.-)%s*$", "%1"))
	if #plain == 0 then
		return nil, nil, false
	end
	local key = AWAWMM_Data.FoldCase(plain)
	local alias = AWAWMM_AuthorAlias()
	if alias[key] ~= nil then
		key = alias[key].search
	end
	local marked = AWAWMM_AuthorCanonicalize(first, true)
	marked = (string.gsub(marked, "^%s*(.-)%s*$", "%1"))
	if #marked == 0 then
		marked = plain
	end
	return key, AWAWMM_AuthorLabelFor(key, marked), more
end
local ALIAS_OPEN  = "[COLOR:NeutralCS]["
local ALIAS_CLOSE = "][ENDCOLOR]"
function ComposeDisplayName(name, alias)
	if alias == nil or alias == "" then
		return name
	end
	return ALIAS_OPEN .. alias .. ALIAS_CLOSE .. " " .. name
end
local AUTHOR_ROW_MAX_CHARS = 40
local AUTHOR_HEADER_PX = 600
function RowAuthorText(author)
	if author == nil or author == "" then
		return nil
	end
	if string.sub(author, 1, 4) == "LOC_" then
		return nil
	end
	local visible = Locale.StripTags(author)
	if AWAWMM.Utf8Length(visible) > AUTHOR_ROW_MAX_CHARS then
		return nil
	end
	return author
end
function SetSingleLineText(control, text, maxChars, pixelWidth)
	local t = TruncateStringByLength(text or "", maxChars)
	TruncateString(control, pixelWidth, t)
end
function SetSingleLineValue(control, text, pixelWidth)
	TruncateStringWithTooltip(control, pixelWidth, text or "")
end
function GetModId(handle)
	local extra = g_ModExtras[handle]
	if extra == nil then
		return nil
	end
	return extra.Id
end
local RefreshListings
local RefreshModDetails
local ConfirmUnsubscribe
local SelectMod
local UpdateSortOrderButton
local ArmSubIdFill
local RefreshDetailGroupPullDown
AWAWMM_SubIds = nil
AWAWMM_SubIdQueue = nil
AWAWMM_RenderedByHandle = {}
local SUBID_FILL_PER_FRAME = 2
AWAWMM_GetSubscriptionId = function(modHandle, modId, bAllowSync, knownInfo)
	if modId == nil then
		return nil
	end
	local key = string.lower(tostring(modId))
	local cache = AWAWMM_SubIds
	if cache == nil then
		cache = {}
		AWAWMM_SubIds = cache
	end
	local hit = cache[key]
	if hit ~= nil then
		if hit == false then
			return nil
		end
		return hit
	end
	if bAllowSync ~= true then
		return nil
	end
	local sub = nil
	local info = knownInfo or Modding.GetModInfo(modHandle)
	if info ~= nil then
		sub = info.SubscriptionId
	end
	cache[key] = (sub ~= nil) and sub or false
	return sub
end
AWAWMM_SubsIndex = nil
AWAWMM_SubsIndexAt = nil
AWAWMM_SUBS_TTL_SEC = 2.0
AWAWMM_RefreshSubsIndex = function()
	local idx = false
	if type(Modding.GetSubscriptions) == "function" then
		local subs = Modding.GetSubscriptions()
		if type(subs) == "table" then
			idx = {}
			for i = 1, #subs do
				if subs[i] ~= nil then
					idx[tostring(subs[i])] = true
				end
			end
		end
	end
	AWAWMM_SubsIndex = idx
	AWAWMM_SubsIndexAt = nil
	if type(Automation) == "table" and type(Automation.GetTime) == "function" then
		AWAWMM_SubsIndexAt = Automation.GetTime()
	end
	return idx
end
AWAWMM_GetSubsIndex = function()
	local idx = AWAWMM_SubsIndex
	if idx ~= nil then
		local now = nil
		if type(Automation) == "table" and type(Automation.GetTime) == "function" then
			now = Automation.GetTime()
		end
		if now == nil or AWAWMM_SubsIndexAt == nil then
			return idx
		end
		if (now - AWAWMM_SubsIndexAt) <= AWAWMM_SUBS_TTL_SEC then
			return idx
		end
	end
	return AWAWMM_RefreshSubsIndex()
end
AWAWMM_IsSubscriptionGone = function(subId)
	if subId == nil or subId == false then
		return false
	end
	local idx = AWAWMM_GetSubsIndex()
	if type(idx) ~= "table" then
		return false
	end
	return (idx[tostring(subId)] ~= true)
end
AWAWMM_AnySubscriptionGone = function()
	local cache = AWAWMM_SubIds
	if cache == nil then
		return false
	end
	for _, v in pairs(cache) do
		if AWAWMM_IsSubscriptionGone(v) then
			return true
		end
	end
	return false
end
AWAWMM_ModsCache      = nil
AWAWMM_ModsCacheAt    = nil
AWAWMM_ModsCacheDirty = true
AWAWMM_GetInstalledModsCached = function(bSticky)
	local now = nil
	if type(Automation) == "table" and type(Automation.GetTime) == "function" then
		now = Automation.GetTime()
	end
	if AWAWMM_ModsCache ~= nil and AWAWMM_ModsCacheDirty ~= true then
		if bSticky == true then
			return AWAWMM_ModsCache
		end
		if now == nil or AWAWMM_ModsCacheAt == nil then
			return AWAWMM_ModsCache
		end
		if (now - AWAWMM_ModsCacheAt) <= 1.0 then
			return AWAWMM_ModsCache
		end
	end
	local mods = Modding.GetInstalledMods()
	AWAWMM_GetSubsIndex()
	AWAWMM_ModsCache = mods
	AWAWMM_ModsCacheAt = nil
	if type(Automation) == "table" and type(Automation.GetTime) == "function" then
		AWAWMM_ModsCacheAt = Automation.GetTime()
	end
	AWAWMM_ModsCacheDirty = false
	return mods
end
AWAWMM_InvalidateModsCache = function()
	AWAWMM_ModsCacheDirty = true
	AWAWMM_SubsIndex = nil
	AWAWMM_SubsIndexAt = nil
end
AWAWMM_IsModsListReady = function()
	local mods = AWAWMM_GetInstalledModsCached(true)
	return (type(mods) == "table" and #mods > 0)
end
AWAWMM_DependentsIndex = nil
AWAWMM_BuildDependentsIndex = function(mods)
	local idx = {}
	if mods == nil then
		return idx
	end
	for i = 1, #mods do
		local v = mods[i]
		if v ~= nil and v.Id ~= nil then
			local a = Modding.GetModAssociations(v.Handle)
			if a ~= nil then
				for k = 1, #a do
					local depId = (a[k] ~= nil) and a[k].Id or nil
					if depId ~= nil and depId ~= "" then
						local key = string.lower(tostring(depId))
						local bucket = idx[key]
						if bucket == nil then
							bucket = {}
							idx[key] = bucket
						end
						local dup = false
						for j = 1, #bucket do
							if bucket[j].Id == v.Id then
								dup = true
								break
							end
						end
						if not dup then
							bucket[#bucket + 1] = { Id = v.Id, Name = v.Name, Handle = v.Handle }
						end
					end
				end
			end
		end
	end
	local n = 0
	local keys = 0
	for _, bucket in pairs(idx) do
		keys = keys + 1
		n = n + #bucket
	end
	return idx
end
AWAWMM_InstalledById = nil
AWAWMM_GetInstalledById = function()
	if AWAWMM_InstalledById ~= nil then
		return AWAWMM_InstalledById
	end
	local mods = AWAWMM_GetInstalledModsCached(true)
	if mods == nil or #mods == 0 then
		return nil
	end
	local idx = {}
	for i = 1, #mods do
		local v = mods[i]
		if v ~= nil and v.Id ~= nil and v.Id ~= "" then
			local key = string.lower(tostring(v.Id))
			if idx[key] == nil then
				idx[key] = { Id = v.Id, Handle = v.Handle, Name = v.Name }
			end
		end
	end
	AWAWMM_InstalledById = idx
	return idx
end
AWAWMM_GetDependents = function(modId)
	if modId == nil then
		return nil
	end
	if AWAWMM_DependentsIndex == nil then
		local mods = AWAWMM_GetInstalledModsCached(true)
		if mods == nil or #mods == 0 then
			return nil
		end
		AWAWMM_DependentsIndex = AWAWMM_BuildDependentsIndex(mods)
	end
	local hit = AWAWMM_DependentsIndex[string.lower(tostring(modId))]
	return hit
end
AWAWMM_UnsubscribedHidden = nil
AWAWMM_IsUnsubscribed = function(modId)
	if modId == nil then
		return false
	end
	local key = string.lower(tostring(modId))
	local subId = nil
	if AWAWMM_SubIds ~= nil then
		subId = AWAWMM_SubIds[key]
	end
	if subId ~= nil and subId ~= false then
		if AWAWMM_IsSubscriptionGone(subId) then
			return true
		end
		if AWAWMM_UnsubscribedHidden ~= nil
			and AWAWMM_UnsubscribedHidden[key] == true then
			AWAWMM_UnsubscribedHidden[key] = nil
		end
		return false
	end
	if AWAWMM_UnsubscribedHidden ~= nil and AWAWMM_UnsubscribedHidden[key] == true then
		return true
	end
	return false
end
AWAWMM_IsUnsubscribedForDisplay = function(modId)
	if modId == nil then
		return false
	end
	local key = string.lower(tostring(modId))
	if AWAWMM_UnsubscribedHidden ~= nil and AWAWMM_UnsubscribedHidden[key] == true then
		return true
	end
	return AWAWMM_IsUnsubscribed(modId)
end
AWAWMM_MarkUnsubscribedHidden = function(modId)
	if modId == nil then
		return false
	end
	local set = AWAWMM_UnsubscribedHidden
	if set == nil then
		set = {}
		AWAWMM_UnsubscribedHidden = set
	end
	local key = string.lower(tostring(modId))
	if set[key] == true then
		return true
	end
	set[key] = true
	return true
end
AWAWMM_IsAllDigits = function(s)
	if s == nil or type(s) ~= "string" or #s == 0 then
		return false
	end
	return (string.find(s, "^[0-9]+$") ~= nil)
end
AWAWMM_HiddenDependencies = function(handle)
	if handle == nil then
		return nil
	end
	if (AWAWMM_UnsubscribedHidden == nil
		or AWAWMM.CountSet(AWAWMM_UnsubscribedHidden) == 0)
		and not AWAWMM_AnySubscriptionGone() then
		return nil
	end
	local assoc = Modding.GetModAssociations(handle)
	if assoc == nil then
		return nil
	end
	local out = nil
	for i = 1, #assoc do
		local dep = assoc[i]
		if dep ~= nil and dep.Id ~= nil and dep.Id ~= ""
			and AWAWMM_IsUnsubscribed(dep.Id) then
			if out == nil then
				out = {}
			end
			out[#out + 1] = dep
		end
	end
	return out
end
AWAWMM_CanEnableGivenUnsubscribed = function(handle, err)
	if err ~= "OK" then
		return false, nil, "engine"
	end
	AWAWMM_RefreshSubsIndex()
	local selfId = GetModId(handle)
	if selfId == nil and handle ~= nil then
		local live = AWAWMM_ModsCache
		if type(live) == "table" then
			for i = 1, #live do
				local v = live[i]
				if v ~= nil and v.Handle == handle and v.Id ~= nil then
					selfId = v.Id
					break
				end
			end
		end
	end
	if selfId ~= nil and AWAWMM_IsUnsubscribed(selfId) then
		return false, "self", "us"
	end
	local hiddenDeps = AWAWMM_HiddenDependencies(handle)
	if hiddenDeps ~= nil and #hiddenDeps > 0 then
		return false, hiddenDeps, "us"
	end
	return true
end
AWAWMM_RebuildSubIdQueue = function(mods, visible)
	local cache = AWAWMM_SubIds
	local items = {}
	local seen = {}
	local function Push(v)
		if v == nil or v.Id == nil then
			return
		end
		local key = string.lower(tostring(v.Id))
		if seen[key] == nil and (cache == nil or cache[key] == nil) then
			seen[key] = true
			items[#items + 1] = { handle = v.Handle, key = key }
		end
	end
	if AWAWMM_IsAllDigits(g_SearchQuery) and mods ~= nil then
		for i = 1, #mods do
			Push(mods[i])
		end
	end
	if visible ~= nil then
		for i = 1, #visible do
			Push(visible[i])
		end
	end
	if mods ~= nil then
		for i = 1, #mods do
			Push(mods[i])
		end
	end
	AWAWMM_SubIdQueue = { items = items, i = 1, total = #items, newly = 0,
		done = (#items == 0) }
	return #items
end
function EnsureExtras(mods)
	local function SetMatches()
		if g_ModExtras == nil then
			return false
		end
		local have = {}
		local n = 0
		for _, e in pairs(g_ModExtras) do
			if e.Id ~= nil then
				have[e.Id] = true
				n = n + 1
			end
		end
		if n ~= #mods then
			return false
		end
		for i = 1, #mods do
			if mods[i].Id == nil or have[mods[i].Id] ~= true then
				return false
			end
		end
		return true
	end
	if g_ModExtras ~= nil and not g_ExtrasDirty and SetMatches() then
		return
	end
	local bFull = (g_ModExtras == nil) or g_ExtrasDirty
	local prev  = g_ModExtras
	local unknownAuthor = Locale.Lookup("LOC_AWAWMM_GROUPBY_AUTHOR_UNKNOWN")
	local function BuildExtra(handle, mod)
		local extra = {
			Id             = nil,
			Official       = false,
			SubscriptionId = nil,
			SubIdKnown     = false,
			Authors        = nil,
			Updated        = nil,
			SupportsMP     = true,
			RequiresXP1    = false,
			RequiresXP2    = false,
			ShowInBrowser  = nil,
			DisplayName                    = nil,
			StrippedDisplayName            = nil,
			GroupKey                       = nil,
		}
		extra.Id = mod.Id
		extra.Official = (mod.Official == true)
		local subKey = nil
		if mod.Id ~= nil then
			subKey = string.lower(tostring(mod.Id))
		end
		extra.SubscriptionId = AWAWMM_GetSubscriptionId(handle, mod.Id, false)
		extra.SubIdKnown = (subKey ~= nil and AWAWMM_SubIds ~= nil
			and AWAWMM_SubIds[subKey] ~= nil)
		local authors = Modding.GetModProperty(handle, "Authors")
		if authors ~= nil and authors ~= "" then
			extra.Authors = ResolveModText(handle, authors)
		end
		local supportsMP = Modding.GetModProperty(handle, "SupportsMultiplayer")
		if supportsMP ~= nil then
			extra.SupportsMP = (tonumber(supportsMP) ~= 0)
		end
		local dependencies = Modding.GetModAssociations(handle)
		if dependencies ~= nil then
			for j = 1, #dependencies do
				local dep = dependencies[j]
				if dep ~= nil and dep.Id ~= nil then
					local depId = dep.Id
					local low = string.lower(tostring(depId))
					if low == DLC_XP1_ID_LOWER then
						extra.RequiresXP1 = true
					elseif low == DLC_XP2_ID_LOWER then
						extra.RequiresXP2 = true
					end
				end
			end
		end
		if extra.SubscriptionId ~= nil and g_SortMode == "UPDATED" then
			local details = Modding.GetSubscriptionDetails(extra.SubscriptionId)
			if details ~= nil then
				extra.Updated = details.LastUpdated
			end
			extra.UpdatedFetched = true
		end
		extra.ShowInBrowser = Modding.GetModProperty(handle, "ShowInBrowser")
		local display = Locale.Lookup(mod.Name)
		extra.DisplayName = display
		extra.StrippedDisplayName = Locale.StripTags(display)
		local aKey, aLabel, aMore = AWAWMM_AuthorParse(extra.Authors)
		if aKey ~= nil then
			extra.GroupKey    = aKey
			extra.GroupLabel  = aLabel
			extra.AuthorLabel = aLabel
			extra.AuthorMulti = aMore
		else
			extra.GroupKey    = AWAWMM_AUTHOR_UNKNOWN_KEY
			extra.GroupLabel  = unknownAuthor
			extra.AuthorLabel = nil
			extra.AuthorMulti = false
		end
		return extra
	end
	local fresh = {}
	local built = 0
	local reused = 0
	for i = 1, #mods do
		local handle = mods[i].Handle
		local old = nil
		if not bFull and prev ~= nil then
			old = prev[handle]
		end
		if old ~= nil then
			fresh[handle] = old
			reused = reused + 1
		else
			fresh[handle] = BuildExtra(handle, mods[i])
			built = built + 1
		end
	end
	local officialIds = {}
	for _, e in pairs(fresh) do
		if e.Official == true and e.Id ~= nil then
			officialIds[string.lower(tostring(e.Id))] = true
		end
	end
	g_OfficialIds = officialIds
	g_ModExtras = fresh
	g_ExtrasDirty = false
	AWAWMM_DependentsIndex = nil
	AWAWMM_InstalledById = nil
end
AWAWMM_ApplyHydratedState = function(st)
	g_Favorites     = st.Favorites
	g_Aliases       = st.Aliases
	g_Filters       = st.Filters
	g_SortMode      = st.SortMode
	g_SortAsc       = st.SortAsc
	g_GroupByAuthor = st.GroupByAuthor
	g_Groups        = st.Groups
	g_GroupMembers  = st.GroupMembers
	return st
end
AWAWMM_HydrateStateFromArchive = function(st, src)
	if st == nil then
		st = AWAWMM.HydrateStateFromArchive()
	end
	st = AWAWMM_ApplyHydratedState(st)
	if AWAWMM_IsModsListReady() then
		AWAWMM.ReconcileGroups(g_Groups, g_GroupMembers)
	else
	end
	return st
end
AWAWMM_TryReadMirrorOnStartup = function(where)
	where = tostring(where or "unspecified")
	local st = AWAWMM.ReadMirrorForFrontend()
	if st == nil then
		return false
	end
	AWAWMM_HydrateStateFromArchive(st, "mirror read")
	AWAWMM_ClearUnavailableState()
	return true
end
AWAWMM_IsUnavailable = function()
	return (AWAWMM.IsFrontendUnavailable() == true)
end
AWAWMM_PulldownButton = function(ctrl)
	if ctrl == nil or type(ctrl.GetButton) ~= "function" then
		return ctrl
	end
	return ctrl:GetButton()
end
AWAWMM_ApplyUnavailableDisable = function(ctrl)
	if ctrl == nil or not AWAWMM_IsUnavailable() then
		return false
	end
	AWAWMM_SetDisabledWithReason(ctrl, true, "LOC_AWAWMM_TIP_INGAME_STALE_DATA", nil)
	return true
end
AWAWMM_SyncUnavailableDisable = function(ctrl, normalKey)
	if ctrl == nil then
		return false
	end
	if AWAWMM_IsUnavailable() then
		AWAWMM_UnavailableDisabled[ctrl] = true
		AWAWMM_UnavailableNormalKey[ctrl] = normalKey
		AWAWMM_SetDisabledWithReason(ctrl, true, "LOC_AWAWMM_TIP_INGAME_STALE_DATA", nil)
		return true
	end
	if AWAWMM_UnavailableDisabled[ctrl] ~= true then
		return false
	end
	AWAWMM_UnavailableDisabled[ctrl] = nil
	AWAWMM_SetDisabledWithReason(ctrl, false, nil, AWAWMM_UnavailableNormalKey[ctrl])
	AWAWMM_UnavailableNormalKey[ctrl] = nil
	return false
end
AWAWMM_UnavailableDisabled = {}
AWAWMM_UnavailableNormalKey = {}
AWAWMM_ApplyUnavailableToControls = function()
	if not AWAWMM_IsUnavailable() then
		for ctrl in pairs(AWAWMM_UnavailableDisabled) do
			AWAWMM_SyncUnavailableDisable(ctrl, AWAWMM_UnavailableNormalKey[ctrl])
		end
		return false
	end
	AWAWMM_SyncUnavailableDisable(Controls.AWAWMMDetailFavoriteButton, "LOC_AWAWMM_FAVORITE_TOOLTIP")
	AWAWMM_SyncUnavailableDisable(Controls.AWAWMMDetailAliasEditBox, "LOC_AWAWMM_ALIAS_TOOLTIP")
	AWAWMM_ApplyUnavailableDisable(Controls.AWAWMMDetailAliasApplyButton)
	AWAWMM_ApplyUnavailableDisable(Controls.AWAWMMDetailAliasClearButton)
	AWAWMM_SyncUnavailableDisable(AWAWMM_PulldownButton(Controls.AWAWMMDetailGroupPullDown), nil)
	AWAWMM_ApplyUnavailableDisable(Controls.AWAWMMGroupRenameButton)
	AWAWMM_ApplyUnavailableDisable(Controls.AWAWMMGroupDeleteButton)
	return true
end
AWAWMM_SetUnavailableState = function(reason)
	AWAWMM.SetFrontendUnavailable(true, reason)
	AWAWMM_ApplyUnavailableToControls()
end
AWAWMM_ClearUnavailableState = function()
	if AWAWMM.IsFrontendUnavailable() ~= true then
		return
	end
	AWAWMM.SetFrontendUnavailable(false, "cleared")
	AWAWMM_ApplyUnavailableToControls()
end
AWAWMM_ApplyFirstUseDefaults = function()
	if AWAWMM.FrontendHasArchive ~= false then
		return false
	end
	if AWAWMM.FrontendMirrorRead == true then
		return false
	end
	if AWAWMM.FindMirrorGroup() ~= nil then
		return false
	end
	AWAWMM_HydrateStateFromArchive(nil, "first-use")
	if g_ShownThisCycle == true then
		RefreshFilterChips()
		UpdateSortOrderButton()
		Controls.AWAWMMGroupByAuthorToggle:SetCheck(g_GroupByAuthor)
		RefreshCustomGroupFilterPullDown()
		RefreshListings()
	end
	return true
end
AWAWMM_ApplyUnavailableForNoMirror = function(where)
	where = tostring(where or "unspecified")
	if AWAWMM.FrontendHasArchive == false then
		AWAWMM_ClearUnavailableState()
		AWAWMM_ApplyFirstUseDefaults()
		AWAWMM.LogFirstUseOnce(where)
		return false
	end
	AWAWMM_SetUnavailableState(where)
	if AWAWMM.FrontendHasArchive == nil then
		AWAWMM.QueryFrontendArchiveExistence()
	end
	return true
end
AWAWMM.FrontendOnArchiveKnown = function(hasArchive)
	if hasArchive == true then
		return
	end
	AWAWMM_ClearUnavailableState()
	AWAWMM_ApplyFirstUseDefaults()
	AWAWMM.LogFirstUseOnce("archive-query-reply")
end
function LoadAllState()
	AWAWMM_ApplyHydratedState(AWAWMM.HydrateStateFromArchive())
	if AWAWMM_IsModsListReady() then
		AWAWMM.ReconcileGroups(g_Groups, g_GroupMembers)
	else
	end
end
function MergeStateFromArchive()
	local fav = AWAWMM.LoadFavorites()
	if AWAWMM.CountSet(fav) > 0 or AWAWMM.CountSet(g_Favorites) == 0 then
		g_Favorites = fav
	end
	local ali = AWAWMM.LoadAliases()
	if AWAWMM.CountMap(ali) > 0 or AWAWMM.CountMap(g_Aliases) == 0 then
		g_Aliases = ali
	end
	local grp = AWAWMM.LoadGroups()
	if AWAWMM.CountSet(grp) > 0 or AWAWMM.CountSet(g_Groups) == 0 then
		g_Groups = grp
	end
	local mem = AWAWMM.LoadGroupMembers()
	if AWAWMM.CountMap(mem) > 0 or AWAWMM.CountMap(g_GroupMembers) == 0 then
		g_GroupMembers = mem
	end
	local flt = AWAWMM.LoadFilters()
	if AWAWMM.CountSet(flt) > 0 or AWAWMM.CountSet(g_Filters) == 0 then
		g_Filters = flt
	end
	if g_SortMode == AWAWMM.SortModes[1] then
		g_SortMode = AWAWMM.LoadSortMode()
	end
	if g_SortAsc == true then
		g_SortAsc = AWAWMM.LoadSortAsc()
	end
	if g_GroupByAuthor == false then
		g_GroupByAuthor = AWAWMM.LoadGroupByAuthor()
	end
	if AWAWMM_IsModsListReady() then
		AWAWMM.ReconcileGroups(g_Groups, g_GroupMembers)
	else
	end
end
function PreprocessListings(mods)
	for i = 1, #mods do
		local v = mods[i]
		local extra = g_ModExtras[v.Handle]
		if extra ~= nil then
			v.Id                           = extra.Id
			v.DisplayName                  = extra.DisplayName
			v.StrippedDisplayName          = extra.StrippedDisplayName
			v.AuthorText                   = extra.Authors
			v.AuthorLabel                  = extra.AuthorLabel
			v.AuthorMulti                  = (extra.AuthorMulti == true)
			v.GroupKey                     = extra.GroupKey
			v.GroupLabel                   = extra.GroupLabel
			v.SubscriptionId               = extra.SubscriptionId
			v.SubIdKnown                   = (extra.SubIdKnown == true)
			v.Updated                      = extra.Updated
			v.SupportsMP                   = (extra.SupportsMP == true)
			v.RequiresXP1                  = (extra.RequiresXP1 == true)
			v.RequiresXP2                  = (extra.RequiresXP2 == true)
			v.ShowInBrowser                = extra.ShowInBrowser
		else
			v.Id                           = nil
			v.DisplayName                  = Locale.Lookup(v.Name)
			v.StrippedDisplayName          = Locale.StripTags(v.DisplayName)
			v.AuthorText                   = nil
			v.AuthorLabel                  = nil
			v.AuthorMulti                  = false
			v.GroupKey                     = AWAWMM_AUTHOR_UNKNOWN_KEY
			v.GroupLabel                   = Locale.Lookup("LOC_AWAWMM_GROUPBY_AUTHOR_UNKNOWN")
			v.SubIdKnown                   = false
			v.SupportsMP                   = true
			v.RequiresXP1                  = false
			v.RequiresXP2                  = false
		end
		if v.Id ~= nil and g_Aliases ~= nil then
			v.Alias = g_Aliases[v.Id]
		else
			v.Alias = nil
		end
		v.IsFavorite = (v.Id ~= nil and AWAWMM.Has(g_Favorites, v.Id))
		local _aliasText = (v.Alias ~= nil) and tostring(v.Alias) or ""
		if #_aliasText > 0 then
			v.SortName = _aliasText .. " " .. v.StrippedDisplayName
		else
			v.SortName = v.StrippedDisplayName
		end
		v.OverrideRank = OVERRIDE_NORMAL
	end
end
function RulesetAllows(v, ruleset)
	if ruleset == AWAWMM.FilterKeys.RulesetXP2 then
		return ((not v.RequiresXP1) or v.RequiresXP2)
	elseif ruleset == AWAWMM.FilterKeys.RulesetXP1 then
		return (not v.RequiresXP2)
	end
	return (not v.RequiresXP1 and not v.RequiresXP2)
end
function PassesFilters(v)
	if v.ShowInBrowser == "AlwaysHidden" then
		return false
	end
	if UI.IsFinalRelease() and v.Allowance == false then
		return false
	end
	if g_GroupFilter ~= nil
		and not AWAWMM.IsModInGroup(g_GroupMembers, v.Id, g_GroupFilter) then
		return false
	end
	if AWAWMM.Has(g_Filters, AWAWMM.FilterKeys.ShowAll) then
		return not v.Official
	end
	if AWAWMM.Has(g_Filters, AWAWMM.FilterKeys.Favorite) then
		return v.IsFavorite
	end
	if AWAWMM.Has(g_Filters, AWAWMM.FilterKeys.OnlyEnabled) then
		return v.Enabled and (not v.Official)
	end
	if not AWAWMM.AnyChecked(g_Filters, AWAWMM.FilterGroups.Source) then
		return false
	end
	local sourceKey = AWAWMM.FilterKeys.Local
	if v.Official then
		sourceKey = AWAWMM.FilterKeys.Official
	elseif v.SubIdKnown == true then
		if v.SubscriptionId ~= nil then
			sourceKey = AWAWMM.FilterKeys.Workshop
		end
	elseif v.Source ~= "Local" then
		sourceKey = AWAWMM.FilterKeys.Workshop
	end
	if not AWAWMM.Has(g_Filters, sourceKey) then
		return false
	end
	if AWAWMM.Has(g_Filters, AWAWMM.FilterKeys.SupportsMP) and not v.SupportsMP then
		return false
	end
	if not RulesetAllows(v, AWAWMM.GetRuleset(g_Filters)) then
		return false
	end
	return true
end
function FindIn(haystack, needleLower)
	if haystack == nil or haystack == "" then
		return nil
	end
	return string.find(AWAWMM_Data.FoldCase(haystack), needleLower, 1, true)
end
function HighlightMatch(haystack, needleLower)
	if haystack == nil or haystack == "" or needleLower == nil or #needleLower == 0 then
		return haystack
	end
	local lower = AWAWMM_Data.FoldCase(haystack)
	local from = 1
	local scanned = 1
	local depth = 0
	while true do
		local s, e = string.find(lower, needleLower, from, true)
		if s == nil then
			return haystack
		end
		while scanned < s do
			local ch = string.sub(haystack, scanned, scanned)
			if ch == "[" then
				depth = depth + 1
			elseif ch == "]" then
				if depth > 0 then depth = depth - 1 end
			end
			scanned = scanned + 1
		end
		if depth == 0 then
			local inner = 0
			local j = s
			while j <= e and inner == 0 do
				local ch = string.sub(haystack, j, j)
				if ch == "[" then
					inner = inner + 1
				elseif ch == "]" then
					inner = inner - 1
				end
				j = j + 1
			end
			if inner == 0 then
				return string.sub(haystack, 1, s - 1)
					.. "[COLOR_LIGHTBLUE]" .. string.sub(haystack, s, e) .. "[ENDCOLOR]"
					.. string.sub(haystack, e + 1)
			end
		end
		from = s + 1
	end
end
function PassesSearch(v)
	if g_SearchQuery == nil or #g_SearchQuery == 0 then
		return true
	end
	local needle = AWAWMM_Data.FoldCase(g_SearchQuery)
	if FindIn(v.StrippedDisplayName, needle) ~= nil then return true end
	if v.Alias ~= nil and FindIn(v.Alias, needle) ~= nil then return true end
	local author = v.AuthorText
	if author ~= nil then
		author = Locale.StripTags(author)
	end
	if FindIn(author, needle) ~= nil then return true end
	local authorNeedle = AWAWMM_Data.FoldCase(tostring(AWAWMM_AuthorCanonicalize(g_SearchQuery, false) or ""))
	if #authorNeedle > 0 and FindIn(author, authorNeedle) ~= nil then return true end
	if FindIn(AWAWMM_AuthorCanonicalize(author, false), needle) ~= nil then return true end
	if FindIn(AWAWMM_AuthorCanonicalize(author, true), needle) ~= nil then return true end
	if v.SubscriptionId ~= nil and FindIn(tostring(v.SubscriptionId), needle) ~= nil then
		return true
	end
	if v.SubIdKnown ~= true and AWAWMM_IsAllDigits(g_SearchQuery) then
		return true
	end
	return false
end
function CompareOptional(x, y)
	if x == nil and y == nil then return 0 end
	if x == nil then return 1 end
	if y == nil then return -1 end
	local nx, ny = tonumber(x), tonumber(y)
	if nx ~= nil and ny ~= nil then
		if nx == ny then return 0 end
		if nx < ny then return -1 end
		return 1
	end
	return Locale.Compare(tostring(x), tostring(y))
end
function MissingSortKey(v)
	if g_SortMode == "AUTHOR" then return v.AuthorText == nil end
	if g_SortMode == "UPDATED" then return v.Updated == nil end
	if g_SortMode == "SUBSCRIPTION" then return v.SubscriptionId == nil end
	return false
end
function CompareByMode(a, b)
	if g_SortMode == "NAME" then
		return Locale.Compare(a.SortName or a.StrippedDisplayName, b.SortName or b.StrippedDisplayName)
	elseif g_SortMode == "AUTHOR" then
		if a.GroupKey == nil or b.GroupKey == nil then
			return CompareOptional(a.AuthorText, b.AuthorText)
		end
		return Locale.Compare(a.GroupKey, b.GroupKey)
	elseif g_SortMode == "UPDATED" then
		return CompareOptional(a.Updated, b.Updated)
	elseif g_SortMode == "SUBSCRIPTION" then
		return CompareOptional(a.SubscriptionId, b.SubscriptionId)
	elseif g_SortMode == "ENABLED" then
		if a.Enabled ~= b.Enabled then
			if a.Enabled then return -1 end
			return 1
		end
	end
	return Locale.Compare(a.SortName or a.StrippedDisplayName, b.SortName or b.StrippedDisplayName)
end
function OverrideRank(id)
	if id ~= nil and AWAWMM.Has(g_Favorites, id) then
		return OVERRIDE_FAVORITE
	end
	return OVERRIDE_NORMAL
end
function SortListings(mods)
	table.sort(mods, function(a, b)
		if a.OverrideRank ~= b.OverrideRank then
			return a.OverrideRank < b.OverrideRank
		end
		if g_GroupByAuthor and a.OverrideRank == OVERRIDE_NORMAL then
			local ca = Locale.Compare(a.GroupKey, b.GroupKey)
			if ca ~= 0 then
				return ca < 0
			end
		end
		local an, bn = MissingSortKey(a), MissingSortKey(b)
		if an ~= bn then
			return bn
		end
		local c = CompareByMode(a, b)
		if not g_SortAsc then
			c = -c
		end
		if c == 0 and g_SortMode ~= "NAME" then
			local aa = a.Alias
			local bb = b.Alias
			if aa == nil then aa = "" end
			if bb == nil then bb = "" end
			if aa ~= "" or bb ~= "" then
				c = Locale.Compare(tostring(aa), tostring(bb))
			end
		end
		if c == 0 then
			return Locale.Compare(a.SortName or "", b.SortName or "") < 0
		end
		return c < 0
	end)
end
function ToggleFavorite(handle)
	local id = GetModId(handle)
	if id == nil then
		return
	end
	local now = AWAWMM.ToggleFavorite(g_Favorites, id)
	RefreshListings()
end
function LayoutDetails()
	Controls.ModDetailsStack:CalculateSize()
	Controls.ModDetailsStack:ReprocessAnchoring()
	Controls.ModDetailsScrollPanel:CalculateInternalSize()
end
function BuildRefList(xtra, suffix)
	local lines = {}
	local seen = {}
	local tail = suffix or ""
	if xtra ~= nil then
		for i = 1, #xtra do
			local ref = xtra[i]
			if ref ~= nil then
				local key = ref.Id
				if key == nil then
					key = tostring(i) .. "/" .. tostring(ref.Name)
				end
				if seen[key] == nil then
					seen[key] = true
					lines[#lines + 1] = "[ICON_BULLET] "
						.. tostring(ResolveLocName(ref.Name)) .. tail
				end
			end
		end
	end
	return lines
end
function CloseConfirmPopup()
	Controls.AWAWMMConfirmPopup:SetHide(true)
end
function OpenConfirmPopup(title, message, depNames, okLabel, onOK, bHideCancel)
	Controls.AWAWMMConfirmTitle:SetText(title)
	Controls.AWAWMMConfirmMessage:SetText(message)
	g_ConfirmDependencyManager:ResetInstances()
	local nDeps = 0
	if depNames ~= nil then
		for i = 1, #depNames do
			local inst = g_ConfirmDependencyManager:GetInstance()
			inst.Item:SetText("[ICON_BULLET] " .. tostring(depNames[i]))
			nDeps = nDeps + 1
		end
	end
	Controls.AWAWMMConfirmDepScroll:SetSizeY(104)
	Controls.AWAWMMConfirmDepScroll:SetHide(nDeps == 0)
	Controls.AWAWMMConfirmDepStack:CalculateSize()
	Controls.AWAWMMConfirmDepStack:ReprocessAnchoring()
	Controls.AWAWMMConfirmDepScroll:CalculateInternalSize()
	Controls.AWAWMMConfirmOK:SetText(okLabel)
	ClearClick(Controls.AWAWMMConfirmOK, Mouse.eLClick)
	Controls.AWAWMMConfirmOK:RegisterCallback(Mouse.eLClick, function()
		CloseConfirmPopup()
		onOK()
	end)
	Controls.AWAWMMConfirmCancel:SetHide(bHideCancel == true)
	ClearClick(Controls.AWAWMMConfirmCancel, Mouse.eLClick)
	Controls.AWAWMMConfirmCancel:RegisterCallback(Mouse.eLClick, function()
		CloseConfirmPopup()
	end)
	Controls.AWAWMMConfirmPopup:SetHide(false)
	Controls.AWAWMMConfirmAlpha:SetToBeginning()
	Controls.AWAWMMConfirmAlpha:Play()
	Controls.AWAWMMConfirmSlide:SetToBeginning()
	Controls.AWAWMMConfirmSlide:Play()
end
AWAWMM_SelfYesOk = function(s)
	if s == nil then
		return false
	end
	local t = string.match(tostring(s), "^%s*(.-)%s*$")
	return (t ~= nil and string.lower(t) == "yes")
end
AWAWMM_SyncSelfPopupOK = function()
	local ok = AWAWMM_SelfYesOk(Controls.AWAWMMSelfYesInput:GetText())
	Controls.AWAWMMSelfOK:SetDisabled(not ok)
end
AWAWMM_SelfPopupAccept = nil
function AWAWMM_CloseSelfPopup()
	Controls.AWAWMMSelfPopup:SetHide(true)
end
function AWAWMM_SelfPopupConfirm()
	if not AWAWMM_SelfYesOk(Controls.AWAWMMSelfYesInput:GetText()) then
		return
	end
	if AWAWMM_SelfPopupAccept == nil then
		return
	end
	local fn = AWAWMM_SelfPopupAccept
	AWAWMM_SelfPopupAccept = nil
	AWAWMM_CloseSelfPopup()
	fn()
end
function AWAWMM_OpenSelfPopup(title, message, notice, onOK)
	Controls.AWAWMMSelfTitle:SetText(title)
	Controls.AWAWMMSelfMessage:SetText(message)
	Controls.AWAWMMSelfNotice:SetText(notice)
	Controls.AWAWMMSelfYesHint:SetText(Locale.Lookup("LOC_AWAWMM_CONFIRM_YES_HINT"))
	Controls.AWAWMMSelfYesInput:SetText("")
	AWAWMM_SelfPopupAccept = onOK
	AWAWMM_SyncSelfPopupOK()
	Controls.AWAWMMSelfPopup:SetHide(false)
	Controls.AWAWMMSelfAlpha:SetToBeginning()
	Controls.AWAWMMSelfAlpha:Play()
	Controls.AWAWMMSelfSlide:SetToBeginning()
	Controls.AWAWMMSelfSlide:Play()
	Controls.AWAWMMSelfYesInput:TakeFocus()
end
AWAWMM_EnabledSetDirty = false
function CommitEnabledModsToEngine()
	AWAWMM_EnabledSetDirty = true
end
AWAWMM_FlushEnabledSetToEngine = function()
	local enDirty = AWAWMM_EnabledSetDirty
	local dataDirty = (AWAWMM_Data ~= nil) and (AWAWMM_Data.DataDirty == true)
	if not enDirty and not dataDirty then
		return false
	end
	AWAWMM_EnabledSetDirty = false
	if AWAWMM_Data ~= nil then
		AWAWMM_Data.DataDirty = false
	end
	local synced = nil
	if enDirty then
		synced = AWAWMM.SyncEnabledModsToEngine()
	end
	local n = AWAWMM.EngineEnabledModsCount()
	AWAWMM.FlushKnownValues()
	AWAWMM.SaveConfigArchive(true)
	return true
end
AWAWMM_MissingDepNames = function(handle, xtra)
	local out = {}
	local seen = {}
	local noValue = tostring(Locale.Lookup("LOC_AWAWMM_NO_VALUE"))
	if xtra ~= nil then
		for i = 1, #xtra do
			local dep = xtra[i]
			if dep ~= nil and dep.Id ~= nil and dep.Id ~= "" then
				local key = tostring(dep.Id)
				if seen[key] == nil then
					seen[key] = true
					local nm = ResolveAssociationName(handle, dep)
					local s = (nm ~= nil) and tostring(nm) or ""
					if s == "" or s == noValue then
						s = key
					end
					out[#out + 1] = s
				end
			end
		end
	end
	return out
end
local ROW_ENABLED_PX = 58
AWAWMM_StateTextFor = function(v)
	if v == nil then
		return ""
	end
	if AWAWMM_IsUnsubscribedForDisplay(v.Id) then
		return "[COLOR_RED]" .. Locale.Lookup("LOC_AWAWMM_ROW_UNSUBSCRIBED") .. "[ENDCOLOR]"
	end
	if v.Enabled == true then
		return Locale.Lookup("LOC_MODS_ENABLED")
	end
	return "[COLOR:GrayMedium]" .. Locale.Lookup("LOC_MODS_DISABLED") .. "[ENDCOLOR]"
end
AWAWMM_EnabledFromCache = function(handle)
	if AWAWMM_ModsCache == nil or AWAWMM_ModsCacheDirty == true then
		return nil
	end
	local live = AWAWMM_ModsCache
	for i = 1, #live do
		if live[i] ~= nil and live[i].Handle == handle then
			return (live[i].Enabled == true)
		end
	end
	return nil
end
AWAWMM_SetDisabledWithReason = function(ctrl, disabled, reasonKey, normalKey)
	if ctrl == nil then
		return
	end
	local off = (disabled == true)
	ctrl:SetDisabled(off)
	if off then
		ctrl:SetToolTipString(Locale.Lookup(reasonKey))
	elseif normalKey ~= nil then
		ctrl:SetToolTipString(Locale.Lookup(normalKey))
	else
		ctrl:SetToolTipString(nil)
	end
end
AWAWMM_SelfDisableGuardActive = false
AWAWMM_SyncDetailUnsubscribeButton = function(modId)
	AWAWMM_SetDisabledWithReason(Controls.AWAWMMDetailUnsubscribeButton,
		AWAWMM_IsUnsubscribedForDisplay(modId) == true, "LOC_AWAWMM_TIP_UNSUBSCRIBED", nil)
end
AWAWMM_ApplyRowState = function(handle)
	local inst = AWAWMM_RenderedByHandle[handle]
	if inst == nil then
		return
	end
	local e = (g_ModExtras ~= nil) and g_ModExtras[handle] or nil
	local localIcon = false
	if e ~= nil then
		localIcon = ((e.Official ~= true) and e.SubIdKnown == true and e.SubscriptionId == nil)
	end
	inst.ModSourceBadgeIcon:SetHide(not localIcon)
	if handle == g_SelectedModHandle then
		AWAWMM_SyncDetailUnsubscribeButton((e ~= nil) and e.Id or nil)
	end
	local en = AWAWMM_EnabledFromCache(handle)
	if en == nil then
		return
	end
	local text = AWAWMM_StateTextFor({ Id = (e ~= nil) and e.Id or nil, Enabled = en })
	if tostring(inst.ModEnabled:GetText() or "") ~= tostring(text) then
		TruncateString(inst.ModEnabled, ROW_ENABLED_PX, text)
	end
end
AWAWMM_ApplyRenderedRowStates = function()
	for handle, _ in pairs(AWAWMM_RenderedByHandle) do
		AWAWMM_ApplyRowState(handle)
	end
end
function DoEnableMod(modHandle, bForceUnsubscribed)
	local err, xtra = Modding.CanEnableMod(modHandle, true)
	if err == "OK" then
		local canEnable, why, source = true, nil, nil
		if bForceUnsubscribed ~= true then
			canEnable, why, source = AWAWMM_CanEnableGivenUnsubscribed(modHandle, err)
		end
		if not canEnable then
			SelectMod(modHandle)
			if why == "self" then
				OpenConfirmPopup(
					Locale.Lookup("LOC_AWAWMM_TITLE_NOT_SUBSCRIBED"),
					Locale.Lookup("LOC_AWAWMM_ENABLE_NEEDS_SUBSCRIPTION"),
					nil, Locale.Lookup("LOC_AWAWMM_ENABLE_ANYWAY"),
					function() DoEnableMod(modHandle, true) end)
				Log("enable", "refused: not subscribed (self) source=" .. tostring(source)
					.. " handle=" .. tostring(modHandle))
				AWAWMM_ApplyRenderedRowStates()
				return
			end
			local hidden = AWAWMM_MissingDepNames(modHandle, why)
			if #hidden > 0 then
				OpenConfirmPopup(
					Locale.Lookup("LOC_AWAWMM_TITLE_NOT_SUBSCRIBED"),
					Locale.Lookup("LOC_MODS_ERROR_MOD_MISSING_DEPENDENCIES")
						.. "[NEWLINE]"
						.. Locale.Lookup("LOC_AWAWMM_ENABLE_NEEDS_DEP_SUBSCRIPTION"),
					hidden, Locale.Lookup("LOC_AWAWMM_ENABLE_ANYWAY"),
					function() DoEnableMod(modHandle, true) end)
			else
			end
			AWAWMM_ApplyRenderedRowStates()
			return
		end
		Modding.EnableMod(modHandle, true)
		CommitEnabledModsToEngine()
		AWAWMM_InvalidateModsCache()
		RefreshListings()
		return
	end
	if err == "MissingDependencies" then
		SelectMod(modHandle)
		local missing = AWAWMM_MissingDepNames(modHandle, xtra)
		if #missing > 0 then
			OpenConfirmPopup(
				Locale.Lookup("LOC_AWAWMM_TITLE_ENABLE_FAILED"),
				Locale.Lookup("LOC_MODS_ERROR_MOD_MISSING_DEPENDENCIES"),
				missing, Locale.Lookup("LOC_OK"), function() end, true)
		else
		end
		AWAWMM_ApplyRenderedRowStates()
		return
	end
	AWAWMM_ApplyRenderedRowStates()
end
function EnableWithCompatCheck(modHandle)
	local needWarn = Modding.ShouldShowCompatibilityWarnings()
		and (not Modding.IsModCompatible(modHandle))
	if not needWarn then
		DoEnableMod(modHandle)
		return
	end
	OpenConfirmPopup(
		Locale.Lookup("LOC_AWAWMM_TITLE_INCOMPATIBLE"),
		Locale.Lookup("LOC_MODS_ENABLE_WARNING_NOT_COMPATIBLE"),
		nil,
		Locale.Lookup("LOC_OK"),
		function() DoEnableMod(modHandle) end)
end
function BuildCascadeOrder(rootHandle)
	local order = {}
	local seen = {}
	local seenId = {}
	local failedName = nil
	local function Visit(handle, name)
		local key = tostring(handle)
		if seen[key] ~= nil then
			return true
		end
		seen[key] = true
		local id = GetModId(handle)
		if id ~= nil then
			local idKey = string.lower(tostring(id))
			if seenId[idKey] ~= nil then
				return true
			end
			seenId[idKey] = true
		end
		local err, _, sources = Modding.CanDisableMod(handle)
		if err == "OwnershipRequired" then
			failedName = name
			return false
		end
		if err == "MissingDependencies" and sources ~= nil then
			for i = 1, #sources do
				local s = sources[i]
				if s ~= nil then
					local childName = ResolveLocName(s.Name)
					local childHandle = nil
					if s.Id ~= nil then
						childHandle = Modding.GetModHandle(s.Id)
					end
					if childHandle == nil then
						failedName = childName
						return false
					end
					if not Visit(childHandle, childName) then
						return false
					end
				end
			end
		end
		order[#order + 1] = handle
		return true
	end
	if not Visit(rootHandle, nil) then
		return nil, failedName
	end
	return order, nil
end
function DoCascadeDisable(rootHandle)
	local order, failedName = BuildCascadeOrder(rootHandle)
	if order == nil then
		OpenConfirmPopup(
			Locale.Lookup("LOC_AWAWMM_CONFIRM_TITLE_DISABLE_CASCADE"),
			Locale.Lookup("LOC_AWAWMM_DISABLE_CASCADE_FAILED") .. tostring(failedName or "?"),
			nil, Locale.Lookup("LOC_OK"), function() end)
		return
	end
	Modding.DisableMod(order)
	CommitEnabledModsToEngine()
	AWAWMM_InvalidateModsCache()
	RefreshListings()
end
function IsSelfMod(modHandle)
	local id = GetModId(modHandle)
	if id == nil then
		local info = Modding.GetModInfo(modHandle)
		id = (info ~= nil) and info.Id or nil
	end
	return (id ~= nil and string.lower(tostring(id)) == AWAWMM_SELF_ID_LOWER)
end
function DoDisableMod(modHandle, bSelfConfirmed)
	if AWAWMM_SelfDisableGuardActive == true and IsSelfMod(modHandle) then
		Log("disable", "refused: self mod (T-0092) handle=" .. tostring(modHandle))
		AWAWMM_ApplyRenderedRowStates()
		return
	end
	if IsSelfMod(modHandle) and bSelfConfirmed ~= true then
		AWAWMM_OpenSelfPopup(
			Locale.Lookup("LOC_AWAWMM_CONFIRM_TITLE"),
			Locale.Lookup("LOC_AWAWMM_CONFIRM_DISABLE_SELF"),
			Locale.Lookup("LOC_AWAWMM_TIP_SELF_FRONTEND_DISABLE"),
			function() DoDisableMod(modHandle, true) end)
		return
	end
	AWAWMM_RefreshSubsIndex()
	local err, _, sources = Modding.CanDisableMod(modHandle)
	if err == "OK" then
		Modding.DisableMod(modHandle)
		CommitEnabledModsToEngine()
		AWAWMM_InvalidateModsCache()
		RefreshListings()
		return
	end
	if err == "MissingDependencies" then
		local enabledById = nil
		local enabledKnown = false
		local function IsEnabledId(id)
			if id == nil or id == "" then
				return true
			end
			if enabledById == nil then
				enabledById = {}
				local live = AWAWMM_GetInstalledModsCached(true)
				if live ~= nil and #live > 0 then
					enabledKnown = true
					for j = 1, #live do
						local v = live[j]
						if v ~= nil and v.Id ~= nil and v.Enabled == true then
							enabledById[string.lower(tostring(v.Id))] = true
						end
					end
				end
			end
			if not enabledKnown then
				return true
			end
			return (enabledById[string.lower(tostring(id))] == true)
		end
		local names = {}
		local seenName = {}
		if sources ~= nil then
			for i = 1, #sources do
				local s = sources[i]
				if s ~= nil and not AWAWMM_IsUnsubscribed(s.Id) and IsEnabledId(s.Id) then
					local dedupKey = (s.Id ~= nil and s.Id ~= "")
						and string.lower(tostring(s.Id)) or nil
					local nm = ResolveLocName(s.Name)
					if dedupKey == nil then
						dedupKey = "n:" .. tostring(nm)
					end
					if seenName[dedupKey] == nil then
						seenName[dedupKey] = true
						names[#names + 1] = nm
					end
				end
			end
		end
		local body = Locale.Lookup("LOC_AWAWMM_CONFIRM_DISABLE_CASCADE")
			.. "[NEWLINE]" .. Locale.Lookup("LOC_AWAWMM_DISABLE_DEPS_HIGHLIGHT")
		OpenConfirmPopup(
			Locale.Lookup("LOC_AWAWMM_CONFIRM_TITLE_DISABLE_CASCADE"),
			body,
			names,
			Locale.Lookup("LOC_MODS_DISABLE_ALL"),
			function() DoCascadeDisable(modHandle) end)
		AWAWMM_ApplyRenderedRowStates()
		return
	end
	AWAWMM_ApplyRenderedRowStates()
end
function ToggleModEnabled(modHandle)
	local info = Modding.GetModInfo(modHandle)
	if info == nil then
		return
	end
	if info.Enabled then
		DoDisableMod(modHandle)
	else
		EnableWithCompatCheck(modHandle)
	end
end
function RenderAuthorHeader(key, label, count)
	local inst = g_AuthorHeaderManager:GetInstance()
	local text = tostring(label) .. GroupCountSuffix(count)
	AWAWMM_SetSingleLineMarked(inst.AWAWMMAuthorHeaderLabel, text,
		AUTHOR_ROW_MAX_CHARS, AUTHOR_HEADER_PX)
	inst.AWAWMMAuthorHeaderCountLabel:SetText("")
	key = tostring(key)
	local collapsed = (AWAWMM_AuthorCollapsed ~= nil and AWAWMM_AuthorCollapsed[key] == true)
	inst.AWAWMMAuthorFoldUpIcon:SetHide(collapsed)
	inst.AWAWMMAuthorFoldDownIcon:SetHide(not collapsed)
	ClearClick(inst.AWAWMMAuthorHeaderButton, Mouse.eLClick)
	inst.AWAWMMAuthorHeaderButton:RegisterCallback(Mouse.eLClick, function()
		local set = AWAWMM_AuthorCollapsed
		if set == nil then
			set = {}
			AWAWMM_AuthorCollapsed = set
		end
		set[key] = not (set[key] == true)
		RefreshListings()
	end)
end
local ROW_BADGE_PX   = 30
local ROW_TITLE_PX   = 298
AWAWMM_ApplyRowMetrics = function()
	local badge = Locale.Lookup("LOC_AWAWMM_BADGE_OFFICIAL")
	if badge == nil or #badge == 0 or string.sub(badge, 1, 4) == "LOC_" then
		badge = "官方"
	end
	local tw = AWAWMM_TOOLBAR.Measure(badge)
	if tw < 24 then
		tw = 24
	end
	if tw > 64 then
		tw = 64
	end
	local w = tw + AWAWMM_TOOLBAR.BADGE_PAD
	ROW_BADGE_PX = w
	local titleX = 48 + w + 16
	if titleX < 88 then
		titleX = 88
	end
	AWAWMM_TOOLBAR.ROW_TITLE_X = titleX
	ROW_TITLE_PX = 392 - titleX
end
local ROW_AUTHOR_PX  = 148
function RenderModRow(v)
	local instance = g_ModListingsManager:GetInstance()
	AWAWMM_RenderedByHandle[v.Handle] = instance
	local notOwned = (v.Allowance == false)
	instance.ModFavoriteOn:SetHide(not v.IsFavorite)
	instance.ModFavoriteOff:SetHide(v.IsFavorite)
	ClearClick(instance.ModFavoriteButton, Mouse.eLClick)
	instance.ModFavoriteButton:RegisterCallback(Mouse.eLClick, function()
		ToggleFavorite(v.Handle)
	end)
	AWAWMM_SyncUnavailableDisable(instance.ModFavoriteButton, "LOC_AWAWMM_FAVORITE_TOOLTIP")
	local badge = nil
	local localIcon = false
	if v.Official then
		badge = Locale.Lookup("LOC_AWAWMM_BADGE_OFFICIAL")
	elseif v.SubIdKnown == true and v.SubscriptionId == nil then
		localIcon = true
	end
	instance.ModSourceBadgeIcon:SetHide(not localIcon)
	SetSingleLineText(instance.ModSourceBadge, badge or "", 8, ROW_BADGE_PX)
	instance.ModSourceBadge:SetToolTipString(Locale.Lookup("LOC_AWAWMM_BADGE_OFFICIAL_TOOLTIP"))
	local baseName = TruncateStringByLength(v.DisplayName, 96)
	local title = ComposeDisplayName(baseName, v.Alias)
	if g_SearchQuery ~= nil and #g_SearchQuery > 0 then
		title = HighlightMatch(title, AWAWMM_Data.FoldCase(g_SearchQuery))
	end
	if notOwned then
		title = title .. " [COLOR_RED](" .. Locale.Lookup("LOC_MODS_DETAILS_OWNERSHIP_NO") .. ")[ENDCOLOR]"
	end
	instance.ModTitle:SetOffsetX(AWAWMM_TOOLBAR.ROW_TITLE_X)
	TruncateString(instance.ModTitle, ROW_TITLE_PX, title)
	local rowAuthor = v.AuthorLabel
	if rowAuthor ~= nil and v.AuthorMulti == true then
		rowAuthor = rowAuthor .. " " .. Locale.Lookup("LOC_AWAWMM_AUTHOR_ET_AL")
	end
	AWAWMM_SetSingleLineMarked(instance.ModAuthorLabel,
		RowAuthorText(rowAuthor) or "", AUTHOR_ROW_MAX_CHARS, ROW_AUTHOR_PX)
	local enabledText = AWAWMM_StateTextFor(v)
	TruncateString(instance.ModEnabled, ROW_ENABLED_PX, enabledText)
	instance.ModEnabledSwitch:SetSelected(v.Enabled)
	instance.ModEnabledSwitch:SetDisabled(false)
	local tip = nil
	if v.Teaser ~= nil and #v.Teaser > 0 then
		tip = Locale.Lookup(v.Teaser)
	end
	local hint = Locale.Lookup("LOC_AWAWMM_RIGHTCLICK_TOOLTIP")
	if tip ~= nil and tip ~= "" then
		instance.ModInstanceRoot:SetToolTipString(tip .. "[NEWLINE]" .. hint)
	else
		instance.ModInstanceRoot:SetToolTipString(hint)
	end
	ClearClick(instance.ModInstanceButton, Mouse.eLClick)
	instance.ModInstanceButton:RegisterCallback(Mouse.eLClick, function()
		SelectMod(v.Handle)
	end)
	ClearClick(instance.ModInstanceButton, Mouse.eRClick)
	instance.ModInstanceButton:RegisterCallback(Mouse.eRClick, function()
		ToggleModEnabled(v.Handle)
	end)
	ClearClick(instance.ModEnabledSwitch, Mouse.eLClick)
	instance.ModEnabledSwitch:RegisterCallback(Mouse.eLClick, function()
		ToggleModEnabled(v.Handle)
	end)
	ClearClick(instance.ModEnabledSwitch, Mouse.eRClick)
	instance.ModEnabledSwitch:RegisterCallback(Mouse.eRClick, function()
		ToggleModEnabled(v.Handle)
	end)
	g_ModListings[#g_ModListings + 1] = { Handle = v.Handle, Instance = instance }
end
function RenderListings(visible)
	AWAWMM_RenderedByHandle = {}
	local groupCounts = nil
	if g_GroupByAuthor then
		groupCounts = {}
		for i = 1, #visible do
			local v = visible[i]
			if v.OverrideRank == OVERRIDE_NORMAL then
				groupCounts[v.GroupKey] = (groupCounts[v.GroupKey] or 0) + 1
			end
		end
	end
	local lastGroup = nil
	for i = 1, #visible do
		local v = visible[i]
		if groupCounts ~= nil and v.OverrideRank == OVERRIDE_NORMAL and v.GroupKey ~= lastGroup then
			lastGroup = v.GroupKey
			RenderAuthorHeader(v.GroupKey, v.GroupLabel, groupCounts[v.GroupKey] or 0)
		end
		local folded = (groupCounts ~= nil and v.OverrideRank == OVERRIDE_NORMAL
			and AWAWMM_AuthorCollapsed ~= nil
			and AWAWMM_AuthorCollapsed[tostring(v.GroupKey)] == true)
		if not folded then
			RenderModRow(v)
		end
	end
end
function UpdateBottomSummary(visible, total, enabledTotal)
	local modeLabel = "LOC_MODS_SORTBY_NAME"
	for i = 1, #SORT_OPTIONS do
		if SORT_OPTIONS[i].Mode == g_SortMode then
			modeLabel = SORT_OPTIONS[i].Label
		end
	end
	local ascLabel = g_SortAsc and "LOC_AWAWMM_SORT_ASCENDING" or "LOC_AWAWMM_SORT_DESCENDING"
	local summarySep = Locale.Lookup("LOC_AWAWMM_SORT_SUMMARY_JOIN")
	local curLang = Locale.GetCurrentLanguage()
	local langType = nil
	if curLang ~= nil then
		langType = curLang.Type
	end
	local sepJoin = " " .. summarySep .. " "
	local sepGap = " " .. summarySep .. " "
	if langType == "zh_Hans_CN" or langType == "zh_Hant_HK" or langType == "ja_JP" then
		sepGap = "　"
	end
	if langType == "ja_JP" then
		sepJoin = summarySep
	end
	Controls.AWAWMMBottomSummary:SetText(
		Locale.Lookup(modeLabel)
		.. sepJoin .. Locale.Lookup(ascLabel)
		.. sepGap
		.. Locale.Lookup("LOC_AWAWMM_BOTTOM_SUMMARY", #visible, total, enabledTotal))
end
function RefreshListingsSelectionState()
	if g_ModListings == nil then
		return
	end
	for i = 1, #g_ModListings do
		local entry = g_ModListings[i]
		if entry.Instance ~= nil and entry.Instance.ModInstanceButton ~= nil then
			entry.Instance.ModInstanceButton:SetSelected(entry.Handle == g_SelectedModHandle)
		end
	end
end
RefreshListings = function(bSkipDetails)
	local t0 = Now()
	local mods = AWAWMM_GetInstalledModsCached(bSkipDetails == true)
	g_ModListings = {}
	g_ModListingsManager:ResetInstances()
	g_AuthorHeaderManager:ResetInstances()
	if mods == nil or #mods == 0 then
		Controls.ModListings:SetHide(true)
		Controls.NoModsInstalled:SetText(Locale.Lookup("LOC_MODS_NONE_INSTALLED"))
		Controls.NoModsInstalled:SetHide(false)
		AWAWMM_SetDisabledWithReason(Controls.EnableAll, true, "LOC_AWAWMM_TIP_ENABLE_ALL_NONE",
			"LOC_MODS_ENABLE_ALL_AWAWMM_TT")
		AWAWMM_SetDisabledWithReason(Controls.DisableAll, true, "LOC_AWAWMM_TIP_DISABLE_ALL_NONE",
			"LOC_MODS_DISABLE_ALL_AWAWMM_TT")
		Controls.AWAWMMBottomSummary:SetText(Locale.Lookup("LOC_AWAWMM_BOTTOM_SUMMARY", 0, 0, 0))
		RefreshListingsSelectionState()
		if not bSkipDetails then
			RefreshModDetails()
		end
		return
	end
	EnsureExtras(mods)
	PreprocessListings(mods)
	local visible = {}
	local hasEnabled = false
	local hasOtherEnabled = false
	local hasDisabled = false
	local enabledTotal = 0
	for i = 1, #mods do
		local v = mods[i]
		if v.Enabled then enabledTotal = enabledTotal + 1 end
		if PassesFilters(v) and PassesSearch(v) then
			v.OverrideRank = OverrideRank(v.Id)
			visible[#visible + 1] = v
			if v.Enabled then hasEnabled = true else hasDisabled = true end
			if v.Enabled and not IsSelfMod(v.Handle) then hasOtherEnabled = true end
		end
	end
	SortListings(visible)
	RenderListings(visible)
	local pending = AWAWMM_RebuildSubIdQueue(mods, visible)
	if pending > 0 then
		ArmSubIdFill()
	end
	Controls.ModListings:SetHide(#visible == 0)
	if #visible == 0 then
		Controls.NoModsInstalled:SetText(Locale.Lookup("LOC_AWAWMM_NO_MODS_FILTERED"))
		Controls.NoModsInstalled:SetHide(false)
	else
		Controls.NoModsInstalled:SetHide(true)
	end
	AWAWMM_SetDisabledWithReason(Controls.EnableAll, not hasDisabled, "LOC_AWAWMM_TIP_ENABLE_ALL_NONE",
		"LOC_MODS_ENABLE_ALL_AWAWMM_TT")
	AWAWMM_SetDisabledWithReason(Controls.DisableAll, not hasOtherEnabled, "LOC_AWAWMM_TIP_DISABLE_ALL_NONE",
		"LOC_MODS_DISABLE_ALL_AWAWMM_TT")
	UpdateBottomSummary(visible, #mods, enabledTotal)
	Controls.ModListingsStack:CalculateSize()
	Controls.ModListingsStack:ReprocessAnchoring()
	Controls.ModListings:CalculateInternalSize()
	RefreshListingsSelectionState()
	if not bSkipDetails then
		RefreshModDetails()
	end
end
SelectMod = function(modHandle)
	g_SelectedModHandle = modHandle
	RefreshListingsSelectionState()
	RefreshModDetails()
end
local PROP_VALUE_CHARS_PER_LINE = 36
local PROP_ROW_LINE_H = 13
local PROP_ROW_MIN_H  = 22
local PROP_ROW_PADDING = PROP_ROW_MIN_H - PROP_ROW_LINE_H
function CountWrappedLines(text, charsPerLine)
	if text == nil or text == "" then
		return 1
	end
	local t = string.gsub(text, "%[NEWLINE%]", "\n")
	t = string.gsub(t, "%[[^%]]*%]", "")
	local lines = 0
	local start = 1
	while true do
		local pos = string.find(t, "\n", start, true)
		local seg = nil
		if pos == nil then
			seg = string.sub(t, start)
		else
			seg = string.sub(t, start, pos - 1)
		end
		local n = AWAWMM.Utf8Length(seg)
		local k = math.ceil(n / charsPerLine)
		if k < 1 then
			k = 1
		end
		lines = lines + k
		if pos == nil then
			break
		end
		start = pos + 1
	end
	if lines < 1 then
		lines = 1
	end
	return lines
end
function SetPropValueWrapped(rowControl, valueControl, value)
	local text = value
	if text == nil or text == "" then
		text = Locale.Lookup("LOC_AWAWMM_NO_VALUE")
	end
	valueControl:SetText(text)
	local engineH = valueControl:GetSizeY()
	local textH = nil
	local lines = nil
	local path = nil
	if engineH ~= nil and engineH > PROP_ROW_MIN_H then
		textH = engineH
		lines = math.ceil(engineH / PROP_ROW_LINE_H)
		if lines < 2 then
			lines = 2
		end
		path = "engine"
	elseif engineH ~= nil and engineH > 0 then
		textH = engineH
		lines = 1
		path = "engine1"
	else
		lines = CountWrappedLines(text, PROP_VALUE_CHARS_PER_LINE)
		textH = lines * PROP_ROW_LINE_H
		path = "estimate"
	end
	if lines < 1 then
		lines = 1
	end
	local rowH = PROP_ROW_MIN_H
	if lines > 1 then
		rowH = textH + PROP_ROW_PADDING
	end
	if rowH < PROP_ROW_MIN_H then
		rowH = PROP_ROW_MIN_H
	end
	if rowControl ~= nil then
		rowControl:SetSizeY(rowH)
	end
	local appliedPad = 0
	if lines > 1 then
		appliedPad = PROP_ROW_PADDING
	end
end
function AliasEditTextIsEmpty()
	local str = Controls.AWAWMMDetailAliasEditBox:GetText()
	return (str == nil or #str == 0 or str == AliasPlaceholder())
end
function ApplyAliasFromEditBox()
	local info = Modding.GetModInfo(g_SelectedModHandle)
	if info == nil or info.Id == nil then
		return
	end
	if AliasEditTextIsEmpty() then
		return
	end
	local text = Controls.AWAWMMDetailAliasEditBox:GetText()
	local ok, reason = AWAWMM.SetAlias(g_Aliases, info.Id, text)
	if not ok then
		return
	end
	AWAWMM.SaveAliases(g_Aliases)
	Controls.AWAWMMDetailAliasEditBox:SetText(AliasPlaceholder())
	RefreshListings()
end
function ClearAlias()
	local info = Modding.GetModInfo(g_SelectedModHandle)
	if info == nil or info.Id == nil then
		return
	end
	local ok, reason = AWAWMM.SetAlias(g_Aliases, info.Id, "")
	if not ok then
		return
	end
	AWAWMM.SaveAliases(g_Aliases)
	Controls.AWAWMMDetailAliasEditBox:SetText(AliasPlaceholder())
	AWAWMM_SetDisabledWithReason(Controls.AWAWMMDetailAliasApplyButton, true,
		"LOC_AWAWMM_TIP_ALIAS_EMPTY", nil)
	AWAWMM_SetDisabledWithReason(Controls.AWAWMMDetailAliasClearButton, true,
		"LOC_AWAWMM_TIP_ALIAS_NONE", nil)
	RefreshListings()
end
function ReadNumberProperty(handle, key)
	local raw = Modding.GetModProperty(handle, key)
	if raw == nil then
		return nil
	end
	return tonumber(raw)
end
AWAWMM_AffectsSavedGames = function(handle)
	local n = ReadNumberProperty(handle, "AffectsSavedGames")
	return (n == nil or n ~= 0)
end
function RefreshDependencyFoldIcons()
	Controls.AWAWMMDlcFoldUpIcon:SetHide(not g_DlcExpanded)
	Controls.AWAWMMDlcFoldDownIcon:SetHide(g_DlcExpanded)
	Controls.AWAWMMDlcItemsStack:SetHide(not g_DlcExpanded)
	Controls.AWAWMMDepsFoldUpIcon:SetHide(not g_DepsExpanded)
	Controls.AWAWMMDepsFoldDownIcon:SetHide(g_DepsExpanded)
	Controls.ModDependencyItemsStack:SetHide(not g_DepsExpanded)
	Controls.AWAWMMDependentsFoldUpIcon:SetHide(not g_DependentsExpanded)
	Controls.AWAWMMDependentsFoldDownIcon:SetHide(g_DependentsExpanded)
	Controls.AWAWMMDependentItemsStack:SetHide(not g_DependentsExpanded)
end
function ToggleDlcFold()
	g_DlcExpanded = not g_DlcExpanded
	RefreshDependencyFoldIcons()
	Controls.AWAWMMDlcStack:CalculateSize()
	Controls.AWAWMMDlcStack:ReprocessAnchoring()
	LayoutDetails()
end
function ToggleDepsFold()
	g_DepsExpanded = not g_DepsExpanded
	RefreshDependencyFoldIcons()
	Controls.ModDependenciesStack:CalculateSize()
	Controls.ModDependenciesStack:ReprocessAnchoring()
	LayoutDetails()
end
function ToggleDependentsFold()
	g_DependentsExpanded = not g_DependentsExpanded
	RefreshDependencyFoldIcons()
	Controls.AWAWMMDependentsStack:CalculateSize()
	Controls.AWAWMMDependentsStack:ReprocessAnchoring()
	LayoutDetails()
end
function IsOfficialDlcId(depId)
	if depId == nil then
		return false
	end
	local low = string.lower(tostring(depId))
	if low == DLC_XP1_ID_LOWER or low == DLC_XP2_ID_LOWER then
		return true
	end
	return (g_OfficialIds ~= nil and g_OfficialIds[low] == true)
end
function RefreshDependencyLists(modHandle)
	local dependencies = Modding.GetModAssociations(modHandle)
	local dlcNames = {}
	local modNames = {}
	local installedById = AWAWMM_GetInstalledById()
	if dependencies ~= nil then
		for i = 1, #dependencies do
			local dep = dependencies[i]
			local fastHandle = nil
			local fastName = nil
			if dep ~= nil and dep.Id ~= nil and dep.Id ~= "" and installedById ~= nil then
				local ent = installedById[string.lower(tostring(dep.Id))]
				if ent ~= nil then
					fastHandle = ent.Handle
					fastName = ent.Name
				end
			end
			if dep ~= nil and dep.Id ~= nil then
				local name = tostring(ResolveAssociationName(modHandle, dep, fastHandle, fastName) or "")
				local depId = dep.Id
				if IsOfficialDlcId(depId) then
					dlcNames[#dlcNames + 1] = name
				else
					modNames[#modNames + 1] = name
				end
			end
		end
	end
	table.sort(dlcNames, function(a, b) return Locale.Compare(a, b) == -1 end)
	table.sort(modNames, function(a, b) return Locale.Compare(a, b) == -1 end)
	g_DlcManager:ResetInstances()
	for i = 1, #dlcNames do
		local inst = g_DlcManager:GetInstance()
		inst.Item:SetText("[ICON_BULLET] " .. dlcNames[i])
	end
	Controls.AWAWMMDlcStack:SetHide(#dlcNames == 0)
	g_DependencyManager:ResetInstances()
	for i = 1, #modNames do
		local inst = g_DependencyManager:GetInstance()
		inst.Item:SetText("[ICON_BULLET] " .. modNames[i])
	end
	Controls.ModDependenciesStack:SetHide(#modNames == 0)
	RefreshDependencyFoldIcons()
	Controls.AWAWMMDlcItemsStack:CalculateSize()
	Controls.AWAWMMDlcItemsStack:ReprocessAnchoring()
	Controls.AWAWMMDlcStack:CalculateSize()
	Controls.AWAWMMDlcStack:ReprocessAnchoring()
	Controls.ModDependencyItemsStack:CalculateSize()
	Controls.ModDependencyItemsStack:ReprocessAnchoring()
	Controls.ModDependenciesStack:CalculateSize()
	Controls.ModDependenciesStack:ReprocessAnchoring()
	g_DependentsManager:ResetInstances()
	local selId = GetModId(modHandle)
	if selId == nil then
		local info = Modding.GetModInfo(modHandle)
		selId = (info ~= nil) and info.Id or nil
	end
	local dependents = AWAWMM_GetDependents(selId)
	if dependents ~= nil and #dependents > 0 then
		local names = {}
		for i = 1, #dependents do
			local e = dependents[i]
			if e ~= nil then
				names[#names + 1] = tostring(
					ResolveAssociationName(modHandle, e, e.Handle, e.Name) or "")
			end
		end
		table.sort(names, function(a, b) return Locale.Compare(a, b) == -1 end)
		for i = 1, #names do
			local inst = g_DependentsManager:GetInstance()
			inst.Item:SetText("[ICON_BULLET] " .. names[i])
		end
		Controls.AWAWMMDependentsStack:SetHide(false)
	else
		Controls.AWAWMMDependentsStack:SetHide(true)
	end
	RefreshDependencyFoldIcons()
	Controls.AWAWMMDependentItemsStack:CalculateSize()
	Controls.AWAWMMDependentItemsStack:ReprocessAnchoring()
	Controls.AWAWMMDependentsStack:CalculateSize()
	Controls.AWAWMMDependentsStack:ReprocessAnchoring()
end
local DETAIL_ACTION_ROW_H = 30
local DETAIL_ACTION_ROW_GAP = 4
function UpdateDetailActionRowsOffset(visibleRows)
	if visibleRows == nil or visibleRows < 1 then
		visibleRows = 1
	end
	local actionsH = Controls.AWAWMMDetailActions:GetSizeY()
	local totalH = visibleRows * DETAIL_ACTION_ROW_H + (visibleRows - 1) * DETAIL_ACTION_ROW_GAP
	local offsetY = math.floor((actionsH - totalH) / 2 + 0.5)
	if offsetY < 0 then
		offsetY = 0
	end
	Controls.AWAWMMDetailActionRows:SetOffsetY(offsetY)
end
function ErrorCodeLocKey(err)
	local s = string.lower(tostring(err or ""))
	if string.find(s, "gameversion", 1, true) ~= nil then
		return "LOC_MODS_ERROR_BAD_GAMEVERSION"
	end
	if string.find(s, "version", 1, true) ~= nil
		or string.find(s, "duplicates", 1, true) ~= nil then
		return "LOC_MODS_ERROR_MOD_VERSION_ALREADY_ENABLED"
	end
	if string.find(s, "exclusiv", 1, true) ~= nil then
		return "LOC_MODS_ERROR_MOD_HAS_EXCLUSIVITY_CONFLICTS"
	end
	if string.find(s, "blocked", 1, true) ~= nil
		or string.find(s, "othermod", 1, true) ~= nil then
		return "LOC_MODS_ERROR_MOD_BLOCKED_BY_OTHER_MOD"
	end
	return nil
end
function RefreshDetailActions(modHandle, info)
	local officialLocked = (info.Official == true and info.Allowance == false)
	if officialLocked then
		Controls.EnableButton:SetHide(true)
		Controls.DisableButton:SetHide(true)
	elseif info.Enabled then
		Controls.EnableButton:SetHide(true)
		Controls.DisableButton:SetHide(false)
		Controls.DisableButton:SetDisabled(false)
		ClearClick(Controls.DisableButton, Mouse.eLClick)
		Controls.DisableButton:RegisterCallback(Mouse.eLClick, function()
			DoDisableMod(modHandle)
		end)
		Controls.DisableButton:SetToolTipString(nil)
		local err, xtra, sources = Modding.CanDisableMod(modHandle)
		if err == "MissingDependencies" then
		elseif err ~= "OK" then
			local tip = {}
			if err == "OwnershipRequired" then
				tip[#tip + 1] = Locale.Lookup("LOC_MODS_DISABLE_ERROR")
				local suffix = " (" .. Locale.Lookup("LOC_MODS_DETAILS_OWNERSHIP_NO") .. ")"
				local refs = BuildRefList(xtra, suffix)
				for i = 1, #refs do
					tip[#tip + 1] = refs[i]
				end
			else
				local mapped = ErrorCodeLocKey(err)
				tip[#tip + 1] = Locale.Lookup(mapped or "LOC_MODS_DISABLE_ERROR")
			end
			Controls.DisableButton:SetToolTipString(table.concat(tip, "[NEWLINE]"))
		end
	else
		Controls.DisableButton:SetHide(true)
		Controls.EnableButton:SetHide(false)
		local err, xtra = Modding.CanEnableMod(modHandle)
		if err == "MissingDependencies" then
			local retryErr, retryXtra = Modding.CanEnableMod(modHandle, true)
			if retryErr == "OK" then
				err = "OK"
				if retryXtra ~= nil and #retryXtra > 0 then
					xtra = retryXtra
				end
			end
		end
		if err == "OK" then
			Controls.EnableButton:SetDisabled(false)
			ClearClick(Controls.EnableButton, Mouse.eLClick)
			Controls.EnableButton:RegisterCallback(Mouse.eLClick, function()
				EnableWithCompatCheck(modHandle)
			end)
			local refs = BuildRefList(xtra)
			if #refs > 0 then
				local tip = { Locale.Lookup("LOC_MODS_ENABLE_INCLUDE") }
				for i = 1, #refs do
					tip[#tip + 1] = refs[i]
				end
				Controls.EnableButton:SetToolTipString(table.concat(tip, "[NEWLINE]"))
			else
				Controls.EnableButton:SetToolTipString(nil)
			end
		else
			Controls.EnableButton:SetDisabled(true)
			ClearClick(Controls.EnableButton, Mouse.eLClick)
			local tip = {}
			if err == "ContainsDuplicates" then
				tip[#tip + 1] = Locale.Lookup("LOC_MODS_ERROR_MOD_VERSION_ALREADY_ENABLED")
			elseif err == "OwnershipRequired" then
				tip[#tip + 1] = Locale.Lookup("LOC_MODS_ENABLE_ERROR")
				local suffix = " (" .. Locale.Lookup("LOC_MODS_DETAILS_OWNERSHIP_NO") .. ")"
				local refs = BuildRefList(xtra, suffix)
				for i = 1, #refs do
					tip[#tip + 1] = refs[i]
				end
			elseif err == "MissingDependencies" then
				tip[#tip + 1] = Locale.Lookup("LOC_MODS_ERROR_MOD_MISSING_DEPENDENCIES")
				local refs = BuildRefList(xtra)
				for i = 1, #refs do
					tip[#tip + 1] = refs[i]
				end
			else
				local mapped = ErrorCodeLocKey(err)
				tip[#tip + 1] = Locale.Lookup(mapped or "LOC_MODS_ENABLE_ERROR")
				local refs = BuildRefList(xtra)
				for i = 1, #refs do
					tip[#tip + 1] = refs[i]
				end
			end
			Controls.EnableButton:SetToolTipString(table.concat(tip, "[NEWLINE]"))
		end
	end
	local id = info.Id
	local isFav = (id ~= nil and AWAWMM.Has(g_Favorites, id))
	Controls.AWAWMMDetailFavoriteButton:LocalizeAndSetText(
		isFav and "LOC_AWAWMM_FAVORITE_REMOVE" or "LOC_AWAWMM_FAVORITE_ADD")
	ClearClick(Controls.AWAWMMDetailFavoriteButton, Mouse.eLClick)
	Controls.AWAWMMDetailFavoriteButton:RegisterCallback(Mouse.eLClick, function()
		ToggleFavorite(modHandle)
	end)
	local extra = g_ModExtras[modHandle]
	local subscriptionId = AWAWMM_GetSubscriptionId(modHandle, info.Id, true, info)
	if extra ~= nil then
		extra.SubscriptionId = subscriptionId
		extra.SubIdKnown = true
	end
	if subscriptionId == nil then
		Controls.AWAWMMDetailUnsubscribeButton:SetHide(true)
		AWAWMM_SyncDetailUnsubscribeButton(nil)
		Controls.AWAWMMDetailViewButton:SetHide(true)
		ClearClick(Controls.AWAWMMDetailUnsubscribeButton, Mouse.eLClick)
		ClearClick(Controls.AWAWMMDetailViewButton, Mouse.eLClick)
	else
		Controls.AWAWMMDetailUnsubscribeButton:SetHide(false)
		AWAWMM_SyncDetailUnsubscribeButton(info.Id)
		ClearClick(Controls.AWAWMMDetailUnsubscribeButton, Mouse.eLClick)
		Controls.AWAWMMDetailUnsubscribeButton:RegisterCallback(Mouse.eLClick, function()
			ConfirmUnsubscribe(modHandle, subscriptionId)
		end)
		local overlay = (Steam ~= nil and Steam.IsOverlayEnabled ~= nil and Steam.IsOverlayEnabled())
		Controls.AWAWMMDetailViewButton:SetHide(not overlay)
		ClearClick(Controls.AWAWMMDetailViewButton, Mouse.eLClick)
		if overlay then
			Controls.AWAWMMDetailViewButton:RegisterCallback(Mouse.eLClick, function()
				Steam.ActivateGameOverlayToUrl(
					"http://steamcommunity.com/sharedfiles/filedetails/?id=" .. tostring(subscriptionId))
			end)
		end
	end
	local rows = 0
	if not Controls.EnableButton:IsHidden()
		or not Controls.DisableButton:IsHidden()
		or not Controls.AWAWMMDetailFavoriteButton:IsHidden() then
		rows = rows + 1
	end
	if not Controls.AWAWMMDetailUnsubscribeButton:IsHidden()
		or not Controls.AWAWMMDetailViewButton:IsHidden() then
		rows = rows + 1
	end
	UpdateDetailActionRowsOffset(rows)
	AWAWMM_ApplyUnavailableToControls()
end
RefreshModDetails = function()
	if g_SelectedModHandle == nil then
		Controls.NoModSelected:SetHide(false)
		Controls.ModDetailsContainer:SetHide(true)
		return
	end
	local info = Modding.GetModInfo(g_SelectedModHandle)
	if info == nil then
		g_SelectedModHandle = nil
		Controls.NoModSelected:SetHide(false)
		Controls.ModDetailsContainer:SetHide(true)
		return
	end
	Controls.NoModSelected:SetHide(true)
	Controls.ModDetailsContainer:SetHide(false)
	local bIsMap = (info.Source == "Map")
	local compatible = Modding.IsModCompatible(g_SelectedModHandle)
	Controls.ModCompatibilityWarning:SetHide(compatible)
	local extra = g_ModExtras[g_SelectedModHandle]
	local alias = nil
	if extra ~= nil and extra.Id ~= nil then
		alias = g_Aliases[extra.Id]
	end
	local resolvedName = ResolveModText(g_SelectedModHandle, info.Name)
	if IsBareLocKey(resolvedName) then
		if info.Name ~= nil and info.Name ~= "" then
			resolvedName = tostring(info.Name)
		else
			resolvedName = FallbackModName(info)
		end
	elseif resolvedName == nil or resolvedName == "" then
		resolvedName = FallbackModName(info)
	end
	local displayName = ComposeDisplayName(tostring(resolvedName or ""), alias)
	TruncateString(Controls.ModTitle, 500, displayName)
	Controls.AWAWMMDetailAliasEditBox:SetText(AliasPlaceholder())
	AWAWMM_SetDisabledWithReason(Controls.AWAWMMDetailAliasApplyButton, true,
		"LOC_AWAWMM_TIP_ALIAS_EMPTY", nil)
	AWAWMM_SetDisabledWithReason(Controls.AWAWMMDetailAliasClearButton,
		(alias == nil or alias == ""), "LOC_AWAWMM_TIP_ALIAS_NONE", nil)
	Controls.AWAWMMAliasEditRow:SetHide(false)
	local isOfficial = (info ~= nil and info.Official == true)
	if extra ~= nil then
		extra.SubscriptionId = AWAWMM_GetSubscriptionId(g_SelectedModHandle, info.Id, true, info)
		extra.SubIdKnown = true
	end
	local isLocalMod = ((not isOfficial) and (extra == nil or extra.SubIdKnown ~= true
		or extra.SubscriptionId == nil))
	local sublineText = nil
	if isOfficial then
		sublineText = Locale.Lookup("LOC_AWAWMM_BADGE_OFFICIAL_TOOLTIP")
	elseif not isLocalMod then
		sublineText = Locale.Lookup("LOC_AWAWMM_DETAILS_SUBSCRIPTION_ID")
			.. " " .. tostring(extra.SubscriptionId)
	else
		sublineText = Locale.Lookup("LOC_AWAWMM_FILTER_LOCAL")
	end
	if alias ~= nil and alias ~= "" then
		sublineText = sublineText .. "    " .. Locale.Lookup("LOC_AWAWMM_DETAILS_ALIAS")
			.. " " .. alias
	end
	SetSingleLineText(Controls.AWAWMMDetailSubscriptionId, sublineText, 96, 500)
	Controls.AWAWMMDetailSubscriptionId:SetHide(false)
	local modIdText = Locale.Lookup("LOC_AWAWMM_DETAIL_MOD_ID") .. " " .. tostring(info.Id or "")
	SetSingleLineText(Controls.ModIdVersion, modIdText, 64, 500)
	local updatedValue = nil
	if extra ~= nil then
		if extra.SubscriptionId ~= nil and extra.UpdatedFetched ~= true then
			extra.UpdatedFetched = true
			local subDetails = Modding.GetSubscriptionDetails(extra.SubscriptionId)
			if subDetails ~= nil then
				extra.Updated = subDetails.LastUpdated
			end
		end
		updatedValue = extra.Updated
	end
	local updatedText = nil
	if updatedValue ~= nil then
		updatedText = Locale.Lookup("LOC_AWAWMM_DETAIL_UPDATED", updatedValue)
	else
		updatedText = Locale.Lookup("LOC_AWAWMM_DETAIL_UPDATED_NONE")
	end
	if updatedText == nil or tostring(updatedText) == "LOC_AWAWMM_DETAIL_UPDATED"
		or tostring(updatedText) == "LOC_AWAWMM_DETAIL_UPDATED_NONE" then
		updatedText = "LOC_AWAWMM_DETAIL_UPDATED_NONE"
	end
	SetSingleLineText(Controls.AWAWMMDetailUpdated, tostring(updatedText), 64, 500)
	if bIsMap then
		SetSingleLineText(Controls.ModFileName, tostring(info.SourceFileName or ""), 64, 500)
		Controls.ModFileName:SetHide(false)
	else
		Controls.ModFileName:SetHide(true)
	end
	local desc = Modding.GetModProperty(g_SelectedModHandle, "Description") or info.Teaser
	if desc ~= nil then
		desc = ResolveVisibleText(g_SelectedModHandle, desc)
		Controls.ModDescription:SetText(desc)
		Controls.ModDescription:SetHide(false)
	else
		Controls.ModDescription:SetText("")
		Controls.ModDescription:SetHide(true)
	end
	local authors = Modding.GetModProperty(g_SelectedModHandle, "Authors")
	SetPropValueWrapped(Controls.ModPropRowAuthors, Controls.ModAuthorsValue,
		AWAWMM_AuthorCanonicalize(tostring(ResolveVisibleText(g_SelectedModHandle, authors) or ""), true))
	local thanks = Modding.GetModProperty(g_SelectedModHandle, "SpecialThanks")
	SetPropValueWrapped(Controls.ModPropRowSpecialThanks, Controls.ModSpecialThanksValue,
		tostring(ResolveVisibleText(g_SelectedModHandle, thanks) or ""))
	SetSingleLineValue(Controls.ModAffectsSavedGamesValue,
		AWAWMM_AffectsSavedGames(g_SelectedModHandle) and Locale.Lookup("LOC_MODS_YES")
			or Locale.Lookup("LOC_MODS_NO"), 120)
	local sp = ReadNumberProperty(g_SelectedModHandle, "SupportsSinglePlayer")
	SetSingleLineValue(Controls.ModSupportsSinglePlayerValue,
		(sp == 0) and ("[COLOR_RED]" .. Locale.Lookup("LOC_MODS_NO") .. "[ENDCOLOR]") or Locale.Lookup("LOC_MODS_YES"), 120)
	local mp = ReadNumberProperty(g_SelectedModHandle, "SupportsMultiplayer")
	SetSingleLineValue(Controls.ModSupportsMultiplayerValue,
		(mp == 0) and ("[COLOR_RED]" .. Locale.Lookup("LOC_MODS_NO") .. "[ENDCOLOR]") or Locale.Lookup("LOC_MODS_YES"), 120)
	RefreshDependencyLists(g_SelectedModHandle)
	RefreshDetailGroupPullDown()
	RefreshDetailActions(g_SelectedModHandle, info)
	Controls.ModPropertiesStack:CalculateSize()
	Controls.ModPropertiesStack:ReprocessAnchoring()
	LayoutDetails()
end
AWAWMM_TOOLBAR = {
	GAP = 12,
	TOOLBAR_W = 1326,
	CONST_PX = 226,
	BIG_COUNT = 5,
	GAP_BIG_MIN = 32,
	GAP_BIG_FLOOR = 28,
	BIG_MIN = 120,
	CJK_W = 12,
	OTHER_W = 6.5,
	PAD_PULLDOWN = 44,
	PAD_SORT = 44,
	PAD_DETAIL = 44,
	ITEM_INSET = 4,
	ITEM_PAD = 16,
	CHIP_PAD = 12,
	CHIP_GAP = 4,
	FILTER_ROW_X = 40,
	TEXT_MIN_ZH = { SORT = 144, GROUPFILTER = 112 },
	ROW_TITLE_X = 88,
	BADGE_PAD = 6,
	CHECK_BOX_PX = 24,
	CHECK_PAD = 20,
	CHECK_GAP = 5,
	CHECK_CJK_W = 16,
	CHECK_OTHER_W = 7.8,
	W = {},
}
AWAWMM_TOOLBAR.Setup = function()
	AWAWMM_TOOLBAR.MIN_W = { BIG = 188, DETAIL = 568, GROUPBYAUTHOR = 129, SEARCH = 180 }
	AWAWMM_TOOLBAR.ORDER = {
		{ ID = "ModGroupPullDown",          KW = "MODGROUP", PullDown = true },
		{ ID = "CreateModGroup",            W  = 26 },
		{ ID = "DeleteModGroup",            W  = 26 },
		{ ID = "AWAWMMGroupFilterPullDown", KW = "GROUPFILTER", PullDown = true },
		{ ID = "AWAWMMGroupRenameButton",   W  = 26 },
		{ ID = "AWAWMMGroupDeleteButton",   W  = 26 },
		{ ID = "AWAWMMSearchGrid",          KW = "SEARCH", NoButton = true },
		{ ID = "SortListingsPullDown",      KW = "SORT", PullDown = true },
		{ ID = "AWAWMMSortOrderToggle",     W  = 26 },
		{ ID = "AWAWMMGroupByAuthorToggle", KW = "GROUPBYAUTHOR", NoButton = true,
		  Right = true },
	}
	AWAWMM_TOOLBAR.CHIPS = {
		{ ID = "AWAWMMFilterShowAll",         Key = "LOC_AWAWMM_FILTER_SHOW_ALL",         Min = 68,  Stack = true },
		{ ID = "AWAWMMFilterFavorite",        Key = "LOC_AWAWMM_FILTER_FAVORITE",         Min = 80,  Stack = true },
		{ ID = "AWAWMMFilterOnlyEnabled",     Key = "LOC_AWAWMM_FILTER_ONLY_ENABLED",     Min = 80,  Stack = true },
		{ ID = "ShowOfficialContent",         Key = "LOC_MODS_FIRAXIAN_CONTENT",          Min = 56,  Stack = true },
		{ ID = "AWAWMMFilterWorkshop",        Key = "LOC_AWAWMM_FILTER_WORKSHOP",         Min = 68,  Stack = true },
		{ ID = "AWAWMMFilterLocal",           Key = "LOC_AWAWMM_FILTER_LOCAL",            Min = 68,  Stack = true },
		{ ID = "AWAWMMFilterSupportsMP",      Key = "LOC_AWAWMM_FILTER_SUPPORTS_MP",      Min = 104, Stack = true },
		{ ID = "AWAWMMFilterRulesetStandard", Key = "LOC_AWAWMM_FILTER_RULESET_STANDARD", Min = 68,  Stack = true },
		{ ID = "AWAWMMFilterRulesetXP1",      Key = "LOC_AWAWMM_FILTER_RULESET_XP1",      Min = 84,  Stack = true },
		{ ID = "AWAWMMFilterRulesetXP2",      Key = "LOC_AWAWMM_FILTER_RULESET_XP2",      Min = 84,  Stack = true },
		{ ID = "AWAWMMCleanupOrphansButton",  Key = "LOC_AWAWMM_CLEANUP_ORPHANS",         Min = 150 },
	}
end
AWAWMM_TOOLBAR.Setup()
AWAWMM_TOOLBAR.Measure = function(text, big)
	if text == nil then
		return 0
	end
	local cw = AWAWMM_TOOLBAR.CJK_W
	local ow = AWAWMM_TOOLBAR.OTHER_W
	if big == true then
		cw = AWAWMM_TOOLBAR.CHECK_CJK_W
		ow = AWAWMM_TOOLBAR.CHECK_OTHER_W
	end
	local s = tostring(text)
	local w = 0
	local i = 1
	local n = #s
	while i <= n do
		local b = string.byte(s, i)
		local step = 1
		if b >= 240 then
			step = 4
		elseif b >= 224 then
			step = 3
		elseif b >= 192 then
			step = 2
		end
		if step >= 3 then
			w = w + cw
		else
			w = w + ow
		end
		i = i + step
	end
	return math.ceil(w)
end
AWAWMM_TOOLBAR.StripPad = function(s)
	while #s >= 2 do
		if string.byte(s, #s - 1) ~= 194 or string.byte(s, #s) ~= 160 then
			break
		end
		s = string.sub(s, 1, #s - 2)
	end
	return s
end
AWAWMM_TOOLBAR.MeasureCheck = function(text)
	return AWAWMM_TOOLBAR.Measure(AWAWMM_TOOLBAR.StripPad(tostring(text or "")), true)
end
AWAWMM_TOOLBAR.Fit = function(text, maxW, big)
	local s = tostring(text or "")
	if AWAWMM_TOOLBAR.Measure(s, big) <= maxW then
		return s
	end
	local ell = "…"
	local ellW = AWAWMM_TOOLBAR.Measure(ell, big)
	local out = ""
	local w = 0
	local i = 1
	local n = #s
	while i <= n do
		local b = string.byte(s, i)
		local step = 1
		if b >= 240 then
			step = 4
		elseif b >= 224 then
			step = 3
		elseif b >= 192 then
			step = 2
		end
		local chW = AWAWMM_TOOLBAR.CJK_W
		if step < 3 then
			chW = AWAWMM_TOOLBAR.OTHER_W
		end
		if big == true then
			if step >= 3 then
				chW = AWAWMM_TOOLBAR.CHECK_CJK_W
			else
				chW = AWAWMM_TOOLBAR.CHECK_OTHER_W
			end
		end
		if w + chW + ellW > maxW then
			break
		end
		out = out .. string.sub(s, i, i + step - 1)
		w = w + chW
		i = i + step
	end
	return out .. ell
end
AWAWMM_TOOLBAR.FitControl = function(control, maxW, big)
	local cur = control:GetText()
	if cur == nil then
		return
	end
	local s = tostring(cur)
	local fitted = AWAWMM_TOOLBAR.Fit(s, maxW, big)
	if fitted ~= s then
		control:SetText(fitted)
	end
end
AWAWMM_TOOLBAR.FitPulldownButton = function(ctrl, w, pad)
	if ctrl == nil or w == nil then
		return
	end
	local btn = ctrl:GetButton()
	if btn == nil then
		return
	end
	local before = tostring(btn:GetText())
	AWAWMM_TOOLBAR.FitControl(btn, w - pad, true)
	local after = tostring(btn:GetText())
end
AWAWMM_TOOLBAR.TextMinPx = function()
	local prefix = LookupLocalized("LOC_AWAWMM_GROUP_FILTER_PREFIX", true)
	local all    = LookupLocalized("LOC_AWAWMM_GROUP_FILTER_ALL", true)
	local w
	if prefix == nil or all == nil then
		w = AWAWMM_TOOLBAR.TEXT_MIN_ZH.GROUPFILTER
	else
		w = AWAWMM_TOOLBAR.Measure(tostring(prefix) .. tostring(all), true)
	end
	local sortW = nil
	for i = 1, #SORT_OPTIONS do
		local t = LookupLocalized(SORT_OPTIONS[i].Label, true)
		if t == nil then
			sortW = nil
			break
		end
		local tw = AWAWMM_TOOLBAR.Measure(t, true)
		if sortW == nil or tw > sortW then
			sortW = tw
		end
	end
	if sortW == nil then
		sortW = AWAWMM_TOOLBAR.TEXT_MIN_ZH.SORT
	end
	if sortW > w then
		w = sortW
	end
	return w
end
AWAWMM_TOOLBAR.Solve = function(gbaW, textMinPx)
	local TB = AWAWMM_TOOLBAR
	local eqW = math.ceil((TB.TOOLBAR_W - TB.CONST_PX - gbaW - TB.GAP_BIG_MIN) / TB.BIG_COUNT)
	if eqW < TB.BIG_MIN then
		eqW = TB.BIG_MIN
	end
	local w = eqW
	local textW = textMinPx + TB.PAD_PULLDOWN
	if w < textW then
		w = textW
	end
	local s = w * 2
	local sMax = TB.TOOLBAR_W - 3 * w - TB.CONST_PX - gbaW - TB.GAP_BIG_FLOOR
	if s > sMax then
		s = sMax
	end
	if s < TB.MIN_W.SEARCH then
		s = TB.MIN_W.SEARCH
	end
	local gapBig = TB.TOOLBAR_W - 3 * w - TB.CONST_PX - gbaW - s
	return w, s, gapBig, eqW
end
AWAWMM_TOOLBAR.Compute = function()
	local gbaText = Locale.Lookup("LOC_AWAWMM_GROUP_BY_AUTHOR")
	if gbaText == nil or #gbaText == 0 or string.sub(gbaText, 1, 4) == "LOC_" then
		gbaText = "按作者分组"
	end
	local gbaW = AWAWMM_TOOLBAR.MeasureCheck(gbaText) + AWAWMM_TOOLBAR.CHECK_BOX_PX
		+ AWAWMM_TOOLBAR.CHECK_PAD + AWAWMM_TOOLBAR.CHECK_GAP
	if gbaW < AWAWMM_TOOLBAR.MIN_W.GROUPBYAUTHOR then
		gbaW = AWAWMM_TOOLBAR.MIN_W.GROUPBYAUTHOR
	end
	AWAWMM_TOOLBAR.W.GROUPBYAUTHOR = gbaW
	local textMin = AWAWMM_TOOLBAR.TextMinPx()
	local big, search, gapBig, eqW = AWAWMM_TOOLBAR.Solve(gbaW, textMin)
	AWAWMM_TOOLBAR.W.BIG         = big
	AWAWMM_TOOLBAR.W.MODGROUP    = big
	AWAWMM_TOOLBAR.W.GROUPFILTER = big
	AWAWMM_TOOLBAR.W.SORT        = big
	AWAWMM_TOOLBAR.W.SEARCH      = search
	AWAWMM_TOOLBAR.W.DETAIL      = AWAWMM_TOOLBAR.MIN_W.DETAIL
	AWAWMM_TOOLBAR.W.GAP_BIG     = gapBig
	AWAWMM_TOOLBAR.W.TEXT_MIN    = textMin + AWAWMM_TOOLBAR.PAD_PULLDOWN
	AWAWMM_TOOLBAR.W.EQ_W        = eqW
end
AWAWMM_TOOLBAR.POPUP_INNER_PAD_X = 3
AWAWMM_TOOLBAR.SyncPopupWidth = function(ctrl, w)
	if ctrl == nil or w == nil or ctrl.GetScrollPanel == nil then
		return
	end
	local sp = ctrl:GetScrollPanel()
	if sp == nil or sp.SetSizeX == nil then
		return
	end
	local want = w - 2 * AWAWMM_TOOLBAR.POPUP_INNER_PAD_X
	if sp:GetSizeX() ~= want then
		sp:SetSizeX(want)
	end
end
AWAWMM_TOOLBAR.ApplyWidths = function()
	AWAWMM_TOOLBAR.Compute()
	for i = 1, #AWAWMM_TOOLBAR.ORDER do
		local item = AWAWMM_TOOLBAR.ORDER[i]
		if item.KW ~= nil then
			local w = AWAWMM_TOOLBAR.W[item.KW]
			local c = Controls[item.ID]
			if c ~= nil and w ~= nil then
				c:SetSizeX(w)
				if item.NoButton ~= true then
					local btn = c:GetButton()
					if btn ~= nil then
						btn:SetSizeX(w)
					end
				end
				if item.PullDown == true then
					AWAWMM_TOOLBAR.SyncPopupWidth(c, w)
				end
				AWAWMM_TOOLBAR.W["ITEM_" .. item.KW] = w - AWAWMM_TOOLBAR.ITEM_INSET
			end
		end
	end
end
AWAWMM_TOOLBAR.Layout = function()
	AWAWMM_TOOLBAR.ApplyWidths()
	local x = 0
	local first = true
	local desc = {}
	for i = 1, #AWAWMM_TOOLBAR.ORDER do
		local item = AWAWMM_TOOLBAR.ORDER[i]
		local c = Controls[item.ID]
		if c ~= nil then
			local w = item.W or AWAWMM_TOOLBAR.W[item.KW] or 0
			if item.Right == true then
				AWAWMM_TOOLBAR.RightAligned = AWAWMM_TOOLBAR.TOOLBAR_W - w
				desc[#desc + 1] = item.ID .. "(R)=" .. tostring(AWAWMM_TOOLBAR.RightAligned)
					.. ".." .. tostring(AWAWMM_TOOLBAR.TOOLBAR_W)
			else
				if not first then
					x = x + (item.Gap or AWAWMM_TOOLBAR.GAP)
				end
				c:SetOffsetX(x)
				desc[#desc + 1] = item.ID .. "=" .. tostring(x) .. ".." .. x + w
				x = x + w
				first = false
			end
		end
	end
	AWAWMM_TOOLBAR.Right = x
end
AWAWMM_TOOLBAR.ApplyFilterChips = function()
	local chips = AWAWMM_TOOLBAR.CHIPS
	local pad = AWAWMM_TOOLBAR.CHIP_PAD
	local done = 0
	local rowW = 0
	local cleanupW = 0
	local desc = {}
	for i = 1, #chips do
		local c = Controls[chips[i].ID]
		if c ~= nil then
			local text = Locale.Lookup(chips[i].Key)
			if text ~= nil and #tostring(text) > 0 and tostring(text) ~= chips[i].Key then
				local w = AWAWMM_TOOLBAR.Measure(text) + pad
				if w < chips[i].Min then
					w = chips[i].Min
				end
				c:SetSizeX(w)
				done = done + 1
				if chips[i].Stack == true then
					rowW = rowW + w
				else
					cleanupW = w
				end
				desc[#desc + 1] = chips[i].ID .. "=" .. tostring(w)
			end
		end
	end
	if done == #chips then
		rowW = rowW + 3 + 12 * AWAWMM_TOOLBAR.CHIP_GAP
		AWAWMM_TOOLBAR.W.FILTER_ROW     = rowW
		AWAWMM_TOOLBAR.W.FILTER_CLEANUP = cleanupW
		AWAWMM_TOOLBAR.W.FILTER_ROW_MAX = AWAWMM_TOOLBAR.TOOLBAR_W - cleanupW
			- AWAWMM_TOOLBAR.FILTER_ROW_X - AWAWMM_TOOLBAR.GAP
	else
		AWAWMM_TOOLBAR.W.FILTER_ROW     = nil
		AWAWMM_TOOLBAR.W.FILTER_CLEANUP = nil
		AWAWMM_TOOLBAR.W.FILTER_ROW_MAX = nil
	end
	if Controls.AWAWMMFilterRow ~= nil then
		Controls.AWAWMMFilterRow:ReprocessAnchoring()
	end
	if Controls.AWAWMMFilterBar ~= nil then
		Controls.AWAWMMFilterBar:ReprocessAnchoring()
	end
end
function SortModGroupsByIndex(groups)
	table.sort(groups, function(a, b)
		if a.SortIndex ~= b.SortIndex then
			return a.SortIndex < b.SortIndex
		end
		return Locale.Compare(a.DisplayName, b.DisplayName) == -1
	end)
end
function RefreshModGroups()
	AWAWMM.EnsureCurrentModGroupSafe()
	local allGroups = Modding.GetModGroups()
	local currentGroup = Modding.GetCurrentModGroup()
	local matchedCurrent = false
	local currentIsOurs = false
	if type(allGroups) == "table" then
		for i = 1, #allGroups do
			if allGroups[i] ~= nil and allGroups[i].Handle == currentGroup
				and AWAWMM_IsOurGroupName(allGroups[i].Name) then
				currentIsOurs = true
			end
		end
	end
	local groups = AWAWMM.FilterOurGroups(allGroups)
	if groups == nil then
		return
	end
	for i = 1, #groups do
		groups[i].DisplayName = Locale.Lookup(groups[i].Name)
	end
	SortModGroupsByIndex(groups)
	local comboBox = Controls.ModGroupPullDown
	AWAWMM_TOOLBAR.ApplyWidths()
	local itemW = AWAWMM_TOOLBAR.W.ITEM_MODGROUP
	comboBox:ClearEntries()
	for i = 1, #groups do
		local v = groups[i]
		local controlTable = {}
		comboBox:BuildEntry("InstanceOne", controlTable)
		controlTable.Button:SetSizeX(itemW)
		controlTable.Button:LocalizeAndSetText(v.Name)
		AWAWMM_TOOLBAR.FitControl(controlTable.Button, itemW - AWAWMM_TOOLBAR.ITEM_PAD, true)
		ClearClick(controlTable.Button, Mouse.eLClick)
		controlTable.Button:RegisterCallback(Mouse.eLClick, function()
			Modding.SetCurrentModGroup(v.Handle)
			CommitEnabledModsToEngine()
			AWAWMM_InvalidateModsCache()
			RefreshModGroups()
			RefreshListings()
		end)
		if v.Handle == currentGroup then
			comboBox:GetButton():SetText(v.DisplayName)
			AWAWMM_SetDisabledWithReason(Controls.DeleteModGroup, not v.CanDelete,
				"LOC_AWAWMM_TIP_GROUP_DELETE_OFFICIAL", "LOC_MODS_GROUP_DELETE_DESCRIPTION")
			matchedCurrent = true
		end
	end
	if not matchedCurrent then
		comboBox:GetButton():SetText("")
		AWAWMM_SetDisabledWithReason(Controls.DeleteModGroup, true,
			"LOC_AWAWMM_TIP_GROUP_NONE_SELECTED", "LOC_MODS_GROUP_DELETE_DESCRIPTION")
	end
	comboBox:CalculateInternals()
	AWAWMM_TOOLBAR.FitPulldownButton(comboBox, AWAWMM_TOOLBAR.W.MODGROUP,
		AWAWMM_TOOLBAR.PAD_PULLDOWN)
	AWAWMM_TOOLBAR.Layout()
	AWAWMM_ApplyUnavailableToControls()
end
function CreateModGroup()
	g_GroupPopupMode = "modgroup"
	Controls.BindingTitle:LocalizeAndSetText("LOC_MODS_GROUP_ENTER_NAME")
	Controls.ModGroupEditBox:SetText("")
	AWAWMM_SetDisabledWithReason(Controls.CreateModGroupButton, true,
		"LOC_AWAWMM_TIP_GROUP_NAME_EMPTY", nil)
	AWAWMM_ShowGroupError("LOC_AWAWMM_TIP_GROUP_NAME_EMPTY")
	Controls.NameModGroupPopup:SetHide(false)
	Controls.NameModGroupPopupAlpha:SetToBeginning()
	Controls.NameModGroupPopupAlpha:Play()
	Controls.NameModGroupPopupSlide:SetToBeginning()
	Controls.NameModGroupPopupSlide:Play()
	Controls.ModGroupEditBox:TakeFocus()
end
function DeleteModGroup()
	local groups = AWAWMM.FilterOurGroups(Modding.GetModGroups())
	if groups == nil then
		return
	end
	for i = 1, #groups do
		groups[i].DisplayName = Locale.Lookup(groups[i].Name)
	end
	SortModGroupsByIndex(groups)
	local currentGroup = Modding.GetCurrentModGroup()
	if currentGroup == nil then
		return
	end
	local switched = false
	for i = 1, #groups do
		if groups[i].Handle ~= currentGroup then
			Modding.SetCurrentModGroup(groups[i].Handle)
			CommitEnabledModsToEngine()
			AWAWMM_InvalidateModsCache()
			Modding.DeleteModGroup(currentGroup)
			switched = true
			break
		end
	end
	RefreshModGroups()
	RefreshListings()
end
local GROUP_CHECK_PREFIX = "✓ "
function SelectedModId()
	if g_SelectedModHandle == nil then
		return nil
	end
	return GetModId(g_SelectedModHandle)
end
function RefreshCustomGroupFilterPullDown()
	local combo = Controls.AWAWMMGroupFilterPullDown
	if combo == nil then
		return
	end
	if g_GroupFilter ~= nil and not AWAWMM.HasGroup(g_Groups, g_GroupFilter) then
		g_GroupFilter = nil
	end
	AWAWMM_TOOLBAR.ApplyWidths()
	local itemW = AWAWMM_TOOLBAR.W.ITEM_GROUPFILTER
	combo:ClearEntries()
	local allEntry = {}
	combo:BuildEntry("InstanceOne", allEntry)
	allEntry.Button:SetSizeX(itemW)
	SetEntryLocalizedText(allEntry.Button, "LOC_AWAWMM_GROUP_FILTER_ALL")
	AWAWMM_TOOLBAR.FitControl(allEntry.Button, itemW - AWAWMM_TOOLBAR.ITEM_PAD, true)
	ClearClick(allEntry.Button, Mouse.eLClick)
	allEntry.Button:RegisterCallback(Mouse.eLClick, function()
		g_GroupFilter = nil
		RefreshCustomGroupFilterPullDown()
		RefreshListings()
	end)
	local names = AWAWMM.GetGroups(g_Groups)
	table.sort(names, function(a, b) return Locale.Compare(a, b) == -1 end)
	for i = 1, #names do
		local name = names[i]
		local count = AWAWMM.CountModsInGroup(g_GroupMembers, name)
		local entry = {}
		combo:BuildEntry("InstanceOne", entry)
		entry.Button:SetSizeX(itemW)
		local suffix = GroupCountSuffix(count)
		local nameBudget = itemW - AWAWMM_TOOLBAR.ITEM_PAD
			- AWAWMM_TOOLBAR.Measure(suffix, true)
		if nameBudget < 1 then
			nameBudget = 1
		end
		SetEntryUserText(entry.Button,
			AWAWMM_TOOLBAR.Fit(tostring(name), nameBudget, true), count)
		ClearClick(entry.Button, Mouse.eLClick)
		entry.Button:RegisterCallback(Mouse.eLClick, function()
			g_GroupFilter = name
			RefreshCustomGroupFilterPullDown()
			RefreshListings()
		end)
	end
	combo:CalculateInternals()
	local prefix = LookupLocalized("LOC_AWAWMM_GROUP_FILTER_PREFIX")
	if prefix == nil then
		prefix = "LOC_AWAWMM_GROUP_FILTER_PREFIX"
	end
	local budget = AWAWMM_TOOLBAR.W.GROUPFILTER - AWAWMM_TOOLBAR.PAD_PULLDOWN
	local display
	if g_GroupFilter == nil then
		local all = LookupLocalized("LOC_AWAWMM_GROUP_FILTER_ALL")
		if all == nil then
			all = "LOC_AWAWMM_GROUP_FILTER_ALL"
		end
		display = tostring(prefix) .. tostring(all)
	else
		local suffix = GroupCountSuffix(AWAWMM.CountModsInGroup(g_GroupMembers, g_GroupFilter))
		local nameBudget = budget - AWAWMM_TOOLBAR.Measure(tostring(prefix), true)
			- AWAWMM_TOOLBAR.Measure(suffix, true)
		if nameBudget < 1 then
			nameBudget = 1
		end
		display = tostring(prefix)
			.. AWAWMM_TOOLBAR.Fit(tostring(g_GroupFilter), nameBudget, true) .. suffix
	end
	combo:GetButton():SetText(display)
	AWAWMM_TOOLBAR.FitControl(combo:GetButton(), budget, true)
	local target = g_GroupFilter
	local hasTarget = (target ~= nil and AWAWMM.HasGroup(g_Groups, target))
	Controls.AWAWMMGroupRenameButton:SetDisabled(not hasTarget)
	Controls.AWAWMMGroupDeleteButton:SetDisabled(not hasTarget)
	local renameTip = LookupLocalized("LOC_AWAWMM_GROUP_RENAME_BUTTON_TOOLTIP")
	local deleteTip = LookupLocalized("LOC_AWAWMM_GROUP_DELETE_BUTTON_TOOLTIP")
	if hasTarget then
		if renameTip ~= nil then
			Controls.AWAWMMGroupRenameButton:SetToolTipString(renameTip)
		end
		if deleteTip ~= nil then
			Controls.AWAWMMGroupDeleteButton:SetToolTipString(deleteTip)
		end
	else
		Controls.AWAWMMGroupRenameButton:SetToolTipString(
			Locale.Lookup("LOC_AWAWMM_TIP_GROUP_PICK_TARGET"))
		Controls.AWAWMMGroupDeleteButton:SetToolTipString(
			Locale.Lookup("LOC_AWAWMM_TIP_GROUP_PICK_TARGET"))
	end
	AWAWMM_TOOLBAR.Layout()
end
function RefreshLocalizedText()
	g_LocaleMissKeys = 0
	g_SearchPlaceholder = nil
	g_AliasPlaceholder  = nil
	AWAWMM_ApplyRowMetrics()
	AWAWMM_TOOLBAR.ApplyFilterChips()
	RefreshCustomGroupFilterPullDown()
	if g_SelectedModHandle ~= nil then
		RefreshDetailGroupPullDown()
	end
	if Controls.SortListingsPullDown ~= nil then
		local sortBtn = Controls.SortListingsPullDown:GetButton()
		if sortBtn ~= nil then
			for i = 1, #SORT_OPTIONS do
				if SORT_OPTIONS[i].Mode == g_SortMode then
					sortBtn:LocalizeAndSetText(SORT_OPTIONS[i].Label)
				end
			end
		end
		AWAWMM_TOOLBAR.FitPulldownButton(Controls.SortListingsPullDown, AWAWMM_TOOLBAR.W.SORT,
			AWAWMM_TOOLBAR.PAD_SORT)
	end
	AWAWMM_TOOLBAR.Layout()
	if Controls.SearchEditBox ~= nil then
		if Controls.SearchEditBox:GetText() == "LOC_AWAWMM_SEARCH_PLACEHOLDER" then
			Controls.SearchEditBox:SetText(SearchPlaceholder())
		end
	end
	if Controls.AWAWMMDetailAliasEditBox ~= nil then
		if Controls.AWAWMMDetailAliasEditBox:GetText() == "LOC_AWAWMM_ALIAS_HINT" then
			Controls.AWAWMMDetailAliasEditBox:SetText(AliasPlaceholder())
		end
	end
	if g_LocaleMissKeys == 0 then
		g_LocalePending   = false
		g_LocaleRetryLeft = 0
		if g_ModExtras ~= nil then
			g_ExtrasDirty = true
			RefreshListings()
		end
		if not g_LocaleReadyLogged then
			g_LocaleReadyLogged = true
		end
	else
	end
end
AWAWMM_FillSubIdsStep = function()
	local q = AWAWMM_SubIdQueue
	if q == nil or q.done then
		return true
	end
	local cache = AWAWMM_SubIds
	if cache == nil then
		cache = {}
		AWAWMM_SubIds = cache
	end
	local n = 0
	while q.i <= #q.items and n < SUBID_FILL_PER_FRAME do
		local item = q.items[q.i]
		q.i = q.i + 1
		n = n + 1
		if item.key ~= nil and cache[item.key] == nil then
			local sub = nil
			local info = Modding.GetModInfo(item.handle)
			if info ~= nil then
				sub = info.SubscriptionId
			end
			cache[item.key] = (sub ~= nil) and sub or false
			q.newly = (q.newly or 0) + 1
			local extra = (g_ModExtras ~= nil) and g_ModExtras[item.handle] or nil
			if extra ~= nil then
				extra.SubscriptionId = sub
				extra.SubIdKnown = true
				if sub ~= nil and g_SortMode == "UPDATED"
					and extra.UpdatedFetched ~= true then
					local details = Modding.GetSubscriptionDetails(sub)
					if details ~= nil then
						extra.Updated = details.LastUpdated
					end
					extra.UpdatedFetched = true
				end
			end
			AWAWMM_ApplyRowState(item.handle)
		end
	end
	if q.i > #q.items then
		q.done = true
		return true
	end
	return false
end
AWAWMM_FinishSubIdFill = function()
	local q = AWAWMM_SubIdQueue
	local n = (q ~= nil) and (q.total or 0) or 0
	local newly = (q ~= nil) and (q.newly or 0) or 0
	local resort = false
	if newly > 0 then
		if g_SortMode == "UPDATED" or g_SortMode == "SUBSCRIPTION" then
			resort = true
		elseif AWAWMM.Has(g_Filters, AWAWMM.FilterKeys.Workshop)
			or AWAWMM.Has(g_Filters, AWAWMM.FilterKeys.Local) then
			resort = true
		elseif AWAWMM.Has(g_Filters, AWAWMM.FilterKeys.ShowAll)
			or AWAWMM.Has(g_Filters, AWAWMM.FilterKeys.Favorite)
			or AWAWMM.Has(g_Filters, AWAWMM.FilterKeys.OnlyEnabled) then
			resort = true
		end
		if AWAWMM_IsAllDigits(g_SearchQuery) then
			resort = true
		end
	end
	if resort then
		RefreshListings()
	end
end
AWAWMM_SearchPending   = false
AWAWMM_SearchWait      = 0
AWAWMM_SEARCH_DEBOUNCE = 0.25
function OnFrame(fdTime)
	if g_LocalePending then
		g_LocaleRetryWait = g_LocaleRetryWait - (tonumber(fdTime) or 0)
		if g_LocaleRetryWait <= 0 then
			g_LocaleRetryWait = LOCALE_RETRY_INTERVAL
			g_LocaleRetryLeft = g_LocaleRetryLeft - 1
			if g_LocaleRetryLeft == LOCALE_KICK_AT then
				AWAWMM.LocaleKickEnabledMods()
			end
			if g_LocaleRetryLeft <= 0 then
				g_LocalePending = false
			else
				RefreshLocalizedText()
			end
		end
	end
	local q = AWAWMM_SubIdQueue
	if q ~= nil and not q.done then
		if AWAWMM_FillSubIdsStep() then
			AWAWMM_FinishSubIdFill()
		end
	end
	if AWAWMM_SearchPending then
		AWAWMM_SearchWait = AWAWMM_SearchWait - (tonumber(fdTime) or 0)
		if AWAWMM_SearchWait <= 0 then
			AWAWMM_SearchPending = false
			AWAWMM_SearchWait = 0
			RefreshListings(true)
		end
	end
	if AWAWMM_RefocusPending ~= nil then
		local ctrl = AWAWMM_RefocusPending
		AWAWMM_RefocusPending = nil
		if ctrl ~= nil and ctrl.TakeFocus ~= nil and ctrl:IsVisible() then
			ctrl:TakeFocus()
		end
	end
	local fillDone = (AWAWMM_SubIdQueue == nil or AWAWMM_SubIdQueue.done == true)
	if (not g_LocalePending) and fillDone and (not AWAWMM_SearchPending) and AWAWMM_RefocusPending == nil then
		if ContextPtr.ClearUpdate ~= nil then
			ContextPtr:ClearUpdate()
		end
	end
end
ArmSubIdFill = function()
	local q = AWAWMM_SubIdQueue
	if q == nil or q.done then
		return
	end
	if ContextPtr.SetUpdate ~= nil then
		ContextPtr:SetUpdate(OnFrame)
	end
end
ArmLocaleRetry = function()
	if g_LocaleRetryLeft <= 0 then
		g_LocaleRetryLeft = LOCALE_RETRY_ATTEMPTS
		g_LocaleRetryWait = LOCALE_RETRY_INTERVAL
	end
	if ContextPtr.SetUpdate ~= nil then
		ContextPtr:SetUpdate(OnFrame)
	end
end
function ToggleModCustomGroup(modId, groupName)
	if modId == nil then
		return
	end
	if not AWAWMM.HasGroup(g_Groups, groupName) then
		return
	end
	local now = AWAWMM.ToggleModGroup(g_GroupMembers, modId, groupName)
	AWAWMM.SaveGroupMembers(g_GroupMembers)
	RefreshCustomGroupFilterPullDown()
	RefreshListings()
end
function ClearModCustomGroups(modId)
	if modId == nil then
		return
	end
	local removed = AWAWMM.RemoveModFromAllGroups(g_GroupMembers, modId)
	if removed == 0 then
		return
	end
	AWAWMM.SaveGroupMembers(g_GroupMembers)
	RefreshCustomGroupFilterPullDown()
	RefreshListings()
end
function CommitCustomGroup(raw)
	local ok, nameOrReason = AWAWMM.AddGroup(g_Groups, raw)
	if not ok then
		local reasonKey = "LOC_AWAWMM_GROUP_INVALID"
		if nameOrReason == "duplicate" then
			reasonKey = "LOC_AWAWMM_GROUP_DUPLICATE"
		elseif nameOrReason == "reserved" then
			reasonKey = "LOC_AWAWMM_GROUP_RESERVED"
		end
		AWAWMM_ShowGroupError(reasonKey)
		return
	end
	local name = nameOrReason
	AWAWMM.SaveGroups(g_Groups)
	local modId = SelectedModId()
	if modId ~= nil then
		AWAWMM.AddModToGroup(g_GroupMembers, modId, name)
		AWAWMM.SaveGroupMembers(g_GroupMembers)
	end
	Controls.NameModGroupPopup:SetHide(true)
	RefreshCustomGroupFilterPullDown()
	RefreshListings()
end
function OpenCustomGroupPopup()
	g_GroupPopupMode = "customgroup"
	Controls.BindingTitle:LocalizeAndSetText("LOC_AWAWMM_GROUP_NEW_TITLE")
	Controls.ModGroupEditBox:SetText("")
	AWAWMM_SetDisabledWithReason(Controls.CreateModGroupButton, true,
		"LOC_AWAWMM_TIP_GROUP_NAME_EMPTY", nil)
	AWAWMM_ShowGroupError("LOC_AWAWMM_TIP_GROUP_NAME_EMPTY")
	Controls.NameModGroupPopup:SetHide(false)
	Controls.NameModGroupPopupAlpha:SetToBeginning()
	Controls.NameModGroupPopupAlpha:Play()
	Controls.NameModGroupPopupSlide:SetToBeginning()
	Controls.NameModGroupPopupSlide:Play()
	Controls.ModGroupEditBox:TakeFocus()
end
function OpenRenameGroupPopup(name)
	if name == nil then
		return
	end
	g_GroupPopupMode = "renamegroup"
	g_RenameGroupFrom = name
	Controls.BindingTitle:LocalizeAndSetText("LOC_AWAWMM_GROUP_RENAME_TITLE")
	Controls.ModGroupEditBox:SetText(name)
	Controls.CreateModGroupButton:SetDisabled(false)
	AWAWMM_ClearGroupError()
	Controls.NameModGroupPopup:SetHide(false)
	Controls.NameModGroupPopupAlpha:SetToBeginning()
	Controls.NameModGroupPopupAlpha:Play()
	Controls.NameModGroupPopupSlide:SetToBeginning()
	Controls.NameModGroupPopupSlide:Play()
	Controls.ModGroupEditBox:TakeFocus()
end
function CommitRenameGroup(raw)
	local from = g_RenameGroupFrom
	local ok, nameOrReason = AWAWMM.RenameGroup(g_Groups, g_GroupMembers, from, raw)
	if not ok then
		local reasonKey = "LOC_AWAWMM_GROUP_INVALID"
		if nameOrReason == "duplicate" then
			reasonKey = "LOC_AWAWMM_GROUP_DUPLICATE"
		elseif nameOrReason == "reserved" then
			reasonKey = "LOC_AWAWMM_GROUP_RESERVED"
		end
		AWAWMM_ShowGroupError(reasonKey)
		return
	end
	local newName = nameOrReason
	AWAWMM.SaveGroups(g_Groups)
	AWAWMM.SaveGroupMembers(g_GroupMembers)
	if g_GroupFilter == from then
		g_GroupFilter = newName
	end
	Controls.NameModGroupPopup:SetHide(true)
	RefreshCustomGroupFilterPullDown()
	RefreshListings()
end
function RequestDeleteGroup(name)
	if name == nil then
		return
	end
	local count = AWAWMM.CountModsInGroup(g_GroupMembers, name)
	OpenConfirmPopup(
		Locale.Lookup("LOC_AWAWMM_GROUP_DELETE_TITLE"),
		Locale.Lookup((count == 1) and "LOC_AWAWMM_GROUP_DELETE_CONFIRM_ONE"
			or "LOC_AWAWMM_GROUP_DELETE_CONFIRM", count),
		nil, Locale.Lookup("LOC_OK"),
		function()
			local ok = AWAWMM.RemoveGroup(g_Groups, g_GroupMembers, name)
			if ok then
				AWAWMM.SaveGroups(g_Groups)
				AWAWMM.SaveGroupMembers(g_GroupMembers)
				if g_GroupFilter == name then
					g_GroupFilter = nil
				end
			end
			RefreshCustomGroupFilterPullDown()
			RefreshListings()
		end)
end
function CommitGroupPopup()
	local raw = Controls.ModGroupEditBox:GetText()
	if raw == nil or #raw == 0 then
		return
	end
	if g_GroupPopupMode == "customgroup" then
		CommitCustomGroup(raw)
		return
	end
	if g_GroupPopupMode == "renamegroup" then
		CommitRenameGroup(raw)
		return
	end
	Controls.NameModGroupPopup:SetHide(true)
	Modding.CreateModGroup(raw, Modding.GetCurrentModGroup())
	RefreshModGroups()
	RefreshListings()
end
RefreshDetailGroupPullDown = function()
	local combo = Controls.AWAWMMDetailGroupPullDown
	if combo == nil then
		return
	end
	AWAWMM_TOOLBAR.ApplyWidths()
	local itemW = AWAWMM_TOOLBAR.W.DETAIL - AWAWMM_TOOLBAR.ITEM_INSET
	combo:SetSizeX(AWAWMM_TOOLBAR.W.DETAIL)
	combo:GetButton():SetSizeX(AWAWMM_TOOLBAR.W.DETAIL)
	AWAWMM_TOOLBAR.SyncPopupWidth(combo, AWAWMM_TOOLBAR.W.DETAIL)
	local modId = SelectedModId()
	combo:ClearEntries()
	local mine = {}
	if modId ~= nil then
		mine = AWAWMM.GetModGroups(g_GroupMembers, modId)
	end
	local names = AWAWMM.GetGroups(g_Groups)
	table.sort(names, function(a, b) return Locale.Compare(a, b) == -1 end)
	for i = 1, #names do
		local name = names[i]
		local member = (modId ~= nil and AWAWMM.IsModInGroup(g_GroupMembers, modId, name))
		local entry = {}
		combo:BuildEntry("InstanceOne", entry)
		entry.Button:SetSizeX(itemW)
		local mark = (member and GROUP_CHECK_PREFIX or "")
		local nameBudget = itemW - AWAWMM_TOOLBAR.ITEM_PAD
			- AWAWMM_TOOLBAR.Measure(mark, true)
		if nameBudget < 1 then
			nameBudget = 1
		end
		entry.Button:SetText(mark .. AWAWMM_TOOLBAR.Fit(tostring(name), nameBudget, true))
		entry.Button:SetToolTipString(Locale.Lookup("LOC_AWAWMM_GROUP_TOGGLE_TOOLTIP"))
		ClearClick(entry.Button, Mouse.eLClick)
		entry.Button:RegisterCallback(Mouse.eLClick, function()
			ToggleModCustomGroup(modId, name)
		end)
	end
	local newEntry = {}
	combo:BuildEntry("InstanceOne", newEntry)
	newEntry.Button:SetSizeX(itemW)
	SetEntryLocalizedText(newEntry.Button, "LOC_AWAWMM_GROUP_NEW")
	newEntry.Button:SetToolTipString(Locale.Lookup("LOC_AWAWMM_GROUP_NEW_TOOLTIP"))
	ClearClick(newEntry.Button, Mouse.eLClick)
	newEntry.Button:RegisterCallback(Mouse.eLClick, function()
		OpenCustomGroupPopup()
	end)
	local clearEntry = {}
	combo:BuildEntry("InstanceOne", clearEntry)
	clearEntry.Button:SetSizeX(itemW)
	SetEntryLocalizedText(clearEntry.Button, "LOC_AWAWMM_GROUP_CLEAR_ALL")
	clearEntry.Button:SetToolTipString(Locale.Lookup("LOC_AWAWMM_GROUP_CLEAR_ALL_TOOLTIP"))
	AWAWMM_SetDisabledWithReason(clearEntry.Button, (#mine == 0),
		"LOC_AWAWMM_TIP_MOD_NO_GROUP", "LOC_AWAWMM_GROUP_CLEAR_ALL_TOOLTIP")
	ClearClick(clearEntry.Button, Mouse.eLClick)
	clearEntry.Button:RegisterCallback(Mouse.eLClick, function()
		ClearModCustomGroups(modId)
	end)
	combo:CalculateInternals()
	local label
	if #mine == 0 then
		label = Locale.Lookup("LOC_AWAWMM_GROUP_NONE")
	else
		label = table.concat(mine, ", ")
	end
	combo:GetButton():SetText(label)
	AWAWMM_TOOLBAR.FitControl(combo:GetButton(), AWAWMM_TOOLBAR.W.DETAIL - AWAWMM_TOOLBAR.PAD_DETAIL, true)
end
function InitializeSortListingsPulldown()
	local sortByPulldown = Controls.SortListingsPullDown
	AWAWMM_TOOLBAR.ApplyWidths()
	local itemW = AWAWMM_TOOLBAR.W.ITEM_SORT
	sortByPulldown:ClearEntries()
	for i = 1, #SORT_OPTIONS do
		local option = SORT_OPTIONS[i]
		local controlTable = {}
		sortByPulldown:BuildEntry("InstanceOne", controlTable)
		controlTable.Button:SetSizeX(itemW)
		controlTable.Button:LocalizeAndSetText(option.Label)
		ClearClick(controlTable.Button, Mouse.eLClick)
		controlTable.Button:RegisterCallback(Mouse.eLClick, function()
			sortByPulldown:GetButton():LocalizeAndSetText(option.Label)
			AWAWMM_TOOLBAR.FitPulldownButton(sortByPulldown, AWAWMM_TOOLBAR.W.SORT,
				AWAWMM_TOOLBAR.PAD_SORT)
			g_SortMode = option.Mode
			AWAWMM.SaveSortMode(g_SortMode)
			if option.Mode == "UPDATED" then
				g_ExtrasDirty = true
			end
			if SORT_DEFAULT_ASC[option.Mode] ~= nil then
				g_SortAsc = SORT_DEFAULT_ASC[option.Mode]
				AWAWMM.SaveSortAsc(g_SortAsc)
				UpdateSortOrderButton()
			end
			RefreshListings()
		end)
	end
	sortByPulldown:CalculateInternals()
	local initial = SORT_OPTIONS[1]
	for i = 1, #SORT_OPTIONS do
		if SORT_OPTIONS[i].Mode == g_SortMode then
			initial = SORT_OPTIONS[i]
		end
	end
	sortByPulldown:GetButton():LocalizeAndSetText(initial.Label)
	AWAWMM_TOOLBAR.FitPulldownButton(sortByPulldown, AWAWMM_TOOLBAR.W.SORT,
		AWAWMM_TOOLBAR.PAD_SORT)
	AWAWMM_TOOLBAR.Layout()
end
UpdateSortOrderButton = function()
	Controls.AWAWMMSortAscIcon:SetHide(not g_SortAsc)
	Controls.AWAWMMSortDescIcon:SetHide(g_SortAsc)
	Controls.AWAWMMSortOrderToggle:SetToolTipString(
		Locale.Lookup(g_SortAsc and "LOC_AWAWMM_SORT_ORDER_TOOLTIP_ASC"
			or "LOC_AWAWMM_SORT_ORDER_TOOLTIP_DESC"))
end
local FILTER_CHIPS = {
	{ Control = "AWAWMMFilterShowAll",         Key = AWAWMM.FilterKeys.ShowAll,         Override = true },
	{ Control = "AWAWMMFilterFavorite",        Key = AWAWMM.FilterKeys.Favorite,        Override = true },
	{ Control = "AWAWMMFilterOnlyEnabled",     Key = AWAWMM.FilterKeys.OnlyEnabled,     Override = true },
	{ Control = "ShowOfficialContent",         Key = AWAWMM.FilterKeys.Official },
	{ Control = "AWAWMMFilterWorkshop",        Key = AWAWMM.FilterKeys.Workshop },
	{ Control = "AWAWMMFilterLocal",           Key = AWAWMM.FilterKeys.Local },
	{ Control = "AWAWMMFilterSupportsMP",      Key = AWAWMM.FilterKeys.SupportsMP,
	  NormalTip = "LOC_AWAWMM_FILTER_SUPPORTS_MP_TT" },
	{ Control = "AWAWMMFilterRulesetStandard", Key = AWAWMM.FilterKeys.RulesetStandard, Ruleset = true },
	{ Control = "AWAWMMFilterRulesetXP1",      Key = AWAWMM.FilterKeys.RulesetXP1,      Ruleset = true },
	{ Control = "AWAWMMFilterRulesetXP2",      Key = AWAWMM.FilterKeys.RulesetXP2,      Ruleset = true },
}
function RefreshFilterChips()
	local showAll = AWAWMM.Has(g_Filters, AWAWMM.FilterKeys.ShowAll)
	local favOnly = AWAWMM.Has(g_Filters, AWAWMM.FilterKeys.Favorite)
	local onlyOn = AWAWMM.Has(g_Filters, AWAWMM.FilterKeys.OnlyEnabled)
	local override = (showAll or favOnly or onlyOn)
	local ruleset = AWAWMM.GetRuleset(g_Filters)
	for i = 1, #FILTER_CHIPS do
		local chip = FILTER_CHIPS[i]
		local ctrl = Controls[chip.Control]
		if not (ctrl == nil) then
			if chip.Ruleset then
				ctrl:SetSelected(chip.Key == ruleset)
			else
				ctrl:SetSelected(AWAWMM.Has(g_Filters, chip.Key))
			end
			if chip.Override then
				ctrl:SetDisabled(false)
			else
				AWAWMM_SetDisabledWithReason(ctrl, override, "LOC_AWAWMM_TIP_FILTER_OVERRIDE", chip.NormalTip)
			end
		end
	end
end
function SetExclusiveOverride(key)
	if g_Filters[key] == true then
		g_Filters[key] = nil
		return 0, true
	end
	local cleared = 0
	for i = 1, #FILTER_CHIPS do
		local other = FILTER_CHIPS[i]
		if other.Override and other.Key ~= key and g_Filters[other.Key] == true then
			g_Filters[other.Key] = nil
			cleared = cleared + 1
		end
	end
	g_Filters[key] = true
	return cleared, false
end
function OnFilterChipClicked(chip)
	if g_Filters == nil then
		g_Filters = AWAWMM.ParseSet(AWAWMM.DefaultFilters)
	end
	local key = chip.Key
	if chip.Override then
		local cleared, turnedOff = SetExclusiveOverride(key)
	elseif chip.Ruleset then
		AWAWMM.SetRuleset(g_Filters, key)
	else
		AWAWMM.ToggleSet(g_Filters, key)
	end
	AWAWMM.SaveFilters(g_Filters)
	RefreshFilterChips()
	RefreshListings()
end
function CollectFilteredMods()
	local mods = AWAWMM_GetInstalledModsCached()
	if mods == nil or #mods == 0 then
		return nil, 0
	end
	EnsureExtras(mods)
	PreprocessListings(mods)
	local out = {}
	for i = 1, #mods do
		local v = mods[i]
		if PassesFilters(v) and PassesSearch(v) then
			out[#out + 1] = v
		end
	end
	return out, #mods
end
function DoEnableAll(mods)
	local enabled = 0
	for i = 1, #mods do
		local handle = mods[i].Handle
		local err = Modding.CanEnableMod(handle, true)
		local canEnable, why = AWAWMM_CanEnableGivenUnsubscribed(handle, err)
		if canEnable then
			Modding.EnableMod(handle, true)
			enabled = enabled + 1
		end
	end
	if enabled > 0 then
		CommitEnabledModsToEngine()
	end
	AWAWMM_InvalidateModsCache()
	RefreshListings()
end
function DoDisableAll(mods)
	local handles = {}
	local function CountEnabled(list)
		local n = 0
		for i = 1, #list do
			if list[i].Enabled == true then
				n = n + 1
			end
		end
		return n
	end
	local selfSkipped = false
	for i = 1, #mods do
		if IsSelfMod(mods[i].Handle) then
			selfSkipped = true
		else
			handles[#handles + 1] = mods[i].Handle
		end
	end
	local before = CountEnabled(mods)
	if selfSkipped then
		before = before - 1
		if before < 0 then
			before = 0
		end
	end
	if #handles > 0 then
		Modding.DisableMod(handles)
	end
	AWAWMM_InvalidateModsCache()
	local after = 0
	if #handles > 0 then
		local want = {}
		for i = 1, #handles do
			want[tostring(handles[i])] = true
		end
		local fresh = AWAWMM_GetInstalledModsCached()
		if fresh ~= nil then
			for i = 1, #fresh do
				if fresh[i].Enabled == true and want[tostring(fresh[i].Handle)] == true then
					after = after + 1
				end
			end
		end
	end
	local disabled = before - after
	if disabled < 0 then
		disabled = 0
	end
	if disabled > 0 then
		CommitEnabledModsToEngine()
	end
	RefreshListings()
end
function ConfirmBatch(kind, mods, total)
	local n = #mods
	local hasIncompatible = false
	if kind == "enable" and Modding.ShouldShowCompatibilityWarnings() then
		for i = 1, #mods do
			if not Modding.IsModCompatible(mods[i].Handle) then
				hasIncompatible = true
				break
			end
		end
	end
	local missingDeps = nil
	local selfUnsub = nil
	if kind == "enable" then
		local seen = {}
		local names = {}
		local selfNames = {}
		local installed = {}
		local noValue = tostring(Locale.Lookup("LOC_AWAWMM_NO_VALUE"))
		for i = 1, #mods do
			if mods[i].Enabled ~= true then
				local selfId = mods[i].Id
				local selfKey = (selfId ~= nil and selfId ~= "")
					and string.lower(tostring(selfId)) or nil
				local selfListed = false
				if selfKey ~= nil and seen[selfKey] == nil and AWAWMM_IsUnsubscribed(selfId) then
					seen[selfKey] = true
					selfListed = true
					local s = ResolveLocName(mods[i].Name)
					s = (s ~= nil) and tostring(s) or ""
					if s == "" or s == noValue then
						s = tostring(selfId)
					end
					selfNames[#selfNames + 1] = s
				end
				local assoc = nil
				if not selfListed then
					assoc = Modding.GetModAssociations(mods[i].Handle)
				end
				if assoc ~= nil then
					for j = 1, #assoc do
						local dep = assoc[j]
						if dep ~= nil and dep.Id ~= nil and dep.Id ~= "" then
							local key = tostring(dep.Id)
							if seen[key] == nil then
								local have = installed[key]
								if have == nil then
									have = (Modding.GetModHandle(dep.Id) ~= nil)
									installed[key] = have
								end
								if not have or AWAWMM_IsUnsubscribed(dep.Id) then
									seen[key] = true
									local nm = ResolveAssociationName(mods[i].Handle, dep)
									local s = (nm ~= nil) and tostring(nm) or ""
									if s == "" or s == noValue then
										s = key
									end
									names[#names + 1] = s
								end
							end
						end
					end
				end
			end
		end
		if #names > 0 then
			missingDeps = names
		end
		if #selfNames > 0 then
			selfUnsub = selfNames
		end
	end
	local allNames = nil
	if missingDeps ~= nil or selfUnsub ~= nil then
		allNames = {}
		if missingDeps ~= nil then
			for i = 1, #missingDeps do
				allNames[#allNames + 1] = missingDeps[i]
			end
		end
		if selfUnsub ~= nil then
			for i = 1, #selfUnsub do
				allNames[#allNames + 1] = selfUnsub[i]
			end
		end
	end
	local function Run()
		if kind ~= "enable" then
			DoDisableAll(mods)
			return
		end
		DoEnableAll(mods)
	end
	if n == total and not hasIncompatible and allNames == nil then
		Run()
		return
	end
	local title = Locale.Lookup("LOC_AWAWMM_CONFIRM_TITLE_BATCH")
	local bodyKey
	if kind == "enable" then
		bodyKey = (n == 1) and "LOC_AWAWMM_CONFIRM_BATCH_ENABLE_ONE"
			or "LOC_AWAWMM_CONFIRM_BATCH_ENABLE"
	else
		bodyKey = (n == 1) and "LOC_AWAWMM_CONFIRM_BATCH_DISABLE_ONE"
			or "LOC_AWAWMM_CONFIRM_BATCH_DISABLE"
	end
	local body = Locale.Lookup(bodyKey, n)
	if hasIncompatible then
		body = body .. "[NEWLINE]"
			.. Locale.Lookup("LOC_MODS_ENABLE_WARNING_NOT_COMPATIBLE_MANY")
	end
	if missingDeps ~= nil then
		body = body .. "[NEWLINE]" .. Locale.Lookup("LOC_MODS_ERROR_SAVE_MISSING_MODS")
	end
	if selfUnsub ~= nil then
		body = body .. "[NEWLINE]" .. Locale.Lookup("LOC_AWAWMM_ENABLE_NEEDS_SUBSCRIPTION")
	end
	OpenConfirmPopup(title, body, allNames, Locale.Lookup("LOC_OK"), Run)
end
function OnEnableAll()
	local mods, total = CollectFilteredMods()
	if mods == nil or #mods == 0 then
		return
	end
	ConfirmBatch("enable", mods, total)
end
function OnDisableAll()
	local mods, total = CollectFilteredMods()
	if mods == nil or #mods == 0 then
		return
	end
	ConfirmBatch("disable", mods, total)
end
function DoCleanupOrphans()
	local mods = AWAWMM_GetInstalledModsCached()
	if mods == nil or #mods == 0 then
		return
	end
	local known = {}
	EnsureExtras(mods)
	for i = 1, #mods do
		local id = GetModId(mods[i].Handle)
		if id ~= nil then
			known[id] = true
		end
	end
	local removed = 0
	removed = removed + AWAWMM.RemoveMissing(g_Favorites, known)
	removed = removed + AWAWMM.PruneAliases(g_Aliases, known)
	removed = removed + AWAWMM.PruneGroupMembers(g_GroupMembers, known)
	AWAWMM.SaveFavorites(g_Favorites)
	AWAWMM.SaveAliases(g_Aliases)
	AWAWMM.SaveGroupMembers(g_GroupMembers)
	if g_SelectedModHandle ~= nil then
		local selectedId = GetModId(g_SelectedModHandle)
		if selectedId == nil or Modding.GetModHandle(selectedId) == nil then
			g_SelectedModHandle = nil
		end
	end
	RefreshCustomGroupFilterPullDown()
	RefreshListings()
end
function OnCleanupOrphans()
	OpenConfirmPopup(
		Locale.Lookup("LOC_AWAWMM_CONFIRM_TITLE_CLEANUP"),
		Locale.Lookup("LOC_AWAWMM_CONFIRM_CLEANUP"),
		nil, Locale.Lookup("LOC_OK"), DoCleanupOrphans)
end
AWAWMM_DoDeleteManagerConfig = function()
	Log("deletecfg", "delete manager config: reset memory first, then delete files")
	AWAWMM_Data.ResetCustomStateToDefaults()
	AWAWMM_Data.DeleteOurGroups()
	LoadAllState()
	RefreshFilterChips()
	UpdateSortOrderButton()
	Controls.AWAWMMGroupByAuthorToggle:SetCheck(g_GroupByAuthor)
	RefreshCustomGroupFilterPullDown()
	RefreshModGroups()
	RefreshListings()
	RefreshModDetails()
	RefreshDetailGroupPullDown()
	local ok = AWAWMM_Data.DeleteConfigArchives(function(count)
	end)
	if ok ~= true then
		Log("deletecfg", "delete manager config files not deleted (API missing)")
	end
end
AWAWMM_OnDeleteManagerConfigClick = function()
	OpenConfirmPopup(
		Locale.Lookup("LOC_AWAWMM_CONFIRM_TITLE_DELETE_CONFIG"),
		Locale.Lookup("LOC_AWAWMM_CONFIRM_DELETE_CONFIG"),
		nil, Locale.Lookup("LOC_OK"), AWAWMM_DoDeleteManagerConfig)
end
ConfirmUnsubscribe = function(modHandle, subscriptionId)
	local err = Modding.CanDisableMod(modHandle)
	local order = nil
	local function HandleName(h)
		local extra = (g_ModExtras ~= nil) and g_ModExtras[h] or nil
		local nm = (extra ~= nil) and extra.DisplayName or nil
		if nm == nil then
			local info = Modding.GetModInfo(h)
			if info ~= nil then
				nm = ResolveLocName(info.Name)
			end
		end
		return tostring(nm or h)
	end
	if err == "OwnershipRequired" then
		OpenConfirmPopup(
			Locale.Lookup("LOC_AWAWMM_CONFIRM_TITLE_DISABLE_CASCADE"),
			Locale.Lookup("LOC_AWAWMM_DISABLE_CASCADE_FAILED") .. HandleName(modHandle),
			nil, Locale.Lookup("LOC_OK"), function() end)
		return
	end
	if err == "MissingDependencies" then
		order = BuildCascadeOrder(modHandle)
		if order == nil then
			OpenConfirmPopup(
				Locale.Lookup("LOC_AWAWMM_CONFIRM_TITLE_DISABLE_CASCADE"),
				Locale.Lookup("LOC_AWAWMM_DISABLE_CASCADE_FAILED") .. HandleName(modHandle),
				nil, Locale.Lookup("LOC_OK"), function() end)
			return
		end
	end
	local rootId = GetModId(modHandle)
	if rootId == nil then
		local rootInfo = Modding.GetModInfo(modHandle)
		rootId = (rootInfo ~= nil) and rootInfo.Id or nil
	end
	local dependents = AWAWMM_GetDependents(rootId)
	local names = {}
	local depHandles = {}
	if dependents ~= nil then
		for i = 1, #dependents do
			local d = dependents[i]
			if d ~= nil and d.Handle ~= nil and not AWAWMM_IsUnsubscribed(d.Id) then
				depHandles[#depHandles + 1] = d.Handle
				names[#names + 1] = HandleName(d.Handle)
			end
		end
	end
	local body = Locale.Lookup("LOC_AWAWMM_CONFIRM_UNSUBSCRIBE")
	if #names > 0 then
		body = body .. "[NEWLINE]" .. Locale.Lookup("LOC_AWAWMM_UNSUBSCRIBE_BREAKS_DEPENDENTS")
	end
	if IsSelfMod(modHandle) and #names > 0 then
		for i = 1, #names do
			body = body .. "[NEWLINE][ICON_BULLET] " .. tostring(names[i])
		end
	end
	local RunUnsubscribe = function()
			local disableOrder = {}
			local seenDisable = {}
			local function AddDisable(h)
				if h == nil then
					return
				end
				local k = tostring(h)
				if seenDisable[k] == nil then
					seenDisable[k] = true
					disableOrder[#disableOrder + 1] = h
				end
			end
			if order ~= nil then
				for i = 1, #order do
					if order[i] ~= modHandle then
						AddDisable(order[i])
					end
				end
			end
			local enabledHandles = {}
			local live = AWAWMM_GetInstalledModsCached(true)
			if live ~= nil then
				for i = 1, #live do
					if live[i].Enabled == true and live[i].Handle ~= nil then
						enabledHandles[tostring(live[i].Handle)] = true
					end
				end
			end
			for i = 1, #depHandles do
				if enabledHandles[tostring(depHandles[i])] == true then
					AddDisable(depHandles[i])
				end
			end
			AddDisable(modHandle)
			Modding.DisableMod(disableOrder)
			AWAWMM_InvalidateModsCache()
			local rootEnabled = false
			local fresh = AWAWMM_GetInstalledModsCached()
			if fresh ~= nil then
				for i = 1, #fresh do
					if fresh[i].Handle == modHandle then
						rootEnabled = (fresh[i].Enabled == true)
					end
				end
			end
			if rootEnabled then
				OpenConfirmPopup(
					Locale.Lookup("LOC_MODS_UNSUBSCRIBE"),
					Locale.Lookup("LOC_AWAWMM_DISABLE_CASCADE_FAILED") .. HandleName(modHandle),
					nil, Locale.Lookup("LOC_OK"), function() end)
				return
			end
			Modding.Unsubscribe(tonumber(subscriptionId))
			AWAWMM_RefreshSubsIndex()
			local rootId = GetModId(modHandle)
			if rootId == nil then
				local info = Modding.GetModInfo(modHandle)
				rootId = (info ~= nil) and info.Id or nil
			end
			AWAWMM_MarkUnsubscribedHidden(rootId)
			CommitEnabledModsToEngine()
			AWAWMM_ApplyRenderedRowStates()
			RefreshListings()
	end
	if IsSelfMod(modHandle) then
		AWAWMM_OpenSelfPopup(
			Locale.Lookup("LOC_MODS_UNSUBSCRIBE"),
			body,
			Locale.Lookup("LOC_AWAWMM_TIP_SELF_FRONTEND_UNSUBSCRIBE"),
			RunUnsubscribe)
	else
		OpenConfirmPopup(
			Locale.Lookup("LOC_MODS_UNSUBSCRIBE"),
			body,
			names,
			Locale.Lookup("LOC_OK"),
			RunUnsubscribe)
	end
end
function OnInstalledModsTabClick()
	Controls.InstalledTabPanel:SetHide(false)
	RefreshFilterChips()
	g_SearchQuery = nil
	g_SelectedModHandle = nil
	Controls.SearchEditBox:SetText(SearchPlaceholder())
	AWAWMM_SyncClearButton(Controls.AWAWMMSearchClearButton,
		Controls.SearchEditBox:GetText(), SearchPlaceholder())
	g_Groups = AWAWMM.LoadGroups()
	g_GroupMembers = AWAWMM.LoadGroupMembers()
	if AWAWMM_IsModsListReady() then
		AWAWMM.ReconcileGroups(g_Groups, g_GroupMembers)
	else
	end
	RefreshCustomGroupFilterPullDown()
	RefreshModGroups()
	RefreshListings()
end
AWAWMM_ReReadConfigArchive = function(reason)
	reason = tostring(reason or "unspecified")
	if AWAWMM.ShouldSkipArchiveRead() then
		AWAWMM_ApplyUnavailableForNoMirror("re-read-mp")
		return false
	end
	if AWAWMM_EnabledSetDirty then
		AWAWMM_FlushEnabledSetToEngine()
	end
	AWAWMM.ResetSawStoredKey()
	AWAWMM_ConfigFallbackTries = 0
	AWAWMM_ConfigReRead = true
	local ok = AWAWMM.LoadConfigArchive()
	if not ok then
		AWAWMM_ConfigReRead = false
		Log("store", "re-read request failed reason=" .. reason)
		return false
	end
	g_ConfigLoadPending = true
	AWAWMM.LoadFilters()
	AWAWMM_ConfigReReadAtRequest = AWAWMM.SawStoredKey()
	if AWAWMM_ConfigReReadAtRequest then
		AWAWMM_ConfigFallbackTries = 0
		g_ConfigLoadPending = false
		AWAWMM_ConfigReRead = false
		AWAWMM_HydrateStateFromArchive()
	else
	end
	return true
end
function HandleExitRequest()
	AWAWMM_FlushEnabledSetToEngine()
	UIManager:DequeuePopup(ContextPtr)
end
function OnShow()
	AWAWMM_FrontEntryCatchUp()
	if g_ShownThisCycle then
		return
	end
	g_ShownThisCycle = true
	if not AWAWMM_TryReadMirrorOnStartup("onshow") then
		AWAWMM_ReReadConfigArchive("onshow")
	end
	OnInstalledModsTabClick()
end
function OnHide()
	g_ShownThisCycle = false
	AWAWMM_RefocusPending = nil
	AWAWMM_FlushEnabledSetToEngine()
end
function PostInit()
	if not ContextPtr:IsHidden() then
		OnShow()
	end
end
function Resize()
	local screenX, screenY = UIManager:GetScreenSizeVal()
	local w = math.min(1350, screenX - 15)
	local h = math.min(748, screenY - 20)
	if w < 320 then w = 320 end
	if h < 240 then h = 240 end
	Controls.MainGrid:SetSizeVal(w, h)
	Controls.ModListingsStack:CalculateSize()
	Controls.ModListingsStack:ReprocessAnchoring()
	Controls.ModListings:CalculateInternalSize()
end
function OnUpdateUI(uiType, tag, iData1, iData2, strData1)
	if uiType == SystemUpdateUI.ScreenResize then
		Resize()
	end
end
function OnSearchBarGainFocus()
	if Controls.SearchEditBox:GetText() == SearchPlaceholder() then
		Controls.SearchEditBox:ClearString()
	end
end
function OnSearchBarLostFocus()
	local str = Controls.SearchEditBox:GetText()
	if str == nil or #str == 0 then
		Controls.SearchEditBox:SetText(SearchPlaceholder())
	end
end
function OnAliasEditGainFocus()
	Controls.AWAWMMAliasEditFrame:SetHide(true)
	Controls.AWAWMMAliasEditFrameFocus:SetHide(false)
	if Controls.AWAWMMDetailAliasEditBox:GetText() == AliasPlaceholder() then
		Controls.AWAWMMDetailAliasEditBox:ClearString()
	end
	AWAWMM_MarkCommitSeen("alias", Controls.AWAWMMDetailAliasEditBox)
end
function OnAliasEditLostFocus()
	Controls.AWAWMMAliasEditFrame:SetHide(false)
	Controls.AWAWMMAliasEditFrameFocus:SetHide(true)
	if AliasEditTextIsEmpty() then
		Controls.AWAWMMDetailAliasEditBox:SetText(AliasPlaceholder())
		AWAWMM_SetDisabledWithReason(Controls.AWAWMMDetailAliasApplyButton, true,
			"LOC_AWAWMM_TIP_ALIAS_EMPTY", nil)
		AWAWMM_SyncClearButton(Controls.AWAWMMAliasEditClearButton,
			Controls.AWAWMMDetailAliasEditBox:GetText(), AliasPlaceholder())
	end
end
local COMMIT_IME_WINDOW_MS = 200
local g_InputSeen = {}
AWAWMM_NowMs = function()
	if Automation ~= nil and type(Automation.GetTime) == "function" then
		return Automation.GetTime() * 1000
	end
	return nil
end
AWAWMM_NoteInputChange = function(key, ctrl)
	g_InputSeen[key] = { text = ctrl:GetText() or "", ms = AWAWMM_NowMs() }
end
AWAWMM_CommitFromIme = function(key, ctrl)
	local seen = g_InputSeen[key]
	local text = ctrl:GetText() or ""
	if seen == nil then
		if text ~= nil and #text > 0 then
			return true, nil, "no-notify"
		end
		return false, nil, "no-notify-empty"
	end
	local nowMs = AWAWMM_NowMs()
	local dt = nil
	if nowMs ~= nil and seen.ms ~= nil then
		dt = nowMs - seen.ms
	end
	if text ~= seen.text then
		return true, dt, "text-mismatch"
	end
	if dt ~= nil and dt <= COMMIT_IME_WINDOW_MS then
		return true, dt, "same-batch"
	end
	return false, dt, "normal"
end
AWAWMM_MarkCommitSeen = function(key, ctrl)
	g_InputSeen[key] = { text = ctrl:GetText() or "", ms = nil }
end
AWAWMM_RefocusNextFrame = function(ctrl)
	AWAWMM_RefocusPending = ctrl
	if ContextPtr.SetUpdate ~= nil then
		ContextPtr:SetUpdate(OnFrame)
	end
end
function OnSearchCharCallback()
	local str = Controls.SearchEditBox:GetText()
	AWAWMM_SyncClearButton(Controls.AWAWMMSearchClearButton, str, SearchPlaceholder())
	if str ~= nil and #str > 0 and str ~= SearchPlaceholder() then
		g_SearchQuery = str
	else
		g_SearchQuery = nil
	end
	AWAWMM_SearchPending = true
	AWAWMM_SearchWait    = AWAWMM_SEARCH_DEBOUNCE
	if ContextPtr.SetUpdate ~= nil then
		ContextPtr:SetUpdate(OnFrame)
	end
end
AWAWMM_FlushSearchFilter = function()
	AWAWMM_SearchPending = false
	AWAWMM_SearchWait    = 0
	RefreshListings(true)
end
function OnSearchClearClick()
	AWAWMM_ClearInputToPlaceholder(Controls.SearchEditBox, SearchPlaceholder(),
		Controls.AWAWMMSearchClearButton)
	g_SearchQuery = nil
	AWAWMM_FlushSearchFilter()
end
function InputHandler(uiMsg, wParam, lParam)
	if uiMsg == KeyEvents.KeyUp and wParam == Keys.VK_RETURN and AWAWMM_SearchPending then
		AWAWMM_FlushSearchFilter()
		return true
	end
	if uiMsg == KeyEvents.KeyUp and wParam == Keys.VK_ESCAPE then
		if Controls.AWAWMMSelfPopup ~= nil and Controls.AWAWMMSelfPopup:IsVisible() then
			AWAWMM_CloseSelfPopup()
			return true
		end
		if Controls.AWAWMMConfirmPopup ~= nil and Controls.AWAWMMConfirmPopup:IsVisible() then
			CloseConfirmPopup()
			return true
		end
		if Controls.NameModGroupPopup ~= nil and Controls.NameModGroupPopup:IsVisible() then
			Controls.NameModGroupPopup:SetHide(true)
			return true
		end
		HandleExitRequest()
		return true
	end
	return false
end
ContextPtr:SetInputHandler( InputHandler )
local g_ConfigLoadPending = false
local g_ConfigHydrated = false
local g_ConfigReadAtRequest = false
AWAWMM_ConfigReRead = false
AWAWMM_ConfigReReadAtRequest = false
AWAWMM_ConfigFallbackTries = 0
AWAWMM_CONFIG_FALLBACK_MAX_TRIES = 2
function OnConfigArchiveLoaded(eResult, eType, eOptions, eFileType)
	if eFileType ~= nil and SaveFileTypes ~= nil
		and eFileType ~= SaveFileTypes.GAME_CONFIGURATION then
		return
	end
	if AWAWMM.ShouldSkipArchiveRead() then
		return
	end
	if AWAWMM_ConfigReRead then
		AWAWMM_ConfigReRead = false
		if AWAWMM.SawStoredKey() then
			AWAWMM_ConfigFallbackTries = 0
			AWAWMM_HydrateStateFromArchive()
		elseif AWAWMM_ConfigFallbackTries < AWAWMM_CONFIG_FALLBACK_MAX_TRIES
			and AWAWMM.LoadConfigArchiveFallback() then
			AWAWMM_ConfigFallbackTries = AWAWMM_ConfigFallbackTries + 1
			AWAWMM.LoadFilters()
			AWAWMM_ConfigReReadAtRequest = AWAWMM.SawStoredKey()
			if AWAWMM_ConfigReReadAtRequest then
				AWAWMM_HydrateStateFromArchive()
			else
				AWAWMM_ConfigReRead = true
				return
			end
		else
		end
		RefreshFilterChips()
		UpdateSortOrderButton()
		Controls.AWAWMMGroupByAuthorToggle:SetCheck(g_GroupByAuthor)
		RefreshCustomGroupFilterPullDown()
		RefreshListings()
		return
	end
	if not g_ConfigLoadPending then
		return
	end
	g_ConfigLoadPending = false
	if g_ConfigHydrated then
		return
	end
	g_ConfigHydrated = true
	if g_ConfigReadAtRequest then
		return
	end
	MergeStateFromArchive()
	RefreshFilterChips()
	UpdateSortOrderButton()
	Controls.AWAWMMGroupByAuthorToggle:SetCheck(g_GroupByAuthor)
	RefreshCustomGroupFilterPullDown()
	RefreshListings()
end
AWAWMM_FRONT_ENTRY_GAP = 8
AWAWMM_FRONT_ENTRY_PAD = 10
AWAWMM_FRONT_ENTRY_SLICE_X = 23
AWAWMM_FRONT_ENTRY_SLICE_Y = 4
AWAWMM_FRONT_ENTRY_MAX_TICKS = 600
AWAWMM_FRONT_ENTRY_BUTTON_ID = "AWAWMMFrontEntryButton"
AWAWMM_FRONT_ENTRY_ADV_CTX = "/FrontEnd/FrontEndContainer/MainMenu/AdvancedSetup"
AWAWMM_FRONT_ENTRY_ADV_ANCHOR = "/FrontEnd/FrontEndContainer/MainMenu/AdvancedSetup/MainGrid/MainWindow/CloseButton"
AWAWMM_FRONT_ENTRY_LOAD_ANCHOR = "/FrontEnd/FrontEndContainer/MainMenu/LoadGameMenu/MainGrid/MainWindow/BackButton"
AWAWMM_FRONT_ENTRY_MODS_CTX = "/FrontEnd/FrontEndContainer/MainMenu/ModsContext"
function AWAWMM_FrontEntryFindButton(host)
	local kids = host:GetChildren()
	for i = 1, #kids do
		local kid = kids[i]
		if type(kid.GetID) == "function" and kid:GetID() == AWAWMM_FRONT_ENTRY_BUTTON_ID then
			return kid
		end
	end
	return nil
end
function AWAWMM_FrontEntryFitSize(btn, padding, sizeOption)
	if type(btn.GetTextControl) ~= "function" then
		return false
	end
	local label = btn:GetTextControl()
	if label == nil or type(label.GetSizeX) ~= "function" then
		return false
	end
	local labelX = label:GetSizeX()
	if type(labelX) ~= "number" or labelX <= 0 then
		return false
	end
	local pad = padding or 0
	btn:SetSizeX(math.max(133, labelX + 2 * (AWAWMM_FRONT_ENTRY_SLICE_X + pad)))
	if sizeOption ~= "H" then
		local labelY = label:GetSizeY()
		if type(labelY) == "number" and labelY > 0 then
			btn:SetSizeY(math.max(36, labelY + 2 * (AWAWMM_FRONT_ENTRY_SLICE_Y + pad)))
		end
	end
	return true
end
function AWAWMM_FrontEntryHoverSound()
	if UI ~= nil and type(UI.PlaySound) == "function" then
		UI.PlaySound("Main_Menu_Mouse_Over")
	end
end
function AWAWMM_MountFrontEntry(anchorPath, autoPadding, autoSizeOption)
	if ContextPtr == nil or type(ContextPtr.LookUpControl) ~= "function" then
		return false, "no-lookup"
	end
	local anchor = ContextPtr:LookUpControl(anchorPath)
	if anchor == nil then
		return false, "no-anchor"
	end
	local host = anchor:GetParent()
	if host == nil then
		return false, "no-host"
	end
	local existing = AWAWMM_FrontEntryFindButton(host)
	if existing ~= nil then
		AWAWMM_FrontEntryFitSize(existing, autoPadding, autoSizeOption)
		return true, "already"
	end
	local sizeX = anchor:GetSizeVal()
	if type(sizeX) ~= "number" or sizeX <= 0 then
		return false, "no-width"
	end
	local inst = {}
	ContextPtr:BuildInstance("AWAWMMFrontEntryInstance", inst)
	local btn = inst.AWAWMMFrontEntryButton
	if btn == nil then
		return false, "no-instance"
	end
	btn:ChangeParent(host)
	host:AddChildAtIndex(btn, 0)
	btn:SetOffsetVal(sizeX + AWAWMM_FRONT_ENTRY_GAP + 1, 0)
	if type(host.ReprocessAnchoring) == "function" then
		host:ReprocessAnchoring()
	end
	btn:RegisterCallback(Mouse.eLClick, AWAWMM_FrontEntryOnClick)
	btn:RegisterCallback(Mouse.eMouseEnter, AWAWMM_FrontEntryHoverSound)
	AWAWMM_FrontEntryFitSize(btn, autoPadding, autoSizeOption)
	return true, "mounted"
end
function AWAWMM_FrontEntryOnClick()
	local target = nil
	if ContextPtr ~= nil and type(ContextPtr.LookUpControl) == "function" then
		target = ContextPtr:LookUpControl(AWAWMM_FRONT_ENTRY_MODS_CTX)
	end
	if target == nil or UIManager == nil or type(UIManager.QueuePopup) ~= "function" then
		return
	end
	UIManager:QueuePopup(target, PopupPriority.Current)
end
function AWAWMM_FrontEntryEnsureLoadGame()
	local ok, why = AWAWMM_MountFrontEntry(AWAWMM_FRONT_ENTRY_LOAD_ANCHOR, AWAWMM_FRONT_ENTRY_PAD, "H")
	return ok
end
function AWAWMM_FrontEntryOnScreenOpen()
	AWAWMM_FrontEntryEnsureLoadGame()
	local adv = nil
	if ContextPtr ~= nil and type(ContextPtr.LookUpControl) == "function" then
		adv = ContextPtr:LookUpControl(AWAWMM_FRONT_ENTRY_ADV_CTX)
	end
	if adv == nil or type(adv.SetUpdate) ~= "function" then
		return
	end
	AWAWMM_FrontEntryAdvTicks = 0
	adv:SetUpdate(AWAWMM_FrontEntryAdvUpdate)
end
function AWAWMM_FrontEntryStopAdvUpdate()
	local adv = nil
	if ContextPtr ~= nil and type(ContextPtr.LookUpControl) == "function" then
		adv = ContextPtr:LookUpControl(AWAWMM_FRONT_ENTRY_ADV_CTX)
	end
	if adv ~= nil and type(adv.ClearUpdate) == "function" then
		adv:ClearUpdate()
	end
end
function AWAWMM_FrontEntryAdvUpdate()
	AWAWMM_FrontEntryAdvTicks = (AWAWMM_FrontEntryAdvTicks or 0) + 1
	local ok, why = AWAWMM_MountFrontEntry(AWAWMM_FRONT_ENTRY_ADV_ANCHOR, AWAWMM_FRONT_ENTRY_PAD, "H")
	if ok then
		AWAWMM_FrontEntryStopAdvUpdate()
		return
	end
	if AWAWMM_FrontEntryAdvTicks >= AWAWMM_FRONT_ENTRY_MAX_TICKS then
		AWAWMM_FrontEntryStopAdvUpdate()
	end
end
function AWAWMM_FrontEntryCatchUp()
	if AWAWMM_FrontEntryEnsureLoadGame() then
	local ok, why = AWAWMM_MountFrontEntry(AWAWMM_FRONT_ENTRY_ADV_ANCHOR, AWAWMM_FRONT_ENTRY_PAD, "H")
	end
end
function Initialize()
	Log("init", "AWAWModManager Mods UI Initialize begin (v" .. tostring(AWAWMM.VERSION)
		.. ") environment=frontend")
	local function HoverSound()
		UI.PlaySound("Main_Menu_Mouse_Over")
	end
	AWAWMM.AllowCurrentGroupRescue = true
	AWAWMM.SelfModId = AWAWMM_SELF_ID
	AWAWMM.SetStore(AWAWMM.MakeGameConfigStore())
	if Events ~= nil and Events.LoadComplete ~= nil then
		Events.LoadComplete.Add(function(eResult, eType, eOptions, eFileType)
			OnConfigArchiveLoaded(eResult, eType, eOptions, eFileType)
			if g_ConfigLoadPending then
				return
			end
			if not g_ConfigHydrated then
				return
			end
			AWAWMM.StartupSyncEnabledMods("loadcomplete", false)
		end)
	end
	if AWAWMM_TryReadMirrorOnStartup("init") then
		g_ConfigLoadPending = false
		g_ConfigReadAtRequest = true
		g_ConfigHydrated = true
		AWAWMM.StartupSyncEnabledMods("mirror-read", false)
		AWAWMM.EnsureConfigArchiveExists("mirror-read")
	elseif AWAWMM.ShouldSkipArchiveRead() then
		g_ConfigLoadPending = false
		AWAWMM_ApplyUnavailableForNoMirror("init-no-mirror-mp")
	else
		local healed, healReason, healState = AWAWMM.SelfHealFromArchive()
		if healed then
			AWAWMM_HydrateStateFromArchive(healState, "self-heal")
			g_ConfigLoadPending = false
			g_ConfigReadAtRequest = true
			g_ConfigHydrated = true
			AWAWMM_ClearUnavailableState()
			AWAWMM.StartupSyncEnabledMods("self-heal", false)
		else
			g_ConfigLoadPending = false
			AWAWMM_ApplyUnavailableForNoMirror("self-heal-" .. tostring(healReason))
			Log("store", "state read self-heal failed reason=" .. tostring(healReason))
		end
	end
	g_ModExtras = {}
	g_ExtrasDirty = true
	g_ModListings = {}
	AWAWMM_ApplyRowMetrics()
	AWAWMM_TOOLBAR.ApplyFilterChips()
	RefreshFilterChips()
	UpdateSortOrderButton()
	Controls.AWAWMMGroupByAuthorToggle:SetCheck(g_GroupByAuthor)
	InitializeSortListingsPulldown()
	RefreshModGroups()
	RefreshCustomGroupFilterPullDown()
	ClearClick(Controls.AWAWMMSortOrderToggle, Mouse.eLClick)
	Controls.AWAWMMSortOrderToggle:RegisterCallback(Mouse.eLClick, function()
		g_SortAsc = not g_SortAsc
		AWAWMM.SaveSortAsc(g_SortAsc)
		UpdateSortOrderButton()
		RefreshListings()
	end)
	ClearClick(Controls.AWAWMMGroupByAuthorToggle, Mouse.eLClick)
	Controls.AWAWMMGroupByAuthorToggle:RegisterCallback(Mouse.eLClick, function()
		g_GroupByAuthor = Controls.AWAWMMGroupByAuthorToggle:IsChecked()
		AWAWMM.SaveGroupByAuthor(g_GroupByAuthor)
		if not g_GroupByAuthor then
			AWAWMM_AuthorCollapsed = {}
		end
		RefreshListings()
	end)
	ClearClick(Controls.AWAWMMGroupRenameButton, Mouse.eLClick)
	Controls.AWAWMMGroupRenameButton:RegisterCallback(Mouse.eLClick, function()
		if g_GroupFilter == nil or not AWAWMM.HasGroup(g_Groups, g_GroupFilter) then
			return
		end
		OpenRenameGroupPopup(g_GroupFilter)
	end)
	ClearClick(Controls.AWAWMMGroupDeleteButton, Mouse.eLClick)
	Controls.AWAWMMGroupDeleteButton:RegisterCallback(Mouse.eLClick, function()
		if g_GroupFilter == nil or not AWAWMM.HasGroup(g_Groups, g_GroupFilter) then
			return
		end
		RequestDeleteGroup(g_GroupFilter)
	end)
	for i = 1, #FILTER_CHIPS do
		local chip = FILTER_CHIPS[i]
		local ctrl = Controls[chip.Control]
		if ctrl ~= nil then
			ClearClick(ctrl, Mouse.eLClick)
			ctrl:RegisterCallback(Mouse.eLClick, function()
				OnFilterChipClicked(chip)
			end)
		end
	end
	Controls.AWAWMMCleanupOrphansButton:RegisterCallback(Mouse.eLClick, OnCleanupOrphans)
	ClearClick(Controls.AWAWMMDeleteConfigButton, Mouse.eLClick)
	Controls.AWAWMMDeleteConfigButton:RegisterCallback(Mouse.eLClick, AWAWMM_OnDeleteManagerConfigClick)
	Controls.AWAWMMDeleteConfigButton:RegisterCallback(Mouse.eMouseEnter, HoverSound)
	Controls.SearchEditBox:RegisterStringChangedCallback(OnSearchCharCallback)
	Controls.AWAWMMSearchClearButton:RegisterCallback(Mouse.eLClick, OnSearchClearClick)
	Controls.SearchEditBox:RegisterHasFocusCallback(OnSearchBarGainFocus)
	Controls.SearchEditBox:RegisterLostFocusCallback(OnSearchBarLostFocus)
	Controls.CreateModGroup:RegisterCallback(Mouse.eLClick, CreateModGroup)
	Controls.DeleteModGroup:RegisterCallback(Mouse.eLClick, DeleteModGroup)
	Controls.CancelBindingButton:RegisterCallback(Mouse.eLClick, function()
		Controls.NameModGroupPopup:SetHide(true)
	end)
	Controls.CreateModGroupButton:RegisterCallback(Mouse.eLClick, CommitGroupPopup)
	Controls.ModGroupEditBox:RegisterStringChangedCallback(function()
		local str = Controls.ModGroupEditBox:GetText()
		AWAWMM_SetDisabledWithReason(Controls.CreateModGroupButton, (str == nil or #str == 0),
			"LOC_AWAWMM_TIP_GROUP_NAME_EMPTY", nil)
		if str == nil or #str == 0 then
			AWAWMM_ShowGroupError("LOC_AWAWMM_TIP_GROUP_NAME_EMPTY")
		else
			AWAWMM_ClearGroupError()
		end
		AWAWMM_NoteInputChange("group", Controls.ModGroupEditBox)
	end)
	Controls.ModGroupEditBox:RegisterCommitCallback(function()
		local isIme, dt, why = AWAWMM_CommitFromIme("group", Controls.ModGroupEditBox)
		if isIme then
			AWAWMM_MarkCommitSeen("group", Controls.ModGroupEditBox)
			AWAWMM_RefocusNextFrame(Controls.ModGroupEditBox)
			return
		end
		CommitGroupPopup()
	end)
	Controls.AWAWMMSelfYesInput:RegisterStringChangedCallback(AWAWMM_SyncSelfPopupOK)
	Controls.AWAWMMSelfOK:RegisterCallback(Mouse.eLClick, AWAWMM_SelfPopupConfirm)
	Controls.AWAWMMSelfCancel:RegisterCallback(Mouse.eLClick, AWAWMM_CloseSelfPopup)
	Controls.AWAWMMDetailAliasEditBox:RegisterStringChangedCallback(function()
		AWAWMM_SetDisabledWithReason(Controls.AWAWMMDetailAliasApplyButton, AliasEditTextIsEmpty(),
			"LOC_AWAWMM_TIP_ALIAS_EMPTY", nil)
		AWAWMM_SyncClearButton(Controls.AWAWMMAliasEditClearButton,
			Controls.AWAWMMDetailAliasEditBox:GetText(), AliasPlaceholder())
		AWAWMM_NoteInputChange("alias", Controls.AWAWMMDetailAliasEditBox)
	end)
	Controls.AWAWMMAliasEditClearButton:RegisterCallback(Mouse.eLClick, function()
		AWAWMM_ClearInputToPlaceholder(Controls.AWAWMMDetailAliasEditBox, AliasPlaceholder(),
			Controls.AWAWMMAliasEditClearButton)
		AWAWMM_SetDisabledWithReason(Controls.AWAWMMDetailAliasApplyButton, true,
			"LOC_AWAWMM_TIP_ALIAS_EMPTY", nil)
	end)
	Controls.AWAWMMDetailAliasEditBox:RegisterHasFocusCallback(OnAliasEditGainFocus)
	Controls.AWAWMMDetailAliasEditBox:RegisterLostFocusCallback(OnAliasEditLostFocus)
	Controls.AWAWMMDetailAliasApplyButton:RegisterCallback(Mouse.eLClick, ApplyAliasFromEditBox)
	Controls.AWAWMMDetailAliasEditBox:RegisterCommitCallback(function()
		local isIme, dt, why = AWAWMM_CommitFromIme("alias", Controls.AWAWMMDetailAliasEditBox)
		if isIme then
			AWAWMM_MarkCommitSeen("alias", Controls.AWAWMMDetailAliasEditBox)
			AWAWMM_RefocusNextFrame(Controls.AWAWMMDetailAliasEditBox)
			return
		end
		ApplyAliasFromEditBox()
	end)
	Controls.AWAWMMDetailAliasClearButton:RegisterCallback(Mouse.eLClick, ClearAlias)
	Controls.EnableAll:RegisterCallback(Mouse.eLClick, OnEnableAll)
	Controls.DisableAll:RegisterCallback(Mouse.eLClick, OnDisableAll)
	Controls.AWAWMMDlcHeader:RegisterCallback(Mouse.eLClick, ToggleDlcFold)
	Controls.AWAWMMDepsHeader:RegisterCallback(Mouse.eLClick, ToggleDepsFold)
	Controls.AWAWMMDependentsHeader:RegisterCallback(Mouse.eLClick, ToggleDependentsFold)
	Controls.EnableAll:RegisterCallback(Mouse.eMouseEnter, HoverSound)
	Controls.DisableAll:RegisterCallback(Mouse.eMouseEnter, HoverSound)
	Controls.AWAWMMDlcHeader:RegisterCallback(Mouse.eMouseEnter, HoverSound)
	Controls.AWAWMMDepsHeader:RegisterCallback(Mouse.eMouseEnter, HoverSound)
	Controls.AWAWMMDependentsHeader:RegisterCallback(Mouse.eMouseEnter, HoverSound)
	Controls.CloseButton:RegisterCallback(Mouse.eLClick, HandleExitRequest)
	Controls.CloseButton:RegisterCallback(Mouse.eMouseEnter, HoverSound)
	Events.SystemUpdateUI.Add( OnUpdateUI )
	ContextPtr:SetShowHandler( OnShow )
	ContextPtr:SetHideHandler( OnHide )
	ContextPtr:SetPostInit( PostInit )
	AWAWMM_FrontEntryEnsureLoadGame()
	LuaEvents.MainMenu_SetLoadGameServerType.Add(AWAWMM_FrontEntryOnScreenOpen)
	Log("init", "AWAWModManager Mods UI initialized (v" .. tostring(AWAWMM.VERSION)
		.. ") environment=frontend multiplayer=" .. tostring(AWAWMM.ShouldSkipArchiveRead()))
end
Initialize()

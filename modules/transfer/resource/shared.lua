local Spring = Spring

local Published = require("modules/published")
local SharedConfig = require("modules/transfer/economy/shared_config")
local TransferEnums = require("modules/transfer/enums")

local Shared = {}

local factorFields = {
	taxedSendable = Published.Number,
	taxRate = Published.Number,
	capacity = Published.Number,
	isNonPlayer = Published.Boolean,
	active = Published.Boolean,
}

local factors = {
	[TransferEnums.ResourceType.METAL] = Published.PerTeam(
		TransferEnums.PolicyType.MetalTransfer .. "_factor",
		factorFields
	),
	[TransferEnums.ResourceType.ENERGY] = Published.PerTeam(
		TransferEnums.PolicyType.EnergyTransfer .. "_factor",
		factorFields
	),
}

---@param resourceType ResourceName
---@return PublishedRecord
function Shared.ResourceFactor(resourceType)
	return factors[resourceType] or factors[TransferEnums.ResourceType.ENERGY]
end

---@param springRepo Spring
---@param teamId integer
---@return boolean
function Shared.IsNonPlayerTeam(springRepo, teamId)
	if teamId == springRepo.GetGaiaTeamID() then
		return true
	end
	local _name, _active, _spec, isAiTeam = springRepo.GetTeamInfo(teamId, false)
	if isAiTeam then
		return true
	end
	local luaAI = springRepo.GetTeamLuaAI and springRepo.GetTeamLuaAI(teamId)
	return luaAI ~= nil and luaAI ~= ""
end

---@param resourceType ResourceName
---@return string the team rules param the resource's record lives on
function Shared.MakeFactorKey(resourceType)
	return Shared.ResourceFactor(resourceType).key
end

---@param terms ResourceTransferTerms
---@return integer TransferEnums.ResourceTermsCase: the one case the terms are in, for every reader to branch on
function Shared.CaseOf(terms)
	if terms.senderTeamId == terms.receiverTeamId then
		return TransferEnums.ResourceTermsCase.OnSelf
	end
	if not terms.canShare then
		return TransferEnums.ResourceTermsCase.OnDisabled
	end
	if terms.taxRate <= 0 then
		return TransferEnums.ResourceTermsCase.OnTaxFree
	end
	return TransferEnums.ResourceTermsCase.OnTaxed
end

---@param terms ResourceTransferTerms
---@param desired number
---@return number received, number sent
function Shared.CalculateSenderTaxedAmount(terms, desired)
	if desired <= 0 then
		return 0, 0
	end
	local r = terms.taxRate
	if r >= 1.0 then
		return 0, 0
	end
	local sent = desired / (1 - r)
	return desired, sent
end

---@param spring Spring
---@param teamId integer
---@param resourceType ResourceName
---@return table|nil factor record, or nil if not cached
local function readFactor(spring, teamId, resourceType)
	return Shared.ResourceFactor(resourceType).Read(spring, teamId)
end

---@param senderId integer
---@param receiverId integer
---@param resourceType ResourceName
---@param springApi Spring?
---@return ResourceTransferTerms
function Shared.GetCachedTerms(senderId, receiverId, resourceType, springApi)
	local spring = springApi or Spring
	---@type ResourceTransferTerms
	local refused = {
		senderTeamId = senderId,
		receiverTeamId = receiverId,
		resourceType = resourceType,
		canShare = false,
		taxRate = 0,
		amountSendable = 0,
		amountReceivable = 0,
	}
	if not SharedConfig.isResourceSharingEnabled(spring) then
		return refused
	end

	local senderFactor = readFactor(spring, senderId, resourceType)
	local receiverFactor = readFactor(spring, receiverId, resourceType)
	if not senderFactor or not receiverFactor then
		return refused
	end

	if not spring.IsCheatingEnabled() then
		if not spring.AreTeamsAllied(senderId, receiverId) and not senderFactor.isNonPlayer then
			return refused
		end
		if not receiverFactor.active then
			return refused
		end
	end

	local room = math.max(0, receiverFactor.capacity)
	---@type ResourceTransferTerms
	return {
		senderTeamId = senderId,
		receiverTeamId = receiverId,
		resourceType = resourceType,
		canShare = true,
		taxRate = senderFactor.taxRate,
		amountSendable = math.min(senderFactor.taxedSendable, room),
		amountReceivable = room,
	}
end

return Shared

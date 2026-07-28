---@diagnostic disable: lowercase-global, undefined-field

-- The transfer module forwards a team's published policy change to LuaUI as SharePolicyChanged, which reaches a
-- widget only when the widget handler declares the callin: that gives it a list, a dispatcher and the LuaUI global
-- the forwarding gadget calls. Expect the list, then dispatch as the gadget would and expect a widget to hear it.
local TransferEnums = VFS.Include("modules/transfer/enums.lua")

local function skip()
	return Spring.GetGameFrame() <= 0
end

local function test()
	local team0 = Spring.GetLocalTeamID()
	local domain = TransferEnums.PolicyType.MetalTransfer
	assert(widgetHandler.SharePolicyChangedList ~= nil, "the widget handler declares SharePolicyChanged")

	Test.expectCallin("SharePolicyChanged")
	widgetHandler:SharePolicyChanged(team0, domain)
	Test.waitUntilCallinArgs("SharePolicyChanged", { team0, domain }, 10)
end

return {
	skip = skip,
	test = test,
}

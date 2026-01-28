local PFS = game:GetService("PathfindingService")

local module = {}

local Path = {}
Path.__index = Path

local PARTIAL = Enum.PathStatus.ClosestNoPath

export type Route = {PathWaypoint}
export type AgentParams = {
	AgentRadius : number,
	AgentHeight : number,
	AgentCanClimb : boolean,
	AgentCanJump : boolean,
	Costs : {},
	WaypointSpacing : number,
	PathSettings : {SupportPartialPath : boolean}
}

function module.new(AgentParams : AgentParams)
	local self = setmetatable({
		Path = PFS:CreatePath(AgentParams),
		Destroying = false,
		_LastCompute = 0,
	}, Path)

	return self
end

function Path:Generate(PointA : Vector3, PointB : Vector3) : Route & boolean
	if self.Destroying then
		return
	end

	local now = os.clock()
	if now - self._LastCompute < 0.25 then
		return
	end
	self._LastCompute = now

	local Success, Message = pcall(function()
		self.Path:ComputeAsync(PointA, PointB)
	end)

	if not Success then
		warn("[Path] ComputeAsync failed:", Message)
		return
	end

	if self.Destroying then
		return
	end

	local Route : Route = self.Path:GetWaypoints()
	if not Route or #Route == 0 then
		return
	end

	for i = #Route - 1, 1, -1 do
		local A = Route[i]
		local B = Route[i + 1]
		if (A.Position - B.Position).Magnitude < 2 and A.Action ~= Enum.PathWaypointAction.Jump then
			table.remove(Route, i)
		end
	end

	if #Route > 256 then
		warn("[Path] Route too large:", #Route)
		return
	end

	return Route, self.Path.Status == PARTIAL
end

function Path:Estimate(Route : Route, Speed : number)
	if not Route or not Speed then
		return {}
	end

	local Estimate = {}

	for i = 1, #Route - 1 do
		local A = Route[i]
		local B = Route[i + 1]
		Estimate[i] = (A.Position - B.Position).Magnitude / Speed
	end

	return Estimate
end

function Path:GetStatus() : Enum.PathStatus
	return self.Path.Status
end

function Path:Show()
	return
end

function Path:Hide()
	return
end

function Path:Destroy()
	if self.Destroying then
		return
	end

	self.Destroying = true

	if self.Path then
		self.Path:Destroy()
	end

	table.clear(self)
	setmetatable(self, nil)
	self = nil
end

return module

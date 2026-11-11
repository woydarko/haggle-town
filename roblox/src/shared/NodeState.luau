--!strict
-- State of one gather node (tree, rock, fishing spot). Pure: time is passed in, so the spec drives it.
-- ready -> claimed(owner) -> felled -> (respawnS later) ready. A claim idle for CLAIM_TTL is dropped
-- (matches the backend's 60 s session TTL), so a stuck player never locks a node.

local CLAIM_TTL = 60

export type NodeState = {
	kind: string,
	respawnS: number,
	state: string, -- "ready" | "claimed" | "felled"
	owner: any,
	at: number, -- last claim activity or the moment it fell
	claim: (self: NodeState, who: any, now: number) -> (boolean, string?),
	hit: (self: NodeState, now: number) -> (),
	fell: (self: NodeState, now: number) -> (),
	release: (self: NodeState, who: any) -> (),
	tick: (self: NodeState, now: number) -> boolean,
	isReady: (self: NodeState) -> boolean,
}

local NodeState = {}
NodeState.CLAIM_TTL = CLAIM_TTL

local methods = {}

-- ok, or false + "taken" (someone else holds it) / "gone" (felled, regrowing).
function methods.claim(self: NodeState, who: any, now: number): (boolean, string?)
	if self.state == "felled" then
		return false, "gone"
	elseif self.state == "claimed" and self.owner ~= who then
		return false, "taken"
	end
	self.state, self.owner, self.at = "claimed", who, now
	return true, nil
end

function methods.hit(self: NodeState, now: number)
	if self.state == "claimed" then
		self.at = now
	end
end

function methods.fell(self: NodeState, now: number)
	if self.state ~= "felled" then
		self.state, self.owner, self.at = "felled", nil, now
	end
end

function methods.release(self: NodeState, who: any)
	if self.state == "claimed" and self.owner == who then
		self.state, self.owner = "ready", nil
	end
end

-- Advances timers; true when the state changed (so the caller updates the world once).
function methods.tick(self: NodeState, now: number): boolean
	if self.state == "felled" and now - self.at >= self.respawnS then
		self.state = "ready"
		return true
	elseif self.state == "claimed" and now - self.at > CLAIM_TTL then
		self.state, self.owner = "ready", nil
		return true
	end
	return false
end

function methods.isReady(self: NodeState): boolean
	return self.state == "ready"
end

function NodeState.new(kind: string, respawnS: number?): NodeState
	local n = {
		kind = kind,
		respawnS = respawnS or 30,
		state = "ready",
		owner = nil,
		at = 0,
		claim = methods.claim,
		hit = methods.hit,
		fell = methods.fell,
		release = methods.release,
		tick = methods.tick,
		isReady = methods.isReady,
	}
	return n :: any
end

return NodeState

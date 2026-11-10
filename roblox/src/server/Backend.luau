--!strict
-- The only place the Roblox server talks to the Haggle Town backend. Every request is HMAC-signed.
-- Config (server-only, never replicated): ServerStorage.Config.BackendUrl and ServerStorage.Config.HmacSecret (StringValues).
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local Hmac = require(script.Parent.Hmac)

local Backend = {}

local function config(): (string, string)
	local folder = ServerStorage:WaitForChild("Config", 10)
	assert(folder, "ServerStorage.Config missing (see roblox/README.md)")
	local url = (folder:WaitForChild("BackendUrl") :: StringValue).Value
	local secret = (folder:WaitForChild("HmacSecret") :: StringValue).Value
	return (string.gsub(url, "/+$", "")), secret
end

local function request(method: string, path: string, body: string?): (boolean, any)
	local base, secret = config()
	local ts = tostring(math.floor(DateTime.now().UnixTimestampMillis))
	local payload = body or ""
	local opts: any = {
		Url = base .. path,
		Method = method,
		Headers = {
			["X-Timestamp"] = ts,
			["X-Signature"] = Hmac.hmac(secret, ts .. "." .. payload),
		},
	}
	if body then
		opts.Body = body
		opts.Headers["Content-Type"] = "application/json"
	end
	for attempt = 1, 2 do
		local ok, res = pcall(HttpService.RequestAsync, HttpService, opts)
		if ok then
			local decoded = nil
			pcall(function()
				decoded = HttpService:JSONDecode(res.Body)
			end)
			if res.StatusCode < 500 or attempt == 2 then
				return res.Success, decoded or { error = "bad_response" }
			end
		elseif attempt == 2 then
			warn("[Backend] request failed: " .. tostring(res))
			return false, { error = "offline" }
		end
		task.wait(0.5)
	end
	return false, { error = "offline" }
end

function Backend.post(path: string, body: { [string]: any }): (boolean, any)
	return request("POST", path, HttpService:JSONEncode(body))
end

function Backend.get(path: string): (boolean, any)
	return request("GET", path, nil)
end

return Backend

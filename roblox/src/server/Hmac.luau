--!strict
-- Pure-Luau SHA-256 and HMAC-SHA256 (hex). Signs every request the Roblox server sends to the backend.
-- Tested by roblox/tests/Hmac.spec.luau against the same vector as server/test/hmac.test.ts.

local band, bxor, bnot, rrotate, rshift = bit32.band, bit32.bxor, bit32.bnot, bit32.rrotate, bit32.rshift

local K = {
	0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
	0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
	0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
	0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
	0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
	0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
	0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
	0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local MOD = 4294967296

local function sha256raw(msg: string): string
	local len = #msg
	local pad = 64 - ((len + 9) % 64)
	if pad == 64 then
		pad = 0
	end
	msg = msg .. "\128" .. string.rep("\0", pad) .. string.pack(">I4I4", math.floor(len * 8 / MOD), (len * 8) % MOD)

	local h0, h1, h2, h3 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
	local h4, h5, h6, h7 = 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
	local w = table.create(64, 0)

	for chunk = 1, #msg, 64 do
		for i = 0, 15 do
			w[i + 1] = string.unpack(">I4", msg, chunk + i * 4)
		end
		for i = 17, 64 do
			local a, b = w[i - 15], w[i - 2]
			local s0 = bxor(rrotate(a, 7), rrotate(a, 18), rshift(a, 3))
			local s1 = bxor(rrotate(b, 17), rrotate(b, 19), rshift(b, 10))
			w[i] = (w[i - 16] + s0 + w[i - 7] + s1) % MOD
		end
		local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7
		for i = 1, 64 do
			local S1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
			local ch = bxor(band(e, f), band(bnot(e), g))
			local t1 = (h + S1 + ch + K[i] + w[i]) % MOD
			local S0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
			local maj = bxor(band(a, b), band(a, c), band(b, c))
			local t2 = (S0 + maj) % MOD
			h, g, f, e, d, c, b, a = g, f, e, (d + t1) % MOD, c, b, a, (t1 + t2) % MOD
		end
		h0, h1, h2, h3 = (h0 + a) % MOD, (h1 + b) % MOD, (h2 + c) % MOD, (h3 + d) % MOD
		h4, h5, h6, h7 = (h4 + e) % MOD, (h5 + f) % MOD, (h6 + g) % MOD, (h7 + h) % MOD
	end
	return string.pack(">I4I4I4I4I4I4I4I4", h0, h1, h2, h3, h4, h5, h6, h7)
end

local function hex(s: string): string
	return (string.gsub(s, ".", function(c)
		return string.format("%02x", string.byte(c))
	end))
end

local function xorPad(key: string, byte: number): string
	return (string.gsub(key, ".", function(c)
		return string.char(bxor(string.byte(c), byte))
	end))
end

local Hmac = {}

Hmac.sha256raw = sha256raw

function Hmac.sha256(msg: string): string
	return hex(sha256raw(msg))
end

function Hmac.hmac(key: string, msg: string): string
	if #key > 64 then
		key = sha256raw(key)
	end
	key = key .. string.rep("\0", 64 - #key)
	return hex(sha256raw(xorPad(key, 0x5c) .. sha256raw(xorPad(key, 0x36) .. msg)))
end

return Hmac

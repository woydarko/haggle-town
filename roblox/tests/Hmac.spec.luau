-- Run: lute run roblox/tests/Hmac.spec.luau
local Hmac = require("../src/server/Hmac")

local function eq(a, b, name)
	if a ~= b then
		error(`{name}: expected {b}, got {a}`)
	end
	print("ok", name)
end

eq(Hmac.sha256(""), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "sha256 empty")
eq(Hmac.sha256("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "sha256 abc")
eq(
	Hmac.sha256(string.rep("a", 1000)),
	"41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3",
	"sha256 1000 a"
)
-- Fixed vector shared with server/test/hmac.test.ts
eq(
	Hmac.hmac("test-secret", '1700000000000.{"userId":"1"}'),
	"fd8fa3b67297a5c514c607c493427bc035f17115d2679ef65cd8f0be55207782",
	"hmac shared vector"
)
eq(
	Hmac.hmac(string.rep("k", 100), "long key"),
	Hmac.hmac(Hmac.sha256raw(string.rep("k", 100)), "long key"),
	"hmac long key is hashed"
)
print("Hmac.spec passed")

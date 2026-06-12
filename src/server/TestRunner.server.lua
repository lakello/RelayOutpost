-- Runs TestEZ specs in Studio only. Safe to leave in; exits immediately outside Studio.

local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local ServerScriptService = game:GetService("ServerScriptService")

local ServerPackages = ServerScriptService:WaitForChild("ServerPackages", 10)
if not ServerPackages then
	warn("[TestRunner] ServerPackages not found — run `wally install` first.")
	return
end

local TestEZ = require(ServerPackages:WaitForChild("TestEZ"))

local Tests = ServerScriptService:WaitForChild("Tests", 5)
if not Tests then
	warn("[TestRunner] Tests folder not found in ServerScriptService.")
	return
end

local sharedTests = Tests:WaitForChild("shared", 5)
if not sharedTests then
	warn("[TestRunner] Tests/shared not found.")
	return
end

print("[TestRunner] Running specs...")
TestEZ.TestBootstrap:run({ sharedTests }, TestEZ.Reporters.TextReporter)

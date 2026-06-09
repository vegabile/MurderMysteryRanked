local t = require("./framework")
local Glicko2 = require("../src/Shared/ReplicatedModules/DataModules/Glicko2")

local function makeRating(r: number, RD: number, sigma: number)
	return { r = r, RD = RD, sigma = sigma }
end

local function makeGame(opponentRating: { r: number, RD: number, sigma: number }, score: number)
	return { opponent = opponentRating, score = score }
end

local function isFinite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

t.describe("Glicko2 module constants", function()
	t.it("exposes DefaultRating of 1500", function()
		t.expect(Glicko2.DefaultRating).toBe(1500)
	end)

	t.it("exposes DefaultRD of 350", function()
		t.expect(Glicko2.DefaultRD).toBe(350)
	end)

	t.it("exposes DefaultVolatility of 0.06", function()
		t.expect(Glicko2.DefaultVolatility).toBe(0.06)
	end)

	t.it("exposes Tau of 0.5", function()
		t.expect(Glicko2.Tau).toBe(0.5)
	end)

	t.it("exposes Scale of 173.7178", function()
		t.expect(Glicko2.Scale).toBe(173.7178)
	end)
end)

t.describe("Glicko2 canonical Glickman worked example", function()
	local player = makeRating(1500, 200, 0.06)
	local games = {
		makeGame(makeRating(1400, 30, 0.06), 1),
		makeGame(makeRating(1550, 100, 0.06), 0),
		makeGame(makeRating(1700, 300, 0.06), 0),
	}
	local result = Glicko2.UpdatePlayer(player, games)

	t.it("produces r' near 1464.06", function()
		t.expect(result.r).toBeCloseTo(1464.06, 0.5)
	end)

	t.it("produces RD' near 151.52", function()
		t.expect(result.RD).toBeCloseTo(151.52, 0.5)
	end)

	t.it("produces sigma' near 0.05999", function()
		t.expect(result.sigma).toBeCloseTo(0.05999, 1e-4)
	end)
end)

t.describe("Glicko2 no-op / inactivity (empty games list)", function()
	local player = makeRating(1600, 150, 0.055)

	t.it("returns the same r when given empty games", function()
		local result = Glicko2.UpdatePlayer(player, {})
		t.expect(result.r).toBe(player.r)
	end)

	t.it("returns the same RD when given empty games", function()
		local result = Glicko2.UpdatePlayer(player, {})
		t.expect(result.RD).toBe(player.RD)
	end)

	t.it("returns the same sigma when given empty games", function()
		local result = Glicko2.UpdatePlayer(player, {})
		t.expect(result.sigma).toBe(player.sigma)
	end)

	t.it("does not mutate the player table during no-op", function()
		local rBefore = player.r
		local RDBefore = player.RD
		local sigmaBefore = player.sigma
		Glicko2.UpdatePlayer(player, {})
		t.expect(player.r).toBe(rBefore)
		t.expect(player.RD).toBe(RDBefore)
		t.expect(player.sigma).toBe(sigmaBefore)
	end)

	t.it("returning player resumes same rating (double no-op is idempotent)", function()
		local first = Glicko2.UpdatePlayer(player, {})
		local second = Glicko2.UpdatePlayer(first, {})
		t.expect(second.r).toBe(first.r)
		t.expect(second.RD).toBe(first.RD)
		t.expect(second.sigma).toBe(first.sigma)
	end)
end)

t.describe("Glicko2 purity — inputs are never mutated during active update", function()
	local playerR = 1500
	local playerRD = 200
	local playerSigma = 0.06

	local opponentR = 1400
	local opponentRD = 30
	local opponentSigma = 0.06

	local player = makeRating(playerR, playerRD, playerSigma)
	local opponent = makeRating(opponentR, opponentRD, opponentSigma)
	local games = { makeGame(opponent, 1) }

	Glicko2.UpdatePlayer(player, games)

	t.it("player.r is unchanged after active update", function()
		t.expect(player.r).toBe(playerR)
	end)

	t.it("player.RD is unchanged after active update", function()
		t.expect(player.RD).toBe(playerRD)
	end)

	t.it("player.sigma is unchanged after active update", function()
		t.expect(player.sigma).toBe(playerSigma)
	end)

	t.it("opponent.r is unchanged after active update", function()
		t.expect(opponent.r).toBe(opponentR)
	end)

	t.it("opponent.RD is unchanged after active update", function()
		t.expect(opponent.RD).toBe(opponentRD)
	end)

	t.it("opponent.sigma is unchanged after active update", function()
		t.expect(opponent.sigma).toBe(opponentSigma)
	end)
end)

t.describe("Glicko2 directional invariants", function()
	local baseline = makeRating(1500, 200, 0.06)
	local equalOpponent = makeRating(1500, 200, 0.06)

	t.it("winning vs an equal opponent raises r", function()
		local result = Glicko2.UpdatePlayer(baseline, { makeGame(equalOpponent, 1) })
		t.expect(result.r).toBeGreaterThan(baseline.r)
	end)

	t.it("losing vs an equal opponent lowers r", function()
		local result = Glicko2.UpdatePlayer(baseline, { makeGame(equalOpponent, 0) })
		t.expect(result.r).toBeLessThan(baseline.r)
	end)

	t.it("drawing vs an identical opponent leaves r approximately unchanged", function()
		local result = Glicko2.UpdatePlayer(baseline, { makeGame(equalOpponent, 0.5) })
		local delta = math.abs(result.r - baseline.r)
		t.expect(delta).toBeLessThan(2)
	end)

	t.it("RD strictly decreases after playing at least one game", function()
		local result = Glicko2.UpdatePlayer(baseline, { makeGame(equalOpponent, 0.5) })
		t.expect(result.RD).toBeLessThan(baseline.RD)
	end)

	t.it("beating a stronger opponent raises r more than beating a weaker one", function()
		local strongOpponent = makeRating(1800, 200, 0.06)
		local weakOpponent = makeRating(1200, 200, 0.06)
		local resultVsStrong = Glicko2.UpdatePlayer(baseline, { makeGame(strongOpponent, 1) })
		local resultVsWeak = Glicko2.UpdatePlayer(baseline, { makeGame(weakOpponent, 1) })
		local gainVsStrong = resultVsStrong.r - baseline.r
		local gainVsWeak = resultVsWeak.r - baseline.r
		t.expect(gainVsStrong).toBeGreaterThan(gainVsWeak)
	end)
end)

t.describe("Glicko2 opponent-uncertainty discount via g(phi)", function()
	local player = makeRating(1500, 200, 0.06)
	local targetRating = 1500
	local lowRDOpponent = makeRating(targetRating, 30, 0.06)
	local highRDOpponent = makeRating(targetRating, 350, 0.06)

	local resultVsLowRD = Glicko2.UpdatePlayer(player, { makeGame(lowRDOpponent, 1) })
	local resultVsHighRD = Glicko2.UpdatePlayer(player, { makeGame(highRDOpponent, 1) })

	local gainVsLowRD = resultVsLowRD.r - player.r
	local gainVsHighRD = resultVsHighRD.r - player.r

	t.it("winning vs a low-RD opponent raises r more than winning vs a high-RD opponent at the same rating", function()
		t.expect(gainVsLowRD).toBeGreaterThan(gainVsHighRD)
	end)

	t.it("both wins still raise r above baseline", function()
		t.expect(gainVsLowRD).toBeGreaterThan(0)
		t.expect(gainVsHighRD).toBeGreaterThan(0)
	end)
end)

t.describe("Glicko2 symmetry of mirrored matchups", function()
	local higherPlayer = makeRating(1600, 200, 0.06)
	local lowerPlayer = makeRating(1400, 200, 0.06)

	local higherAfterWin = Glicko2.UpdatePlayer(higherPlayer, { makeGame(lowerPlayer, 1) })
	local lowerAfterLoss = Glicko2.UpdatePlayer(lowerPlayer, { makeGame(higherPlayer, 0) })

	local higherGain = higherAfterWin.r - higherPlayer.r
	local lowerLoss = lowerPlayer.r - lowerAfterLoss.r

	t.it("the winner gains approximately what the loser loses in a symmetric mirror matchup", function()
		local difference = math.abs(higherGain - lowerLoss)
		t.expect(difference).toBeLessThan(5)
	end)

	t.it("the winner's new r and the loser's new r are symmetric about 1500", function()
		local winnerDistFrom1500 = higherAfterWin.r - 1500
		local loserDistFrom1500 = 1500 - lowerAfterLoss.r
		local difference = math.abs(winnerDistFrom1500 - loserDistFrom1500)
		t.expect(difference).toBeLessThan(5)
	end)
end)

t.describe("Glicko2 robustness and edge cases", function()
	t.it("score of exactly 1 (win) produces finite outputs", function()
		local player = makeRating(1500, 200, 0.06)
		local result = Glicko2.UpdatePlayer(player, { makeGame(makeRating(1500, 200, 0.06), 1) })
		t.expect(isFinite(result.r)).toBeTruthy()
		t.expect(isFinite(result.RD)).toBeTruthy()
		t.expect(isFinite(result.sigma)).toBeTruthy()
	end)

	t.it("score of exactly 0 (loss) produces finite outputs", function()
		local player = makeRating(1500, 200, 0.06)
		local result = Glicko2.UpdatePlayer(player, { makeGame(makeRating(1500, 200, 0.06), 0) })
		t.expect(isFinite(result.r)).toBeTruthy()
		t.expect(isFinite(result.RD)).toBeTruthy()
		t.expect(isFinite(result.sigma)).toBeTruthy()
	end)

	t.it("score of exactly 0.5 (draw) produces finite outputs", function()
		local player = makeRating(1500, 200, 0.06)
		local result = Glicko2.UpdatePlayer(player, { makeGame(makeRating(1500, 200, 0.06), 0.5) })
		t.expect(isFinite(result.r)).toBeTruthy()
		t.expect(isFinite(result.RD)).toBeTruthy()
		t.expect(isFinite(result.sigma)).toBeTruthy()
	end)

	t.it("sigma' is strictly positive after any active update", function()
		local player = makeRating(1500, 200, 0.06)
		local result = Glicko2.UpdatePlayer(player, { makeGame(makeRating(1500, 200, 0.06), 1) })
		t.expect(result.sigma).toBeGreaterThan(0)
	end)

	t.it("a long list of games produces finite outputs", function()
		local player = makeRating(1500, 200, 0.06)
		local games = {}
		for i = 1, 50 do
			local score = if i % 3 == 0 then 0 elseif i % 3 == 1 then 1 else 0.5
			table.insert(games, makeGame(makeRating(1500 + (i * 7), 100, 0.06), score))
		end
		local result = Glicko2.UpdatePlayer(player, games)
		t.expect(isFinite(result.r)).toBeTruthy()
		t.expect(isFinite(result.RD)).toBeTruthy()
		t.expect(isFinite(result.sigma)).toBeTruthy()
	end)

	t.it("an established player with very low RD stays tightly rated after a game", function()
		local established = makeRating(1500, 20, 0.06)
		local result = Glicko2.UpdatePlayer(established, { makeGame(makeRating(1500, 20, 0.06), 0.5) })
		t.expect(result.RD).toBeGreaterThan(15)
		t.expect(result.RD).toBeLessThan(30)
	end)

	t.it("sigma' is positive for an established low-RD player", function()
		local established = makeRating(1500, 20, 0.06)
		local result = Glicko2.UpdatePlayer(established, { makeGame(makeRating(1500, 20, 0.06), 0.5) })
		t.expect(result.sigma).toBeGreaterThan(0)
	end)

	t.it("a player who wins all games in a long session has r' greater than initial r", function()
		local player = makeRating(1500, 200, 0.06)
		local games = {}
		for _ = 1, 20 do
			table.insert(games, makeGame(makeRating(1500, 200, 0.06), 1))
		end
		local result = Glicko2.UpdatePlayer(player, games)
		t.expect(result.r).toBeGreaterThan(player.r)
	end)

	t.it("a player who loses all games in a long session has r' less than initial r", function()
		local player = makeRating(1500, 200, 0.06)
		local games = {}
		for _ = 1, 20 do
			table.insert(games, makeGame(makeRating(1500, 200, 0.06), 0))
		end
		local result = Glicko2.UpdatePlayer(player, games)
		t.expect(result.r).toBeLessThan(player.r)
	end)

	t.it("UpdatePlayer returns a new table distinct from the player input", function()
		local player = makeRating(1500, 200, 0.06)
		local result = Glicko2.UpdatePlayer(player, { makeGame(makeRating(1500, 200, 0.06), 1) })
		t.expect(result ~= player).toBeTruthy()
	end)
end)

return nil

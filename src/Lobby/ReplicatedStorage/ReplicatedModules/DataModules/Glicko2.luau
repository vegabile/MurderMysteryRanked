--!strict

export type Rating = {
	r: number,
	RD: number,
	sigma: number,
}

export type Game = {
	opponent: Rating,
	score: number,
}

local Glicko2 = {}

Glicko2.DefaultRating = 1500
Glicko2.DefaultRD = 350
Glicko2.DefaultVolatility = 0.06
Glicko2.Tau = 0.5
Glicko2.Scale = 173.7178
Glicko2.ConvergenceTolerance = 1e-6

local PI_SQUARED = math.pi * math.pi

local function g(phi: number): number
	return 1 / math.sqrt(1 + 3 * phi * phi / PI_SQUARED)
end

local function expectedScore(mu: number, opponentMu: number, opponentPhi: number): number
	return 1 / (1 + math.exp(-g(opponentPhi) * (mu - opponentMu)))
end

local function copyRating(rating: Rating): Rating
	return {
		r = rating.r,
		RD = rating.RD,
		sigma = rating.sigma,
	}
end

local function solveVolatility(delta: number, phi: number, v: number, sigma: number): number
	local tau = Glicko2.Tau
	local epsilon = Glicko2.ConvergenceTolerance
	local deltaSquared = delta * delta
	local phiSquared = phi * phi
	local a = math.log(sigma * sigma)

	local function f(x: number): number
		local expX = math.exp(x)
		local denom = phiSquared + v + expX
		return (expX * (deltaSquared - phiSquared - v - expX)) / (2 * denom * denom) - (x - a) / (tau * tau)
	end

	local function computeB(): number
		if deltaSquared > phiSquared + v then
			return math.log(deltaSquared - phiSquared - v)
		end
		local k = 1
		while f(a - k * tau) < 0 do
			k = k + 1
		end
		return a - k * tau
	end

	local A = a
	local B = computeB()
	local fA = f(A)
	local fB = f(B)

	while math.abs(B - A) > epsilon do
		local C = A + (A - B) * fA / (fB - fA)
		local fC = f(C)
		if fC * fB <= 0 then
			A = B
			fA = fB
		else
			fA = fA / 2
		end
		B = C
		fB = fC
	end

	return math.exp(A / 2)
end

function Glicko2.UpdatePlayer(player: Rating, games: { Game }): Rating
	if games==  nil or #games==  0 then
		return copyRating(player)
	end

	local scale = Glicko2.Scale
	local mu = (player.r - Glicko2.DefaultRating) / scale
	local phi = player.RD / scale

	local invV = 0
	local deltaSum = 0
	for _, game in ipairs(games) do
		local opponent = game.opponent
		local opponentMu = (opponent.r - Glicko2.DefaultRating) / scale
		local opponentPhi = opponent.RD / scale
		local gPhi = g(opponentPhi)
		local e = expectedScore(mu, opponentMu, opponentPhi)
		invV += gPhi * gPhi * e * (1 - e)
		deltaSum += gPhi * (game.score - e)
	end

	local v = 1 / invV
	local delta = v * deltaSum

	local newSigma = solveVolatility(delta, phi, v, player.sigma)
	local phiStar = math.sqrt(phi * phi + newSigma * newSigma)
	local newPhi = 1 / math.sqrt(1 / (phiStar * phiStar) + 1 / v)
	local newMu = mu + newPhi * newPhi * deltaSum

	return {
		r = scale * newMu + Glicko2.DefaultRating,
		RD = scale * newPhi,
		sigma = newSigma,
	}
end

return Glicko2

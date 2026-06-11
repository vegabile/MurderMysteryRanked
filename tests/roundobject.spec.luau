local t =  require("./framework")
local RoundObject =  require("../src/Shared/RoundSystem/RoundObject")

local function state(eliminated: boolean, order: number?)
	return { Eliminated =  eliminated, EliminationOrder =  order }
end

t.describe("RoundObject.ClassifyMode", function()
	t.it("classifies two equal teams of one as 1v1", function()
		t.expect(RoundObject.ClassifyMode({ 1, 1 })).toBe("1v1")
	end)

	t.it("classifies two equal teams of two as 2v2", function()
		t.expect(RoundObject.ClassifyMode({ 2, 2 })).toBe("2v2")
	end)

	t.it("classifies two equal teams of three as 3v3", function()
		t.expect(RoundObject.ClassifyMode({ 3, 3 })).toBe("3v3")
	end)

	t.it("classifies two equal teams of four as 4v4", function()
		t.expect(RoundObject.ClassifyMode({ 4, 4 })).toBe("4v4")
	end)

	t.it("classifies three solo teams as FFA", function()
		t.expect(RoundObject.ClassifyMode({ 1, 1, 1 })).toBe("FFA")
	end)

	t.it("classifies four solo teams as FFA", function()
		t.expect(RoundObject.ClassifyMode({ 1, 1, 1, 1 })).toBe("FFA")
	end)

	t.it("returns nil for two unequal teams", function()
		t.expect(RoundObject.ClassifyMode({ 2, 3 })).toBeFalsy()
	end)

	t.it("returns nil for two teams larger than four", function()
		t.expect(RoundObject.ClassifyMode({ 5, 5 })).toBeFalsy()
	end)

	t.it("returns nil for a single team", function()
		t.expect(RoundObject.ClassifyMode({ 1 })).toBeFalsy()
	end)
end)

t.describe("RoundObject.DecideOutcome", function()
	t.it("is Ongoing while two teams are alive", function()
		local outcome =  RoundObject.DecideOutcome({ state(false), state(false) })
		t.expect(outcome.Status).toBe("Ongoing")
	end)

	t.it("awards the sole surviving team", function()
		local outcome =  RoundObject.DecideOutcome({ state(false), state(true, 2) })
		t.expect(outcome.Status).toBe("Awarded")
		t.expect(outcome.TeamIndex).toBe(1)
	end)

	t.it("awards the team that died last on a double knockout", function()
		local outcome =  RoundObject.DecideOutcome({ state(true, 3), state(true, 5) })
		t.expect(outcome.Status).toBe("Awarded")
		t.expect(outcome.TeamIndex).toBe(2)
	end)

	t.it("awards team one when it died last on a double knockout", function()
		local outcome =  RoundObject.DecideOutcome({ state(true, 6), state(true, 4) })
		t.expect(outcome.TeamIndex).toBe(1)
	end)

	t.it("awards the lowest index when elimination ordering ties", function()
		local outcome =  RoundObject.DecideOutcome({ state(true, 5), state(true, 5) })
		t.expect(outcome.TeamIndex).toBe(1)
	end)

	t.it("is Ongoing in FFA while two of three are alive", function()
		local outcome =  RoundObject.DecideOutcome({ state(false), state(false), state(true, 1) })
		t.expect(outcome.Status).toBe("Ongoing")
	end)

	t.it("awards the FFA survivor when only one is alive", function()
		local outcome =  RoundObject.DecideOutcome({ state(true, 1), state(false), state(true, 2) })
		t.expect(outcome.Status).toBe("Awarded")
		t.expect(outcome.TeamIndex).toBe(2)
	end)

	t.it("stays Ongoing when all teams are eliminated with no recorded deaths", function()
		local outcome =  RoundObject.DecideOutcome({ state(true, nil), state(true, nil) })
		t.expect(outcome.Status).toBe("Ongoing")
	end)
end)

t.describe("RoundObject.FindWinner", function()
	t.it("returns the team that reached the score", function()
		t.expect(RoundObject.FindWinner({ 5, 3 }, 5)).toBe(1)
	end)

	t.it("returns the second team when it reached the score", function()
		t.expect(RoundObject.FindWinner({ 2, 5 }, 5)).toBe(2)
	end)

	t.it("returns nil when no team reached the score", function()
		t.expect(RoundObject.FindWinner({ 4, 4 }, 5)).toBeFalsy()
	end)

	t.it("returns the lowest index when several reached the score", function()
		t.expect(RoundObject.FindWinner({ 5, 5 }, 5)).toBe(1)
	end)

	t.it("returns nil for a non-positive winning score", function()
		t.expect(RoundObject.FindWinner({ 0, 0 }, 0)).toBeFalsy()
	end)
end)

t.describe("RoundObject.BeginGame", function()
	t.it("starts the game from PRE_GAME", function()
		local round =  RoundObject.new()
		t.expect(round:BeginGame()).toBeTruthy()
		t.expect(round:GetState()).toBe("GAME")
	end)

	t.it("refuses to start the game from IN_BETWEEN", function()
		local round =  RoundObject.new()
		round:Transition("GAME")
		round:Transition("IN_BETWEEN")
		t.expect(round:BeginGame()).toBeFalsy()
		t.expect(round:GetState()).toBe("IN_BETWEEN")
	end)
end)

t.describe("RoundObject match scoring", function()
	t.it("defaults to two teams", function()
		t.expect(RoundObject.new():GetTeamCount()).toBe(2)
	end)

	t.it("creates the requested number of teams", function()
		t.expect(RoundObject.new(4):GetTeamCount()).toBe(4)
	end)

	t.it("falls back to two teams for an invalid team count", function()
		t.expect(RoundObject.new(1):GetTeamCount()).toBe(2)
	end)

	t.it("starts every team on zero points", function()
		local round =  RoundObject.new(2)
		t.expect(round:GetPoints(1)).toBe(0)
		t.expect(round:GetPoints(2)).toBe(0)
	end)

	t.it("awards points and detects the winner at the winning score", function()
		local round =  RoundObject.new(2, 3)
		t.expect(round:IsOver()).toBeFalsy()
		round:AwardPoint(1)
		round:AwardPoint(1)
		t.expect(round:GetWinner()).toBeFalsy()
		round:AwardPoint(1)
		t.expect(round:GetWinner()).toBe(1)
		t.expect(round:IsOver()).toBeTruthy()
	end)

	t.it("falls back to the default winning score for an invalid score", function()
		local round =  RoundObject.new(2, 0)
		for _ =  1, RoundObject.DefaultWinningScore - 1 do
			round:AwardPoint(2)
		end
		t.expect(round:GetWinner()).toBeFalsy()
		round:AwardPoint(2)
		t.expect(round:GetWinner()).toBe(2)
	end)

	t.it("rejects awarding points to a team outside the range", function()
		local round =  RoundObject.new(2)
		t.expect(round:AwardPoint(3)).toBeFalsy()
	end)
end)

return nil

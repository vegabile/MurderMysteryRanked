local t =  require("./framework")
local MatchData =  require("../src/Shared/MatchData")

t.describe("MatchData.fromPadName", function()
	t.it("parses 1v1Pad to mode 1v1 and perSide 1", function()
		local mode, perSide =  MatchData.fromPadName("1v1Pad")
		t.expect(mode).toBe("1v1")
		t.expect(perSide).toBe(1)
	end)

	t.it("parses a suffixed 3v3Pad2 to mode 3v3 and perSide 3", function()
		local mode, perSide =  MatchData.fromPadName("3v3Pad2")
		t.expect(mode).toBe("3v3")
		t.expect(perSide).toBe(3)
	end)

	t.it("parses 4v4Pad to perSide 4", function()
		local _, perSide =  MatchData.fromPadName("4v4Pad")
		t.expect(perSide).toBe(4)
	end)

	t.it("rejects an asymmetric 1v2Pad", function()
		local mode =  MatchData.fromPadName("1v2Pad")
		t.expect(mode).toBe(nil)
	end)

	t.it("rejects a non-pad name", function()
		local mode =  MatchData.fromPadName("Model")
		t.expect(mode).toBe(nil)
	end)

	t.it("rejects a bare Pad1 step pad", function()
		local mode =  MatchData.fromPadName("Pad1")
		t.expect(mode).toBe(nil)
	end)
end)

t.describe("MatchData.build", function()
	local snapshot =  {
		side1 =  { { UserId =  10 }, { UserId =  11 } },
		side2 =  { { UserId =  20 }, { UserId =  21 } },
	}
	local data =  MatchData.build(snapshot, "2v2")

	t.it("carries the mode", function()
		t.expect(data.mode).toBe("2v2")
	end)

	t.it("maps side1 to team1 user ids", function()
		t.expect(#data.team1).toBe(2)
		t.expect(data.team1[1]).toBe(10)
		t.expect(data.team1[2]).toBe(11)
	end)

	t.it("maps side2 to team2 user ids", function()
		t.expect(#data.team2).toBe(2)
		t.expect(data.team2[1]).toBe(20)
		t.expect(data.team2[2]).toBe(21)
	end)
end)

t.describe("MatchData.isValid", function()
	t.it("accepts a well-formed payload", function()
		t.expect(MatchData.isValid({ mode =  "1v1", team1 =  { 1 }, team2 =  { 2 } })).toBeTruthy()
	end)

	t.it("rejects a missing team", function()
		t.expect(MatchData.isValid({ mode =  "1v1", team1 =  { 1 } })).toBeFalsy()
	end)

	t.it("rejects a non-table value", function()
		t.expect(MatchData.isValid("nope")).toBeFalsy()
	end)

	t.it("rejects a non-string mode", function()
		t.expect(MatchData.isValid({ mode =  5, team1 =  { 1 }, team2 =  { 2 } })).toBeFalsy()
	end)

	t.it("rejects non-number team entries", function()
		t.expect(MatchData.isValid({ mode =  "1v1", team1 =  { "a" }, team2 =  { 2 } })).toBeFalsy()
	end)

	t.it("rejects an empty team", function()
		t.expect(MatchData.isValid({ mode =  "1v1", team1 =  {}, team2 =  { 2 } })).toBeFalsy()
	end)

	t.it("rejects duplicate user ids across teams", function()
		t.expect(MatchData.isValid({ mode =  "2v2", team1 =  { 1, 2 }, team2 =  { 2, 3 } })).toBeFalsy()
	end)

	t.it("rejects a roster that does not match the mode's per-side count", function()
		t.expect(MatchData.isValid({ mode =  "1v1", team1 =  { 1, 2 }, team2 =  { 3 } })).toBeFalsy()
	end)

	t.it("accepts a balanced 2v2 roster", function()
		t.expect(MatchData.isValid({ mode =  "2v2", team1 =  { 1, 2 }, team2 =  { 3, 4 } })).toBeTruthy()
	end)
end)

t.describe("MatchData.teamOf", function()
	local data =  { mode =  "2v2", team1 =  { 10, 11 }, team2 =  { 20, 21 } }

	t.it("returns 1 for a team1 member", function()
		t.expect(MatchData.teamOf(data, 10)).toBe(1)
	end)

	t.it("returns 2 for a team2 member", function()
		t.expect(MatchData.teamOf(data, 21)).toBe(2)
	end)

	t.it("returns nil for an outsider", function()
		t.expect(MatchData.teamOf(data, 99)).toBe(nil)
	end)
end)

return nil

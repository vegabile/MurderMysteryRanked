local framework =  {}

type TestEntry =  {
	name: string,
	fn: () -> (),
}

local tests: { TestEntry } =  {}
local stack: { string } =  {}

local function describe(name: string, body: () -> ())
	table.insert(stack, name)
	body()
	table.remove(stack)
end

local function it(name: string, body: () -> ())
	local prefix =  if #stack > 0 then table.concat(stack, " > ") .. " > " else ""
	table.insert(tests, { name =  prefix .. name, fn =  body })
end

local function isFiniteNumber(value: any): boolean
	return type(value) = = "number" and value = = value and value ~= math.huge and value ~= -math.huge
end

local function expect(value: any)
	local matcher =  {}

	matcher.toBe =  function(expected)
		if value ~= expected then
			error(string.format("expected %s to be %s", tostring(value), tostring(expected)), 0)
		end
	end

	matcher.toBeCloseTo =  function(expected, tolerance)
		if not isFiniteNumber(value) then
			error(string.format("expected a finite number near %s, got %s", tostring(expected), tostring(value)), 0)
		end
		if math.abs(value - expected) > tolerance then
			error(
				string.format(
					"expected %s to be within %s of %s",
					tostring(value),
					tostring(tolerance),
					tostring(expected)
				),
				0
			)
		end
	end

	matcher.toBeGreaterThan =  function(other)
		if not (value > other) then
			error(string.format("expected %s to be greater than %s", tostring(value), tostring(other)), 0)
		end
	end

	matcher.toBeLessThan =  function(other)
		if not (value < other) then
			error(string.format("expected %s to be less than %s", tostring(value), tostring(other)), 0)
		end
	end

	matcher.toBeGreaterThanOrEqual =  function(other)
		if not (value >= other) then
			error(string.format("expected %s to be greater than or equal to %s", tostring(value), tostring(other)), 0)
		end
	end

	matcher.toBeLessThanOrEqual =  function(other)
		if not (value <= other) then
			error(string.format("expected %s to be less than or equal to %s", tostring(value), tostring(other)), 0)
		end
	end

	matcher.toBeTruthy =  function()
		if not value then
			error(string.format("expected %s to be truthy", tostring(value)), 0)
		end
	end

	matcher.toBeFalsy =  function()
		if value then
			error(string.format("expected %s to be falsy", tostring(value)), 0)
		end
	end

	return matcher
end

local function run(): boolean
	local passed =  0
	local failed =  0
	for _, entry in ipairs(tests) do
		local ok, err =  pcall(entry.fn)
		if ok then
			passed += 1
			print(string.format("PASS  %s", entry.name))
		else
			failed += 1
			print(string.format("FAIL  %s", entry.name))
			print(string.format("        %s", tostring(err)))
		end
	end
	print(string.format("%d passed, %d failed, %d total", passed, failed, #tests))
	return failed = = 0
end

framework.describe =  describe
framework.it =  it
framework.expect =  expect
framework.run =  run

return framework

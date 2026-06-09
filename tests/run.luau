local framework = require("./framework")

require("./glicko2.spec")

if not framework.run() then
	error("Glicko2 test suite failed", 0)
end

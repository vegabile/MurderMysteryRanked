local framework = require("./framework")

require("./glicko2.spec")
require("./queue.spec")

if not framework.run() then
	error("Test suite failed", 0)
end

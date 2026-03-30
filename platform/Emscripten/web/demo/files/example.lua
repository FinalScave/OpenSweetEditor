-- Lua sample

--[[ multi-line comment
      can span multiple lines ]]

local function greet(name)
    print("Hello, " .. name .. "!")
end

-- object-oriented
local Animal = {}
Animal.__index = Animal

function Animal.new(name, sound)
    local self = setmetatable({}, Animal)
    self.name = name
    self.sound = sound
    return self
end

function Animal:speak()
    return self.name .. " says " .. self.sound
end

-- built-in function
local nums = {3, 1, 4, 1, 5}
local len = #nums
local str = tostring(42)
local num = tonumber("3.14")
local tp = type(nums)

for i, v in ipairs(nums) do
    if v > 3 then
        print(v)
    end
end

for k, v in pairs({a = 1, b = 2}) do
    assert(v > 0)
end

-- numeric literal
local hex = 0xFF
local float = 3.14
local sci = 1e10
local zero = 0

-- literal
local flag = true
local off = false
local empty = nil

-- long string
local longStr = [[
this is a
multi-line string
]]

-- string library
local upper = string.upper("hello")
local result = string.format("PI = %.2f", 3.14)
local found = string.find("hello world", "world")

-- math library
local abs = math.abs(-42)
local sqrt = math.sqrt(144)

-- table operation
local t = {10, 20, 30}
table.insert(t, 40)
table.sort(t)

-- pcall error handling
local ok, err = pcall(function()
    error("something went wrong")
end)

-- require module
local json = require("json")

-- select and unpack
local first = select(1, "a", "b", "c")
local a, b = unpack({10, 20})

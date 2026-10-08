local Account = require("models.account")

local Savings = setmetatable({}, { __index = Account })
Savings.__index = Savings

function Savings.new(owner, balance, rate)
  local self = Account.new(owner, balance)
  self.rate = rate
  return setmetatable(self, Savings)
end

function Savings:addInterest()
  local interest = math.floor(self.balance * self.rate)
  if interest > 0 then self:deposit(interest) end
  return interest
end

function Savings:describe()   -- overrides Account:describe
  return string.format("%-8s PHP %d (rate %.0f%%)", self.owner, self.balance, self.rate * 100)
end

return Savings

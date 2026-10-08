local Account = {}
Account.__index = Account

local function validAmount(a)
  return type(a) == "number" and a > 0 and a % 1 == 0
end

function Account.new(owner, balance)
  local self = setmetatable({}, Account)
  self.owner = owner
  self.balance = balance or 0
  self.history = {}
  return self
end

function Account:log(kind, amount)
  self.history[#self.history + 1] = string.format("%s %d", kind, amount)
end

function Account:deposit(amount)
  if not validAmount(amount) then error("Invalid amount", 2) end
  self.balance = self.balance + amount
  self:log("deposit", amount)
end

function Account:withdraw(amount)
  if not validAmount(amount) then error("Invalid amount", 2) end
  if amount > self.balance then error("Insufficient funds in " .. self.owner, 2) end
  self.balance = self.balance - amount
  self:log("withdraw", amount)
end

function Account:describe()
  return string.format("%-8s PHP %d", self.owner, self.balance)
end

return Account

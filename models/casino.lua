local Transaction = require("services.transaction")
local Blackjack   = require("games.blackjack")

local Casino = {}
Casino.__index = Casino

function Casino.new(wallet)
  return setmetatable({ wallet = wallet }, Casino)
end

-- Transaction 1: take the bet and deal. Returns ok, msg, game.
function Casino:startBlackjack(bet)
  local game
  local ok, msg = Transaction.run({ self.wallet }, function()
    self.wallet:withdraw(bet)
    game = Blackjack.new(bet)
  end)
  return ok, msg, game
end

-- Transaction 2: pay out a finished game. Returns ok, msg (msg is nil if nothing was paid).
function Casino:settle(game)
  if game.payout <= 0 then return true, nil end
  return Transaction.run({ self.wallet }, function()
    self.wallet:deposit(game.payout)
  end)
end

return Casino

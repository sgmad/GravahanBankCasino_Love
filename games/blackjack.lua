local Deck = require("models.deck")

-- Event-driven blackjack: LÖVE can't block on io.read(), so the game is an
-- object with a state ("player" -> "done") advanced by hit() and stand().
local Blackjack = {}
Blackjack.__index = Blackjack

function Blackjack.handValue(hand)
  local total, aces = 0, 0
  for _, card in ipairs(hand) do
    local rank = card:sub(1, -2)
    if rank == "A" then
      total = total + 11; aces = aces + 1
    elseif rank == "J" or rank == "Q" or rank == "K" then
      total = total + 10
    else
      total = total + tonumber(rank)
    end
  end
  while total > 21 and aces > 0 do
    total = total - 10; aces = aces - 1
  end
  return total
end
local handValue = Blackjack.handValue

function Blackjack.new(bet)
  local deck = Deck.new()
  local self = setmetatable({
    bet = bet, deck = deck, state = "player",
    player = { deck:draw(), deck:draw() },
    dealer = { deck:draw(), deck:draw() },
    payout = 0, message = "",
  }, Blackjack)
  if handValue(self.player) == 21 then self:stand() end  -- natural: go straight to dealer
  return self
end

function Blackjack:hit()
  if self.state ~= "player" then return end
  self.player[#self.player + 1] = self.deck:draw()
  local pv = handValue(self.player)
  if pv > 21 then
    self.state, self.payout = "done", 0
    self.message = "Bust! You lose PHP " .. self.bet
  elseif pv == 21 then
    self:stand()
  end
end

-- Dealer plays, then the hand is scored. payout = total returned to the player.
function Blackjack:stand()
  if self.state ~= "player" then return end
  local pv, bet = handValue(self.player), self.bet
  while handValue(self.dealer) < 17 do
    self.dealer[#self.dealer + 1] = self.deck:draw()
  end
  local dv = handValue(self.dealer)
  self.state = "done"

  if pv == 21 and #self.player == 2 and dv ~= 21 then
    self.payout, self.message = math.floor(bet * 2.5), "Blackjack! You win PHP " .. math.floor(bet * 1.5)
  elseif dv > 21 or pv > dv then
    self.payout, self.message = bet * 2, "You win PHP " .. bet
  elseif pv == dv then
    self.payout, self.message = bet, "Push. Bet returned."
  else
    self.payout, self.message = 0, "Dealer wins. You lose PHP " .. bet
  end
end

return Blackjack

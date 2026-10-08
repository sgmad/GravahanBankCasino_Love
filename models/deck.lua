local Deck = {}
Deck.__index = Deck

function Deck.new()
  local self = setmetatable({ cards = {} }, Deck)
  local ranks = { "2","3","4","5","6","7","8","9","10","J","Q","K","A" }
  local suits = { "S","H","D","C" }
  for _, s in ipairs(suits) do
    for _, r in ipairs(ranks) do
      self.cards[#self.cards + 1] = r .. s
    end
  end
  self:shuffle()
  return self
end

function Deck:shuffle()
  for i = #self.cards, 2, -1 do
    local j = math.random(i)
    self.cards[i], self.cards[j] = self.cards[j], self.cards[i]
  end
end

function Deck:draw()
  return table.remove(self.cards)
end

return Deck

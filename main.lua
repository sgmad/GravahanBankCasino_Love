local Account     = require("models.account")
local Savings     = require("models.savings")
local Casino      = require("models.casino")
local Blackjack   = require("games.blackjack")
local Transaction = require("services.transaction")
local Storage     = require("services.storage")

local wallet, bank, casino
local screen  = "menu"          -- "menu" | "amount" | "blackjack" | "history"
local input   = nil             -- { kind = "deposit"|"withdraw"|"bet", buf = "" }
local game    = nil
local message, messageOk = "Welcome to Gravahan Bank & Casino.", true
local btns    = {}              -- rebuilt every frame by button()
local font, big, small

-- ---------------------------------------------------------------- logic
local function report(ok, msg)
  message, messageOk = msg, ok
  if ok then Storage.save(wallet, bank) end
end

local function settleIfDone()
  if game and game.state == "done" and not game.settled then
    game.settled = true
    local ok, txmsg = casino:settle(game)
    local text = game.message
    if txmsg then text = text .. "  (" .. txmsg .. ")" end
    report(ok, text)
  end
end

local function openInput(kind)
  input, screen = { kind = kind, buf = "" }, "amount"
end

local function submitInput()
  if not input.buf or input.buf == "" then return end
  local amount, kind = tonumber(input.buf), input.kind
  input, screen = nil, "menu"
  if kind == "deposit" then
    report(Transaction.transfer(wallet, bank, amount))
  elseif kind == "withdraw" then
    report(Transaction.transfer(bank, wallet, amount))
  elseif kind == "bet" then
    local ok, msg, g = casino:startBlackjack(amount)
    if ok then
      game, screen = g, "blackjack"
      report(true, "Bet placed. " .. msg)
      settleIfDone()
    else
      report(false, msg)
    end
  end
end

local function doInterest()
  local earned = 0
  local ok, msg = Transaction.run({ bank }, function() earned = bank:addInterest() end)
  if ok then msg = msg .. " (interest earned: PHP " .. earned .. ")" end
  report(ok, msg)
end

local function hit()   if game then game:hit();   settleIfDone() end end
local function stand() if game then game:stand(); settleIfDone() end end
local function toMenu() screen, game = "menu", nil end

-- ---------------------------------------------------------------- drawing
local function button(label, x, y, w, h, fn, style)
  btns[#btns + 1] = { x = x, y = y, w = w, h = h, fn = fn }
  local mx, my = love.mouse.getPosition()
  local hover = mx >= x and mx <= x + w and my >= y and my <= y + h
  
  love.graphics.setLineWidth(2)
  if style == "casino" then
    love.graphics.setColor(hover and {0.8, 0.2, 0.2} or {0.6, 0.1, 0.1})
    love.graphics.rectangle("fill", x, y, w, h, 24, 24)
    love.graphics.setColor(0.9, 0.8, 0.2)
    love.graphics.rectangle("line", x+4, y+4, w-8, h-8, 20, 20)
    love.graphics.setColor(1, 1, 1)
  elseif style == "bank" then
    love.graphics.setColor(hover and {0.2, 0.3, 0.5} or {0.1, 0.15, 0.25})
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    love.graphics.setColor(0.3, 0.5, 0.8)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)
    love.graphics.setColor(1, 1, 1)
  else
    love.graphics.setColor(hover and {0.4, 0.4, 0.4} or {0.2, 0.2, 0.2})
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    love.graphics.setColor(1, 1, 1)
  end

  love.graphics.setFont(font)
  love.graphics.printf(label, x, y + h / 2 - font:getHeight() / 2, w, "center")
end

local function drawSuitShape(suit, x, y, r)
  if suit == "D" then
    love.graphics.polygon("fill", x, y - r, x + r, y, x, y + r, x - r, y)
  elseif suit == "H" then
    love.graphics.circle("fill", x - r/2, y - r/4, r/2.2)
    love.graphics.circle("fill", x + r/2, y - r/4, r/2.2)
    love.graphics.polygon("fill", x - r, y - r/8, x + r, y - r/8, x, y + r)
  elseif suit == "C" then
    love.graphics.circle("fill", x, y - r/2, r/2.2)
    love.graphics.circle("fill", x - r/2, y + r/8, r/2.2)
    love.graphics.circle("fill", x + r/2, y + r/8, r/2.2)
    love.graphics.polygon("fill", x, y, x - r/3, y + r, x + r/3, y + r)
  elseif suit == "S" then
    love.graphics.polygon("fill", x - r, y + r/8, x + r, y + r/8, x, y - r)
    love.graphics.circle("fill", x - r/2, y + r/8, r/2.2)
    love.graphics.circle("fill", x + r/2, y + r/8, r/2.2)
    love.graphics.polygon("fill", x, y + r/8, x - r/3, y + r, x + r/3, y + r)
  end
end

local function drawCard(card, x, y, hidden)
  -- Shadow
  love.graphics.setColor(0, 0, 0, 0.4)
  love.graphics.rectangle("fill", x + 3, y + 3, 70, 100, 6, 6)

  if hidden then
    love.graphics.setColor(0.6, 0.1, 0.1)
    love.graphics.rectangle("fill", x, y, 70, 100, 6, 6)
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x + 6, y + 6, 58, 88, 4, 4)
    love.graphics.setFont(big)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.printf("?", x, y + 35, 70, "center")
    love.graphics.setFont(font)
    return
  end

  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle("fill", x, y, 70, 100, 6, 6)
  
  local suit = card:sub(-1)
  local rank = card:sub(1, -2)
  local isRed = (suit == "H" or suit == "D")
  
  love.graphics.setColor(isRed and {0.8, 0.1, 0.1} or {0.1, 0.1, 0.1})
  
  -- Rank top left
  love.graphics.setFont(font)
  love.graphics.print(rank, x + 6, y + 4)
  
  -- Small suit shape below rank
  drawSuitShape(suit, x + 12, y + 32, 6)
  
  -- Large suit shape center
  drawSuitShape(suit, x + 35, y + 65, 16)
end

local function drawHand(hand, cx, y, hideSecond)
  local w = #hand * 80 - 10
  local startX = cx - w / 2
  for i, card in ipairs(hand) do
    drawCard(card, startX + (i - 1) * 80, y, hideSecond and i == 2)
  end
end

local function drawLobby()
  -- Bank Terminal Side
  love.graphics.setColor(0.08, 0.12, 0.18)
  love.graphics.rectangle("fill", 40, 60, 340, 420, 8, 8)
  love.graphics.setColor(0.3, 0.5, 0.8)
  love.graphics.setFont(big)
  love.graphics.printf("GRAVAHAN BANK", 40, 80, 340, "center")
  
  love.graphics.setFont(small)
  love.graphics.setColor(0.6, 0.7, 0.8)
  love.graphics.printf("ACCOUNT BALANCE", 40, 120, 340, "center")
  love.graphics.setFont(big)
  love.graphics.setColor(0.4, 0.9, 0.5)
  love.graphics.printf("PHP " .. bank.balance, 40, 140, 340, "center")
  
  button("Deposit", 70, 200, 280, 45, function() openInput("deposit") end, "bank")
  button("Withdraw", 70, 260, 280, 45, function() openInput("withdraw") end, "bank")
  button("Collect Interest ("..string.format("%.0f%%", bank.rate * 100)..")", 70, 320, 280, 45, doInterest, "bank")
  button("Ledger History", 70, 380, 280, 45, function() screen = "history" end, "bank")

  -- Casino Felt Side
  love.graphics.setColor(0.05, 0.25, 0.12)
  love.graphics.rectangle("fill", 420, 60, 340, 420, 8, 8)
  love.graphics.setColor(0.9, 0.8, 0.2)
  love.graphics.setFont(big)
  love.graphics.printf("CASINO FLOOR", 420, 80, 340, "center")

  love.graphics.setFont(small)
  love.graphics.setColor(0.7, 0.8, 0.7)
  love.graphics.printf("WALLET BALANCE", 420, 120, 340, "center")
  love.graphics.setFont(big)
  love.graphics.setColor(0.9, 0.8, 0.2)
  love.graphics.printf("PHP " .. wallet.balance, 420, 140, 340, "center")

  button("Play Blackjack", 450, 240, 280, 60, function() openInput("bet") end, "casino")

  -- System
  button("Exit System", 300, 500, 200, 40, function() love.event.quit() end, "neutral")
end

local function drawAmount()
  local isBank = (input.kind == "deposit" or input.kind == "withdraw")
  local titles = { deposit = "DEPOSIT FUNDS", withdraw = "WITHDRAW FUNDS", bet = "PLACE YOUR BET" }
  local caret = (math.floor(love.timer.getTime() * 2) % 2 == 0) and "_" or ""

  if isBank then
    love.graphics.setColor(0.08, 0.12, 0.18)
    love.graphics.rectangle("fill", 200, 150, 400, 260, 8, 8)
    love.graphics.setColor(0.3, 0.5, 0.8)
    love.graphics.setFont(big)
    love.graphics.printf(titles[input.kind], 200, 180, 400, "center")
    
    love.graphics.setColor(0.05, 0.08, 0.12)
    love.graphics.rectangle("fill", 240, 230, 320, 50, 4, 4)
    love.graphics.setColor(0.4, 0.9, 0.5)
    love.graphics.printf("PHP " .. input.buf .. caret, 250, 243, 300, "left")

    button("Confirm", 240, 310, 150, 45, submitInput, "bank")
    button("Cancel", 410, 310, 150, 45, function() input, screen = nil, "menu" end, "neutral")
  else
    -- Casino Chip placement style
    love.graphics.setColor(0.05, 0.25, 0.12)
    love.graphics.rectangle("fill", 200, 150, 400, 260, 8, 8)
    love.graphics.setColor(0.9, 0.8, 0.2)
    love.graphics.setFont(big)
    love.graphics.printf(titles[input.kind], 200, 180, 400, "center")

    love.graphics.setColor(0.03, 0.15, 0.08)
    love.graphics.circle("fill", 400, 255, 45)
    love.graphics.setColor(0.9, 0.8, 0.2)
    love.graphics.circle("line", 400, 255, 45)
    love.graphics.setFont(font)
    love.graphics.printf("PHP\n" .. input.buf .. caret, 350, 240, 100, "center")

    button("Deal", 240, 330, 150, 45, submitInput, "casino")
    button("Cancel", 410, 330, 150, 45, function() input, screen = nil, "menu" end, "neutral")
  end
end

local function drawBlackjack()
  local done = game.state == "done"
  
  -- Felt Background
  love.graphics.clear(0.04, 0.20, 0.10)

  -- Dealer Zone Arc
  love.graphics.setLineWidth(4)
  love.graphics.setColor(0.9, 0.8, 0.2, 0.3)
  love.graphics.arc("line", "open", 400, -20, 350, 0, math.pi)
  
  love.graphics.setColor(0.9, 0.8, 0.2)
  love.graphics.setFont(font)
  love.graphics.printf(done and ("Dealer (" .. Blackjack.handValue(game.dealer) .. ")") or "Dealer Shows", 0, 50, 800, "center")
  drawHand(game.dealer, 400, 80, not done)

  -- Betting Circle
  love.graphics.setLineWidth(2)
  love.graphics.setColor(0.9, 0.8, 0.2, 0.5)
  love.graphics.circle("line", 400, 260, 40)
  love.graphics.setColor(0.9, 0.8, 0.2)
  love.graphics.setFont(small)
  love.graphics.printf("BET\n" .. game.bet, 360, 245, 80, "center")

  -- Player Zone
  love.graphics.setFont(font)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("Player (" .. Blackjack.handValue(game.player) .. ")", 0, 320, 800, "center")
  drawHand(game.player, 400, 350, false)

  if done then
    button("Leave Table", 300, 480, 200, 50, toMenu, "neutral")
  else
    button("Hit (H)", 240, 480, 150, 50, hit, "casino")
    button("Stand (S)", 410, 480, 150, 50, stand, "bank") -- using bank style just for contrasting blue color
  end
end

local function drawHistory()
  -- Printed Ledger Layout
  love.graphics.clear(0.9, 0.9, 0.9) -- Paper white
  
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.setFont(big)
  love.graphics.printf("GRAVAHAN OFFICIAL LEDGER", 0, 40, 800, "center")
  
  love.graphics.setFont(font)
  for c, acc in ipairs({ wallet, bank }) do
    local x = 60 + (c - 1) * 350
    love.graphics.setColor(0.2, 0.3, 0.5)
    love.graphics.rectangle("fill", x, 90, 330, 36)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(string.upper(acc.owner) .. " ACCOUNT", x, 98, 330, "center")
    
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.setFont(small)
    if #acc.history == 0 then love.graphics.print("(No transactions recorded)", x + 20, 140) end
    
    local first = math.max(1, #acc.history - 15)
    for i = first, #acc.history do
      love.graphics.print(string.format("%04d | %s", i, acc.history[i]), x + 20, 140 + (i - first) * 22)
    end
  end
  
  button("Return", 320, 500, 160, 46, function() screen = "menu" end, "neutral")
end

-- ---------------------------------------------------------------- LÖVE callbacks
function love.load()
  math.randomseed(os.time())
  font  = love.graphics.newFont(18)
  big   = love.graphics.newFont(26)
  small = love.graphics.newFont(14)

  local data = Storage.load()
  wallet = Account.new("Wallet", data.wallet)
  bank   = Savings.new("Bank", data.bank, 0.05)
  casino = Casino.new(wallet)
end

function love.draw()
  btns = {}
  love.graphics.clear(0.05, 0.06, 0.08)

  if     screen == "menu"      then drawLobby()
  elseif screen == "amount"    then drawAmount()
  elseif screen == "blackjack" then drawBlackjack()
  elseif screen == "history"   then drawHistory() end

  -- Status line at bottom
  if screen ~= "blackjack" and screen ~= "history" then
    love.graphics.setFont(small)
    love.graphics.setColor(messageOk and { 0.4, 0.9, 0.5 } or { 1, 0.45, 0.45 })
    love.graphics.printf(message, 40, 560, 720, "left")
  elseif screen == "blackjack" then
    love.graphics.setFont(font)
    love.graphics.setColor(messageOk and { 0.9, 0.8, 0.2 } or { 1, 0.4, 0.4 })
    love.graphics.printf(message, 0, 550, 800, "center")
  end
end

function love.mousepressed(x, y, buttonClick)
  if buttonClick ~= 1 then return end
  for i = #btns, 1, -1 do
    local b = btns[i]
    if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then b.fn(); return end
  end
end

function love.textinput(t)
  if input and t:match("^%d$") and #input.buf < 9 then input.buf = input.buf .. t end
end

function love.keypressed(key)
  if screen == "amount" then
    if key == "backspace" then input.buf = input.buf:sub(1, -2)
    elseif key == "return" or key == "kpenter" then submitInput()
    elseif key == "escape" then input, screen = nil, "menu" end
  elseif screen == "blackjack" and game then
    if game.state == "player" then
      if key == "h" then hit() elseif key == "s" then stand() end
    elseif key == "return" or key == "escape" then toMenu() end
  elseif screen == "history" and (key == "escape" or key == "return") then
    screen = "menu"
  end
end

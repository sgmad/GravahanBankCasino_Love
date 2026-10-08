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
      settleIfDone()                      -- handles an instant natural blackjack
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
local function button(label, x, y, w, h, fn)
  btns[#btns + 1] = { x = x, y = y, w = w, h = h, fn = fn }
  local mx, my = love.mouse.getPosition()
  local hover = mx >= x and mx <= x + w and my >= y and my <= y + h
  love.graphics.setColor(hover and { 0.30, 0.50, 0.80 } or { 0.20, 0.32, 0.55 })
  love.graphics.rectangle("fill", x, y, w, h, 6, 6)
  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(font)
  love.graphics.printf(label, x, y + h / 2 - font:getHeight() / 2, w, "center")
end

local function drawCard(card, x, y, hidden)
  if hidden then
    love.graphics.setColor(0.2, 0.3, 0.6)
    love.graphics.rectangle("fill", x, y, 56, 80, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("?", x, y + 28, 56, "center")
    return
  end
  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle("fill", x, y, 56, 80, 6, 6)
  local suit = card:sub(-1)
  if suit == "H" or suit == "D" then love.graphics.setColor(0.8, 0.1, 0.1)
  else love.graphics.setColor(0.1, 0.1, 0.1) end
  love.graphics.printf(card, x, y + 28, 56, "center")
end

local function drawHand(hand, x, y, hideSecond)
  for i, card in ipairs(hand) do
    drawCard(card, x + (i - 1) * 64, y, hideSecond and i == 2)
  end
end

local function drawBalances()
  love.graphics.setColor(0.12, 0.14, 0.2)
  love.graphics.rectangle("fill", 40, 80, 720, 90, 8, 8)
  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(font)
  love.graphics.print("Wallet", 60, 98);  love.graphics.print("PHP " .. wallet.balance, 200, 98)
  love.graphics.print("Bank",   60, 132)
  love.graphics.print("PHP " .. bank.balance .. "  (rate " .. string.format("%.0f%%", bank.rate * 100) .. ")", 200, 132)
end

local function drawMenu()
  local labels = {
    { "Deposit to Bank",    function() openInput("deposit")  end },
    { "Withdraw from Bank", function() openInput("withdraw") end },
    { "Play Blackjack",     function() openInput("bet")      end },
    { "Collect Interest",   doInterest },
    { "History",            function() screen = "history" end },
    { "Quit",               function() love.event.quit() end },
  }
  for i, b in ipairs(labels) do
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    button(b[1], 40 + col * 370, 200 + row * 70, 350, 54, b[2])
  end
end

local function drawAmount()
  local titles = { deposit = "DEPOSIT TO BANK", withdraw = "WITHDRAW FROM BANK", bet = "BLACKJACK" }
  local prompts = { deposit = "Amount: PHP ", withdraw = "Amount: PHP ", bet = "Bet: PHP " }
  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(big)
  love.graphics.print(titles[input.kind], 40, 200)
  love.graphics.setFont(font)
  local caret = (math.floor(love.timer.getTime() * 2) % 2 == 0) and "_" or ""
  love.graphics.print(prompts[input.kind] .. input.buf .. caret, 40, 260)
  button("Confirm", 40, 320, 170, 50, submitInput)
  button("Cancel", 230, 320, 170, 50, function() input, screen = nil, "menu" end)
end

local function drawBlackjack()
  local done = game.state == "done"
  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(big)
  love.graphics.print("BLACKJACK   (bet PHP " .. game.bet .. ")", 40, 190)
  love.graphics.setFont(font)

  love.graphics.print(done and ("Dealer (" .. Blackjack.handValue(game.dealer) .. ")") or "Dealer shows", 40, 240)
  drawHand(game.dealer, 40, 265, not done)

  love.graphics.setColor(1, 1, 1)
  love.graphics.print("You (" .. Blackjack.handValue(game.player) .. ")", 40, 360)
  drawHand(game.player, 40, 385, false)

  if done then
    button("Back to Menu", 40, 490, 200, 50, toMenu)
  else
    button("Hit (H)",    40, 490, 200, 50, hit)
    button("Stand (S)", 260, 490, 200, 50, stand)
  end
end

local function drawHistory()
  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(big)
  love.graphics.print("HISTORY", 40, 190)
  love.graphics.setFont(small)
  for c, acc in ipairs({ wallet, bank }) do
    local x = 40 + (c - 1) * 370
    love.graphics.setColor(0.6, 0.8, 1)
    love.graphics.print("-- " .. acc.owner .. " --", x, 235)
    love.graphics.setColor(1, 1, 1)
    if #acc.history == 0 then love.graphics.print("(no transactions)", x, 258) end
    local first = math.max(1, #acc.history - 11)       -- show the latest 12
    for i = first, #acc.history do
      love.graphics.print(i .. "   " .. acc.history[i], x, 258 + (i - first) * 20)
    end
  end
  button("Back", 40, 520, 160, 46, function() screen = "menu" end)
end

-- ---------------------------------------------------------------- LÖVE callbacks
function love.load()
  math.randomseed(os.time())
  font  = love.graphics.newFont(18)
  big   = love.graphics.newFont(26)
  small = love.graphics.newFont(15)

  local data = Storage.load()
  wallet = Account.new("Wallet", data.wallet)
  bank   = Savings.new("Bank", data.bank, 0.05)
  casino = Casino.new(wallet)
end

function love.draw()
  btns = {}
  love.graphics.clear(0.07, 0.08, 0.12)
  love.graphics.setColor(1, 0.85, 0.3)
  love.graphics.setFont(big)
  love.graphics.printf("GRAVAHAN BANK & CASINO", 0, 24, 800, "center")

  drawBalances()
  if     screen == "menu"      then drawMenu()
  elseif screen == "amount"    then drawAmount()
  elseif screen == "blackjack" then drawBlackjack()
  elseif screen == "history"   then drawHistory() end

  -- status line (green = committed, red = rolled back)
  love.graphics.setFont(small)
  love.graphics.setColor(messageOk and { 0.4, 0.9, 0.5 } or { 1, 0.45, 0.45 })
  love.graphics.printf(message, 40, 560, 720, "left")
end

function love.mousepressed(x, y, button)
  if button ~= 1 then return end
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

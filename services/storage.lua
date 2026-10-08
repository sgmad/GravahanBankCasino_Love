-- Uses love.filesystem, which writes to LÖVE's per-game save folder.
local Storage = {}
local SAVE_FILE = "bankcasino.sav"

function Storage.save(wallet, bank)
  local text = string.format("wallet=%d\nbank=%d\n", wallet.balance, bank.balance)
  assert(love.filesystem.write(SAVE_FILE, text))
end

function Storage.load()
  local data = { wallet = 500, bank = 1000 }
  if love.filesystem.getInfo(SAVE_FILE) then
    local text = love.filesystem.read(SAVE_FILE)
    for key, val in text:gmatch("(%w+)=(%d+)") do
      data[key] = tonumber(val)
    end
  end
  return data
end

return Storage

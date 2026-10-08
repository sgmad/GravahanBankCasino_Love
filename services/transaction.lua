local Transaction = {}

-- Closure: private counter, not visible outside this module
local function makeCounter()
  local count = 0
  return function() count = count + 1; return count end
end
local nextTxId = makeCounter()

function Transaction.run(accounts, action)
  local id = nextTxId()
  local snap = {}
  for i, acc in ipairs(accounts) do
    snap[i] = { balance = acc.balance, n = #acc.history }
  end

  local ok, err = pcall(action)
  if not ok then
    for i, acc in ipairs(accounts) do          -- rollback
      acc.balance = snap[i].balance
      for j = #acc.history, snap[i].n + 1, -1 do acc.history[j] = nil end
    end
    return false, "Transaction #" .. id .. " rolled back: " .. tostring(err)
  end
  return true, "Transaction #" .. id .. " committed"
end

function Transaction.transfer(from, to, amount)
  return Transaction.run({ from, to }, function()
    from:withdraw(amount)
    to:deposit(amount)
  end)
end

return Transaction

function on_login(event)
  local fullJSON = event:serialize("json")
  freeswitch.consoleLog("warning", "Весь ивент: " .. fullJSON .. "\n")
end

-- Подписываемся на событие sofia::register и начинаем обработку
local eventConsumer = freeswitch.EventConsumer("CUSTOM", "verto::login")
while true do
  local event = eventConsumer:pop(1)
  if event then
      on_login(event)
  end
end

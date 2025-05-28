function on_disconnect(event)
  local fullJSON = event:serialize("json")
  freeswitch.consoleLog("warning", "Весь ивент: " .. fullJSON .. "\n")
end

-- Подписываемся на событие sofia::register и начинаем обработку
local eventConsumer = freeswitch.EventConsumer("CUSTOM", "verto::client_disconnect")
while true do
  local event = eventConsumer:pop(1)
  if event then
      on_disconnect(event)
  end
end

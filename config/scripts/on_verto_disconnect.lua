function on_disconnect(event)
  local fullJSON = event:serialize("json")
  freeswitch.consoleLog("warning", "Весь ивент: " .. fullJSON .. "\n")

  local verto_login = event:getHeader("verto_login")
  if not(verto_login) then
    return
  end

  local uuid = event:getHeader("Core-UUID")

  local login =  string.match(verto_login, "([^@]+)@?")
  if not(login) then
    freeswitch.consoleLog("warning", "Login not match in event:" .. fullJSON .. "\n")
    return
  end
  freeswitch.consoleLog("warning", "login: " .. login .. "\n")

  local agent_name = login .. string.sub(uuid, 1, 5)

  -- Команда для добавления агента с использованием контакта из регистрации
  local del_agent_cmd = string.format("callcenter_config agent del %s", agent_name)
  freeswitch.consoleLog("info", "Удаление агента: " .. del_agent_cmd .. "\n")
  api = freeswitch.API()
  api:executeString(del_agent_cmd)
end

-- Подписываемся на событие sofia::register и начинаем обработку
local eventConsumer = freeswitch.EventConsumer("CUSTOM", "verto::client_disconnect")
while true do
  local event = eventConsumer:pop(1)
  if event then
      on_disconnect(event)
  end
end

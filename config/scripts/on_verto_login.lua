function on_login(event)
  api = freeswitch.API()

  local fullJSON = event:serialize("json")
  freeswitch.consoleLog("warning", "Весь ивент: " .. fullJSON .. "\n")

  local verto_login = event:getHeader("verto_login")
  if not(verto_login) then
    return
  end

  local uuid = event:getHeader("Core-UUID")

  local login =  string.match(verto_login, "([^@]+)@")
  freeswitch.consoleLog("warning", "login: " .. login .. "\n")

  local agent_name = login .. string.sub(uuid, 1, 5)

  local queue_name = login .. "@default"
  freeswitch.consoleLog("warning", "queue_name: " .. queue_name .. "\n")


  contact = api:executeString("verto_contact " .. login)

  if contact == "error/user_not_registered" then
    return
  end

  freeswitch.consoleLog("warning", "contact: " .. contact .. "\n")

  -- Команда для добавления агента с использованием контакта из регистрации
  local add_agent_cmd = string.format("callcenter_config agent add %s callback", agent_name)
  freeswitch.consoleLog("info", "Добавление агента: " .. add_agent_cmd .. "\n")
  api:executeString(add_agent_cmd)

  local set_contact_cmd = string.format("callcenter_config agent set contact %s %s", agent_name, contact)
  freeswitch.consoleLog("info", "Ставим контакт: " .. set_contact_cmd .. "\n")
  api:executeString(set_contact_cmd)

  local set_status_cmd = string.format("callcenter_config agent set status %s Available", agent_name)
  freeswitch.consoleLog("info", "Ставим статус: " .. set_status_cmd .. "\n")
  api:executeString(set_status_cmd)

  -- Добавление агента в очередь
  local add_to_queue_cmd = string.format("callcenter_config tier add %s %s 1 1", queue_name, agent_name)
  freeswitch.consoleLog("info", "Добавление агента в очередь: " .. add_to_queue_cmd .. "\n")
  api:executeString(add_to_queue_cmd)

  -- Планируем удаление агента и уровня через 1 час
  local delete_agent_cmd = string.format("sched_api +3600 none callcenter_config agent del %s", agent_name)
  freeswitch.consoleLog("info", "Запланировано удаление агента: " .. delete_agent_cmd .. "\n")
  api:executeString(delete_agent_cmd)

  local delete_tier_cmd = string.format("sched_api +3600 none callcenter_config tier del %s %s", queue_name, agent_name)
  freeswitch.consoleLog("info", "Запланировано удаление уровня: " .. delete_tier_cmd .. "\n")
  api:executeString(delete_tier_cmd)
end

-- Подписываемся на событие sofia::register и начинаем обработку
local eventConsumer = freeswitch.EventConsumer("CUSTOM", "verto::login")
while true do
  local event = eventConsumer:pop(1)
  if event then
      on_login(event)
  end
end

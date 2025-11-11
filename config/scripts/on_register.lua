function on_register(event)
  local fullJSON = event:serialize("json")
  freeswitch.consoleLog("warning", "Весь ивент: " .. fullJSON .. "\n")

  local sip_user = event:getHeader("from-user")
  freeswitch.consoleLog("warning", string.format("Sip User: %s", sip_user))
  local domain = event:getHeader("from-host")
  local contact = event:getHeader("contact")
  freeswitch.consoleLog("warning", string.format("Contact Before: %s", contact))
  contact = string.gsub(convert_sip_string(contact), "ws;", "wss;")
  freeswitch.consoleLog("warning", string.format("Contact After: %s", contact))
  
  local call_id = contact
  local agent_name = sip_user .. "(" .. call_id .. ")" .. "@default"
  local queue_name = sip_user .. "@default"
  
  local user_type = event:getHeader("X-Doma-AI-Type")
  if not (user_type) then
    return
  end
  freeswitch.consoleLog("warning", string.format("User Type: %s", user_type))

  local is_apartment = user_type:match("apartment")
  freeswitch.consoleLog("warning", string.format("Is apartment: %s", is_apartment))

  if not (is_apartment) then
      return
  end

  api = freeswitch.API()

  -- Команда для создания очереди
  -- local create_queue_cmd = string.format("callcenter_config queue add %s", queue_name)
  -- freeswitch.consoleLog("info", "Создание очереди: " .. create_queue_cmd .. "\n")
  -- api:executeString(create_queue_cmd)

  -- Устанавливаем параметры очереди
  -- local queue_params = {
  --     {"strategy", "ring-all"},
  --     {"moh-sound", "$${hold_music}"},
  --     {"time-base-score", "system"},
  --     {"max-wait-time", "120"},
  --     {"max-wait-time-with-no-agent", "0"},
  --     {"max-wait-time-with-no-agent-time-reached", "0"},
  --     {"tier-rules-apply", "false"},
  --     {"tier-rule-wait-second", "300"},
  --     {"tier-rule-wait-multiply-level", "false"},
  --     {"tier-rule-no-agent-no-wait", "false"},
  --     {"discard-abandoned-after", "60"},
  --     {"abandoned-resume-allowed", "false"}
  -- }

  -- for _, param in ipairs(queue_params) do
  --     local set_param_cmd = string.format("callcenter_config queue set %s %s %s", queue_name, param[1], param[2])
  --     freeswitch.consoleLog("info", "Установка параметра очереди: " .. set_param_cmd .. "\n")
  --     api:executeString(set_param_cmd)
  -- end

  -- Команда для добавления агента с использованием контакта из регистрации
  local add_agent_cmd = string.format("callcenter_config agent add %s callback", agent_name)
  freeswitch.consoleLog("info", "Добавление агента: " .. add_agent_cmd .. "\n")
  api:executeString(add_agent_cmd)

  local set_contact_cmd = string.format("callcenter_config agent set contact %s %s", agent_name, convert_sip_string(contact))
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

function convert_sip_string(original_string)
  local user, host_port, params = original_string:match("sip:(.+)@([%d%.]+:%d+);([^>]+)")
  
  if not (user and host_port and params) then
      error('Ошибка: Невозможно извлечь необходимые данные из исходной строки.')
  end
  
  return "sofia/internal/sip:" .. user .. "@" .. host_port .. ";" .. params
end

-- Подписываемся на событие sofia::register и начинаем обработку
local eventConsumer = freeswitch.EventConsumer("CUSTOM", "sofia::register")
while true do
  local event = eventConsumer:pop(1)
  if event then
      on_register(event)
  end
end

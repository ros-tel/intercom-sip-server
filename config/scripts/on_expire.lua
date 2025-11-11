
function on_unregister(event)
  local fullJSON = event:serialize("json")

  local sip_user = event:getHeader("user")
  local contact = event:getHeader("contact")
  contact = string.gsub(convert_sip_string(contact), "ws;", "wss;")
  local call_id = contact
  local agent_name = sip_user .. "(" .. call_id .. ")" .. "@default" 

  
  local user_type = event:getHeader("X-Doma-AI-Type")
  if not (user_type) then
    return
  end
  freeswitch.consoleLog("warning", string.format( "User Type: %s", user_type))

  local is_apartment = user_type:match("apartment")

  if not (is_apartment) then
    return
  end

  -- Команда для добавления агента с использованием контакта из регистрации
  local del_agent_cmd = string.format("callcenter_config agent del %s", agent_name)
  freeswitch.consoleLog("info", "Удаление агента: " .. del_agent_cmd .. "\n")
  api = freeswitch.API()
  api:executeString(del_agent_cmd)

end

function convert_sip_string(original_string)
  local user, host_port, params = original_string:match("sip:(.+)@([%d%.]+:%d+);([^>]+)")

  if not (user and host_port and params) then
    throw('Ошибка: Невозможно извлечь необходимые данные из исходной строки.')  
  end

  return "sofia/internal/sip:" .. user .. "@" .. host_port .. ";" .. params
end

local eventConsumer = freeswitch.EventConsumer("CUSTOM", "sofia::expire")
while true do
  local event = eventConsumer:pop(1)
  if event then
      on_unregister(event)
  end
end

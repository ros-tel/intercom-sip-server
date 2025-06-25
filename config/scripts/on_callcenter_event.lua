-- Извлекаем информацию из события
local action = event:getHeader("CC-Action")
local caller = event:getHeader("CC-Member-CID-Number")
local queue = event:getHeader("CC-Queue")
local agent = event:getHeader("CC-Agent")
local cause = event:getHeader("CC-Cause")

local cmd = "/dev/null"


if action == "member-queue-start" then
    cmd = string.format(
  "sh /usr/local/freeswitch/scripts/sh/on_join.sh \"%s\" \"%s\"",
  caller:gsub('([%(%)])', '\\%1'), 
  queue:gsub('@default$', '') 
)

    os.execute(cmd)
end
if action == "member-queue-end" then
    cmd = string.format("sh /usr/local/freeswitch/scripts/sh/on_decline.sh \"%s\" \"%s\" \"%s\"", caller:gsub('([%(%)])', '\\%1'), queue:gsub('([%(%)])', '\\%1'), cause:gsub('([%(%)])', '\\%1'))

    os.execute(cmd)
end
if action == "bridge-agent-start" then
    freeswitch.consoleLog("NOTICE", string.format("sh /usr/local/freeswitch/scripts/sh/on_bridge.sh \"%s\" \"%s\" \"%s\"\n", caller:gsub('([%(%)])', '\\%1'), agent:gsub('([%(%)])', '\\%1'), queue:gsub('([%(%)])', '\\%1')))
    cmd = string.format("sh /usr/local/freeswitch/scripts/sh/on_bridge.sh \"%s\" \"%s\" \"%s\"", caller:gsub('([%(%)])', '\\%1'), agent:gsub('([%(%)])', '\\%1'), queue:gsub('([%(%)])', '\\%1'))

    os.execute(cmd)
end

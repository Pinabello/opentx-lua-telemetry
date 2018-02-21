--
-- KISS/SPORT code
--
-- Based on Betaflight LUA script
--
-- Kiss version by Alex Fedorov aka FedorComander


-- SPORT BEGIN

SPORT_KISS_VERSION = bit32.lshift(1,5)
SPORT_KISS_STARTFLAG = bit32.lshift(1,4)
LOCAL_SENSOR_ID  = 0x0D
REMOTE_SENSOR_ID = 0x1B
REQUEST_FRAME_ID = 0x30
REPLY_FRAME_ID   = 0x32

-- Sequence number for next KISS/SPORT packet
local sportKissSeq = 0
local sportKissRemoteSeq = 0

local kissRxBuf = {}
local kissRxIdx = 1
local kissRxCRC = 0
local kissStarted = false
local kissLastReq = 0
local kissTxBuf = {}
local kissTxIdx = 1
local kissTxCRC = 0
local kissTxPk = 0

local function isTelemetryPresent()
  return getValue("RSSI")>0
end

local function subrange(t, first, last)
  local sub = {}
  for i=first,last do
    sub[#sub + 1] = t[i]
  end
  return sub
end

local function kissSendSport(payload)
  local dataId = 0
  dataId = payload[1] + bit32.lshift(payload[2],8)

  local value = 0
  value = payload[3] + bit32.lshift(payload[4],8)
    + bit32.lshift(payload[5],16) + bit32.lshift(payload[6],24)

  local ret = sportTelemetryPush(LOCAL_SENSOR_ID, REQUEST_FRAME_ID, dataId, value)
  if ret then
    kissTxPk = kissTxPk + 1
  end
end

local function kissProcessTxQ()

  if (#(kissTxBuf) == 0) then
    return false
  end

  if not sportTelemetryPush() then
    return true
  end

  local payload = {}
  payload[1] = sportKissSeq + SPORT_KISS_VERSION
  sportKissSeq = bit32.band(sportKissSeq + 1, 0x0F)

  if kissTxIdx == 1 then
    -- start flag
    payload[1] = payload[1] + SPORT_KISS_STARTFLAG
	print(payload[1])
  end

  local i = 2
  while (i <= 6) do
    payload[i] = kissTxBuf[kissTxIdx]
    kissTxIdx = kissTxIdx + 1
    i = i + 1
    if kissTxIdx > #(kissTxBuf) then
      break
    end
  end

  if i <= 6 then
    while i <= 6 do
      payload[i] = 0
      i = i + 1
    end
    kissSendSport(payload)
    kissTxBuf = {}
    kissTxIdx = 1
    return false
  else
    kissSendSport(payload)
    if kissTxIdx > #(kissTxBuf) then
      kissTxBuf = {}
      kissTxIdx = 1
      return false
    else
      return true
    end
  end
end

local function kissSendRequest(cmd, payload)
  -- busy
  if #(kissTxBuf) ~= 0 then
    return nil
  end

  local crc = 0

  kissTxBuf[1] = bit32.band(cmd,0xFF)  -- KISS command
  kissTxBuf[2] = bit32.band(#(payload), 0xFF) -- KISS payload size

  for i=1,#(payload) do
    kissTxBuf[i+2] = payload[i]
    crc = bit32.bxor(crc, payload[i]);
    for i=1,8 do
      if bit32.band(crc, 0x80) ~= 0 then
        crc = bit32.bxor(bit32.lshift(crc, 1), 0xD5)
      else
        crc = bit32.lshift(crc, 1)
      end
      crc = bit32.band(crc, 0xFF)
    end
  end
  kissTxBuf[#(payload)+3] = crc
  kissLastReq = cmd
  return kissProcessTxQ()
end

local function kissReceivedReply(payload)

  local idx      = 1
  local head     = payload[idx]
  local err_flag = (bit32.band(head,0x20) ~= 0)
  idx = idx + 1

  if err_flag then
    -- error flag set
    kissStarted = false
    return nil
  end

  local start = (bit32.band(head,0x10) ~= 0)
  local seq   = bit32.band(head,0x0F)

  if start then
    -- start flag set
    kissRxIdx = 1
    kissRxBuf = {}

    kissRxSize = payload[idx + 1] + 3
    kissRxCRC  = 0
    kissStarted = true

  elseif not kissStarted then
    return nil

  elseif bit32.band(sportKissRemoteSeq + 1, 0x0F) ~= seq then
    kissStarted = false
    return nil
  end

  while (idx <= 6) and (kissRxIdx <= kissRxSize) do
    kissRxBuf[kissRxIdx] = payload[idx]
    if (kissRxIdx>2) and (kissRxIdx < kissRxSize) then
      kissRxCRC = bit32.bxor(kissRxCRC, payload[idx]);
      for i=1,8 do
        if bit32.band(kissRxCRC, 0x80) ~= 0 then
          kissRxCRC = bit32.bxor(bit32.lshift(kissRxCRC, 1), 0xD5)
        else
          kissRxCRC = bit32.lshift(kissRxCRC, 1)
        end
        kissRxCRC = bit32.band(kissRxCRC, 0xFF)
      end
    end
    kissRxIdx = kissRxIdx + 1
    idx = idx + 1
  end

  if kissRxIdx <= kissRxSize then
    sportKissRemoteSeq = seq
    return true
  end

  if kissRxSize>3 then
    if kissRxCRC ~= kissRxBuf[kissRxSize] then
      kissStarted = false
      return nil
    end
  end

  kissStarted = false
  return subrange(kissRxBuf, 3, kissRxSize-1)
end

local function kissPollReply()
  while true do
    local sensorId, frameId, dataId, value = sportTelemetryPop()

    if sensorId == REMOTE_SENSOR_ID and frameId == REPLY_FRAME_ID then

      local payload = {}
      payload[1] = bit32.band(dataId,0xFF)
      dataId = bit32.rshift(dataId,8)
      payload[2] = bit32.band(dataId,0xFF)

      payload[3] = bit32.band(value,0xFF)
      value = bit32.rshift(value,8)
      payload[4] = bit32.band(value,0xFF)
      value = bit32.rshift(value,8)
      payload[5] = bit32.band(value,0xFF)
      value = bit32.rshift(value,8)
      payload[6] = bit32.band(value,0xFF)

      local ret = kissReceivedReply(payload)
      if type(ret) == "table" then
        return kissLastReq,ret
      end
    else
      break
    end
  end

  return nil
end

-- SPORT END

-- BEGIN X9

RADIO = "X9"

local drawScreenTitle = function(title, currentPage, totalPages)
	lcd.drawScreenTitle('Kiss Setup:  '..title, currentPage, totalPages)
end

local drawTelemetry = function()
	lcd.drawText(75,55,"No telemetry",BLINK)
end

local drawSaving = function() 
	lcd.drawFilledRectangle(40,12,120,30,ERASE)
	lcd.drawRectangle(40,12,120,30,SOLID)
	lcd.drawText(64,18,"Saving...", DBLSIZE + BLINK)
end

local function drawMenu(menuList, menuActive)
   local x = 40
   local y = 12
   local w = 120
   local h = #(menuList) * 8 + 6
   lcd.drawFilledRectangle(x,y,w,h,ERASE)
   lcd.drawRectangle(x,y,w-1,h-1,SOLID)
   lcd.drawText(x+4,y+3,"Menu:")

   for i,e in ipairs(menuList) do
      if menuActive == i then
         lcd.drawText(x+36,y+(i-1)*8+3,e.t,INVERS)
      else
         lcd.drawText(x+36,y+(i-1)*8+3,e.t)
      end
   end
end

local function getDefaultTextOptions() 
	return 0
end

local EVT_MENU_LONG = bit32.bor(bit32.band(EVT_MENU_BREAK,0x1f),0x80)

-- END X9
-- BEGIN UI

local currentPage = 6
local currentLine = 1
local saveTS = 0
local saveTimeout = 0
local saveRetries = 0
local saveMaxRetries = 0

local REQ_TIMEOUT = 200 -- 1000ms request timeout

--local PAGE_REFRESH = 1
local PAGE_DISPLAY = 2
local EDITING      = 3
local PAGE_SAVING  = 4
local MENU_DISP    = 5

local telemetryScreenActive = false
local menuActive = false
local lastRunTS = 0

local gState = PAGE_DISPLAY
ActivePage = nil

AllPages = { "pids", "rates", "tpa", "filters", "alarms", "vtx" }

local function formatKissFloat(v, d)
	local s = string.format("%0.4d", v);
	local part1 = string.sub(s, 1, string.len(s)-3)
	local part2 = string.sub(string.sub(s,-3), 1, d)
	if d>0 then 
		return part1.."."..part2
	else
		return part1
	end
end

local function clearTable(t)
	if type(t)=="table" then
  		for i,v in pairs(t) do
    		if type(v) == "table" then
      			clearTable(v)
    		end
    		t[i] = nil
  		end
	end
	collectgarbage()
	return t
end

local function saveSettings(new)
   if ActivePage.values then
      if ActivePage.preWrite then
         kissSendRequest(ActivePage.write, ActivePage.preWrite(ActivePage.values))
      else
         kissSendRequest(ActivePage.write, ActivePage.values)
      end
      saveTS = getTime()
      if gState == PAGE_SAVING then
         saveRetries = saveRetries + 1
      else
         gState = PAGE_SAVING
         saveRetries = 0
         saveMaxRetries = ActivePage.saveMaxRetries or 2 -- default 2
         saveTimeout = ActivePage.saveTimeout or 400     -- default 4s
      end
   end
end

local function invalidatePage()
	ActivePage.values = nil
	gState = PAGE_DISPLAY
	saveTS = 0
end

local function loadPage(pageId) 
	local file = "/SCRIPTS/TELEMETRY/KISS/"..AllPages[pageId]..".lua"
	clearTable(ActivePage)
	local tmp = assert(loadScript(file))
    ActivePage = tmp()
end

local menuList = {
   { t = "save page",  f = saveSettings }, { t = "reload", f = invalidatePage }
}

local function processKissReply(cmd, rx_buf)

   if cmd == nil or rx_buf == nil then
      return
   end
   
   -- response on saving
   if cmd == ActivePage.write then
      gState = PAGE_DISPLAY
      ActivePage.values = nil
      saveTS = 0
      return
   end
   
   if cmd ~= ActivePage.read then
      return
   end

   if #(rx_buf) > 0 then
      ActivePage.values = {}
      for i=1,#(rx_buf) do
         ActivePage.values[i] = rx_buf[i]
      end

      if ActivePage.postRead ~= nil then
         ActivePage.values = ActivePage.postRead(ActivePage.values)
      end
   end
end
   
local function MaxLines()
   return #(ActivePage.fields)
end

local function changeWithLimit(value, direction, min, max) 
	local tmp = value + direction
	if tmp > max and direction>0 then
		tmp = min
	elseif tmp < 1 and direction<0 then
		tmp = max
	end
	return tmp
end

local function incPage(inc)
   currentPage = changeWithLimit(currentPage, inc, 1, #(AllPages))
   loadPage(currentPage)
end

local function incLine(inc)
   currentLine = changeWithLimit(currentLine, inc, 1, MaxLines())
end

local function incMenu(inc)
   menuActive = changeWithLimit(menuActive, inc, 1, #(menuList))
end

local function requestPage()
   if ActivePage.read and ((ActivePage.reqTS == nil) or (ActivePage.reqTS + REQ_TIMEOUT <= getTime())) then
      ActivePage.reqTS = getTime()
      kissSendRequest(ActivePage.read, {})
   end
end

local function drawScreen(page_locked)

   drawScreenTitle(ActivePage.title, currentPage, #(AllPages))	
  
   for i=1,#(ActivePage.text) do
      local f = ActivePage.text[i]
      if f.to == nil then
         lcd.drawText(f.x, f.y, f.t, getDefaultTextOptions())
      else
         lcd.drawText(f.x, f.y, f.t, f.to)
      end
   end
   
   if ActivePage.lines ~= nil then
   	for i=1,#(ActivePage.lines) do
    	  local f = ActivePage.lines[i]
      	lcd.drawLine (f.x1, f.y1, f.x2, f.y2, SOLID, 0)
   	end
   end
   
   for i=1,#(ActivePage.fields) do
      local f = ActivePage.fields[i]

      local text_options = getDefaultTextOptions()
      if i == currentLine then
         text_options = INVERS
         if gState == EDITING then
            text_options = text_options + BLINK
         end
      end

	  local spacing = 20

      if f.t ~= nil then
         lcd.drawText(f.x, f.y, f.t .. ":", getDefaultTextOptions())
	  end
	  
      -- draw some value
      if f.sp ~= nil then
          spacing = f.sp
      end

      local idx = f.i or i
      if ActivePage.values and ActivePage.values[idx] then
         local val = ActivePage.values[idx]
         if f.table and f.table[ActivePage.values[idx]] then
            val = f.table[ActivePage.values[idx]]
         end
         
          if f.prec ~= nil then
          	val = formatKissFloat(val, f.prec, f.base)
          end
          
         lcd.drawText(f.x + spacing, f.y, val, text_options)
      else
         lcd.drawText(f.x + spacing, f.y, "---", text_options)
      end
   end
   
   if ActivePage.customDraw ~= nil then
  		ActivePage.customDraw()
   end
end

local function clipValue(val,min,max)
   if val < min then
      val = min
   elseif val > max then
      val = max
   end
   return val
end

local function getCurrentField()
   return ActivePage.fields[currentLine]
end

local function incValue(inc)
   local field = ActivePage.fields[currentLine]
   local idx = field.i or currentLine
   
   local tmpInc = inc
   if field.prec ~= nil then
      tmpInc = tmpInc * 10^(3-field.prec)
   end
   
   if field.inc ~= nil then
   	  tmpInc = tmpInc * field.inc
   end
          
   ActivePage.values[idx] = clipValue(ActivePage.values[idx] + tmpInc, field.min or 0, field.max or 255)
end

local function run(event)
  
	if ActivePage==nil then
		loadPage(currentPage)
	end

   local now = getTime()

   -- if lastRunTS old than 500ms
   if lastRunTS + 50 < now then
      invalidatePage()
   end
   lastRunTS = now

   if (gState == PAGE_SAVING) and (saveTS + saveTimeout < now) then
      if saveRetries < saveMaxRetries then
         saveSettings()
      else
         -- max retries reached
         gState = PAGE_DISPLAY
         invalidatePage()
      end
   end
   
   if #(kissTxBuf) > 0 then
      kissProcessTxQ()
   end

   -- navigation
   if event == EVT_MENU_LONG then
      menuActive = 1
      gState = MENU_DISP

   elseif EVT_PAGEUP_FIRST and (event == EVT_ENTER_LONG) then
      menuActive = 1
      killEnterBreak = 1
      gState = MENU_DISP
      
   -- menu is currently displayed
   elseif gState == MENU_DISP then
      if event == EVT_EXIT_BREAK then
         gState = PAGE_DISPLAY
      elseif event == EVT_PLUS_BREAK or event == EVT_ROT_LEFT then
         incMenu(-1)
      elseif event == EVT_MINUS_BREAK or event == EVT_ROT_RIGHT then
         incMenu(1)
      elseif event == EVT_ENTER_BREAK then
      	if RADIO == "HORUS" then
      		if killEnterBreak == 1 then
            	killEnterBreak = 0
         	else
            	gState = PAGE_DISPLAY
            	menuList[menuActive].f()
         	end
      	else
         	gState = PAGE_DISPLAY
         	menuList[menuActive].f()
        end 
      end
   -- normal page viewing
   elseif gState <= PAGE_DISPLAY then
   	  if event == EVT_PAGEUP_FIRST then
         incPage(-1)
      elseif event == EVT_MENU_BREAK  or event == EVT_PAGEDN_FIRST then
         incPage(1)
      elseif event == EVT_PLUS_BREAK or event == EVT_ROT_LEFT then
         incLine(-1)
      elseif event == EVT_MINUS_BREAK or event == EVT_ROT_RIGHT then
         incLine(1)
      elseif event == EVT_ENTER_BREAK then
         local field = ActivePage.fields[currentLine]
         local idx = field.i or currentLine
         if ActivePage.values and ActivePage.values[idx] and (field.ro ~= true) then
            gState = EDITING
         end
      end
   -- editing value
   elseif gState == EDITING then
      if (event == EVT_EXIT_BREAK) or (event == EVT_ENTER_BREAK) then
         gState = PAGE_DISPLAY
      elseif event == EVT_PLUS_FIRST or event == EVT_ROT_RIGHT then
         incValue(1)
      elseif event == EVT_PLUS_REPT then
         incValue(10)
      elseif event == EVT_MINUS_FIRST or event == EVT_ROT_LEFT then
         incValue(-1)
      elseif event == EVT_MINUS_REPT then
		 incValue(-10)
      end
   end

   local page_locked = false

   if ActivePage.values == nil then
      requestPage()
      page_locked = true
   end

   lcd.clear()
   drawScreen(page_locked)
  
   if isTelemetryPresent()~=true then
      drawTelemetry()
      invalidatePage()
   end

   if gState == MENU_DISP then
      drawMenu(menuList, menuActive)
   elseif gState == PAGE_SAVING then
     drawSaving()
   end

   processKissReply(kissPollReply())
   return 0
end

return {run=run}

-- END UI

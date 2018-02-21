
local function run_func(event)

  local batt_s = 'VFAS'

  local batt_t = getValue(batt_s)
  local batt_v = {}
  local img_path = '/SCRIPTS/BMP/'
  local percent = 0
  local cell = 0
  local spacing = 2
  local settings = getGeneralSettings()
  local MEDIUM_SIZE = 20
  local first_line = 6
  local second_line = 25
  local third_line = 39
  local onehalf_column = 50
  local second_column = 70
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

 local uno = 0
        local band = 1
        local channel = ''
        local minPw = ''
        local maxPw = ''


local function subrange(t, first, last)
  local sub = {}
  for i=first,last do
    sub[#sub + 1] = t[i]
  end
  return sub
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

local function processKissReply(cmd, rx_buf)
    
    
   if cmd == nil or rx_buf == nil then
     
      return
   end
   
   if cmd ~= 0x45 then
      return
   end
   
   if #(rx_buf) > 0 then
        table = { "A", "B", "E", "FS", "RB" }
        uno = rx_buf[1]
        band = table[1 + bit32.rshift(rx_buf[2], 3)]
        channel = 1 + bit32.band(rx_buf[2], 0x07)
        minPw = bit32.lshift(rx_buf[3], 8) + rx_buf[4]
        maxPw = bit32.lshift(rx_buf[5], 8) + rx_buf[6]
        
        
   end
   

end

  function drawCurrentTime(x, y)
    datetime = getDateTime()
    lcd.drawPixmap(x, y, img_path .. 'clock.bmp')
    lcd.drawText(x + 18, y + 5, format(datetime.hour)..":"..format(datetime.min)..":"..format(datetime.sec), SMLSIZE)
  end

  function round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
  end

  function drawTxBattery(x,y)
    percent = (getValue('tx-voltage') - settings.battMin) * 100 / (settings.battMax - settings.battMin)
    lcd.drawRectangle(x, y -1, 15, 8)
    lcd.drawFilledRectangle(x + 1, y-1 + 1, 13, 6, GREY_DEFAULT)
    lcd.drawLine(x + 15, y-1 + 2, x + 15, y-1 + 5, SOLID, 0)
    -- Tx Voltage
    lcd.drawChannel(x + 20, y, 'RxBt', SMLSIZE)
  end

  function lipoBattery(x,y)
    
    lcd.drawPixmap(x, y, img_path .. 'battery.bmp')
    batt_v[2] = { low = 7.4, high = 8.4 }
    batt_v[3] = { low = 11.1, high = 12.6 }
    batt_v[4] = { low = 14.8, high = 16.8 }
    batt_v[5] = { low = 18.5, high = 21.0 }
    batt_v[6] = { low = 22.2, high = 25.2 }

    if batt_t > 3 then
      -- Only show voltage and cell count if battery is connected
      batt_c = math.ceil(batt_t / 4.25)
      percent = (batt_t - batt_v[batt_c]['low']) * (100 / (batt_v[batt_c]['high'] - batt_v[batt_c]['low']))
      cell = batt_t / batt_c
      if cell < 3.7 then
        lcd.drawText(9, 56, round(batt_t,1)..'v', BLINK + SMLSIZE)
        lcd.drawText(lcd.getLastPos() + spacing + 2, 56, round(cell, 1) .. 'v', BLINK + SMLSIZE)
      else
        lcd.drawText(9, 56, round(batt_t,1)..'v', LEFT + SMLSIZE)
        lcd.drawText(lcd.getLastPos() + spacing + 2, 56, round(cell, 1) .. 'v', SMLSIZE)
      end
      lcd.drawText(lcd.getLastPos() + spacing + 2, 56, batt_c .. 's', SMLSIZE)
    end

    if percent > 0 then
      local myPxX = math.floor(percent * 0.37)
      local myPxY = 11 + 37 - myPxX
      lcd.drawFilledRectangle(x + 7, myPxY, 21, myPxX, FILL_WHITE)
    end

    for i = 36, 2, -2 do
      lcd.drawLine(x + 7, y + 10 + i, x + 27, y + 10 + i, SOLID, GREY_DEFAULT)
    end

  end

  function format(num)
    formatted = ''..num
    if num < 10 then
      formatted = '0'..num
    end
    return formatted
  end
  
  function drawVtx(x, y) 
       
    lcd.drawText(x + 2,y,channel, SMLSIZE)
    lcd.drawText(lcd.getLastPos() + 1,y,band, SMLSIZE)
    lcd.drawText(lcd.getLastPos()+ 1,y,maxPw, SMLSIZE)
    

  end

  lcd.clear()
  lipoBattery(1,1)

  drawCurrentTime(onehalf_column -11, first_line -5)

  -- drawTxBattery(onehalf_column + 70, first_line)


  -- Flight Mode

  if getValue(MIXSRC_SA) < 0 then
    lcd.drawText(second_column, second_line, 'Normal Mode', MEDIUM_SIZE)
  elseif getValue(MIXSRC_SA) >= 0 then
    lcd.drawText(second_column + 2, second_line, 'Acro Mode', MEDIUM_SIZE)
  end

  -- Arm Status
  if getValue(MIXSRC_SF) > 0 and getValue(MIXSRC_SC) > 0 then
    lcd.drawText(second_column + 7, third_line, 'Armed', MIDSIZE + BLINK)
  else
    lcd.drawText(second_column, third_line, 'Disarmed', MIDSIZE)
  end

  -- RSSI Data
  if getValue('RSSI') > 0 then
    percent = round(((math.log(getValue('RSSI') - 28, 10) - 1) / (math.log(72, 10) - 1)) * 100, -1)
  else
    percent = 0
  end
  lcd.drawPixmap(164, 1, img_path .. 'rssi_' .. percent .. '.bmp')
  lcd.drawText(182, 56, getValue('RSSI')..'db', SMLSIZE)
  
  --local command, data = crossfireTelemetryPop()
  kissPollReply()
  
 
   kissSendRequest( 0x45, {})
  processKissReply(kissPollReply())
  
  drawVtx(120, 56) 
  
  table = nil

end

return { run=run_func}

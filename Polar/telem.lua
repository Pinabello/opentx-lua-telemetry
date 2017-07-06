
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
  
  table = { "A", "B", "E", "FS", "RB" }
  
  bandIndex = 1+bit32.rshift(34,3)
  
  band = table[bandIndex]
  channel = 1+bit32.band(34,0x07)
  power = bit32.lshift(2,8)+88
  
  lcd.drawText(1,1,band, MIDSIZE)
  lcd.drawText(1,20,channel, MIDSIZE)
  lcd.drawText(1,30,power, MIDSIZE)
  
  table = nil
  --print('pinaz '..tostring(data))

end

return { run=run_func}

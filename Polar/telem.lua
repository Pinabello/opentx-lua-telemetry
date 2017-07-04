
local function run_func(event)

  function round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
  end
  
  lcd.clear()
  
  local batt_s = 'VFAS'
  local batt_t = getValue(batt_s)
  local batt_v = {}
  local img_path = '/SCRIPTS/BMP/'
  local percent = 0
  local cell = 0
  local spacing = 2
  
  
  local first_line = 5
  local second_line = 25
  local third_line = 45
  
  local onehalf_column = 45
  local second_column = 70
  
  lcd.drawPixmap(6, 1, img_path .. 'battery.bmp')
  batt_v[2] = { low = 7.4, high = 8.4 }
  batt_v[3] = { low = 11.1, high = 12.6 }
  batt_v[4] = { low = 14.8, high = 16.8 }
  batt_v[5] = { low = 18.5, high = 21.0 }
  batt_v[6] = { low = 22.2, high = 25.2 }
  
  if batt_t > 3 then
    -- Only show voltage and cell count if battery is connected
    batt_c = math.ceil(batt_t / 4.25)
    percent = (batt_t - batt_v[batt_c]['low']) * (100 / (batt_v[batt_c]['high'] - batt_v[batt_c]['low']))
    lcd.drawChannel(4, 55, batt_s, LEFT)
    lcd.drawText(lcd.getLastPos() + spacing, 55, batt_c .. 'S', 0)
    cell = batt_t / batt_c
    lcd.drawText(lcd.getLastPos() + spacing, 55, round(cell, 1) .. 'v', 0)
  end
  
  if percent > 0 then
    local myPxX = math.floor(percent * 0.37)
    local myPxY = 11 + 37 - myPxX
    lcd.drawFilledRectangle(13, myPxY, 21, myPxX, FILL_WHITE)
  end
  
  for i = 36, 2, -2 do
    lcd.drawLine(14, 11 + i, 32, 11 + i, SOLID, GREY_DEFAULT)
  end
  
  -- Time
  datetime = getDateTime()
  lcd.drawText(onehalf_column, first_line, datetime.hour..":"..datetime.min..":"..datetime.sec, 0)
  
  -- Flight Mode

  if getValue(MIXSRC_SA) < 0 then
    lcd.drawText(second_column + 15, third_line, 'Level', MIDSIZE)
  elseif getValue(MIXSRC_SA) >= 0 then
    lcd.drawText(second_column  + 15, third_line, 'Acro', MIDSIZE)
  end
  
  -- Arm Status
  if getValue(MIXSRC_SF) > 0 then
    lcd.drawText(second_column, second_line, 'ARMED', MIDSIZE)
  else
    lcd.drawText(second_column, second_line, 'DISARMED', MIDSIZE)
  end
  
end

return { run=run_func}
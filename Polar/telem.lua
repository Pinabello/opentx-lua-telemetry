
local function run_func(event)
  
  lcd.clear()
  
  local batt_s = 'VFAS'
  local batt_t = getValue(batt_s)
  local batt_v = {}
  local img_path = '/SCRIPTS/BMP/'
  local percent = 0
  
  
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
    lcd.drawText(lcd.getLastPos() + 1, 55, batt_c .. 'S', 0)
  end
  
  if percent > 0 then
    local myPxX = math.floor(percent * 0.37)
    local myPxY = 11 + 37 - myPxX
    lcd.drawFilledRectangle(13, myPxY, 21, myPxX, FILL_WHITE)
  end
  
  for i = 36, 2, -2 do
    lcd.drawLine(14, 11 + i, 32, 11 + i, SOLID, GREY_DEFAULT)
  end
  
end

return { run=run_func}
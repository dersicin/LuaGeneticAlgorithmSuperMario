if gameinfo.getromname() == "Super Mario World (USA)" then
  Filename = "DP1.state"
  ButtonNames = {
    "A",
    "B",
    "X",
    "Y",
    "Up",
    "Down",
    "Left",
    "Right",
  }
elseif gameinfo.getromname() == "Super Mario Bros." then
  Filename = "SMB1-1.state"
  ButtonNames = {
    "A",
    "B",
    "Up",
    "Down",
    "Left",
    "Right",
  }
end

BoxRadius = 6
InputSize = (BoxRadius*2+1)*(BoxRadius*2+1)
rightmost = 0
basbireysayi = 1 --luada diziler 1.indisten başlıyor. C deki gibi 0 değil.
generasyoncount=1
popBuyukluk = 100
TimeoutConstant = 30
Inputs = InputSize+1
Outputs = #ButtonNames
i=1
currentFrame = 0
timeout = 30
bas_pop = {0}
pop = {}
pop_count = 1
birey_count = 1
gen_uzunluk = 16
ortalamafitnessyaz = 0
eniyiolan = {}

function getPositions()
  if gameinfo.getromname() == "Super Mario World (USA)" then
    marioX = memory.read_s16_le(0x94)
    marioY = memory.read_s16_le(0x96)
    
    local layer1x = memory.read_s16_le(0x1A);
    local layer1y = memory.read_s16_le(0x1C);
    
    screenX = marioX-layer1x
    screenY = marioY-layer1y
  elseif gameinfo.getromname() == "Super Mario Bros." then
    marioX = memory.readbyte(0x6D) * 0x100 + memory.readbyte(0x86)
    marioY = memory.readbyte(0x03B8)+16
  
    screenX = memory.readbyte(0x03AD)
    screenY = memory.readbyte(0x03B8)
  end
end

function getTile(dx, dy)
  if gameinfo.getromname() == "Super Mario World (USA)" then
    x = math.floor((marioX+dx+8)/16)
    y = math.floor((marioY+dy)/16)
    
    return memory.readbyte(0x1C800 + math.floor(x/0x10)*0x1B0 + y*0x10 + x%0x10)
  elseif gameinfo.getromname() == "Super Mario Bros." then
    local x = marioX + dx + 8
    local y = marioY + dy - 16
    local page = math.floor(x/256)%2

    local subx = math.floor((x%256)/16)
    local suby = math.floor((y - 32)/16)
    local addr = 0x500 + page*13*16+suby*16+subx
    
    if suby >= 13 or suby < 0 then
      return 0
    end
    
    if memory.readbyte(addr) ~= 0 then
      return 1
    else
      return 0
    end
  end
end

function getSprites()
  if gameinfo.getromname() == "Super Mario World (USA)" then
    local sprites = {}
    for slot=0,11 do
      local status = memory.readbyte(0x14C8+slot)
      if status ~= 0 then
        spritex = memory.readbyte(0xE4+slot) + memory.readbyte(0x14E0+slot)*256
        spritey = memory.readbyte(0xD8+slot) + memory.readbyte(0x14D4+slot)*256
        sprites[#sprites+1] = {["x"]=spritex, ["y"]=spritey}
      end
    end   
    
    return sprites
  elseif gameinfo.getromname() == "Super Mario Bros." then
    local sprites = {}
    for slot=0,4 do
      local enemy = memory.readbyte(0xF+slot)
      if enemy ~= 0 then
        local ex = memory.readbyte(0x6E + slot)*0x100 + memory.readbyte(0x87+slot)
        local ey = memory.readbyte(0xCF + slot)+24
        sprites[#sprites+1] = {["x"]=ex,["y"]=ey}
      end
    end
    
    return sprites
  end
end

function getExtendedSprites()
  if gameinfo.getromname() == "Super Mario World (USA)" then
    local extended = {}
    for slot=0,11 do
      local number = memory.readbyte(0x170B+slot)
      if number ~= 0 then
        spritex = memory.readbyte(0x171F+slot) + memory.readbyte(0x1733+slot)*256
        spritey = memory.readbyte(0x1715+slot) + memory.readbyte(0x1729+slot)*256
        extended[#extended+1] = {["x"]=spritex, ["y"]=spritey}
      end
    end   
    
    return extended
  elseif gameinfo.getromname() == "Super Mario Bros." then
    return {}
  end
end

function getInputs()
  getPositions()
  
  sprites = getSprites()
  extended = getExtendedSprites()
  
  local inputs = {}
  
  for dy=-BoxRadius*16,BoxRadius*16,16 do
    for dx=-BoxRadius*16,BoxRadius*16,16 do
      inputs[#inputs+1] = 0
      
      tile = getTile(dx, dy)
      if tile == 1 and marioY+dy < 0x1B0 then
        inputs[#inputs] = 1
      end
      
      for i = 1,#sprites do
        distx = math.abs(sprites[i]["x"] - (marioX+dx))
        disty = math.abs(sprites[i]["y"] - (marioY+dy))
        if distx <= 8 and disty <= 8 then
          inputs[#inputs] = -1
        end
      end

      for i = 1,#extended do
        distx = math.abs(extended[i]["x"] - (marioX+dx))
        disty = math.abs(extended[i]["y"] - (marioY+dy))
        if distx < 8 and disty < 8 then
          inputs[#inputs] = -1
        end
      end
    end
  end
  
  --mariovx = memory.read_s8(0x7B)
  --mariovy = memory.read_s8(0x7D)
  
  return inputs
end

function sigmoid(x)
  return 2/(1+math.exp(-4.9*x))-1
end

function clearJoypad()
  controller = {}
  for b = 1,#ButtonNames do
    controller["P1 " .. ButtonNames[b]] = false
  end
  joypad.set(controller)
end

function initializeRun()
  savestate.load(Filename);
  rightmost = 0
  timeout = TimeoutConstant
  clearJoypad()
end

function evaluateCurrent()


  inputs = getInputs()
  controller = evaluateNetwork(genome.network, inputs)
  
  if controller["P1 Left"] and controller["P1 Right"] then
    controller["P1 Left"] = false
    controller["P1 Right"] = false
  end
  if controller["P1 Up"] and controller["P1 Down"] then
    controller["P1 Up"] = false
    controller["P1 Down"] = false
  end

  joypad.set(controller)
end

--Bazır hazır tanımlanması gereken sabitler ve fonksiyonlar.

function populasyonolustur(Bas_Pop_L) --Başlangıç populasyonu oluşturulur
	if basbireysayi < popBuyukluk+1 then
		Bas_Pop_L[basbireysayi] = baslangicgenomolustur()
	end
end

function baslangicgenomolustur() --Rastgele Genom Oluşturma
local dizi = {}
for temp = 1,gen_uzunluk do
table.insert(dizi,temp,math.random(1,8))
end
return dizi
end

function caprazla(ortalamapop) --İlk 6 terimi yer değiştirdik
	local indis1=math.random(1,#ortalamapop)
	local indis2=math.random(1,#ortalamapop)
	local gecicidizi1 = ortalamapop
	local x = 1
	for x = 1,6 do
	local temp = gecicidizi1[indis1][x]
	gecicidizi1[indis1][x] = gecicidizi1[indis2][x]
	gecicidizi1[indis2][x] = temp
	end
	return gecicidizi1[indis1]
end

function mutasyon(tempgenom) --Seçtiğimiz noktadaki gen'i rastgele değer ile değiştirdik
	local sans = math.random(1,100)
	if(sans<40) then--yüzde 40 ihtimal
		local tempgen = math.random(1,16)
		tempgenom[1][tempgen] = math.random(1,8)
	end
	return tempgenom
end

function fitnesshesapla() --Fitness değerini gidebildiği son noktaya göre hesapladık

	getPositions()
if marioX > rightmost then
    rightmost = marioX
end
	return rightmost
end

function zamanekle() --Eğer birey ilerlemeye devam ediyorsa zaman eklenir, ilerleyişi durduysa sonraki bireye geçilir
getPositions()
if marioX > rightmost then
    timeout = TimeoutConstant
end
timeout = timeout - 1
end

function maincalistir() -- Populasyonu çağırdığımız fonksiyon
	rightmost = 0
	if generasyoncount ==1 and basbireysayi<popBuyukluk+1 then 
		populasyonolustur(bas_pop)
	else
	
		if basbireysayi == popBuyukluk+1 then
		i=1
		generasyoncount = generasyoncount + 1
		basbireysayi = 1
		ortalamafitnessyaz = ortalamafitness(bas_pop) --önceki jenerasyonun fitness ortalaması
		console.writeline(generasyoncount-1 .. ".jenerasyonun ortalama fitness'i: " .. ortalamafitnessyaz)
		console.writeline("En iyi genom'un fitness'i:" .. bas_pop[bestgenom(bas_pop)][gen_uzunluk+1])
		bas_pop=yeniGenerasyon(bas_pop)	
		end
	end
end

function yazdir()  --Ekrana yazdırma fonksiyonu
console.writeline(basbireysayi .. ".birey")
console.writeline(bas_pop[basbireysayi])
end

function yeniGenerasyon(gecerli_pop) --Yeni generasyon oluşturup mutasyon ve çaprazlamaları gerçekleştirdiğimiz fonksiyon 

local y = 0 --ortalama pop a sayı index li yazması için garanti ettim.
local gecicipop = {}
local ortalamapop = {}
local gecicifitnesstoplam = 0
for gecicigenom = 1,popBuyukluk do --Ortalama aldırdık
gecicifitnesstoplam = gecerli_pop[gecicigenom][17] + gecicifitnesstoplam
end
gecicifitnesstoplam = gecicifitnesstoplam / popBuyukluk --ortalama fitness bulundu.

for gecicigenom = 1,popBuyukluk do --ortalama üstü fitness olanları gecici bir diziye aktardık.
	
	if gecerli_pop[gecicigenom][17] >= gecicifitnesstoplam then --popülasyondaki ortalama üstü fitnessa sahip bireyler bulunur.
		y = y+1
		table.insert(ortalamapop,y,gecerli_pop[gecicigenom]) -- bulunan bireyler ortalamapop dizisine aktarılır.
	end
end

--en iyi genom gecicipop 1 e atanıyor.
table.insert(gecicipop,1,gecerli_pop[bestgenom(gecerli_pop)])
--yeni popülasyonun kalanı çaprazlama + mutasyon sonucu oluşan elemanlarla dolduruluyor.
for gecicigenom = 2, popBuyukluk do
local gecicidizi = {}
table.insert(gecicidizi,1,caprazla(ortalamapop))
gecicidizi=mutasyon(gecicidizi)
table.insert(gecicipop,gecicigenom,gecicidizi[1])
end

return gecicipop
end

function bestgenom(gecerli_pop) --eniyigenoma sahip birey bulunur.
local i = 1
maxgenom = 0
maxgenomkonum = 0
for i = 1,popBuyukluk do
if maxgenom < math.max(unpack(gecerli_pop[i])) then
maxgenom = math.max(unpack(gecerli_pop[i]))
maxgenomkonum = i
end
end
return maxgenomkonum
end

function ortalamafitness(gecerli_pop) --Fitness ortalamasını hesapla
local gecicifitnesstoplam = 0
local gecicigenom = 0
	for gecicigenom = 1,popBuyukluk do --Ortalama aldırdık
	gecicifitnesstoplam = gecerli_pop[gecicigenom][gen_uzunluk+1] + gecicifitnesstoplam
	end
	gecicifitnesstoplam = gecicifitnesstoplam / popBuyukluk
	
	return gecicifitnesstoplam
end

populasyonolustur(bas_pop)
savestate.load(Filename);


while true do --Ana fonksiyon
	clearJoypad()
	if currentFrame%5 == 0 then --Butonlara bastırılan kısım
		
			controller["P1 " .. ButtonNames[bas_pop[basbireysayi][i]]] = true
			--console.writeline("ButonlarıYaz" .. ButtonNames[bas_pop[basbireysayi][i]])
			bas_pop[basbireysayi][gen_uzunluk+1] = rightmost --Her bireyin gen_uzunluk+1. gen'i fitness'a ayrılır
		
			
	joypad.set(controller)
	zamanekle()
	i=i+1
	end
	if i==gen_uzunluk then
	i = 1
	end

	
	gui.drawText(0, 36, "Fitness: " .. fitnesshesapla() , 0xFF000000, 11) --Ekrana fitness'ı anlık olarak görüntüledik
	gui.drawText(0, 60, "Birey: " .. basbireysayi , 0xFF000000, 11) --Ekrana birey'ı anlık olarak görüntüledik
	gui.drawText(100, 36, "Jenerasyon: " .. generasyoncount , 0xFF000000, 11)	--Ekrana Populasyonu'ı anlık olarak görüntüledik
	gui.drawText(100, 60, "Pop Ortalama: " .. ortalamafitnessyaz , 0xFF000000, 11)	--Ekrana Populasyonu'ı anlık olarak görüntüledik--ortalamafitnessyaz
	
	currentFrame = currentFrame+1
	
	if timeout <= 0 then --Reset
	currentFrame = 0
	i=1
	timeout = 30
	yazdir()
	basbireysayi = basbireysayi+1
	maincalistir()
	savestate.load(Filename);
	end
	emu.frameadvance();
end







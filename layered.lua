local RADIUS=31
local MIN_EMPTY_SLOTS=4
local currentX,currentZ,currentY,currentDir=0,0,0,0
local DUMP_X,DUMP_Z,DUMP_DIR=-30,0,3
local DX={[0]=0,1,0,-1}
local DZ={[0]=-1,0,1,0}
local PATH_ORDER={3,0,2,1}
local blocked={}
local inDump=false
local dumpInventory

write("Sections: ")
local BAND_COUNT=math.max(1,math.floor(tonumber(read()) or 1))

local function fuelOK()
    local f=turtle.getFuelLevel()
    return f=="unlimited" or f>0
end

local function getEmptySlots()
    local n=0
    for i=1,16 do
        if turtle.getItemCount(i)==0 then n=n+1 end
    end
    return n
end

local function turnTo(d)
    local n=(d-currentDir)%4
    if n==1 then turtle.turnRight()
    elseif n==2 then
        turtle.turnRight()
        turtle.turnRight()
    elseif n==3 then turtle.turnLeft() end
    currentDir=d
end

local function isInCircle(x,z)
    local ox=x-0.5
    local oz=z-0.5
    return ox*ox+oz*oz<=RADIUS*RADIUS
end

local function key(x,z)
    return x..","..z
end

local function isBlocked(x,z)
    local y=blocked[currentY]
    return y and y[key(x,z)] or false
end

local function markBlocked(x,z)
    if not blocked[currentY] then blocked[currentY]={} end
    blocked[currentY][key(x,z)]=true
end

local function stepDir(d)
    turnTo(d)
    local nx=currentX+DX[d]
    local nz=currentZ+DZ[d]

    if not isInCircle(nx,nz) or isBlocked(nx,nz) then
        return false
    end

    while turtle.detect() do
        if not turtle.dig() then
            markBlocked(nx,nz)
            return false
        end
        os.sleep(0.1)
    end

    while true do
        if turtle.forward() then
            currentX=nx
            currentZ=nz
            if not inDump and getEmptySlots()<=MIN_EMPTY_SLOTS then
                dumpInventory()
            end
            return true
        end

        if not fuelOK() then error("Out of fuel") end

        if turtle.detect() then
            if not turtle.dig() then
                markBlocked(nx,nz)
                return false
            end
        else
            turtle.attack()
        end

        os.sleep(0.1)
    end
end

local function findPath(tx,tz)
    if not isInCircle(tx,tz) or isBlocked(tx,tz) then
        return nil
    end

    local start=key(currentX,currentZ)
    local target=key(tx,tz)
    local queue={{currentX,currentZ}}
    local head=1
    local seen={[start]=true}
    local parent={}

    while head<=#queue do
        local p=queue[head]
        head=head+1

        if p[1]==tx and p[2]==tz then break end

        for _,d in ipairs(PATH_ORDER) do
            local nx=p[1]+DX[d]
            local nz=p[2]+DZ[d]
            local k=key(nx,nz)

            if isInCircle(nx,nz)
            and not isBlocked(nx,nz)
            and not seen[k] then
                seen[k]=true
                parent[k]={key(p[1],p[2]),d}
                queue[#queue+1]={nx,nz}
            end
        end
    end

    if not seen[target] then return nil end

    local path={}
    local k=target

    while k~=start do
        local p=parent[k]
        table.insert(path,1,p[2])
        k=p[1]
    end

    return path
end

local function navigateTo(tx,tz)
    while currentX~=tx or currentZ~=tz do
        local path=findPath(tx,tz)
        if not path then return false end

        local failed=false

        for i=1,#path do
            if not stepDir(path[i]) then
                failed=true
                break
            end
        end

        if not failed then return true end
    end

    return true
end

local function upOne()
    while turtle.detectUp() do
        if not turtle.digUp() then return false end
        os.sleep(0.1)
    end

    while true do
        if turtle.up() then
            currentY=currentY+1
            return true
        end

        if not fuelOK() then error("Out of fuel") end

        if turtle.detectUp() then
            if not turtle.digUp() then return false end
        else
            turtle.attackUp()
        end

        os.sleep(0.1)
    end
end

local function downOne()
    while turtle.detectDown() do
        if not turtle.digDown() then return false end
        os.sleep(0.1)
    end

    while true do
        if turtle.down() then
            currentY=currentY-1
            return true
        end

        if not fuelOK() then error("Out of fuel") end

        if turtle.detectDown() then
            if not turtle.digDown() then return false end
        else
            turtle.attackDown()
        end

        os.sleep(0.1)
    end
end

local function moveVerticalTo(y)
    while currentY<y do
        if not upOne() then return false end
    end

    while currentY>y do
        if not downOne() then return false end
    end

    return true
end

dumpInventory=function()
    if inDump then return end
    inDump=true

    local sx,sz,sy,sd=currentX,currentZ,currentY,currentDir

    if not navigateTo(0,0) then
        inDump=false
        error("Cannot reach shaft")
    end

    if not moveVerticalTo(0) then
        inDump=false
        error("Shaft blocked")
    end

    if not navigateTo(DUMP_X,DUMP_Z) then
        inDump=false
        error("Cannot reach chest")
    end

    turnTo(DUMP_DIR)

    while true do
        local ok,data=turtle.inspect()
        if ok and data.name and string.find(data.name,"chest",1,true) then
            break
        end
        write("Chest missing. Fix and press Enter: ")
        read()
    end

    for i=1,16 do
        turtle.select(i)

        while turtle.getItemCount(i)>0 do
            if not turtle.drop() then
                write("Chest full. Empty and press Enter: ")
                read()
            end
        end
    end

    turtle.select(1)

    if not navigateTo(0,0) then
        inDump=false
        error("Cannot reach shaft")
    end

    if not moveVerticalTo(sy) then
        inDump=false
        error("Cannot return to level")
    end

    if not navigateTo(sx,sz) then
        inDump=false
        error("Cannot return to work")
    end

    turnTo(sd)
    inDump=false
end

local function clearColumn()
    while turtle.detectUp() do
        if not turtle.digUp() then break end
        os.sleep(0.1)
    end

    while turtle.detectDown() do
        if not turtle.digDown() then break end
        os.sleep(0.1)
    end

    if getEmptySlots()<=MIN_EMPTY_SLOTS then
        dumpInventory()
    end
end

local columns={}

for x=-RADIUS,RADIUS do
    local minZ,maxZ

    for z=-RADIUS,RADIUS do
        if isInCircle(x,z) then
            if not minZ then minZ=z end
            maxZ=z
        end
    end

    if minZ then
        columns[#columns+1]={x=x,minZ=minZ,maxZ=maxZ}
    end
end

local function changeLevel(y)
    if currentY==y then return true end
    if not navigateTo(0,0) then return false end
    return moveVerticalTo(y)
end

local function minePass(y)
    if not changeLevel(y) then return false end

    local south=true

    for _,c in ipairs(columns) do
        if south then
            for z=c.minZ,c.maxZ do
                if not isBlocked(c.x,z) then
                    if navigateTo(c.x,z) then clearColumn() end
                end
            end
        else
            for z=c.maxZ,c.minZ,-1 do
                if not isBlocked(c.x,z) then
                    if navigateTo(c.x,z) then clearColumn() end
                end
            end
        end

        south=not south
    end

    return true
end

for band=1,BAND_COUNT do
    local y=-(band-1)*9

    if not minePass(y) then break end
    if not minePass(y-3) then break end
end

local hasItems=false

for i=1,16 do
    if turtle.getItemCount(i)>0 then
        hasItems=true
        break
    end
end

if hasItems then dumpInventory() end

if not navigateTo(0,0) then
    error("Cannot reach shaft")
end

if not moveVerticalTo(0) then
    error("Cannot return to surface")
end

navigateTo(0,0)
turnTo(0)

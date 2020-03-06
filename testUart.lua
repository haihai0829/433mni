module(..., package.seeall)
require "utils"
require "pm"
require "nvm" --必须！引用nvm.lua
require "config" --必须！保存的文件
nvm.init("config.lua")

--防止串口一秒内输出两次devicecode，定义一个recent_write作为等待10秒。十秒后定时器设置为空串
recent_write = ""

--串口ID,1对应uart1
--如果要修改为uart2，把UART_ID赋值为2即可
local UART_ID = 2
--缓存数据
local buf = ""
--处理串口数据
local function proc(data)
    data = buf .. data

    local used = true
    --数据是否被处理？

    if recent_write == "wait" then
        return
    else
        recent_write = "wait"
        sys.timerStart(
            function()
                recent_write = ""
            end,
            1000
        )
    end

    --LC开头的是433模块发来的
    if string.sub(data, 1, 2) == "LC" then
        --这个elseif的是服务器的指令
        --拿到LC:DAB10  8 8F\r\n 中的 遥控器标记位，1，2，4，8
        local judge = string.sub(data, -5, -5)
        --拿到LC:DAB1088F\r\n 中的 DAB108
        local devicecode = string.sub(data, 4, 9)
        --拿到LC:DAB1088F\r\n 中的 DAB10 可以方便字符串拼接1，2，4，8
        local tmpdevice = string.sub(data, 4, 8)

        --先看一下收到的devicecode,是否存在NVM，如果不存在，就放到NVM里边
        if is_include(devicecode) or is_ykqinclude(devicecode) then
            print("47 if is_include(devicecode) then")
            --如果NVM里边有这个devicecode然后。。
            if not is_controller(judge) then
                --遥控器情况，布防8，撤防4，SOS 1
                print("51 if not is_controller(judge) then")
                ok0 = '{"alarm":"' .. devicecode .. '"}'
                if nvm.get("alarm") then
                    write(ok0)
                end
            elseif judge == "1" then
                --elseif judge == "2" then
                write("recorded and sos")
            elseif judge == "4" then
                --撤防
                nvm.set("alarm", flase)
                write("recorded and chefang")
            elseif judge == "8" then
                --布防
                nvm.set("alarm", true)
                write("recorded and bufang")
            else
            end
        elseif (not is_include(devicecode)) or (is_ykqinclude(devicecode)) then
            print("68 elseif not is_include(devicecode) then")
            if not is_controller(judge) then
                print("70 if not is_controller(judge) then")
                ok1 = '{"record":"' .. devicecode .. '"}'
                write(ok1)
                local where = get_devicenumber()
                local needwhere = "device" .. where
                nvm.set(needwhere, devicecode)
            else
                write(controller_record(tmpdevice))
            end
        else
            --数据没匹配上任何东西，没被使用
            used = false
        end
    elseif data == "all" then
        all()
    else
        used = false
    end
    if not used then --数据没被使用
        --数据追加到缓存区
        if buf == "" then --如果缓冲区是空的
            sys.timerStart(
                function()
                    buf = ""
                end,
                500
            )
        --500ms后清空缓冲区
        end
        buf = data
    else
        buf = ""
    end
end
--接收串口数据
local function read()
    local data = ""
    --底层core中，串口收到数据时：
    --如果接收缓冲区为空，则会以中断方式通知Lua脚本收到了新数据；
    --如果接收缓冲器不为空，则不会通知Lua脚本
    --所以Lua脚本中收到中断读串口数据时，每次都要把接收缓冲区中的数据全部读出，这样才能保证底层core中的新数据中断上来，此read函数中的while语句中就保证了这一点
    while true do
        data = uart.read(UART_ID, "*l")
        --数据不存在时停止接收数据
        if not data or string.len(data) == 0 then
            break
        end
        --打开下面的打印会耗时
        --log.info("testUart.read bin",data)
        --log.info("testUart.read hex",data:toHex())
        --真正的串口数据处理函数
        proc(data)
    end
end
--发送串口数据
function write(s)
    --log.info("testuart.write",s:toHex(),s)
    uart.write(UART_ID, s)
end
--保持系统处于唤醒状态，此处只是为了测试需要，所以此模块没有地方调用pm.sleep("testUart")休眠，不会进入低功耗休眠状态
--在开发“要求功耗低”的项目时，一定要想办法保证pm.wake("testUart")后，在不需要串口时调用pm.sleep("testUart")
pm.wake("testUart")
--注册串口的数据接收函数，串口收到数据后，会以中断方式，调用read接口读取数据
uart.on(UART_ID, "receive", read)
--配置并且打开串口
uart.setup(UART_ID, 9600, 8, uart.PAR_NONE, uart.STOP_1)

--include
function is_include(is_include_data)
    --devicecode前五位，不包含识别位，find是否包含字符串
    local i
    for i = 1, 30, 1 do
        local temp = nvm.get(("device" .. i))
        if (string.find(temp, is_include_data, 1)) then
            return true
        else
            if i == 30 then
                return false
            end
        end
    end
end
--include end

--ykq_include
function is_ykqinclude(is_ykqinclude_data)
    --devicecode前五位，不包含识别位，find是否包含字符串
    local i
    for i = 1, 10, 1 do
        local temp = nvm.get(("ykq" .. i))
        if (string.find(temp, is_ykqinclude_data, 1)) then
            return true
        else
            if i == 10 then
                return false
            end
        end
    end
end
--ykq_include end

--is_controller
function is_controller(is_controller_judgedata)
    print("156 here is function is_controller data is:" .. is_controller_judgedata)
    is_controller_data = "" .. is_controller_judgedata
    if (is_controller_judgedata) == "1" then
        print("158 1")
        return true
    elseif (is_controller_judgedata) == "2" then
        print("162 2")
        return true
    elseif (is_controller_judgedata) == "4" then
        print("165 4")
        return true
    elseif (is_controller_judgedata) == "8" then
        print("168 8")
        return true
    else
        return false
    end
end
--is_controller end

--get_devicenumber
function get_devicenumber()
    local ii
    --devicecode前五位，不包含识别位，find是否包含字符串
    for ii = 1, 30, 1 do
        local temp1 = nvm.get(("device" .. ii))
        if string.len(temp1) == 0 then
            --return "" .. i 看你要的是不是打印，串口出来一定是字符串
            return ii
        else
            if ii == 30 then
                return ""
            end
        end
    end
end
--get_devicenumber end

--get_controllernumber
function get_controllernumber()
    local i
    --devicecode前五位，不包含识别位，find是否包含字符串
    for i = 1, 10, 1 do
        local temp1 = nvm.get(("ykq" .. i))
        if string.len(temp1) == 0 then
            --return "" .. i 看你要的是不是打印，串口出来一定是字符串
            return i
        else
            if i == 10 then
                return ""
            end
        end
    end
end
--get_controllernumber end

--all
function all()
    local i
    local alldevicecode = ""
    for i = 1, 30, 1 do
        local temp = nvm.get(("device" .. i))
        if string.len(temp) > 1 then
            alldevicecode = alldevicecode .. temp .. ","
        end
    end
    alldevicecode = string.sub(alldevicecode, 1, string.len(alldevicecode) - 1)
    write('{"alldevicecode":"' .. alldevicecode .. '"}')
end
--all end

--controller_record
function controller_record(needtmpdevice)
    local temp_ykq_temdevicecode =
        needtmpdevice .. "1," .. needtmpdevice .. "2," .. needtmpdevice .. "4," .. needtmpdevice .. "8"
    local the_number = get_controllernumber()
    the_number = "ykq" .. the_number
    nvm.set(the_number, temp_ykq_temdevicecode)
    return '{"recordykq":"' .. temp_ykq_temdevicecode .. '"}'
end
--controller_record end


--test 串口
--sys.timerStart(function()
--write("010203")
--end,30000)

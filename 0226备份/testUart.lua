--没有保存的数据的时候，记得是保存一个空串  ""  千万不要 Nil
--旧的时候写的0226
module(..., package.seeall)
require "utils"
require "pm"

--NEW
require "nvm" --必须！引用nvm.lua
require "config" --必须！保存的文件
nvm.init("config.lua") --必须！初始化并使用config.lua作为配置文件进行读写，任何情况下都不可删除！
nvm.set("peiduinow", "not")
--NEWEND

--串口ID,1对应uart1
--如果要修改为uart2，把UART_ID赋值为2即可
local UART_ID = 2
--缓存数据
local buf = ""
--处理串口数据

--防止串口一秒内输出两次devicecode，定义一个recent_write作为等待10秒。十秒后定时器设置为空串
recent_write = ""

local function proc(data)
    data = buf .. data

    local used = true
    --数据是否被处理？

    --判断最后一位是不是1，2，4，8
    --如果不是，就是设备

    local iswhat
    local judge = string.sub(data, -5, -5)
    --拿到LC:DAB1088F\r\n 中的 DAB108
    local devicecode = string.sub(data, 4, 9)
    --拿到LC:DAB1088F\r\n 中的 DAB10 可以方便字符串拼接1，2，4，8
    local tmpdevice = string.sub(data, 4, 8)

    -- if (is_include(tmpdevice)) then
    --    write("is cun zai")
    --end
    --write("you kong wei" .. get_devicenumber())

    if data == "all" then
        all()
    end

    if nvm.get("peiduinow") == "is" then
        if judge == "1" then
            iswhat = "ykq"
            nvm.set("iswhat", "ykq")
            ok = '{"pdykq":"' .. devicecode .. '"}'
            write(ok)

            nvm.set("yaokongqi", ykqtable)
        elseif judge == "2" then
            iswhat = "ykq"
            nvm.set("iswhat", "ykq")
            ok = '{"pdykq":"' .. devicecode .. '"}'
            write(ok)
        elseif judge == "4" then
            iswhat = "ykq"
            nvm.set("iswhat", "ykq")
            ok = '{"pdykq":"' .. devicecode .. '"}'
            write(ok)
        elseif judge == "8" then
            iswhat = "ykq"
            nvm.set("iswhat", "ykq")
            ok = '{"pdykq":"' .. devicecode .. '"}'
            write(ok)
        elseif string.sub(data, 1, 2) == "LC" then
            --不是1 ，2，4，8那就是设备了，红外什么的
            iswhat = "device"
            nvm.set("iswhat", "device")
            --看看设备第几位可以插进去设备
            local where = get_devicenumber()
            local needwhere = "device" .. where
            nvm.set(needwhere, devicecode)
            ok = '{"pd":"' .. devicecode .. '","position":"' .. needwhere .. '"}'
            write(ok)
        else
            --数据没匹配上任何东西，没被使用
            used = false
        end
    end

    if nvm.get("peiduinow") == "not" then
        --遥控器情况，布防8，撤防4，SOS 1
        if judge == "1" then
            --sos，警号响起来
            write("sos")
        elseif judge == "2" then
            --暂时没定义
        elseif judge == "4" then
            --撤防
            recent_write = ""
            write("chefang")
        elseif judge == "8" then
            --布防
            write("bufang")
        elseif string.sub(data, 1, 2) == "LC" then
            --不是1 ，2，4，8那就是设备了，红外什么的
            --直接打印devicecode出来就好了
            ok = '{"alarm":"' .. devicecode .. '"}'
            if is_include(devicecode) then
                if recent_write ~= "wait" then
                    recent_write = "wait"
                    write(ok)
                    sys.timerStart(
                        function()
                            recent_write = ""
                        end,
                        10000
                    )
                end
            end
        else
        end
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
    --write("iswhat.......")
    --write(nvm.get("iswhat"))
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
        --log.info("testUart.read bin", data)
        --log.info("testUart.read hex", data:toHex())
        --真正的串口数据处理函数
        proc(data)
    end
end
--发送串口数据
function write(s)
    --log.info("testuart.write", s:toHex(), s)
    uart.write(UART_ID, s)
end
--保持系统处于唤醒状态，此处只是为了测试需要，所以此模块没有地方调用pm.sleep("testUart")休眠，不会进入低功耗休眠状态
--在开发“要求功耗低”的项目时，一定要想办法保证pm.wake("testUart")后，在不需要串口时调用pm.sleep("testUart")
pm.wake("testUart")
--注册串口的数据接收函数，串口收到数据后，会以中断方式，调用read接口读取数据
uart.on(UART_ID, "receive", read)
--配置并且打开串口
uart.setup(UART_ID, 9600, 8, uart.PAR_NONE, uart.STOP_1)

--模块开机第10秒后，向设备发送`0x01 0x02 0x03`三个字节
sys.timerStart(
    function()
        local odevicecode = "init sj999 ok..."
        local ook = '{"ok":"' .. odevicecode .. '"}'
        write(ook)
    end,
    30000
)

--include
function is_include(value)
    --devicecode前五位，不包含识别位，find是否包含字符串
    for i = 1, 30, 1 do
        local temp = nvm.get(("device" .. i))
        if temp == nil then
            temp = ""
        end
        if (string.find(temp, value, 1)) then
            return true
        else
            if i == 30 then
                return false
            end
        end
    end
end

--判断device1-30里边，第几个是空位，可以放变量进去
function get_devicenumber()
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

function deleteone(deleteone_value)
    local i
    for i = 1, 30, 1 do
        local temp = nvm.get(("device" .. i))
        if deleteone_value == temp then
            nvm.set("device" .. i, "")
            write("delete" .. temp .. "ok")
        else
            write("no this device code")
        end
    end
end

--new

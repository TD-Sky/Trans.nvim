local api = vim.api

---@diagnostic disable-next-line: duplicate-set-field
function string:width()
    ---@diagnostic disable-next-line: param-type-mismatch
    return vim.fn.strwidth(self)
end

local busy = false
local function check_busy()
    while busy do
        vim.wait(50)
    end
end

---@type window
local window = {
    ---设置窗口的选项
    ---@param self table 需要设置的window
    ---@param option string 待设置的选项名
    ---@param value any 选项的值
    set = function(self, option, value)
        api.nvim_win_set_option(self.winid, option, value)
    end,

    ---设置窗口的高度
    ---@param self table 窗口类
    ---@param height integer 设置的高度
    set_height = function(self, height)
        api.nvim_win_set_height(self.winid, height)
        self.height = height
    end,

    ---设置窗口的宽度
    ---@param self table 窗口对象
    ---@param width integer 设置的宽度
    set_width = function(self, width)
        api.nvim_win_set_width(self.winid, width)
        self.width = width
    end,

    ---设置窗口对应的buffer
    ---@param self table 同set类似
    ---@param option string
    ---@param value any
    bufset = function(self, option, value)
        api.nvim_buf_set_option(self.bufnr, option, value)
    end,

    ---查看**窗口**的选项
    ---@param self table 窗口对象
    ---@param name string 选项名
    ---@return any 对应的值
    ---@nodiscard
    option = function(self, name)
        return api.nvim_win_get_option(self.winid, name)
    end,

    ---设置当前窗口内的键映射, **需要光标在该窗口内**
    ---@param self table 窗口对象
    ---@param key string 映射的键位
    ---@param operation any 执行的操作
    map = function(self, key, operation)
        vim.keymap.set('n', key, operation, {
            buffer = self.bufnr,
            silent = true,
        })
    end,

    ---查看窗口是否是打开状态
    ---@param self table window对象
    ---@return boolean
    ---@nodiscard
    is_open = function(self)
        return self.winid > 0 and api.nvim_win_is_valid(self.winid)
    end,

    normal = function(self, key)
        api.nvim_buf_call(self.bufnr, function()
            vim.cmd([[normal! ]] .. key)
        end)
    end,

    ---**第一次**绘制窗口的内容
    ---@param self table 窗口的对象
    draw = function(self)
        -- TODO :
        local offset = 0
        for _, content in ipairs(self.contents) do
            content:attach(offset)
            offset = offset + content.size
        end
    end,

    open = function(self, callback)
        local animation = self.animation
        if animation.open then
            check_busy()

            local handler
            local function wrap(name, target)
                local count = 0
                local action = 'nvim_win_set_' .. target
                return function()
                    if count < self[target] then
                        busy = true
                        count = count + 1
                        api[action](self.winid, count)
                        vim.defer_fn(handler[name], animation.interval)

                    else
                        busy = false
                        if type(callback) == 'function' then
                            callback()
                        end
                    end
                end
            end

            handler = {
                slid = wrap('slid', 'width'),
                fold = wrap('fold', 'height'),
            }

            handler[animation.open]()
        end
    end,

    ---**重新绘制内容**(标题不变)
    ---@param self table 窗口对象
    redraw = function(self)
        self.content:attach()
    end,


    ---安全的关闭窗口
    try_close = function(self, callback)
        if self:is_open() then
            check_busy()
            self.config = api.nvim_win_get_config(self.winid)
            local animation = self.animation
            if animation.close then

                local handler
                local function wrap(name, target)
                    local count = self[target]
                    local action = 'nvim_win_set_' .. target
                    return function()
                        if count > 1 then
                            busy = true
                            count = count - 1
                            api[action](self.winid, count)
                            vim.defer_fn(handler[name], animation.interval)

                        else
                            vim.defer_fn(function()
                                api.nvim_win_close(self.winid, true)
                                self.winid = -1
                                busy = false

                                if type(callback) == 'function' then
                                    callback()
                                end

                            end, animation.interval + 2)
                        end
                    end
                end

                handler = {
                    slid = wrap('slid', 'width'),
                    fold = wrap('fold', 'height'),
                }

                handler[animation.close]()

            else
                api.nvim_win_close(self.winid, true)
                self.winid = -1
            end
        end
        end,

    reopen = function(self, entry, opt, callback)
        check_busy()
        self.config.win = nil
        if opt then
            for k, v in pairs(opt) do
                self.config[k] = v
            end
        end

        self.winid = api.nvim_open_win(self.bufnr, entry, self.config)
        self:open(callback)
    end,

    set_hl = function(self, name, hl)
        api.nvim_set_hl(self.hl, name, hl)
    end
}

---@class window
---@field winid integer 窗口的handle
---@field bufnr integer 窗口对应buffer的handle
---@field width integer 窗口当前的宽度
---@field height integer 窗口当前的高度
---@field hl integer 窗口highlight的namespace
---@field contents table[] 窗口内容的对象数组


---窗口对象的构造器
---@param entry boolean 光标初始化时是否应该进入窗口
---@param option table 需要设置的选项
---@return window win
---@nodiscard
return function(entry, option)
    vim.validate {
        entry = { entry, 'b' },
        option = { option, 't' },
    }

    local opt = {
        relative  = nil,
        width     = nil,
        height    = nil,
        border    = nil,
        title     = nil,
        col       = nil,
        row       = nil,
        title_pos = 'center',
        focusable = false,
        zindex    = 100,
        style     = 'minimal',
    }

    for k, v in pairs(option) do
        opt[k] = v
    end

    local bufnr = api.nvim_create_buf(false, true)
    local winid = api.nvim_open_win(bufnr, entry, opt)


    local win
    win = {
        winid    = winid,
        bufnr    = bufnr,
        width    = opt.width,
        height   = opt.height,
        hl       = api.nvim_create_namespace('TransWinHl'),
        contents = setmetatable({}, {
            __index = function(self, key)
                assert(type(key) == 'number')
                self[key] = require('Trans.content')(win)
                return self[key]
            end
        })
    }

    setmetatable(win, { __index = window })
    win:set('winhl', 'Normal:TransWin,FloatBorder:TransBorder')
    win:bufset('filetype', 'Trans')
    win:bufset('buftype', 'nofile')

    api.nvim_win_set_hl_ns(win.winid, win.hl)
    ---@diagnostic disable-next-line: return-type-mismatch
    return win
end
local Trans = require 'Trans'
local node = Trans.util.node
local i, t, pr, f = node.item, node.text, node.prompt, node.format

---@param func fun(buffer: TransBuffer)
---@return fun()
local function with_buffer(func)
    return function()
        local buffer = Trans.buffer.new()
        func(buffer)
        buffer:destroy()
    end
end


describe('buffer:setline()', function()
    it('and buffer[i] can accept a string as first arg', with_buffer(function(buffer)
        buffer:setline 'hello world'
        buffer[2] = 'hello world'
        assert.are.equal(buffer[1], 'hello world')
        assert.are.equal(buffer[2], 'hello world')
    end))

    it('and buffer[i] can accept a node as first arg', with_buffer(function(buffer)
        buffer:setline(i { 'hello world' })
        buffer[2] = i { 'hello world' }
        assert.are.equal(buffer[1], 'hello world')
        assert.are.equal(buffer[2], 'hello world')
    end))

    it('and buffer[i] can accept a node list as first arg', with_buffer(function(buffer)
        buffer:setline {
            i { 'hello ' },
            i { 'world' },
        }

        buffer[2] = {
            i { 'hello ' },
            i { 'world' },
        }

        assert.are.equal(buffer[1], 'hello world')
        assert.are.equal(buffer[2], 'hello world')
    end))

    it('and buffer[i] accept linenr more than line_count will fill with empty line', with_buffer(function(buffer)
        buffer:setline('hello world', 3)
        buffer[4] = 'hello world'
        assert.are.equal(buffer[1], '')
        assert.are.equal(buffer[2], '')
        assert.are.equal(buffer[3], 'hello world')
        assert.are.equal(buffer[4], 'hello world')
    end))


    it('can accept one index linenr as second arg', with_buffer(function(buffer)
        buffer:setline({
            i { 'hello ' },
            i { 'world' },
        }, 1)
        assert.are.equal(buffer[1], 'hello world')
    end))

    it('when no second arg, it will append line', with_buffer(function(buffer)
        buffer[1] = 'hello'
        buffer:setline 'world'

        assert.are.equal(buffer[2], 'world')
    end))
end)

-- TODO :Add node test
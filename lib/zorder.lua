local bit = require("bit")
local band, bor, lshift, rshift = bit.band, bit.bor, bit.lshift, bit.rshift

-- Zigzag encode: maps signed integers to non-negative integers
-- 0→0, -1→1, 1→2, -2→3, 2→4, ...
---@param n integer
local function zigzag_encode(n)
    if n >= 0 then
        return n * 2
    else
        return (-n) * 2 - 1
    end
end

---@param n integer
local function zigzag_decode(n)
    if band(n, 1) == 0 then
        return rshift(n, 1)       -- even: n/2
    else
        return -rshift(n + 1, 1)  -- odd: -(n+1)/2
    end
end

-- Spread bits of a 32-bit integer into even bit positions
-- e.g. ...b3b2b1b0 → ...0b3 0b2 0b1 0b0
---@param x integer
local function spread_bits(x)
    x = band(x, 0xFFFF)                  -- keep 16 bits (gives 32-bit result)
    x = bor(x, lshift(x, 8))
    x = band(x, 0x00FF00FF)
    x = bor(x, lshift(x, 4))
    x = band(x, 0x0F0F0F0F)
    x = bor(x, lshift(x, 2))
    x = band(x, 0x33333333)
    x = bor(x, lshift(x, 1))
    x = band(x, 0x55555555)
    return x
end

-- Compact bits from even positions back into a contiguous integer
---@param x integer
local function compact_bits(x)
    x = band(x, 0x55555555)
    x = bor(x, rshift(x, 1))
    x = band(x, 0x33333333)
    x = bor(x, rshift(x, 2))
    x = band(x, 0x0F0F0F0F)
    x = bor(x, rshift(x, 4))
    x = band(x, 0x00FF00FF)
    x = bor(x, rshift(x, 8))
    x = band(x, 0x0000FFFF)
    return x
end

-- Hash (x, y) → single integer Z-order key
-- Supports any signed integers; result fits in a Lua number (double)
-- for coordinates in roughly [-32768, 32767] (16-bit range per axis)
---@param x integer
---@param y integer
local function z_hash(x, y)
    local ux = zigzag_encode(x)
    local uy = zigzag_encode(y)
    -- x goes into even bits (0,2,4,...), y into odd bits (1,3,5,...)
    return bor(spread_bits(ux), lshift(spread_bits(uy), 1))
end

-- Unhash a Z-order key back to (x, y)
---@param h integer
local function z_unhash(h)
    local ux = compact_bits(h)               -- extract even bits → x
    local uy = compact_bits(rshift(h, 1))    -- extract odd bits → y
    return zigzag_decode(ux), zigzag_decode(uy)
end


-- Quick test
local tests = {
    {0, 0}, {1, 0}, {0, 1}, {1, 1},
    {-1, 0}, {0, -1}, {-1, -1},
    {100, -200}, {-32768, 32767},
}

for _, t in ipairs(tests) do
    local x, y = t[1], t[2]
    local h = z_hash(x, y)
    local rx, ry = z_unhash(h)
    local ok = (rx == x and ry == y) and "OK" or "FAIL"
    print(string.format("(%6d, %6d) → %10d → (%6d, %6d) %s",
                        x, y, h, rx, ry, ok))
end

---@class zorder
return {
    encode = z_hash,
    decode = z_unhash
}

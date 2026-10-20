local Format = {}

--- 1234567 -> "1,234,567"
function Format.commas(n: number): string
	local s = tostring(math.floor(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return (if n < 0 then "-" else "") .. out
end

--- 1234 -> "$1,234"
function Format.money(n: number): string
	return "$" .. Format.commas(n)
end

--- 75 -> "1:15"
function Format.clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

--- 75 -> "1 min 15 s", 30 -> "30 s"
function Format.duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds + 0.5))
	if seconds < 60 then
		return seconds .. " s"
	end
	local minutes = seconds // 60
	local rest = seconds % 60
	return if rest == 0 then minutes .. " min" else string.format("%d min %d s", minutes, rest)
end

return Format

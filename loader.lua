-- An empty cache file is not a valid downloaded file. Some executors still
-- report one as existing, so check its contents before deciding to skip a download.
local function isfile(file)
	local suc, res = pcall(readfile, file)
	return suc and type(res) == 'string' and res ~= ''
end
local delfile = delfile or function(file)
	writefile(file, '')
end

-- Root loading screen: it appears before main.lua or a UI library is loaded.
local loaderGui
local function setLoaderStatus(status)
	pcall(function()
		if not loaderGui then
			loaderGui = Instance.new('ScreenGui')
			loaderGui.Name = 'VapeLoader'
			loaderGui.DisplayOrder = 9999999
			loaderGui.IgnoreGuiInset = true
			loaderGui.ResetOnSpawn = false
			loaderGui.Parent = (gethui and gethui()) or game:GetService('CoreGui')

			local card = Instance.new('Frame')
			card.Name = 'Card'
			card.AnchorPoint = Vector2.new(0.5, 0.5)
			card.BackgroundColor3 = Color3.fromRGB(16, 16, 19)
			card.BorderSizePixel = 0
			card.Position = UDim2.fromScale(0.5, 0.5)
			card.Size = UDim2.fromOffset(350, 132)
			card.Parent = loaderGui
			local corner = Instance.new('UICorner')
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = card
			local stroke = Instance.new('UIStroke')
			stroke.Color = Color3.fromRGB(45, 214, 197)
			stroke.Transparency = 0.58
			stroke.Parent = card
			local title = Instance.new('TextLabel')
			title.BackgroundTransparency = 1
			title.Font = Enum.Font.GothamBold
			title.Position = UDim2.fromOffset(24, 22)
			title.Size = UDim2.fromOffset(302, 26)
			title.Text = 'VAPE V4'
			title.TextColor3 = Color3.fromRGB(91, 241, 222)
			title.TextSize = 24
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.Parent = card
			local bar = Instance.new('Frame')
			bar.BackgroundColor3 = Color3.fromRGB(47, 47, 54)
			bar.BorderSizePixel = 0
			bar.Position = UDim2.fromOffset(24, 70)
			bar.Size = UDim2.fromOffset(302, 5)
			bar.Parent = card
			local barCorner = Instance.new('UICorner')
			barCorner.CornerRadius = UDim.new(1, 0)
			barCorner.Parent = bar
			local fill = Instance.new('Frame')
			fill.BackgroundColor3 = Color3.fromRGB(52, 227, 211)
			fill.BorderSizePixel = 0
			fill.Size = UDim2.fromScale(0.72, 1)
			fill.Parent = bar
			local fillCorner = Instance.new('UICorner')
			fillCorner.CornerRadius = UDim.new(1, 0)
			fillCorner.Parent = fill
			local label = Instance.new('TextLabel')
			label.Name = 'Status'
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.Gotham
			label.Position = UDim2.fromOffset(24, 88)
			label.Size = UDim2.fromOffset(302, 18)
			label.TextColor3 = Color3.fromRGB(171, 171, 182)
			label.TextSize = 12
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Parent = card
		end
		loaderGui.Card.Status.Text = status
	end)
end

setLoaderStatus('Checking for updates…')

local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/Mont015/BlackSharkCompiled/main/'..select(1, path:gsub('newvape/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function wipeFolder(path)
	if not isfolder(path) then return end
	for _, file in listfiles(path) do
		if file:find('loader') then continue end
		if isfile(file) and select(1, readfile(file):find('--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.')) == 1 then
			delfile(file)
		end
	end
end

for _, folder in {'newvape', 'newvape/games', 'newvape/profiles', 'newvape/assets', 'newvape/libraries', 'newvape/guis'} do
	if not isfolder(folder) then
		makefolder(folder)
	end
end

if not shared.VapeDeveloper then
	local assetVer = '1'
	local success, response = pcall(function()
		return game:HttpGet('https://api.github.com/repos/Mont015/BlackSharkCompiled/commits/main', true)
	end)
	local commit = success and response:match('"sha"%s*:%s*"([0-9a-f]+)"') or nil
	commit = commit and #commit == 40 and commit or 'main'

	if commit ~= 'main' and (isfile('newvape/profiles/commit.txt') and readfile('newvape/profiles/commit.txt') or '') ~= commit then
		setLoaderStatus('Refreshing local files…')
		pcall(delfile, 'newvape/main.lua')
		pcall(delfile, 'newvape/games/'..game.PlaceId..'.lua')
		-- UI code is cached independently from main.lua. Refresh it with each
		-- release so users do not keep an old branded interface indefinitely.
		pcall(delfile, 'newvape/guis/new.lua')
		pcall(delfile, 'newvape/guis/whisper.lua')
	end

	if (isfile('newvape/profiles/asset.txt') and readfile('newvape/profiles/asset.txt') or '') ~= assetVer then
		wipeFolder('newvape/assets')
	end

	writefile('newvape/profiles/asset.txt', assetVer)
	writefile('newvape/profiles/commit.txt', commit)
end

setLoaderStatus('Launching VAPE…')
local result = loadstring(downloadFile('newvape/main.lua'), 'main')()
task.delay(0.25, function()
	pcall(function() loaderGui:Destroy() end)
end)
return result

local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert') end
	return res
end
local isfile = isfile or function(file)
	local suc, res = pcall(function() return readfile(file) end)
	return suc and res ~= nil and res ~= ''
end
local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function() return game:HttpGet('https://raw.githubusercontent.com/7GrandDadPGN/VapeCompiled/'..readfile('newvape/profiles/commit.txt')..'/'..select(1, path:gsub('newvape/', '')), true) end)
		if not suc or res == '404: Not Found' then error(res) end
		if path:find('.lua') then res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res end
		writefile(path, res)
	end
	return (func or readfile)(path)
end
local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end
local vapeEvents = setmetatable({}, {
	__index = function(self, index)
		self[index] = Instance.new('BindableEvent')
		return self[index]
	end
})

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local textService = cloneref(game:GetService('TextService'))
local tweenService = cloneref(game:GetService('TweenService'))
local collectionService = cloneref(game:GetService('CollectionService'))
local contextService = cloneref(game:GetService('ContextActionService'))
local httpService = cloneref(game:GetService('HttpService'))
local teams = cloneref(game:GetService('Teams'))

local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer

local vape = shared.vape
local entitylib = vape.Libraries.entity
local whitelist = vape.Libraries.whitelist
local prediction = vape.Libraries.prediction
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local vm = loadstring(downloadFile('newvape/libraries/vm.lua'), 'vm')()

local jb = {}
local InfNitro = {Enabled = false}
local LazerGodmode = {Enabled = false}
local InvTracker = {Inventories = {}, Connections = {}}
local oldBulletUpdate

local function getVehicle(entity)
	if entity.Player then
		for _, car in collectionService:GetTagged('Vehicle') do
			for _, seat in car:GetChildren() do
				if (seat.Name == 'Seat' or seat.Name == 'Passenger') then
					seat = seat:FindFirstChild('PlayerName')
					if seat and seat.Value == entity.Player.Name then
						return car
					end
				end
			end
		end
	end
end

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end

	return nil
end

local function isIllegal(entity, teamCheck)
	if entity.Character:GetAttribute('HasHandcuffs') then
		return false
	end

	if entity.Player and entity.Player.Team == teams.Prisoner then
		for tool in InvTracker.Inventories[entity.Player] do
			if tool ~= 'MansionInvite' and tool ~= 'Donut' then
				return true
			end
		end

		return entity.InVehicle
	end

	return not teamCheck
end

local function isTarget(plr)
	return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end

local function notif(...)
	return vape:CreateNotification(...)
end

local OriginScanner = {Cache = {}}
run(function()
	local rayParams = RaycastParams.new()
	local overlapParams = OverlapParams.new()
	rayParams.RespectCanCollide = true
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.RespectCanCollide = true
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	OriginScanner.Ray = rayParams

	local positions = {
		Vector3.new(0, 1, 0),
		Vector3.new(1, 0, 0),
		Vector3.new(0.7, -0.5, -0.5),
		Vector3.new(-0.1, -0.8, -0.8),
		Vector3.new(-0.8, -0.5, -0.5),
		Vector3.new(-1, 0, 0),
		Vector3.new(-0.8, 0.4, 0.4),
		Vector3.new(0, 0.7, 0.7),
		Vector3.new(0.7, 0.5, 0.5),
		Vector3.new(1, 0, 0),
		Vector3.new(0.7, 0, -0.8),
		Vector3.new(-0.1, 0, -1),
		Vector3.new(-0.8, 0, -0.8),
		Vector3.new(-1, 0, 0),
		Vector3.new(-0.8, 0, 0.7),
		Vector3.new(0, 0, 1),
		Vector3.new(0.7, 0, 0.7),
		Vector3.new(1, 0, 0),
		Vector3.new(0.7, 0.4, -0.5),
		Vector3.new(-0.1, 0.7, -0.8),
		Vector3.new(-0.8, 0.4, -0.5),
		Vector3.new(-1, -0.1, 0),
		Vector3.new(-0.8, -0.5, 0.4),
		Vector3.new(0, -0.8, 0.7),
		Vector3.new(0.7, -0.6, 0.5),
		Vector3.new(0, -1, 0)
	}

	local function checkPoint(pos, params)
		for _, part in workspace:GetPartBoundsInRadius(pos, 0, params) do
			if part.CanCollide and (part:GetClosestPointOnSurface(pos) - pos).Magnitude <= 0.0001 then
				return false
			end
		end

		return true
	end

	function OriginScanner:Scan(origin, target, extra, part)
		if self.Cache[part] then
			return table.unpack(self.Cache[part])
		end

		if extra and (origin - extra).Magnitude < 14 then
			self.Cache[part] = {extra}
			return extra
		end

		local scanPositions = {}
		local diff = CFrame.lookAt(origin * Vector3.new(1, 0, 1), target * Vector3.new(1, 0, 1)).LookVector
		for _, offset in positions do
			if (offset * Vector3.new(1, 0, 1)):Dot(diff) > -0.5 then
				local pos = origin + offset * 14

				if checkPoint(pos, overlapParams) then
					table.insert(scanPositions, pos)
				end
			end
		end

		for _, pos in scanPositions do
			local ray = workspace:Raycast(target, (pos - target), rayParams)

			if not ray then
				self.Cache[part] = {pos}
				return pos
			end
		end
	end

	function OriginScanner:UpdateIgnore(model)
		local ignore = {lplr.Character, workspace.Items, model}
		for _, entity in entitylib.List do
			table.insert(ignore, entity.Character)
		end

		rayParams.FilterDescendantsInstances = ignore
		overlapParams.FilterDescendantsInstances = ignore
	end
end)

run(function()
	function InvTracker:AddInventory(inventory)
		local plr = inventory.Parent
		if plr and plr:IsA('Player') then
			self.Inventories[plr] = {}
			self.Connections[inventory] = {
				inventory.ChildAdded:Connect(function(tool)
					self.Inventories[plr][tool.Name] = tool

					if plr == lplr then
						vapeEvents.ItemAdded:Fire(tool)
					else
						local entity = entitylib.getEntity(plr)
						if entity then
							entitylib.Events.EntityUpdated:Fire(entity)
						end
					end
				end),
				inventory.ChildRemoved:Connect(function(tool)
					self.Inventories[plr][tool.Name] = nil

					if plr ~= lplr then
						local entity = entitylib.getEntity(plr)
						if entity then
							entitylib.Events.EntityUpdated:Fire(entity)
						end
					end
				end),
				inventory.Destroying:Once(function()
					for _, connection in self.Connections[inventory] do
						connection:Disconnect()
					end

					table.clear(self.Connections[inventory])
					table.clear(self.Inventories[plr])
					self.Inventories[plr] = nil
				end)
			}

			for _, tool in inventory:GetChildren() do
				self.Inventories[plr][tool.Name] = tool
			end
		end
	end

	for _, inventory in collectionService:GetTagged('Inventory') do
		InvTracker:AddInventory(inventory)
	end

	vape:Clean(collectionService:GetInstanceAddedSignal('Inventory'):Connect(function(inventory)
		InvTracker:AddInventory(inventory)
	end))

	vape:Clean(function()
		for _, connections in InvTracker.Connections do
			for _, connection in connections do
				connection:Disconnect()
			end
		end

		table.clear(InvTracker.Connections)
		table.clear(InvTracker.Inventories)
	end)
end)

local BountyTracker = {Data = {}, List = {}}
run(function()
	function BountyTracker:UpdateData(data, update)
		table.clear(self.Data)
		table.clear(self.List)

		for _, entry in data do
			self.Data[entry.Name] = entry.Bounty
			table.insert(self.List, {entry.Name, entry.Bounty})
		end

		table.sort(self.List, function(a, b)
			return a[2] > b[2]
		end)

		if update then
			for _, entity in entitylib.List do
				entitylib.Events.EntityUpdated:Fire(entity)
			end
		end
	end

	BountyTracker:UpdateData(httpService:JSONDecode(replicatedStorage.BountyData.Value))
	vape:Clean(replicatedStorage.BountyData:GetPropertyChangedSignal('Value'):Connect(function()
		BountyTracker:UpdateData(httpService:JSONDecode(replicatedStorage.BountyData.Value), true)
	end))
end)

run(function()
	local function getMousePosition()
		if inputService.TouchEnabled then
			return gameCamera.ViewportSize / 2
		end

		return inputService:GetMouseLocation()
	end

	entitylib.getUpdateConnections = function(entity)
		local hum = entity.Humanoid
		entity.InVehicle = not entity.Character:GetAttribute('HasHandcuffs') and (entity.Character:GetAttribute('InVehicle') or entity.InVehicle)
		entity.Illegal = isIllegal(entity, true)

		return {
			hum:GetPropertyChangedSignal('Health'),
			hum:GetPropertyChangedSignal('MaxHealth'),
			entity.Character:GetAttributeChangedSignal('InVehicle'),
			entity.Character:GetAttributeChangedSignal('HasHandcuffs'),
			{
				Connect = function()
					entity.Friend = entity.Player and isFriend(entity.Player) or nil
					entity.Target = entity.Player and isTarget(entity.Player) or nil
					return {Disconnect = function() end}
				end
			}
		}
	end

	entitylib.targetCheck = function(entity)
		if entity.TeamCheck then return entity:TeamCheck() end
		if entity.NPC then return true end
		if isFriend(entity.Player) then return false end
		if not select(2, whitelist:get(entity.Player)) then return false end

		if lplr.Team == teams.Police then
			return entity.Player.Team ~= teams.Police
		else
			return entity.Player.Team == teams.Police
		end

		return true
	end

	entitylib.EntityMouse = function(entitysettings)
		if entitylib.isAlive then
			local mouseLocation, sortingTable = entitysettings.MouseOrigin or getMousePosition(), {}
			local localPosition = entitysettings.Origin or entitylib.character.HumanoidRootPart.Position
			for _, entity in entitylib.List do
				if not entitysettings.Players and entity.Player then continue end
				if not entitysettings.NPCs and entity.NPC then continue end
				if not entity.Targetable then continue end
				local position, vis = gameCamera.WorldToViewportPoint(gameCamera, entity[entitysettings.Part].Position)
				if not vis then continue end
				local mag = (mouseLocation - Vector2.new(position.x, position.y)).Magnitude
				if mag > entitysettings.Range then continue end
				if entitylib.isVulnerable(entity, entitysettings.AttackCheck) then
					if entitysettings.RangePosition then
						local pmag = (entity[entitysettings.Part].Position - localPosition).Magnitude
						if pmag > entitysettings.RangePosition then continue end
					end

					table.insert(sortingTable, {
						Entity = entity,
						Magnitude = entity.Target and -1 or mag
					})
				end
			end

			table.sort(sortingTable, entitysettings.Sort or function(a, b)
				return a.Magnitude < b.Magnitude
			end)

			for _, v in sortingTable do
				if entitysettings.Wallcheck then
					if entitylib.Wallcheck(entitysettings.Origin, v.Entity[entitysettings.Part].Position, entitysettings.Wallbang, v.Entity[entitysettings.Part]) then continue end
				end
				table.clear(entitysettings)
				table.clear(sortingTable)
				return v.Entity
			end
			table.clear(sortingTable)
		end
		table.clear(entitysettings)
	end

	entitylib.EntityPosition = function(entitysettings)
		if entitylib.isAlive then
			local localPosition, sortingTable = entitysettings.Origin or entitylib.character.HumanoidRootPart.Position, {}
			for _, entity in entitylib.List do
				if not entitysettings.Players and entity.Player then continue end
				if not entitysettings.NPCs and entity.NPC then continue end
				if not entity.Targetable then continue end
				local mag = (entity[entitysettings.Part].Position - localPosition).Magnitude
				if mag > entitysettings.Range then continue end
				if entitylib.isVulnerable(entity, entitysettings.AttackCheck) then
					table.insert(sortingTable, {
						Entity = entity,
						Magnitude = entity.Target and -1 or mag
					})
				end
			end

			table.sort(sortingTable, entitysettings.Sort or function(a, b)
				return a.Magnitude < b.Magnitude
			end)

			for _, v in sortingTable do
				if entitysettings.Wallcheck then
					if entitylib.Wallcheck(localPosition, v.Entity[entitysettings.Part].Position, entitysettings.Wallbang, v.Entity[entitysettings.Part]) then continue end
				end
				table.clear(entitysettings)
				table.clear(sortingTable)
				return v.Entity
			end
			table.clear(sortingTable)
		end
		table.clear(entitysettings)
	end

	entitylib.AllPosition = function(entitysettings)
		local returned = {}
		if entitylib.isAlive then
			local localPosition, sortingTable = entitysettings.Origin or entitylib.character.HumanoidRootPart.Position, {}
			for _, entity in entitylib.List do
				if not entitysettings.Players and entity.Player then continue end
				if not entitysettings.NPCs and entity.NPC then continue end
				if not entity.Targetable then continue end
				local mag = (entity[entitysettings.Part].Position - localPosition).Magnitude
				if mag > entitysettings.Range then continue end
				if entitylib.isVulnerable(entity, entitysettings.AttackCheck) then
					table.insert(sortingTable, {
						Entity = entity,
						Magnitude = entity.Target and -1 or mag
					})
				end
			end

			table.sort(sortingTable, entitysettings.Sort or function(a, b)
				return a.Magnitude < b.Magnitude
			end)

			for _, v in sortingTable do
				if entitysettings.Wallcheck then
					if entitylib.Wallcheck(localPosition, v.Entity[entitysettings.Part].Position, entitysettings.Wallbang, v.Entity[entitysettings.Part]) then continue end
				end
				table.insert(returned, v.Entity)
				if #returned >= (entitysettings.Limit or math.huge) then break end
			end
			table.clear(sortingTable)
		end
		table.clear(entitysettings)
		return returned
	end

	entitylib.Wallcheck = function(origin, position, checkpos, part)
		local ray = workspace.Raycast(workspace, position, (origin - position), OriginScanner.Ray)
		if ray then
			return not checkpos or not OriginScanner:Scan(checkpos, position, ray.Position + ray.Normal * 0.01, part)
		end

		return false
	end
end)
entitylib.start()

run(function()
	local function dumpRemotes(scripts, renamed)
		local returned = {}

		for _, scr in scripts do
			local deserializedcode = vm.luau_deserialize(getscriptbytecode(scr))

			for _, proto in deserializedcode.protoList do
				local stack, top, code = {}, -1, proto.code
				for i, inst in code do
					if inst.opcode == 4 then -- LOADN
						stack[inst.A] = inst.D
					elseif inst.opcode == 5 then -- LOADK
						stack[inst.A] = inst.K
					elseif inst.opcode == 6 then -- MOVE
						stack[inst.A] = stack[inst.B]
					elseif inst.opcode == 12 then -- GETIMPORT
						local count, import = inst.KC, getrenv()[inst.K0]

						if count == 1 then
							stack[inst.A] = import
						elseif count == 2 then
							stack[inst.A] = import[inst.K1]
						elseif count == 3 then
							stack[inst.A] = import[inst.K1][inst.K2]
						end
					elseif inst.opcode == 20 then -- NAMECALL
						local A, B, kv = inst.A, inst.B, inst.K
						stack[A + 1] = stack[B]

						local callInst = code[i + 2]
						local callA, callB, callC = callInst.A, callInst.B, callInst.C
						local params = if callB == 0 then top - callA else callB - 1
						if kv == 'sub' or kv == 'reverse' then
							local arg1, arg2, arg3 = table.unpack(stack, callA + 1, callA + params)
							if kv == 'reverse' and not arg1 then arg1 = 'a' end

							local ret_list = table.pack(string[kv](arg1, arg2, arg3))
							local ret_num = ret_list.n - 1
							if callC == 0 then
								top = callA + ret_num - 1
							else
								ret_num = callC - 1
							end

							table.move(ret_list, 1, ret_num, callA, stack)
						elseif kv == 'FireServer' then
							local name, val = proto.debugname == '(??)' and scr.Name or proto.debugname, stack[callA + 2]
							if name == val then table.insert(returned, val) continue end
							if returned[name] then
								for i = 1, 10 do
									if not returned[name..i] then name ..= i break end
								end
							end

							returned[name] = val
						end
					elseif inst.opcode == 49 then -- CONCAT
						local s = ""
						for i = inst.B, inst.C do
							if type(stack[i]) ~= 'string' then continue end
							s ..= stack[i]
						end
						stack[inst.A] = s
					end
				end
			end
		end

		for i, v in table.clone(returned) do
			if renamed[i] then
				returned[i] = nil
				returned[renamed[i]] = v
			end
		end

		return returned
	end

	local function getAwardEvent()
		for _, callback in debug.getupvalue(jb.TeamChooseController.Init, 2) do
			if type(callback) == 'function' then
				for _, const in debug.getconstants(callback) do
					if tostring(const):find('PlusCash') then
						return callback
					end
				end
			end
		end
	end

	local function toMoney(num)
		local one, two, three = string.match(tostring(num), '^([^%d]*%d)(%d*)(.-)$')
		return one .. (two:reverse():gsub('(%d%d%d)', '%1,'):reverse() .. three)..'$'
	end

	jb = {
		Audio = require(replicatedStorage.Std.Audio),
		BulletEmitter = require(replicatedStorage.Game.ItemSystem.BulletEmitter),
		CircleAction = require(replicatedStorage.Module.UI).CircleAction,
		FallingController = require(replicatedStorage.Game.Falling),
		GunController = require(replicatedStorage.Game.Item.Gun),
		InventoryItemBinder = require(replicatedStorage.Inventory.InventoryItemBinder),
		ItemSystemController = require(replicatedStorage.Game.ItemSystem.ItemSystem),
		LightningUtils = require(replicatedStorage.Game.LightningUtils),
		PlayerUtils = require(replicatedStorage.Game.PlayerUtils),
		TeamChooseController = require(replicatedStorage.TeamSelect.TeamChooseUI),
		VehicleController = require(replicatedStorage.Vehicle.VehicleUtils)
	}

	if not jb.VehicleController.toggleLocalLocked or not jb.VehicleController.NitroShopVisible then
		repeat
			task.wait()
		until (jb.VehicleController.toggleLocalLocked and jb.VehicleController.NitroShopVisible) or vape.Loaded == nil

		if vape.Loaded == nil then
			return
		end
	end

	local remotetable = debug.getupvalue(jb.VehicleController.toggleLocalLocked, 2)
	local fireserver, hook = remotetable.FireServer

	remotes = dumpRemotes({
		replicatedStorage.Game.TrainSystem.LocomotiveFront,
		replicatedStorage.Game.ItemSystem.ItemSystem,
		replicatedStorage.Game.CashBuyUI,
		replicatedStorage.Game.GunShop.GunShopUI,
		replicatedStorage.Game.Item.Taser,
		replicatedStorage.Game.Item.Donut,
		replicatedStorage.Game.Item.Gun,
		replicatedStorage.Game.Falling,
		lplr.PlayerScripts.LocalScript
	}, {
		Action3 = 'Pickup',
		AttemptArrest = 'Arrest',
		attemptPunch = 'Punch',
		AttemptVehicleEject = 'Eject',
		AttemptVehicleEnter = 'GetIn',
		BroadcastInputBegan = 'InputBegan',
		BroadcastInputEnded = 'InputEnded',
		CalculateDelta = 'UseNitro',
		Draw = 'TaseReplicate',
		Gun = 'PopTires',
		GunShopUI = 'UnequipItem',
		GunShopUI1 = 'EquipItem',
		LocalScript2 = 'LookAngle',
		LocalScript = 'SelfDamage',
		onPressed = 'FlipVehicle',
		OnJump = 'GetOut',
		OnJump1 = 'GetOut',
		UpdateMousePosition = 'AimPosition'
	})

	local function FireServerHook(...)
		local self, id = ...
		local remote
		for name, key in remotes do
			if key == id then
				remote = name
			end
		end

		if InfNitro.Enabled and remote == 'UseNitro' then return end
		if LazerGodmode.Enabled and remote == 'SelfDamage' then return end
		if remote ~= 'LookAngle' and remote ~= 'AimPosition' and shared.VapeDeveloper then
			local called = getfenv(3)
			called = called and called.script
			if called and (not remote) then
				print(id, 'called with', called:GetFullName())
			end

			print(id, remote or id, ...)
		end

		return hook(...)
	end

	hook = hookfunction(fireserver, function(...)
		return FireServerHook(...)
	end)

	function jb:FireServer(id, ...)
		if not remotes[id] then
			notif('Vape', 'Failed to find remote ('..id..')', 10, 'alert')
			return
		end

		return hook(remotetable, remotes[id], ...)
	end

	local arrests = sessioninfo:AddItem('Arrested')
	local moneymade = sessioninfo:AddItem('Money Made', 0, toMoney, true)
	local bounty = sessioninfo:AddItem('Bounty List', '', function()
		local text = ''

		for _, data in BountyTracker.List do
			text = text..'\n'..data[1]..': '..toMoney(tostring(data[2]))
		end

		return text
	end, false)

	local awardCallback = getAwardEvent()
	if awardCallback then
		local hook
		hook = hookfunction(awardCallback, function(amount, text, ...)
			moneymade:Increment(amount)
			if text == 'Arrest' then
				arrests:Increment()
			end

			return hook(amount, text, ...)
		end)

		vape:Clean(function()
			restorefunction(awardCallback)
		end)
	end

	table.insert(whitelist.tagcallback, function(plr, plrtag, rich)
		if plr then
			local entity = entitylib.getEntity(plr)
			if entity then
				if plr.Team == teams.Prisoner and entity.Illegal then
					table.insert(plrtag, {text = rich and '💢' or 'Hostile'})
				end

				if BountyTracker.Data[plr.Name] then
					table.insert(plrtag, {
						text = toMoney(tostring(BountyTracker.Data[plr.Name])),
						color = Color3.fromHSV(0.4, 0.89, 0.75)
					})
				end
			end
		end
	end)

	vape:Clean(runService.RenderStepped:Connect(function()
		table.clear(OriginScanner.Cache)
	end))

	vape:Clean(entitylib.Events.EntityUpdated:Connect(function(entity)
		entity.InVehicle = not entity.Character:GetAttribute('HasHandcuffs') and (entity.Character:GetAttribute('InVehicle') or entity.InVehicle)
		entity.Illegal = isIllegal(entity, true)
	end))

	vape:Clean(function()
		table.clear(remotes)
		table.clear(jb)
		restorefunction(fireserver)
	end)
end)

for _, v in {'Reach', 'TriggerBot', 'Disabler', 'AntiFall', 'HitBoxes', 'Killaura', 'MurderMystery'} do
	vape:Remove(v)
end

run(function()
	local SilentAim
	local Target
	local Mode
	local Range
	local HitChance
	local HeadshotChance
	local Wallbang
	local CircleColor
	local CircleTransparency
	local CircleFilled
	local CircleObject
	local old
	local ProjectileRaycast = RaycastParams.new()
	ProjectileRaycast.RespectCanCollide = true
	
	local function getMousePosition()
		if inputService.TouchEnabled then
			return gameCamera.ViewportSize / 2
		end
	
		return inputService:GetMouseLocation()
	end
	
	local function getTarget(origin, limit, attackcheck)
		local targetPart = 'RootPart'
		local entity = entitylib['Entity'..Mode.Value]({
			Range = Mode.Value == 'Position' and math.min(Range.Value, limit) or Range.Value,
			RangePosition = limit,
			Wallcheck = Target.Walls.Enabled and true or nil,
			Wallbang = Wallbang.Enabled and entitylib.character.RootPart.Position or nil,
			Part = targetPart,
			Origin = origin.Position,
			Players = Target.Players.Enabled,
			NPCs = Target.NPCs.Enabled
		})
	
		if entity then
			targetinfo.Targets[entity] = tick() + 1
		end
	
		return entity, entity and entity[targetPart], origin
	end
	
	local function Hook(...)
		local item = ...
	
		if item.Local then
			OriginScanner:UpdateIgnore(item.Model)
			local entity, targetPart, origin = getTarget(item.Tip.CFrame, (item.Config.BulletSpeed or 1000) * item.BulletEmitter.LifeSpan)
	
			if entity then
				local oldTip
				if Wallbang.Enabled then
					local ray = workspace:Raycast(targetPart.Position, (origin.Position - targetPart.Position), OriginScanner.Ray)
	
					if ray then
						local neworigin, hitbox = OriginScanner:Scan(entitylib.character.RootPart.Position, targetPart.Position, ray.Position + ray.Normal * 0.01, targetPart)
	
						if neworigin then
							oldTip = item.Tip.CFrame
							origin = CFrame.lookAt(neworigin, targetPart.Position)
							item.Tip.CFrame = origin
						end
					end
				end
	
				ProjectileRaycast.FilterDescendantsInstances = {gameCamera, entity.Character, workspace.Vehicles}
				ProjectileRaycast.CollisionGroup = entity.RootPart.CollisionGroup
	
				local trajectory = prediction.SolveTrajectory(origin.Position, item.Config.BulletSpeed or 1000, math.abs(item.BulletEmitter.GravityVector.Y), entity.RootPart.Position, oldBulletUpdate and Vector3.zero or entity.RootPart.AssemblyLinearVelocity, workspace.Gravity, entity.HipHeight, nil, ProjectileRaycast)
				if trajectory then
					targetinfo.Targets[entity] = tick() + 1
					item.TipDirection = CFrame.lookAt(origin.Position, trajectory).LookVector
				end
	
				if oldTip then
					local call = table.pack(old(...))
					item.Tip.CFrame = oldTip
					return unpack(call, 1, call.n)
				end
			end
		end
	
		return old(...)
	end
	
	SilentAim = vape.Categories.Combat:CreateModule({
		Name = 'SilentAim',
		Function = function(callback)
			if CircleObject then
				CircleObject.Visible = callback and Mode.Value == 'Mouse'
			end
	
			if callback then
				old = hookfunction(jb.GunController.ShootOther, function(...)
					return Hook(...)
				end)
	
				repeat
					if CircleObject then
						CircleObject.Position = getMousePosition()
					end
	
					task.wait()
				until not SilentAim.Enabled
			else
				if old then
					restorefunction(jb.GunController.ShootOther)
					old = nil
				end
			end
		end,
		Tooltip = 'Silently adjusts your aim towards the enemy'
	})
	Target = SilentAim:CreateTargets({
		Players = true
	})
	Mode = SilentAim:CreateDropdown({
		Name = 'Mode',
		List = {'Mouse', 'Position'},
		Function = function(val)
			if CircleObject then
				CircleObject.Visible = SilentAim.Enabled and val == 'Mouse'
			end
		end,
		Tooltip = 'Mouse - Checks for entities near the mouses position\nPosition - Checks for entities near the local character'
	})
	Range = SilentAim:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 150,
		Function = function(val)
			if CircleObject then
				CircleObject.Radius = val
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Wallbang = SilentAim:CreateToggle({
		Name = 'Wallbang',
		Tooltip = 'Allow you to shoot people through walls when specific conditions are met.\n(If the entity has a valid hitbox position exposed or if the shoot position can be moved past walls (eg hugging walls))'
	})
	SilentAim:CreateToggle({
		Name = 'Range Circle',
		Function = function(callback)
			if callback then
				CircleObject = Drawing.new('Circle')
				CircleObject.Filled = CircleFilled.Enabled
				CircleObject.Color = Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value)
				CircleObject.Position = vape.gui.AbsoluteSize / 2
				CircleObject.Radius = Range.Value
				CircleObject.NumSides = 100
				CircleObject.Transparency = 1 - CircleTransparency.Value
				CircleObject.Visible = SilentAim.Enabled and Mode.Value == 'Mouse'
			else
				pcall(function()
					CircleObject.Visible = false
					CircleObject:Remove()
				end)
			end
			CircleColor.Object.Visible = callback
			CircleTransparency.Object.Visible = callback
			CircleFilled.Object.Visible = callback
		end
	})
	CircleColor = SilentAim:CreateColorSlider({
		Name = 'Circle Color',
		Function = function(hue, sat, val)
			if CircleObject then
				CircleObject.Color = Color3.fromHSV(hue, sat, val)
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleTransparency = SilentAim:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Default = 0.5,
		Function = function(val)
			if CircleObject then
				CircleObject.Transparency = 1 - val
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleFilled = SilentAim:CreateToggle({
		Name = 'Circle Filled',
		Function = function(callback)
			if CircleObject then
				CircleObject.Filled = callback
			end
		end,
		Darker = true,
		Visible = false
	})
end)

run(function()
	local AutoArrest
	local Range
	local AutoEquip
	local cooldown = 0
	local ejectCooldown = 0
	
	local function equipTool(tool)
		local obj = jb.InventoryItemBinder:Get(tool)
		if obj then
			obj:AttemptSelect()
		end
	end
	
	AutoArrest = vape.Categories.Blatant:CreateModule({
		Name = 'AutoArrest',
		Function = function(callback)
			if callback then
				repeat
					local cuffs = InvTracker.Inventories[lplr].Handcuffs
	
					if lplr.Team == teams.Police and cuffs then
						local serverPos = entitylib.character.Humanoid:FindFirstChild('HumanoidUnloadServerPosition')
						local vehicle
						local target
	
						local entities = entitylib.AllPosition({
							Players = true,
							Part = 'RootPart',
							Range = Range.Value,
							Origin = serverPos and serverPos.Value or nil
						})
	
						for _, entity in entities do
							if entity.Player and isIllegal(entity) then
								if entity.Character:GetAttribute('InVehicle') then
									if not vehicle and ejectCooldown < os.clock() then
										vehicle = getVehicle(entity)
									end
								elseif not entity.Character:GetAttribute('HasHandcuffs') and not target and cooldown < os.clock() then
									target = entity.Player.Name
								end
							end
						end
	
						if vehicle or target then
							local lastEquipped = jb.ItemSystemController:GetLocalEquipped()
							if AutoEquip.Enabled and not (lastEquipped and lastEquipped.__ClassName == 'Handcuffs') then
								equipTool(cuffs)
							end
	
							local equipped = jb.ItemSystemController:GetLocalEquipped()
							if equipped and equipped.__ClassName == 'Handcuffs' then
								if vehicle then
									jb:FireServer('Eject', vehicle)
									ejectCooldown = os.clock() + 0.2
								end
	
								if target then
									jb:FireServer('Arrest', target)
									cooldown = os.clock() + 0.5
								end
							end
	
							if AutoEquip.Enabled and lastEquipped ~= equipped then
								equipTool(lastEquipped and lastEquipped.inventoryItemValue or cuffs)
							end
						end
					end
	
					task.wait(0.016)
				until not AutoArrest.Enabled
			end
		end,
		Tooltip = 'Automatically uses handcuffs on nearby entities'
	})
	Range = AutoArrest:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 16,
		Default = 16,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AutoEquip = AutoArrest:CreateToggle({
		Name = 'AutoEquip',
		Tooltip = 'Automatically equip the handcuffs for performing actions (RISKY)'
	})
end)

run(function()
	local AutoPop
	local Range
	local TeamCheck
	local hitDelays = {}
	
	local function getEntitiesInVehicle(car)
		local entities = {}
	
		for _, seat in car:GetChildren() do
			if (seat.Name == 'Seat' or seat.Name == 'Passenger') then
				seat = seat:FindFirstChild('PlayerName')
				if seat then
					for _, entity in entitylib.List do
						if entity.Player and entity.Player.Name == seat.Value then
							table.insert(entities, entity)
						end
					end
				end
			end
		end
	
		return entities
	end
	
	local function getVehiclesNear()
		local vehicles = {}
	
		if entitylib.isAlive then
			local localPosition = entitylib.character.HumanoidRootPart.Position
	
			for _, vehicle in collectionService:GetTagged('Vehicle') do
				if vehicle.PrimaryPart and (vehicle.PrimaryPart.Position - localPosition).Magnitude <= Range.Value then
					local entities = getEntitiesInVehicle(vehicle)
					local canAttack = #entities > 0
	
					if TeamCheck.Enabled then
						for _, entity in entities do
							if not entity.Targetable then
								canAttack = false
								break
							end
						end
					end
	
					if canAttack then
						table.insert(vehicles, vehicle)
					end
				end
			end
		end
	
		return vehicles
	end
	
	AutoPop = vape.Categories.Blatant:CreateModule({
		Name = 'AutoPop',
		Function = function(callback)
			if callback then
				task.spawn(function()
					repeat
						local item = jb.ItemSystemController:GetLocalEquipped()
						if item and item.BulletEmitter then
							for _, car in getVehiclesNear() do
								if (hitDelays[car] or 0) > os.clock() then
									continue
								end
	
								hitDelays[car] = os.clock() + 0.1
								jb:FireServer('PopTires', car, item.__ClassName)
							end
						end
	
						task.wait(0.016)
					until not AutoPop.Enabled
				end)
			else
				table.clear(hitDelays)
			end
		end,
		Tooltip = 'Automatically pops vehicles tires around you'
	})
	Range = AutoPop:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 600,
		Default = 600,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	TeamCheck = AutoPop:CreateToggle({
		Name = 'Priority Only'
	})
end)

run(function()
	local AutoPunch
	
	AutoPunch = vape.Categories.Blatant:CreateModule({
		Name = 'AutoPunch',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive then
						jb:FireServer('Punch')
					end
	
					task.wait(0.3)
				until not AutoPunch.Enabled
			end
		end,
		Tooltip = 'Always punches people infront of you'
	})
end)

run(function()
	local AutoTaze
	local Range
	local HandCheck
	local CooldownBar
	local cdholder, cdframe, cdlabel
	
	local function drawTaser(origin, target)
		local tracer = jb.LightningUtils.strikePosition({
			Transparency = 0,
			PartWidth = 0.1,
			NumSegments = 10,
			OffsetRadius = 2,
			Origin = origin.Position,
			Target = target,
			Color = Color3.fromRGB(175, 130, 90)
		})
	
		jb.Audio.ObjectLocal(origin, 754972373)
	
		task.delay(0.1, tracer.Destroy, tracer)
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	end
	
	AutoTaze = vape.Categories.Blatant:CreateModule({
		Name = 'AutoTaze',
		Function = function(callback)
			if callback then
				repeat
					local taser = InvTracker.Inventories[lplr].Taser
	
					if taser then
						local equipped = jb.ItemSystemController:GetLocalEquipped()
						local isTaser = equipped and equipped.__ClassName == 'Taser'
	
						if (not HandCheck.Enabled or isTaser) then
							local entities = entitylib.AllPosition({
								Players = true,
								Part = 'RootPart',
								Range = Range.Value
							})
	
							if (taser:GetAttribute('NextUse') or 0) < os.clock() then
								for _, entity in entities do
									if isIllegal(entity) and not (entity.Character:GetAttribute('HasHandcuffs') or entity.Character:GetAttribute('InVehicle')) then
										drawTaser(equipped and equipped.Tip or entitylib.character.RootPart, entity.RootPart.Position)
										taser:SetAttribute('LastUsedAt', os.clock())
										taser:SetAttribute('NextUse', os.clock() + 10)
	
										if isTaser then
											jb:FireServer('TaseReplicate', entity.RootPart.Position)
										end
	
										jb:FireServer('Tase', entity.Humanoid, entity.RootPart, entity.RootPart.Position)
	
										if isTaser then
											equipped:BroadcastInputBegan({UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.None})
										end
	
										break
									end
								end
							end
						end
					end
	
					if cdholder then
						if vape.ThreadFix then
							setthreadidentity(8)
						end
	
						cdholder.Visible = taser and (taser:GetAttribute('NextUse') or 0) > os.clock() or false
	
						if cdholder.Visible then
							local diff = (taser:GetAttribute('NextUse') or 0) - os.clock()
							cdframe.Size = UDim2.new(math.clamp(diff / 10, 0, 1), -2, 1, -2)
							cdlabel.Text = (math.round(diff * 10) / 10)..'s'
						end
					end
	
					task.wait(0.016)
				until not AutoTaze.Enabled
			else
				if cdholder then
					cdholder.Visible = false
				end
			end
		end,
		Tooltip = 'Immobilizes entities around you'
	})
	Range = AutoTaze:CreateSlider({
		Name = 'Range',
		Min = 0,
		Max = 75,
		Default = 75,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	HandCheck = AutoTaze:CreateToggle({
		Name = 'Hand Check'
	})
	CooldownBar = AutoTaze:CreateToggle({
		Name = 'Cooldown Bar',
		Function = function(callback)
			if callback then
				cdholder = Instance.new('Frame')
				cdholder.Visible = false
				cdholder.BorderSizePixel = 0
				cdholder.BackgroundTransparency = 0.7
				cdholder.AnchorPoint = Vector2.new(0.5, 0)
				cdholder.BackgroundColor3 = Color3.new(1, 1, 1)
				cdholder.Size = UDim2.new(0.1, 0, 0, 5)
				cdholder.Position = UDim2.fromScale(0.5, 0.55)
				cdholder.Parent = vape.gui
				cdframe = Instance.new('Frame')
				cdframe.BorderSizePixel = 0
				cdframe.BackgroundTransparency = 0.3
				cdframe.BackgroundColor3 = Color3.new(1, 1, 1)
				cdframe.Size = UDim2.new(1, -2, 1, -2)
				cdframe.Position = UDim2.fromOffset(1, 1)
				cdframe.Parent = cdholder
				cdlabel = Instance.new('TextLabel')
				cdlabel.Size = UDim2.new(1, 0, 0, 14)
				cdlabel.Position = UDim2.fromOffset(0, 10)
				cdlabel.BackgroundTransparency = 1
				cdlabel.TextColor3 = Color3.new(1, 1, 1)
				cdlabel.TextScaled = true
				cdlabel.TextStrokeTransparency = 0
				cdlabel.Font = Enum.Font.Arial
				cdlabel.Parent = cdholder
			else
				if cdholder then
					cdholder:Destroy()
					cdholder = nil
				end
			end
		end,
		Tooltip = 'Show the cooldown for arresting'
	})
end)

run(function()
	local GunModifications
	local Headshot
	local Hitscan
	local oldhit
	
	GunModifications = vape.Categories.Blatant:CreateModule({
		Name = 'GunModifications',
		Function = function(callback)
			if callback then
				if Hitscan.Enabled then
					oldBulletUpdate = hookfunction(jb.BulletEmitter.Update, function(...)
						local self = ...
						if self.Local then
							self.LastUpdate = tick() - (self.LifeSpan - 0.1)
						end
	
						return oldBulletUpdate(...)
					end)
				end
	
				if Headshot.Enabled then
					oldhit = hookfunction(jb.GunController.BulletEmitterOnLocalHitPlayer, function(...)
						local shotData = select(15, ...)
						shotData.isHeadshot = true
						return oldhit(...)
					end)
				end
			else
				if oldBulletUpdate then
					restorefunction(jb.BulletEmitter.Update)
					oldBulletUpdate = nil
				end
	
				if oldhit then
					restorefunction(jb.GunController.BulletEmitterOnLocalHitPlayer)
					oldhit = nil
				end
			end
		end,
		Tooltip = 'Apply various modifications to enhance any firearm'
	})
	Headshot = GunModifications:CreateToggle({
		Name = 'Always Headshot',
		Function = function()
			if GunModifications.Enabled then
				GunModifications:Toggle()
				GunModifications:Toggle()
			end
		end,
		Tooltip = 'Force headshot damage when hitting any body part'
	})
	Hitscan = GunModifications:CreateToggle({
		Name = 'Hitscan Bullets',
		Function = function()
			if GunModifications.Enabled then
				GunModifications:Toggle()
				GunModifications:Toggle()
			end
		end,
		Tooltip = 'Instantly teleport bullets along the destination trajectory'
	})
end)

run(function()
	local modified = {}
	local overlapCheck = OverlapParams.new()
	
	LazerGodmode = vape.Categories.Blatant:CreateModule({
		Name = 'LazerGodmode',
		Function = function(callback)
			if callback then
				LazerGodmode:Clean(runService.PreSimulation:Connect(function()
					if entitylib.isAlive then
						overlapCheck.FilterDescendantsInstances = {gameCamera, lplr.Character}
	
						local parts = workspace:GetPartBoundsInRadius(entitylib.character.RootPart.Position, 10, overlapCheck)
						for _, part in parts do
							modified[part] = true
							part.CanTouch = false
						end
	
						for part in modified do
							if not table.find(parts, part) then
								modified[part] = nil
								part.CanTouch = true
							end
						end
					end
				end))
			else
				for inst in modified do
					inst.CanTouch = true
				end
	
				table.clear(modified)
			end
		end,
		Tooltip = 'Allow you to ignore lazers found in the jewelry store'
	})
end)

run(function()
	vape.Categories.Blatant:CreateModule({
		Name = 'NoFall',
		Function = function(callback)
			debug.setconstant(debug.getupvalue(jb.FallingController.Init, 20), 9, callback and 'Archivable' or 'Sit')
		end,
		Tooltip = 'Disables ragdoll handling & fall damage'
	})
end)

run(function()
	local oldnitro
	
	InfNitro = vape.Categories.Utility:CreateModule({
		Name = 'InfiniteNitro',
		Function = function(callback)
			if callback then
				oldnitro = jb.VehicleController.nitroState.Nitro
				jb.VehicleController.updateSpdBarRatio(1)
	
				repeat
					jb.VehicleController.nitroState.Nitro = 250
					task.wait(0.1)
				until not InfNitro.Enabled
			else
				jb.VehicleController.nitroState.Nitro = oldnitro
				jb.VehicleController.updateSpdBarRatio(oldnitro / 250)
			end
		end,
		Tooltip = 'Infinite boost for the local car'
	})
end)

run(function()
	local old
	local await
	
	vape.Categories.Utility:CreateModule({
		Name = 'InstantAction',
		Function = function(callback)
			if callback then
				old = hookfunction(jb.CircleAction.Press, function(...)
					local action = jb.CircleAction.Spec
					if action and action.Timed and not (action.ReleaseCallback or await) then
						local old = action.Timed
	
						action.Timed = false
						await = task.defer(function()
							action.Timed = old
							await = nil
						end)
					end
	
					return old(...)
				end)
			else
				if old then
					restorefunction(jb.CircleAction.Press)
					old = nil
				end
			end
		end,
		Tooltip = 'Allows you to instantly complete ProximityPrompt actions'
	})
end)

run(function()
	local AutoHeal
	
	AutoHeal = vape.Categories.Inventory:CreateModule({
		Name = 'AutoHeal',
		Function = function(callback)
			if callback then
				repeat
					local entity = entitylib.isAlive and entitylib.character
					local donut = InvTracker.Inventories[lplr].Donut
	
					if donut and entity and entity.Humanoid.Health <= 70 then
						jb:FireServer('Donut')
					end
	
					task.wait(0.05)
				until not AutoHeal.Enabled
			end
		end,
		Tooltip = 'Automatically heal damage with consumables.'
	})
end)

run(function()
	local AutoHotbar
	local SortList = {Police = {}, Prisoner = {}}
	
	local function DoSorting()
		local collected = {}
		for _, item in InvTracker.Inventories[lplr] do
			table.insert(collected, {
				Tool = item,
				Slot = item:GetAttribute('DisplayOrder') or 0
			})
		end
	
		local list = SortList[lplr.Team == teams.Police and 'Police' or 'Prisoner']
		table.sort(collected, function(a, b)
			return (list[a.Tool.name] or 15 + a.Slot) < (list[b.Tool.name] or 15 + b.Slot)
		end)
	
		for index, item in collected do
			item.Tool:SetAttribute('DisplayOrder', index)
			table.clear(item)
		end
	
		table.clear(collected)
	end
	
	AutoHotbar = vape.Categories.Inventory:CreateModule({
		Name = 'AutoHotbar',
		Function = function(callback)
			if callback then
				AutoHotbar:Clean(vapeEvents.ItemAdded.Event:Connect(DoSorting))
				task.spawn(DoSorting)
			end
		end,
		Tooltip = 'Automatically sort hotbar entries'
	})
	
	for _, team in {'Prisoner', 'Police'} do
		AutoHotbar:CreateTextList({
			Name = team..' Pickups',
			Default = team == 'Prisoner' and {'1/AK47', '2/Shotgun', '3/Pistol'} or {'1/AK47', '2/Shotgun', '3/Pistol', '4/Taser', '5/Taser', '6/RoadSpike'},
			Placeholder = 'priority/item',
			Function = function(list)
				table.clear(SortList[team])
	
				for _, entry in list do
					local data = entry:split('/')
					local priority = tonumber(data[1]) or 999
					SortList[team][data[2]] = priority
				end
			end
		})
	end
end)

run(function()
	local AutoPickup
	local Lists = {}
	local Regions = {}
	local pickupList = {Police = {}, Prisoner = {}}
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.MaxParts = 1
	
	local function doesPlayerOwn(item)
		local items = lplr:FindFirstChild('Items')
		return items and items:FindFirstChild(item) or false
	end
	
	AutoPickup = vape.Categories.Inventory:CreateModule({
		Name = 'AutoPickup',
		Function = function(callback)
			if callback then
				Regions = collectionService:GetTagged('GunShopRegion')
				overlapParams.FilterDescendantsInstances = Regions
	
				AutoPickup:Clean(collectionService:GetInstanceAddedSignal('GunShopRegion'):Connect(function(obj)
					table.insert(Regions, obj)
					overlapParams.FilterDescendantsInstances = Regions
				end))
	
				AutoPickup:Clean(collectionService:GetInstanceRemovedSignal('GunShopRegion'):Connect(function(obj)
					local index = table.find(Regions, obj)
					if index then
						table.remove(Regions, index)
					end
				end))
	
				repeat
					if entitylib.isAlive then
						local parts = workspace:GetPartsInPart(entitylib.character.RootPart, overlapParams)
						if #parts > 0 then
							for _, entry in pickupList[lplr.Team == teams.Police and 'Police' or 'Prisoner'] do
								if not InvTracker.Inventories[lplr][entry] and doesPlayerOwn(entry) then
									jb:FireServer('EquipItem', entry, nil)
								end
							end
	
							task.wait(0.2)
						end
					end
	
					task.wait(0.05)
				until not AutoPickup.Enabled
			else
				table.clear(Regions)
			end
		end,
		Tooltip = 'Automatically grab item pickups'
	})
	
	for _, team in {'Prisoner', 'Police'} do
		AutoPickup:CreateTextList({
			Name = team..' Pickups',
			Default = team == 'Prisoner' and {'AK47', 'Shotgun', 'Pistol'} or {'AK47', 'Shotgun'},
			Placeholder = 'item',
			Function = function(list)
				table.clear(pickupList[team])
	
				for _, entry in list do
					table.insert(pickupList[team], entry)
				end
			end
		})
	end
end)
local run = function(func) func() end
local cloneref = cloneref or function(obj) return obj end

local playersService = cloneref(game:GetService('Players'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))

local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer

local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local uipallet = vape.Libraries.uipallet
local whitelist = vape.Libraries.whitelist

local RS = cloneref(game:GetService('ReplicatedStorage'))
local CameraRemote = RS.Remotes.Replication.Fighter.UpdateCameraRotations
local ReplicateRemote = RS.Remotes.Replication.Fighter.Replicate

for _, v in {'AntiRagdoll', 'TriggerBot', 'SilentAim', 'AutoRejoin', 'Rejoin', 'Disabler', 'Timer', 'ServerHop', 'MouseTP', 'MurderMystery', 'Schematica', 'BedESP', 'KitESP', 'ChatSpammer', 'Xray', 'StorageESP', 'Parkour', 'AutoTool', 'AutoBalloon', 'RavenTP', 'MissileTP', 'BedProtector', 'BedPlates', 'AutoShoot', 'AutoPlay', 'AutoPearl', 'AutoKit', 'AutoVoidDrop', 'PickupRange', 'ChestSteal', 'AutoToxic', 'FastProxPrompt', 'Breaker', 'AutoSuffocate', 'Waypoints', 'Search', 'GamingChair', 'Invisible', 'Arrows', 'Tracers', 'NameTags', 'Chams', 'Health'} do
	pcall(function() vape:Remove(v) end)
end

run(function()
	entitylib.addPlayer = function(plr)
		if plr.Character then
			entitylib.refreshEntity(plr.Character, plr)
		end
		entitylib.PlayerConnections[plr] = {
			plr.CharacterAdded:Connect(function(char)
				entitylib.refreshEntity(char, plr)
			end),
			plr.CharacterRemoving:Connect(function(char)
				entitylib.removeEntity(char, plr == lplr)
			end)
		}
	end

	entitylib.targetCheck = function(ent)
		if ent.NPC then return true end
		if not select(2, whitelist:get(ent.Player)) then return false end
		return lplr.Team ~= ent.Player.Team
	end

	entitylib.start()

	local kills = sessioninfo:AddItem('Kills')
	local games = sessioninfo:AddItem('Games')

	task.delay(1, function() games:Increment() end)

	vape:Clean(function()
		table.clear(entitylib.List)
	end)
end)

run(function()
	local SilentAim
	local FOV
	local Part
	local Smoothness
	local TeamCheck
	local ShowFOV
	local fovCircle

	local function getTarget()
		local closest, closestDist = nil, math.huge
		local mousePos = inputService:GetMouseLocation()

		for _, ent in entitylib.List do
			if not ent.Targetable or not ent.Character or not ent.RootPart then continue end
			if TeamCheck.Enabled and lplr.Team == ent.Player.Team then continue end

			local targetPart = Part.Value == 'Head' and ent.Character:FindFirstChild('Head') or ent.RootPart
			if not targetPart then continue end

			local screenPos, onScreen = gameCamera:WorldToViewportPoint(targetPart.Position)
			if not onScreen then continue end

			local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
			if dist < FOV.Value and dist < closestDist then
				closestDist = dist
				closest = ent
			end
		end

		return closest
	end

	local oldNamecall
	SilentAim = vape.Categories.Combat:CreateModule({
		Name = 'SilentAim',
		Function = function(callback)
			if callback then
				oldNamecall = hookmetamethod(game, '__namecall', function(self, ...)
					local method = getnamecallmethod()
					if method == 'FireServer' and self == CameraRemote then
						local target = getTarget()
						if target then
							local targetPart = Part.Value == 'Head' and target.Character:FindFirstChild('Head') or target.RootPart
							if targetPart then
								targetinfo.Targets[target] = tick() + 1
								local args = {...}
								if type(args[1]) == 'table' then
									args[1].cf = CFrame.lookAt(gameCamera.CFrame.Position, targetPart.Position)
								end
								return oldNamecall(self, table.unpack(args))
							end
						end
					end
					return oldNamecall(self, ...)
				end)

				SilentAim:Clean(function()
					if oldNamecall then
						hookmetamethod(game, '__namecall', oldNamecall)
						oldNamecall = nil
					end
					if fovCircle then
						fovCircle:Remove()
						fovCircle = nil
					end
				end)

				if ShowFOV.Enabled then
					fovCircle = Drawing.new('Circle')
					fovCircle.Radius = FOV.Value
					fovCircle.Color = Color3.fromRGB(255, 255, 255)
					fovCircle.Thickness = 1
					fovCircle.Transparency = 0.8
					fovCircle.Filled = false
					fovCircle.Visible = true

					SilentAim:Clean(runService.RenderStepped:Connect(function()
						if fovCircle then
							local mousePos = inputService:GetMouseLocation()
							fovCircle.Position = mousePos
							fovCircle.Radius = FOV.Value
						end
					end))
				end
			else
				if oldNamecall then
					hookmetamethod(game, '__namecall', oldNamecall)
					oldNamecall = nil
				end
				if fovCircle then
					fovCircle:Remove()
					fovCircle = nil
				end
			end
		end,
		Tooltip = 'Redirects your shots to the nearest enemy'
	})

	FOV = SilentAim:CreateSlider({Name = 'FOV', Min = 1, Max = 1000, Default = 200, Suffix = 'px'})
	Part = SilentAim:CreateDropdown({Name = 'Target Part', List = {'Head', 'RootPart'}, Default = 'Head'})
	Smoothness = SilentAim:CreateSlider({Name = 'Smoothness', Min = 0, Max = 10, Default = 0, Decimal = 10})
	TeamCheck = SilentAim:CreateToggle({Name = 'Team Check', Default = true})
	ShowFOV = SilentAim:CreateToggle({
		Name = 'Show FOV',
		Default = false,
		Function = function(val)
			if SilentAim.Enabled then
				if val and not fovCircle then
					fovCircle = Drawing.new('Circle')
					fovCircle.Radius = FOV.Value
					fovCircle.Color = Color3.fromRGB(255, 255, 255)
					fovCircle.Thickness = 1
					fovCircle.Transparency = 0.8
					fovCircle.Filled = false
					fovCircle.Visible = true
				elseif not val and fovCircle then
					fovCircle:Remove()
					fovCircle = nil
				end
			end
		end
	})
end)

run(function()
	local AimAssist
	local FOV
	local Speed
	local Part
	local TeamCheck
	local ClickOnly

	AimAssist = vape.Categories.Combat:CreateModule({
		Name = 'AimAssist',
		Function = function(callback)
			if callback then
				AimAssist:Clean(runService.Heartbeat:Connect(function(dt)
					if not entitylib.isAlive then return end
					if ClickOnly.Enabled and not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return end

					local closest, closestDist = nil, math.huge
					local mousePos = inputService:GetMouseLocation()

					for _, ent in entitylib.List do
						if not ent.Targetable or not ent.Character or not ent.RootPart then continue end
						if TeamCheck.Enabled and lplr.Team == ent.Player.Team then continue end

						local targetPart = Part.Value == 'Head' and ent.Character:FindFirstChild('Head') or ent.RootPart
						if not targetPart then continue end

						local screenPos, onScreen = gameCamera:WorldToViewportPoint(targetPart.Position)
						if not onScreen then continue end

						local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
						if dist < FOV.Value and dist < closestDist then
							closestDist = dist
							closest = ent
						end
					end

					if closest then
						local targetPart = Part.Value == 'Head' and closest.Character:FindFirstChild('Head') or closest.RootPart
						if targetPart then
							targetinfo.Targets[closest] = tick() + 1
							gameCamera.CFrame = gameCamera.CFrame:Lerp(
								CFrame.new(gameCamera.CFrame.Position, targetPart.Position),
								Speed.Value * dt
							)
						end
					end
				end))
			end
		end,
		Tooltip = 'Smoothly aims toward the nearest enemy'
	})

	FOV = AimAssist:CreateSlider({Name = 'FOV', Min = 1, Max = 1000, Default = 300, Suffix = 'px'})
	Speed = AimAssist:CreateSlider({Name = 'Speed', Min = 1, Max = 20, Default = 6})
	Part = AimAssist:CreateDropdown({Name = 'Target Part', List = {'Head', 'RootPart'}, Default = 'Head'})
	TeamCheck = AimAssist:CreateToggle({Name = 'Team Check', Default = true})
	ClickOnly = AimAssist:CreateToggle({Name = 'Click only', Default = true})
end)

run(function()
	local TriggerBot
	local FOV
	local CPS
	local TeamCheck

	TriggerBot = vape.Categories.Combat:CreateModule({
		Name = 'TriggerBot',
		Function = function(callback)
			if callback then
				TriggerBot:Clean(runService.Heartbeat:Connect(function()
					if not entitylib.isAlive then return end

					local mousePos = inputService:GetMouseLocation()
					local unitRay = gameCamera:ScreenPointToRay(mousePos.X, mousePos.Y)
					local rayParams = RaycastParams.new()
					rayParams.FilterDescendantsInstances = {lplr.Character}
					rayParams.FilterType = Enum.RaycastFilterType.Exclude

					local ray = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, rayParams)
					if not ray then return end

					local hitChar = ray.Instance and ray.Instance.Parent
					local hitPlr = hitChar and playersService:GetPlayerFromCharacter(hitChar)
					if not hitPlr or hitPlr == lplr then return end
					if TeamCheck.Enabled and lplr.Team == hitPlr.Team then return end

					task.wait(1 / CPS.GetRandomValue())
					inputService:SendKeyEvent(true, Enum.KeyCode.Unknown, false, game)
					mouse1press()
					task.wait(0.05)
					mouse1release()
				end))
			end
		end,
		Tooltip = 'Auto shoots when crosshair is over an enemy'
	})

	FOV = TriggerBot:CreateSlider({Name = 'FOV', Min = 1, Max = 500, Default = 100, Suffix = 'px'})
	CPS = TriggerBot:CreateTwoSlider({Name = 'CPS', Min = 1, Max = 20, DefaultMin = 8, DefaultMax = 12})
	TeamCheck = TriggerBot:CreateToggle({Name = 'Team Check', Default = true})
end)

run(function()
	local ESP
	local TeamCheck
	local ShowBox
	local ShowName
	local ShowHealth
	local ShowDist
	local drawings = {}

	local function removeDrawings(plr)
		if drawings[plr] then
			for _, d in drawings[plr] do
				d:Remove()
			end
			drawings[plr] = nil
		end
	end

	local function createDrawings(plr)
		removeDrawings(plr)
		drawings[plr] = {
			box = Drawing.new('Square'),
			name = Drawing.new('Text'),
			health = Drawing.new('Square'),
			healthFill = Drawing.new('Square'),
		}
		local d = drawings[plr]
		d.box.Thickness = 1
		d.box.Filled = false
		d.box.Visible = false
		d.name.Size = 13
		d.name.Center = true
		d.name.Outline = true
		d.name.Visible = false
		d.health.Thickness = 1
		d.health.Filled = true
		d.health.Color = Color3.fromRGB(0, 0, 0)
		d.health.Visible = false
		d.healthFill.Thickness = 1
		d.healthFill.Filled = true
		d.healthFill.Visible = false
	end

	ESP = vape.Categories.Render:CreateModule({
		Name = 'ESP',
		Function = function(callback)
			if callback then
				for _, plr in playersService:GetPlayers() do
					if plr ~= lplr then createDrawings(plr) end
				end

				ESP:Clean(playersService.PlayerAdded:Connect(function(plr)
					createDrawings(plr)
				end))

				ESP:Clean(playersService.PlayerRemoving:Connect(function(plr)
					removeDrawings(plr)
				end))

				ESP:Clean(runService.RenderStepped:Connect(function()
					for _, plr in playersService:GetPlayers() do
						if plr == lplr or not drawings[plr] then continue end
						if TeamCheck.Enabled and lplr.Team == plr.Team then
							for _, d in drawings[plr] do d.Visible = false end
							continue
						end

						local char = plr.Character
						local root = char and char:FindFirstChild('HumanoidRootPart')
						local head = char and char:FindFirstChild('Head')
						local hum = char and char:FindFirstChildOfClass('Humanoid')

						if not root or not head or not hum then
							for _, d in drawings[plr] do d.Visible = false end
							continue
						end

						local rootPos, rootOnScreen = gameCamera:WorldToViewportPoint(root.Position)
						local headPos, headOnScreen = gameCamera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))

						if not rootOnScreen and not headOnScreen then
							for _, d in drawings[plr] do d.Visible = false end
							continue
						end

						local d = drawings[plr]
						local espColor = vape.GUIColor and Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value) or Color3.fromRGB(255, 255, 255)
						local w = math.abs(rootPos.X - headPos.X) * 2 + 20
						local h = math.abs(rootPos.Y - headPos.Y) + 10
						local x = rootPos.X - w / 2
						local y = headPos.Y - 5

						if ShowBox.Enabled then
							d.box.Size = Vector2.new(w, h)
							d.box.Position = Vector2.new(x, y)
							d.box.Color = espColor
							d.box.Visible = true
						else
							d.box.Visible = false
						end

						if ShowName.Enabled then
							d.name.Text = plr.DisplayName
							d.name.Position = Vector2.new(rootPos.X, y - 15)
							d.name.Color = espColor
							d.name.Visible = true
						else
							d.name.Visible = false
						end

						if ShowHealth.Enabled then
							local healthPct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
							local healthColor = Color3.fromHSV(healthPct / 3, 0.89, 0.75)
							d.health.Size = Vector2.new(4, h)
							d.health.Position = Vector2.new(x - 6, y)
							d.health.Visible = true
							d.healthFill.Size = Vector2.new(4, h * healthPct)
							d.healthFill.Position = Vector2.new(x - 6, y + h * (1 - healthPct))
							d.healthFill.Color = healthColor
							d.healthFill.Visible = true
						else
							d.health.Visible = false
							d.healthFill.Visible = false
						end
					end
				end))
			else
				for plr in drawings do
					removeDrawings(plr)
				end
				table.clear(drawings)
			end
		end,
		Tooltip = 'Shows enemies through walls'
	})

	ShowBox = ESP:CreateToggle({Name = 'Box', Default = true})
	ShowName = ESP:CreateToggle({Name = 'Name', Default = true})
	ShowHealth = ESP:CreateToggle({Name = 'Health', Default = true})
	TeamCheck = ESP:CreateToggle({Name = 'Team Check', Default = true})
end)

run(function()
	local Velocity
	local Horizontal
	local Vertical
	local Chance
	local rand = Random.new()

	Velocity = vape.Categories.Combat:CreateModule({
		Name = 'Velocity',
		Function = function(callback)
			if callback then
				Velocity:Clean(runService.PreSimulation:Connect(function()
					if not entitylib.isAlive or not entitylib.character then return end
					local root = entitylib.character.RootPart
					if not root then return end
					if rand:NextNumber(0, 100) > Chance.Value then return end
					local vel = root.AssemblyLinearVelocity
					root.AssemblyLinearVelocity = Vector3.new(
						vel.X * (Horizontal.Value / 100),
						vel.Y * (Vertical.Value / 100),
						vel.Z * (Horizontal.Value / 100)
					)
				end))
			end
		end,
		Tooltip = 'Reduces knockback taken'
	})
	Horizontal = Velocity:CreateSlider({Name = 'Horizontal', Min = 0, Max = 100, Default = 0, Suffix = '%'})
	Vertical = Velocity:CreateSlider({Name = 'Vertical', Min = 0, Max = 100, Default = 0, Suffix = '%'})
	Chance = Velocity:CreateSlider({Name = 'Chance', Min = 0, Max = 100, Default = 100, Suffix = '%'})
end)

run(function()
	local Speed
	local Value
	local WallCheck
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true

	Speed = vape.Categories.Blatant:CreateModule({
		Name = 'Speed',
		Function = function(callback)
			if callback then
				Speed:Clean(runService.PreSimulation:Connect(function(dt)
					if not entitylib.isAlive or not entitylib.character then return end
					local root = entitylib.character.RootPart
					local hum = entitylib.character.Humanoid
					if not root or not hum then return end
					if hum:GetState() == Enum.HumanoidStateType.Climbing then return end
					local moveDir = hum.MoveDirection
					local baseSpeed = hum.WalkSpeed
					local destination = moveDir * math.max(Value.Value - baseSpeed, 0) * dt
					if WallCheck.Enabled then
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
						rayCheck.CollisionGroup = root.CollisionGroup
						local ray = workspace:Raycast(root.Position, destination, rayCheck)
						if ray then destination = (ray.Position + ray.Normal) - root.Position end
					end
					root.CFrame += destination
					root.AssemblyLinearVelocity = (moveDir * Value.Value) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
				end))
			end
		end,
		Tooltip = 'Increases movement speed'
	})
	Value = Speed:CreateSlider({Name = 'Speed', Min = 1, Max = 150, Default = 50, Suffix = 'studs'})
	WallCheck = Speed:CreateToggle({Name = 'Wall Check', Default = true})
end)

run(function()
	local Fly
	local Value
	local VertValue
	local WallCheck
	local up, down = 0, 0
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true

	Fly = vape.Categories.Blatant:CreateModule({
		Name = 'Fly',
		Function = function(callback)
			if callback then
				up, down = 0, 0
				Fly:Clean(runService.PreSimulation:Connect(function(dt)
					if not entitylib.isAlive or not entitylib.character then return end
					local root = entitylib.character.RootPart
					local hum = entitylib.character.Humanoid
					if not root or not hum then return end
					local moveDir = hum.MoveDirection
					local destination = moveDir * Value.Value * dt
					if WallCheck.Enabled then
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
						rayCheck.CollisionGroup = root.CollisionGroup
						local ray = workspace:Raycast(root.Position, destination, rayCheck)
						if ray then destination = (ray.Position + ray.Normal) - root.Position end
					end
					root.CFrame += destination
					root.AssemblyLinearVelocity = (moveDir * Value.Value) + Vector3.new(0, (up + down) * VertValue.Value, 0)
				end))
				Fly:Clean(inputService.InputBegan:Connect(function(input)
					if not inputService:GetFocusedTextBox() then
						if input.KeyCode == Enum.KeyCode.Space then up = 1
						elseif input.KeyCode == Enum.KeyCode.LeftShift then down = -1 end
					end
				end))
				Fly:Clean(inputService.InputEnded:Connect(function(input)
					if input.KeyCode == Enum.KeyCode.Space then up = 0
					elseif input.KeyCode == Enum.KeyCode.LeftShift then down = 0 end
				end))
			else
				up, down = 0, 0
			end
		end,
		Tooltip = 'Fly around freely'
	})
	Value = Fly:CreateSlider({Name = 'Speed', Min = 1, Max = 150, Default = 50, Suffix = 'studs'})
	VertValue = Fly:CreateSlider({Name = 'Vertical Speed', Min = 1, Max = 150, Default = 50, Suffix = 'studs'})
	WallCheck = Fly:CreateToggle({Name = 'Wall Check', Default = true})
end)

run(function()
	local NoFall

	NoFall = vape.Categories.Blatant:CreateModule({
		Name = 'NoFall',
		Function = function(callback)
			if callback then
				NoFall:Clean(runService.PreSimulation:Connect(function()
					if not entitylib.isAlive or not entitylib.character then return end
					local root = entitylib.character.RootPart
					local hum = entitylib.character.Humanoid
					if hum and hum.FloorMaterial == Enum.Material.Air and root.AssemblyLinearVelocity.Y < -50 then
						root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, -50, root.AssemblyLinearVelocity.Z)
					end
				end))
			end
		end,
		Tooltip = 'Prevents taking fall damage'
	})
end)

run(function()
	local HitBoxes
	local Expand
	local objects = {}

	HitBoxes = vape.Categories.Blatant:CreateModule({
		Name = 'HitBoxes',
		Function = function(callback)
			if callback then
				for _, ent in entitylib.List do
					if ent.Targetable and ent.Player and ent.RootPart then
						local hitbox = Instance.new('Part')
						hitbox.Size = Vector3.new(4, 6, 4) + Vector3.one * (Expand.Value / 5)
						hitbox.CFrame = ent.RootPart.CFrame
						hitbox.CanCollide = false
						hitbox.Massless = true
						hitbox.Transparency = 1
						hitbox.Parent = ent.Character
						local weld = Instance.new('Motor6D')
						weld.Part0 = hitbox
						weld.Part1 = ent.RootPart
						weld.Parent = hitbox
						objects[ent] = hitbox
					end
				end

				HitBoxes:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if ent.Targetable and ent.Player and ent.RootPart then
						local hitbox = Instance.new('Part')
						hitbox.Size = Vector3.new(4, 6, 4) + Vector3.one * (Expand.Value / 5)
						hitbox.CFrame = ent.RootPart.CFrame
						hitbox.CanCollide = false
						hitbox.Massless = true
						hitbox.Transparency = 1
						hitbox.Parent = ent.Character
						local weld = Instance.new('Motor6D')
						weld.Part0 = hitbox
						weld.Part1 = ent.RootPart
						weld.Parent = hitbox
						objects[ent] = hitbox
					end
				end))

				HitBoxes:Clean(entitylib.Events.EntityRemoving:Connect(function(ent)
					if objects[ent] then objects[ent]:Destroy() objects[ent] = nil end
				end))
			else
				for _, part in objects do part:Destroy() end
				table.clear(objects)
			end
		end,
		Tooltip = 'Expands enemy hitboxes making them easier to hit'
	})
	Expand = HitBoxes:CreateSlider({
		Name = 'Expand amount', Min = 0, Max = 30, Default = 10, Decimal = 10,
		Function = function(val)
			for _, part in objects do
				part.Size = Vector3.new(4, 6, 4) + Vector3.one * (val / 5)
			end
		end,
		Suffix = 'studs'
	})
end)

run(function()
	local Backtrack
	local Delay
	local ShowGhost
	local positionHistory = {}
	local ghostPart = nil
	local MAX_HISTORY = 128

	Backtrack = vape.Categories.Blatant:CreateModule({
		Name = 'Backtrack',
		Function = function(callback)
			if callback then
				if ShowGhost.Enabled then
					if ghostPart then ghostPart:Destroy() end
					local root = entitylib.character and entitylib.character.RootPart
					if root then
						ghostPart = Instance.new('Part')
						ghostPart.Size = root.Size
						ghostPart.Anchored = true
						ghostPart.CanCollide = false
						ghostPart.Transparency = 0.5
						ghostPart.Color = Color3.fromRGB(0, 120, 255)
						ghostPart.Material = Enum.Material.Neon
						ghostPart.Parent = workspace
					end
				end

				Backtrack:Clean(runService.Heartbeat:Connect(function()
					local root = entitylib.character and entitylib.character.RootPart
					if not root or not root.Parent then return end
					table.insert(positionHistory, {cframe = root.CFrame, time = tick()})
					if #positionHistory > MAX_HISTORY then table.remove(positionHistory, 1) end
					if ShowGhost.Enabled and ghostPart then ghostPart.CFrame = root.CFrame end
				end))

				Backtrack:Clean(runService.PreSimulation:Connect(function()
					if not entitylib.isAlive then return end
					local root = entitylib.character and entitylib.character.RootPart
					if not root or not root.Parent then return end
					local targetTime = tick() - Delay.Value
					local delayed = nil
					for i = #positionHistory, 1, -1 do
						if positionHistory[i].time <= targetTime then
							delayed = positionHistory[i].cframe
							break
						end
					end
					if not delayed then return end
					pcall(function()
						local mt = getrawmetatable(root)
						local old = mt.__newindex
						rawset(mt, '__newindex', function(t, k, v)
							if t == root and k == 'CFrame' then return end
							return old(t, k, v)
						end)
						rawset(root, 'CFrame', delayed)
						rawset(mt, '__newindex', old)
					end)
				end))

				Backtrack:Clean(function()
					if ghostPart then ghostPart:Destroy() ghostPart = nil end
					table.clear(positionHistory)
				end)
			else
				if ghostPart then ghostPart:Destroy() ghostPart = nil end
				table.clear(positionHistory)
			end
		end,
		Tooltip = 'Delays your position on the server to increase effective attack range'
	})
	Delay = Backtrack:CreateSlider({Name = 'Delay', Min = 0.05, Max = 0.5, Default = 0.15, Decimal = 100, Suffix = 's'})
	ShowGhost = Backtrack:CreateToggle({
		Name = 'Show ghost', Default = false,
		Function = function(val)
			if Backtrack.Enabled then
				if not val and ghostPart then ghostPart:Destroy() ghostPart = nil end
			end
		end
	})
end)

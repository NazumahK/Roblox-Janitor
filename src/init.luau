--!optimize 2
--!strict

local FastDefer = require(script.FastDefer)
local Vow = require(script.Vow)

type MethodName = true | string
type Vow<T> = Vow.Vow<T>
type VowAPI = Vow.VowAPI

local LinkToInstanceIndex = setmetatable({}, {
	__tostring = function()
		return "LinkToInstanceIndex"
	end,
})

local INVALID_METHOD_NAME =
	"Object is a %* and as such expected `true?` for the method name and instead got %*. Traceback: %*"
local METHOD_NOT_FOUND_ERROR = "Object %* doesn't have method %*, are you sure you want to add it? Traceback: %*"
local NOT_A_VOW = "Invalid argument #1 to 'Janitor:AddVow' (Vow expected, got %* (%*)) Traceback: %*"

export type Janitor = typeof(setmetatable(
	{} :: {
		CurrentlyCleaning: boolean,
		SuppressInstanceReDestroy: boolean,
		UnsafeThreadCleanup: boolean,

		Add: <T>(self: Janitor, object: T, methodName: MethodName?, index: unknown?) -> T,
		AddObject: <T, A...>(
			self: Janitor,
			constructor: { new: (A...) -> T },
			methodName: MethodName?,
			index: unknown?,
			A...
		) -> T,
		AddVow: <T>(self: Janitor, vowObject: Vow<T>, index: unknown?) -> Vow<T>,

		Remove: (self: Janitor, index: unknown) -> Janitor,
		RemoveNoClean: (self: Janitor, index: unknown) -> Janitor,

		RemoveList: (self: Janitor, ...unknown) -> Janitor,
		RemoveListNoClean: (self: Janitor, ...unknown) -> Janitor,

		Get: (self: Janitor, index: unknown) -> unknown?,
		GetAll: (self: Janitor) -> { [unknown]: unknown },

		Cleanup: (self: Janitor) -> (),
		Destroy: (self: Janitor) -> (),

		LinkToInstance: (self: Janitor, object: Instance, allowMultiple: boolean?) -> RBXScriptConnection,
		LinkToInstances: (self: Janitor, ...Instance) -> Janitor,
	},
	{} :: { __call: (self: Janitor) -> () }
))

type Private = typeof(setmetatable(
	{} :: {
		CurrentlyCleaning: boolean,
		SuppressInstanceReDestroy: boolean,
		UnsafeThreadCleanup: boolean,

		[any]: MethodName,

		Add: <T>(self: Private, object: T, methodName: MethodName?, index: unknown?) -> T,
		AddObject: <T, A...>(
			self: Private,
			constructor: { new: (A...) -> T },
			methodName: MethodName?,
			index: unknown?,
			A...
		) -> T,
		AddVow: <T>(self: Private, vowObject: Vow<T>, index: unknown?) -> Vow<T>,

		Remove: (self: Private, index: unknown) -> Private,
		RemoveNoClean: (self: Private, index: unknown) -> Private,

		RemoveList: (self: Private, ...unknown) -> Private,
		RemoveListNoClean: (self: Private, ...unknown) -> Private,

		Get: (self: Private, index: unknown) -> unknown?,
		GetAll: (self: Private) -> { [unknown]: unknown },

		Cleanup: (self: Private) -> (),
		Destroy: (self: Private) -> (),

		LinkToInstance: (self: Private, object: Instance, allowMultiple: boolean?) -> RBXScriptConnection,
		LinkToInstances: (self: Private, ...Instance) -> Private,
	},
	{} :: { __call: (self: Private) -> () }
))

type JanitorAPI = {
	ClassName: "Janitor",

	CurrentlyCleaning: boolean,
	SuppressInstanceReDestroy: boolean,
	UnsafeThreadCleanup: boolean,

	new: () -> Janitor,
	Is: (object: unknown) -> boolean,
	instanceof: (object: unknown) -> boolean,
}

type PrivateAPI = JanitorAPI & {
	__call: (self: Private) -> (),
	__tostring: (self: Private) -> string,
}

local Janitor = {} :: Janitor & JanitorAPI
local Private = Janitor :: Private & PrivateAPI
Janitor.ClassName = "Janitor"
Janitor.CurrentlyCleaning = true
Janitor.SuppressInstanceReDestroy = false
Janitor.UnsafeThreadCleanup = false
(Janitor :: any).__index = Janitor

local Janitors = setmetatable({} :: { [Private]: { [any]: any } }, { __mode = "ks" })

local TYPE_DEFAULTS: { [string]: MethodName } = {
	["function"] = true,
	thread = true,
	RBXScriptConnection = "Disconnect",
}

function Janitor.new(): Janitor
	return setmetatable({
		CurrentlyCleaning = false,
	}, Janitor) :: any
end

function Janitor.Is(object: unknown): boolean
	return type(object) == "table" and getmetatable(object :: any) == Janitor
end

Janitor.instanceof = Janitor.Is

local GameDestroy = game.Destroy

local function CleanupObject(object: unknown, methodName: MethodName, suppressReDestroy: boolean, unsafeThread: boolean)
	if methodName == true then
		if type(object) == "function" then
			(object :: () -> ())()
		else
			local wasCancelled: boolean? = nil
			if coroutine.running() ~= (object :: thread) then
				wasCancelled = pcall(function()
					task.cancel(object :: thread)
				end)
			end

			if not wasCancelled then
				local toCleanup = object :: thread
				if unsafeThread then
					FastDefer(function()
						task.cancel(toCleanup)
					end)
				else
					task.defer(function()
						task.cancel(toCleanup)
					end)
				end
			end
		end
	elseif methodName == "Destroy" then
		if suppressReDestroy and typeof(object) == "Instance" then
			pcall(GameDestroy, object :: Instance)
		else
			local castObject = object :: any
			local destroy = castObject.Destroy
			if destroy then
				destroy(castObject)
			end
		end
	elseif methodName == "Disconnect" then
		local castObject = object :: any
		local disconnect = castObject.Disconnect
		if disconnect then
			disconnect(castObject)
		end
	else
		local objectMethod = (object :: any)[methodName] :: ((self: unknown) -> ())?
		if objectMethod then
			objectMethod(object)
		end
	end
end

local function Remove(self: Private, index: unknown): Private
	local this = Janitors[self]
	if not this then
		return self
	end

	local object = this[index]
	if not object then
		return self
	end

	local methodName = self[object]
	if methodName then
		CleanupObject(object, methodName, self.SuppressInstanceReDestroy, self.UnsafeThreadCleanup)
		self[object] = nil
	end

	this[index] = nil
	return self
end

local function Add<T>(self: Private, object: T, methodName: MethodName?, index: unknown?): T
	if index then
		Remove(self, index)

		local this = Janitors[self]
		if not this then
			this = {}
			Janitors[self] = this
		end

		this[index] = object
	end

	local typeOf = typeof(object)
	local newMethodName: MethodName = methodName or TYPE_DEFAULTS[typeOf] or "Destroy"

	if typeOf == "function" or typeOf == "thread" then
		if newMethodName ~= true then
			warn(string.format(INVALID_METHOD_NAME, typeOf, tostring(newMethodName), debug.traceback(nil, 2)))
		end
	elseif newMethodName ~= true then
		if not (object :: any)[newMethodName] then
			warn(
				string.format(
					METHOD_NOT_FOUND_ERROR,
					tostring(object),
					tostring(newMethodName),
					debug.traceback(nil, 2)
				)
			)
		end
	end

	self[object :: any] = newMethodName
	return object
end

Private.Add = Add

function Janitor:AddObject<T, A...>(constructor: { new: (A...) -> T }, methodName: MethodName?, index: unknown?, ...: A...): T
	return Add(self, constructor.new(...), methodName, index)
end

local function Get(self: Private, index: unknown): unknown?
	local this = Janitors[self]
	return if this then this[index] else nil
end
Janitor.Get = Get

function Janitor:AddVow<T>(vowObject: Vow<T>, index: unknown?): Vow<T>
	local VowLib: VowAPI? = Vow :: VowAPI?
	if not VowLib then
		return vowObject
	end

	if not VowLib.is(vowObject) then
		error(string.format(NOT_A_VOW, typeof(vowObject), tostring(vowObject), debug.traceback(nil, 2)))
	end

	if vowObject:getStatus() ~= VowLib.Status.Started then
		return vowObject
	end

	local uniqueId: unknown = if index ~= nil then index else newproxy(false)

	local newVow = Add(
		self,
		VowLib.new(function(resolve, _, onCancel)
			if onCancel(function()
				vowObject:cancel()
			end) then
				return
			end

			resolve(vowObject)
		end),
		"cancel",
		uniqueId
	)

	newVow:finally(function()
		if Get(self, uniqueId) == newVow then
			Remove(self, uniqueId)
		end
	end)

	return newVow :: never
end

Private.Remove = Remove

function Private:RemoveNoClean(index: unknown): Janitor
	local this = Janitors[self]
	if this then
		local object = this[index]
		if object then
			self[object] = nil
			this[index] = nil
		end
	end

	return self
end

function Janitor:RemoveList(...: unknown): Janitor
	local this = Janitors[self]
	if this then
		local length = select("#", ...)
		if length == 1 then
			return Remove(self, ...)
		end

		for selectIndex = 1, length do
			Remove(self, select(selectIndex, ...))
		end
	end

	return self
end

function Janitor:RemoveListNoClean(...: unknown): Janitor
	local this = Janitors[self]
	if this then
		for selectIndex = 1, select("#", ...) do
			local index = select(selectIndex, ...)
			local object = this[index]
			if object then
				self[object] = nil
				this[index] = nil
			end
		end
	end

	return self
end

function Janitor:GetAll(): { [unknown]: unknown }
	local this = Janitors[self]
	return if this then table.freeze(table.clone(this)) else {}
end

local function Cleanup(self: Private): ()
	if self.CurrentlyCleaning then
		return
	end

	local suppressReDestroy = self.SuppressInstanceReDestroy
	local unsafeThread = self.UnsafeThreadCleanup

	self.CurrentlyCleaning = nil :: never
	self.SuppressInstanceReDestroy = nil :: never
	self.UnsafeThreadCleanup = nil :: never

	local object, methodName = next(self)
	while object and methodName do
		CleanupObject(object, methodName, suppressReDestroy, unsafeThread)
		self[object :: any] = nil
		object, methodName = next(self, object)
	end

	local this = Janitors[self]
	if this then
		table.clear(this)
		Janitors[self] = nil
	end

	self.CurrentlyCleaning = false
	self.SuppressInstanceReDestroy = suppressReDestroy
	self.UnsafeThreadCleanup = unsafeThread
end
Private.Cleanup = Cleanup

function Janitor:Destroy(): ()
	Cleanup(self)
	table.clear(self :: any)
	setmetatable(self :: any, nil)
end
(Janitor :: any).__call = Cleanup

local function LinkToInstance(self: Private, object: Instance, allowMultiple: boolean?): RBXScriptConnection
	local indexToUse = if allowMultiple then newproxy(false) else LinkToInstanceIndex

	return Add(
		self,
		object.Destroying:Connect(function()
			Cleanup(self)
		end),
		"Disconnect",
		indexToUse
	)
end

Private.LinkToInstance = LinkToInstance

function Janitor:LinkToInstances(...: Instance): Janitor
	local manualCleanup = Janitor.new()
	for index = 1, select("#", ...) do
		local object = select(index, ...)
		if typeof(object) ~= "Instance" then
			continue
		end

		manualCleanup:Add(LinkToInstance(self, object, true), "Disconnect")
	end

	return manualCleanup
end
(Janitor :: any).__tostring = function()
	return "Janitor"
end

return Janitor :: JanitorAPI

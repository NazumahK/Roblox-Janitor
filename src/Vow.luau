--!optimize 2
--!strict

--[[
	Vow adapter for Janitor.
	Resolves the Vow package from the Packages directory (sibling of Janitor).
	If Vow is not installed, this module returns nil and Janitor gracefully
	skips all Vow-related functionality.
]]

local Packages = script.Parent.Parent
local Vow: any = if Packages:FindFirstChild("Vow") then (require :: any)(Packages.Vow) else nil

export type Status = "Started" | "Resolved" | "Rejected" | "Cancelled"
export type ErrorKind = "ExecutionError" | "AlreadyCancelled" | "NotResolvedInTime" | "TimedOut"

export type ErrorOptions = {
	error: unknown?,
	trace: string?,
	context: string?,
	kind: ErrorKind?,
}

export type Error = {
	error: string,
	trace: string?,
	context: string?,
	kind: ErrorKind?,
	parent: Error?,
	createdTick: number,
	createdTrace: string,
	extend: (self: Error, options: ErrorOptions?) -> Error,
	getErrorChain: (self: Error) -> { Error },
}

type ErrorStatic = {
	Kind: {
		ExecutionError: "ExecutionError",
		AlreadyCancelled: "AlreadyCancelled",
		NotResolvedInTime: "NotResolvedInTime",
		TimedOut: "TimedOut",
	},
	new: (options: ErrorOptions?, parent: Error?) -> Error,
	is: (anything: unknown) -> boolean,
	isKind: (anything: unknown, kind: ErrorKind) -> boolean,
}

export type Vow<T> = {
	andThen: (self: Vow<T>, successHandler: ((T) -> unknown)?, failureHandler: ((...unknown) -> unknown)?) -> Vow<T>,
	catch: (self: Vow<T>, failureHandler: (...unknown) -> unknown) -> Vow<T>,
	tap: (self: Vow<T>, tapHandler: (T) -> ()) -> Vow<T>,
	finally: (self: Vow<T>, finallyHandler: ((Status) -> ())?) -> Vow<T>,
	andThenCall: (self: Vow<T>, callback: (...unknown) -> unknown, ...unknown) -> Vow<T>,
	andThenReturn: (self: Vow<T>, ...unknown) -> Vow<T>,
	finallyCall: (self: Vow<T>, callback: (...unknown) -> (), ...unknown) -> Vow<T>,
	finallyReturn: (self: Vow<T>, ...unknown) -> Vow<T>,
	now: (self: Vow<T>, rejectionValue: unknown?) -> Vow<T>,
	timeout: (self: Vow<T>, seconds: number, rejectionValue: unknown?) -> Vow<T>,
	cancel: (self: Vow<T>) -> (),
	awaitStatus: (self: Vow<T>) -> (Status, ...unknown),
	await: (self: Vow<T>) -> (boolean, ...unknown),
	expect: (self: Vow<T>) -> T,
	getStatus: (self: Vow<T>) -> Status,
}

export type VowAPI = {
	Error: ErrorStatic,
	Status: {
		Started: "Started",
		Resolved: "Resolved",
		Rejected: "Rejected",
		Cancelled: "Cancelled",
	},

	new: <T>(
		executor: (
			resolve: (T) -> (),
			reject: (...unknown) -> (),
			onCancel: (abortHandler: (() -> ())?) -> boolean
		) -> ()
	) -> Vow<T>,
	defer: <T>(
		executor: (
			resolve: (T) -> (),
			reject: (...unknown) -> (),
			onCancel: (abortHandler: (() -> ())?) -> boolean
		) -> ()
	) -> Vow<T>,
	resolve: <T>(value: T) -> Vow<T>,
	reject: <T>(...unknown) -> Vow<T>,
	try: <T>(callback: (...unknown) -> T, ...unknown) -> Vow<T>,
	vowify: <T>(callback: (...unknown) -> T) -> (...unknown) -> Vow<T>,

	all: <T>(vows: { Vow<T> }) -> Vow<{ T }>,
	allSettled: <T>(vows: { Vow<T> }) -> Vow<{ Status }>,
	any: <T>(vows: { Vow<T> }) -> Vow<T>,
	race: <T>(vows: { Vow<T> }) -> Vow<T>,
	some: <T>(vows: { Vow<T> }, count: number) -> Vow<{ T }>,

	each: <T, U>(list: { T }, predicate: (value: T, index: number) -> U) -> Vow<{ U }>,
	fold: <T, U>(list: { T }, reducer: (accumulator: U, value: T, index: number) -> U, initialValue: U) -> Vow<U>,
	fromEvent: <T>(event: unknown, predicate: ((T) -> boolean)?) -> Vow<T>,

	delay: (seconds: number) -> Vow<number>,
	retry: <T>(callback: (...unknown) -> Vow<T>, times: number, ...unknown) -> Vow<T>,
	retryWithDelay: <T>(callback: (...unknown) -> Vow<T>, times: number, seconds: number, ...unknown) -> Vow<T>,

	is: (object: unknown) -> boolean,
	onUnhandledRejection: (callback: (...unknown) -> ()) -> () -> (),
}

return Vow :: VowAPI?

# API Reference

A formal reference for the Janitor library's types and methods.

---

## `Janitor`

The primary class for resource lifecycle management.

### Methods

#### `Janitor.new(): Janitor`
Constructs a new Janitor instance.
```luau
local janitor = Janitor.new()
```

#### `Janitor:Add<T>(object: T, methodName: (true | string)?, index: unknown?): T`
Registers an object and returns it. The generic `<T>` preserves the original type for immediate use.
- `methodName`: The cleanup method to invoke. `true` calls the object directly (functions/threads). Defaults to `"Destroy"`.
- `index`: An optional key for later retrieval or individual removal.
```luau
local part = janitor:Add(Instance.new("Part"))
local conn  = janitor:Add(signal:Connect(fn), "Disconnect", "MyConn")
janitor:Add(function() print("done") end, true)
```

#### `Janitor:AddObject<T, A...>(constructor: { new: (A...) -> T }, methodName: (true | string)?, index: unknown?, A...): T`
Instantiates an object via its constructor and registers it in one call. Argument types are fully inferred via the variadic generic `<A...>`.
```luau
local obj = janitor:AddObject(MyClass, "Destroy", "Key", arg1, arg2)
```

#### `Janitor:AddVow<T>(vowObject: Vow<T>, index: unknown?): Vow<T>`
Registers an active Vow. The Vow is cancelled automatically if Janitor is cleaned up before it settles. Settled Vows remove themselves from the registry automatically.
```luau
janitor:AddVow(Vow.delay(5):andThen(doWork))
```

#### `Janitor:Remove(index: unknown): Janitor`
Cleans up and removes the object associated with the given index.
```luau
janitor:Remove("MyConn")
```

#### `Janitor:RemoveNoClean(index: unknown): Janitor`
Removes the object from management without invoking its cleanup method.
```luau
janitor:RemoveNoClean("MyConn")
```

#### `Janitor:RemoveList(...: unknown): Janitor`
Cleans up and removes multiple indexed objects in one call.
```luau
janitor:RemoveList("KeyA", "KeyB", "KeyC")
```

#### `Janitor:RemoveListNoClean(...: unknown): Janitor`
Removes multiple indexed objects without invoking their cleanup methods.

#### `Janitor:Get(index: unknown): unknown?`
Returns the object registered under the given index. The return type is `unknown`; callers must perform type refinement before use.
```luau
local obj = janitor:Get("MyConn")
if typeof(obj) == "RBXScriptConnection" then
    print(obj.Connected)
end
```

#### `Janitor:GetAll(): { [unknown]: unknown }`
Returns a frozen, shallow copy of the entire index registry.

#### `Janitor:Cleanup()`
Invokes the registered cleanup method on every managed object and clears the internal state. Also callable as `janitor()` via `__call`.
```luau
janitor:Cleanup()
janitor() -- equivalent
```

#### `Janitor:Destroy()`
Performs cleanup and then clears the Janitor table itself, permanently invalidating the instance.
```luau
janitor:Destroy()
```

#### `Janitor:LinkToInstance(object: Instance, allowMultiple: boolean?): RBXScriptConnection`
Connects the Janitor's `Cleanup` to the `Destroying` event of an Instance.
```luau
janitor:LinkToInstance(workspace.MyPart)
```

#### `Janitor:LinkToInstances(...: Instance): Janitor`
Links to multiple Instances and returns a secondary Janitor managing those connections.
```luau
local linkJanitor = janitor:LinkToInstances(partA, partB)
```

---

## `JanitorAPI`

The static interface of the Janitor module.

### Properties

#### `Janitor.ClassName: "Janitor"`
A string identifier for the class.

#### `Janitor.CurrentlyCleaning: boolean`
Indicates whether a cleanup pass is currently in progress.

#### `Janitor.SuppressInstanceReDestroy: boolean`
When `true`, prevents errors from calling `Destroy` on already-destroyed Instances.

#### `Janitor.UnsafeThreadCleanup: boolean`
When `true`, thread cancellations are deferred via `FastDefer` instead of `task.defer`.

### Static Methods

#### `Janitor.Is(object: unknown): boolean`
Returns `true` if the given object is a Janitor instance.
```luau
print(Janitor.Is(janitor)) -- true
```

#### `Janitor.instanceof(object: unknown): boolean`
Alias for `Janitor.Is`.

---

## Summary

- Use `Add` for all standard resources; the returned object is immediately typed.
- Use `AddVow` for any asynchronous task that must be cancellable.
- Use `index` parameters to enable targeted removal via `Remove` or `Get`.
- Call `Destroy` when the Janitor itself will no longer be used.

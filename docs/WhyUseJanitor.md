# Why Use Janitor?

This document explains the practical value of using Janitor for resource management in Roblox development.

## 1. Manual Cleanup Does Not Scale

As a system grows, tracking which connections, threads, and instances need to be cleaned up at any given point becomes error-prone. A single uncleaned `RBXScriptConnection` or lingering thread is enough to produce subtle bugs that are difficult to reproduce.

Janitor provides a single point of disposal. All resources registered with a Janitor are freed by one `Cleanup` call, regardless of type.

## 2. Consistent Handling Across Resource Types

Different Roblox resource types require different cleanup calls: `Instance:Destroy()`, `RBXScriptConnection:Disconnect()`, `task.cancel(thread)`. Tracking which method applies to which object adds cognitive overhead.

Janitor infers the correct default from the object's type, while still allowing explicit override:

```luau
janitor:Add(Instance.new("Part"))               -- Destroy called automatically
janitor:Add(signal:Connect(fn))                 -- Disconnect called automatically
janitor:Add(task.delay(5, fn), true)            -- thread cancelled automatically
janitor:Add(myObject, "CustomCleanupMethod")    -- explicit override
```

## 3. Asynchronous Safety

Asynchronous tasks that outlive their owning system are a common source of invalid state errors. A callback that fires after its parent has been destroyed can write to nil references or trigger logic that should no longer run.

`AddVow` resolves this by tying a Vow's lifecycle directly to the Janitor. If the system is torn down, the Vow is cancelled. If the Vow settles first, it removes itself without any external coordination required.

```luau
-- The fetch is cancelled if the UI is destroyed before it completes
local janitor = Janitor.new()
janitor:AddVow(DataService:FetchAsync(userId))
janitor:LinkToInstance(uiFrame)
```

## 4. Full Type Preservation

Unlike generic cleanup utilities that accept `any`, Janitor's registration methods are generic at the call site. The object's type is preserved through registration and returned to the caller without requiring a cast.

```luau
-- part is typed as Part, not any
local part = janitor:Add(Instance.new("Part"))
part.Size = Vector3.new(4, 1, 4) -- IDE knows the type
```

## 5. Index-Based Resource Management

For long-running systems, individual resources may need to be replaced or removed before a full cleanup occurs. The optional `index` parameter enables this without manual bookkeeping:

```luau
janitor:Add(task.delay(5, doSomething), true, "MyTimer")

-- Later, replace the timer without leaking the old one
janitor:Add(task.delay(10, doSomethingElse), true, "MyTimer")
-- The previous task was cancelled automatically before the new one was added.
```

---

For a deeper look at the implementation, see the [Architecture Guide](Architecture.md).

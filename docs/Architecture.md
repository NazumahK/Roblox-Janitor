# Technical Architecture

This document describes the internal design decisions and optimizations behind the Janitor library.

## 1. Dual Storage Model

Janitor uses two separate data structures to manage resources.

The primary table (`self`) is keyed by **object reference**, storing the associated `MethodName`. This layout makes the cleanup loop branchless and cache-friendly: a single `next(self)` traversal yields each object and its method name simultaneously.

```luau
-- Cleanup traversal
local object, methodName = next(self)
while object and methodName do
    CleanupObject(object, methodName, ...)
    self[object] = nil
    object, methodName = next(self, object)
end
```

The secondary table (`Janitors[self]`) is a weak-keyed external map keyed by **index**, allowing named lookup and individual removal. Separating these two concerns avoids key collisions and keeps the primary loop fast.

## 2. Thread Safety: FastDefer

Cancelling the currently running coroutine from within itself causes a fatal panic. Janitor detects this case using `coroutine.running()` and routes the cancellation through `FastDefer` (or `task.defer`), which defers execution to the next resumption cycle.

```luau
if coroutine.running() ~= (object :: thread) then
    task.cancel(object :: thread)
else
    FastDefer(function()
        task.cancel(object :: thread)
    end)
end
```

`FastDefer` maintains a module-level thread pool to avoid allocating a new coroutine on each deferred call.

## 3. Vow Integration: Self-Managed Lifecycle

When `AddVow` is called, a new wrapper Vow is created that owns the cancellation hook. This design ensures that the registered entry is the wrapper, not the original Vow, so the `"cancel"` method is always present regardless of the Vow implementation.

Once the wrapper Vow settles (either by completion or external cancellation), a `finally` handler checks whether the entry still matches and removes it:

```luau
newVow:finally(function()
    if Get(self, uniqueId) == newVow then
        Remove(self, uniqueId)
    end
end)
```

This means a Janitor managing many short-lived Vows does not accumulate stale references over time.

## 4. Type Safety: Strict Generics

All registration methods are generic at the call site. `Add<T>` returns `T` directly, meaning the caller's type information is never lost. `AddObject<T, A...>` extends this with a variadic generic that propagates constructor argument types end-to-end.

```luau
-- T is inferred as Part; no cast required
local part = janitor:Add(Instance.new("Part"))
part.Position = Vector3.new(0, 10, 0) -- fully typed
```

`MethodName` is typed as `true | string` rather than a broad `string | boolean`. This singleton constraint ensures `false` cannot be passed, eliminating an entire class of silent misuse that would otherwise only surface at runtime.

## 5. Instance Reuse: LinkToInstance Index

When `allowMultiple` is `false` (the default), `LinkToInstance` registers under a shared sentinel key (`LinkToInstanceIndex`). This guarantees that calling `LinkToInstance` a second time on the same Janitor automatically removes the previous connection, preventing duplicate listeners without requiring the caller to track the returned connection.

## Summary

The architecture prioritizes two goals: safe cleanup under all conditions (self-cancel, destroyed instances, settled Vows) and zero information loss through the type system. Both are achieved without compromising the simplicity of the public API.

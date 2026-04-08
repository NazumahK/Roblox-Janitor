# Janitor

A strictly typed, high-performance resource management library for Luau.

## Features

- **Strict Generics**: Full type safety with `<T>` and variadic `<A...>` generics across all registration methods.
- **Vow Integration**: Native support for cancelling asynchronous tasks registered via `AddVow`.
- **Index-Based Retrieval**: Named resources can be retrieved, replaced, or individually removed at any time.
- **Thread-Safe Cleanup**: Coroutine cancellation handled via `FastDefer` to avoid self-cancellation panics.
- **Zero-Overhead Linking**: Instance destruction events automatically trigger cleanup via `LinkToInstance`.

## Installation

Add to your `wally.toml`:

```toml
[dependencies]
Janitor = "nazumahk/janitor@1.0.1"
```

## Quick Start

```luau
local Janitor = require(path.to.Janitor)

local janitor = Janitor.new()

-- Register an instance
local part = janitor:Add(Instance.new("Part"))

-- Register a connection
janitor:Add(RunService.Heartbeat:Connect(function() end))

-- Register a cleanup function
janitor:Add(function()
    print("cleaned up")
end, true)

-- Register a Vow (cancelled automatically if not settled)
janitor:AddVow(Vow.delay(10))

-- Link to instance destruction
janitor:LinkToInstance(workspace.SomePart)

-- Dispose all resources
janitor:Cleanup()
```

## Documentation

- [Why Use Janitor?](docs/WhyUseJanitor.md) -- Benefits and Case Studies
- [Technical Architecture](docs/Architecture.md) -- Internal Design & Optimizations
- [API Reference](docs/API.md) -- Full Method Specification

## License
MIT

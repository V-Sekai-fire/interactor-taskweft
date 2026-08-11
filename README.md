# fabric-taskweft-plane

The planner. It decides what a body should do, and it does not decide how the body moves.

## What it runs

[taskweft](https://github.com/v-sekai-multiplayer-fabric), a hierarchical task network
planner. It decomposes a goal into tasks a body can be asked for: cross the room, sit on that
bench, greet the person who just arrived. Each task is an intent, and it carries no pose.

Today it runs as an MCP server over HTTP on a loopback port. Here it becomes a plane, which
means it reads and publishes on the ring instead, because a plane has no networking.

## What it does not do

**It generates no motion.** A plan is a sequence of intents, and an intent is not a pose.
`fabric-motion-plane` turns each one into motion with ARDY, and a tracker makes that motion
physical. Three separate jobs, and this is the first.

The split matters because the three run at different rates. A plan changes when the world
changes, which is seconds. Motion is generated per tick. Physics is stepped per substep. Only
the last two are hot.

## Why a plane

It reads the ring to know where bodies and props are, and it publishes intents onto the same
ring. Reading a shared memory ring is what forces co-location, so it is a plane in a domain
rather than a service somewhere.

It samples at its own rate rather than per tick, in the way `fabric-janet-plane` does, and for
the same reason: **a planner must never sit in the per-packet path.** Planning is a search, and
a search has no bounded time.

## State

**Not built.** This holds the decision. The harness subtree, the ring subscription and the
taskweft call come next.

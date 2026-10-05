# Performance

- **Performance is a design-phase activity.** The 1000x wins happen before there is anything to profile — napkin-sketch the four resources (network, disk, memory, CPU) and their bandwidth and latency before building, and be roughly right.
- **Optimize the slowest resource first** — in application code usually the network and the database — after weighting by frequency of use.
- **Batch to amortize.** Per-item round trips are the N+1 shape of this mistake; give the CPU and the database large, predictable chunks of work.
- **Every multi-row read is bounded or paginated.** A function that returns many records either carries an explicit bound or paginates, and pagination is keyset-first — a stable sort key plus a unique tiebreaker, resumed from the last row seen — because it stays O(page) at any depth and neither skips nor duplicates rows when data shifts between pages. This is Control flow's put-a-limit-on-everything rule at the I/O surface.

# Out-of-Order RISC-V CPU

A 32-bit, out-of-order RISC-V processor implemented in **SystemVerilog** for UIUC ECE 411. The design targets the **RV32IM** instruction set and combines register renaming, dynamic instruction scheduling, a cache hierarchy, and branch prediction with performance-focused hardware optimizations.

## Core architecture

- **Out-of-order execution:** Register renaming, reservation stations, a physical register file, and a reorder buffer (ROB) allow independent instructions to execute before older instructions while maintaining in-order retirement.
- **RV32IM support:** Integer arithmetic, control flow, loads/stores, and multiply/divide instructions.
- **Separate instruction and data caches:** 256-bit cache lines, configurable set/way counts, and a parameterized pseudo-LRU (PLRU) replacement policy.
- **Memory interface:** Cache-line adapters and arbitration connect the caches to a burst-based memory model.

## Performance features

| Feature | Description |
| --- | --- |
| Tournament branch predictor | Combines **gshare** and **bimodal** prediction to improve branch-direction accuracy. |
| Parameterized stride prefetcher | Prefetches future cache lines using a configurable stride and a stream buffer. |
| Post-commit store buffer | Buffers committed stores to reduce stalls; the project presentation reports a **10% IPC increase** on the compression benchmark. |
| Pipelined multiply/divide | Multi-stage arithmetic units designed with throughput, power, and critical-path timing in mind. |
| Area optimization | Reduced queue/storage widths and tuned cache associativity to lower hardware area. |

## Selected results

The final project presentation reports the following comparison for the tournament predictor against a static **not-taken** baseline:

| Metric | Tournament (gshare/bimodal) | Not taken |
| --- | ---: | ---: |
| IPC | 0.402 | 0.347 |
| Branch prediction accuracy | 87.98% | 43.35% |
| Area | 271k | 201k |

The predictor improved IPC by **15.65%** in this comparison, at the cost of additional area. Results are configuration- and benchmark-specific.

## Verification and implementation

The project uses RISC-V architectural verification (RVFI/Spike), simulation, lint, and synthesis workflows. See the repository's testbench, synthesis, and documentation directories for available scripts and configurations.

> **Project scope:** The load/store queue was listed as unfinished in the final presentation; it is not claimed as a completed feature here.

**Course:** ECE 411 — Computer Organization and Design, University of Illinois Urbana-Champaign.

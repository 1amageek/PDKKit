# Progress

- [x] PC1 Measure actual Native SPICE profile admission at 128 and 512 models; freeze unchanged meaning, exact resource counts and representative timing evidence `depends:none` `parallel:none`
- [x] PC2 Separate cumulative charge from retained reservations; Native before/after counters and digests agree, 53 focused regressions and source review passed; commit only task source `depends:PC1` `parallel:none`
- [ ] PC3 Integrate changed Core/admission through actual SPICE and host consumers; verify exact counters/meaning and measured speedup, preserve unrelated source and disclose target/dependency adoption limits `depends:PC1,PC2` `parallel:none`

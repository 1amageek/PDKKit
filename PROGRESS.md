# Progress

- [x] PC1 Measure Native SPICE admission at 128/512 models; fixed digests and all 21 resource observations agree across three repetitions `depends:none` `parallel:none`
- [x] PC2 Separate cumulative charge from retained reservations; 53 focused regressions and source review passed; commit `1f2ea4a` `depends:PC1` `parallel:none`
- [x] PC3 Integration passed: actual SPICE admission reduced 11.6%/15.3% in Native Debug, Xcircuite's 28 simulation/STA/artifact/failure/cancel/resume methods passed with explicit PDK edit and compiled charge witnesses; both overrides released; normal Host pins and other targets remain unqualified; evidence at `../.verification/runs/pdk-runtime-performance-20261009/evidence.json` `depends:PC1,PC2` `parallel:none`

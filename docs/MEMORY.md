# Memory usage

Use `footprint <pid>` or `vmmap -summary <pid>` when checking Tuck's memory use. RSS alone excludes compressed or swapped-out memory and allocations charged to Tuck outside its address space.

## Investigation on November 8, 2026

On Apple Silicon, macOS 26.5.1, the installed 0.1.0 process had a 429.6 MB physical footprint after almost eight days of uptime. About 382 MB was categorized as owned, unmapped memory; RSS was only about 43 MB. This confirms the reported memory cost, but does not establish which allocation path caused the long-term accumulation.

The changes remove ScreenCaptureKit, replace the fixed 10,000-point divider length with a display-dependent bound, rasterize app icons at row size, and cancel Settings work when its window closes. Closing before a queued task starts also releases the menu bar hold; closing during a synthetic drag waits for mouse-up and cursor restoration.

A temporary release harness called the actual AppKit controllers on a Mac with 1512- and 1920-point displays and Accessibility access granted. After 100 reveal/hide cycles, a fresh original build measured 27 MB physical footprint and the optimized build measured 17 MB. These are short-run measurements, not a comparison with the eight-day-old process. The original build settled at 45 MB after its Settings cycle run.

The optimized Settings comparison was stopped before completion. The controller harness is not an end-to-end test of clicking the arrow, using a revealed app's menu, or dragging items between sections. Real interaction checks, display hot-plug testing, cancellation during a real drag, and a long-running soak remain unverified. Do not interpret the short-run results as proof that all long-term memory growth is fixed.

## Optional developer profiling

Quit Tuck first, then run:

```sh
SIGN_IDENTITY="Tuck Release" scripts/profile-memory.sh
```

Use the signing identity already associated with the installed app to preserve Accessibility access. An ad hoc run without access exercises the permission fallback but cannot validate scanning. The script compiles an isolated diagnostic app using the production controllers, shares Tuck's preferences, and records `footprint` categories and Mach-port counts in `build/memory-profile/current/profile.log`. It restores collapse state on successful completion; an interrupted run may leave that preference changed.

The optional harness checks repeated reveal/hide, Settings open/refresh/close, rapid refresh requests, cancellation before task startup and during scanning, controller release, and menu bar hold release. It does not synthesize user drags or change launch-at-login settings.

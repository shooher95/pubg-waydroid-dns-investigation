# NDK translation and Houdini diagnostics

## Why this is documented separately

These observations came from the same PUBG-on-Waydroid troubleshooting effort, but they are a separate diagnostic track from the DNS failure described in the main report. The DNS workaround produced an immediate improvement in launch and button-triggered transitions. The translation observations do not establish that NDK translation caused the DNS symptom, or that the DNS workaround fixes every translation-related problem.

## Runtime configuration

The tested Android environment was Waydroid with Android 13 / LineageOS 20. PUBG was tested with more than one ARM translation path:

- **NDK translation** (libndk_translation.so), including the Android property:
  ndk_translation.mode=light-translate-or-interpret.
- **Houdini** (libhoudini), used as an alternative translation path.

The property was observed to be empty after a Waydroid/Weston restart in one test. Setting it again inside Android restored the expected value and PUBG then booted to the lobby. This suggests the setting was not persistent across that restart in the tested setup; persistence was not solved in this investigation.

Set/check the property from the Android shell, not directly in the Linux host shell:

~~~bash
sudo waydroid shell setprop ndk_translation.mode light-translate-or-interpret
sudo waydroid shell getprop ndk_translation.mode
~~~

Expected output from the second command:

~~~text
light-translate-or-interpret
~~~

## Observed behavior

### NDK translation

- With the mode property empty / default in one splash-screen capture, the host perf profiles showed hot paths including ndk_translation::HeavyOptimizeRegion and ndk_translation::HeavyOptimizerFrontend::ResolveJumps. These appeared in both the main game process and its plugin process while the game was stuck around startup.
- After restoring light-translate-or-interpret, PUBG reached the lobby. A later lobby profile showed InterpretInsn at approximately 11.03% of sampled CPU time and LightTranslateRange at approximately 0.14%; the earlier HeavyOptimizer symbols were not present in that report.
- A separate profile was collected during a training-ground/map transition. It contained interpreter activity, including InterpretInsn, but the capture covered a mixed interval (brief freeze followed by loading). It cannot be treated as a clean measurement of the frozen interval.
- An approximately 83% CPU figure attributed to libndk_translation was reported during troubleshooting. The exact sampling interval and process/thread accounting for that figure are not preserved in the repository, so it is recorded as a reported observation rather than a reproducible benchmark.

### Signal / crash report

A tombstone from a separate run contained an abort report with the message:

~~~text
Cannot process signal 11
~~~

The captured termination signal was reported as **SIGABRT**. The text refers to signal 11 (SIGSEGV) being processed; it should not be simplified to “the game definitely crashed with SIGSEGV.” The recorded stack passed through libndk_translation.so, including HandleHostSignal, and then through memmove / an anonymous executable region / proxy-related frames. This is evidence of a translation/runtime crash path, but it does not identify the original invalid access or prove that the DNS failure caused it.

### Houdini

With libhoudini, the game reached the lobby and a first tutorial match in one test, but a later map-loading attempt stalled around 60% progress. This was a separate behavior from the NDK default-mode splash-screen optimizer hotspot. The 60% figure is the displayed loading progress, not a measured CPU or network percentage.

## Interpretation

The evidence shows that the selected translation mode materially changed the startup profile in the tested sessions. The default-mode splash capture was dominated by heavy optimizer functions; after selecting light-translate-or-interpret, the game reached the lobby and the later profile showed interpreter activity instead.

It does **not** establish that NDK translation was the root cause of the DNS failure, nor that translation is now fully stable. DNS resolution, ARM translation, Vulkan/graphics, storage loading, and match networking should be treated as distinct diagnostic layers unless a trace directly connects them.

## Evidence limitations / next steps

- Preserve full perf command lines, capture duration, process IDs, and the exact game state for future profiles.
- Keep raw perf.data, tombstones, and full logs local unless they have been reviewed and sanitized; they may contain usernames, paths, IP addresses, or other machine-specific details.
- To investigate persistence, verify the property after a full Waydroid restart and host reboot before deciding on an automated startup mechanism.
- Do not infer a translation bug solely from high CPU, a thread waiting in a syscall, or the presence of InterpretInsn; correlate samples with the exact period of visible stalling.

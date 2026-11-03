# Investigation evidence and timeline

## Scope

## Tested environment

The reported test machine was:

- Host OS: Linux Mint 22.3 (KDE Plasma, X11).
- CPU: AMD FX-8350.
- GPU: NVIDIA GeForce GTX 1060 6 GB.
- Host NVIDIA driver: 580.178.04.
- Kernel: XanMod 7.2.14-x64v2-xanmod1.
- Android environment: Waydroid, Android 13 / LineageOS 20.

These are the user's reported configuration details for this investigation; they are not requirements for the DNS workaround.

This document records observations from the PUBG + Waydroid DNS investigation. It separates directly captured results, user-reported behavior, and causal hypotheses.

## Reported environment and symptom pattern

The investigation concerned PUBG running inside Waydroid. Reported symptoms included long pauses during launch and button-triggered transitions, while the Android environment remained responsive. Gameplay after a match had loaded was reported to be smooth.

The exact duration and reproducibility of each pause were not consistently measured. Do not treat earlier estimates as benchmark data.

## Timeline

### Before the hosts-file change

- The host's /etc/hosts was inspected; it contained no entry for waydroid.
- Android's /etc/hosts contained only localhost entries.
- Hostname: shooher-To-be-filled-by-O-E-M.
- Waydroid-facing DNS server: 192.168.240.1.
- Host systemd-resolved stub: 127.0.0.53.
- dnsmasq version reported by the host: 2.91-0ubuntu0.24.04.2.

A packet capture on waydroid0 showed the Android-side address 192.168.240.112 asking for A and AAAA records for api.club.gpubgm.com via 192.168.240.1:53. The A query returned 101.33.48.209; the AAAA query returned no AAAA answer with an SOA in the authority section. That AAAA response is a valid DNS negative answer (NOERROR/NODATA), not a SERVFAIL.

A simultaneous loopback capture showed dnsmasq forwarding those queries to 127.0.0.53:53 and receiving corresponding responses.

### Focused trace of the waydroid. query

A short strace of dnsmasq (PID 118494 at that time) captured this sequence:

1. dnsmasq received a DNS query for waydroid.
2. dnsmasq created a UDP socket and forwarded the query to 127.0.0.53:53.
3. dnsmasq received a 37-byte DNS response from 127.0.0.53 with response code SERVFAIL.
4. dnsmasq later received a separate query for test-diagnostic.invalid., forwarded it, and returned NXDOMAIN.
5. dnsmasq also successfully forwarded a query for sg.datamaster.com. and returned six A records.

A repeated waydroid. query was again forwarded upstream and returned SERVFAIL. This trace establishes the forwarding and failure path for that name at the time of capture. It does not identify which Android process or subsystem originated the query.

### Workaround applied

The following commands were run on the host:

~~~bash
sudo cp -a /etc/hosts /etc/hosts.bak.pubg-test
echo '192.168.240.1 waydroid' | sudo tee -a /etc/hosts
sudo resolvectl flush-caches
~~~

### After the change

Direct queries to both resolvers succeeded:

- dig @127.0.0.53 waydroid. A returned 192.168.240.1.
- dig @192.168.240.1 waydroid. A returned 192.168.240.1.
- Both responses had status NOERROR and completed in 0 ms in the displayed output.

Immediately after adding the hosts-file entry and flushing the resolver cache, the user reported:

- PUBG launched successfully.
- The lag during launch and button-triggered transitions disappeared.

This is the key observed before/after result.

## Evidence classification

| Statement | Status |
|---|---|
| Host /etc/hosts initially had no waydroid entry | Directly inspected |
| Android /etc/hosts contained only localhost entries | Directly inspected |
| dnsmasq forwarded waydroid. to 127.0.0.53 | Directly observed in strace |
| The upstream response to waydroid. was SERVFAIL | Directly observed in strace |
| api.club.gpubgm.com A lookup returned 101.33.48.209 | Directly observed in packet capture |
| api.club.gpubgm.com AAAA lookup returned no AAAA record | Directly observed; valid NODATA response |
| Adding 192.168.240.1 waydroid made both tested resolvers return that address | Directly tested with dig |
| PUBG launch and transition lag disappeared immediately afterward | User-reported before/after observation |
| PUBG itself was the process that requested waydroid. | Not established |
| The missing hostname was the sole cause of every PUBG freeze | Not established |
| The workaround resolves every map-loading, match, or reconnect issue | Not established |

## Interpretation

The most defensible current explanation is that the Waydroid-side DNS client requested the single-label hostname waydroid.; dnsmasq forwarded it to systemd-resolved, which returned SERVFAIL because the host had no matching local mapping. Adding the mapping made the name resolvable through both tested resolver endpoints, and PUBG behavior improved immediately afterward.

The causal chain from that DNS failure to PUBG's internal behavior remains unknown. The packet capture includes PUBG-related domain traffic, but it does not prove that PUBG itself issued the waydroid. lookup. It may have been another Android service or component. Do not state otherwise without process-level attribution.

## Reproduction / future verification

If the issue returns, collect before changing anything:

~~~bash
date --iso-8601=seconds
getent ahostsv4 waydroid
dig +time=2 +tries=1 @127.0.0.53 waydroid. A
dig +time=2 +tries=1 @192.168.240.1 waydroid. A
grep -nE '(^|[[:space:]])waydroid([[:space:]]|$)' /etc/hosts
ip -br addr show waydroid0
~~~

If tracing again, capture the dnsmasq query and response around the exact time of the PUBG pause. Avoid committing raw logs containing public IP addresses, usernames, tokens, or unrelated traffic.

## Rollback

The pre-change host hosts file was backed up locally as /etc/hosts.bak.pubg-test. Restore it with:

~~~bash
sudo cp -a /etc/hosts.bak.pubg-test /etc/hosts
sudo resolvectl flush-caches
~~~

The backup file is on the user's machine and is not stored in this repository.

## Related translation diagnostics

NDK translation and Houdini behavior were also investigated on this machine. Those observations are documented separately in [translation-diagnostics.md](translation-diagnostics.md). They include a default-mode splash profile dominated by HeavyOptimizer functions, a later light-translate-or-interpret profile with InterpretInsn activity, a separate Houdini map-load stall, and a tombstone whose recorded termination was SIGABRT with the message “Cannot process signal 11.” These are separate diagnostic observations; they do not establish the cause of the DNS failure.

## Open questions

- Which Android process or service asks for waydroid.?
- Why did the upstream system resolver return SERVFAIL for that single-label hostname?
- Does dnsmasq now answer the name directly from the host hosts file (as expected), or is there another resolver behavior involved?
- Does the fix survive Waydroid restart and host reboot?
- Is 192.168.240.1 stable for this installation?
- Do any remaining map-loading or reconnect stalls correlate with DNS failures?

## Change log

- Initial documentation recorded the reported resolver failure and workaround.
- Follow-up evidence added packet-capture results, dnsmasq syscall trace findings, successful post-change queries, and the user's immediate PUBG improvement report.

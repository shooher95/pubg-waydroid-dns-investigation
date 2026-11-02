# Investigation evidence and timeline

## Scope

This document records the observations reported during the PUBG + Waydroid DNS investigation. It deliberately separates observed results from causal interpretation.

## Reported environment and symptom pattern

The investigation concerned PUBG running inside Waydroid. The reported behavior was not simply that the entire Android environment became slow:

- The Android interface remained responsive during PUBG freezes.
- Once a match was loaded, gameplay itself was reported to run smoothly.
- PUBG could pause for roughly 20–30 seconds during the first lobby load.
- Entering the training ground or a match could trigger a freeze of roughly one minute before continuing.

These timings are user-reported observations, not measurements collected by this repository's script.

## DNS observations

The investigation notes report the following resolver path for the hostname `waydroid.`:

1. A lookup was sent to `192.168.240.1`.
2. `dnsmasq` accepted the request and forwarded it to the system resolver at `127.0.0.53`.
3. The system resolver returned `SERVFAIL`.
4. The relevant `/etc/hosts` file did not contain a mapping for `waydroid`.

The notes do not include the original packet capture, exact command transcript, timestamps, or resolver configuration files. The path above is therefore recorded as an observation from the investigation, not independently reproduced evidence in this repository.

## Workaround and observed outcome

The following hosts-file mapping was added:

```text
192.168.240.1 waydroid
```

After the mapping was added, the hostname reportedly resolved successfully. PUBG was then reported to launch, and the previously observed lag disappeared.

This before/after relationship makes the hostname-resolution issue a strong diagnostic lead. It does not alone prove the exact internal mechanism by which PUBG was affected, nor establish that all freezes or reconnects share this cause.

## Evidence classification

| Statement | Status |
|---|---|
| Lookup for `waydroid.` failed with `SERVFAIL` through the reported resolver path | Reported observation |
| No `waydroid` entry was present in the inspected `/etc/hosts` | Reported observation |
| Adding `192.168.240.1 waydroid` made the name resolve | Reported observation |
| PUBG launch behavior improved after the mapping was added | Reported before/after observation |
| This DNS failure was the sole cause of every PUBG freeze | Not established |
| The workaround resolves every map-loading or reconnection issue | Not established |

## Reproduction checklist

To strengthen the evidence, capture the following before and after applying the workaround, from the same relevant Linux environment:

```bash
date --iso-8601=seconds
cat /etc/os-release
getent hosts waydroid
grep -nE '(^|[[:space:]])waydroid([[:space:]]|$)' /etc/hosts
cat /etc/resolv.conf
```

If available, also record the Waydroid version, PUBG version, relevant DNS/dnsmasq configuration, and a timestamped description of the exact PUBG transition that freezes. Redact public IPs, usernames, tokens, and other private information before committing logs.

## Open questions

- Which exact component or request in PUBG depends on resolving `waydroid`?
- Does the issue recur after a Waydroid restart or host reboot?
- Is `192.168.240.1` stable across this installation's network lifecycle?
- Do the remaining map-loading freezes or reconnects correlate with DNS failures?
- Can the failure and recovery be reproduced with timestamped resolver logs or packet captures?

## Change log

- Initial repository commit: documented the reported DNS failure, hosts-file workaround, observed PUBG improvement, and limitations.

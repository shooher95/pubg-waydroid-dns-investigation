# PUBG on Waydroid: DNS investigation

A documented Linux troubleshooting case: a single-label DNS lookup for `waydroid.` failed through the Waydroid host resolver; adding the host mapping `192.168.240.1 waydroid` made both tested resolvers return the expected address. Immediately afterward, the user reported that PUBG launched and the previously observed launch / button-transition lag disappeared.

**Scope:** evidence-backed case study and workaround for one reported Waydroid setup — not a universal PUBG performance tweak.

**Languages:** English documentation; key search terms are also listed in Russian below.

## Tested environment

The investigation was performed on this reported setup:

| Component | Configuration |
|---|---|
| Host OS | Linux Mint 22.3 (KDE Plasma, X11) |
| CPU | AMD FX-8350 |
| GPU | NVIDIA GeForce GTX 1060 6 GB |
| Host NVIDIA driver | 580.178.04 |
| Kernel | XanMod 7.2.14-x64v2-xanmod1 |
| Android container | Waydroid, Android 13 / LineageOS 20 |

These details describe the test machine, not a claim that the workaround is specific to this hardware.

## Summary

A DNS request from the Waydroid client (192.168.240.112) for the single-label hostname **waydroid.** reached the host's dnsmasq at **192.168.240.1**. Before the workaround, dnsmasq forwarded the query to the systemd-resolved stub at **127.0.0.53**, which returned **SERVFAIL**.

The host's /etc/hosts did not contain a waydroid mapping. Adding:

~~~text
192.168.240.1 waydroid
~~~

made both the host resolver (127.0.0.53) and Waydroid-facing resolver (192.168.240.1) return 192.168.240.1 for waydroid. Immediately afterward, the user reported that PUBG launched and the previously observed lag during launch / button-triggered transitions disappeared.

This is a strong before/after correlation supported by packet capture, dnsmasq syscall tracing, and successful post-change DNS queries. It is not proof that the missing hostname was the sole cause of every PUBG freeze, nor does the capture identify which Android component requested waydroid.

## Repository contents

- docs/evidence.md — timeline, evidence classification, interpretation, and open questions.
- docs/dns-resolution-capture.md — sanitized packet-capture and dnsmasq trace findings.
- docs/translation-diagnostics.md — separate NDK translation / Houdini observations; these are not established as the cause of the DNS issue.
- scripts/verify-dns-fix.sh — read-only check for the expected resolution and hosts-file entry.
- llms.txt — concise project map and evidence summary for AI assistants and other automated readers.

## Verify the workaround

Run:

~~~bash
chmod +x scripts/verify-dns-fix.sh
./scripts/verify-dns-fix.sh
~~~

A successful check confirms that the current host lookup resolves to the expected address and that the matching hosts-file entry exists. It does not, by itself, prove that DNS was the only cause of every PUBG issue.

You can also check both resolver endpoints directly:

~~~bash
dig +time=2 +tries=1 @127.0.0.53 waydroid. A
dig +time=2 +tries=1 @192.168.240.1 waydroid. A
~~~

Both should return 192.168.240.1 in the tested setup.

## Workaround and rollback

First confirm that 192.168.240.1 is still the Waydroid host-side gateway:

~~~bash
ip -br addr show waydroid0
~~~

Then add the mapping if it is absent:

~~~bash
grep -qE '^[[:space:]]*192\.168\.240\.1[[:space:]]+.*(^|[[:space:]])waydroid([[:space:]]|$)' /etc/hosts \
  || printf '%s\n' '192.168.240.1 waydroid' | sudo tee -a /etc/hosts
sudo resolvectl flush-caches
~~~

A backup was created during this investigation at /etc/hosts.bak.pubg-test. To restore that exact pre-test file:

~~~bash
sudo cp -a /etc/hosts.bak.pubg-test /etc/hosts
sudo resolvectl flush-caches
~~~

Do not blindly apply this address to a different Waydroid/network configuration. Verify the gateway first.

## Evidence quality and limitations

The repository includes sanitized summaries of the actual terminal output. Raw captures and trace files remain local and are not committed. The investigation does not yet establish why the Android-side client requested waydroid, or whether all remaining match/map/reconnect stalls share this cause. See docs/evidence.md, docs/dns-resolution-capture.md, and docs/translation-diagnostics.md.

## Search keywords

**English:** Waydroid, PUBG Mobile, PUBG on Linux, Linux Mint, Android container, DNS troubleshooting, DNS resolution, dnsmasq, systemd-resolved, /etc/hosts, single-label hostname, SERVFAIL, network debugging, Linux gaming.

**Русский:** Waydroid, PUBG Mobile на Linux, PUBG в Waydroid, Linux Mint, DNS, настройка DNS, dnsmasq, systemd-resolved, ошибка SERVFAIL, файл hosts, контейнер Android, исправление лагов.

Suggested GitHub repository topics: `waydroid`, `pubg-mobile`, `linux`, `android`, `dns`, `dnsmasq`, `systemd-resolved`, `linux-mint`, `troubleshooting`, `networking`.

## The investigation crew

Every serious investigation needs a crew. Ours was assembled from the finest available AI specialists:

- **GPT — navigator:** kept the investigation on course, connected the clues, and tried very hard not to send us into the DNS wilderness.
- **DeepSeek — psychological support:** provided emotional stability while we stared into packet captures and questioned our life choices.
- **Gemini — fresh-information search engine:** went looking for current documentation and clues from the outside world.
- **The human operator — chief investigator:** ran the commands, captured the evidence, pressed the PUBG buttons, and discovered that one line in `/etc/hosts` could apparently defeat an entire boss fight.

**Final boss:** `waydroid.`  
**Weapon:** `192.168.240.1 waydroid`  
**Boss health:** mysteriously reduced to zero.

*No AI was harmed during this investigation. A few terminal tabs, however, may never recover.*

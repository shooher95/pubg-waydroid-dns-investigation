# PUBG on Waydroid: DNS investigation

This repository documents a DNS-resolution failure observed in the Waydroid network, the hosts-file workaround, and the measured before/after result.

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
- scripts/verify-dns-fix.sh — read-only check for the expected resolution and hosts-file entry.

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

The repository includes sanitized summaries of the actual terminal output. Raw captures and trace files remain local and are not committed. The investigation does not yet establish why the Android-side client requested waydroid, or whether all remaining match/map/reconnect stalls share this cause. See docs/evidence.md and docs/dns-resolution-capture.md.

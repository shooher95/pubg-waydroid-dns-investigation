# DNS packet capture and dnsmasq trace

This note summarizes the relevant output collected during the investigation. It omits unrelated traffic and raw packet identifiers.

## Packet capture on waydroid0

The Android-side client (192.168.240.112) queried the Waydroid host gateway/resolver (192.168.240.1:53) for:

- AAAA api.club.gpubgm.com
- A api.club.gpubgm.com

Observed responses:

- AAAA: no AAAA answer; an SOA for gpubgm.com appeared in the authority section (NOERROR/NODATA).
- A: api.club.gpubgm.com A 101.33.48.209.

The same queries appeared on host loopback as dnsmasq forwarding to 127.0.0.53:53. The upstream responses returned promptly. This capture does not show that the game itself requested waydroid.

## dnsmasq syscall trace

A short trace of dnsmasq (PID 118494 during the test) showed:

- recvmsg on its DNS socket for waydroid.
- sendto of the query to 127.0.0.53:53.
- recvfrom of a DNS response from 127.0.0.53 with response code SERVFAIL.
- The same forwarding pattern for test-diagnostic.invalid., which returned NXDOMAIN.
- A separate sg.datamaster.com. lookup succeeded and returned six A records.

This demonstrates that dnsmasq was alive and could forward other DNS queries; the observed failure was specific to the waydroid. lookup in that test. It does not establish why systemd-resolved returned SERVFAIL or which Android process originated the query.

## After adding the hosts entry

After adding 192.168.240.1 waydroid to the host /etc/hosts and running sudo resolvectl flush-caches, both direct tests succeeded:

~~~text
@127.0.0.53 waydroid. A -> NOERROR, 192.168.240.1
@192.168.240.1 waydroid. A -> NOERROR, 192.168.240.1
~~~

The user then reported that PUBG launched and the previously observed lag disappeared.

## Capture caveats

- The bad udp cksum annotations printed by tcpdump on locally captured outgoing packets can be caused by checksum offload; they are not, by themselves, evidence of corrupted DNS packets.
- The first standalone dig @192.168.240.1 waydroid. A test timed out, while the later strace showed an upstream SERVFAIL response and subsequent post-fix tests succeeded. Preserve this distinction rather than describing every pre-fix client query as receiving the same response.
- Raw files such as /tmp/dns-waydroid.txt, /tmp/dns-loopback.txt, and /tmp/dnsmasq.trace remained local; this repository contains a sanitized summary, not raw captures.

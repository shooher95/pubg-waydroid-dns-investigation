# PUBG on Waydroid: DNS investigation

This repository documents a DNS-related issue encountered while running PUBG in Waydroid, the observed workaround, and a small verification script.

## Summary

During the investigation, a lookup for the hostname `waydroid.` was observed failing through the DNS path used by Waydroid. The reported resolver path was:

```text
waydroid. -> 192.168.240.1 -> dnsmasq -> 127.0.0.53 -> SERVFAIL
```

The hostname `waydroid` was not present in `/etc/hosts` in the environment where the failing lookup was investigated. Adding the mapping below made the hostname resolve:

```text
192.168.240.1 waydroid
```

After this change, PUBG was reported to launch successfully and the previously observed lag disappeared.

**Important:** this is a documented working workaround and a strong diagnostic lead, not proof that every PUBG freeze, map-loading issue, or reconnection problem has the same cause. The repository distinguishes reported observations from conclusions that still need testing.

## Repository contents

- [`docs/evidence.md`](docs/evidence.md) — investigation timeline, observations, interpretation, and open questions.
- [`scripts/verify-dns-fix.sh`](scripts/verify-dns-fix.sh) — checks whether `waydroid` currently resolves to `192.168.240.1` and whether the matching hosts-file entry exists.

## Verify the workaround

Run the script in the same environment / network namespace in which the failing lookup was observed:

```bash
chmod +x scripts/verify-dns-fix.sh
./scripts/verify-dns-fix.sh
```

A successful check confirms that the current lookup resolves to the expected address. It does not, by itself, prove that DNS was the only cause of every PUBG issue.

## Workaround

In the environment where the lookup failed, ensure that `/etc/hosts` contains:

```text
192.168.240.1 waydroid
```

For example, after confirming that this is the correct environment and that the address is still valid:

```bash
grep -qE '^[[:space:]]*192\.168\.240\.1[[:space:]]+.*(^|[[:space:]])waydroid([[:space:]]|$)' /etc/hosts \
  || printf '%s\n' '192.168.240.1 waydroid' | sudo tee -a /etc/hosts
```

Do not blindly apply this to a different Waydroid/network configuration: verify that `192.168.240.1` is still the intended address first.

## Evidence quality and limitations

The initial documentation is based on the investigation notes available when this repository was created. Raw command output, packet captures, exact timestamps, and full environment version information were not included in those notes. They should be added as new evidence becomes available; they must not be fabricated or inferred.

See [`docs/evidence.md`](docs/evidence.md) for the detailed record.

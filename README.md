# sml-actor

Cooperative actor mailboxes built on [`sml-chan`](../sml-chan). Processes communicate via FIFO channels and `Chan.run` schedules them deterministically.

## Scope

- Mailbox = `sml-chan` channel
- `spawn`/`run` delegate to the cooperative scheduler
- No preemptive threads or FFI

## Tests

Ping-pong: two processes exchange `n` messages; count must equal `n`.

```sh
make all-tests
```

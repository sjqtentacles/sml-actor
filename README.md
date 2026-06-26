# sml-actor

[![CI](https://github.com/sjqtentacles/sml-actor/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-actor/actions/workflows/ci.yml)

A small **cooperative actor model** for Standard ML, built on
[`sml-chan`](../sml-chan) mailboxes. Actors handle messages with a swappable
behavior, can `become` a new behavior, `stop` themselves, ask for a reply, and
be supervised — all on a single thread with a deterministic, run-to-quiescence
scheduler. No OS threads, no FFI.

## High-level actor API

```sml
(* A behavior receives its own handle (`self`) and a message. *)
datatype msg = Inc | Add of int | Get of int Actor.mailbox

val () = Actor.system ()                 (* reset scheduler state *)

val state = ref 0
val counter = Actor.spawn (fn self => fn m =>
  case m of
      Inc     => state := !state + 1
    | Add k   => state := !state + k
    | Get rep => Actor.send rep (!state))

val () = Actor.tell counter Inc          (* enqueue messages *)
val () = Actor.tell counter (Add 10)
val () = Actor.run ()                    (* drain to quiescence *)
(* !state = 11 *)

(* ask/reply: build a message from a one-shot reply mailbox *)
val now = Actor.ask counter (fn rep => Get rep)   (* 11 *)
```

### Behavior control

```sml
(* become: swap the behavior for subsequent messages *)
val a = Actor.spawn (fn self => fn _ =>
  Actor.become self (fn _ => fn _ => print "new behavior\n"))

(* stop: mark the actor dead; later tells are dropped *)
val b = Actor.spawn (fn self => fn _ => Actor.stop self)
val () = Actor.tell b ()    (* handled *)
val () = Actor.tell b ()    (* dropped — actor stopped itself *)
Actor.isAlive b             (* false *)
```

### Supervision

```sml
(* supervise: if the behavior raises, reinstate the initial behavior and keep
   going (the offending message is dropped) instead of aborting `run`. *)
val sup = Actor.supervise (fn self => fn k =>
  if k = 0 then raise Fail "bad input" else use k)
val () = Actor.tell sup 0   (* raises internally, actor restarts *)
val () = Actor.tell sup 5   (* still delivered *)
val () = Actor.run ()       (* does not propagate the exception *)
```

## Low-level mailbox API (back-compat)

The original FIFO mailbox primitives are retained:

```sml
val ch : int Actor.mailbox = Actor.mailbox ()
val () = Actor.send ch 1
val () = Actor.send ch 2
val x = Actor.recv ch        (* 1 — FIFO order *)
(* recv on an empty mailbox raises *)
```

## API sketch

```sml
type 'a mailbox
val mailbox : unit -> 'a mailbox
val send    : 'a mailbox -> 'a -> unit
val recv    : 'a mailbox -> 'a

type 'msg ref_
type 'msg behavior = 'msg ref_ -> 'msg -> unit
val system    : unit -> unit
val spawn     : 'msg behavior -> 'msg ref_
val supervise : 'msg behavior -> 'msg ref_
val tell      : 'msg ref_ -> 'msg -> unit
val self      : 'msg ref_ -> 'msg ref_
val become    : 'msg ref_ -> 'msg behavior -> unit
val stop      : 'msg ref_ -> unit
val isAlive   : 'msg ref_ -> bool
val run       : unit -> unit
val ask       : 'msg ref_ -> ('reply mailbox -> 'msg) -> 'reply
```

## Scheduling model

- `tell` enqueues a message into the actor's mailbox; nothing runs until `run`.
- `run` performs round-robin passes over all spawned actors, delivering at most
  one message per actor per pass, and loops until a full pass makes no progress
  (**run to quiescence**). This is fully deterministic and single-threaded.
- Messages an actor sends to itself (or to others) **during** `run` are picked
  up in later passes of the same `run`.

## Scope and limitations

- **Cooperative, not preemptive.** Everything runs on the calling thread; a
  behavior that loops forever blocks the scheduler. There is no time-slicing.
- **Deterministic order.** Delivery is round-robin over actors in spawn order —
  there is no randomization or real concurrency. Great for testing, not for
  parallelism.
- **No mailbox priorities or selective receive.** Each actor's mailbox is a
  plain FIFO (`sml-chan` channel); behaviors handle whatever message is next.
- **Supervision is single-strategy.** `supervise` restarts with the initial
  behavior and drops the failing message. There are no escalation policies,
  supervision trees, or restart limits.
- **`stop` is terminal.** A stopped actor drops all future messages; there is no
  resume. Its drain thunk remains registered but is inert.
- Built entirely on the existing `sml-chan` API — the vendored `sml-chan` is
  **unmodified**.

## Tests

```sh
make all-tests
```

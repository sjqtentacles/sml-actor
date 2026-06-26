(* actor.sig — cooperative actors on sml-chan mailboxes.

   Two layers:
   - A high-level actor model: spawn behaviors, `tell` messages, `become`
     to swap behavior, `stop` to halt, and `run` to drain to quiescence.
   - The original low-level mailbox API (`mailbox`/`send`/`recv`), retained
     for back-compat with the ping-pong style of usage. *)

signature ACTOR =
sig
  (* --- low-level mailbox API (back-compat) --- *)
  type 'a mailbox
  val mailbox : unit -> 'a mailbox
  val send    : 'a mailbox -> 'a -> unit
  val recv    : 'a mailbox -> 'a

  (* --- high-level actor model --- *)
  type 'msg ref_                                   (* actor handle *)
  type 'msg behavior = 'msg ref_ -> 'msg -> unit   (* handle one message *)

  val system  : unit -> unit                       (* reset scheduler state *)
  val spawn   : 'msg behavior -> 'msg ref_
  val tell    : 'msg ref_ -> 'msg -> unit          (* enqueue a message *)
  val self    : 'msg ref_ -> 'msg ref_
  val become  : 'msg ref_ -> 'msg behavior -> unit (* swap behavior *)
  val stop    : 'msg ref_ -> unit                  (* mark dead; drops msgs *)
  val isAlive : 'msg ref_ -> bool
  val run     : unit -> unit                       (* run to quiescence *)

  (* supervised spawn: if the behavior raises while handling a message, the
     actor is restarted with its initial behavior (the offending message is
     dropped) instead of the exception escaping `run`. *)
  val supervise : 'msg behavior -> 'msg ref_

  (* ask/reply: build a message from a fresh one-shot reply mailbox, `tell`
     it to the target, run to quiescence, and return the reply. *)
  val ask : 'msg ref_ -> ('reply mailbox -> 'msg) -> 'reply
end

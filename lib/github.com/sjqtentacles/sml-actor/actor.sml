structure Actor :> ACTOR =
struct
  (* --- low-level mailbox API (back-compat) --- *)
  type 'a mailbox = 'a Chan.chan
  fun mailbox () = Chan.channel ()
  val send = Chan.send
  val recv = Chan.recv

  (* --- scheduler state --------------------------------------------------- *)

  (* Each actor registers a `drain` thunk: process at most one queued message,
     returning true if a message was handled (so the scheduler knows progress
     was made this round). The thunk is monomorphic (`unit -> bool`) so actors
     of different message types can share one ready list. *)
  val drains : (unit -> bool) list ref = ref []

  fun system () = drains := []

  (* --- actor handle ------------------------------------------------------- *)

  (* An actor handle is a record; its behavior stores a function from the
     handle back to a message handler. We tie the recursive knot with a
     single-constructor datatype rather than `withtype` (which only attaches
     to datatypes). *)
  datatype 'msg ref_ =
    Ref of { box   : 'msg Chan.chan,   (* mailbox: queued messages *)
             beh   : ('msg ref_ -> 'msg -> unit) ref,
             alive : bool ref }
  type 'msg behavior = 'msg ref_ -> 'msg -> unit

  fun self (a : 'msg ref_) = a
  fun isAlive (Ref a : 'msg ref_) = !(#alive a)

  fun become (Ref a : 'msg ref_) b = (#beh a) := b
  fun stop (Ref a : 'msg ref_) = (#alive a) := false

  (* tell: enqueue a message if the actor is still alive (else drop). *)
  fun tell (Ref a : 'msg ref_) msg =
    if !(#alive a) then Chan.send (#box a) msg else ()

  (* Drain one message from an actor's mailbox, dispatching to its behavior.
     `onError` decides what happens if the behavior raises. *)
  fun makeDrain (a as Ref r : 'msg ref_) onError () =
    if not (!(#alive r)) then false
    else
      (case (SOME (Chan.recv (#box r)) handle _ => NONE) of
           NONE => false
         | SOME msg =>
             ((!(#beh r)) a msg handle e => onError (a, e); true))

  fun register (a : 'msg ref_) onError =
    drains := !drains @ [makeDrain a onError]

  fun spawn (b : 'msg behavior) : 'msg ref_ =
    let
      val a = Ref { box = Chan.channel (), beh = ref b, alive = ref true }
    in
      register a (fn (_, e) => raise e);   (* unsupervised: propagate *)
      a
    end

  fun supervise (b : 'msg behavior) : 'msg ref_ =
    let
      val a = Ref { box = Chan.channel (), beh = ref b, alive = ref true }
    in
      (* on failure, reinstate the initial behavior and keep going *)
      register a (fn (Ref r, _) => (#beh r) := b);
      a
    end

  (* run-to-quiescence: round-robin every actor's drain until a full pass
     makes no progress (no actor had a message to handle). *)
  fun run () =
    let
      fun pass () = List.foldl (fn (d, acc) => d () orelse acc) false (!drains)
      fun loop () = if pass () then loop () else ()
    in loop () end

  (* ask/reply: a one-shot reply mailbox, message built from it, run, recv. *)
  fun ask (target : 'msg ref_) (make : 'reply mailbox -> 'msg) : 'reply =
    let
      val reply : 'reply mailbox = mailbox ()
    in
      tell target (make reply);
      run ();
      Chan.recv reply
    end
end

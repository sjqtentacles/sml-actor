structure Actor :> ACTOR =
struct
  type 'a mailbox = 'a Chan.chan
  fun mailbox () = Chan.channel ()
  val send = Chan.send
  val recv = Chan.recv

  (* Spawned actor bodies are registered and run later by `run`, so the
     caller can wire up several actors (and their mailboxes) before any of
     them executes.  Execution order is spawn order, on the single calling
     thread (sml-chan provides buffered queues, not OS threads). *)
  val pending : Chan.process list ref = ref []

  fun spawn f = pending := !pending @ [f]

  fun run () =
    let val ps = !pending
    in pending := []; Chan.run ps end
end

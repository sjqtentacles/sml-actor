structure Tests =
struct
  open Harness
  structure A = Actor
  fun run () =
  let
    (* --- spawn defers execution until run --- *)
    val () = section "spawn defers, run executes"
    val ran = ref false
    val () = A.spawn (fn () => ran := true)
    val () = checkBool "not run before run()" (false, !ran)
    val () = A.run ()
    val () = checkBool "run executes spawned body" (true, !ran)
    (* run drains the queue: a second run with nothing pending is a no-op *)
    val ran2 = ref false
    val () = A.run ()
    val () = checkBool "queue drained after run" (false, !ran2)

    (* --- producer/consumer over a mailbox via spawn/run --- *)
    val () = section "producer/consumer message passing"
    val ch = A.mailbox ()
    val n = 10
    val received = ref 0
    val () = A.spawn (fn () =>
               List.app (fn _ => A.send ch 1) (List.tabulate (n, fn i => i)))
    val () = A.spawn (fn () =>
               received := List.length (List.tabulate (n, fn _ => A.recv ch)))
    val () = A.run ()
    val () = checkInt "received count" (n, !received)

    (* --- ordering: spawned bodies run in spawn order --- *)
    val () = section "spawn order preserved"
    val log = ref ([] : int list)
    val () = A.spawn (fn () => log := 1 :: !log)
    val () = A.spawn (fn () => log := 2 :: !log)
    val () = A.spawn (fn () => log := 3 :: !log)
    val () = A.run ()
    val () = checkIntList "ran in order" ([3,2,1], !log)

    (* --- recv on an empty mailbox raises --- *)
    val () = section "recv error path"
    val empty : int A.mailbox = A.mailbox ()
    val () = checkRaises "recv empty raises" (fn () => A.recv empty)
  in Harness.run () end
end

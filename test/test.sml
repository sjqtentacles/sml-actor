structure Tests =
struct
  open Harness
  structure A = Actor

  (* message types for the high-level tests *)
  datatype counterMsg = Inc | Add of int | Get of int A.mailbox

  fun run () =
  let
    (* ================= low-level mailbox API (back-compat) ============== *)
    val () = section "mailbox send/recv FIFO"
    val ch : int A.mailbox = A.mailbox ()
    val () = A.send ch 1
    val () = A.send ch 2
    val () = A.send ch 3
    val () = checkInt "first out" (1, A.recv ch)
    val () = checkInt "second out" (2, A.recv ch)
    val () = checkInt "third out" (3, A.recv ch)

    val () = section "producer/consumer over a mailbox"
    val ch2 : int A.mailbox = A.mailbox ()
    val n = 10
    val () = List.app (fn _ => A.send ch2 1) (List.tabulate (n, fn i => i))
    val received = List.foldl op+ 0 (List.tabulate (n, fn _ => A.recv ch2))
    val () = checkInt "received sum" (n, received)

    val () = section "recv on empty mailbox raises"
    val empty : int A.mailbox = A.mailbox ()
    val () = checkRaises "recv empty raises" (fn () => A.recv empty)

    (* ================= high-level actor model =========================== *)

    val () = section "spawn + tell + run to quiescence"
    val () = A.system ()
    val state = ref 0
    val counter : counterMsg A.ref_ =
      A.spawn (fn self => fn msg =>
        case msg of
            Inc     => state := !state + 1
          | Add k   => state := !state + k
          | Get rep => A.send rep (!state))
    val () = A.tell counter Inc
    val () = A.tell counter Inc
    val () = A.tell counter Inc
    val () = checkInt "not processed before run" (0, !state)
    val () = A.run ()
    val () = checkInt "three Inc -> 3" (3, !state)

    val () = section "messages telled during run are also drained"
    val () = A.system ()
    val total = ref 0
    val acc : int A.ref_ =
      A.spawn (fn self => fn k =>
        (total := !total + k;
         (* re-tell a decremented message to self until it hits 0 *)
         if k > 1 then A.tell self (k - 1) else ()))
    val () = A.tell acc 4
    val () = A.run ()
    (* 4 + 3 + 2 + 1 = 10 *)
    val () = checkInt "self-retell drains fully" (10, !total)

    val () = section "ask / reply"
    val () = A.system ()
    val st2 = ref 0
    val c2 : counterMsg A.ref_ =
      A.spawn (fn self => fn msg =>
        case msg of
            Inc     => st2 := !st2 + 1
          | Add k   => st2 := !st2 + k
          | Get rep => A.send rep (!st2))
    val () = A.tell c2 (Add 5)
    val () = A.tell c2 (Add 7)
    val answer = A.ask c2 (fn rep => Get rep)
    val () = checkInt "ask returns current state" (12, answer)

    val () = section "become swaps behavior"
    val () = A.system ()
    val log = ref ([] : string list)
    fun push s = log := s :: !log
    val sw : int A.ref_ =
      A.spawn (fn self => fn _ =>
        (push "first"; A.become self (fn _ => fn _ => push "second")))
    val () = A.tell sw 0
    val () = A.tell sw 0
    val () = A.tell sw 0
    val () = A.run ()
    val () = checkStringList "become takes effect"
               (["second", "second", "first"], !log)

    val () = section "stop drops later messages"
    val () = A.system ()
    val hits = ref 0
    val s3 : int A.ref_ =
      A.spawn (fn self => fn _ => (hits := !hits + 1; A.stop self))
    val () = A.tell s3 0
    val () = A.tell s3 0
    val () = A.tell s3 0
    val () = A.run ()
    val () = checkInt "only one msg before stop" (1, !hits)
    val () = checkBool "actor is dead" (false, A.isAlive s3)
    (* telling a dead actor is a no-op *)
    val () = A.tell s3 0
    val () = A.run ()
    val () = checkInt "dead actor ignores tell" (1, !hits)

    val () = section "supervise restarts on failure"
    val () = A.system ()
    val seen = ref ([] : int list)
    (* behavior: on the first message it has fresh state via a closed-over ref;
       supervise reinstates the initial behavior after a raise. *)
    val crashed = ref false
    val sup : int A.ref_ =
      A.supervise (fn self => fn k =>
        (seen := k :: !seen;
         if k = 2 andalso not (!crashed)
         then (crashed := true; raise Fail "boom")
         else ()))
    val () = A.tell sup 1
    val () = A.tell sup 2   (* this one raises, gets dropped, actor restarts *)
    val () = A.tell sup 3
    val () = A.run ()       (* must not propagate the exception *)
    val () = checkBool "supervised actor still alive" (true, A.isAlive sup)
    val () = checkIntList "messages seen (incl crashed)" ([3, 2, 1], !seen)
  in Harness.run () end
end

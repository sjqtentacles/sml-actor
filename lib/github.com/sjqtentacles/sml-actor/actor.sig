(* actor.sig — cooperative actors on sml-chan mailboxes. *)

signature ACTOR =
sig
  type 'a mailbox
  val mailbox : unit -> 'a mailbox
  val send : 'a mailbox -> 'a -> unit
  val recv : 'a mailbox -> 'a
  val spawn : (unit -> unit) -> unit
  val run : unit -> unit
end

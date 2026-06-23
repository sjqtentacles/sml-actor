(* chan.sig — CSP channels and cooperative scheduler. *)

signature CHAN =
sig
  type 'a chan
  type process = unit -> unit

  val channel : unit -> 'a chan
  val send : 'a chan -> 'a -> unit
  val recv : 'a chan -> 'a
  val spawn : process -> process
  val run : process list -> unit
end

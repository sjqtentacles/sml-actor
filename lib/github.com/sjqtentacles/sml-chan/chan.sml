structure Chan :> CHAN =
struct
  type 'a chan = 'a list ref
  type process = unit -> unit

  fun channel () = ref []
  fun send ch x = ch := !(ch) @ [x]
  fun recv ch =
    case !(ch) of
        x :: xs => (ch := xs; x)
      | [] => raise Fail "recv on empty channel"
  fun spawn f = f
  fun run ps = List.app (fn p => p ()) ps
end

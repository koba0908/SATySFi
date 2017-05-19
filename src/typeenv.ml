open Types

module VarMap = Map.Make(String)


module ModuleID
: sig
    type t
    val compare : t -> t -> int
    val fresh : unit -> t
  end
= struct

    type t = int

    let compare i1 i2 = i1 - i2

    let current_id = ref 0

    let fresh () =
      begin
        incr current_id ;
        !current_id
      end

  end


module ModuleTree = HashTree.Make(ModuleID)

module ModuleNameMap = Map.Make(String)

type name_to_id_map = ModuleID.t ModuleNameMap.t

type single_environment = poly_type VarMap.t

type t = (ModuleID.t list) * name_to_id_map * (single_environment ModuleTree.t)

(*
let empty : t = (ModuleNameMap.empty, ModuleTree.empty VarMap.empty)
*)

let from_list (lst : (var_name * poly_type) list) =
  let vmapinit = List.fold_left (fun vmap (varnm, pty) -> VarMap.add varnm pty vmap) VarMap.empty lst in
    ([], ModuleNameMap.empty, ModuleTree.empty vmapinit)


let add ((addr, nmtoid, mtr) : t) (varnm : var_name) (pty : poly_type) =
  let mtrnew = ModuleTree.update mtr addr (VarMap.add varnm pty) in
    (addr, nmtoid, mtrnew)


let find ((addr, _, mtr) : t) (varnm : var_name) =
  let ptyopt =
    ModuleTree.search_backward mtr addr (fun sgl ->
      try Some(VarMap.find varnm sgl) with
      | Not_found -> None
    )
  in
    match ptyopt with
    | None      -> raise Not_found
    | Some(pty) -> pty


(* ---- following are all for debugging --- *)
(*
let string_of_type_environment (tyenv : t) (msg : string) =
  let rec iter (tyenv : t) =
    match tyenv with
    | []               -> ""
    | (vn, ts) :: tail ->
            "    #  "
              ^ ( let len = String.length vn in if len >= 16 then vn else vn ^ (String.make (16 - len) ' ') )
       ^ " : " ^ ((* string_of_mono_type ts *) "type") ^ "\n"
              ^ (iter tail)
  in
      "    #==== " ^ msg ^ " " ^ (String.make (58 - (String.length msg)) '=') ^ "\n"
    ^ (iter tyenv)
    ^ "    #================================================================\n"


let string_of_control_sequence_type (tyenv : t) =
  let rec iter (tyenv : t) =
    match tyenv with
    | []               -> ""
    | (vn, ts) :: tail ->
        ( match String.sub vn 0 1 with
          | "\\" ->
              "    #  "
                ^ ( let len = String.length vn in if len >= 16 then vn else vn ^ (String.make (16 - len) ' ') )
                ^ " : " ^ ((* string_of_mono_type ts *) "type") ^ "\n" (* remains to be implemented *)
          | _    -> ""
        ) ^ (iter tail)
  in
      "    #================================================================\n"
    ^ (iter tyenv)
    ^ "    #================================================================\n"
*)

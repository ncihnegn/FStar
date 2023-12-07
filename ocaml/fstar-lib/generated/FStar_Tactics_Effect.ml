open Prims
type 'a tac_wp_t0 = unit
type ('a, 'wp) tac_wp_monotonic = unit
type 'a tac_wp_t = unit
type ('a, 'wp) tac_repr =
  FStar_Tactics_Types.proofstate -> 'a FStar_Tactics_Result.__result
type ('a, 'x, 'ps, 'post) tac_return_wp = 'post
let tac_return : 'a . 'a -> ('a, Obj.t) tac_repr =
  fun x -> fun s -> FStar_Tactics_Result.Success (x, s)
type ('a, 'b, 'wpuf, 'wpug, 'ps, 'post) tac_bind_wp = 'wpuf
type ('a, 'wp, 'ps, 'post) tac_wp_compact = unit
let tac_bind :
  'a 'b 'wpuf 'wpug .
    FStar_Range.range ->
      FStar_Range.range ->
        ('a, 'wpuf) tac_repr ->
          ('a -> ('b, 'wpug) tac_repr) -> ('b, unit) tac_repr
  =
  fun r1 ->
    fun r2 ->
      fun t1 ->
        fun t2 ->
          fun ps ->
            let ps1 = FStar_Tactics_Types.set_proofstate_range ps r1 in
            let ps2 = FStar_Tactics_Types.incr_depth ps1 in
            let r = t1 ps2 in
            match r with
            | FStar_Tactics_Result.Success (a1, ps') ->
                let ps'1 = FStar_Tactics_Types.set_proofstate_range ps' r2 in
                (match FStar_Tactics_Types.tracepoint ps'1 with
                 | true -> t2 a1 (FStar_Tactics_Types.decr_depth ps'1))
            | FStar_Tactics_Result.Failed (e, ps') ->
                FStar_Tactics_Result.Failed (e, ps')
type ('a, 'wputhen, 'wpuelse, 'b, 'ps, 'post) tac_if_then_else_wp = unit
type ('a, 'wputhen, 'wpuelse, 'f, 'g, 'b) tac_if_then_else =
  ('a, unit) tac_repr
let tac_subcomp :
  'a 'wpuf 'wpug . ('a, 'wpuf) tac_repr -> ('a, 'wpug) tac_repr =
  fun uu___ -> (fun f -> Obj.magic f) uu___
type ('a, 'b, 'wpuf, 'f) tac_close = ('a, unit) tac_repr
let __proj__TAC__item__return = tac_return
let __proj__TAC__item__bind = tac_bind
type ('a, 'wp, 'uuuuu, 'uuuuu1) lift_div_tac_wp = 'wp
let lift_div_tac : 'a 'wp . (unit -> 'a) -> ('a, 'wp) tac_repr =
  fun f ->
    fun ps -> let uu___1 = f () in FStar_Tactics_Result.Success (uu___1, ps)
let (get : unit -> (FStar_Tactics_Types.proofstate, Obj.t) tac_repr) =
  fun uu___ -> fun ps -> FStar_Tactics_Result.Success (ps, ps)
let raise : 'a . Prims.exn -> ('a, Obj.t) tac_repr =
  fun e -> fun ps -> FStar_Tactics_Result.Failed (e, ps)
type ('uuuuu, 'p) with_tactic = 'p
let (rewrite_with_tactic :
  (unit -> (unit, unit) tac_repr) -> unit -> Obj.t -> Obj.t) =
  fun uu___ -> fun uu___1 -> fun p -> p
let synth_by_tactic : 'uuuuu . (unit -> (unit, unit) tac_repr) -> 'uuuuu =
  fun uu___ -> Prims.admit ()
let assume_safe : 'a . (unit -> ('a, unit) tac_repr) -> ('a, unit) tac_repr =
  fun tau ->
    tac_bind
      (FStar_Sealed.seal
         (Obj.magic
            (FStar_Range.mk_range "FStar.Tactics.Effect.fsti"
               (Prims.of_int (221)) (Prims.of_int (57)) (Prims.of_int (221))
               (Prims.of_int (65)))))
      (FStar_Sealed.seal
         (Obj.magic
            (FStar_Range.mk_range "FStar.Tactics.Effect.fsti"
               (Prims.of_int (221)) (Prims.of_int (67)) (Prims.of_int (221))
               (Prims.of_int (73))))) (lift_div_tac (fun uu___ -> ()))
      (fun uu___ -> (fun uu___ -> Obj.magic (tau ())) uu___)
type ('a, 'b) tac = 'a -> ('b, unit) tac_repr
type 'a tactic = (unit, 'a) tac
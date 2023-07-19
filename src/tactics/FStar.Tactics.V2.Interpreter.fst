﻿(*
   Copyright 2008-2016 Microsoft Research

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*)

module FStar.Tactics.V2.Interpreter

open FStar
open FStar.Compiler
open FStar.Compiler.Effect
open FStar.Compiler.List
open FStar.Compiler.Range
open FStar.Compiler.Util
open FStar.Syntax.Syntax
open FStar.Syntax.Embeddings
open FStar.TypeChecker.Common
open FStar.TypeChecker.Env
open FStar.Tactics.Result
open FStar.Tactics.Types
open FStar.Tactics.Printing
open FStar.Tactics.Monad
open FStar.Tactics.V2.Basic
open FStar.Tactics.CtrlRewrite
open FStar.Tactics.V2.InterpFuns
open FStar.Tactics.Native
open FStar.Tactics.Common

module BU      = FStar.Compiler.Util
module Cfg     = FStar.TypeChecker.Cfg
module E       = FStar.Tactics.Embedding
module Env     = FStar.TypeChecker.Env
module Err     = FStar.Errors
module NBE     = FStar.TypeChecker.NBE
module NBET    = FStar.TypeChecker.NBETerm
module N       = FStar.TypeChecker.Normalize
module NRE     = FStar.Reflection.V2.NBEEmbeddings
module Print   = FStar.Syntax.Print
module RE      = FStar.Reflection.V2.Embeddings
module S       = FStar.Syntax.Syntax
module SS      = FStar.Syntax.Subst
module TcComm  = FStar.TypeChecker.Common
module TcRel   = FStar.TypeChecker.Rel
module TcTerm  = FStar.TypeChecker.TcTerm
module U       = FStar.Syntax.Util
module PC      = FStar.Parser.Const

let tacdbg = BU.mk_ref false

let unembed ea a norm_cb = unembed ea a norm_cb
let embed ea r x norm_cb = embed ea x r None norm_cb

let native_tactics_steps () =
  let step_from_native_step (s: native_primitive_step): Cfg.primitive_step =
    { Cfg.name                         = s.name
    ; Cfg.arity                        = s.arity
    ; Cfg.univ_arity                   = 0 // Zoe : We might need to change that
    ; Cfg.auto_reflect                 = Some (s.arity - 1)
    ; Cfg.strong_reduction_ok          = s.strong_reduction_ok
    ; Cfg.requires_binder_substitution = false // GM: Don't think we care about pretty-printing on native
    ; Cfg.interpretation               = (fun psc cb _us t -> s.tactic psc cb t)
    ; Cfg.interpretation_nbe           = fun _cb _us -> NBET.dummy_interp s.name
    }
  in
  List.map step_from_native_step (FStar.Tactics.Native.list_all ())

(* mk_total_step_1/mk_total_step_2 uses names in FStar.Tactics.Builtins, we override these few who
 * are in other modules: *)
let mk_total_step_1' uarity nm f ea er nf ena enr =
  { mk_total_step_1  uarity nm f ea er nf ena enr
    with Cfg.name = Ident.lid_of_str ("FStar.Tactics.Types." ^ nm) }

let mk_total_step_1'_psc uarity nm f ea er nf ena enr =
  { mk_total_step_1_psc  uarity nm f ea er nf ena enr
    with Cfg.name = Ident.lid_of_str ("FStar.Tactics.Types." ^ nm) }

let mk_total_step_2' uarity nm f ea eb er nf ena enb enr =
  { mk_total_step_2  uarity nm f ea eb er nf ena enb enr
    with Cfg.name = Ident.lid_of_str ("FStar.Tactics.Types." ^ nm) }

(* This reference keeps all of the tactic primitives. *)
let __primitive_steps_ref : ref (list Cfg.primitive_step) =
  BU.mk_ref []

let primitive_steps () : list Cfg.primitive_step =
    (!__primitive_steps_ref)
    @ (native_tactics_steps ())

let register_tactic_primitive_step (s : Cfg.primitive_step) : unit =
  __primitive_steps_ref := s :: !__primitive_steps_ref

(* This function attempts to reconstruct the reduction head of a
stuck tactic term, to provide a better error message for the user. *)
let rec t_head_of (t : term) : term =
    match (SS.compress t).n with
    | Tm_app _ ->
      (* If the head is a ctor, or an uninterpreted fv, do not shrink
         further. Otherwise we will get failures saying that 'Success'
         or 'dump' got stuck, which is not helpful. *)
      let h, args = U.head_and_args_full t in
      let h = U.unmeta h in
      begin match (SS.compress h).n with
      | Tm_uinst _
      | Tm_fvar _
      | Tm_bvar _ // should not occur
      | Tm_name _
      | Tm_constant _ -> t
      | _ -> t_head_of h
      end
    | Tm_match {scrutinee=t}
    | Tm_ascribed {tm=t}
    | Tm_meta {tm=t} -> t_head_of t
    | _ -> t

let unembed_tactic_0 (eb:embedding 'b) (embedded_tac_b:term) (ncb:norm_cb) : tac 'b =
    bind get (fun proof_state ->
    let rng = embedded_tac_b.pos in

    (* First, reify it from Tac a into __tac a *)
    let embedded_tac_b = U.mk_reify embedded_tac_b (Some PC.effect_TAC_lid) in

    let tm = S.mk_Tm_app embedded_tac_b
                         [S.as_arg (embed E.e_proofstate rng proof_state ncb)]
                          rng in


    // Why not HNF? While we don't care about strong reduction we need more than head
    // normal form due to primitive steps. Consider `norm (steps 2)`: we need to normalize
    // `steps 2` before caling norm, or it will fail to unembed the set of steps. Further,
    // at this moment at least, the normalizer will not call into any step of arity > 1.
    let steps = [Env.Weak;
                 Env.Reify;
                 Env.UnfoldUntil delta_constant; Env.UnfoldTac;
                 Env.Primops; Env.Unascribe] in

    // Maybe use NBE if the user asked for it
    let norm_f = if Options.tactics_nbe ()
                 then NBE.normalize
                 else N.normalize_with_primitive_steps
    in
    (* if proof_state.tac_verb_dbg then *)
    (*     BU.print1 "Starting normalizer with %s\n" (Print.term_to_string tm); *)
    let result = norm_f (primitive_steps ()) steps proof_state.main_context tm in
    (* if proof_state.tac_verb_dbg then *)
    (*     BU.print1 "Reduced tactic: got %s\n" (Print.term_to_string result); *)

    let res = unembed (E.e_result eb) result ncb in

    match res with
    | Some (Success (b, ps)) ->
        bind (set ps) (fun _ -> ret b)

    | Some (Failed (e, ps)) ->
        bind (set ps) (fun _ -> traise e)

    | None ->
        (* The tactic got stuck, try to provide a helpful error message. *)
        let h_result = t_head_of result in
        let maybe_admit_tip =
          (* (ab)use the map visitor to check whether the reduced head
          contains an admit, which is a common error *)
          let has_admit = BU.mk_ref false in
          let _ : term =
            Syntax.Visit.visit_term (fun t ->
              match t.n with
              | Tm_fvar fv when fv_eq_lid fv PC.admit_lid -> (has_admit := true; S.tun)
              | _ -> S.tun
            ) h_result
          in
          if !has_admit
          then "\nThe term contains an `admit`, which will not reduce. Did you mean `tadmit()`?"
          else ""
        in
        Err.raise_error (Err.Fatal_TacticGotStuck,
          (BU.format2 "Tactic got stuck!\n\
                       Reduction stopped at: %s%s" (Print.term_to_string h_result) maybe_admit_tip)) proof_state.main_context.range
    )

let unembed_tactic_nbe_0 (eb:NBET.embedding 'b) (cb:NBET.nbe_cbs) (embedded_tac_b:NBET.t) : tac 'b =
    bind get (fun proof_state ->

    (* Applying is normalizing!!! *)
    let result = NBET.iapp_cb cb embedded_tac_b [NBET.as_arg (NBET.embed E.e_proofstate_nbe cb proof_state)] in
    let res = NBET.unembed (E.e_result_nbe eb) cb result in

    match res with
    | Some (Success (b, ps)) ->
        bind (set ps) (fun _ -> ret b)

    | Some (Failed (e, ps)) ->
        bind (set ps) (fun _ -> traise e)

    | None ->
        Err.raise_error (Err.Fatal_TacticGotStuck, (BU.format1 "Tactic got stuck (in NBE)! Please file a bug report with a minimal reproduction of this issue.\n%s" (NBET.t_to_string result))) proof_state.main_context.range
    )

let unembed_tactic_1 (ea:embedding 'a) (er:embedding 'r) (f:term) (ncb:norm_cb) : 'a -> tac 'r =
    fun x ->
      let rng = FStar.Compiler.Range.dummyRange  in
      let x_tm = embed ea rng x ncb in
      let app = S.mk_Tm_app f [as_arg x_tm] rng in
      unembed_tactic_0 er app ncb

let unembed_tactic_nbe_1 (ea:NBET.embedding 'a) (er:NBET.embedding 'r) (cb:NBET.nbe_cbs) (f:NBET.t) : 'a -> tac 'r =
    fun x ->
      let x_tm = NBET.embed ea cb x in
      let app = NBET.iapp_cb cb f [NBET.as_arg x_tm] in
      unembed_tactic_nbe_0 er cb app

let e_tactic_thunk (er : embedding 'r) : embedding (tac 'r)
    =
    mk_emb (fun _ _ _ _ -> failwith "Impossible: embedding tactic (thunk)?")
           (fun t cb -> Some (unembed_tactic_1 e_unit er t cb ()))
           (FStar.Syntax.Embeddings.term_as_fv S.t_unit)

let e_tactic_nbe_thunk (er : NBET.embedding 'r) : NBET.embedding (tac 'r)
    =
    NBET.mk_emb
           (fun cb _ -> failwith "Impossible: NBE embedding tactic (thunk)?")
           (fun cb t -> Some (unembed_tactic_nbe_1 NBET.e_unit er cb t ()))
           (NBET.mk_t (NBET.Constant NBET.Unit))
           (emb_typ_of e_unit)

let e_tactic_1 (ea : embedding 'a) (er : embedding 'r) : embedding ('a -> tac 'r)
    =
    mk_emb (fun _ _ _ _ -> failwith "Impossible: embedding tactic (1)?")
           (fun t cb -> Some (unembed_tactic_1 ea er t cb))
           (FStar.Syntax.Embeddings.term_as_fv S.t_unit)

let e_tactic_nbe_1 (ea : NBET.embedding 'a) (er : NBET.embedding 'r) : NBET.embedding ('a -> tac 'r)
    =
    NBET.mk_emb
           (fun cb _ -> failwith "Impossible: NBE embedding tactic (1)?")
           (fun cb t -> Some (unembed_tactic_nbe_1 ea er cb t))
           (NBET.mk_t (NBET.Constant NBET.Unit))
           (emb_typ_of e_unit)

(* Takes a `sealed a`, but that's just a userspace abstraction. *)
let unseal (_typ:_) (x:'a) : tac 'a = ret x

let unseal_step =
  (* Unseal is not in builtins. *)
  let s =
    mk_tac_step_2 1 "unseal"
      unseal e_any      (e_sealed      e_any)      e_any
      unseal NBET.e_any (NBET.e_sealed NBET.e_any) NBET.e_any
  in
  { s with name = PC.unseal_lid }

(* Set the primitive steps ref *)
let () =
    (* NB: We need a PRECISE number for the universe arguments or NBE will
     * just go crazy. Most of the tactics work on ground types and thus have 0
     * universe arguments. Those polymorphic, usually take 1 universe per Type argument. *)

    (* Sigh, due to lack to expressive typing we need to duplicate a bunch of information here,
     * like which embeddings are needed for the arguments, but more annoyingly the underlying
     * implementation. Would be nice to have something better in the not-so-long run. *)
    List.iter register_tactic_primitive_step
    [ unseal_step;

      mk_tac_step_1 0 "compress"
        compress RE.e_term RE.e_term
        compress NRE.e_term NRE.e_term;

      mk_total_step_1'_psc 0 "tracepoint"
        tracepoint_with_psc E.e_proofstate e_bool
        tracepoint_with_psc E.e_proofstate_nbe NBET.e_bool;

      mk_total_step_2' 0 "set_proofstate_range"
        set_proofstate_range E.e_proofstate e_range E.e_proofstate
        set_proofstate_range E.e_proofstate_nbe NBET.e_range E.e_proofstate_nbe;

      mk_total_step_1' 0 "incr_depth"
        incr_depth E.e_proofstate E.e_proofstate
        incr_depth E.e_proofstate_nbe E.e_proofstate_nbe;

      mk_total_step_1' 0 "decr_depth"
        decr_depth E.e_proofstate E.e_proofstate
        decr_depth E.e_proofstate_nbe E.e_proofstate_nbe;

      mk_total_step_1' 0 "goals_of"
        goals_of E.e_proofstate (e_list E.e_goal)
        goals_of E.e_proofstate_nbe (NBET.e_list E.e_goal_nbe);

      mk_total_step_1' 0 "smt_goals_of"
        smt_goals_of E.e_proofstate (e_list E.e_goal)
        smt_goals_of E.e_proofstate_nbe (NBET.e_list E.e_goal_nbe);

      mk_total_step_1' 0 "goal_env"
        goal_env E.e_goal RE.e_env
        goal_env E.e_goal_nbe NRE.e_env;

      mk_total_step_1' 0 "goal_type"
        goal_type E.e_goal RE.e_term
        goal_type E.e_goal_nbe NRE.e_term;

      mk_total_step_1' 0 "goal_witness"
        goal_witness E.e_goal RE.e_term
        goal_witness E.e_goal_nbe NRE.e_term;

      mk_total_step_1' 0 "is_guard"
        is_guard E.e_goal e_bool
        is_guard E.e_goal_nbe NBET.e_bool;

      mk_total_step_1' 0 "get_label"
        get_label E.e_goal e_string
        get_label E.e_goal_nbe NBET.e_string;

      mk_total_step_2' 0 "set_label"
        set_label e_string E.e_goal E.e_goal
        set_label NBET.e_string E.e_goal_nbe E.e_goal_nbe;

      mk_tac_step_1 0 "set_goals"
        set_goals (e_list E.e_goal) e_unit
        set_goals (NBET.e_list E.e_goal_nbe) (NBET.e_unit);

      mk_tac_step_1 0 "set_smt_goals"
        set_smt_goals (e_list E.e_goal) e_unit
        set_smt_goals (NBET.e_list E.e_goal_nbe) (NBET.e_unit);

      mk_tac_step_2 1 "catch"
        (fun _ -> catch) e_any (e_tactic_thunk e_any) (e_either E.e_exn e_any)
        (fun _ -> catch) NBET.e_any (e_tactic_nbe_thunk NBET.e_any) (NBET.e_either E.e_exn_nbe NBET.e_any);

      mk_tac_step_2 1 "recover"
        (fun _ -> recover) e_any (e_tactic_thunk e_any) (e_either E.e_exn e_any)
        (fun _ -> recover) NBET.e_any (e_tactic_nbe_thunk NBET.e_any) (NBET.e_either E.e_exn_nbe NBET.e_any);

      mk_tac_step_1 0 "intro"
        intro e_unit RE.e_binding
        intro NBET.e_unit NRE.e_binding;

      mk_tac_step_1 0 "intro_rec"
        intro_rec e_unit (e_tuple2 RE.e_binding RE.e_binding)
        intro_rec NBET.e_unit (NBET.e_tuple2 NRE.e_binding NRE.e_binding);

      mk_tac_step_1 0 "norm"
        norm (e_list e_norm_step) e_unit
        norm (NBET.e_list NBET.e_norm_step) NBET.e_unit;

      mk_tac_step_3 0 "norm_term_env"
        norm_term_env RE.e_env (e_list e_norm_step) RE.e_term RE.e_term
        norm_term_env NRE.e_env (NBET.e_list NBET.e_norm_step) NRE.e_term NRE.e_term;

      mk_tac_step_2 0 "norm_binding_type"
        norm_binding_type (e_list e_norm_step) RE.e_binding e_unit
        norm_binding_type (NBET.e_list NBET.e_norm_step) NRE.e_binding NBET.e_unit;

      mk_tac_step_2 0 "rename_to"
        rename_to RE.e_binding e_string RE.e_binding
        rename_to NRE.e_binding NBET.e_string NRE.e_binding;

      mk_tac_step_1 0 "var_retype"
        var_retype RE.e_binding e_unit
        var_retype NRE.e_binding NBET.e_unit;

      mk_tac_step_1 0 "revert"
        revert e_unit e_unit
        revert NBET.e_unit NBET.e_unit;

      mk_tac_step_1 0 "clear_top"
        clear_top e_unit e_unit
        clear_top NBET.e_unit NBET.e_unit;

      mk_tac_step_1 0 "clear"
        clear RE.e_binding e_unit
        clear NRE.e_binding NBET.e_unit;

      mk_tac_step_1 0 "rewrite"
        rewrite RE.e_binding e_unit
        rewrite NRE.e_binding NBET.e_unit;

      mk_tac_step_1 0 "refine_intro"
        refine_intro e_unit e_unit
        refine_intro NBET.e_unit NBET.e_unit;

      mk_tac_step_3 0 "t_exact"
        t_exact e_bool e_bool RE.e_term e_unit
        t_exact NBET.e_bool NBET.e_bool NRE.e_term NBET.e_unit;

      mk_tac_step_4 0 "t_apply"
        t_apply e_bool e_bool e_bool RE.e_term e_unit
        t_apply NBET.e_bool NBET.e_bool NBET.e_bool NRE.e_term NBET.e_unit;

      mk_tac_step_3 0 "t_apply_lemma"
        t_apply_lemma e_bool e_bool RE.e_term e_unit
        t_apply_lemma NBET.e_bool NBET.e_bool NRE.e_term NBET.e_unit;

      mk_tac_step_1 0 "set_options"
        set_options e_string e_unit
        set_options NBET.e_string NBET.e_unit;

      mk_tac_step_2 0 "tcc"
        tcc RE.e_env RE.e_term RE.e_comp
        tcc NRE.e_env NRE.e_term NRE.e_comp;

      mk_tac_step_2 0 "tc"
        tc RE.e_env RE.e_term RE.e_term
        tc NRE.e_env NRE.e_term NRE.e_term;

      mk_tac_step_1 0 "unshelve"
        unshelve RE.e_term e_unit
        unshelve NRE.e_term NBET.e_unit;

      mk_tac_step_2 1 "unquote"
        unquote e_any RE.e_term e_any
        (fun _ _ -> failwith "NBE unquote") NBET.e_any NRE.e_term NBET.e_any;

      mk_tac_step_1 0 "prune"
        prune e_string e_unit
        prune NBET.e_string NBET.e_unit;

      mk_tac_step_1 0 "addns"
        addns e_string e_unit
        addns NBET.e_string NBET.e_unit;

      mk_tac_step_1 0 "print"
        print e_string e_unit
        print NBET.e_string NBET.e_unit;

      mk_tac_step_1 0 "debugging"
        debugging e_unit e_bool
        debugging NBET.e_unit NBET.e_bool;

      mk_tac_step_1 0 "dump"
        dump e_string e_unit
        dump NBET.e_string NBET.e_unit;

      mk_tac_step_2 0 "dump_all"
        dump_all e_bool      e_string      e_unit
        dump_all NBET.e_bool NBET.e_string NBET.e_unit;

      mk_tac_step_2 0 "dump_uvars_of"
        dump_uvars_of E.e_goal      e_string      e_unit
        dump_uvars_of E.e_goal_nbe NBET.e_string NBET.e_unit;

      mk_tac_step_3 0 "ctrl_rewrite"
        ctrl_rewrite E.e_direction (e_tactic_1 RE.e_term (e_tuple2 e_bool E.e_ctrl_flag))
                                   (e_tactic_thunk e_unit)
                                   e_unit
        ctrl_rewrite E.e_direction_nbe (e_tactic_nbe_1 NRE.e_term (NBET.e_tuple2 NBET.e_bool E.e_ctrl_flag_nbe))
                                       (e_tactic_nbe_thunk NBET.e_unit)
                                        NBET.e_unit;

      mk_tac_step_1 0 "t_trefl"
        t_trefl   e_bool e_unit
        t_trefl   NBET.e_bool NBET.e_unit;

      mk_tac_step_1 0 "dup"
        dup     e_unit e_unit
        dup     NBET.e_unit NBET.e_unit;

      mk_tac_step_1 0 "tadmit_t"
        tadmit_t  RE.e_term e_unit
        tadmit_t  NRE.e_term NBET.e_unit;

      mk_tac_step_1 0 "join"
        join  e_unit e_unit
        join  NBET.e_unit NBET.e_unit;

      mk_tac_step_1 0 "t_destruct"
        t_destruct RE.e_term (e_list (e_tuple2 RE.e_fv e_int))
        t_destruct NRE.e_term (NBET.e_list (NBET.e_tuple2 NRE.e_fv NBET.e_int));

      mk_tac_step_1 0 "top_env"
        top_env     e_unit RE.e_env
        top_env     NBET.e_unit NRE.e_env;

      mk_tac_step_1 0 "binder_bv"
        binder_bv RE.e_binder RE.e_bv
        binder_bv NRE.e_binder NRE.e_bv;

      mk_tac_step_1 0 "fresh"
        fresh       e_unit e_int
        fresh       NBET.e_unit NBET.e_int;

      mk_tac_step_1 0 "curms"
        curms       e_unit e_int
        curms       NBET.e_unit NBET.e_int;

      mk_tac_step_2 0 "uvar_env"
        uvar_env RE.e_env (e_option RE.e_term) RE.e_term
        uvar_env NRE.e_env (NBET.e_option NRE.e_term) NRE.e_term;

      mk_tac_step_2 0 "ghost_uvar_env"
        ghost_uvar_env RE.e_env  RE.e_term  RE.e_term
        ghost_uvar_env NRE.e_env NRE.e_term NRE.e_term;

      mk_tac_step_1 0 "fresh_universe_uvar"
        fresh_universe_uvar e_unit RE.e_term
        fresh_universe_uvar NBET.e_unit NRE.e_term;

      mk_tac_step_3 0 "unify_env"
        unify_env RE.e_env RE.e_term RE.e_term e_bool
        unify_env NRE.e_env NRE.e_term NRE.e_term NBET.e_bool;

      mk_tac_step_3 0 "unify_guard_env"
        unify_guard_env RE.e_env RE.e_term RE.e_term e_bool
        unify_guard_env NRE.e_env NRE.e_term NRE.e_term NBET.e_bool;

      mk_tac_step_3 0 "match_env"
        match_env RE.e_env RE.e_term RE.e_term e_bool
        match_env NRE.e_env NRE.e_term NRE.e_term NBET.e_bool;

      mk_tac_step_3 0 "launch_process"
        launch_process e_string (e_list e_string) e_string e_string
        launch_process NBET.e_string (NBET.e_list NBET.e_string) NBET.e_string NBET.e_string;

      mk_tac_step_1 0 "fresh_bv_named"
        fresh_bv_named e_string RE.e_bv
        fresh_bv_named NBET.e_string NRE.e_bv;

      mk_tac_step_1 0 "change"
        change RE.e_term e_unit
        change NRE.e_term NBET.e_unit;

      mk_tac_step_1 0 "get_guard_policy"
        get_guard_policy e_unit E.e_guard_policy
        get_guard_policy NBET.e_unit E.e_guard_policy_nbe;

      mk_tac_step_1 0 "set_guard_policy"
        set_guard_policy E.e_guard_policy e_unit
        set_guard_policy E.e_guard_policy_nbe NBET.e_unit;

      mk_tac_step_1 0 "lax_on"
        lax_on e_unit e_bool
        lax_on NBET.e_unit NBET.e_bool;

      mk_tac_step_2 1 "lget"
        lget e_any e_string e_any
        (fun _ _ -> fail "sorry, `lget` does not work in NBE") NBET.e_any NBET.e_string NBET.e_any;

      mk_tac_step_3 1 "lset"
        lset e_any e_string e_any e_unit
        (fun _ _ _ -> fail "sorry, `lset` does not work in NBE") NBET.e_any NBET.e_string NBET.e_any NBET.e_unit;

      mk_tac_step_1 1 "set_urgency"
        set_urgency e_int e_unit
        set_urgency NBET.e_int NBET.e_unit;

      mk_tac_step_1 1 "t_commute_applied_match"
        t_commute_applied_match e_unit e_unit
        t_commute_applied_match NBET.e_unit NBET.e_unit;

      mk_tac_step_1 0 "gather_or_solve_explicit_guards_for_resolved_goals"
        gather_explicit_guards_for_resolved_goals e_unit e_unit
        gather_explicit_guards_for_resolved_goals NBET.e_unit NBET.e_unit;

      mk_tac_step_2 0 "string_to_term"
        string_to_term RE.e_env e_string RE.e_term
        string_to_term NRE.e_env NBET.e_string NRE.e_term;

      mk_tac_step_2 0 "push_bv_dsenv"
        push_bv_dsenv RE.e_env e_string (e_tuple2 RE.e_env RE.e_binding)
        push_bv_dsenv NRE.e_env NBET.e_string (NBET.e_tuple2 NRE.e_env NRE.e_binding);

      mk_tac_step_1 0 "term_to_string"
        term_to_string RE.e_term e_string
        term_to_string NRE.e_term NBET.e_string;

      mk_tac_step_1 0 "comp_to_string"
        comp_to_string RE.e_comp e_string
        comp_to_string NRE.e_comp NBET.e_string;

      mk_tac_step_1 0 "range_to_string"
        range_to_string FStar.Syntax.Embeddings.e_range e_string
        range_to_string FStar.TypeChecker.NBETerm.e_range NBET.e_string;

      mk_tac_step_2 0 "term_eq_old"
        term_eq_old RE.e_term RE.e_term e_bool
        term_eq_old NRE.e_term NRE.e_term NBET.e_bool;

      mk_tac_step_3 1 "with_compat_pre_core"
        (fun _ -> with_compat_pre_core) e_any e_int (e_tactic_thunk e_any) e_any
        (fun _ -> with_compat_pre_core) NBET.e_any NBET.e_int (e_tactic_nbe_thunk NBET.e_any) NBET.e_any;

      mk_tac_step_1 0 "get_vconfig"
        get_vconfig e_unit e_vconfig
        get_vconfig NBET.e_unit NBET.e_vconfig;

      mk_tac_step_1 0 "set_vconfig"
        set_vconfig e_vconfig e_unit
        set_vconfig NBET.e_vconfig NBET.e_unit;

      mk_tac_step_1 0 "t_smt_sync"
        t_smt_sync e_vconfig e_unit
        t_smt_sync NBET.e_vconfig NBET.e_unit;

      mk_tac_step_1 0 "free_uvars"
        free_uvars RE.e_term (e_list e_int)
        free_uvars NRE.e_term (NBET.e_list NBET.e_int);

      // reflection typechecker callbacks (part of the DSL framework)

      mk_tac_step_3 0 "check_subtyping"
        refl_check_subtyping RE.e_env RE.e_term RE.e_term (e_tuple2 (e_option e_unit) (e_list e_issue))
        refl_check_subtyping NRE.e_env NRE.e_term NRE.e_term NBET.(e_tuple2 (e_option e_unit) (e_list e_issue));

      mk_tac_step_3 0 "check_equiv"
        refl_check_equiv RE.e_env RE.e_term RE.e_term (e_tuple2 (e_option e_unit) (e_list e_issue))
        refl_check_equiv NRE.e_env NRE.e_term NRE.e_term NBET.(e_tuple2 (e_option e_unit) (e_list e_issue));

      mk_tac_step_3 0 "core_compute_term_type"
        refl_core_compute_term_type RE.e_env RE.e_term E.e_tot_or_ghost (e_tuple2 (e_option RE.e_term) (e_list e_issue))
        refl_core_compute_term_type NRE.e_env NRE.e_term E.e_tot_or_ghost_nbe NBET.(e_tuple2 (e_option NRE.e_term) (e_list e_issue));

      mk_tac_step_4 0 "core_check_term"
        refl_core_check_term RE.e_env RE.e_term RE.e_term E.e_tot_or_ghost (e_tuple2 (e_option e_unit) (e_list e_issue))
        refl_core_check_term NRE.e_env NRE.e_term NRE.e_term E.e_tot_or_ghost_nbe NBET.(e_tuple2 (e_option e_unit) (e_list e_issue));

      mk_tac_step_3 0 "tc_term"
        refl_tc_term RE.e_env RE.e_term E.e_tot_or_ghost (e_tuple2 (e_option (e_tuple2 RE.e_term RE.e_term)) (e_list e_issue))
        refl_tc_term NRE.e_env NRE.e_term E.e_tot_or_ghost_nbe NBET.(e_tuple2 (e_option (e_tuple2 NRE.e_term NRE.e_term)) (e_list e_issue));

      mk_tac_step_2 0 "universe_of"
        refl_universe_of RE.e_env RE.e_term (e_tuple2 (e_option RE.e_universe) (e_list e_issue))
        refl_universe_of NRE.e_env NRE.e_term NBET.(e_tuple2 (e_option NRE.e_universe) (e_list e_issue));

      mk_tac_step_2 0 "check_prop_validity"
        refl_check_prop_validity RE.e_env RE.e_term (e_tuple2 (e_option e_unit) (e_list e_issue))
        refl_check_prop_validity NRE.e_env NRE.e_term NBET.(e_tuple2 (NBET.e_option NBET.e_unit) (e_list e_issue));

      mk_tac_step_4 0 "check_match_complete"
        refl_check_match_complete RE.e_env RE.e_term RE.e_term (e_list RE.e_pattern)
                (e_option (e_tuple2 (e_list RE.e_pattern) (e_list (e_list RE.e_binding))))
        refl_check_match_complete NRE.e_env NRE.e_term NRE.e_term (NBET.e_list NRE.e_pattern)
                (NBET.e_option (NBET.e_tuple2 (NBET.e_list NRE.e_pattern) (NBET.e_list (NBET.e_list NRE.e_binding))))
        ;

      mk_tac_step_2 0 "instantiate_implicits"
        refl_instantiate_implicits RE.e_env RE.e_term (e_tuple2 (e_option (e_tuple2 RE.e_term RE.e_term)) (e_list e_issue))
        refl_instantiate_implicits NRE.e_env NRE.e_term NBET.(e_tuple2 (e_option (NBET.e_tuple2 NRE.e_term NRE.e_term)) (e_list e_issue));

      mk_tac_step_3 0 "maybe_relate_after_unfolding"
        refl_maybe_relate_after_unfolding RE.e_env RE.e_term RE.e_term (e_tuple2 (e_option E.e_unfold_side) (e_list e_issue))
        refl_maybe_relate_after_unfolding NRE.e_env NRE.e_term NRE.e_term NBET.(e_tuple2 (e_option E.e_unfold_side_nbe) (e_list e_issue));

      mk_tac_step_2 0 "maybe_unfold_head"
        refl_maybe_unfold_head RE.e_env RE.e_term (e_tuple2 (e_option RE.e_term) (e_list e_issue))
        refl_maybe_unfold_head NRE.e_env NRE.e_term NBET.(e_tuple2 (e_option NRE.e_term) (e_list e_issue));

      mk_tac_step_2 0 "push_open_namespace"
        push_open_namespace RE.e_env (e_list e_string) RE.e_env
        push_open_namespace NRE.e_env (NBET.e_list NBET.e_string) NRE.e_env;

      mk_tac_step_3 0 "push_module_abbrev"
        push_module_abbrev RE.e_env e_string (e_list e_string) RE.e_env
        push_module_abbrev NRE.e_env NBET.e_string (NBET.e_list NBET.e_string) NRE.e_env;

      mk_tac_step_2 0 "resolve_name"
        resolve_name RE.e_env (e_list e_string) (e_option (e_either RE.e_bv RE.e_fv))
        resolve_name NRE.e_env (NBET.e_list NBET.e_string) (NBET.e_option (NBET.e_either NRE.e_bv NRE.e_fv));

      mk_tac_step_1 0 "log_issues"
        (fun is -> ret (FStar.Errors.add_issues is)) (e_list e_issue) e_unit
        (fun is -> ret (FStar.Errors.add_issues is)) NBET.(e_list e_issue) NBET.e_unit;
    ]

let unembed_tactic_1_alt (ea:embedding 'a) (er:embedding 'r) (f:term) (ncb:norm_cb) : option ('a -> tac 'r) =
    Some (fun x ->
      let rng = FStar.Compiler.Range.dummyRange  in
      let x_tm = embed ea rng x ncb in
      let app = S.mk_Tm_app f [as_arg x_tm] rng in
      unembed_tactic_0 er app ncb)

let e_tactic_1_alt (ea: embedding 'a) (er:embedding 'r): embedding ('a -> (proofstate -> __result 'r)) =
    let em = (fun _ _ _ _ -> failwith "Impossible: embedding tactic (1)?") in
    let un (t0: term) (n: norm_cb): option ('a -> (proofstate -> __result 'r)) =
        match unembed_tactic_1_alt ea er t0 n with
        | Some f -> Some (fun x -> run (f x))
        | None -> None
    in
    mk_emb em un (FStar.Syntax.Embeddings.term_as_fv t_unit)

let report_implicits rng (is : TcRel.tagged_implicits) : unit =
  is |> List.iter
    (fun (imp, tag) ->
      match tag with
      | TcRel.Implicit_unresolved
      | TcRel.Implicit_checking_defers_univ_constraint ->
        Errors.log_issue rng
                (Err.Error_UninstantiatedUnificationVarInTactic,
                 BU.format3 ("Tactic left uninstantiated unification variable %s of type %s (reason = \"%s\")")
                             (Print.uvar_to_string imp.imp_uvar.ctx_uvar_head)
                             (Print.term_to_string (U.ctx_uvar_typ imp.imp_uvar))
                             imp.imp_reason)
      | TcRel.Implicit_has_typing_guard (tm, ty) ->
        Errors.log_issue rng
                (Err.Error_UninstantiatedUnificationVarInTactic,
                 BU.format4 ("Tactic solved goal %s of type %s to %s : %s, but it has a non-trivial typing guard. Use gather_or_solve_explicit_guards_for_resolved_goals to inspect and prove these goals")
                             (Print.uvar_to_string imp.imp_uvar.ctx_uvar_head)
                             (Print.term_to_string (U.ctx_uvar_typ imp.imp_uvar))
                             (Print.term_to_string tm)
                             (Print.term_to_string ty)));
  Err.stop_if_err ()

let run_tactic_on_ps'
  (rng_call : Range.range)
  (rng_goal : Range.range)
  (background : bool)
  (e_arg : embedding 'a)
  (arg : 'a)
  (e_res : embedding 'b)
  (tactic:term)
  (tactic_already_typed:bool)
  (ps:proofstate)
  : list goal // remaining goals
  * 'b // return value
  =
    let ps = { ps with main_context = { ps.main_context with intactics = true } } in
    let env = ps.main_context in
    if !tacdbg then
        BU.print2 "Typechecking tactic: (%s) (already_typed: %s) {\n"
          (Print.term_to_string tactic)
          (string_of_bool tactic_already_typed);

    (* Do NOT use the returned tactic, the typechecker is not idempotent and
     * will mess up the monadic lifts. We're just making sure it's well-typed
     * so it won't get stuck. c.f #1307 *)
    let g =
      if tactic_already_typed
      then Env.trivial_guard
      else let _, _, g = TcTerm.tc_tactic (type_of e_arg) (type_of e_res) env tactic in
           g in

    if !tacdbg then
        BU.print_string "}\n";

    TcRel.force_trivial_guard env g;
    Err.stop_if_err ();
    let tau = unembed_tactic_1 e_arg e_res tactic FStar.Syntax.Embeddings.id_norm_cb in

    (* if !tacdbg then *)
    (*     BU.print1 "Running tactic with goal = (%s) {\n" (Print.term_to_string typ); *)
    let res =
      Profiling.profile
        (fun () -> run_safe (tau arg) ps)
        (Some (Ident.string_of_lid (Env.current_module ps.main_context)))
        "FStar.Tactics.Interpreter.run_safe"
    in
    if !tacdbg then
        BU.print_string "}\n";

    match res with
    | Success (ret, ps) ->
        (* if !tacdbg || Options.tactics_info () then *)
        (*     BU.print1 "Tactic generated proofterm %s\n" (Print.term_to_string w); *)
        let remaining_smt_goals = ps.goals@ps.smt_goals in
        List.iter
          (fun g ->
            FStar.Tactics.V2.Basic.mark_goal_implicit_already_checked g;//all of these will be fed to SMT anyway
            if is_irrelevant g
            then (
              if !tacdbg then BU.print1 "Assigning irrelevant goal %s\n" (Print.term_to_string (goal_witness g));
              if TcRel.teq_nosmt_force (goal_env g) (goal_witness g) U.exp_unit
              then ()
              else failwith (BU.format1 "Irrelevant tactic witness does not unify with (): %s"
                                                           (Print.term_to_string (goal_witness g)))
            ))
          remaining_smt_goals;

        // Check that all implicits were instantiated
        if !tacdbg then
            BU.print1 "About to check tactic implicits: %s\n" (FStar.Common.string_of_list
                                                                    (fun imp -> Print.ctx_uvar_to_string imp.imp_uvar)
                                                                    ps.all_implicits);

        let g = {Env.trivial_guard with TcComm.implicits=ps.all_implicits} in
        let g = TcRel.solve_deferred_constraints env g in
        if !tacdbg then
            BU.print2 "Checked %s implicits (1): %s\n"
                        (string_of_int (List.length ps.all_implicits))
                        (FStar.Common.string_of_list
                                (fun imp -> Print.ctx_uvar_to_string imp.imp_uvar)
                                ps.all_implicits);
        let tagged_implicits = TcRel.resolve_implicits_tac env g in
        if !tacdbg then
            BU.print2 "Checked %s implicits (2): %s\n"
                        (string_of_int (List.length ps.all_implicits))
                        (FStar.Common.string_of_list
                                (fun imp -> Print.ctx_uvar_to_string imp.imp_uvar)
                                ps.all_implicits);
        report_implicits rng_goal tagged_implicits;
        // /implicits

        if !tacdbg then
            do_dump_proofstate ps "at the finish line";
        (ps.goals@ps.smt_goals, ret)

    | Failed (e, ps) ->
        do_dump_proofstate ps "at the time of failure";
        let texn_to_string e =
            match e with
            | TacticFailure s ->
                s
            | EExn t ->
                "uncaught exception: " ^ (Print.term_to_string t)
            | e ->
                raise e
        in
        let rng =
          if background
          then match ps.goals with
               | g::_ -> g.goal_ctx_uvar.ctx_uvar_range
               | _ -> rng_call
          else ps.entry_range
        in
        Err.raise_error (Err.Fatal_UserTacticFailure,
                            BU.format1 "user tactic failed: `%s`" (texn_to_string e))
                          rng

let run_tactic_on_ps
          (rng_call : Range.range)
          (rng_goal : Range.range)
          (background : bool)
          (e_arg : embedding 'a)
          (arg : 'a)
          (e_res : embedding 'b)
          (tactic:term)
          (tactic_already_typed:bool)
          (ps:proofstate) =
    Profiling.profile
      (fun () -> run_tactic_on_ps' rng_call rng_goal background e_arg arg e_res tactic tactic_already_typed ps)
      (Some (Ident.string_of_lid (Env.current_module ps.main_context)))
      "FStar.Tactics.Interpreter.run_tactic_on_ps"

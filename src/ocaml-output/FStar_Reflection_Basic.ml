open Prims
let (env_hook :
  FStar_TypeChecker_Env.env FStar_Pervasives_Native.option FStar_ST.ref) =
  FStar_Util.mk_ref FStar_Pervasives_Native.None 
let (inspect_aqual :
  FStar_Syntax_Syntax.aqual -> FStar_Reflection_Data.aqualv) =
  fun aq  ->
    match aq with
    | FStar_Pervasives_Native.Some (FStar_Syntax_Syntax.Implicit uu____12) ->
        FStar_Reflection_Data.Q_Implicit
    | FStar_Pervasives_Native.Some (FStar_Syntax_Syntax.Meta t) ->
        FStar_Reflection_Data.Q_Meta t
    | FStar_Pervasives_Native.Some (FStar_Syntax_Syntax.Equality ) ->
        FStar_Reflection_Data.Q_Explicit
    | FStar_Pervasives_Native.None  -> FStar_Reflection_Data.Q_Explicit
  
let (pack_aqual : FStar_Reflection_Data.aqualv -> FStar_Syntax_Syntax.aqual)
  =
  fun aqv  ->
    match aqv with
    | FStar_Reflection_Data.Q_Explicit  -> FStar_Pervasives_Native.None
    | FStar_Reflection_Data.Q_Implicit  ->
        FStar_Pervasives_Native.Some (FStar_Syntax_Syntax.Implicit false)
    | FStar_Reflection_Data.Q_Meta t ->
        FStar_Pervasives_Native.Some (FStar_Syntax_Syntax.Meta t)
  
let (inspect_fv : FStar_Syntax_Syntax.fv -> Prims.string Prims.list) =
  fun fv  ->
    let uu____37 = FStar_Syntax_Syntax.lid_of_fv fv  in
    FStar_Ident.path_of_lid uu____37
  
let (pack_fv : Prims.string Prims.list -> FStar_Syntax_Syntax.fv) =
  fun ns  ->
    let lid = FStar_Parser_Const.p2l ns  in
    let fallback uu____56 =
      let quals =
        let uu____60 = FStar_Ident.lid_equals lid FStar_Parser_Const.cons_lid
           in
        if uu____60
        then FStar_Pervasives_Native.Some FStar_Syntax_Syntax.Data_ctor
        else
          (let uu____67 =
             FStar_Ident.lid_equals lid FStar_Parser_Const.nil_lid  in
           if uu____67
           then FStar_Pervasives_Native.Some FStar_Syntax_Syntax.Data_ctor
           else
             (let uu____74 =
                FStar_Ident.lid_equals lid FStar_Parser_Const.some_lid  in
              if uu____74
              then FStar_Pervasives_Native.Some FStar_Syntax_Syntax.Data_ctor
              else
                (let uu____81 =
                   FStar_Ident.lid_equals lid FStar_Parser_Const.none_lid  in
                 if uu____81
                 then
                   FStar_Pervasives_Native.Some FStar_Syntax_Syntax.Data_ctor
                 else FStar_Pervasives_Native.None)))
         in
      let uu____88 = FStar_Parser_Const.p2l ns  in
      FStar_Syntax_Syntax.lid_as_fv uu____88
        (FStar_Syntax_Syntax.Delta_constant_at_level (Prims.of_int (999)))
        quals
       in
    let uu____90 = FStar_ST.op_Bang env_hook  in
    match uu____90 with
    | FStar_Pervasives_Native.None  -> fallback ()
    | FStar_Pervasives_Native.Some env ->
        let qninfo = FStar_TypeChecker_Env.lookup_qname env lid  in
        (match qninfo with
         | FStar_Pervasives_Native.Some (FStar_Util.Inr (se,_us),_rng) ->
             let quals = FStar_Syntax_DsEnv.fv_qual_of_se se  in
             let uu____170 = FStar_Parser_Const.p2l ns  in
             FStar_Syntax_Syntax.lid_as_fv uu____170
               (FStar_Syntax_Syntax.Delta_constant_at_level
                  (Prims.of_int (999))) quals
         | uu____172 -> fallback ())
  
let rec last : 'a . 'a Prims.list -> 'a =
  fun l  ->
    match l with
    | [] -> failwith "last: empty list"
    | x::[] -> x
    | uu____191::xs -> last xs
  
let rec init : 'a . 'a Prims.list -> 'a Prims.list =
  fun l  ->
    match l with
    | [] -> failwith "init: empty list"
    | x::[] -> []
    | x::xs -> let uu____221 = init xs  in x :: uu____221
  
let (inspect_const :
  FStar_Syntax_Syntax.sconst -> FStar_Reflection_Data.vconst) =
  fun c  ->
    match c with
    | FStar_Const.Const_unit  -> FStar_Reflection_Data.C_Unit
    | FStar_Const.Const_int (s,uu____231) ->
        let uu____246 = FStar_BigInt.big_int_of_string s  in
        FStar_Reflection_Data.C_Int uu____246
    | FStar_Const.Const_bool (true ) -> FStar_Reflection_Data.C_True
    | FStar_Const.Const_bool (false ) -> FStar_Reflection_Data.C_False
    | FStar_Const.Const_string (s,uu____250) ->
        FStar_Reflection_Data.C_String s
    | FStar_Const.Const_range r -> FStar_Reflection_Data.C_Range r
    | FStar_Const.Const_reify  -> FStar_Reflection_Data.C_Reify
    | FStar_Const.Const_reflect l ->
        let uu____255 = FStar_Ident.path_of_lid l  in
        FStar_Reflection_Data.C_Reflect uu____255
    | uu____256 ->
        let uu____257 =
          let uu____259 = FStar_Syntax_Print.const_to_string c  in
          FStar_Util.format1 "unknown constant: %s" uu____259  in
        failwith uu____257
  
let rec (inspect_ln :
  FStar_Syntax_Syntax.term -> FStar_Reflection_Data.term_view) =
  fun t  ->
    let t1 = FStar_Syntax_Util.unascribe t  in
    let t2 = FStar_Syntax_Util.un_uinst t1  in
    let t3 = FStar_Syntax_Util.unlazy_emb t2  in
    match t3.FStar_Syntax_Syntax.n with
    | FStar_Syntax_Syntax.Tm_meta (t4,uu____272) -> inspect_ln t4
    | FStar_Syntax_Syntax.Tm_name bv -> FStar_Reflection_Data.Tv_Var bv
    | FStar_Syntax_Syntax.Tm_bvar bv -> FStar_Reflection_Data.Tv_BVar bv
    | FStar_Syntax_Syntax.Tm_fvar fv -> FStar_Reflection_Data.Tv_FVar fv
    | FStar_Syntax_Syntax.Tm_app (hd1,[]) ->
        failwith "inspect_ln: empty arguments on Tm_app"
    | FStar_Syntax_Syntax.Tm_app (hd1,args) ->
        let uu____330 = last args  in
        (match uu____330 with
         | (a,q) ->
             let q' = inspect_aqual q  in
             let uu____358 =
               let uu____363 =
                 let uu____364 =
                   let uu____369 = init args  in
                   FStar_Syntax_Syntax.mk_Tm_app hd1 uu____369  in
                 uu____364 FStar_Pervasives_Native.None
                   t3.FStar_Syntax_Syntax.pos
                  in
               (uu____363, (a, q'))  in
             FStar_Reflection_Data.Tv_App uu____358)
    | FStar_Syntax_Syntax.Tm_abs ([],uu____378,uu____379) ->
        failwith "inspect_ln: empty arguments on Tm_abs"
    | FStar_Syntax_Syntax.Tm_abs (b::bs,t4,k) ->
        let body =
          match bs with
          | [] -> t4
          | bs1 ->
              FStar_Syntax_Syntax.mk
                (FStar_Syntax_Syntax.Tm_abs (bs1, t4, k))
                FStar_Pervasives_Native.None t4.FStar_Syntax_Syntax.pos
           in
        FStar_Reflection_Data.Tv_Abs (b, body)
    | FStar_Syntax_Syntax.Tm_type uu____471 ->
        FStar_Reflection_Data.Tv_Type ()
    | FStar_Syntax_Syntax.Tm_arrow ([],k) ->
        failwith "inspect_ln: empty binders on arrow"
    | FStar_Syntax_Syntax.Tm_arrow uu____492 ->
        let uu____507 = FStar_Syntax_Util.arrow_one t3  in
        (match uu____507 with
         | FStar_Pervasives_Native.Some (b,c) ->
             FStar_Reflection_Data.Tv_Arrow (b, c)
         | FStar_Pervasives_Native.None  -> failwith "impossible")
    | FStar_Syntax_Syntax.Tm_refine (bv,t4) ->
        FStar_Reflection_Data.Tv_Refine (bv, t4)
    | FStar_Syntax_Syntax.Tm_constant c ->
        let uu____532 = inspect_const c  in
        FStar_Reflection_Data.Tv_Const uu____532
    | FStar_Syntax_Syntax.Tm_uvar (ctx_u,s) ->
        let uu____551 =
          let uu____556 =
            let uu____557 =
              FStar_Syntax_Unionfind.uvar_id
                ctx_u.FStar_Syntax_Syntax.ctx_uvar_head
               in
            FStar_BigInt.of_int_fs uu____557  in
          (uu____556, (ctx_u, s))  in
        FStar_Reflection_Data.Tv_Uvar uu____551
    | FStar_Syntax_Syntax.Tm_let ((false ,lb::[]),t21) ->
        if lb.FStar_Syntax_Syntax.lbunivs <> []
        then FStar_Reflection_Data.Tv_Unknown
        else
          (match lb.FStar_Syntax_Syntax.lbname with
           | FStar_Util.Inr uu____589 -> FStar_Reflection_Data.Tv_Unknown
           | FStar_Util.Inl bv ->
               FStar_Reflection_Data.Tv_Let
                 (false, bv, (lb.FStar_Syntax_Syntax.lbdef), t21))
    | FStar_Syntax_Syntax.Tm_let ((true ,lb::[]),t21) ->
        if lb.FStar_Syntax_Syntax.lbunivs <> []
        then FStar_Reflection_Data.Tv_Unknown
        else
          (match lb.FStar_Syntax_Syntax.lbname with
           | FStar_Util.Inr uu____615 -> FStar_Reflection_Data.Tv_Unknown
           | FStar_Util.Inl bv ->
               FStar_Reflection_Data.Tv_Let
                 (true, bv, (lb.FStar_Syntax_Syntax.lbdef), t21))
    | FStar_Syntax_Syntax.Tm_match (t4,brs) ->
        let rec inspect_pat p =
          match p.FStar_Syntax_Syntax.v with
          | FStar_Syntax_Syntax.Pat_constant c ->
              let uu____668 = inspect_const c  in
              FStar_Reflection_Data.Pat_Constant uu____668
          | FStar_Syntax_Syntax.Pat_cons (fv,ps) ->
              let uu____689 =
                let uu____701 =
                  FStar_List.map
                    (fun uu____725  ->
                       match uu____725 with
                       | (p1,b) ->
                           let uu____746 = inspect_pat p1  in (uu____746, b))
                    ps
                   in
                (fv, uu____701)  in
              FStar_Reflection_Data.Pat_Cons uu____689
          | FStar_Syntax_Syntax.Pat_var bv ->
              FStar_Reflection_Data.Pat_Var bv
          | FStar_Syntax_Syntax.Pat_wild bv ->
              FStar_Reflection_Data.Pat_Wild bv
          | FStar_Syntax_Syntax.Pat_dot_term (bv,t5) ->
              FStar_Reflection_Data.Pat_Dot_Term (bv, t5)
           in
        let brs1 =
          FStar_List.map
            (fun uu___0_797  ->
               match uu___0_797 with
               | (pat,uu____819,t5) ->
                   let uu____837 = inspect_pat pat  in (uu____837, t5)) brs
           in
        FStar_Reflection_Data.Tv_Match (t4, brs1)
    | FStar_Syntax_Syntax.Tm_unknown  -> FStar_Reflection_Data.Tv_Unknown
    | uu____842 ->
        ((let uu____844 =
            let uu____850 =
              let uu____852 = FStar_Syntax_Print.tag_of_term t3  in
              let uu____854 = FStar_Syntax_Print.term_to_string t3  in
              FStar_Util.format2
                "inspect_ln: outside of expected syntax (%s, %s)\n" uu____852
                uu____854
               in
            (FStar_Errors.Warning_CantInspect, uu____850)  in
          FStar_Errors.log_issue t3.FStar_Syntax_Syntax.pos uu____844);
         FStar_Reflection_Data.Tv_Unknown)
  
let (inspect_comp :
  FStar_Syntax_Syntax.comp -> FStar_Reflection_Data.comp_view) =
  fun c  ->
    match c.FStar_Syntax_Syntax.n with
    | FStar_Syntax_Syntax.Total (t,uu____865) ->
        FStar_Reflection_Data.C_Total (t, FStar_Pervasives_Native.None)
    | FStar_Syntax_Syntax.Comp ct ->
        let uu____877 =
          FStar_Ident.lid_equals ct.FStar_Syntax_Syntax.effect_name
            FStar_Parser_Const.effect_Lemma_lid
           in
        if uu____877
        then
          (match ct.FStar_Syntax_Syntax.effect_args with
           | (pre,uu____881)::(post,uu____883)::uu____884 ->
               FStar_Reflection_Data.C_Lemma (pre, post)
           | uu____927 ->
               failwith "inspect_comp: Lemma does not have enough arguments?")
        else
          (let uu____941 =
             FStar_Ident.lid_equals ct.FStar_Syntax_Syntax.effect_name
               FStar_Parser_Const.effect_Tot_lid
              in
           if uu____941
           then
             let maybe_dec =
               FStar_List.tryFind
                 (fun uu___1_949  ->
                    match uu___1_949 with
                    | FStar_Syntax_Syntax.DECREASES uu____951 -> true
                    | uu____955 -> false) ct.FStar_Syntax_Syntax.flags
                in
             let md =
               match maybe_dec with
               | FStar_Pervasives_Native.None  ->
                   FStar_Pervasives_Native.None
               | FStar_Pervasives_Native.Some (FStar_Syntax_Syntax.DECREASES
                   t) -> FStar_Pervasives_Native.Some t
               | uu____965 -> failwith "impossible"  in
             FStar_Reflection_Data.C_Total
               ((ct.FStar_Syntax_Syntax.result_typ), md)
           else FStar_Reflection_Data.C_Unknown)
    | FStar_Syntax_Syntax.GTotal uu____975 -> FStar_Reflection_Data.C_Unknown
  
let (pack_comp : FStar_Reflection_Data.comp_view -> FStar_Syntax_Syntax.comp)
  =
  fun cv  ->
    match cv with
    | FStar_Reflection_Data.C_Total (t,uu____991) ->
        FStar_Syntax_Syntax.mk_Total t
    | FStar_Reflection_Data.C_Lemma (pre,post) ->
        let ct =
          let uu____999 =
            let uu____1010 = FStar_Syntax_Syntax.as_arg pre  in
            let uu____1019 =
              let uu____1030 = FStar_Syntax_Syntax.as_arg post  in
              [uu____1030]  in
            uu____1010 :: uu____1019  in
          {
            FStar_Syntax_Syntax.comp_univs = [];
            FStar_Syntax_Syntax.effect_name =
              FStar_Parser_Const.effect_Lemma_lid;
            FStar_Syntax_Syntax.result_typ = FStar_Syntax_Syntax.t_unit;
            FStar_Syntax_Syntax.effect_args = uu____999;
            FStar_Syntax_Syntax.flags = []
          }  in
        FStar_Syntax_Syntax.mk_Comp ct
    | uu____1063 -> failwith "cannot pack a C_Unknown"
  
let (pack_const : FStar_Reflection_Data.vconst -> FStar_Syntax_Syntax.sconst)
  =
  fun c  ->
    match c with
    | FStar_Reflection_Data.C_Unit  -> FStar_Const.Const_unit
    | FStar_Reflection_Data.C_Int i ->
        let uu____1072 =
          let uu____1084 = FStar_BigInt.string_of_big_int i  in
          (uu____1084, FStar_Pervasives_Native.None)  in
        FStar_Const.Const_int uu____1072
    | FStar_Reflection_Data.C_True  -> FStar_Const.Const_bool true
    | FStar_Reflection_Data.C_False  -> FStar_Const.Const_bool false
    | FStar_Reflection_Data.C_String s ->
        FStar_Const.Const_string (s, FStar_Range.dummyRange)
    | FStar_Reflection_Data.C_Range r -> FStar_Const.Const_range r
    | FStar_Reflection_Data.C_Reify  -> FStar_Const.Const_reify
    | FStar_Reflection_Data.C_Reflect ns ->
        let uu____1104 = FStar_Ident.lid_of_path ns FStar_Range.dummyRange
           in
        FStar_Const.Const_reflect uu____1104
  
let (pack_ln : FStar_Reflection_Data.term_view -> FStar_Syntax_Syntax.term) =
  fun tv  ->
    match tv with
    | FStar_Reflection_Data.Tv_Var bv -> FStar_Syntax_Syntax.bv_to_name bv
    | FStar_Reflection_Data.Tv_BVar bv -> FStar_Syntax_Syntax.bv_to_tm bv
    | FStar_Reflection_Data.Tv_FVar fv -> FStar_Syntax_Syntax.fv_to_tm fv
    | FStar_Reflection_Data.Tv_App (l,(r,q)) ->
        let q' = pack_aqual q  in FStar_Syntax_Util.mk_app l [(r, q')]
    | FStar_Reflection_Data.Tv_Abs (b,t) ->
        FStar_Syntax_Util.abs [b] t FStar_Pervasives_Native.None
    | FStar_Reflection_Data.Tv_Arrow (b,c) -> FStar_Syntax_Util.arrow [b] c
    | FStar_Reflection_Data.Tv_Type () -> FStar_Syntax_Util.ktype
    | FStar_Reflection_Data.Tv_Refine (bv,t) -> FStar_Syntax_Util.refine bv t
    | FStar_Reflection_Data.Tv_Const c ->
        let uu____1169 =
          let uu____1176 =
            let uu____1177 = pack_const c  in
            FStar_Syntax_Syntax.Tm_constant uu____1177  in
          FStar_Syntax_Syntax.mk uu____1176  in
        uu____1169 FStar_Pervasives_Native.None FStar_Range.dummyRange
    | FStar_Reflection_Data.Tv_Uvar (u,ctx_u_s) ->
        FStar_Syntax_Syntax.mk (FStar_Syntax_Syntax.Tm_uvar ctx_u_s)
          FStar_Pervasives_Native.None FStar_Range.dummyRange
    | FStar_Reflection_Data.Tv_Let (false ,bv,t1,t2) ->
        let lb =
          FStar_Syntax_Util.mk_letbinding (FStar_Util.Inl bv) []
            bv.FStar_Syntax_Syntax.sort FStar_Parser_Const.effect_Tot_lid t1
            [] FStar_Range.dummyRange
           in
        FStar_Syntax_Syntax.mk
          (FStar_Syntax_Syntax.Tm_let ((false, [lb]), t2))
          FStar_Pervasives_Native.None FStar_Range.dummyRange
    | FStar_Reflection_Data.Tv_Let (true ,bv,t1,t2) ->
        let lb =
          FStar_Syntax_Util.mk_letbinding (FStar_Util.Inl bv) []
            bv.FStar_Syntax_Syntax.sort FStar_Parser_Const.effect_Tot_lid t1
            [] FStar_Range.dummyRange
           in
        FStar_Syntax_Syntax.mk
          (FStar_Syntax_Syntax.Tm_let ((true, [lb]), t2))
          FStar_Pervasives_Native.None FStar_Range.dummyRange
    | FStar_Reflection_Data.Tv_Match (t,brs) ->
        let wrap v1 =
          {
            FStar_Syntax_Syntax.v = v1;
            FStar_Syntax_Syntax.p = FStar_Range.dummyRange
          }  in
        let rec pack_pat p =
          match p with
          | FStar_Reflection_Data.Pat_Constant c ->
              let uu____1243 =
                let uu____1244 = pack_const c  in
                FStar_Syntax_Syntax.Pat_constant uu____1244  in
              FStar_All.pipe_left wrap uu____1243
          | FStar_Reflection_Data.Pat_Cons (fv,ps) ->
              let uu____1261 =
                let uu____1262 =
                  let uu____1276 =
                    FStar_List.map
                      (fun uu____1300  ->
                         match uu____1300 with
                         | (p1,b) ->
                             let uu____1315 = pack_pat p1  in (uu____1315, b))
                      ps
                     in
                  (fv, uu____1276)  in
                FStar_Syntax_Syntax.Pat_cons uu____1262  in
              FStar_All.pipe_left wrap uu____1261
          | FStar_Reflection_Data.Pat_Var bv ->
              FStar_All.pipe_left wrap (FStar_Syntax_Syntax.Pat_var bv)
          | FStar_Reflection_Data.Pat_Wild bv ->
              FStar_All.pipe_left wrap (FStar_Syntax_Syntax.Pat_wild bv)
          | FStar_Reflection_Data.Pat_Dot_Term (bv,t1) ->
              FStar_All.pipe_left wrap
                (FStar_Syntax_Syntax.Pat_dot_term (bv, t1))
           in
        let brs1 =
          FStar_List.map
            (fun uu___2_1363  ->
               match uu___2_1363 with
               | (pat,t1) ->
                   let uu____1380 = pack_pat pat  in
                   (uu____1380, FStar_Pervasives_Native.None, t1)) brs
           in
        FStar_Syntax_Syntax.mk (FStar_Syntax_Syntax.Tm_match (t, brs1))
          FStar_Pervasives_Native.None FStar_Range.dummyRange
    | FStar_Reflection_Data.Tv_AscribedT (e,t,tacopt) ->
        FStar_Syntax_Syntax.mk
          (FStar_Syntax_Syntax.Tm_ascribed
             (e, ((FStar_Util.Inl t), tacopt), FStar_Pervasives_Native.None))
          FStar_Pervasives_Native.None FStar_Range.dummyRange
    | FStar_Reflection_Data.Tv_AscribedC (e,c,tacopt) ->
        FStar_Syntax_Syntax.mk
          (FStar_Syntax_Syntax.Tm_ascribed
             (e, ((FStar_Util.Inr c), tacopt), FStar_Pervasives_Native.None))
          FStar_Pervasives_Native.None FStar_Range.dummyRange
    | FStar_Reflection_Data.Tv_Unknown  ->
        FStar_Syntax_Syntax.mk FStar_Syntax_Syntax.Tm_unknown
          FStar_Pervasives_Native.None FStar_Range.dummyRange
  
let (compare_bv :
  FStar_Syntax_Syntax.bv -> FStar_Syntax_Syntax.bv -> FStar_Order.order) =
  fun x  ->
    fun y  ->
      let n1 = FStar_Syntax_Syntax.order_bv x y  in
      if n1 < Prims.int_zero
      then FStar_Order.Lt
      else if n1 = Prims.int_zero then FStar_Order.Eq else FStar_Order.Gt
  
let (is_free :
  FStar_Syntax_Syntax.bv -> FStar_Syntax_Syntax.term -> Prims.bool) =
  fun x  -> fun t  -> FStar_Syntax_Util.is_free_in x t 
let (lookup_attr :
  FStar_Syntax_Syntax.term ->
    FStar_TypeChecker_Env.env -> FStar_Syntax_Syntax.fv Prims.list)
  =
  fun attr  ->
    fun env  ->
      let uu____1541 =
        let uu____1542 = FStar_Syntax_Subst.compress attr  in
        uu____1542.FStar_Syntax_Syntax.n  in
      match uu____1541 with
      | FStar_Syntax_Syntax.Tm_fvar fv ->
          let ses =
            let uu____1551 =
              let uu____1553 = FStar_Syntax_Syntax.lid_of_fv fv  in
              FStar_Ident.text_of_lid uu____1553  in
            FStar_TypeChecker_Env.lookup_attr env uu____1551  in
          FStar_List.concatMap
            (fun se  ->
               let uu____1557 = FStar_Syntax_Util.lid_of_sigelt se  in
               match uu____1557 with
               | FStar_Pervasives_Native.None  -> []
               | FStar_Pervasives_Native.Some l ->
                   let uu____1563 =
                     FStar_Syntax_Syntax.lid_as_fv l
                       (FStar_Syntax_Syntax.Delta_constant_at_level
                          (Prims.of_int (999))) FStar_Pervasives_Native.None
                      in
                   [uu____1563]) ses
      | uu____1565 -> []
  
let (all_defs_in_env :
  FStar_TypeChecker_Env.env -> FStar_Syntax_Syntax.fv Prims.list) =
  fun env  ->
    let uu____1576 = FStar_TypeChecker_Env.lidents env  in
    FStar_List.map
      (fun l  ->
         FStar_Syntax_Syntax.lid_as_fv l
           (FStar_Syntax_Syntax.Delta_constant_at_level (Prims.of_int (999)))
           FStar_Pervasives_Native.None) uu____1576
  
let (defs_in_module :
  FStar_TypeChecker_Env.env ->
    FStar_Reflection_Data.name -> FStar_Syntax_Syntax.fv Prims.list)
  =
  fun env  ->
    fun modul  ->
      let uu____1597 = FStar_TypeChecker_Env.lidents env  in
      FStar_List.concatMap
        (fun l  ->
           let ns =
             let uu____1605 =
               let uu____1608 = FStar_Ident.ids_of_lid l  in
               FStar_All.pipe_right uu____1608 init  in
             FStar_All.pipe_right uu____1605
               (FStar_List.map FStar_Ident.string_of_ident)
              in
           if ns = modul
           then
             let uu____1621 =
               FStar_Syntax_Syntax.lid_as_fv l
                 (FStar_Syntax_Syntax.Delta_constant_at_level
                    (Prims.of_int (999))) FStar_Pervasives_Native.None
                in
             [uu____1621]
           else []) uu____1597
  
let (lookup_typ :
  FStar_TypeChecker_Env.env ->
    Prims.string Prims.list ->
      FStar_Syntax_Syntax.sigelt FStar_Pervasives_Native.option)
  =
  fun env  ->
    fun ns  ->
      let lid = FStar_Parser_Const.p2l ns  in
      FStar_TypeChecker_Env.lookup_sigelt env lid
  
let (sigelt_attrs :
  FStar_Syntax_Syntax.sigelt -> FStar_Syntax_Syntax.attribute Prims.list) =
  fun se  -> se.FStar_Syntax_Syntax.sigattrs 
let (set_sigelt_attrs :
  FStar_Syntax_Syntax.attribute Prims.list ->
    FStar_Syntax_Syntax.sigelt -> FStar_Syntax_Syntax.sigelt)
  =
  fun attrs  ->
    fun se  ->
      let uu___372_1672 = se  in
      {
        FStar_Syntax_Syntax.sigel = (uu___372_1672.FStar_Syntax_Syntax.sigel);
        FStar_Syntax_Syntax.sigrng =
          (uu___372_1672.FStar_Syntax_Syntax.sigrng);
        FStar_Syntax_Syntax.sigquals =
          (uu___372_1672.FStar_Syntax_Syntax.sigquals);
        FStar_Syntax_Syntax.sigmeta =
          (uu___372_1672.FStar_Syntax_Syntax.sigmeta);
        FStar_Syntax_Syntax.sigattrs = attrs;
        FStar_Syntax_Syntax.sigopts =
          (uu___372_1672.FStar_Syntax_Syntax.sigopts)
      }
  
let (sigelt_quals :
  FStar_Syntax_Syntax.sigelt -> FStar_Syntax_Syntax.qualifier Prims.list) =
  fun se  -> se.FStar_Syntax_Syntax.sigquals 
let (set_sigelt_quals :
  FStar_Syntax_Syntax.qualifier Prims.list ->
    FStar_Syntax_Syntax.sigelt -> FStar_Syntax_Syntax.sigelt)
  =
  fun quals  ->
    fun se  ->
      let uu___377_1698 = se  in
      {
        FStar_Syntax_Syntax.sigel = (uu___377_1698.FStar_Syntax_Syntax.sigel);
        FStar_Syntax_Syntax.sigrng =
          (uu___377_1698.FStar_Syntax_Syntax.sigrng);
        FStar_Syntax_Syntax.sigquals = quals;
        FStar_Syntax_Syntax.sigmeta =
          (uu___377_1698.FStar_Syntax_Syntax.sigmeta);
        FStar_Syntax_Syntax.sigattrs =
          (uu___377_1698.FStar_Syntax_Syntax.sigattrs);
        FStar_Syntax_Syntax.sigopts =
          (uu___377_1698.FStar_Syntax_Syntax.sigopts)
      }
  
let (sigelt_opts :
  FStar_Syntax_Syntax.sigelt ->
    FStar_Options.optionstate FStar_Pervasives_Native.option)
  = fun se  -> se.FStar_Syntax_Syntax.sigopts 
let (inspect_sigelt :
  FStar_Syntax_Syntax.sigelt -> FStar_Reflection_Data.sigelt_view) =
  fun se  ->
    match se.FStar_Syntax_Syntax.sigel with
    | FStar_Syntax_Syntax.Sig_let ((r,lb::[]),uu____1717) ->
        let fv =
          match lb.FStar_Syntax_Syntax.lbname with
          | FStar_Util.Inr fv -> fv
          | FStar_Util.Inl uu____1728 ->
              failwith "impossible: global Sig_let has bv"
           in
        let uu____1730 =
          FStar_Syntax_Subst.univ_var_opening lb.FStar_Syntax_Syntax.lbunivs
           in
        (match uu____1730 with
         | (s,us) ->
             let typ =
               FStar_Syntax_Subst.subst s lb.FStar_Syntax_Syntax.lbtyp  in
             let def =
               FStar_Syntax_Subst.subst s lb.FStar_Syntax_Syntax.lbdef  in
             FStar_Reflection_Data.Sg_Let
               (r, fv, (lb.FStar_Syntax_Syntax.lbunivs),
                 (lb.FStar_Syntax_Syntax.lbtyp),
                 (lb.FStar_Syntax_Syntax.lbdef)))
    | FStar_Syntax_Syntax.Sig_inductive_typ (lid,us,bs,ty,uu____1758,c_lids)
        ->
        let nm = FStar_Ident.path_of_lid lid  in
        let uu____1769 = FStar_Syntax_Subst.univ_var_opening us  in
        (match uu____1769 with
         | (s,us1) ->
             let bs1 = FStar_Syntax_Subst.subst_binders s bs  in
             let ty1 = FStar_Syntax_Subst.subst s ty  in
             let uu____1790 =
               let uu____1807 = FStar_List.map FStar_Ident.path_of_lid c_lids
                  in
               (nm, us1, bs1, ty1, uu____1807)  in
             FStar_Reflection_Data.Sg_Inductive uu____1790)
    | FStar_Syntax_Syntax.Sig_datacon (lid,us,ty,uu____1819,n1,uu____1821) ->
        let uu____1828 = FStar_Syntax_Subst.univ_var_opening us  in
        (match uu____1828 with
         | (s,us1) ->
             let ty1 = FStar_Syntax_Subst.subst s ty  in
             let uu____1848 =
               let uu____1853 = FStar_Ident.path_of_lid lid  in
               (uu____1853, ty1)  in
             FStar_Reflection_Data.Sg_Constructor uu____1848)
    | uu____1854 -> FStar_Reflection_Data.Unk
  
let (pack_sigelt :
  FStar_Reflection_Data.sigelt_view -> FStar_Syntax_Syntax.sigelt) =
  fun sv  ->
    match sv with
    | FStar_Reflection_Data.Sg_Let (r,fv,univs1,typ,def) ->
        let s = FStar_Syntax_Subst.univ_var_closing univs1  in
        let typ1 = FStar_Syntax_Subst.subst s typ  in
        let def1 = FStar_Syntax_Subst.subst s def  in
        let lb =
          FStar_Syntax_Util.mk_letbinding (FStar_Util.Inr fv) univs1 typ1
            FStar_Parser_Const.effect_Tot_lid def1 []
            def1.FStar_Syntax_Syntax.pos
           in
        let uu____1880 =
          let uu____1881 =
            let uu____1888 =
              let uu____1891 = FStar_Syntax_Syntax.lid_of_fv fv  in
              [uu____1891]  in
            ((r, [lb]), uu____1888)  in
          FStar_Syntax_Syntax.Sig_let uu____1881  in
        FStar_All.pipe_left FStar_Syntax_Syntax.mk_sigelt uu____1880
    | FStar_Reflection_Data.Sg_Constructor uu____1897 ->
        failwith "packing Sg_Constructor, sorry"
    | FStar_Reflection_Data.Sg_Inductive uu____1903 ->
        failwith "packing Sg_Inductive, sorry"
    | FStar_Reflection_Data.Unk  -> failwith "packing Unk, sorry"
  
let (inspect_bv : FStar_Syntax_Syntax.bv -> FStar_Reflection_Data.bv_view) =
  fun bv  ->
    let uu____1928 =
      FStar_Ident.string_of_ident bv.FStar_Syntax_Syntax.ppname  in
    let uu____1930 = FStar_BigInt.of_int_fs bv.FStar_Syntax_Syntax.index  in
    {
      FStar_Reflection_Data.bv_ppname = uu____1928;
      FStar_Reflection_Data.bv_index = uu____1930;
      FStar_Reflection_Data.bv_sort = (bv.FStar_Syntax_Syntax.sort)
    }
  
let (pack_bv : FStar_Reflection_Data.bv_view -> FStar_Syntax_Syntax.bv) =
  fun bvv  ->
    let uu____1937 =
      FStar_Ident.mk_ident
        ((bvv.FStar_Reflection_Data.bv_ppname), FStar_Range.dummyRange)
       in
    let uu____1939 =
      FStar_BigInt.to_int_fs bvv.FStar_Reflection_Data.bv_index  in
    {
      FStar_Syntax_Syntax.ppname = uu____1937;
      FStar_Syntax_Syntax.index = uu____1939;
      FStar_Syntax_Syntax.sort = (bvv.FStar_Reflection_Data.bv_sort)
    }
  
let (inspect_binder :
  FStar_Syntax_Syntax.binder ->
    (FStar_Syntax_Syntax.bv * FStar_Reflection_Data.aqualv))
  =
  fun b  ->
    let uu____1955 = b  in
    match uu____1955 with
    | (bv,aq) -> let uu____1966 = inspect_aqual aq  in (bv, uu____1966)
  
let (pack_binder :
  FStar_Syntax_Syntax.bv ->
    FStar_Reflection_Data.aqualv -> FStar_Syntax_Syntax.binder)
  =
  fun bv  -> fun aqv  -> let uu____1978 = pack_aqual aqv  in (bv, uu____1978) 
let (moduleof : FStar_TypeChecker_Env.env -> Prims.string Prims.list) =
  fun e  -> FStar_Ident.path_of_lid e.FStar_TypeChecker_Env.curmodule 
let (env_open_modules :
  FStar_TypeChecker_Env.env -> FStar_Reflection_Data.name Prims.list) =
  fun e  ->
    let uu____2005 =
      FStar_Syntax_DsEnv.open_modules e.FStar_TypeChecker_Env.dsenv  in
    FStar_List.map
      (fun uu____2023  ->
         match uu____2023 with
         | (l,m) ->
             let uu____2033 = FStar_Ident.ids_of_lid l  in
             FStar_List.map FStar_Ident.text_of_id uu____2033) uu____2005
  
let (binders_of_env :
  FStar_TypeChecker_Env.env -> FStar_Syntax_Syntax.binders) =
  fun e  -> FStar_TypeChecker_Env.all_binders e 
let (term_eq :
  FStar_Syntax_Syntax.term -> FStar_Syntax_Syntax.term -> Prims.bool) =
  fun t1  ->
    fun t2  ->
      let uu____2055 = FStar_Syntax_Util.un_uinst t1  in
      let uu____2056 = FStar_Syntax_Util.un_uinst t2  in
      FStar_Syntax_Util.term_eq uu____2055 uu____2056
  
let (term_to_string : FStar_Syntax_Syntax.term -> Prims.string) =
  fun t  -> FStar_Syntax_Print.term_to_string t 
let (comp_to_string : FStar_Syntax_Syntax.comp -> Prims.string) =
  fun c  -> FStar_Syntax_Print.comp_to_string c 
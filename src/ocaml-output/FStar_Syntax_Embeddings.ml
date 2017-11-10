open Prims
type 'a embedder = FStar_Range.range -> 'a -> FStar_Syntax_Syntax.term
[@@deriving show]
type 'a unembedder =
  FStar_Syntax_Syntax.term -> 'a FStar_Pervasives_Native.option[@@deriving
                                                                 show]
let embed_unit: FStar_Range.range -> Prims.unit -> FStar_Syntax_Syntax.term =
  fun rng  ->
    fun u  ->
      let uu___264_26 = FStar_Syntax_Util.exp_unit in
      {
        FStar_Syntax_Syntax.n = (uu___264_26.FStar_Syntax_Syntax.n);
        FStar_Syntax_Syntax.pos = rng;
        FStar_Syntax_Syntax.vars = (uu___264_26.FStar_Syntax_Syntax.vars)
      }
let __unembed_unit:
  Prims.bool ->
    FStar_Syntax_Syntax.term -> Prims.unit FStar_Pervasives_Native.option
  =
  fun w  ->
    fun t0  ->
      let t = FStar_Syntax_Util.unascribe t0 in
      match t.FStar_Syntax_Syntax.n with
      | FStar_Syntax_Syntax.Tm_constant (FStar_Const.Const_unit ) ->
          FStar_Pervasives_Native.Some ()
      | uu____42 ->
          (if w
           then
             (let uu____44 =
                let uu____49 =
                  let uu____50 = FStar_Syntax_Print.term_to_string t in
                  FStar_Util.format1 "Not an embedded unit: %s" uu____50 in
                (FStar_Errors.NotEmbeddedUnit, uu____49) in
              FStar_Errors.maybe_fatal_error t0.FStar_Syntax_Syntax.pos
                uu____44)
           else ();
           FStar_Pervasives_Native.None)
let unembed_unit:
  FStar_Syntax_Syntax.term -> Prims.unit FStar_Pervasives_Native.option =
  fun t  -> __unembed_unit true t
let unembed_unit_safe:
  FStar_Syntax_Syntax.term -> Prims.unit FStar_Pervasives_Native.option =
  fun t  -> __unembed_unit false t
let embed_bool: FStar_Range.range -> Prims.bool -> FStar_Syntax_Syntax.term =
  fun rng  ->
    fun b  ->
      let t =
        if b
        then FStar_Syntax_Util.exp_true_bool
        else FStar_Syntax_Util.exp_false_bool in
      let uu___265_81 = t in
      {
        FStar_Syntax_Syntax.n = (uu___265_81.FStar_Syntax_Syntax.n);
        FStar_Syntax_Syntax.pos = rng;
        FStar_Syntax_Syntax.vars = (uu___265_81.FStar_Syntax_Syntax.vars)
      }
let __unembed_bool:
  Prims.bool ->
    FStar_Syntax_Syntax.term -> Prims.bool FStar_Pervasives_Native.option
  =
  fun w  ->
    fun t0  ->
      let t = FStar_Syntax_Util.unmeta_safe t0 in
      match t.FStar_Syntax_Syntax.n with
      | FStar_Syntax_Syntax.Tm_constant (FStar_Const.Const_bool b) ->
          FStar_Pervasives_Native.Some b
      | uu____98 ->
          (if w
           then
             (let uu____100 =
                let uu____105 =
                  let uu____106 = FStar_Syntax_Print.term_to_string t0 in
                  FStar_Util.format1 "Not an embedded bool: %s" uu____106 in
                (FStar_Errors.NotEmbeddedBool, uu____105) in
              FStar_Errors.maybe_fatal_error t0.FStar_Syntax_Syntax.pos
                uu____100)
           else ();
           FStar_Pervasives_Native.None)
let unembed_bool:
  FStar_Syntax_Syntax.term -> Prims.bool FStar_Pervasives_Native.option =
  fun t  -> __unembed_bool true t
let unembed_bool_safe:
  FStar_Syntax_Syntax.term -> Prims.bool FStar_Pervasives_Native.option =
  fun t  -> __unembed_bool false t
let embed_char:
  FStar_Range.range -> FStar_Char.char -> FStar_Syntax_Syntax.term =
  fun rng  ->
    fun c  ->
      let t = FStar_Syntax_Util.exp_char c in
      let uu___266_132 = t in
      {
        FStar_Syntax_Syntax.n = (uu___266_132.FStar_Syntax_Syntax.n);
        FStar_Syntax_Syntax.pos = rng;
        FStar_Syntax_Syntax.vars = (uu___266_132.FStar_Syntax_Syntax.vars)
      }
let __unembed_char:
  Prims.bool ->
    FStar_Syntax_Syntax.term ->
      FStar_Char.char FStar_Pervasives_Native.option
  =
  fun w  ->
    fun t0  ->
      let t = FStar_Syntax_Util.unmeta_safe t0 in
      match t.FStar_Syntax_Syntax.n with
      | FStar_Syntax_Syntax.Tm_constant (FStar_Const.Const_char c) ->
          FStar_Pervasives_Native.Some c
      | uu____147 ->
          (if w
           then
             (let uu____149 =
                let uu____154 =
                  let uu____155 = FStar_Syntax_Print.term_to_string t0 in
                  FStar_Util.format1 "Not an embedded char: %s" uu____155 in
                (FStar_Errors.NotEmbeddedChar, uu____154) in
              FStar_Errors.maybe_fatal_error t0.FStar_Syntax_Syntax.pos
                uu____149)
           else ();
           FStar_Pervasives_Native.None)
let unembed_char:
  FStar_Syntax_Syntax.term -> FStar_Char.char FStar_Pervasives_Native.option
  = fun t  -> __unembed_char true t
let unembed_char_safe:
  FStar_Syntax_Syntax.term -> FStar_Char.char FStar_Pervasives_Native.option
  = fun t  -> __unembed_char false t
let embed_int:
  FStar_Range.range -> FStar_BigInt.t -> FStar_Syntax_Syntax.term =
  fun rng  ->
    fun i  ->
      let t =
        let uu____181 = FStar_BigInt.string_of_big_int i in
        FStar_Syntax_Util.exp_int uu____181 in
      let uu___267_182 = t in
      {
        FStar_Syntax_Syntax.n = (uu___267_182.FStar_Syntax_Syntax.n);
        FStar_Syntax_Syntax.pos = rng;
        FStar_Syntax_Syntax.vars = (uu___267_182.FStar_Syntax_Syntax.vars)
      }
let __unembed_int:
  Prims.bool ->
    FStar_Syntax_Syntax.term -> FStar_BigInt.t FStar_Pervasives_Native.option
  =
  fun w  ->
    fun t0  ->
      let t = FStar_Syntax_Util.unmeta_safe t0 in
      match t.FStar_Syntax_Syntax.n with
      | FStar_Syntax_Syntax.Tm_constant (FStar_Const.Const_int (s,uu____197))
          ->
          let uu____210 = FStar_BigInt.big_int_of_string s in
          FStar_Pervasives_Native.Some uu____210
      | uu____211 ->
          (if w
           then
             (let uu____213 =
                let uu____218 =
                  let uu____219 = FStar_Syntax_Print.term_to_string t0 in
                  FStar_Util.format1 "Not an embedded int: %s" uu____219 in
                (FStar_Errors.NotEmbeddedInt, uu____218) in
              FStar_Errors.maybe_fatal_error t.FStar_Syntax_Syntax.pos
                uu____213)
           else ();
           FStar_Pervasives_Native.None)
let unembed_int:
  FStar_Syntax_Syntax.term -> FStar_BigInt.t FStar_Pervasives_Native.option =
  fun t  -> __unembed_int true t
let unembed_int_safe:
  FStar_Syntax_Syntax.term -> FStar_BigInt.t FStar_Pervasives_Native.option =
  fun t  -> __unembed_int false t
let embed_string:
  FStar_Range.range -> Prims.string -> FStar_Syntax_Syntax.term =
  fun rng  ->
    fun s  ->
      FStar_Syntax_Syntax.mk
        (FStar_Syntax_Syntax.Tm_constant (FStar_Const.Const_string (s, rng)))
        FStar_Pervasives_Native.None rng
let __unembed_string:
  Prims.bool ->
    FStar_Syntax_Syntax.term -> Prims.string FStar_Pervasives_Native.option
  =
  fun w  ->
    fun t0  ->
      let t = FStar_Syntax_Util.unmeta_safe t0 in
      match t.FStar_Syntax_Syntax.n with
      | FStar_Syntax_Syntax.Tm_constant (FStar_Const.Const_string
          (s,uu____258)) -> FStar_Pervasives_Native.Some s
      | uu____259 ->
          (if w
           then
             (let uu____261 =
                let uu____266 =
                  let uu____267 = FStar_Syntax_Print.term_to_string t0 in
                  FStar_Util.format1 "Not an embedded string: %s" uu____267 in
                (FStar_Errors.NotEmbeddedString, uu____266) in
              FStar_Errors.maybe_fatal_error t.FStar_Syntax_Syntax.pos
                uu____261)
           else ();
           FStar_Pervasives_Native.None)
let unembed_string:
  FStar_Syntax_Syntax.term -> Prims.string FStar_Pervasives_Native.option =
  fun t  -> __unembed_string true t
let unembed_string_safe:
  FStar_Syntax_Syntax.term -> Prims.string FStar_Pervasives_Native.option =
  fun t  -> __unembed_string false t
let embed_pair:
  'a 'b .
    'a embedder ->
      FStar_Syntax_Syntax.typ ->
        'b embedder ->
          FStar_Syntax_Syntax.typ ->
            ('a,'b) FStar_Pervasives_Native.tuple2 embedder
  =
  fun embed_a  ->
    fun t_a  ->
      fun embed_b  ->
        fun t_b  ->
          fun rng  ->
            fun x  ->
              let uu____350 =
                let uu____351 =
                  let uu____352 =
                    FStar_Syntax_Syntax.tdataconstr
                      FStar_Parser_Const.lid_Mktuple2 in
                  FStar_Syntax_Syntax.mk_Tm_uinst uu____352
                    [FStar_Syntax_Syntax.U_zero; FStar_Syntax_Syntax.U_zero] in
                let uu____353 =
                  let uu____354 = FStar_Syntax_Syntax.iarg t_a in
                  let uu____355 =
                    let uu____358 = FStar_Syntax_Syntax.iarg t_b in
                    let uu____359 =
                      let uu____362 =
                        let uu____363 =
                          embed_a rng (FStar_Pervasives_Native.fst x) in
                        FStar_Syntax_Syntax.as_arg uu____363 in
                      let uu____367 =
                        let uu____370 =
                          let uu____371 =
                            embed_b rng (FStar_Pervasives_Native.snd x) in
                          FStar_Syntax_Syntax.as_arg uu____371 in
                        [uu____370] in
                      uu____362 :: uu____367 in
                    uu____358 :: uu____359 in
                  uu____354 :: uu____355 in
                FStar_Syntax_Syntax.mk_Tm_app uu____351 uu____353 in
              uu____350 FStar_Pervasives_Native.None rng
let __unembed_pair:
  'a 'b .
    Prims.bool ->
      'a unembedder ->
        'b unembedder ->
          FStar_Syntax_Syntax.term ->
            ('a,'b) FStar_Pervasives_Native.tuple2
              FStar_Pervasives_Native.option
  =
  fun w  ->
    fun unembed_a  ->
      fun unembed_b  ->
        fun t0  ->
          let t = FStar_Syntax_Util.unmeta_safe t0 in
          let uu____424 = FStar_Syntax_Util.head_and_args t in
          match uu____424 with
          | (hd1,args) ->
              let uu____467 =
                let uu____480 =
                  let uu____481 = FStar_Syntax_Util.un_uinst hd1 in
                  uu____481.FStar_Syntax_Syntax.n in
                (uu____480, args) in
              (match uu____467 with
               | (FStar_Syntax_Syntax.Tm_fvar
                  fv,uu____499::uu____500::(a,uu____502)::(b,uu____504)::[])
                   when
                   FStar_Syntax_Syntax.fv_eq_lid fv
                     FStar_Parser_Const.lid_Mktuple2
                   ->
                   let uu____563 = unembed_a a in
                   FStar_Util.bind_opt uu____563
                     (fun a1  ->
                        let uu____575 = unembed_b b in
                        FStar_Util.bind_opt uu____575
                          (fun b1  -> FStar_Pervasives_Native.Some (a1, b1)))
               | uu____590 ->
                   (if w
                    then
                      (let uu____604 =
                         let uu____609 =
                           let uu____610 =
                             FStar_Syntax_Print.term_to_string t0 in
                           FStar_Util.format1 "Not an embedded pair: %s"
                             uu____610 in
                         (FStar_Errors.NotEmbeddedPair, uu____609) in
                       FStar_Errors.maybe_fatal_error
                         t.FStar_Syntax_Syntax.pos uu____604)
                    else ();
                    FStar_Pervasives_Native.None))
let unembed_pair:
  'a 'b .
    'a unembedder ->
      'b unembedder -> ('a,'b) FStar_Pervasives_Native.tuple2 unembedder
  = fun ul  -> fun ur  -> fun t  -> __unembed_pair true ul ur t
let unembed_pair_safe:
  'a 'b .
    'a unembedder ->
      'b unembedder -> ('a,'b) FStar_Pervasives_Native.tuple2 unembedder
  = fun ul  -> fun ur  -> fun t  -> __unembed_pair false ul ur t
let embed_option:
  'a .
    'a embedder ->
      FStar_Syntax_Syntax.typ -> 'a FStar_Pervasives_Native.option embedder
  =
  fun embed_a  ->
    fun typ  ->
      fun rng  ->
        fun o  ->
          match o with
          | FStar_Pervasives_Native.None  ->
              let uu____761 =
                let uu____762 =
                  let uu____763 =
                    FStar_Syntax_Syntax.tdataconstr
                      FStar_Parser_Const.none_lid in
                  FStar_Syntax_Syntax.mk_Tm_uinst uu____763
                    [FStar_Syntax_Syntax.U_zero] in
                let uu____764 =
                  let uu____765 = FStar_Syntax_Syntax.iarg typ in [uu____765] in
                FStar_Syntax_Syntax.mk_Tm_app uu____762 uu____764 in
              uu____761 FStar_Pervasives_Native.None rng
          | FStar_Pervasives_Native.Some a ->
              let uu____769 =
                let uu____770 =
                  let uu____771 =
                    FStar_Syntax_Syntax.tdataconstr
                      FStar_Parser_Const.some_lid in
                  FStar_Syntax_Syntax.mk_Tm_uinst uu____771
                    [FStar_Syntax_Syntax.U_zero] in
                let uu____772 =
                  let uu____773 = FStar_Syntax_Syntax.iarg typ in
                  let uu____774 =
                    let uu____777 =
                      let uu____778 = embed_a rng a in
                      FStar_Syntax_Syntax.as_arg uu____778 in
                    [uu____777] in
                  uu____773 :: uu____774 in
                FStar_Syntax_Syntax.mk_Tm_app uu____770 uu____772 in
              uu____769 FStar_Pervasives_Native.None rng
let __unembed_option:
  'a .
    Prims.bool ->
      'a unembedder ->
        FStar_Syntax_Syntax.term ->
          'a FStar_Pervasives_Native.option FStar_Pervasives_Native.option
  =
  fun w  ->
    fun unembed_a  ->
      fun t0  ->
        let t = FStar_Syntax_Util.unmeta_safe t0 in
        let uu____814 = FStar_Syntax_Util.head_and_args t in
        match uu____814 with
        | (hd1,args) ->
            let uu____855 =
              let uu____868 =
                let uu____869 = FStar_Syntax_Util.un_uinst hd1 in
                uu____869.FStar_Syntax_Syntax.n in
              (uu____868, args) in
            (match uu____855 with
             | (FStar_Syntax_Syntax.Tm_fvar fv,uu____885) when
                 FStar_Syntax_Syntax.fv_eq_lid fv FStar_Parser_Const.none_lid
                 -> FStar_Pervasives_Native.Some FStar_Pervasives_Native.None
             | (FStar_Syntax_Syntax.Tm_fvar fv,uu____905::(a,uu____907)::[])
                 when
                 FStar_Syntax_Syntax.fv_eq_lid fv FStar_Parser_Const.some_lid
                 ->
                 let uu____944 = unembed_a a in
                 FStar_Util.bind_opt uu____944
                   (fun a1  ->
                      FStar_Pervasives_Native.Some
                        (FStar_Pervasives_Native.Some a1))
             | uu____955 ->
                 (if w
                  then
                    (let uu____969 =
                       let uu____974 =
                         let uu____975 = FStar_Syntax_Print.term_to_string t0 in
                         FStar_Util.format1 "Not an embedded option: %s"
                           uu____975 in
                       (FStar_Errors.NotEmbeddedOption, uu____974) in
                     FStar_Errors.maybe_fatal_error t.FStar_Syntax_Syntax.pos
                       uu____969)
                  else ();
                  FStar_Pervasives_Native.None))
let unembed_option:
  'a . 'a unembedder -> 'a FStar_Pervasives_Native.option unembedder =
  fun ua  -> fun t  -> __unembed_option true ua t
let unembed_option_safe:
  'a . 'a unembedder -> 'a FStar_Pervasives_Native.option unembedder =
  fun ua  -> fun t  -> __unembed_option false ua t
let rec embed_list:
  'a . 'a embedder -> FStar_Syntax_Syntax.typ -> 'a Prims.list embedder =
  fun embed_a  ->
    fun typ  ->
      fun rng  ->
        fun l  ->
          match l with
          | [] ->
              let uu____1079 =
                let uu____1080 =
                  let uu____1081 =
                    FStar_Syntax_Syntax.tdataconstr
                      FStar_Parser_Const.nil_lid in
                  FStar_Syntax_Syntax.mk_Tm_uinst uu____1081
                    [FStar_Syntax_Syntax.U_zero] in
                let uu____1082 =
                  let uu____1083 = FStar_Syntax_Syntax.iarg typ in
                  [uu____1083] in
                FStar_Syntax_Syntax.mk_Tm_app uu____1080 uu____1082 in
              uu____1079 FStar_Pervasives_Native.None rng
          | hd1::tl1 ->
              let uu____1090 =
                let uu____1091 =
                  let uu____1092 =
                    FStar_Syntax_Syntax.tdataconstr
                      FStar_Parser_Const.cons_lid in
                  FStar_Syntax_Syntax.mk_Tm_uinst uu____1092
                    [FStar_Syntax_Syntax.U_zero] in
                let uu____1093 =
                  let uu____1094 = FStar_Syntax_Syntax.iarg typ in
                  let uu____1095 =
                    let uu____1098 =
                      let uu____1099 = embed_a rng hd1 in
                      FStar_Syntax_Syntax.as_arg uu____1099 in
                    let uu____1103 =
                      let uu____1106 =
                        let uu____1107 =
                          let uu____1108 = embed_list embed_a typ in
                          uu____1108 rng tl1 in
                        FStar_Syntax_Syntax.as_arg uu____1107 in
                      [uu____1106] in
                    uu____1098 :: uu____1103 in
                  uu____1094 :: uu____1095 in
                FStar_Syntax_Syntax.mk_Tm_app uu____1091 uu____1093 in
              uu____1090 FStar_Pervasives_Native.None rng
let rec __unembed_list:
  'a .
    Prims.bool ->
      'a unembedder ->
        FStar_Syntax_Syntax.term ->
          'a Prims.list FStar_Pervasives_Native.option
  =
  fun w  ->
    fun unembed_a  ->
      fun t0  ->
        let t = FStar_Syntax_Util.unmeta_safe t0 in
        let uu____1154 = FStar_Syntax_Util.head_and_args t in
        match uu____1154 with
        | (hd1,args) ->
            let uu____1195 =
              let uu____1208 =
                let uu____1209 = FStar_Syntax_Util.un_uinst hd1 in
                uu____1209.FStar_Syntax_Syntax.n in
              (uu____1208, args) in
            (match uu____1195 with
             | (FStar_Syntax_Syntax.Tm_fvar fv,uu____1225) when
                 FStar_Syntax_Syntax.fv_eq_lid fv FStar_Parser_Const.nil_lid
                 -> FStar_Pervasives_Native.Some []
             | (FStar_Syntax_Syntax.Tm_fvar
                fv,_t::(hd2,uu____1247)::(tl1,uu____1249)::[]) when
                 FStar_Syntax_Syntax.fv_eq_lid fv FStar_Parser_Const.cons_lid
                 ->
                 let uu____1296 = unembed_a hd2 in
                 FStar_Util.bind_opt uu____1296
                   (fun hd3  ->
                      let uu____1306 = __unembed_list w unembed_a tl1 in
                      FStar_Util.bind_opt uu____1306
                        (fun tl2  ->
                           FStar_Pervasives_Native.Some (hd3 :: tl2)))
             | uu____1325 ->
                 (if w
                  then
                    (let uu____1339 =
                       let uu____1344 =
                         let uu____1345 =
                           FStar_Syntax_Print.term_to_string t0 in
                         FStar_Util.format1 "Not an embedded list: %s"
                           uu____1345 in
                       (FStar_Errors.NotEmbeddedList, uu____1344) in
                     FStar_Errors.maybe_fatal_error t.FStar_Syntax_Syntax.pos
                       uu____1339)
                  else ();
                  FStar_Pervasives_Native.None))
let unembed_list: 'a . 'a unembedder -> 'a Prims.list unembedder =
  fun ua  -> fun t  -> __unembed_list true ua t
let unembed_list_safe: 'a . 'a unembedder -> 'a Prims.list unembedder =
  fun ua  -> fun t  -> __unembed_list false ua t
let embed_string_list:
  FStar_Range.range -> Prims.string Prims.list -> FStar_Syntax_Syntax.term =
  fun rng  ->
    fun ss  ->
      let uu____1424 = embed_list embed_string FStar_Syntax_Syntax.t_string in
      uu____1424 rng ss
let unembed_string_list:
  FStar_Syntax_Syntax.term ->
    Prims.string Prims.list FStar_Pervasives_Native.option
  = fun t  -> let uu____1441 = unembed_list unembed_string in uu____1441 t
let unembed_string_list_safe:
  FStar_Syntax_Syntax.term ->
    Prims.string Prims.list FStar_Pervasives_Native.option
  =
  fun t  ->
    let uu____1457 = unembed_list_safe unembed_string_safe in uu____1457 t
type norm_step =
  | Simpl
  | Weak
  | HNF
  | Primops
  | Delta
  | Zeta
  | Iota
  | UnfoldOnly of Prims.string Prims.list[@@deriving show]
let uu___is_Simpl: norm_step -> Prims.bool =
  fun projectee  ->
    match projectee with | Simpl  -> true | uu____1473 -> false
let uu___is_Weak: norm_step -> Prims.bool =
  fun projectee  ->
    match projectee with | Weak  -> true | uu____1477 -> false
let uu___is_HNF: norm_step -> Prims.bool =
  fun projectee  -> match projectee with | HNF  -> true | uu____1481 -> false
let uu___is_Primops: norm_step -> Prims.bool =
  fun projectee  ->
    match projectee with | Primops  -> true | uu____1485 -> false
let uu___is_Delta: norm_step -> Prims.bool =
  fun projectee  ->
    match projectee with | Delta  -> true | uu____1489 -> false
let uu___is_Zeta: norm_step -> Prims.bool =
  fun projectee  ->
    match projectee with | Zeta  -> true | uu____1493 -> false
let uu___is_Iota: norm_step -> Prims.bool =
  fun projectee  ->
    match projectee with | Iota  -> true | uu____1497 -> false
let uu___is_UnfoldOnly: norm_step -> Prims.bool =
  fun projectee  ->
    match projectee with | UnfoldOnly _0 -> true | uu____1504 -> false
let __proj__UnfoldOnly__item___0: norm_step -> Prims.string Prims.list =
  fun projectee  -> match projectee with | UnfoldOnly _0 -> _0
let steps_Simpl: FStar_Syntax_Syntax.term =
  FStar_Syntax_Syntax.tdataconstr FStar_Parser_Const.steps_simpl
let steps_Weak: FStar_Syntax_Syntax.term =
  FStar_Syntax_Syntax.tdataconstr FStar_Parser_Const.steps_weak
let steps_HNF: FStar_Syntax_Syntax.term =
  FStar_Syntax_Syntax.tdataconstr FStar_Parser_Const.steps_hnf
let steps_Primops: FStar_Syntax_Syntax.term =
  FStar_Syntax_Syntax.tdataconstr FStar_Parser_Const.steps_primops
let steps_Delta: FStar_Syntax_Syntax.term =
  FStar_Syntax_Syntax.tdataconstr FStar_Parser_Const.steps_delta
let steps_Zeta: FStar_Syntax_Syntax.term =
  FStar_Syntax_Syntax.tdataconstr FStar_Parser_Const.steps_zeta
let steps_Iota: FStar_Syntax_Syntax.term =
  FStar_Syntax_Syntax.tdataconstr FStar_Parser_Const.steps_iota
let steps_UnfoldOnly: FStar_Syntax_Syntax.term =
  FStar_Syntax_Syntax.tdataconstr FStar_Parser_Const.steps_unfoldonly
let embed_norm_step:
  FStar_Range.range -> norm_step -> FStar_Syntax_Syntax.term =
  fun rng  ->
    fun n1  ->
      match n1 with
      | Simpl  -> steps_Simpl
      | Weak  -> steps_Weak
      | HNF  -> steps_HNF
      | Primops  -> steps_Primops
      | Delta  -> steps_Delta
      | Zeta  -> steps_Zeta
      | Iota  -> steps_Iota
      | UnfoldOnly l ->
          let uu____1530 =
            let uu____1531 =
              let uu____1532 =
                let uu____1533 =
                  let uu____1534 =
                    embed_list embed_string FStar_Syntax_Syntax.t_string in
                  uu____1534 rng l in
                FStar_Syntax_Syntax.as_arg uu____1533 in
              [uu____1532] in
            FStar_Syntax_Syntax.mk_Tm_app steps_UnfoldOnly uu____1531 in
          uu____1530 FStar_Pervasives_Native.None rng
let __unembed_norm_step:
  Prims.bool ->
    FStar_Syntax_Syntax.term -> norm_step FStar_Pervasives_Native.option
  =
  fun w  ->
    fun t0  ->
      let t = FStar_Syntax_Util.unmeta_safe t0 in
      let uu____1555 = FStar_Syntax_Util.head_and_args t in
      match uu____1555 with
      | (hd1,args) ->
          let uu____1594 =
            let uu____1607 =
              let uu____1608 = FStar_Syntax_Util.un_uinst hd1 in
              uu____1608.FStar_Syntax_Syntax.n in
            (uu____1607, args) in
          (match uu____1594 with
           | (FStar_Syntax_Syntax.Tm_fvar fv,[]) when
               FStar_Syntax_Syntax.fv_eq_lid fv
                 FStar_Parser_Const.steps_simpl
               -> FStar_Pervasives_Native.Some Simpl
           | (FStar_Syntax_Syntax.Tm_fvar fv,[]) when
               FStar_Syntax_Syntax.fv_eq_lid fv FStar_Parser_Const.steps_weak
               -> FStar_Pervasives_Native.Some Weak
           | (FStar_Syntax_Syntax.Tm_fvar fv,[]) when
               FStar_Syntax_Syntax.fv_eq_lid fv FStar_Parser_Const.steps_hnf
               -> FStar_Pervasives_Native.Some HNF
           | (FStar_Syntax_Syntax.Tm_fvar fv,[]) when
               FStar_Syntax_Syntax.fv_eq_lid fv
                 FStar_Parser_Const.steps_primops
               -> FStar_Pervasives_Native.Some Primops
           | (FStar_Syntax_Syntax.Tm_fvar fv,[]) when
               FStar_Syntax_Syntax.fv_eq_lid fv
                 FStar_Parser_Const.steps_delta
               -> FStar_Pervasives_Native.Some Delta
           | (FStar_Syntax_Syntax.Tm_fvar fv,[]) when
               FStar_Syntax_Syntax.fv_eq_lid fv FStar_Parser_Const.steps_zeta
               -> FStar_Pervasives_Native.Some Zeta
           | (FStar_Syntax_Syntax.Tm_fvar fv,[]) when
               FStar_Syntax_Syntax.fv_eq_lid fv FStar_Parser_Const.steps_iota
               -> FStar_Pervasives_Native.Some Iota
           | (FStar_Syntax_Syntax.Tm_fvar fv,(l,uu____1728)::[]) when
               FStar_Syntax_Syntax.fv_eq_lid fv
                 FStar_Parser_Const.steps_unfoldonly
               ->
               let uu____1753 =
                 let uu____1758 = unembed_list unembed_string in uu____1758 l in
               FStar_Util.bind_opt uu____1753
                 (fun ss  ->
                    FStar_All.pipe_left
                      (fun _0_44  -> FStar_Pervasives_Native.Some _0_44)
                      (UnfoldOnly ss))
           | uu____1773 ->
               (if w
                then
                  (let uu____1787 =
                     let uu____1792 =
                       let uu____1793 = FStar_Syntax_Print.term_to_string t0 in
                       FStar_Util.format1 "Not an embedded norm_step: %s"
                         uu____1793 in
                     (FStar_Errors.NotEmbeddedNormStep, uu____1792) in
                   FStar_Errors.maybe_fatal_error t.FStar_Syntax_Syntax.pos
                     uu____1787)
                else ();
                FStar_Pervasives_Native.None))
let unembed_norm_step:
  FStar_Syntax_Syntax.term -> norm_step FStar_Pervasives_Native.option =
  fun t  -> __unembed_norm_step true t
let unembed_norm_step_safe:
  FStar_Syntax_Syntax.term -> norm_step FStar_Pervasives_Native.option =
  fun t  -> __unembed_norm_step false t
let embed_range:
  FStar_Range.range -> FStar_Range.range -> FStar_Syntax_Syntax.term =
  fun rng  ->
    fun r  ->
      FStar_Syntax_Syntax.mk
        (FStar_Syntax_Syntax.Tm_constant (FStar_Const.Const_range r))
        FStar_Pervasives_Native.None rng
let __unembed_range:
  Prims.bool ->
    FStar_Syntax_Syntax.term ->
      FStar_Range.range FStar_Pervasives_Native.option
  =
  fun w  ->
    fun t0  ->
      let t = FStar_Syntax_Util.unmeta_safe t0 in
      match t.FStar_Syntax_Syntax.n with
      | FStar_Syntax_Syntax.Tm_constant (FStar_Const.Const_range r) ->
          FStar_Pervasives_Native.Some r
      | uu____1832 ->
          (if w
           then
             (let uu____1834 =
                let uu____1839 =
                  let uu____1840 = FStar_Syntax_Print.term_to_string t0 in
                  FStar_Util.format1 "Not an embedded range: %s" uu____1840 in
                (FStar_Errors.NotEmbeddedRange, uu____1839) in
              FStar_Errors.maybe_fatal_error t.FStar_Syntax_Syntax.pos
                uu____1834)
           else ();
           FStar_Pervasives_Native.None)
let unembed_range:
  FStar_Syntax_Syntax.term ->
    FStar_Range.range FStar_Pervasives_Native.option
  = fun t  -> __unembed_range true t
let unembed_range_safe:
  FStar_Syntax_Syntax.term ->
    FStar_Range.range FStar_Pervasives_Native.option
  = fun t  -> __unembed_range false t
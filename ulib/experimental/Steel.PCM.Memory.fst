(*
   Copyright 2019 Microsoft Research

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
module Steel.PCM.Memory
module F = FStar.FunctionalExtensionality
open FStar.FunctionalExtensionality
open Steel.PCM

// In the future, we may have other cases of cells
// for arrays and structs
noeq
type cell : Type u#(a + 1) =
  | Ref : a:Type u#a ->
          p:pcm a ->
          v:a ->
          squash (defined p v) ->
          cell

let addr = nat

/// This is just the core of a memory, about which one can write
/// assertions. At one level above, we'll encapsulate this memory
/// with a freshness counter, a lock store etc.
let heap : Type u#(a + 1) = addr ^-> option (cell u#a)

let contains_addr (m:heap) (a:addr)
  : bool
  = Some? (m a)

let select_addr (m:heap) (a:addr{contains_addr m a})
  : cell
  = Some?.v (m a)

let update_addr (m:heap) (a:addr) (c:cell)
  : heap
  = F.on _ (fun a' -> if a = a' then Some c else m a')

let combinable_sym (#a:Type) (pcm:pcm a) (x y: a)
  : Lemma (combinable pcm x y ==>
           combinable pcm y x)
  = pcm.comm x y

let disjoint_cells (c0 c1:cell u#h) : prop =
    let Ref t0 p0 v0 _ = c0 in
    let Ref t1 p1 v1 _ = c1 in
    t0 == t1 /\
    p0 == p1 /\
    combinable p0 v0 v1

let disjoint_cells_sym (c0 c1:cell u#h)
  : Lemma (requires disjoint_cells c0 c1)
          (ensures disjoint_cells c1 c0)
  = let Ref t0 p0 v0 _ = c0 in
    let Ref t1 p1 v1 _ = c1 in
    p0.comm v0 v1

let disjoint_addr (m0 m1:heap u#h) (a:addr)
  : prop
  = match m0 a, m1 a with
    | Some c0, Some c1 ->
      disjoint_cells c0 c1
    | Some _, None
    | None, Some _
    | None, None ->
      True

let ref (a:Type u#a) (pcm:pcm a): Type u#0 = addr

let disjoint (m0 m1:heap u#h)
  : prop
  = forall a. disjoint_addr m0 m1 a

#push-options "--warn_error -271"

let disjoint_sym (m0 m1:heap u#h)
  = let aux (m0 m1:heap u#h) (a:addr)
      : Lemma (requires disjoint_addr m0 m1 a)
              (ensures disjoint_addr m1 m0 a)
              [SMTPat (disjoint_addr m1 m0 a)]
    = match m0 a, m1 a with
      | Some c0, Some c1 -> disjoint_cells_sym c0 c1
      | _ -> ()
    in
    ()

let join_cells (c0:cell u#h) (c1:cell u#h{disjoint_cells c0 c1}) =
  let Ref a0 p0 v0 _ = c0 in
  let Ref a1 p1 v1 _ = c1 in
  Ref a0 p0 (p0.op v0 v1) ()

let join (m0:heap) (m1:heap{disjoint m0 m1})
  : heap
  = F.on _ (fun a ->
      match m0 a, m1 a with
      | None, None -> None
      | None, Some x -> Some x
      | Some x, None -> Some x
      | Some c0, Some c1 ->
        Some (join_cells c0 c1))

let disjoint_join_cells_assoc (c0 c1 c2:cell u#h)
  : Lemma
    (requires disjoint_cells c1 c2 /\
              disjoint_cells c0 (join_cells c1 c2))
    (ensures  disjoint_cells c0 c1 /\
              disjoint_cells (join_cells c0 c1) c2 /\
              join_cells (join_cells c0 c1) c2 == join_cells c0 (join_cells c1 c2))
  = let Ref a0 p0 v0 _ = c0 in
    let Ref a1 p1 v1 _ = c1 in
    let Ref a2 p2 v2 _ = c2 in
    assert (p0 == p1 /\ p1 == p2);
    assert (p0.op v1 v2 =!= p0.undef);
    assert (p0.op v0 (p0.op v1 v2) =!= p0.undef);
    p0.undef_inv v1 v2;
    p0.undef_inv v0 (p0.op v1 v2);
    p0.undef_inv (p0.op v0 v1) v2;
    p0.assoc v0 v1 v2

let disjoint_join' (m0 m1 m2:heap u#h)
  : Lemma (requires disjoint m1 m2 /\
                    disjoint m0 (join m1 m2))
          (ensures  disjoint m0 m1 /\ disjoint (join m0 m1) m2)
          [SMTPat (disjoint (join m0 m1) m2)]
  = let aux (a:addr)
      : Lemma (disjoint_addr m0 m1 a)
              [SMTPat ()]
      = match m0 a, m1 a, m2 a with
        | Some c0, Some c1, Some c2 ->
          disjoint_join_cells_assoc c0 c1 c2
        | _ -> ()
    in
    assert (disjoint m0 m1);
    let aux (a:addr)
      : Lemma (disjoint_addr (join m0 m1) m2 a)
              [SMTPat ()]
      = match m0 a, m1 a, m2 a with
        | Some c0, Some c1, Some c2 ->
          disjoint_join_cells_assoc c0 c1 c2
        | _ -> ()
    in
    ()

let mem_equiv (m0 m1:heap) =
  forall a. m0 a == m1 a

let mem_equiv_eq (m0 m1:heap)
  : Lemma
    (requires
      m0 `mem_equiv` m1)
    (ensures
      m0 == m1)
    [SMTPat (m0 `mem_equiv` m1)]
  = F.extensionality _ _ m0 m1

let join_cells_commutative (c0:cell u#h) (c1:cell u#h{disjoint_cells c0 c1})
  : Lemma (disjoint_cells_sym c0 c1; join_cells c0 c1 == join_cells c1 c0)
          [SMTPat (join_cells c0 c1)]
  = let Ref a0 p0 v0 _ = c0 in
    let Ref a1 p1 v1 _ = c1 in
    p0.comm v0 v1

let join_commutative' (m0 m1:heap)
  : Lemma
    (requires
      disjoint m0 m1)
    (ensures
      join m0 m1 `mem_equiv` join m1 m0)
    [SMTPat (join m0 m1)]
  = ()

let join_commutative m0 m1 = ()

let disjoint_join (m0 m1 m2:heap)
  : Lemma (disjoint m1 m2 /\
           disjoint m0 (join m1 m2) ==>
           disjoint m0 m1 /\
           disjoint m0 m2 /\
           disjoint (join m0 m1) m2 /\
           disjoint (join m0 m2) m1)
          [SMTPat (disjoint m0 (join m1 m2))]
  = let aux ()
      : Lemma
        (requires disjoint m1 m2 /\
                  disjoint m0 (join m1 m2))
        (ensures  disjoint m0 m1 /\
                  disjoint m0 m2 /\
                  disjoint (join m0 m1) m2 /\
                  disjoint (join m0 m2) m1)
        [SMTPat ()]
      = disjoint_join' m0 m1 m2;
        join_commutative m0 m1;
        disjoint_join' m0 m2 m1
    in
    ()

let join_associative' (m0 m1 m2:heap)
  : Lemma
    (requires
      disjoint m1 m2 /\
      disjoint m0 (join m1 m2))
    (ensures
      (disjoint_join m0 m1 m2;
       join m0 (join m1 m2) `mem_equiv` join (join m0 m1) m2))
    [SMTPatOr
      [[SMTPat (join m0 (join m1 m2))];
       [SMTPat (join (join m0 m1) m2)]]]
  = disjoint_join m0 m1 m2;
    let l = join m0 (join m1 m2) in
    let r = join (join m0 m1) m2 in
    let aux (a:addr)
        : Lemma (l a == r a)
                [SMTPat ()]
        = match m0 a, m1 a, m2 a with
          | Some c0, Some c1, Some c2 ->
            disjoint_join_cells_assoc c0 c1 c2
          | _ -> ()
    in
    ()

let join_associative (m0 m1 m2:heap) = join_associative' m0 m1 m2

let join_associative2 (m0 m1 m2:heap)
  : Lemma
    (requires
      disjoint m0 m1 /\
      disjoint (join m0 m1) m2)
    (ensures
      disjoint m1 m2 /\
      disjoint m0 (join m1 m2) /\
      join m0 (join m1 m2) `mem_equiv` join (join m0 m1) m2)
    [SMTPat (join (join m0 m1) m2)]
  = disjoint_join m2 m0 m1;
    join_commutative (join m0 m1) m2;
    join_associative m2 m0 m1

let heap_prop_is_affine (p:heap -> prop) =
  forall m0 m1. p m0 /\ disjoint m0 m1 ==> p (join m0 m1)
let a_heap_prop : Type u#(a + 1) =
  p:(heap u#a -> prop) { heap_prop_is_affine p }

////////////////////////////////////////////////////////////////////////////////

module W = FStar.WellFounded

[@erasable]
noeq
type slprop : Type u#(a + 1) =
  | Emp : slprop
  | Pts_to : #a:Type u#a -> #pcm:pcm a -> r:ref a pcm -> v:a -> slprop
  | Refine : slprop u#a -> a_heap_prop u#a -> slprop
  | And    : slprop u#a -> slprop u#a -> slprop
  | Or     : slprop u#a -> slprop u#a -> slprop
  | Star   : slprop u#a -> slprop u#a -> slprop
  | Wand   : slprop u#a -> slprop u#a -> slprop
  | Ex     : #a:Type u#a -> (a -> slprop u#a) -> slprop
  | All    : #a:Type u#a -> (a -> slprop u#a) -> slprop

let interp_cell (p:slprop u#a) (c:cell u#a) =
  let Ref a' pcm' v' _ = c in
  match p with
  | Pts_to #a #pcm r v ->
    a == a' /\
    pcm == pcm' /\
    compatible pcm v v'
  | _ -> False

let rec interp (p:slprop u#a) (m:heap u#a)
  : Tot prop (decreases p)
  = match p with
    | Emp -> True
    | Pts_to #a #pcm r v ->
      m `contains_addr` r /\
      interp_cell p (select_addr m r)

    | Refine p q ->
      interp p m /\ q m

    | And p1 p2 ->
      interp p1 m /\
      interp p2 m

    | Or  p1 p2 ->
      interp p1 m \/
      interp p2 m

    | Star p1 p2 ->
      exists m1 m2.
        m1 `disjoint` m2 /\
        m == join m1 m2 /\
        interp p1 m1 /\
        interp p2 m2

    | Wand p1 p2 ->
      forall m1.
        m `disjoint` m1 /\
        interp p1 m1 ==>
        interp p2 (join m m1)

    | Ex f ->
      exists x. (W.axiom1 f x; interp (f x) m)

    | All f ->
      forall x. (W.axiom1 f x; interp (f x) m)

let emp : slprop u#a = Emp
let pts_to = Pts_to
let h_and = And
let h_or = Or
let star = Star
let wand = Wand
let h_exists = Ex
let h_forall = All

////////////////////////////////////////////////////////////////////////////////
//properties of equiv
////////////////////////////////////////////////////////////////////////////////

let equiv_symmetric (p1 p2:slprop u#a) = ()
let equiv_extensional_on_star (p1 p2 p3:slprop u#a) = ()

////////////////////////////////////////////////////////////////////////////////
//pts_to
////////////////////////////////////////////////////////////////////////////////

let intro_pts_to (#a:_) (#pcm:pcm a) (x:ref a pcm) (v:a) (m:heap)
  : Lemma
    (requires
       m `contains_addr` x /\
       (let Ref a' pcm' v' _ = select_addr m x in
        a == a' /\
        pcm == pcm' /\
        compatible pcm v v'))
     (ensures
       interp (pts_to x v) m)
  = ()

let pts_to_compatible (#a:Type u#a)
                      (#pcm:_)
                      (x:ref a pcm)
                      (v0 v1:a)
                      (m:heap u#a)
  : Lemma
    (requires
      interp (pts_to x v0 `star` pts_to x v1) m)
    (ensures
      combinable pcm v0 v1 /\
      interp (pts_to x (pcm.op v0 v1)) m)
  = let c = select_addr m x in
    let Ref _ _ v _ = select_addr m x in
    let aux (c0 c1: cell u#a)
      : Lemma
        (requires
           c0 `disjoint_cells` c1 /\
           interp_cell (pts_to x v0) c0 /\
           interp_cell (pts_to x v1) c1 /\
           c == join_cells c0 c1 )
        (ensures
           combinable pcm v0 v1 /\
           interp (pts_to x (pcm.op v0 v1)) m)
        [SMTPat (c0 `disjoint_cells` c1)]
      = let Ref _ _ v0' _ = c0 in
        let Ref _ _ v1' _ = c1 in
        assert (exists frame. pcm.op frame v0 == v0');
        assert (exists frame. pcm.op frame v1 == v1');
        assert (pcm.op v0' v1' == v);
        assert (v =!= pcm.undef);
        let aux (frame0 frame1:a)
          : Lemma
            (requires
              pcm.op frame0 v0 == v0' /\
              pcm.op frame1 v1 == v1' /\
              pcm.op v0' v1' == v)
            (ensures (
              let frame = pcm.op frame0 frame1 in
              pcm.op frame (pcm.op v0 v1) == v /\
              pcm.op v0 v1 =!= pcm.undef))
            [SMTPat(pcm.op frame0 v0);
             SMTPat(pcm.op frame1 v1)]
          = assert (pcm.op (pcm.op frame0 v0) (pcm.op frame1 v1) == v);
            pcm.assoc frame0 v0 (pcm.op frame1 v1);
            assert (pcm.op frame0 (pcm.op v0 (pcm.op frame1 v1)) == v);
            pcm.comm frame1 v1;
            assert (pcm.op frame0 (pcm.op v0 (pcm.op v1 frame1)) == v);
            pcm.assoc v0 v1 frame1;
            assert (pcm.op frame0 (pcm.op (pcm.op v0 v1) frame1) == v);
            pcm.comm (pcm.op v0 v1) frame1;
            pcm.assoc frame0 frame1 (pcm.op v0 v1);
            pcm.undef_inv (pcm.op frame0 frame1) (pcm.op v0 v1)
        in
        ()
    in
    assert (exists c0 c1.
              c0 `disjoint_cells` c1 /\
              interp_cell (pts_to x v0) c0 /\
              interp_cell (pts_to x v1) c1 /\
              c == join_cells c0 c1)

////////////////////////////////////////////////////////////////////////////////
// star
////////////////////////////////////////////////////////////////////////////////

let intro_star (p q:slprop) (mp:hheap p) (mq:hheap q)
  : Lemma
    (requires
      disjoint mp mq)
    (ensures
      interp (p `star` q) (join mp mq))
  = ()


(* Properties of star *)

let star_commutative (p1 p2:slprop) = ()

let star_associative (p1 p2 p3:slprop)
  = let ltor (m m1 m2 m3:heap)
    : Lemma
      (requires
        disjoint m2 m3 /\
        disjoint m1 (join m2 m3) /\
        m == join m1 (join m2 m3) /\
        interp p1 m1 /\
        interp p2 m2 /\
        interp p3 m3 /\
        interp (p1 `star` (p2 `star` p3)) m)
      (ensures
        disjoint m1 m2 /\
        disjoint (join m1 m2) m3 /\
        m == join (join m1 m2) m3 /\
        interp (p1 `star` p2) (join m1 m2) /\
        interp ((p1 `star` p2) `star` p3) m)
      [SMTPat()]
    = disjoint_join m1 m2 m3;
      join_associative m1 m2 m3;
      intro_star p1 p2 m1 m2;
      intro_star (p1 `star` p2) p3 (join m1 m2) m3
   in
   let rtol (m m1 m2 m3:heap)
    : Lemma
      (requires
        disjoint m1 m2 /\
        disjoint (join m1 m2) m3 /\
        m == join (join m1 m2) m3 /\
        interp p1 m1 /\
        interp p2 m2 /\
        interp p3 m3 /\
        interp ((p1 `star` p2) `star` p3) m)
      (ensures
        disjoint m2 m3 /\
        disjoint m1 (join m2 m3) /\
        m == join m1 (join m2 m3) /\
        interp (p2 `star` p3) (join m2 m3) /\
        interp (p1 `star`(p2 `star` p3)) m)
      [SMTPat()]
    = join_associative2 m1 m2 m3;
      intro_star p2 p3 m2 m3;
      intro_star p1 (p2 `star` p3) m1 (join m2 m3)
   in
   ()

let star_congruence (p1 p2 p3 p4:slprop) = ()


////////////////////////////////////////////////////////////////////////////////
// sel
////////////////////////////////////////////////////////////////////////////////
let sel #a #pcm (r:ref a pcm) (m:hheap (ptr r))
  : a
  = let Ref _ _ v _ = select_addr m r in
    v

let sel_lemma (#a:_) (#pcm:_) (r:ref a pcm) (m:hheap (ptr r))
  : Lemma (interp (pts_to r (sel r m)) m)
  = let Ref _ _ v _ = select_addr m r in
    assert (sel r m == v);
    assert (defined pcm v);
    compatible_refl pcm v

let sel_action (#a:_) (#pcm:_) (r:ref a pcm) (v0:erased a)
  : action (pts_to r v0) (v:a{compatible pcm v0 v}) (fun _ -> pts_to r v0)
  = let f
      : pre_action (pts_to r v0)
                   (v:a{compatible pcm v0 v})
                   (fun _ -> pts_to r v0)
      = fun m0 -> (| sel r m0, m0 |)
    in
    f


let update_defined #a pcm (v0:a{defined pcm v0}) (v1:a{frame_preserving pcm v0 v1})
  : Lemma (defined pcm v1)
  = pcm.is_unit v0; pcm.is_unit v1;
    assert (defined pcm (pcm.op v0 pcm.one));
    assert (v1 =!= pcm.undef)

let frame_preserving #a (pcm:pcm a) (x y: a) =
  Steel.PCM.frame_preserving pcm x y /\
  (forall frame.{:pattern (combinable pcm frame x)}  combinable pcm frame x ==> pcm.op frame y == y)

let upd' (#a:_) (#pcm:_) (r:ref a pcm) (v0:FStar.Ghost.erased a) (v1:a {frame_preserving pcm v0 v1})
  : pre_action (pts_to r v0) unit (fun _ -> pts_to r v1)
  = fun h ->
    update_defined pcm v0 v1;
    let cell = Ref a pcm v1 () in
    let h' = update_addr h r cell in
    assert (h' `contains_addr` r);
    compatible_refl pcm v1;
    assert (interp_cell (pts_to r v1) cell);
    assert (interp (pts_to r v1) h');
    (| (), h' |)


let definedness #a #pcm (v0:a{defined pcm v0}) (v0_val:a{defined pcm v0_val}) (v1:a{defined pcm v1}) (vf:a{defined pcm vf})
  : Lemma (requires
             compatible pcm v0 v0_val /\
             combinable pcm v0_val vf /\
             frame_preserving pcm v0 v1)
          (ensures
             combinable pcm v1 vf)
  = assert (exists vf'. pcm.op vf' v0 == v0_val);
    let aux (vf':a {pcm.op vf' v0 == v0_val})
      : Lemma (combinable pcm v1 vf)
              [SMTPat(pcm.op vf' v0)]
        = pcm.undef_inv vf' v0;
          assert (defined pcm vf');
          assert (combinable pcm (pcm.op vf' v0) vf);
          pcm.comm (pcm.op vf' v0) vf;
          pcm.assoc vf vf' v0;
          pcm.comm (pcm.op vf vf') v0;
          assert (combinable pcm v0 (pcm.op vf vf'));
          assert (combinable pcm v1 (pcm.op vf vf'));
          pcm.assoc v1 vf vf';
          assert (combinable pcm (pcm.op v1 vf) vf');
          pcm.undef_inv v1 vf;
          pcm.undef_inv (pcm.op v1 vf) vf';
          assert (combinable pcm v1 vf)
    in
    ()

let combinable_compatible #a pcm (x y z:a)
  : Lemma (requires compatible pcm x y /\
                    combinable pcm y z)
          (ensures combinable pcm x z /\
                   combinable pcm z x)
  = let aux (f:a{pcm.op f x == y})
      : Lemma (combinable pcm x z /\
               combinable pcm z x)
              [SMTPat (pcm.op f x)]
      = assert (combinable pcm (pcm.op f x) z);
        pcm.assoc f x z;
        assert (combinable pcm f (pcm.op x z));
        pcm.undef_inv f (pcm.op x z);
        pcm.comm x z
    in
    let s : squash (exists f. pcm.op f x == y) = () in
    ()

let pts_to_defined #a #pcm (r:ref a pcm) (v:a) (m:hheap (pts_to r v))
  : Lemma (defined pcm v)
  = ()

#push-options "--z3rlimit_factor 2"
let upd_lemma' (#a:_) #pcm (r:ref a pcm)
               (v0:Ghost.erased a) (v1:a {frame_preserving pcm v0 v1})
               (h:hheap (pts_to r v0)) (frame:slprop)
  : Lemma
    (requires
      interp (pts_to r v0 `star` frame) h)
    (ensures (
      (let (| x, h1 |) = upd' r v0 v1 h in
       interp (pts_to r v1 `star` frame) h1)))
  = assert (defined pcm v0); update_defined pcm v0 v1;
    let aux (h0 hf:heap)
     : Lemma
       (requires
         disjoint h0 hf /\
         h == join h0 hf /\
         interp (pts_to r v0) h0 /\
         interp frame hf)
       (ensures (
         let (| _, h' |) = upd' r v0 v1 h in
         let h0' = update_addr h0 r (Ref a pcm v1 ()) in
         disjoint h0' hf /\
         interp (pts_to r v1) h0' /\
         interp frame hf /\
         h' == join h0' hf))
       [SMTPat (disjoint h0 hf)]
     = let (| _, h'|) = upd' r v0 v1 h in
       let cell1 = (Ref a pcm v1 ()) in
       let h0' = update_addr h0 r cell1 in
       assert (interp (pts_to r v1) h0');
       assert (interp frame hf);
       let aux (a:addr)
         : Lemma (disjoint_addr h0' hf a )
                 [SMTPat (disjoint_addr h0' hf a)]
         = if a <> r then ()
           else match h0 a, h0' a, hf a with
                | Some (Ref a0 p0 v0_val _),
                  Some (Ref a0' p0' v0' _),
                  Some (Ref af pf vf _) ->
                  assert (a0' == af);
                  assert (p0' == pf);
                  assert (v0' == v1);
                  assert (compatible pcm v0 v0_val);

                  compatible_refl pcm vf;
                  assert (interp_cell (pts_to r vf) (Some?.v (hf a)));
                  assert (interp (pts_to r vf) hf);

                  compatible_refl pcm v0_val;
                  assert (interp_cell (pts_to r v0_val) (Some?.v (h0 a)));
                  assert (interp (pts_to r v0_val) h0);
                  assert (interp (pts_to r v0_val `star` pts_to r vf) h);
                  pts_to_compatible r v0_val vf h;
                  assert (combinable pcm v0_val vf);

                  assert (interp (pts_to r (pcm.op v0_val vf)) h);
                  pcm.comm v0_val vf;
                  assert (defined pcm (pcm.op vf v0_val));
                  definedness #_ #pcm v0 v0_val v1 vf;
                  assert (combinable pcm v1 vf)
                | _ -> ()
       in
       assert (disjoint h0' hf);
       let aux (a:addr)
         : Lemma (h' a == (join h0' hf) a)
                 [SMTPat ()]
         = if a <> r
           then ()
           else begin
             assert (h' a == Some cell1);
             assert (h0' a == Some cell1);
             match h0 a, hf a with
             | _, None -> ()
             | Some (Ref a0 p0 v0_val _),
               Some (Ref af pf vf _) ->
               let c0 = Some?.v (h0 a) in
               let cf = Some?.v (hf a) in
               assert (a0 == af);
               assert (p0 == pf);
               assert (compatible pcm v0 v0_val);
               assert (disjoint_cells c0 cf);
               assert (combinable pcm v0_val vf);
               combinable_compatible pcm v0 v0_val vf;
               assert (combinable pcm v0 vf);
               assert (disjoint_cells cell1 cf);
               assert (combinable pcm v1 vf);
               assert (combinable pcm vf v0);
               assert (pcm.op vf v1 == v1);
               pcm.comm vf v1
           end
       in
       assert (mem_equiv h' (join h0' hf))
   in
   ()
#pop-options

let upd_action (#a:_) (#pcm:_) (r:ref a pcm) (v0:FStar.Ghost.erased a) (v1:a {frame_preserving pcm v0 v1})
  : action (pts_to r v0) unit (fun _ -> pts_to r v1)
  = let aux (h:hheap (pts_to r v0)) (frame:slprop)
    : Lemma
      (requires
        interp (pts_to r v0 `star` frame) h)
      (ensures (
        (let (| x, h1 |) = upd' r v0 v1 h in
        interp (pts_to r v1 `star` frame) h1)))
      [SMTPat ( interp (pts_to r v0 `star` frame) h)]
    = upd_lemma' r v0 v1 h frame
    in
    upd' r v0 v1


////////////////////////////////////////////////////////////////////////////////
// wand
////////////////////////////////////////////////////////////////////////////////
let intro_wand_alt (p1 p2:slprop) (m:heap)
  : Lemma
    (requires
      (forall (m0:hheap p1).
         disjoint m0 m ==>
         interp p2 (join m0 m)))
    (ensures
      interp (wand p1 p2) m)
  = ()

let intro_wand (p q r:slprop) (m:hheap q)
  : Lemma
    (requires
      (forall (m:hheap (p `star` q)). interp r m))
    (ensures
      interp (p `wand` r) m)
  = let aux (m0:hheap p)
      : Lemma
        (requires
          disjoint m0 m)
        (ensures
          interp r (join m0 m))
        [SMTPat (disjoint m0 m)]
      = ()
    in
    intro_wand_alt p r m

let elim_wand (p1 p2:slprop) (m:heap) = ()

////////////////////////////////////////////////////////////////////////////////
// or
////////////////////////////////////////////////////////////////////////////////

let intro_or_l (p1 p2:slprop) (m:hheap p1)
  : Lemma (interp (h_or p1 p2) m)
  = ()

let intro_or_r (p1 p2:slprop) (m:hheap p2)
  : Lemma (interp (h_or p1 p2) m)
  = ()

let or_star (p1 p2 p:slprop) (m:hheap ((p1 `star` p) `h_or` (p2 `star` p)))
  : Lemma (interp ((p1 `h_or` p2) `star` p) m)
  = ()

let elim_or (p1 p2 q:slprop) (m:hheap (p1 `h_or` p2))
  : Lemma (((forall (m:hheap p1). interp q m) /\
            (forall (m:hheap p2). interp q m)) ==> interp q m)
  = ()


////////////////////////////////////////////////////////////////////////////////
// and
////////////////////////////////////////////////////////////////////////////////

let intro_and (p1 p2:slprop) (m:heap)
  : Lemma (interp p1 m /\
           interp p2 m ==>
           interp (p1 `h_and` p2) m)
  = ()

let elim_and (p1 p2:slprop) (m:hheap (p1 `h_and` p2))
  : Lemma (interp p1 m /\
           interp p2 m)
  = ()


////////////////////////////////////////////////////////////////////////////////
// h_exists
////////////////////////////////////////////////////////////////////////////////

let intro_exists (#a:_) (x:a) (p : a -> slprop) (m:hheap (p x))
  : Lemma (interp (h_exists p) m)
  = ()

let elim_exists (#a:_) (p:a -> slprop) (q:slprop) (m:hheap (h_exists p))
  : Lemma
    ((forall (x:a). interp (p x) m ==> interp q m) ==>
     interp q m)
  = ()


////////////////////////////////////////////////////////////////////////////////
// h_forall
////////////////////////////////////////////////////////////////////////////////

let intro_forall (#a:_) (p : a -> slprop) (m:heap)
  : Lemma ((forall x. interp (p x) m) ==> interp (h_forall p) m)
  = ()

let elim_forall (#a:_) (p : a -> slprop) (m:hheap (h_forall p))
  : Lemma ((forall x. interp (p x) m) ==> interp (h_forall p) m)
  = ()

////////////////////////////////////////////////////////////////////////////////


#push-options "--z3rlimit_factor 6 --max_fuel 1 --max_ifuel 2  --initial_fuel 2 --initial_ifuel 2"
#push-options "--warn_error -271" //local patterns miss variables; ok
let rec affine_star_aux (p:slprop) (m:heap) (m':heap { disjoint m m' })
  : Lemma
    (ensures interp p m ==> interp p (join m m'))
    [SMTPat (interp p (join m m'))]
  = match p with
    | Emp -> ()

    | Pts_to _ _ _ -> ()

    | Refine p q -> affine_star_aux p m m'

    | And p1 p2 -> affine_star_aux p1 m m'; affine_star_aux p2 m m'

    | Or p1 p2 -> affine_star_aux p1 m m'; affine_star_aux p2 m m'

    | Star p1 p2 ->
      let aux (m1 m2:heap) (m':heap {disjoint m m'})
        : Lemma
          (requires
            disjoint m1 m2 /\
            m == join m1 m2 /\
            interp p1 m1 /\
            interp p2 m2)
          (ensures interp (Star p1 p2) (join m m'))
          [SMTPat (interp (Star p1 p2) (join (join m1 m2) m'))]
        = affine_star_aux p2 m2 m';
          // assert (interp p2 (join m2 m'));
          affine_star_aux p1 m1 (join m2 m');
          // assert (interp p1 (join m1 (join m2 m')));
          join_associative m1 m2 m';
          // assert (disjoint m1 (join m2 m'));
          intro_star p1 p2 m1 (join m2 m')
      in
      ()

    | Wand p q ->
      let aux (mp:hheap p)
        : Lemma
          (requires
            disjoint mp (join m m') /\
            interp (wand p q) m)
          (ensures (interp q (join mp (join m m'))))
          [SMTPat  ()]
        = disjoint_join mp m m';
          assert (disjoint mp m);
          assert (interp q (join mp m));
          join_associative mp m m';
          affine_star_aux q (join mp m) m'
      in
      assert (interp (wand p q) m ==> interp (wand p q) (join m m'))

    | Ex #a f ->
      let aux (x:a)
        : Lemma (ensures interp (f x) m ==> interp (f x) (join m m'))
                [SMTPat ()]
        = W.axiom1 f x;
          affine_star_aux (f x) m m'
      in
      ()

    | All #a f ->
      let aux (x:a)
        : Lemma (ensures interp (f x) m ==> interp (f x) (join m m'))
                [SMTPat ()]
        = W.axiom1 f x;
          affine_star_aux (f x) m m'
      in
      ()
#pop-options
#pop-options

let affine_star (p q:slprop) (m:heap)
  : Lemma
    (ensures (interp (p `star` q) m ==> interp p m /\ interp q m))
  = ()

////////////////////////////////////////////////////////////////////////////////
// emp
////////////////////////////////////////////////////////////////////////////////

let intro_emp (m:heap)
  : Lemma (interp emp m)
  = ()

let emp_unit (p:slprop)
  : Lemma
    ((p `star` emp) `equiv` p)
  = let emp_unit_1 (p:slprop) (m:heap)
      : Lemma
        (requires interp p m)
        (ensures  interp (p `star` emp) m)
        [SMTPat (interp (p `star` emp) m)]
      = let emp_m : heap = F.on _ (fun _ -> None) in
        assert (disjoint emp_m m);
        assert (interp (p `star` emp) (join m emp_m));
        assert (mem_equiv m (join m emp_m));
        intro_star p emp m emp_m
    in
    let emp_unit_2 (p:slprop) (m:heap)
      : Lemma
        (requires interp (p `star` emp) m)
        (ensures interp p m)
        [SMTPat (interp (p `star` emp) m)]
      = affine_star p emp m
    in
    ()

////////////////////////////////////////////////////////////////////////////////
// Frameable heap predicates
////////////////////////////////////////////////////////////////////////////////
let weaken_depends_only_on (q:heap -> prop) (fp fp': slprop)
  : Lemma (depends_only_on q fp ==> depends_only_on q (fp `star` fp'))
  = ()

let refine (p:slprop) (q:fp_prop p) : slprop = Refine p q

let refine_equiv (p:slprop) (q:fp_prop p) (h:heap)
  : Lemma (interp p h /\ q h <==> interp (Refine p q) h)
  = ()

let refine_star (p0 p1:slprop) (q:fp_prop p0)
  : Lemma (equiv (Refine (p0 `star` p1) q) (Refine p0 q `star` p1))
  = ()

let refine_star_r (p0 p1:slprop) (q:fp_prop p1)
  : Lemma (equiv (Refine (p0 `star` p1) q) (p0 `star` Refine p1 q))
  = ()

let interp_depends_only (p:slprop)
  : Lemma (interp p `depends_only_on` p)
  = ()

let refine_elim (p:slprop) (q:fp_prop p) (h:heap)
  : Lemma (requires
            interp (Refine p q) h)
          (ensures
            interp p h /\ q h)
  = refine_equiv p q h

#push-options "--z3rlimit_factor 4 --query_stats"
let frame_fp_prop' #fp #a #fp' frame
                   (q:fp_prop frame)
                   (act:action fp a fp')
                   (h0:hheap (fp `star` frame))
   : Lemma (requires q h0)
           (ensures (
             let (| x, h1 |) = act h0 in
             q h1))
   = assert (interp (Refine (fp `star` frame) q) h0);
     assert (interp (fp `star` (Refine frame q)) h0);
     let (| x, h1 |) = act h0 in
     assert (interp (fp' x `star` (Refine frame q)) h1);
     refine_star_r (fp' x) frame q;
     assert (interp (Refine (fp' x `star` frame) q) h1);
     assert (q h1)

let frame_fp_prop #fp #a #fp' (act:action fp a fp')
                  (#frame:slprop) (q:fp_prop frame)
   = let aux (h0:hheap (fp `star` frame))
       : Lemma
         (requires q h0)
         (ensures
           (let (|x, h1|) = act h0 in
            q h1))
         [SMTPat (act h0)]
       = frame_fp_prop' frame q act h0
     in
     ()
#pop-options


let test_q (pre:_) (a:_) (post:_)
           (k:(x:a -> fp_prop (post x))) : fp_prop pre =
  fun (h:heap) ->
    interp pre h /\
    (forall (f:action pre a post).
      let (| x, h' |) = f h in
      k x h')


////////////////////////////////////////////////////////////////////////////////
// allocation and locks
////////////////////////////////////////////////////////////////////////////////
noeq
type lock_state =
  | Available : slprop -> lock_state
  | Locked    : slprop -> lock_state

let lock_store = list lock_state

let rec lock_store_invariant (l:lock_store) : slprop =
  match l with
  | [] -> emp
  | Available h :: tl -> h `star` lock_store_invariant tl
  | _ :: tl -> lock_store_invariant tl

noeq
type mem = {
  ctr: nat;
  heap: heap;
  locks: lock_store;
  properties: squash (
    (forall i. i >= ctr ==> heap i == None) /\
    interp (lock_store_invariant locks) heap
  )
}

let heap_of_mem (x:mem) : heap = x.heap

let alloc #a v frame m
  = let x : ref a = m.ctr in
    let cell = Ref a full_permission v in
    let mem : heap = F.on _ (fun i -> if i = x then Some cell else None) in
    assert (disjoint mem m.heap);
    assert (mem `contains_addr` x);
    assert (select_addr mem x == cell);
    let mem' = join mem m.heap in
    intro_pts_to x full_permission v mem;
    assert (interp (pts_to x full_permission v) mem);
    assert (interp frame m.heap);
    intro_star (pts_to x full_permission v) frame mem m.heap;
    assert (interp (pts_to x full_permission v `star` frame) mem');
    let t = {
      ctr = x + 1;
      heap = mem';
      locks = m.locks;
      properties = ();
    } in
    (| x, t |)

let mem_invariant (m:mem) : slprop = lock_store_invariant m.locks

let hmem (fp:slprop) = m:mem{interp (fp `star` mem_invariant m) (heap_of_mem m)}

let pre_m_action (fp:slprop) (a:Type) (fp':a -> slprop) =
  hmem fp -> (x:a & hmem (fp' x))

let is_m_frame_preserving #a #fp #fp' (f:pre_m_action fp a fp') =
  forall frame (m0:hmem (fp `star` frame)).
    (affine_star fp frame (heap_of_mem m0);
     let (| x, m1 |) = f m0 in
     interp (fp' x `star` frame `star` mem_invariant m1) (heap_of_mem m1))

let m_action (fp:slprop) (a:Type) (fp':a -> slprop) =
  f:pre_m_action fp a fp'{ is_m_frame_preserving f }

val alloc_action (#a:_) (v:a)
  : m_action emp (ref a) (fun x -> pts_to x full_permission v)

#push-options "--z3rlimit_factor 4 --query_stats"
let singleton_heap #a (x:ref a) (c:cell) : heap =
    F.on _ (fun i -> if i = x then Some c else None)

let singleton_pts_to #a (x:ref a) (c:cell)
  : Lemma (requires (Ref?.a c == a))
          (ensures (interp (pts_to x (Ref?.perm c) (Ref?.v c)) (singleton_heap x c)))
  = ()

let alloc_pre_m_action (#a:_) (v:a)
  : pre_m_action emp (ref a) (fun x -> pts_to x full_permission v)
  = fun m ->
    let x : ref a = m.ctr in
    let cell = Ref a full_permission v in
    let mem : heap = singleton_heap x cell in
    assert (disjoint mem m.heap);
    assert (mem `contains_addr` x);
    assert (select_addr mem x == cell);
    let mem' = join mem m.heap in
    intro_pts_to x full_permission v mem;
    assert (interp (pts_to x full_permission v) mem);
    let frame = (lock_store_invariant m.locks) in
    assert (interp frame m.heap);
    intro_star (pts_to x full_permission v) frame mem m.heap;
    assert (interp (pts_to x full_permission v `star` frame) mem');
    let t = {
      ctr = x + 1;
      heap = mem';
      locks = m.locks;
      properties = ();
    } in
    (| x, t |)
#pop-options

#push-options "--z3rlimit_factor 4 --query_stats"
let alloc_is_frame_preserving' (#a:_) (v:a) (m:mem) (frame:slprop)
  : Lemma
    (requires
      interp (frame `star` mem_invariant m) (heap_of_mem m))
    (ensures (
      let (| x, m1 |) = alloc_pre_m_action v m in
      interp (pts_to x full_permission v `star` frame `star` mem_invariant m1) (heap_of_mem m1)))
  = let (| x, m1 |) = alloc_pre_m_action v m in
    assert (x == m.ctr);
    assert (m1.ctr = m.ctr + 1);
    assert (m1.locks == m.locks);
    let h = heap_of_mem m in
    let h1 = heap_of_mem m1 in
    let cell = (Ref a full_permission v) in
    assert (h1 == join (singleton_heap x cell) h);
    intro_pts_to x full_permission v (singleton_heap x cell);
    singleton_pts_to x cell;
    assert (interp (pts_to x full_permission v) (singleton_heap x cell));
    assert (interp (frame `star` mem_invariant m) h);
    intro_star (pts_to x full_permission v) (frame `star` mem_invariant m) (singleton_heap x cell) h;
    assert (interp (pts_to x full_permission v `star` (frame `star` mem_invariant m)) h1);
    star_associative (pts_to x full_permission v) frame (mem_invariant m);
    assert (interp (pts_to x full_permission v `star` frame `star` mem_invariant m) h1)
#pop-options

#push-options "--warn_error -271 --z3rlimit_factor 4"
let alloc_is_frame_preserving (#a:_) (v:a)
  : Lemma (is_m_frame_preserving (alloc_pre_m_action v))
  = let aux (frame:slprop) (m:hmem (emp `star` frame))
      : Lemma
          (ensures (
            let (| x, m1 |) = alloc_pre_m_action v m in
            interp (pts_to x full_permission v `star` frame `star` mem_invariant m1) (heap_of_mem m1)))
          [SMTPat ()]
      = alloc_is_frame_preserving' v m frame
    in
    ()
#pop-options

let alloc_m_action (#a:_) (v:a)
  : m_action emp (ref a) (fun x -> pts_to x full_permission v)
  = alloc_is_frame_preserving v;
    alloc_pre_m_action v

let m_disjoint (m:mem) (h:heap) =
  disjoint (heap_of_mem m) h /\
  (forall i. i >= m.ctr ==> h i == None)

let m_action_framing #pre #a #post (f:m_action pre a post)
  = forall (m0:hmem pre)
      (h1:heap {m_disjoint m0 h1})
      (post: (x:a -> fp_prop (post x))).
      (let h0 = heap_of_mem m0 in
       let h = join h0 h1 in
       let m1 = { m0 with heap = h } in
       let (| x0, m |) = f m0 in
       let (| x1, m' |) = f m1 in
       x0 == x1 /\
       (post x0 (heap_of_mem m) <==> post x1 (heap_of_mem m')))
#push-options "--query_stats --z3rlimit_factor 4"
// let test2 (#a:_) (v:a) (m0:hmem emp)
//           (h1:heap {m_disjoint m0 h1})
//           (post: (x:ref a -> fp_prop (pts_to x full_permission v)))
//    = let h0 = heap_of_mem m0 in
//      let h = join h0 h1 in
//      let m1 = { m0 with heap = h } in
//      let (| x0, m |) = alloc_m_action v m0 in
//      let (| x1, m' |) = alloc_m_action v m1 in
//      assert (x0 == x1);
//      // assert (forall (x0:ref a). post x0 `depends_only_on` (pts_to x0 full_permission v));
//      // let post' :fp_prop (pts_to x0 full_permission v) = post x0 in
//      // assert (post' `depends_only_on` (pts_to x0 full_permission v));
//      let h = heap_of_mem m in
//      let h' = heap_of_mem m' in
//      let s = singleton_heap x0 (Ref a full_permission v) in
//      singleton_pts_to x0 (Ref a full_permission v);
//      assume (disjoint s h0);
//      assume (disjoint s (join h0 h1));
//      assume (h `mem_equiv` join s h0);
//      assume (h' `mem_equiv` join s (join h0 h1));
//      // assert (h' `mem_equiv` join (singleton_heap x0 (Ref a full_permission v)) (join h0 h1));
//      let post' : fp_prop (pts_to x0 full_permission v) = post x0 in
//      let s : hheap (pts_to x0 full_permission v) = s in
//      assert (post' h <==> post' s);
//      assert (post' h' <==> post' s);
//      assert (post x0 h <==> post x1 h')

let lock (p:slprop) = nat

module L = FStar.List.Tot

let new_lock_pre_m_action (p:slprop)
  : pre_m_action p (lock p) (fun _ -> emp)
  = fun m ->
     let l = Available p in
     let locks' = l :: m.locks in
     assert (interp (lock_store_invariant locks') (heap_of_mem m));
     let mem :mem = { m with locks = locks' } in
     assert (mem_invariant mem == p `star` mem_invariant m);
     assert (interp (mem_invariant mem) (heap_of_mem mem));
     emp_unit (mem_invariant mem);
     star_commutative emp (mem_invariant mem);
     assert (interp (emp `star` mem_invariant mem) (heap_of_mem mem));
     let lock_id = List.Tot.length locks' - 1 in
     (| lock_id, mem |)

let emp_unit_left (p:slprop)
  : Lemma
    ((emp `star` p) `equiv` p)
  = emp_unit p;
    star_commutative emp p

let equiv_star_left (p q r:slprop)
  : Lemma
    (requires q `equiv` r)
    (ensures (p `star` q) `equiv` (p `star` r))
  = ()

#push-options "--warn_error -271"
let new_lock_is_frame_preserving (p:slprop)
  : Lemma (is_m_frame_preserving (new_lock_pre_m_action p))
  = let aux (frame:slprop) (m:hmem (p `star` frame))
      : Lemma
          (ensures (
            let (| x, m1 |) = new_lock_pre_m_action p m in
            interp (emp `star` frame `star` mem_invariant m1) (heap_of_mem m1)))
          [SMTPat ()]
      = let (| x, m1 |) = new_lock_pre_m_action p m in
        assert (m1.locks == Available p :: m.locks);
        assert (mem_invariant m1 == (p `star` mem_invariant m));
        assert (interp ((p `star` frame) `star` mem_invariant m) (heap_of_mem m));
        star_associative p frame (mem_invariant m);
        assert (interp (p `star` (frame `star` mem_invariant m)) (heap_of_mem m));
        star_commutative frame (mem_invariant m);
        equiv_star_left p (frame `star` mem_invariant m) (mem_invariant m `star` frame);
        assert (interp (p `star` (mem_invariant m `star` frame)) (heap_of_mem m));
        star_associative p (mem_invariant m) frame;
        assert (interp ((p `star` mem_invariant m) `star` frame) (heap_of_mem m));
        assert (interp ((mem_invariant m1) `star` frame) (heap_of_mem m));
        assert (heap_of_mem m == heap_of_mem m1);
        star_commutative (mem_invariant m1) frame;
        assert (interp (frame `star` (mem_invariant m1)) (heap_of_mem m1));
        emp_unit_left (frame `star` (mem_invariant m1));
        assert (interp (emp `star` (frame `star` (mem_invariant m1))) (heap_of_mem m1));
        star_associative emp frame (mem_invariant m1)
    in
    ()
#pop-options

let new_lock_action (p:slprop)
  : m_action p (lock p) (fun _ -> emp)
  = new_lock_is_frame_preserving p;
    new_lock_pre_m_action p

////////////////////////////////////////////////////////////////////////////////
assume
val get_lock (l:lock_store) (i:nat{i < L.length l})
  : (prefix : lock_store &
     li : lock_state &
     suffix : lock_store {
       l == L.(prefix @ (li::suffix)) /\
       L.length (li::suffix) == i + 1
     })

let lock_i (l:lock_store) (i:nat{i < L.length l}) : lock_state =
  let (| _, li, _ |) = get_lock l i in
  li

assume
val lock_store_invariant_append (l1 l2:lock_store)
  : Lemma (lock_store_invariant (l1 @ l2) `equiv`
           (lock_store_invariant l1 `star` lock_store_invariant l2))

let slprop_of_lock_state (l:lock_state) : slprop =
  match l with
  | Available p -> p
  | Locked p -> p

let lock_ok (#p:slprop) (l:lock p) (m:mem) =
  l < L.length m.locks /\
  slprop_of_lock_state (lock_i m.locks l) == p

let lock_store_evolves : Preorder.preorder lock_store =
  fun (l1 l2 : lock_store) ->
    L.length l2 >= L.length l1 /\
    (forall (i:nat{i < L.length l1}).
       slprop_of_lock_state (lock_i l1 i) ==
       slprop_of_lock_state (lock_i l2 i))

let mem_evolves : Preorder.preorder mem =
  fun m0 m1 -> lock_store_evolves m0.locks m1.locks

let lock_ok_stable (#p:_) (l:lock p) (m0 m1:mem)
  : Lemma (lock_ok l m0 /\
           m0 `mem_evolves` m1 ==>
           lock_ok l m1)
  = ()

let pure (p:prop) : slprop = refine emp (fun _ -> p)

let intro_pure (p:prop) (q:slprop) (h:hheap q { p })
  : hheap (pure p `star` q)
  = emp_unit q;
    star_commutative q emp;
    h

let intro_hmem_or (p:prop) (q:slprop) (h:hmem q)
  : hmem (h_or (pure p) q)
  = h

let middle_to_head (p q r:slprop) (h:hheap (p `star` (q `star` r)))
  : hheap (q `star` (p `star` r))
  = star_associative p q r;
    star_commutative p q;
    star_associative q p r;
    h

let maybe_acquire #p (l:lock p) (m:mem { lock_ok l m } )
  : (b:bool &
     m:hmem (h_or (pure (b == false)) p))
  = let (| prefix, li, suffix |) = get_lock m.locks l in
    match li with
    | Available _ ->
      let h = heap_of_mem m in
      assert (interp (lock_store_invariant m.locks) h);
      lock_store_invariant_append prefix (li::suffix);
      assert (lock_store_invariant m.locks `equiv`
             (lock_store_invariant prefix `star`
                      (p `star` lock_store_invariant suffix)));
      assert (interp (lock_store_invariant prefix `star`
                       (p `star` lock_store_invariant suffix)) h);
      let h = middle_to_head (lock_store_invariant prefix) p (lock_store_invariant suffix) h in
      assert (interp (p `star`
                        (lock_store_invariant prefix `star`
                         lock_store_invariant suffix)) h);
      let new_lock_store = prefix @ (Locked p :: suffix) in
      lock_store_invariant_append prefix (Locked p :: suffix);
      assert (lock_store_invariant new_lock_store `equiv`
              (lock_store_invariant prefix `star`
                         lock_store_invariant suffix));
      equiv_star_left p (lock_store_invariant new_lock_store)
                        (lock_store_invariant prefix `star`
                          lock_store_invariant suffix);
      assert (interp (p `star` lock_store_invariant new_lock_store) h);
      let h : hheap (p `star` lock_store_invariant new_lock_store) = h in
      assert (heap_of_mem m == h);
      star_commutative p (lock_store_invariant new_lock_store);
      affine_star (lock_store_invariant new_lock_store) p h;
      assert (interp (lock_store_invariant new_lock_store) h);
      let mem : hmem p = { m with locks = new_lock_store } in
      let b = true in
      let mem : hmem (h_or (pure (b==false)) p) = intro_hmem_or (b == false) p mem in
      (| b, mem |)

    | Locked _ ->
      let b = false in
      assert (interp (pure (b == false)) (heap_of_mem m));
      let h : hheap (mem_invariant m) = heap_of_mem m in
      let h : hheap (pure (b==false) `star` mem_invariant m) =
        intro_pure (b==false) (mem_invariant m) h in
      intro_or_l (pure (b==false) `star` mem_invariant m)
                 (p `star` mem_invariant m)
                 h;
      or_star (pure (b==false)) p (mem_invariant m) h;
      assert (interp (h_or (pure (b==false)) p `star` mem_invariant m) h);
      (| false, m |)

let hmem_emp (p:slprop) (m:hmem p) : hmem emp = m

#push-options "--query_stats --z3rlimit_factor 8"
let release #p (l:lock p) (m:hmem p { lock_ok l m } )
  : (b:bool &
     hmem emp)
  = let (| prefix, li, suffix |) = get_lock m.locks l in
    let h = heap_of_mem m in
    lock_store_invariant_append prefix (li::suffix);
    assert (interp (p `star`
                     (lock_store_invariant prefix `star`
                       (lock_store_invariant (li::suffix)))) h);
    match li with
    | Available _ ->
      (* this case is odd, but not inadmissible.
         We're releasing a lock that was not previously acquired.
         We could either fail, or just silently proceed.
         I choose to at least signal this case in the result
         so that we can decide to fail if we like, at a higher layer.

         Another cleaner way to handle this would be to insist
         that lockable resources are non-duplicable ...
         in which case this would be unreachable, since we have `p star p` *)
      (| false, hmem_emp p m |)

    | Locked _ ->
      assert (interp (p `star`
                        (lock_store_invariant prefix `star`
                          (lock_store_invariant suffix))) h);
      let h = middle_to_head p (lock_store_invariant prefix) (lock_store_invariant suffix) h in
      assert (interp (lock_store_invariant prefix `star`
                        (p `star`
                          (lock_store_invariant suffix))) h);
      let new_lock_store = prefix @ (Available p :: suffix) in
      lock_store_invariant_append prefix (Available p :: suffix);
      assert (lock_store_invariant new_lock_store `equiv`
                (lock_store_invariant prefix `star`
                 (p `star` lock_store_invariant (suffix))));
      assert (interp (lock_store_invariant new_lock_store) h);
      emp_unit_left (lock_store_invariant new_lock_store);
      let mem : hmem emp = { m with locks = new_lock_store } in
      (| true, mem |)
#pop-options

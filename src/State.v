Require Import Coq.Lists.List.

Import ListNotations.

Module Effect.
  Record t := New {
    command : Type;
    answer : command -> Type }.
End Effect.

Module C.
  Inductive t (E : Effect.t) (A : Type) : Type :=
  | Ret : A -> t E A
  | Call : forall c, (Effect.answer E c -> t E A) -> t E A.
  Arguments Ret {E A} _.
  Arguments Call {E A} _ _.
End C.

Module Event.
  Record t (E : Effect.t) : Type := New {
    c : Effect.command E;
    a : Effect.answer E c }.
  Arguments New {E} _ _.
  Arguments c {E} _.
  Arguments a {E} _.
End Event.

Module Trace.
  Definition t (E : Effect.t) : Type :=
    list (Event.t E).

  Module Valid.
    Inductive t {E : Effect.t} {A : Type} : C.t E A -> Trace.t E -> A -> Prop :=
    | Ret : forall v, t (C.Ret v) [] v
    | Call : forall c a h trace v, t (h a) trace v ->
      t (C.Call c h) (Event.New c a :: trace) v.
  End Valid.
End Trace.

Module Run.
  Inductive t {E A} : C.t E A -> Type :=
  | Ret : forall v, t (C.Ret v)
  | Call : forall c a h, t (h a) -> t (C.Call c h).
  Arguments Ret {E A} _.
  Arguments Call {E A} _ _ _ _.

  Fixpoint eval {E A} {x : C.t E A} (r : t x) : A :=
    match r with
    | Ret v => v
    | Call _ _ _ r => eval r
    end.
End Run.

Module State.
  Module Command.
    Inductive t (S : Type) : Type :=
    | Read : t S
    | Write : S -> t S.

    Definition answer {S : Type} (c : t S) : Type :=
      match c with
      | Read => S
      | Write _ => unit
      end.

    Definition run_anwser {S : Type} (c : t S) (s : S) : answer c :=
      match c with
      | Read => s
      | Write x => tt
      end.

    Definition run_state {S : Type} (c : t S) (s : S) : S :=
      match c with
      | Read => s
      | Write x => x
      end.
  End Command.

  Definition E (S : Type) : Effect.t :=
    Effect.New (Command.t S) Command.answer.

  Module Invariant.
    Inductive t {S A} (s : S) : forall {x : C.t (E S) A}, Run.t x -> Prop :=
    | Ret : forall v, t s (Run.Ret v)
    | Call : forall c h run_h_a,
      t (Command.run_state c s) run_h_a ->
      t s (Run.Call (E := E S) c (Command.run_anwser c s) h run_h_a).
  End Invariant.

  Fixpoint eval {S A} (x : C.t (E S) A) (s : S) : A :=
    match x with
    | C.Ret v => v
    | C.Call c h =>
      let a := Command.run_anwser c s in
      let s' := Command.run_state c s in
      eval (h a) s'
    end.

  Fixpoint eval_ok {S} {x : C.t (E S) unit} {r : Run.t x} {s : S}
    (H : Invariant.t s r) : eval x s = Run.eval r.
    destruct x; simpl.
    - now inversion_clear H.
    - refine (
        match H in Invariant.t _ (x := x) r return
        match x with
        | C.Call c h =>
          eval (h (Command.run_anwser c s)) (Command.run_state c s) = Run.eval r
        | _ => True
        end : Prop with
        | Invariant.Call _ _ _ _ => _
        | _ => I
        end).
      simpl.
      now apply eval_ok.
  Qed.
End State.

Module Incr.
  Module Command.
    Inductive t : Set :=
    | Incr : t
    | Read : t.

    Definition answer (c : t) : Type :=
      match c with
      | Incr => unit
      | Read => nat
      end.

    Definition run_anwser (c : t) (s : nat) : answer c :=
      match c with
      | Incr => tt
      | Read => s
      end.

    Definition run_state (c : t) (s : nat) : nat :=
      match c with
      | Incr => S s
      | Read => s
      end.
  End Command.

  Definition E : Effect.t :=
    Effect.New Command.t Command.answer.

  Fixpoint eval {A} (x : C.t E A) (s : nat) : A :=
    match x with
    | C.Ret v => v
    | C.Call c h =>
      let a := Command.run_anwser c s in
      let s' := Command.run_state c s in
      eval (h a) s'
    end.
End Incr.

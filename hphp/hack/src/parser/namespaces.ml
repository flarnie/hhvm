(**
 * Copyright (c) 2015, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the "hack" directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 *)

open Ast
open Hh_core
open Namespace_env

(* When dealing with an <?hh file, HHVM automatically imports a few
 * "core" classes into every namespace, mostly collections. Their
 * unqualified names always refer to this global version.
 *
 * Note that these are technically in the \HH namespace as far as the
 * runtime is concerned, but we treat them as in the global
 * namespace. This is a tiny bit weird, but since Facebook www all runs
 * in the global namespace relying on this autoimport, this makes the
 * most sense there.
 *
 * See hhvm/compiler/parser/parser.cpp Parser::getAutoAliasedClasses
 * for the canonical list of classes and Parser::onCall for the
 * canonical list of functions. *)
let autoimport_classes = [
  "Traversable";
  "KeyedTraversable";
  "Container";
  "KeyedContainer";
  "Iterator";
  "KeyedIterator";
  "Iterable";
  "KeyedIterable";
  "Collection";
  "Vector";
  "ImmVector";
  "vec";
  "dict";
  "keyset";
  "Map";
  "ImmMap";
  "StableMap";
  "Set";
  "ImmSet";
  "Pair";
  "Awaitable";
  "AsyncIterator";
  "IMemoizeParam";
  "AsyncKeyedIterator";
  "InvariantException";
  "AsyncGenerator";
  "WaitHandle";
  "StaticWaitHandle";
  "WaitableWaitHandle";
  "ResumableWaitHandle";
  "AsyncFunctionWaitHandle";
  "AsyncGeneratorWaitHandle";
  "AwaitAllWaitHandle";
  "ConditionWaitHandle";
  "RescheduleWaitHandle";
  "SleepWaitHandle";
  "ExternalThreadEventWaitHandle";
  "Shapes";
  "TypeStructureKind";
]
let autoimport_funcs = [
  "invariant";
  "invariant_violation";
  "type_structure";
]
let autoimport_types = [
  "typename";
  "classname";
  "TypeStructure";
]

let autoimport_set =
  let autoimport_list
    = autoimport_classes @ autoimport_funcs @ autoimport_types in
  List.fold_left autoimport_list ~init:SSet.empty ~f:(fun s e -> SSet.add e s)
(* NOTE that the runtime is able to distinguish between class and
   function names when auto-importing *)
let is_autoimport_name id =
  Naming_special_names.Typehints.is_reserved_global_name id ||
  Naming_special_names.Typehints.is_reserved_hh_name id ||
  SSet.mem id autoimport_set

let elaborate_into_current_ns nsenv id =
  match nsenv.ns_name with
    | None -> "\\" ^ id
    | Some ns -> "\\" ^ ns ^ "\\" ^ id

(* Walks over the namespace map and checks if any source
 * matches the given id.
 * If a match is found, then removes the match and
 * replaces it with the target
 * If no match is found, returns the id
 *
 * Regularly, translates from the long name to the short name.
 * If the reverse flag is give, then translation is done
 * otherway around.*)
let rec translate_id ~reverse ns_map id =
  match ns_map with
    | [] -> id
    | (short_name, long_name)::rest ->
      let (target, source) = if reverse
                             then (long_name, short_name)
                             else (short_name, long_name) in
      (* Append backslash at the end so that it doesn't match partially *)
      if String_utils.string_starts_with id (source ^ "\\")
      (* Strip out the prefix and connect it to the next beginning *)
      then target ^ (String_utils.lstrip id source)
      else translate_id ~reverse rest id

(* Runs the autonamespace translation for both fully qualified and non qualified
 * names *)
let renamespace_if_aliased ?(reverse = false) ns_map id =
  try
    let has_bslash = id.[0] = '\\' in
    let len = String.length id in
    let id = if has_bslash then String.sub id 1 (len - 1) else id in
    let translation = translate_id ~reverse ns_map id in
    if has_bslash then "\\" ^ translation else translation
  (* If there is some matching problem, that means we are not aliasing *)
  with _ -> id

type elaborate_kind =
  | ElaborateFun
  | ElaborateClass
  | ElaborateConst

(* Elaborate a defined identifier in a given namespace environment. For example,
 * a class might be defined inside a namespace. Return new environment if
 * ID is auto imported (e.g. Map) and so must be mapped when used.
 *)
let elaborate_defined_id nsenv kind (p, id) =
  let newid = elaborate_into_current_ns nsenv id in
  let update_nsenv = kind = ElaborateClass && is_autoimport_name id in
  let nsenv =
    if update_nsenv
    then {nsenv with ns_class_uses = SMap.add id newid nsenv.ns_class_uses}
    else nsenv in
  let translated = renamespace_if_aliased
      (ParserOptions.auto_namespace_map nsenv.ns_popt) newid in
  (p, translated), nsenv, update_nsenv

(* Resolves an identifier in a given namespace environment. For example, if we
 * are in the namespace "N\O", the identifier "P\Q" is resolved to "\N\O\P\Q".
 *
 * All identifiers are fully-qualified by this function; the internal
 * representation of identifiers inside the typechecker after naming is a fully
 * qualified identifier.
 *
 * It's extremely important that this function is idempotent. We actually
 * normalize identifiers in two phases. Right after parsing, we need to have
 * the class hierarchy normalized so that we can recompute dependencies for
 * incremental mode properly. Other identifiers are normalized during naming.
 * However, we don't do any bookkeeping to determine which we've normalized or
 * not, just relying on the idempotence of this function to make sure everything
 * works out. (Fully qualifying identifiers is of course idempotent, but there
 * used to be other schemes here.)
 *)
let elaborate_id_impl ~autoimport nsenv kind (p, id) =
  (* Go ahead and fully-qualify the name first. *)
  let was_renamed, fully_qualified =
    if id <> "" && id.[0] = '\\'
    then false, id
    else
    begin
      (* Expand "use" imports. *)
      let (bslash_loc, has_bslash) =
        try String.index id '\\', true
        with Not_found -> String.length id, false in
      (* "use function" and "use const" only apply if the id is completely
       * unqualified, otherwise the normal "use" imports apply. *)
      let uses = if has_bslash then nsenv.ns_ns_uses else match kind with
        | ElaborateClass -> nsenv.ns_class_uses
        | ElaborateFun -> nsenv.ns_fun_uses
        | ElaborateConst -> nsenv.ns_const_uses in
      let prefix = String.sub id 0 bslash_loc in
      if prefix = "namespace" && id <> "namespace" then begin
        (* Strip off the 'namespace\' (including the slash) from id, then
        elaborate back into the current namespace. *)
        let len = (String.length id) - bslash_loc  - 1 in
        false, elaborate_into_current_ns nsenv (String.sub id (bslash_loc + 1) len)
      end
      else
      begin
      match SMap.get prefix uses with
        | None ->
          if autoimport && is_autoimport_name id
          then false, "\\" ^ id
          else false, elaborate_into_current_ns nsenv id
        | Some use -> begin
          (* Strip off the "use" from id, but *not* the backslash after that
           * (so "use\foo" will become "\foo") and then prepend the new
           * namespace. *)
          let len = (String.length id) - bslash_loc in
          true, use ^ (String.sub id bslash_loc len)
        end
      end
    end in
  let translated = renamespace_if_aliased
      (ParserOptions.auto_namespace_map nsenv.ns_popt) fully_qualified in
  was_renamed, (p, translated)

let elaborate_id nsenv kind id =
  let _, newid = elaborate_id_impl ~autoimport:true nsenv kind id in
  newid

(* First pass of flattening namespaces, run super early in the pipeline, right
 * after parsing.
 *
 * Fully-qualifies the things we need for Parsing_service.AddDeps -- the classes
 * we extend, traits we use, interfaces we implement; along with classes we
 * define. So that we can also use them to figure out fallback behavior, we also
 * fully-qualify functions that we define, even though AddDeps doesn't need
 * them this early.
 *
 * Note that, since AddDeps doesn't need it, we don't recursively traverse
 * through Happly in hints -- we rely on the idempotence of elaborate_id to
 * allow us to fix those up during a second pass during naming.
 *)
module ElaborateDefs = struct
  let hint nsenv = function
    | p, Happly (id, args) ->
        p, Happly (elaborate_id nsenv ElaborateClass id, args)
    | other -> other

  let class_def nsenv = function
    | ClassUse h -> ClassUse (hint nsenv h)
    | XhpAttrUse h -> XhpAttrUse (hint nsenv h)
    | other -> other

  let finish nsenv updated_nsenv stmt =
    if updated_nsenv
    then nsenv, [stmt; SetNamespaceEnv nsenv]
    else nsenv, [stmt]

  let rec def nsenv = function
    (*
      The default namespace in php is the global namespace specified by
      the empty string. In the case of an empty string, we model it as
      the global namespace.

      We remove namespace and use nodes and replace them with
      SetNamespaceEnv nodes that contain the namespace environment
    *)
    | Namespace ((_, nsname), prog) -> begin
        let parent_nsname =
          Option.value_map nsenv.ns_name
            ~default:""
            ~f:(fun n -> n ^ "\\") in
        let nsname = match nsname with
          | "" -> None
          | _ -> Some (parent_nsname ^ nsname) in
        let new_nsenv = {nsenv with ns_name = nsname} in
        nsenv, SetNamespaceEnv new_nsenv :: program new_nsenv prog
      end
    | NamespaceUse l -> begin
        let nsenv =
          List.fold_left l ~init:nsenv ~f:begin fun nsenv (kind, id1, id2) ->
            match kind with
              | NSNamespace -> begin
                let m = SMap.add (snd id2) (snd id1) nsenv.ns_ns_uses in
                {nsenv with ns_ns_uses = m}
              end
              | NSClass -> begin
                let m = SMap.add (snd id2) (snd id1) nsenv.ns_class_uses in
                {nsenv with ns_class_uses = m}
              end
              | NSClassAndNamespace -> begin
                let m = SMap.add (snd id2) (snd id1) nsenv.ns_class_uses in
                let n = SMap.add (snd id2) (snd id1) nsenv.ns_ns_uses in
                {nsenv with ns_class_uses = m; ns_ns_uses = n}
              end
              | NSFun -> begin
                let m = SMap.add (snd id2) (snd id1) nsenv.ns_fun_uses in
                {nsenv with ns_fun_uses = m}
              end
              | NSConst -> begin
                let m = SMap.add (snd id2) (snd id1) nsenv.ns_const_uses in
                {nsenv with ns_const_uses = m}
              end
          end in
        nsenv, [SetNamespaceEnv nsenv]
      end
    | Class c ->
      let name, nsenv, updated_nsenv =
        elaborate_defined_id nsenv ElaborateClass c.c_name in
      finish nsenv updated_nsenv (Class {c with
        c_name = name;
        c_extends = List.map c.c_extends (hint nsenv);
        c_implements = List.map c.c_implements (hint nsenv);
        c_body = List.map c.c_body (class_def nsenv);
        c_namespace = nsenv;
      })
    | Fun f ->
      let name, nsenv, updated_nsenv =
        elaborate_defined_id nsenv ElaborateFun f.f_name in
      finish nsenv updated_nsenv (Fun {f with
        f_name = name;
        f_namespace = nsenv;
      })
    | Typedef t ->
      let name, nsenv, updated_nsenv =
        elaborate_defined_id nsenv ElaborateClass t.t_id in
      finish nsenv updated_nsenv (Typedef {t with
        t_id = name;
        t_namespace = nsenv;
      })
    | Constant cst -> nsenv, [Constant {cst with
        cst_name =
          if cst.cst_kind = Ast.Cst_define
          then
            (* names in define are interpreted as-is:
            prefix it with "\\" to mark it as elaborated. This prefix will be
            stripped during emit phase.
            In program this name of the constant can be accessed either
            via identifier name or through 'constant' PHP function.
            In the former case in Naming phase reference will be mangled in
            the same way so name will be successfully resolved.*)
            let (pos, n) = cst.cst_name in
            pos, "\\" ^ n
          else
            (let name, _, _ =
              elaborate_defined_id nsenv ElaborateConst cst.cst_name
            in name);
        cst_namespace = nsenv;
      }]
    | other -> nsenv, [other]

  and program nsenv p =
    let _, acc =
      List.fold_left p ~init:(nsenv, []) ~f:begin fun (nsenv, acc) item ->
        let nsenv, item = def nsenv item in
        nsenv, item :: acc
      end in
    List.concat (List.rev acc)
end

let elaborate_toplevel_defs popt ast =
  ElaborateDefs.program (Namespace_env.empty popt) ast

let elaborate_def nsenv def =
  ElaborateDefs.def nsenv def

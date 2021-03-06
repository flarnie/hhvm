(**
 * Copyright (c) 2016, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the "hack" directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 *)

(* TODO: Integrate these with the rest of the Hack error messages. *)

type error_type = ParseError | RuntimeError

type t = {
  child        : t option;
  start_offset : int;
  end_offset   : int;
  error_type   : error_type;
  message      : string;
}

exception ParserFatal of t

let make
  ?(child = None) ?(error_type = ParseError) start_offset end_offset message =
  { child; error_type; start_offset; end_offset; message }

let rec to_positioned_string error offset_to_position =
  let child =
    match error.child with
    | Some child ->
      Printf.sprintf "\n  %s" (to_positioned_string child offset_to_position)
    | _ -> "" in
  let (sl, sc) = offset_to_position error.start_offset in
  let (el, ec) = offset_to_position error.end_offset in
  Printf.sprintf "(%d,%d)-(%d,%d) %s%s" sl sc el ec error.message child

let compare err1 err2 =
  if err1.start_offset < err2.start_offset then -1
  else if err1.start_offset > err2.start_offset then 1
  else if err1.end_offset < err2.end_offset then -1
  else if err1.end_offset > err2.end_offset then 1
  else 0

let exactly_equal err1 err2 =
  err1.start_offset = err2.start_offset &&
    err1.end_offset = err2.end_offset &&
    err1.message = err2.message

let error_type err = err.error_type

let message err = err.message

let start_offset err = err.start_offset
let end_offset err = err.end_offset

(* Lexical errors *)
let error0001 = "A hexadecimal literal needs at least one digit."
let error0002 = "A binary literal needs at least one digit."
let error0003 = "A floating literal with an exponent needs at least " ^
                " one digit in the exponent."
let error0004 = "An octal literal must contain only digits 0 through 7."
let error0005 = "This string literal escape sequence is invalid."
let error0006 = "This character is invalid."
let error0007 = "This delimited comment is not terminated."
let error0008 = "A name is expected here."
let error0009 = "An unqualified name is expected here."
let error0010 = "A single quote is expected here."
let error0011 = "A newline is expected here."
let error0012 = "This string literal is not terminated."
let error0013 = "This XHP body is not terminated."
let error0014 = "This XHP comment is not terminated."

(* Syntactic errors *)
let error1001 = "A source file must begin with '<?hh'."
let error1002 = "An inclusion directive or type, function, " ^
                "namespace or use declaration is expected here."
let error1003 = "The 'function' keyword is expected here."
let error1004 = "A name is expected here."
let error1006 = "A right brace is expected here."
let error1007 = "A type specifier is expected here."
let error1008 = "A variable name is expected here."
let error1009 = "A comma or right parenthesis is expected here."
let error1010 = "A semicolon is expected here."
let error1011 = "A right parenthesis is expected here."
let error1012 = "A type is expected here."  (* TODO: Redundant to 1007. *)
let error1013 = "A closing angle bracket is expected here."
let error1014 = "A closing angle bracket or comma is expected here."
let error1015 = "An expression is expected here."
let error1016 = "An assignment is expected here."
let error1017 = "An XHP attribute value is expected here."
let error1018 = "The 'while' keyword is expected here."
let error1019 = "A left parenthesis is expected here."
let error1020 = "A colon is expected here."
let error1021 = "An opening angle bracket is expected here."
(* TODO: Remove this; redundant to 1009. *)
let error1022 = "A right parenthesis or comma is expected here."
let error1023 = "An 'as' keyword is expected here."
let error1024 = "A comma or semicolon is expected here."
let error1025 = "A shape field name is expected here."
let error1026 = "An opening square bracket is expected here."
let error1027 = "A class name, variable name, or 'static' is expected here."
let error1028 = "An arrow ('=>') is expected here."
let error1029 = "A closing double angle bracket is expected here."
let error1030 = "An attribute is expected here."
let error1031 = "A comma or a closing square bracket is expected here."
let error1032 = "A closing square bracket is expected here."
(* TODO: Break this up according to classish type *)
let error1033 = "A class member, method, type, trait usage, trait require, " ^
  "xhp attribute, xhp use, or xhp category is expected here."
let error1034 = "A left brace is expected here."
let error1035 = "The 'class' keyword is expected here."
let error1036 = "A '=' is expected here."
let error1037 = "A left brace is expected here."
let error1038 = "A semicolon or a namespace body is expected here."
let error1039 = "A closing XHP tag is expected here."
let error1040 = "A right brace or an enumerator is expected here."
let error1041 = "A function body or a semicolon is expected here."
let error1042 = "A visibility modifier, static, abstract, or final keyword is "^
                "expected here."
let error1043 = "A function header is expected here."
let error1044 = "A name, __construct, or __destruct keyword is expected here."
let error1045 = "An 'extends' or 'implements' keyword is expected here."
let error1046 = "A lambda arrow ('==>') is expected here."
let error1047 = "A scope resolution operator ('::') is expected here."
let error1048 = "A name, variable name or 'class' is expected here."
let error1050 = "A name or variable name is expected here."
let error1051 = "The 'required' keyword is expected here."
let error1052 = "An XHP category name beginning with a '%' is expected here."
let error1053 = "An XHP name or category name is expected here."
let error1054 = "A comma is expected here."
let error1055 = "A fallthrough directive can only appear at the end of" ^
  " a switch section."
(* TODO(20052790): use the specific token's text in the message body. *)
let error1056 = "This token is not valid as part of a function declaration."
let error1057 text = "Encountered unexpected token '" ^ text ^ "'."
let error1058 received required = Printf.sprintf ("Encountered unexpected " ^^
  "token '%s'. Did you mean '%s'?") received required

let error2001 = "A type annotation is required in strict mode."
let error2002 = "An XHP attribute name may not contain '-' or ':'."
let error2003 = "A case statement may only appear directly inside a switch."
let error2004 = "A default statement may only appear directly inside a switch."
let error2005 = "A break statement may only appear inside a switch or loop."
let error2006 = "A continue statement may only appear inside a loop."
let error2007 = "A try statement requires a catch or a finally clause."
let error2008 = "The first statement inside a switch statement must " ^
  "be a case or default label statement."
let error2009 = "A constructor cannot be static."
let error2010 = "Parameters cannot have visibility modifiers (except in " ^
  "parameter lists of constructors)."
let error2011 = "A destructor must have an empty parameter list."
let error2012 = "A destructor can only have visibility modifiers."
let error2013 = "A method declaration cannot have duplicate modifiers."
let error2014 = "An abstract method cannot have a method body."
let error2015 = "A non-abstract method must have a body."
let error2016 = "A method cannot be both abstract and private."
let error2017 =
  "A method declaration cannot have multiple visibility modifiers."
let error2018 =
  "A constructor or destructor cannot have a non-void type annotation."
let error2019 = "A method cannot be both abstract and final."
let error2020 = "Use of the '{}' subscript operator is deprecated; " ^
  " use '[]' instead."
let error2021 = "A variadic parameter ('...') may only appear at the end of " ^
  "a parameter list."
let error2022 = "A variadic parameter ('...') may not be followed by a comma."

let error2029 = "Only traits and interfaces may use 'require extends'."
let error2030 = "Only traits may use 'require implements'."
let error2031 =
  "A class, interface, or trait declaration cannot have duplicate modifiers."
let error2032 = "The array type is not allowed in strict mode."
let error2033 = "The splat operator ('...') for unpacking variadic arguments " ^
  "may only appear at the end of an argument list."
let error2034 = "A type alias declaration cannot both use 'type' and have a " ^
  "constraint. Did you mean 'newtype'?"
let error2035 = "Only classes may implement interfaces."
let error2036 = "Only interfaces and classes may extend other interfaces and "
  ^ "classes."
let error2037 = "A class may extend at most one other class."
let error2038 constructor_name =
  "A constructor initializing an object must be passed a (possibly empty) " ^
  "list of arguments. Did you mean 'new " ^ constructor_name ^ "()'?"
let error2039 classish_keyword classish_name function_name = Printf.sprintf
  ("Cannot define a class, interface, or trait inside a function. Currently " ^^
  "%s '%s' is inside function '%s'.") classish_keyword classish_name function_name
let error2040 = "Invalid use of 'list(...)'. A list expression may only be " ^
  "used as the left side of a simple assignment, the value clause of a " ^
  "foreach loop, or a list item nested inside another list expression."
let error2041 = "Unexpected method body: interfaces may contain only" ^
  " method signatures, and not method implementations."
let error2042 = "Interfaces may not be declared 'abstract'."
let error2043 = "Traits may not be declared 'abstract'."
let error2044 class_name method_name = Printf.sprintf ("Classes cannot both " ^^
  "contain abstract methods and be non-abstract. Either declare 'abstract " ^^
  "class %s', or make 'function %s' non-abstract.") class_name method_name
let error2045 = "No method inside an interface may be declared 'abstract'."
let error2046 = "The 'async' annotation cannot be used on 'abstract' methods " ^
  "or methods inside of interfaces."
let error2047 visibility_modifier = "Methods inside of interfaces may not be " ^
  "marked '" ^ visibility_modifier ^ "'; only 'public' visibility is allowed."
let error2048 = "Expected group use prefix to end with '\\'"
let error2049 = "A namespace use clause may not specify the kind here."
let error2050 = "A concrete constant declaration must have an initializer."
let error2051 = "An abstract constant declaration must not have an initializer."
let error2052 = "Cannot mix bracketed namespace declarations with " ^
  "unbracketed namespace declarations"
let error2053 = "Use of 'var' as synonym for 'public' in declaration disallowed in Hack. " ^
  "Use 'public' instead."
let error2054 = "Method declarations require a visibility modifier " ^
  "such as public, private or protected."
let error2055 = "At least one enumerated item is expected."
let error2056 = "First unbracketed namespace occurrence here"
let error2057 = "First bracketed namespace occurrence here"
let error2058 = "Property may not be abstract."
let error2059 = "Shape field name must be a string or a class constant"
let error2060 = "Shape field name must not start with an integer"
let error2061 = "Non-static instance variables are not allowed in abstract final
  classes."
let error2062 = "Non-static methods are not allowed in abstract final classes."
let error2063 = "Expected integer or string literal."
let error2064 = "Reference methods are not allowed in strict mode."
let error2065 = "A variadic parameter ('...') must not have a default value."
(* This was typing error 4077. *)
let error2066 = "A previous parameter has a default value. Remove all the " ^
  "default values for the preceding parameters, or add a default value to " ^
  "this one."
let error2067 = "A hack source file cannot contain '?>'."
let error2068 = "hh blocks and php blocks cannot be mixed."
let error2069 = "Operator '?->' is only allowed in Hack."
let error2070 ~open_tag ~close_tag =
  Printf.sprintf "XHP: mismatched tag: '%s' not the same as '%s'"
    open_tag close_tag
let error2071 s = "Decimal number is too big: " ^ s
let error2072 s = "Hexadecimal number is too big: " ^ s
let error2073 = "A variadic parameter ('...') cannot have a modifier " ^
  "that changes the calling convention, like 'inout'."
let error2074 call_modifier = "An '" ^ call_modifier ^ "' parameter must not " ^
  "have a default value."
let error2075 call_modifier = "An '" ^ call_modifier ^ "' parameter cannot " ^
  "be passed by reference ('&')."
let error2076 = "Cannot use both 'inout' and '&' on the same argument."

(* Start giving names rather than numbers *)
let hsl_in_php = "Hack standard library is only allowed in Hack files"
let vdarray_in_php = "varray and darray are only allowed in Hack files"
let using_st_function_scoped_top_level =
  "Using statement in function scoped form may only be used at the top " ^
  "level of a function or a method"
let const_in_trait = "Traits cannot have constants"
let strict_namespace_hh =
  "To use strict hack, place // strict after the open tag. " ^
  "If it's already there, remove this line. " ^
  "Hack is strict already."
let strict_namespace_not_hh =
  "You seem to be trying to use a different language. " ^
  "May I recommend Hack? http://hacklang.org"

let original_definition = "Original definition"

let name_is_already_in_use ~name ~short_name =
  "Cannot use " ^ name ^ " as " ^ short_name ^
  " because the name is already in use"

let function_name_is_already_in_use ~name ~short_name =
  "Cannot use function " ^ name ^ " as " ^ short_name ^
  " because the name is already in use"

let const_name_is_already_in_use ~name ~short_name =
  "Cannot use const " ^ name ^ " as " ^ short_name ^
  " because the name is already in use"

let type_name_is_already_in_use ~name ~short_name =
  "Cannot use type " ^ name ^ " as " ^ short_name ^
  " because the name is already in use"

let variadic_reference = "Found '...&'. Did you mean '&...'?"
let double_variadic = "Parameter redundantly marked as variadic ('...')."
let double_reference = "Parameter redundantly marked as reference ('&')."
let global_in_const_decl = "Cannot have globals in constant declaration"

let conflicting_trait_require_clauses ~name =
  "Conflicting requirements for '" ^ name ^ "'"

let yield_in_magic_methods =
  "'yield' is not allowed in constructor, destructor, or magic methods"

let reference_not_allowed_on_key = "Key of collection element cannot " ^
  "be marked as reference"
let reference_not_allowed_on_value = "Value of collection element cannot " ^
  "be marked as reference"
let reference_not_allowed_on_element = "Collection element cannot " ^
  "be marked as reference"
let yield_in_finally_block =
  "Yield expression inside a finally block is not supported"

let coloncolonclass_on_dynamic =
  "Dynamic class names are not allowed in compile-time ::class fetch"
let enum_elem_name_is_class =
  "Enum element cannot be named 'class'"
let safe_member_selection_in_write =
  "?-> is not allowed in write context"
let xhp_member_selection_in_write =
  "Using ->: syntax in write context is not supported"
let reassign_this =
  "Cannot re-assign $this"
let strict_types_first_statement =
  "strict_types declaration must be the very first statement in the script"
let async_magic_method =
  "cannot declare constructors, destructors, and magic methods such as as async"

let reserved_keyword_as_class_name =
  "You may not use a reserved keyword for a class name"

let inout_param_in_generator =
  "Parameters may not be marked inout on generators"
let inout_param_in_async_generator =
  "Parameters may not be marked inout on an async generators"
let inout_param_in_async =
  "Parameters may not be marked inout on async functions"
let inout_param_in_construct =
  "Parameters may not be marked inout on constructors"
let fun_arg_inout_set =
  "You cannot set an inout decorated argument while calling a function"
let fun_arg_inout_const =
  "You cannot decorate a constant as inout"
let fun_arg_invalid_arg =
  "You cannot decorate this argument as inout"
let fun_arg_inout_containers =
  "Parameters marked inout must be contained in locals, vecs, dicts, keysets," ^
  " and arrays"
let memoize_with_inout =
  "<<__Memoize>> cannot be used on functions with inout parameters"
let fn_with_inout_and_ref_params =
  "Functions may not use both reference and inout parameters"
let method_calls_on_xhp_attributes =
  "Method calls are not allowed on XHP attributes"
let invalid_constant_initializer =
  "Invalid expression in constant initializer"
let no_args_in_halt_compiler =
  "__halt_compiler function does not accept any arguments"
let halt_compiler_top_level_only =
  "__halt_compiler function should appear only at the top level"
let trait_alias_rule_allows_only_final_and_visibility_modifiers =
  "Only 'final' and visibility modifiers are allowed in trait alias rule"
let namespace_decl_first_statement =
  "Namespace declaration statement has to be the very first statement in the script"
let code_outside_namespace =
  "No code may exist outside of namespace {}"
let strict_types_in_declare_block_mode =
  "strict_types declaration must not use block mode"
let invalid_number_of_args name n =
  "Method " ^ name ^ " must take exactly " ^ (string_of_int n) ^ " arguments"

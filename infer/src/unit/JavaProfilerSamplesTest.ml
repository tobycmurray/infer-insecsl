(*
 * Copyright (c) 2018 - present Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *)

open! IStd
open OUnit2
module T = JavaProfilerSamples.JNI.VISIBLE_FOR_TESTING_DO_NOT_USE_DIRECTLY

let mk_split (pkg, typ) = Typ.Name.Java.Split.make ?package:pkg typ

let test_jni_pp =
  let create_test input expected _ =
    let found = Format.asprintf "%a" T.pp input in
    let pp_diff fmt (expected, actual) =
      Format.fprintf fmt "Expected: '%s', found: '%s'" expected actual
    in
    assert_equal ~cmp:String.equal ~pp_diff expected found
  in
  [ ( "test_jni_pp_1"
    , T.(Method ([Int; Boolean; FullyQualifiedClass ("java.lang", "String")], Array Char))
    , "(IZLjava/lang/String;)[C" )
  ; ( "test_jni_pp_2"
    , (let open T in
      Method
        ( [ Array
              (Method
                 ( [Int; Method ([Long; Array (Array Long); Boolean], Long)]
                 , Array
                     (Array
                        (Array
                           (Method
                              ([Int; FullyQualifiedClass ("aaa.bbb", "Ccc"); Boolean], Array Char))))
                 )) ]
        , Void ))
    , "([(I(J[[JZ)J)[[[(ILaaa/bbb/Ccc;Z)[C)V" ) ]
  |> List.map ~f:(fun (name, test_input, expected_output) ->
         name >:: create_test test_input expected_output )


let test_jni_parse_method_str_with_invalid_input =
  let create_test input expected_exception _ =
    let run () = T.parse_method_str input in
    assert_raises expected_exception run
  in
  [ ( "test_jni_parse_method_str_with_empty_input"
    , ""
    , Logging.InferUserError "The input provided did not parse as one JNI method signature" )
  ; ( "test_jni_parse_method_str_with_valid_non_method_input"
    , "I"
    , Logging.InferUserError "The input provided did not parse as one JNI method signature" ) ]
  |> List.map ~f:(fun (name, test_input, expected_exception) ->
         name >:: create_test test_input expected_exception )


let test_jni_parse_str_with_valid_input =
  let create_test input expected _ =
    let found = T.parse_str input in
    let pp_diff fmt (expected, actual) =
      Format.fprintf fmt "Expected: '%a', found: '%a'" (Format.pp_print_list T.pp) expected
        (Format.pp_print_list T.pp) actual
    in
    assert_equal ~cmp:(List.equal ~equal:T.equal) ~pp_diff expected found
  in
  [ ( "test_jni_parse_str_with_method_signature"
    , "(IZLjava/lang/String;)[C"
    , T.[Method ([Int; Boolean; FullyQualifiedClass ("java.lang", "String")], Array Char)] )
  ; ( "test_jni_parse_str_with_multiple_separate_types"
    , "I[[[CIJ(I)[C"
    , T.[Int; Array (Array (Array Char)); Int; Long; Method ([Int], Array Char)] )
  ; ( "test_jni_parse_str_with_multiple_fully_qualified_classes"
    , "(Laaa/bbb/Ccc;Laaa/bbb/Ccc;)V"
    , let open T in
      [ Method
          ([FullyQualifiedClass ("aaa.bbb", "Ccc"); FullyQualifiedClass ("aaa.bbb", "Ccc")], Void)
      ] )
  ; ( "test_jni_parse_str_with_complex_method_signature_1"
    , "([[J(I)V)V"
    , T.[Method ([Array (Array Long); Method ([Int], Void)], Void)] )
  ; ( "test_jni_parse_str_with_complex_method_signature_2"
    , "([C()V)V"
    , T.[Method ([Array Char; Method ([], Void)], Void)] )
  ; ( "test_jni_parse_str_with_complex_method_signature_3"
    , "(J[[J)V"
    , T.[Method ([Long; Array (Array Long)], Void)] )
  ; ( "test_jni_parse_str_with_complex_method_signature_4"
    , "([(I(J[[JZ)J)[[[(ILaaa/bbb/Ccc;Z)[C)V"
    , let open T in
      [ Method
          ( [ Array
                (Method
                   ( [Int; Method ([Long; Array (Array Long); Boolean], Long)]
                   , Array
                       (Array
                          (Array
                             (Method
                                ([Int; FullyQualifiedClass ("aaa.bbb", "Ccc"); Boolean], Array Char))))
                   )) ]
          , Void ) ] )
  ; ("test_jni_parse_str_with_empty_method_signature", "()V", T.[Method ([], Void)])
  ; ("test_jni_parse_str_with_empty_input", "", []) ]
  |> List.map ~f:(fun (name, test_input, expected_output) ->
         name >:: create_test test_input expected_output )


let test_jni_parse_str_with_invalid_input =
  let create_test input expected_exception _ =
    let run () = T.parse_str input in
    assert_raises expected_exception run
  in
  [ ( "test_jni_parse_str_with_missing_semicolon"
    , "Ljava/lang/String"
    , Logging.InferUserError
        "Cannot find a semicolon symbol to delimit the L token. Failed parsing input" )
  ; ( "test_jni_parse_str_with_unrecognized_char"
    , "M"
    , Logging.InferUserError "Unrecognized char 'M' while reading the input sequence" )
  ; ( "test_jni_parse_str_with_no_reductions_in_a_scan"
    , "(((("
    , Logging.InferUserError "No symbols were reduced during a scan, failed parsing input" ) ]
  |> List.map ~f:(fun (name, test_input, expected_exception) ->
         name >:: create_test test_input expected_exception )


let test_jni_to_java_type_with_valid_input =
  let create_test input expected _ =
    let found = T.to_java_type input in
    let pp_diff fmt (expected, actual) =
      let exp_pkg = Option.value ~default:"<None>" (Typ.Name.Java.Split.package expected) in
      let exp_cl = Typ.Name.Java.Split.type_name expected in
      let actual_pkg = Option.value ~default:"<None>" (Typ.Name.Java.Split.package actual) in
      let actual_cl = Typ.Name.Java.Split.type_name actual in
      Format.fprintf fmt "Expected: '(%s, %s)', found: '(%s, %s)'" exp_pkg exp_cl actual_pkg
        actual_cl
    in
    let cmp a b = Int.equal 0 (Typ.Procname.Java.compare_java_type a b) in
    assert_equal ~cmp ~pp_diff expected found
  in
  [ ("test_jni_to_java_type_1", T.Boolean, mk_split (None, "bool"))
  ; ( "test_jni_to_java_type_2"
    , T.FullyQualifiedClass ("java.lang", "String")
    , mk_split (Some "java.lang", "String") ) ]
  |> List.map ~f:(fun (name, test_input, expected_output) ->
         name >:: create_test test_input expected_output )


let test_jni_to_java_type_with_invalid_input =
  let run () = T.to_java_type (Method ([], Void)) in
  let expected_exception =
    Logging.InferUserError "Cannot express a method as a Procname.Java.java_type"
  in
  let do_assert _ = assert_raises expected_exception run in
  "test_jni_to_java_type_with_method_should_fail" >:: do_assert


let test_from_json_string_with_valid_input =
  let create_test input expected _ =
    let expected = JavaProfilerSamples.ProfilerSample.of_list expected in
    let found = JavaProfilerSamples.from_json_string input in
    assert_equal ~cmp:JavaProfilerSamples.ProfilerSample.equal expected found
  in
  let input1 = "{\"whatever\": {}, \"methods\": [], \"foo\": {}}" in
  let expected1 = [] in
  let input2 =
    "{\"whatever\": {}, \"methods\": [{\"class\": \"aaa.bbb.Ccc\", \"boo\": \"\", \"method\": \
     \"methodOne\", \"signature\": \"()V\", \"wat\": \"\"},{\"class\": \"ddd.eee.Fff\", \"boo\": \
     \"\", \"method\": \"methodTwo\", \"signature\": \"(Ljava/lang/String;[IJ)[[C\", \"wat\": \
     \"\"},{\"class\": \"ggg.hhh.Iii\", \"boo\": \"\", \"method\": \"<clinit>\", \"signature\": \
     \"(Ljava/lang/String;[IJ)V\", \"wat\": \"\"},{\"class\": \"lll.mmm.Nnn\", \"boo\": \"\", \
     \"method\": \"<init>\", \"signature\": \"(Ljava/lang/String;[IJ)V\", \"wat\": \"\"}], \
     \"foo\": {}}"
  in
  let expected2 =
    [ Typ.Procname.(
        Java
          (Java.make
             (Typ.Name.Java.from_string "lll.mmm.Nnn")
             None "<init>"
             [ mk_split (Some "java.lang", "String")
             ; mk_split (None, "int[]")
             ; mk_split (None, "long") ]
             Java.Static))
    ; Typ.Procname.(
        Java
          (Java.make
             (Typ.Name.Java.from_string "lll.mmm.Nnn")
             None "<init>"
             [ mk_split (Some "java.lang", "String")
             ; mk_split (None, "int[]")
             ; mk_split (None, "long") ]
             Java.Non_Static))
    ; Typ.Procname.(
        Java
          (Java.make
             (Typ.Name.Java.from_string "ggg.hhh.Iii")
             None "<clinit>"
             [ mk_split (Some "java.lang", "String")
             ; mk_split (None, "int[]")
             ; mk_split (None, "long") ]
             Java.Static))
    ; Typ.Procname.(
        Java
          (Java.make
             (Typ.Name.Java.from_string "ggg.hhh.Iii")
             None "<clinit>"
             [ mk_split (Some "java.lang", "String")
             ; mk_split (None, "int[]")
             ; mk_split (None, "long") ]
             Java.Non_Static))
    ; Typ.Procname.(
        Java
          (Java.make
             (Typ.Name.Java.from_string "ddd.eee.Fff")
             (Some (mk_split (None, "char[][]")))
             "methodTwo"
             [ mk_split (Some "java.lang", "String")
             ; mk_split (None, "int[]")
             ; mk_split (None, "long") ]
             Java.Static))
    ; Typ.Procname.(
        Java
          (Java.make
             (Typ.Name.Java.from_string "ddd.eee.Fff")
             (Some (mk_split (None, "char[][]")))
             "methodTwo"
             [ mk_split (Some "java.lang", "String")
             ; mk_split (None, "int[]")
             ; mk_split (None, "long") ]
             Java.Non_Static))
    ; Typ.Procname.(
        Java
          (Java.make
             (Typ.Name.Java.from_string "aaa.bbb.Ccc")
             (Some (mk_split (None, "void")))
             "methodOne" [] Java.Static))
    ; Typ.Procname.(
        Java
          (Java.make
             (Typ.Name.Java.from_string "aaa.bbb.Ccc")
             (Some (mk_split (None, "void")))
             "methodOne" [] Java.Non_Static)) ]
  in
  [("test_from_json_string_1", input1, expected1); ("test_from_json_string_2", input2, expected2)]
  |> List.map ~f:(fun (name, test_input, expected_output) ->
         name >:: create_test test_input expected_output )


let test_from_json_string_with_invalid_input =
  let create_test input expected_exception _ =
    let run () = JavaProfilerSamples.from_json_string input in
    assert_raises expected_exception run
  in
  [ ( "test_from_json_string_1"
    , "{\"whatever\": {}, \"methods\": []}"
    , Logging.InferUserError "Unexpected JSON input for the collection of methods" )
  ; ( "test_from_json_string_2"
    , "{\"whatever\": {}, \"methods\": [{\"class\": \"aaa.bbb.Ccc\", \"boo\": \"\", \"method\": \
       \"methodOne\", \"signature\": \"()V\"}], \"foo\": {}}"
    , Logging.InferUserError "Unexpected JSON input for the description of a single method" )
  ; ("test_from_json_string_3", "(", Yojson.Json_error "Line 1, bytes 0-1:\nInvalid token '('") ]
  |> List.map ~f:(fun (name, test_input, expected_exception) ->
         name >:: create_test test_input expected_exception )


let tests =
  "java_profiler_samples"
  >::: test_jni_to_java_type_with_invalid_input :: test_jni_parse_str_with_valid_input
       @ test_jni_parse_str_with_invalid_input @ test_jni_parse_method_str_with_invalid_input
       @ test_jni_pp @ test_jni_to_java_type_with_valid_input
       @ test_from_json_string_with_valid_input @ test_from_json_string_with_invalid_input

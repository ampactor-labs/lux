  ;; ═══ WAT Fragment Data Segments ═════════════════════════════════════
  ;; Raw byte strings for WAT syntax emission. No length prefix —
  ;; these are used with emit_cstr(addr, len).
  ;;
  ;; Address map (starting at 536, each aligned to next available byte):
  ;;
  ;; 536  "(local.get "   11 bytes  → 547
  ;; 548  "(local.set "   11 bytes  → 559
  ;; 560  "(i32.const "   11 bytes  → 571
  ;; 572  "(call "         6 bytes  → 578
  ;; 578  "(drop "         6 bytes  → 584
  ;; 584  "(func "         6 bytes  → 590
  ;; 590  "(param "        7 bytes  → 597
  ;; 597  " (result i32)"  13 bytes → 610
  ;; 610  "(local "        7 bytes  → 617
  ;; 617  "(if (result i32) " 18 bytes → 635
  ;; 635  "(then "         6 bytes  → 641
  ;; 641  "(else "         6 bytes  → 647
  ;; 647  "(block "        7 bytes  → 654
  ;; 654  "(loop "         6 bytes  → 660
  ;; 660  "(br "           4 bytes  → 664
  ;; 664  "(br_if "        7 bytes  → 671
  ;; 671  "(return "       8 bytes  → 679
  ;; 679  "(i32.add "      9 bytes  → 688
  ;; 688  "(i32.sub "      9 bytes  → 697
  ;; 697  "(i32.mul "      9 bytes  → 706
  ;; 706  "(i32.div_s "   11 bytes  → 717
  ;; 717  "(i32.rem_s "   11 bytes  → 728
  ;; 728  "(i32.eq "       8 bytes  → 736
  ;; 736  "(i32.ne "       8 bytes  → 744
  ;; 744  "(i32.lt_s "    10 bytes  → 754
  ;; 754  "(i32.gt_s "    10 bytes  → 764
  ;; 764  "(i32.le_s "    10 bytes  → 774
  ;; 774  "(i32.ge_s "    10 bytes  → 784
  ;; 784  "(i32.and "      9 bytes  → 793
  ;; 793  "(i32.or "       8 bytes  → 801
  ;; 801  "(i32.eqz "      9 bytes  → 810
  ;; 810  "(i32.store "   11 bytes  → 821
  ;; 821  "(i32.load "    10 bytes  → 831
  ;; 831  "(module"        7 bytes  → 838
  ;; 838  "(memory "       8 bytes  → 846
  ;; 846  "(export "       8 bytes  → 854
  ;; 854  "(import "       8 bytes  → 862
  ;; 862  "(global "       8 bytes  → 870
  ;; 870  "(table "        7 bytes  → 877
  ;; 877  "(elem "         6 bytes  → 883
  ;; 883  "(i32.store8 "  12 bytes  → 895
  ;; 895  "(i32.load8_u " 13 bytes  → 908
  ;; 908  " i32"           4 bytes  → 912
  ;; 912  "(data "         6 bytes  → 918
  ;; 918  "(type "         6 bytes  → 924
  ;; 924  "(func"          5 bytes  → 929
  ;; 929  "offset="        7 bytes  → 936
  ;; 936  "(select "       8 bytes  → 944
  ;; 944  "(i32.sub (i32.const 0) " 24 bytes → 968
  ;;
  ;; Next free: 968
  ;;
  ;; NOTE: these overlap with the bump allocator's sentinel region
  ;; (0-4096) but that's fine — sentinels are identified by value,
  ;; not by reading memory at those addresses. The allocator starts
  ;; at 1 MiB (1048576). Data segments are written at module load
  ;; time before any allocation happens.

  (data (i32.const 536) "(local.get ")
  (data (i32.const 548) "(local.set ")
  (data (i32.const 560) "(i32.const ")
  (data (i32.const 572) "(call ")
  (data (i32.const 578) "(drop ")
  (data (i32.const 584) "(func ")
  (data (i32.const 590) "(param ")
  (data (i32.const 597) " (result i32)")
  (data (i32.const 610) "(local ")
  (data (i32.const 617) "(if (result i32) ")
  (data (i32.const 635) "(then ")
  (data (i32.const 641) "(else ")
  (data (i32.const 647) "(block ")
  (data (i32.const 654) "(loop ")
  (data (i32.const 660) "(br ")
  (data (i32.const 664) "(br_if ")
  (data (i32.const 671) "(return ")
  (data (i32.const 679) "(i32.add ")
  (data (i32.const 688) "(i32.sub ")
  (data (i32.const 697) "(i32.mul ")
  (data (i32.const 706) "(i32.div_s ")
  (data (i32.const 717) "(i32.rem_s ")
  (data (i32.const 728) "(i32.eq ")
  (data (i32.const 736) "(i32.ne ")
  (data (i32.const 744) "(i32.lt_s ")
  (data (i32.const 754) "(i32.gt_s ")
  (data (i32.const 764) "(i32.le_s ")
  (data (i32.const 774) "(i32.ge_s ")
  (data (i32.const 784) "(i32.and ")
  (data (i32.const 793) "(i32.or ")
  (data (i32.const 801) "(i32.eqz ")
  (data (i32.const 810) "(i32.store ")
  (data (i32.const 821) "(i32.load ")
  (data (i32.const 831) "(module")
  (data (i32.const 838) "(memory ")
  (data (i32.const 846) "(export ")
  (data (i32.const 854) "(import ")
  (data (i32.const 862) "(global ")
  (data (i32.const 870) "(table ")
  (data (i32.const 877) "(elem ")
  (data (i32.const 883) "(i32.store8 ")
  (data (i32.const 895) "(i32.load8_u ")
  (data (i32.const 908) " i32")
  (data (i32.const 912) "(data ")
  (data (i32.const 918) "(type ")
  (data (i32.const 924) "(func")
  (data (i32.const 929) "offset=")
  (data (i32.const 936) "(select ")
  (data (i32.const 944) "(i32.sub (i32.const 0) ")

  ;; Additional: runtime function name strings for emitter
  ;; 968: "str_concat"  (10 bytes) → 978
  ;; 978: "call_indirect" (13 bytes) → 991
  ;; 991: "str_alloc"  (9 bytes) → 1000
  ;; 1000: "record_get" (10 bytes) → 1010
  ;; 1010: "make_list"  (9 bytes) → 1019
  ;; 1019: "list_set"   (8 bytes) → 1027
  ;; 1027: "list_index" (10 bytes) → 1037
  ;; 1037: "tag_of"     (6 bytes) → 1043
  ;; 1043: "str_from_mem" (12 bytes) → 1055
  ;; 1055: "alloc"      (5 bytes) → 1060
  ;; 1060: "str_len"    (7 bytes) → 1067
  ;; 1067: "byte_at"    (7 bytes) → 1074
  ;; 1074: "str_eq"     (6 bytes) → 1080
  ;; Next free: 1080

  (data (i32.const 968) "str_concat")
  (data (i32.const 978) "call_indirect")
  (data (i32.const 991) "str_alloc")
  (data (i32.const 1000) "record_get")
  (data (i32.const 1010) "make_list")
  (data (i32.const 1019) "list_set")
  (data (i32.const 1027) "list_index")
  (data (i32.const 1037) "tag_of")
  (data (i32.const 1043) "str_from_mem")
  (data (i32.const 1055) "alloc")
  (data (i32.const 1060) "str_len")
  (data (i32.const 1067) "byte_at")
  (data (i32.const 1074) "str_eq")

  ;; 1080: "__match_" (8 bytes) → 1088
  ;; 1088: "ctor_tag" (8 bytes) → 1096
  ;; Next free: 1096
  (data (i32.const 1080) "__match_")
  (data (i32.const 1088) "ctor_tag")

  ;; Module emission strings
  ;; 1096: "memory"  (6 bytes) → 1102
  ;; 1102: "heap_ptr" (8 bytes) → 1110
  ;; 1110: " (mut i32) " (12 bytes, with leading/trailing space) → 1122
  ;; 1122: "wasi_snapshot_preview1" (22 bytes) → 1144
  ;; But wait - that's 22 bytes not 13. Let me recalculate.
  ;; Actually "wasi_snapshot_preview1" is 22 chars. Let me fix the emit_module references.
  ;; 1096: "memory" (6) → 1102
  ;; 1102: "heap_ptr" (8) → 1110
  ;; 1110: " (mut i32) " (11) → 1121
  ;; 1121: "wasi_snapshot_preview1" (22) → 1143
  ;; 1143: "fd_write" (8) → 1151
  ;; 1151: "wasi_fd_write" (13) → 1164
  ;; 1164: " (param i32 i32 i32 i32) (result i32)" (38) → 1202
  ;; 1202: "fd_read" (7) → 1209
  ;; 1209: "wasi_fd_read" (12) → 1221
  ;; 1221: "proc_exit" (9) → 1230
  ;; 1230: "wasi_proc_exit" (14) → 1244
  ;; 1244: " (param i32)" (12) → 1256
  ;; 1256: " (param $size i32)" (18 — but we only need 15 "(param $size i32)") → let me use 15
  ;; Actually: " (param $size i32)" is 19 chars. Use 19.
  ;; 1256: " (param $size i32)" (19) → 1275
  ;; 1275-1475: alloc function body as raw WAT text (200 bytes)
  ;; 1475: " (param $v i32)" (16) → 1491
  ;; Next free: ~1491

  (data (i32.const 1096) "memory")
  (data (i32.const 1102) "heap_ptr")
  (data (i32.const 1110) " (mut i32) ")
  (data (i32.const 1121) "wasi_snapshot_preview1")
  (data (i32.const 1143) "fd_write")
  (data (i32.const 1151) "wasi_fd_write")
  (data (i32.const 1164) " (param i32 i32 i32 i32) (result i32)")
  (data (i32.const 1202) "fd_read")
  (data (i32.const 1209) "wasi_fd_read")
  (data (i32.const 1221) "proc_exit")
  (data (i32.const 1230) "wasi_proc_exit")
  (data (i32.const 1244) " (param i32)")
  (data (i32.const 1256) " (param $size i32)")
  ;; Alloc body as raw WAT (padded to 200 bytes with spaces)
  (data (i32.const 1275) "(local $ptr i32)(local.set $ptr (global.get $heap_ptr))(global.set $heap_ptr (i32.add (global.get $heap_ptr)(i32.and (i32.add (local.get $size)(i32.const 7))(i32.const -8))))(local.get $ptr)                  ")
  (data (i32.const 1475) " (param $v i32)")

  ;; 1491: "_start_fn" (9) → 1500
  ;; 1500: " (export \"_start\")" (19, including escaped quotes) → 1519
  ;; But WAT data segments need literal bytes. The quotes are 0x22.
  ;; " (export \22_start\22)" — use \22 for double quote in data segment
  ;; Next free: 1519

  (data (i32.const 1491) "_start_fn")
  (data (i32.const 1500) " (export \22_start\22)")
  ;; Next free in emit_data.wat: 1519 (but 1520+ is claimed by
  ;; emit/emit_const.wat — see emit_const.wat:143). Phase F strings
  ;; live in emit/main.wat's own segment range (1584+).

import sys

file_path = "std/compiler/lower.lux"
with open(file_path, "r") as f:
    text = f.read()

def replace_in_func(func_name, code):
    lines = code.split('\n')
    out_lines = []
    in_func = False
    for line in lines:
        if line.startswith(f"fn {func_name}"):
            in_func = True
        elif in_func and line.startswith("fn "):
            in_func = False
            
        if in_func:
            line = line.replace("list_head", "list_first")
            line = line.replace("list_tail", "list_rest")
        out_lines.append(line)
    return '\n'.join(out_lines)

targets = [
    "install_evidence_from_record",
    "install_stateful_evidence",
    "build_rewrite_map_from_names",
    "save_op_bindings",
    "restore_op_bindings",
    "gen_state_names",
    "lower_state_updates",
    "save_state_globals",
    "restore_state_globals",
    "subst_state_to_cells",
    "is_orig_state_name",
    "filter_out_hs_names",
    "remap_rewrites_to_cells",
    "bind_rewrite_params",
    "lookup_rewrite",
    "flatten_blocks"
]

for t in targets:
    text = replace_in_func(t, text)

with open(file_path, "w") as f:
    f.write(text)

print("Done phase 2 fixes")

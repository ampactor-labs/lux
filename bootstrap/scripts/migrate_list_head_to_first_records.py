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

text = replace_in_func("lower_record_fields", text)
text = replace_in_func("infer_record_field_types", text)
text = replace_in_func("sort_fields_for_lower", text)
text = replace_in_func("insert_field_sorted", text)
text = replace_in_func("extract_record_ty_names", text)
text = replace_in_func("lower_field_name_list", text)

with open(file_path, "w") as f:
    f.write(text)

print("Done")

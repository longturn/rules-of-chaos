def to_lua(obj):
    if isinstance(obj, str):
        return f'"{value}"'
    elif isinstance(obj, bool):
        return str(obj).lower()
    elif isinstance(obj, dict):
        lua_items = [f'{key} = {to_lua(value)}' for key, value in obj.items()]
        return "{ " + ", ".join(lua_items) + " }"
        #lua_table = "{ "
        #for key, value in obj.items():
        #    lua_value = to_lua(value)  # Recursively convert nested dicts
        #    lua_table += f'{key} = {lua_value}, '
        #lua_table += " }"
        #return lua_table
    else:
        return str(obj)


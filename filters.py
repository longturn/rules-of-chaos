def to_lua(obj):
    if isinstance(obj, str):
        return f'"{value}"'
    elif isinstance(obj, bool):
        return str(obj).lower()
    elif isinstance(obj, dict):
        lua_items = [f'{key} = {to_lua(value)}' for key, value in obj.items()]
        return "{ " + ", ".join(lua_items) + " }"
    else:
        return str(obj)


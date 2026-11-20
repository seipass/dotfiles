import ast
import base64
import colorsys
import datetime as dt
import json
import math
import operator
import re
import sys
import urllib.parse
import urllib.request
import unicodedata
from pathlib import Path
from zoneinfo import ZoneInfo, available_timezones


def timezone(name):
    key = name.strip().casefold().replace(" ", "_")
    key = {"東京": "asia/tokyo", "ロンドン": "europe/london", "jst": "asia/tokyo", "gmt": "utc"}.get(key, key)
    zones = available_timezones()
    exact = next((zone for zone in zones if zone.casefold() == key), None)
    if exact:
        return ZoneInfo(exact)
    matches = sorted(zone for zone in zones if zone.rsplit("/", 1)[-1].casefold() == key)
    if len(matches) == 1:
        return ZoneInfo(matches[0])
    raise ValueError(f"{'Ambiguous' if matches else 'Unknown'} time zone: {name}")


def calculate(node):
    if isinstance(node, ast.Constant) and type(node.value) in (int, float):
        value = node.value
    elif isinstance(node, ast.Name) and node.id in ("pi", "e", "tau"):
        value = getattr(math, node.id)
    elif isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and len(node.args) == 1 and not node.keywords:
        functions = {"sqrt": math.sqrt, "sin": math.sin, "cos": math.cos, "tan": math.tan,
                     "ln": math.log, "log": math.log10, "abs": abs}
        if node.func.id not in functions:
            raise ValueError("Unknown calculator function")
        value = functions[node.func.id](calculate(node.args[0]))
    elif isinstance(node, ast.UnaryOp) and type(node.op) in (ast.UAdd, ast.USub):
        value = calculate(node.operand) * (-1 if isinstance(node.op, ast.USub) else 1)
    elif isinstance(node, ast.BinOp):
        a, b = calculate(node.left), calculate(node.right)
        if isinstance(node.op, ast.Pow) and abs(b) > 100:
            raise ValueError("Exponent too large")
        value = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul,
                 ast.Div: operator.truediv, ast.Mod: operator.mod, ast.Pow: operator.pow}[type(node.op)](a, b)
    else:
        raise ValueError("Use numbers and arithmetic operators")
    if not math.isfinite(value) or abs(value) > 1e100:
        raise ValueError("Result out of range")
    return value


def result(mode, value):
    if mode == "emoji":
        data = json.loads(Path(__file__).with_name("launcher-data").joinpath("emoji.json").read_text())
        terms = value.casefold().split()
        return {"emoji": [[emoji, names[0].replace("_", " ")] for emoji, names in data.items()
                          if names and all(term in " ".join(names).replace("_", " ") or term in emoji for term in terms)][:80]}
    if mode == "calc":
        value = unicodedata.normalize("NFKC", value).lower().translate(str.maketrans({"π": "pi", "×": "*", "÷": "/", "−": "-"})).replace("^", "**")
        value = re.sub(r"(?<=[\d)])\s*(?=(?:pi|tau)\b)", "*", value)
        return {"text": format(calculate(ast.parse(value, mode="eval").body), ".14g")}
    if mode == "time":
        value = unicodedata.normalize("NFKC", value).replace("−", "-")
        if match := re.fullmatch(r"(\d{1,2}:\d{2})\s*([+-].+)", value):
            start = dt.datetime.strptime(match[1], "%H:%M")
            total = 0
            for sign, term in re.findall(r"([+-])([^+-]*)", match[2]):
                term = term.strip().lower()
                if clock := re.fullmatch(r"(\d+):([0-5]\d)", term):
                    minutes = int(clock[1]) * 60 + int(clock[2])
                elif re.fullmatch(r"(?:\d+\s*[dhm]\s*)+", term):
                    minutes = sum(int(n) * {"d": 1440, "h": 60, "m": 1}[unit]
                                  for n, unit in re.findall(r"(\d+)\s*([dhm])", term))
                else:
                    raise ValueError("Use durations like 2h 30m or 1:45")
                total += minutes if sign == "+" else -minutes
            end = start + dt.timedelta(minutes=total)
            days = (end.date() - start.date()).days
            return {"text": end.strftime("%H:%M") + (f" ({days:+} days)" if days else "")}
        parts = re.split(r"\s+to\s+|\s*(?:→|->)\s*", value, maxsplit=1, flags=re.I)
        if len(parts) == 2:
            source, target = parts
            clock = re.fullmatch(r"(\d{1,2}:\d{2})\s+(.+)", source)
            origin = timezone(clock[2] if clock else source)
            stamp = dt.datetime.now(origin)
            if clock:
                local_time = dt.datetime.strptime(clock[1], "%H:%M").time()
                stamp = dt.datetime.combine(stamp.date(), local_time, origin)
            zone = timezone(target)
        else:
            stamp, zone = dt.datetime.now(dt.timezone.utc), timezone(value)
        converted = stamp.astimezone(zone).strftime("%Y-%m-%d %H:%M %Z (UTC%z)")
        return {"text": f"{stamp:%H:%M %Z} → {converted}" if len(parts) == 2 else converted}
    if mode == "color":
        if re.fullmatch(r"#?[0-9a-fA-F]{3}(?:[0-9a-fA-F]{3})?", value):
            code = value.lstrip("#")
            if len(code) == 3:
                code = "".join(c * 2 for c in code)
            rgb = tuple(int(code[i:i+2], 16) for i in (0, 2, 4))
        elif match := re.fullmatch(r"rgb\(\s*(\d+),\s*(\d+),\s*(\d+)\s*\)", value, re.I):
            rgb = tuple(map(int, match.groups()))
            if max(rgb) > 255:
                raise ValueError("RGB channels must be 0–255")
        elif match := re.fullmatch(r"hsl\(\s*(-?\d+(?:\.\d+)?),\s*(\d+(?:\.\d+)?)%,\s*(\d+(?:\.\d+)?)%\s*\)", value, re.I):
            h, s, l = map(float, match.groups())
            if max(s, l) > 100:
                raise ValueError("Saturation and lightness must be 0–100%")
            rgb = tuple(round(c * 255) for c in colorsys.hls_to_rgb(h % 360 / 360, l / 100, s / 100))
        else:
            raise ValueError("Enter HEX, rgb(r, g, b), or hsl(h, s%, l%)")
        h, l, s = colorsys.rgb_to_hls(*(c / 255 for c in rgb))
        hexcode = "#%02X%02X%02X" % rgb
        return {"text": f"{hexcode}   rgb{rgb}   hsl({h*360:.1f}, {s*100:.1f}%, {l*100:.1f}%)", "color": hexcode}
    if mode == "qr":
        sys.path.insert(0, str(Path(__file__).with_name("launcher-data")))
        import qrcode
        qr = qrcode.QRCode()
        qr.add_data(value)
        qr.make()
        grid = qr.get_matrix()
        n = len(grid)
        path = "".join(f"M{x} {y}h1v1h-1z" for y, row in enumerate(grid) for x, cell in enumerate(row) if cell)
        svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {n} {n}"><rect width="{n}" height="{n}" fill="white"/><path d="{path}"/></svg>'
        return {"text": "Scan this QR code", "image": "data:image/svg+xml;base64," + base64.b64encode(svg.encode()).decode()}
    if mode == "weather":
        city = urllib.parse.quote(value, safe="")
        with urllib.request.urlopen(f"https://wttr.in/{city}?format=j1", timeout=6) as response:
            data = json.load(response)
        rows = [f'{day["date"]}   {day["mintempC"]}–{day["maxtempC"]} °C   {day["hourly"][4]["weatherDesc"][0]["value"]}'
                for day in data["weather"][:3]]
        return {"text": "\n".join(rows)}
    raise ValueError("Unknown tool")


if __name__ == "__main__":
    try:
        mode, value = sys.argv[1:3]
        if len(value) > ({"qr": 800, "time": 4096}.get(mode, 160)):
            raise ValueError("Input too long")
        print(json.dumps(result(mode, value), ensure_ascii=False))
    except Exception as error:
        print(json.dumps({"error": str(error) or "Could not calculate result"}))

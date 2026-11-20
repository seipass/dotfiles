#!/usr/bin/env python3
import sys
import json
import urllib.request
import urllib.parse

def main():
    if len(sys.argv) < 2:
        print("[]")
        return

    query = sys.argv[1].strip()
    if not query:
        print("[]")
        return

    url = f"https://geocoding-api.open-meteo.com/v1/search?name={urllib.parse.quote(query)}&count=6&format=json"
    req = urllib.request.Request(url, headers={"User-Agent": "quickshell-settings/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=3.5) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            results = []
            for item in data.get("results", []):
                name = item.get("name", "")
                admin = item.get("admin1") or item.get("admin2") or ""
                country = item.get("country", "")
                results.append({
                    "name": name,
                    "admin": admin,
                    "country": country,
                    "fullName": f"{name}, {country}" if country and country != name else name
                })
            print(json.dumps(results))
    except Exception:
        print("[]")

if __name__ == "__main__":
    main()

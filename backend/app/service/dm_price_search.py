import csv
import io
import json
import re
from typing import Any

import requests

from app.util.units import KG, ML, PIECE, G, L

# Official dm-drogerie markt MCP server (dmTECH) - fixed, trusted host.
_MCP_URL = "https://mcp.dm.de/mcp"
_TIMEOUT = 8
_HEADERS = {
    "Content-Type": "application/json",
    "Accept": "application/json, text/event-stream",
}

_TOON_HEADER_RE = re.compile(r"^\S*\[(\d+)\]\{(.*?)\}:\r?\n", re.DOTALL)
_PRICE_RE = re.compile(r"([\d.,]+)")
_WEIGHT_RE = re.compile(r"(\d+(?:[.,]\d+)?)\s*(kg|g)\b", re.IGNORECASE)
_VOLUME_RE = re.compile(r"(\d+(?:[.,]\d+)?)\s*(l|ml)\b", re.IGNORECASE)
_AMOUNT_UNIT_RE = re.compile(r"^\s*([\d.,]+)\s*(kg|g|l|ml)\s*$", re.IGNORECASE)
_UNIT_MAP = {"g": G, "kg": KG, "l": L, "ml": ML}


def _parseSseEvent(text: str) -> dict[str, Any]:
    for line in text.splitlines():
        if line.startswith("data:"):
            return json.loads(line[len("data:") :].strip())
    raise ValueError("dm MCP: no data frame in response")


def _parseToonTable(raw: str) -> list[dict[str, str]]:
    match = _TOON_HEADER_RE.match(raw)
    if not match:
        return []

    count = int(match.group(1))
    delimiter = "|" if "|" in match.group(2) else ","
    fields = match.group(2).split(delimiter)
    body = raw[match.end() :]

    rows = []
    for row in csv.reader(io.StringIO(body), delimiter=delimiter, quotechar='"'):
        if len(row) < len(fields):
            continue
        rows.append({k: v.strip() for k, v in zip(fields, row)})
        if len(rows) >= count:
            break

    return rows


def _mcpInitializeSession() -> str:
    resp = requests.post(
        _MCP_URL,
        headers=_HEADERS,
        timeout=_TIMEOUT,
        json={
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2025-06-18",
                "capabilities": {},
                "clientInfo": {"name": "kitchenowl", "version": "1.0"},
            },
        },
    )
    resp.raise_for_status()
    session_id = resp.headers["Mcp-Session-Id"]

    notify_headers = dict(_HEADERS, **{"Mcp-Session-Id": session_id})
    notify_resp = requests.post(
        _MCP_URL,
        headers=notify_headers,
        timeout=_TIMEOUT,
        json={"jsonrpc": "2.0", "method": "notifications/initialized"},
    )
    notify_resp.raise_for_status()

    return session_id


def _mcpCallTool(
    session_id: str, call_id: int, name: str, arguments: dict[str, Any]
) -> list[dict[str, str]]:
    headers = dict(_HEADERS, **{"Mcp-Session-Id": session_id})
    resp = requests.post(
        _MCP_URL,
        headers=headers,
        timeout=_TIMEOUT,
        json={
            "jsonrpc": "2.0",
            "id": call_id,
            "method": "tools/call",
            "params": {"name": name, "arguments": arguments},
        },
    )
    resp.raise_for_status()
    # requests guesses ISO-8859-1 for text/event-stream (no charset param in
    # the content-type), which would corrupt non-ASCII bytes (e.g. "€"); the
    # server actually sends UTF-8, so decode the raw bytes explicitly.
    envelope = _parseSseEvent(resp.content.decode("utf-8"))
    result = envelope["result"]
    if result.get("isError"):
        raise RuntimeError(f"dm MCP tool {name} returned an error")

    # content[0].text is a JSON-encoded string containing {"result": ...}.
    # Depending on the tool, "result" is either the raw TOON table text
    # directly (getProductDetails), or that same text JSON-encoded as a
    # 1-element array (searchProducts) - handle both shapes.
    inner = json.loads(result["content"][0]["text"])
    return _parseToonTable(_extractTableText(inner["result"]))


def _extractTableText(rawResult: str) -> str:
    if _TOON_HEADER_RE.match(rawResult):
        return rawResult
    unwrapped = json.loads(rawResult)
    return unwrapped[0] if isinstance(unwrapped, list) else unwrapped


def _parseGermanPrice(text: str) -> float | None:
    match = _PRICE_RE.search(text or "")
    if not match:
        return None
    raw = match.group(1)
    if "," in raw:
        raw = raw.replace(".", "").replace(",", ".")
    return float(raw)


def _parsePackSize(title: str, weight: str, volume: str) -> tuple[float, str]:
    # dm's structured weight/volume detail fields are shipping estimates
    # (e.g. gross weight incl. packaging), not the declared net content -
    # the actual pack size is only reliably given in the product title
    # (e.g. "Ahornsirup Grad A, 250 ml"). Only fall back to the detail
    # fields when the title doesn't state an amount.
    match = _WEIGHT_RE.search(title)
    if match:
        amount = float(match.group(1).replace(",", "."))
        return amount, (KG if match.group(2).lower() == "kg" else G)
    match = _VOLUME_RE.search(title)
    if match:
        amount = float(match.group(1).replace(",", "."))
        return amount, (L if match.group(2).lower() == "l" else ML)

    for value in (weight, volume):
        if not value:
            continue
        match = _AMOUNT_UNIT_RE.match(value)
        if match:
            amount = float(match.group(1).replace(",", "."))
            return amount, _UNIT_MAP[match.group(2).lower()]

    return 1.0, PIECE


def searchDmArticles(query: str, limit: int = 10) -> list[dict[str, Any]]:
    session_id = _mcpInitializeSession()

    searchRows = _mcpCallTool(
        session_id, 2, "searchProducts", {"query": query}
    )[:limit]

    dans: list[int] = []
    for row in searchRows:
        dan = row.get("dan")
        if dan:
            try:
                dans.append(int(dan))
            except ValueError:
                pass

    detailsByDan: dict[str, dict[str, str]] = {}
    if dans:
        detailRows = _mcpCallTool(
            session_id, 3, "getProductDetails", {"dans": dans}
        )
        detailsByDan = {r["dan"]: r for r in detailRows if r.get("dan")}

    results = []
    for row in searchRows:
        title = row.get("title")
        price = _parseGermanPrice(row.get("price", ""))
        if not title or price is None:
            continue

        detail = detailsByDan.get(row.get("dan", ""), {})
        packAmount, packUnit = _parsePackSize(
            title, detail.get("weight", ""), detail.get("volume", "")
        )
        results.append(
            {
                "title": title,
                "image_url": detail.get("image") or None,
                "price": price,
                "pack_amount": packAmount,
                "pack_unit": packUnit,
                "piece_weight": None,
                # The DAN - lets app.service.price_refresh re-find this exact
                # product in a later search (dm has no fetch-by-id endpoint).
                "external_ref": row.get("dan") or None,
            }
        )

    return results

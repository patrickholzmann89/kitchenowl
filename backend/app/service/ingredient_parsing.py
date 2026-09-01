import json
import os
import re
from typing import cast

import ingredient_parser
import ingredient_parser.dataclasses
import pint
from litellm import completion

from app.config import SUPPORTED_LANGUAGES
from app.util.units import KG, ML, PIECE, G, L

LLM_MODEL = os.getenv("LLM_MODEL")
LLM_API_URL = os.getenv("LLM_API_URL")


class IngredientParsingResult:
    originalText: str | None = None
    name: str | None = None
    description: str | None = None
    # Structured quantity, in KitchenOwl's fixed unit vocabulary
    # (piece/mg/g/kg/ml/l) - only set when cleanly derivable; otherwise the
    # quantity stays as free text folded into `description`, as before.
    amount: float | None = None
    unit: str | None = None

    def __init__(self, original_text, name, description, amount=None, unit=None):
        self.originalText = original_text
        self.name = name
        self.description = description
        self.amount = amount
        self.unit = unit

    def __str__(self):
        return f"{self.originalText} -> {self.name} ({self.amount} {self.unit} {self.description})"


# Recognised pint units are converted to grams/millilitres (KitchenOwl's own
# base units, see app.util.units) via real unit conversion (e.g. cup/tbsp/tsp
# -> ml, oz/lb -> g) rather than a hand-written lookup table.
_PINT_CONVERSION_TARGETS = {G: "gram", ML: "milliliter"}


def _nlpAmountToStructured(
    amount: ingredient_parser.dataclasses.IngredientAmount
    | ingredient_parser.dataclasses.CompositeIngredientAmount,
) -> tuple[float | None, str | None, str]:
    """Returns (amount, unit, extra_description_text). extra_description_text
    holds whatever couldn't be folded into amount/unit (e.g. a count-style
    unit like "clove"/"can" with no metric equivalent - the amount still
    becomes a plain piece count, but the noun is kept as text so it isn't
    silently lost)."""
    if isinstance(amount, ingredient_parser.dataclasses.CompositeIngredientAmount):
        return None, None, amount.text

    try:
        qty = float(amount.quantity)
        qtyMax = float(amount.quantity_max)
    except (TypeError, ValueError):
        return None, None, amount.text
    if qty != qtyMax:
        qty = (qty + qtyMax) / 2  # a range (e.g. "2-3") -> its midpoint

    unit = amount.unit
    if isinstance(unit, pint.Unit):
        quantity = qty * unit
        for allowedUnit, pintUnit in _PINT_CONVERSION_TARGETS.items():
            try:
                return round(quantity.to(pintUnit).magnitude, 1), allowedUnit, ""
            except pint.DimensionalityError:
                continue
        # A recognised pint unit that isn't a mass/volume we convert to
        # (unlikely, but keep the amount as a piece count either way).
        return qty, PIECE, str(unit)

    # A plain string unit: "" (bare count, e.g. "2 eggs") or a count-style
    # noun (e.g. "clove", "can") with no metric equivalent.
    return qty, PIECE, (unit or "")


def parseNLP(ingredients: list[str]) -> list[IngredientParsingResult]:
    def parseNLPSingle(ingredient: str) -> IngredientParsingResult:
        parsed = ingredient_parser.parse_ingredient(ingredient)
        if isinstance(parsed.name, list):
            name = parsed.name[0].text if parsed.name else None
        else:
            name = parsed.name.text

        amount = None
        unit = None
        description = ""
        if len(parsed.amount) > 0:
            amount, unit, description = _nlpAmountToStructured(parsed.amount[0])
        # description = description + (" " if description else "") + (parsed.comment.text if parsed.comment else "") # Usually cooking instructions

        return IngredientParsingResult(
            ingredient, name, description, amount=amount, unit=unit
        )

    return [parseNLPSingle(e) for e in ingredients]


# ingredient-parser-nlp is trained on English recipe text only, so it does not
# recognise German quantities/units. This lightweight rule-based fallback is
# used for German households instead, when no LLM is configured.
_GERMAN_NUMBER_WORDS = {
    "ein": "1",
    "eine": "1",
    "einen": "1",
    "einem": "1",
    "einer": "1",
    "zwei": "2",
    "drei": "3",
    "vier": "4",
    "fünf": "5",
    "sechs": "6",
    "sieben": "7",
    "acht": "8",
    "neun": "9",
    "zehn": "10",
    "elf": "11",
    "zwölf": "12",
}

_GERMAN_UNIT_WORDS = [
    "kilogramm",
    "gramm",
    "milliliter",
    "esslöffel",
    "teelöffel",
    "messerspitze",
    "handvoll",
    "packungen",
    "packung",
    "scheiben",
    "scheibe",
    "bündel",
    "bund",
    "zehen",
    "zehe",
    "dosen",
    "dose",
    "gläser",
    "glas",
    "tassen",
    "tasse",
    "würfel",
    "prisen",
    "prise",
    "stück",
    "kg",
    "g",
    "ml",
    "l",
    "el",
    "tl",
    "msp",
    "pkg",
    "pck",
    "stk",
]
# Longest first so e.g. "esslöffel" matches before a shorter, unrelated prefix would.
_GERMAN_UNIT_WORDS.sort(key=len, reverse=True)

# Only units with a clean metric equivalent map to a structured amount/unit;
# count-style words (Zehe, Bund, Scheibe, Prise, ...) have no equivalent and
# are kept as description text instead (see parseGermanSingle).
_GERMAN_UNIT_TO_ALLOWED = {
    "kilogramm": KG,
    "kg": KG,
    "gramm": G,
    "g": G,
    "milliliter": ML,
    "ml": ML,
    "l": L,
}

_GERMAN_UNICODE_FRACTIONS = {
    "¼": 0.25,
    "½": 0.5,
    "¾": 0.75,
    "⅓": 1 / 3,
    "⅔": 2 / 3,
    "⅕": 0.2,
    "⅖": 0.4,
    "⅗": 0.6,
    "⅘": 0.8,
    "⅙": 1 / 6,
    "⅚": 5 / 6,
    "⅛": 0.125,
    "⅜": 0.375,
    "⅝": 0.625,
    "⅞": 0.875,
}
_GERMAN_RANGE_RE = re.compile(r"^(\d+[.,]?\d*)\s*[-–]\s*(\d+[.,]?\d*)$")
_GERMAN_FRACTION_RE = re.compile(r"^(\d+)\s*/\s*(\d+)$")


def _parseGermanQty(qty: str) -> float | None:
    qty = qty.strip()
    if qty in _GERMAN_UNICODE_FRACTIONS:
        return _GERMAN_UNICODE_FRACTIONS[qty]

    rangeMatch = _GERMAN_RANGE_RE.match(qty)
    if rangeMatch:
        # A range (e.g. "2-3") -> its midpoint, matching how the Aldi price
        # search averages a piece-count range (see aldi_price_search.py).
        lo = float(rangeMatch.group(1).replace(",", "."))
        hi = float(rangeMatch.group(2).replace(",", "."))
        return (lo + hi) / 2

    fractionMatch = _GERMAN_FRACTION_RE.match(qty)
    if fractionMatch:
        denominator = int(fractionMatch.group(2))
        return int(fractionMatch.group(1)) / denominator if denominator else None

    try:
        return float(qty.replace(",", "."))
    except ValueError:
        return None


# Trailing \b keeps these from matching as a prefix of an unrelated word, e.g.
# the "ein" in "Eintopf" or the "g" in "Gurke" — since the input is otherwise
# unspaced ("300g"), only a trailing boundary is enforced, not a leading one.
_GERMAN_NUMBER_PATTERN = (
    r"\d+\s*/\s*\d+"
    r"|\d+[.,]?\d*(?:\s*[-–]\s*\d+[.,]?\d*)?"
    r"|[¼½¾⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞]"
    r"|(?:" + "|".join(_GERMAN_NUMBER_WORDS.keys()) + r")\b"
)
_GERMAN_UNIT_PATTERN = (
    "(?:" + "|".join(re.escape(unit) for unit in _GERMAN_UNIT_WORDS) + r")\b"
)

_GERMAN_INGREDIENT_RE = re.compile(
    rf"^\s*(?P<qty>{_GERMAN_NUMBER_PATTERN})?"
    rf"\s*(?P<unit>{_GERMAN_UNIT_PATTERN})?\.?"
    rf"\s*(?P<rest>.*)$",
    re.IGNORECASE,
)
_PARENTHETICAL_RE = re.compile(r"\(([^)]*)\)")

# Descriptive adjectives/participles that commonly sit between the
# quantity/unit and the actual ingredient noun (e.g. "500g kleine
# Kartoffeln", "eiskaltes Wasser", "gehackte Petersilie"). Left in place they
# break the "starts with" item lookup against the household's pantry, since
# the item is named after the noun, not the description. Stripped into the
# description instead, matching how a trailing comma clause is handled.
_GERMAN_ADJECTIVE_STEMS = [
    "klein",
    "groß",
    "frisch",
    "gehackt",
    "gewürfelt",
    "gerieben",
    "gepresst",
    "getrocknet",
    "eiskalt",
    "kalt",
    "warm",
    "heiß",
    "weich",
    "hart",
    "reif",
    "geschält",
    "entkernt",
    "fein",
    "grob",
    "ganz",
    "halbiert",
    "geviertelt",
    "zerkleinert",
    "gemahlen",
]
_GERMAN_ADJECTIVE_RE = re.compile(
    r"^(?:(?:" + "|".join(_GERMAN_ADJECTIVE_STEMS) + r")(?:e|er|es|en|em)?\s+)+",
    re.IGNORECASE,
)


def parseGerman(ingredients: list[str]) -> list[IngredientParsingResult]:
    def parseGermanSingle(ingredient: str) -> IngredientParsingResult:
        text = ingredient.strip()
        notes = [n.strip() for n in _PARENTHETICAL_RE.findall(text) if n.strip()]
        text_without_parens = _PARENTHETICAL_RE.sub(" ", text).strip()

        match = _GERMAN_INGREDIENT_RE.match(text_without_parens)
        qty = match.group("qty").strip() if match and match.group("qty") else None
        unit = match.group("unit").strip() if match and match.group("unit") else None
        rest = match.group("rest").strip() if match else text_without_parens

        if qty and qty.lower() in _GERMAN_NUMBER_WORDS:
            qty = _GERMAN_NUMBER_WORDS[qty.lower()]

        adjectiveMatch = _GERMAN_ADJECTIVE_RE.match(rest)
        adjective = adjectiveMatch.group().strip() if adjectiveMatch else None
        if adjectiveMatch:
            rest = rest[adjectiveMatch.end() :]

        # Anything after the first comma is a preparation note (e.g. "gehackt"),
        # not part of the ingredient name.
        name = rest.split(",")[0].strip(" .-") or text_without_parens

        amount = _parseGermanQty(qty) if qty else None

        allowedUnit = None
        descriptionUnitText = None
        if unit:
            allowedUnit = _GERMAN_UNIT_TO_ALLOWED.get(unit.lower())
            if allowedUnit is None:
                # A count-style unit with no metric equivalent (Zehe, Bund,
                # Scheibe, Prise, ...) - the amount still becomes a plain
                # piece count below, but the noun is kept as text so it
                # isn't silently lost.
                descriptionUnitText = unit
        if amount is not None and allowedUnit is None:
            allowedUnit = PIECE

        description = " ".join(
            filter(
                None,
                [
                    qty if amount is None else None,
                    descriptionUnitText,
                    adjective,
                    *notes,
                ],
            )
        )

        return IngredientParsingResult(
            ingredient, name, description, amount=amount, unit=allowedUnit
        )

    return [parseGermanSingle(e) for e in ingredients]


def parseFallback(
    ingredients: list[str], targetLanguageCode: str | None = None
) -> list[IngredientParsingResult]:
    if targetLanguageCode and targetLanguageCode.startswith("de"):
        return parseGerman(ingredients)
    return parseNLP(ingredients)


def parseLLM(
    ingredients: list[str], targetLanguageCode: str | None = None
) -> list[IngredientParsingResult] | None:
    systemMessage = """
You are a tool that returns only JSON in the form of [{"name": name, "description": description}, ...]. Split every string from the list into these two properties. You receive recipe ingredients and fill the name field with the singular name of the ingredient and everything else is the description. Translate the response into the specified language.

For example in English:
Given: ["300g of Rice", "2 Chocolates"] you return only:
[{"name": "Rice", "description": "300g"}, {"name": "Chocolate", "description": "2"}]

Return only JSON and nothing else.
""" + (
        f"Translate the response to {SUPPORTED_LANGUAGES[targetLanguageCode]}. Translate the JSON content to {SUPPORTED_LANGUAGES[targetLanguageCode]}. Your target language is {SUPPORTED_LANGUAGES[targetLanguageCode]}. Respond in {SUPPORTED_LANGUAGES[targetLanguageCode]} from the start."
        if targetLanguageCode in SUPPORTED_LANGUAGES
        else ""
    )

    messages = [
        {
            "role": "system",
            "content": systemMessage,
        }
    ]

    userMessage: str = ""
    if targetLanguageCode in SUPPORTED_LANGUAGES:
        userMessage += f"Translate the response to {SUPPORTED_LANGUAGES[targetLanguageCode]}. Translate the JSON content to {SUPPORTED_LANGUAGES[targetLanguageCode]}. Your target language is {SUPPORTED_LANGUAGES[targetLanguageCode]}. Respond in {SUPPORTED_LANGUAGES[targetLanguageCode]} from the start."
        userMessage += "\n"

    userMessage += json.dumps(ingredients)
    messages.append(
        {
            "role": "user",
            "content": userMessage,
        }
    )

    response = completion(
        model=cast(str, LLM_MODEL),
        api_base=LLM_API_URL,
        # response_format={"type": "json_object"},
        messages=messages,
    )
    llmResponse = json.loads(response.choices[0].message.content)
    if len(llmResponse) != len(ingredients):
        return None
    parsedIngredients = []
    for i in range(len(llmResponse)):
        parsedIngredients.append(
            IngredientParsingResult(
                ingredients[i], llmResponse[i]["name"], llmResponse[i]["description"]
            )
        )

    return parsedIngredients


def parseIngredients(
    ingredients: list[str],
    targetLanguageCode=None,
) -> list[IngredientParsingResult]:
    if LLM_MODEL:
        try:
            return parseLLM(ingredients, targetLanguageCode) or parseFallback(
                ingredients, targetLanguageCode
            )
        except Exception as e:
            print("Error parsing ingredients:", e)
    return parseFallback(ingredients, targetLanguageCode)

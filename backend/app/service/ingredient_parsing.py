from typing import cast
import ingredient_parser
import ingredient_parser.dataclasses
from litellm import completion
import json
import os
import re

from app.config import SUPPORTED_LANGUAGES

LLM_MODEL = os.getenv("LLM_MODEL")
LLM_API_URL = os.getenv("LLM_API_URL")


class IngredientParsingResult:
    originalText: str | None = None
    name: str | None = None
    description: str | None = None

    def __init__(self, original_text, name, description):
        self.originalText = original_text
        self.name = name
        self.description = description

    def __str__(self):
        return f"{self.originalText} -> {self.name} ({self.description})"


def parseNLP(ingredients: list[str]) -> list[IngredientParsingResult]:
    def nlpAmountToDescription(
        amount: ingredient_parser.dataclasses.IngredientAmount
        | ingredient_parser.dataclasses.CompositeIngredientAmount,
    ) -> str:
        if isinstance(amount, ingredient_parser.dataclasses.CompositeIngredientAmount):
            return amount.text
        return f"{amount.quantity} {amount.unit}"

    def parseNLPSingle(ingredient: str) -> IngredientParsingResult:
        parsed = ingredient_parser.parse_ingredient(ingredient)
        if isinstance(parsed.name, list):
            name = parsed.name[0].text if parsed.name else None
        else:
            name = parsed.name.text
        description = (
            nlpAmountToDescription(parsed.amount[0]) if len(parsed.amount) > 0 else ""
        )
        # description = description + (" " if description else "") + (parsed.comment.text if parsed.comment else "") # Usually cooking instructions
        return IngredientParsingResult(ingredient, name, description)

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

        # Anything after the first comma is a preparation note (e.g. "gehackt"),
        # not part of the ingredient name.
        name = rest.split(",")[0].strip(" .-") or text_without_parens

        description = " ".join(filter(None, [qty, unit, *notes]))

        return IngredientParsingResult(ingredient, name, description)

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

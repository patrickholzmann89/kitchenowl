import json
import re
from typing import Any, BinaryIO, cast

from litellm import completion
from pypdf import PdfReader

from app.config import SUPPORTED_LANGUAGES
from app.models import Household, Item, Recipe
from app.service.ingredient_parsing import LLM_API_URL, LLM_MODEL, parseIngredients

# Kept well under typical context windows while still covering most
# printed/exported recipes.
_MAX_TEXT_CHARS = 12000


def extractPdfText(file_stream: BinaryIO) -> str | None:
    try:
        reader = PdfReader(file_stream)
    except Exception:
        return None

    if reader.is_encrypted:
        try:
            reader.decrypt("")
        except Exception:
            return None
        if reader.is_encrypted:
            return None

    try:
        text = "\n\n".join(page.extract_text() or "" for page in reader.pages)
    except Exception:
        return None

    text = text.strip()
    return text or None


def parseRecipeStructureLLM(
    text: str, targetLanguageCode: str | None = None
) -> dict[str, Any] | None:
    systemMessage = """
You are a tool that extracts a recipe from raw text extracted from a PDF and returns only JSON in the form of {"name": string, "yields": integer or null, "time": integer or null, "prep_time": integer or null, "cook_time": integer or null, "ingredients": [string, ...], "instructions": string}.

"time", "prep_time" and "cook_time" are in minutes. "ingredients" must contain one raw ingredient line per entry, unmodified from the source text - do not split out quantities or units. "instructions" is the full step-by-step preparation text, preserving the original step order.

If the text does not contain a recipe, or you cannot identify a title, return {"name": null}.

Return only JSON and nothing else.
""" + (
        f'Translate the response to {SUPPORTED_LANGUAGES[targetLanguageCode]}. Translate "name" and "instructions" into {SUPPORTED_LANGUAGES[targetLanguageCode]}. Do not translate the "ingredients" entries, they are parsed separately in their original language.'
        if targetLanguageCode in SUPPORTED_LANGUAGES
        else ""
    )

    messages = [
        {"role": "system", "content": systemMessage},
        {"role": "user", "content": text[:_MAX_TEXT_CHARS]},
    ]

    response = completion(
        model=cast(str, LLM_MODEL),
        api_base=LLM_API_URL,
        messages=messages,
    )
    result = json.loads(response.choices[0].message.content)
    if not isinstance(result, dict) or not result.get("name"):
        return None

    return {
        "name": str(result["name"])[:128],
        "ingredients": [str(i) for i in result.get("ingredients") or []],
        "instructions": str(result.get("instructions") or ""),
        "yields": result.get("yields"),
        "time": result.get("time"),
        "prep_time": result.get("prep_time"),
        "cook_time": result.get("cook_time"),
    }


# ingredient-parser-nlp/LLM extraction is preferred; this rule-based fallback
# only kicks in when no LLM is configured. It recognises English/German
# section headers and otherwise guesses the ingredient block from short,
# list-like lines - a weak signal that breaks on multi-column layouts,
# decorative headers, or any other language. Treat it as a safety net, not a
# real extraction.
_INGREDIENT_HEADERS = {"ingredients", "zutaten"}
_INSTRUCTION_HEADERS = {
    "instructions",
    "directions",
    "method",
    "steps",
    "preparation",
    "zubereitung",
    "anleitung",
}
# Headers that mark the start of a section following the instructions (e.g.
# in an LLM-generated recipe card) - used to stop the instructions block from
# swallowing everything up to the end of the pasted text.
_INSTRUCTION_END_HEADERS = {
    "anrichten",
    "servieren",
    "serving",
    "presentation",
    "nährwerte",
    "naehrwerte",
    "nutrition",
    "nutritionalvalues",
    "tipps",
    "tippsvarianten",
    "tips",
    "tipsvariations",
    "aufbewahrung",
    "storage",
}
_NUMBERED_MARKER_RE = re.compile(r"^\d+[.)]\s*")
# Accepts the count before or after the unit ("4 Portionen" or "Portionen: 4").
_YIELDS_RE = re.compile(
    r"(?:(?P<n1>\d+)\s*(?:servings?|portionen|personen))"
    r"|(?:(?:servings?|portionen|personen)\D{0,5}(?P<n2>\d+))",
    re.IGNORECASE,
)
# Matches "<Label>: 15 Minuten" style time fields, in minutes.
_TIME_FIELD_PATTERNS = {
    "prep_time": re.compile(r"vorbereitung(?:szeit)?\D{0,10}(\d+)\s*min", re.IGNORECASE),
    "cook_time": re.compile(r"(?:koch|gar)(?:zeit)?\D{0,10}(\d+)\s*min", re.IGNORECASE),
    "time": re.compile(r"gesamtzeit\D{0,10}(\d+)\s*min", re.IGNORECASE),
}


def _normalizeHeader(line: str) -> str:
    return re.sub(r"[^a-zäöüß]", "", line.lower())


def _findHeaderIndex(lines: list[str], keywords: set[str]) -> int | None:
    for i, line in enumerate(lines):
        header = _normalizeHeader(line)
        if header and len(header) <= 20 and header in keywords:
            return i
    return None


def _isMarkerLine(line: str) -> bool:
    # A numbered marker ("1.", "2)") or a single leading non-alphanumeric
    # character. The latter deliberately isn't restricted to a fixed set of
    # bullet characters ("-", "•", "*", ...): PDFs exported from word
    # processors often render list bullets through a custom symbol font,
    # which pypdf then extracts as an arbitrary (sometimes private-use-area)
    # codepoint instead of the plain "•" glyph.
    if not line:
        return False
    if _NUMBERED_MARKER_RE.match(line):
        return True
    return not line[0].isalnum()


def _stripMarker(line: str) -> str:
    match = _NUMBERED_MARKER_RE.match(line)
    if match:
        return line[match.end() :].strip()
    if line and not line[0].isalnum():
        return line[1:].strip()
    return line


def _cleanIngredientLines(lines: list[str]) -> list[str]:
    stripped = [line.strip() for line in lines if line.strip()]
    marked = [line for line in stripped if _isMarkerLine(line)]
    # Prefer marked (bulleted/numbered) lines when present - drops stray
    # sub-section headings (e.g. "Für den Hummus") that share the
    # ingredients block but aren't themselves list items.
    source = marked if marked else stripped
    return [_stripMarker(line) for line in source]


def _guessIngredientBlock(lines: list[str]) -> tuple[list[str], int | None]:
    ingredients: list[str] = []
    blockEnd = None
    for i, line in enumerate(lines):
        stripped = line.strip()
        if not stripped:
            if ingredients:
                blockEnd = i
                break
            continue
        if _isMarkerLine(stripped) or len(stripped) <= 60:
            ingredients.append(_stripMarker(stripped))
            blockEnd = i + 1
        elif ingredients:
            blockEnd = i
            break
    return ingredients, blockEnd


def parseRecipeStructureFallback(
    text: str, targetLanguageCode: str | None = None
) -> dict[str, Any]:
    lines = text.splitlines()
    nonEmpty = [line.strip() for line in lines if line.strip()]
    name = nonEmpty[0][:128] if nonEmpty else None

    ingredientsIdx = _findHeaderIndex(lines, _INGREDIENT_HEADERS)
    instructionsIdx = _findHeaderIndex(lines, _INSTRUCTION_HEADERS)

    if ingredientsIdx is not None:
        end = (
            instructionsIdx
            if instructionsIdx is not None and instructionsIdx > ingredientsIdx
            else len(lines)
        )
        ingredients = _cleanIngredientLines(lines[ingredientsIdx + 1 : end])
    else:
        # Skip past the title line itself - it's almost always short enough
        # to otherwise be mistaken for the first "ingredient".
        titleIdx = next((i for i, l in enumerate(lines) if l.strip()), None)
        searchStart = titleIdx + 1 if titleIdx is not None else 0
        ingredients, guessedEnd = _guessIngredientBlock(lines[searchStart:])
        if instructionsIdx is None:
            instructionsIdx = (
                searchStart + guessedEnd if guessedEnd is not None else None
            )

    instructions = ""
    if instructionsIdx is not None:
        body = lines[instructionsIdx + 1 :]
        endIdx = _findHeaderIndex(body, _INSTRUCTION_END_HEADERS)
        if endIdx is not None:
            body = body[:endIdx]
        instructions = "\n".join(line.strip() for line in body if line.strip())

    yieldsMatch = _YIELDS_RE.search(text)

    def timeMinutes(field: str) -> int | None:
        match = _TIME_FIELD_PATTERNS[field].search(text)
        return int(match.group(1)) if match else None

    return {
        "name": name,
        "ingredients": ingredients,
        "instructions": instructions,
        "yields": (
            int(yieldsMatch.group("n1") or yieldsMatch.group("n2"))
            if yieldsMatch
            else None
        ),
        "time": timeMinutes("time"),
        "prep_time": timeMinutes("prep_time"),
        "cook_time": timeMinutes("cook_time"),
    }


def _asInt(value: Any) -> int | None:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def extractRecipeFromText(text: str, household: Household) -> dict[str, Any] | None:
    structure = None
    if LLM_MODEL:
        try:
            structure = parseRecipeStructureLLM(text, household.language)
        except Exception as e:
            print("Error extracting recipe from PDF via LLM:", e)
    if not structure:
        structure = parseRecipeStructureFallback(text, household.language)

    if not structure.get("name") and not structure.get("ingredients") and not structure.get(
        "instructions"
    ):
        return None

    recipe = Recipe()
    recipe.name = (structure.get("name") or "Recipe")[:128]
    recipe.description = structure.get("instructions") or ""
    for field in ("yields", "time", "prep_time", "cook_time"):
        value = _asInt(structure.get(field))
        if value is not None:
            setattr(recipe, field, value)

    items = {}
    for ingredient in parseIngredients(
        structure.get("ingredients") or [], household.language
    ):
        name = ingredient.name if ingredient.name else ingredient.originalText or ""
        item = Item.find_name_starts_with(household.id, name)
        if item:
            items[ingredient.originalText] = item.obj_to_dict() | {
                "description": ingredient.description,
                "optional": False,
            }
        else:
            items[ingredient.originalText] = None

    return {
        "recipe": recipe.obj_to_dict(),
        "items": items,
    }

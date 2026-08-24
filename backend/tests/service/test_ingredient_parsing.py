import pytest
from app.service.ingredient_parsing import parseGerman


@pytest.mark.parametrize(
    "ingredient,name,description",
    [
        ("300g Reis", "Reis", "300 g"),
        ("300 g Reis", "Reis", "300 g"),
        ("2 Zwiebeln, gewürfelt", "Zwiebeln", "2"),
        ("1 TL Salz", "Salz", "1 TL"),
        ("3 EL Olivenöl", "Olivenöl", "3 EL"),
        ("1 Bund Petersilie, gehackt", "Petersilie", "1 Bund"),
        ("200 ml Sahne", "Sahne", "200 ml"),
        ("Salz und Pfeffer nach Geschmack", "Salz und Pfeffer nach Geschmack", ""),
        ("2 Eier", "Eier", "2"),
        ("1 Packung (500g) Nudeln", "Nudeln", "1 Packung 500g"),
        ("eine Zwiebel", "Zwiebel", "1"),
        ("1/2 Zitrone", "Zitrone", "1/2"),
        ("½ Zitrone", "Zitrone", "½"),
        ("1 Dose Tomaten (400g)", "Tomaten", "1 Dose 400g"),
        ("2-3 Karotten", "Karotten", "2-3"),
        ("1 Prise Zucker", "Zucker", "1 Prise"),
        ("1 Msp. Muskat", "Muskat", "1 Msp"),
        ("4 Scheiben Schinken", "Schinken", "4 Scheiben"),
        ("2 Zehen Knoblauch", "Knoblauch", "2 Zehen"),
        ("1 kg Kartoffeln", "Kartoffeln", "1 kg"),
        # Ingredient names that happen to start like a number word or a unit
        # abbreviation must not be mangled.
        ("Gurke", "Gurke", ""),
        ("Gouda", "Gouda", ""),
        ("Lauch", "Lauch", ""),
        ("Limetten", "Limetten", ""),
        ("Linsen", "Linsen", ""),
        ("Eintopf-Gemüse", "Eintopf-Gemüse", ""),
        ("Einlegegurken", "Einlegegurken", ""),
        ("Glas Nutella", "Nutella", "Glas"),
        # A descriptive adjective/participle between quantity+unit and the
        # noun must be moved into the description, not left in the name -
        # otherwise it breaks matching against an existing pantry item.
        ("500 g kleine Kartoffeln", "Kartoffeln", "500 g kleine"),
        ("3-5 EL eiskaltes Wasser", "Wasser", "3-5 EL eiskaltes"),
        ("1-2 EL gehackte Petersilie", "Petersilie", "1-2 EL gehackte"),
        ("1 kleine Knoblauchzehe", "Knoblauchzehe", "1 kleine"),
    ],
)
def testParseGerman(ingredient, name, description):
    [result] = parseGerman([ingredient])
    assert result.name == name
    assert result.description == description


def testParseGermanPreservesOriginalText():
    [result] = parseGerman(["300g Reis"])
    assert result.originalText == "300g Reis"


def testParseGermanMultipleIngredients():
    results = parseGerman(["300g Reis", "2 Eier"])
    assert [r.name for r in results] == ["Reis", "Eier"]

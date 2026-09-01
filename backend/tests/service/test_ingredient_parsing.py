import pytest

from app.service.ingredient_parsing import parseGerman, parseNLP


@pytest.mark.parametrize(
    "ingredient,name,description,amount,unit",
    [
        ("300g Reis", "Reis", "", 300.0, "g"),
        ("300 g Reis", "Reis", "", 300.0, "g"),
        ("2 Zwiebeln, gewürfelt", "Zwiebeln", "", 2.0, "piece"),
        ("1 TL Salz", "Salz", "", 1.0, "tsp"),
        ("3 EL Olivenöl", "Olivenöl", "", 3.0, "tbsp"),
        ("1 Bund Petersilie, gehackt", "Petersilie", "Bund", 1.0, "piece"),
        ("200 ml Sahne", "Sahne", "", 200.0, "ml"),
        ("Salz und Pfeffer nach Geschmack", "Salz und Pfeffer nach Geschmack", "", None, None),
        ("2 Eier", "Eier", "", 2.0, "piece"),
        ("1 Packung (500g) Nudeln", "Nudeln", "Packung 500g", 1.0, "piece"),
        ("eine Zwiebel", "Zwiebel", "", 1.0, "piece"),
        ("1/2 Zitrone", "Zitrone", "", 0.5, "piece"),
        ("½ Zitrone", "Zitrone", "", 0.5, "piece"),
        ("1 Dose Tomaten (400g)", "Tomaten", "Dose 400g", 1.0, "piece"),
        ("2-3 Karotten", "Karotten", "", 2.5, "piece"),
        ("1 Prise Zucker", "Zucker", "Prise", 1.0, "piece"),
        ("1 Msp. Muskat", "Muskat", "Msp", 1.0, "piece"),
        ("4 Scheiben Schinken", "Schinken", "Scheiben", 4.0, "piece"),
        ("2 Zehen Knoblauch", "Knoblauch", "Zehen", 2.0, "piece"),
        ("1 kg Kartoffeln", "Kartoffeln", "", 1.0, "kg"),
        # Ingredient names that happen to start like a number word or a unit
        # abbreviation must not be mangled.
        ("Gurke", "Gurke", "", None, None),
        ("Gouda", "Gouda", "", None, None),
        ("Lauch", "Lauch", "", None, None),
        ("Limetten", "Limetten", "", None, None),
        ("Linsen", "Linsen", "", None, None),
        ("Eintopf-Gemüse", "Eintopf-Gemüse", "", None, None),
        ("Einlegegurken", "Einlegegurken", "", None, None),
        # A unit word with no leading quantity at all isn't assumed to mean
        # "1" - it stays purely descriptive.
        ("Glas Nutella", "Nutella", "Glas", None, None),
        # A descriptive adjective/participle between quantity+unit and the
        # noun must be moved into the description, not left in the name -
        # otherwise it breaks matching against an existing pantry item.
        ("500 g kleine Kartoffeln", "Kartoffeln", "kleine", 500.0, "g"),
        ("3-5 EL eiskaltes Wasser", "Wasser", "eiskaltes", 4.0, "tbsp"),
        ("1-2 EL gehackte Petersilie", "Petersilie", "gehackte", 1.5, "tbsp"),
        ("1 kleine Knoblauchzehe", "Knoblauchzehe", "kleine", 1.0, "piece"),
        # An adjective/participle can also sit *between* the quantity and
        # the unit (not just after it), e.g. a baking recipe's "level
        # teaspoon".
        ("1 gestrichener TL Backpulver", "Backpulver", "gestrichener", 1.0, "tsp"),
        ("2 gehäufte EL Mehl", "Mehl", "gehäufte", 2.0, "tbsp"),
    ],
)
def testParseGerman(ingredient, name, description, amount, unit):
    [result] = parseGerman([ingredient])
    assert result.name == name
    assert result.description == description
    assert result.amount == amount
    assert result.unit == unit


def testParseGermanPreservesOriginalText():
    [result] = parseGerman(["300g Reis"])
    assert result.originalText == "300g Reis"


def testParseGermanMultipleIngredients():
    results = parseGerman(["300g Reis", "2 Eier"])
    assert [r.name for r in results] == ["Reis", "Eier"]


@pytest.mark.parametrize(
    "ingredient,name,description,amount,unit",
    [
        ("300g rice", "rice", "", 300.0, "g"),
        # A recognised pint unit with no mass/volume mapping of its own
        # (a cup) is converted via real unit conversion, not string matching.
        ("2 cups flour, sifted", "flour", "", 473.2, "ml"),
        # A count-style unit with no metric equivalent - piece count, noun
        # kept in the description so it isn't silently lost.
        ("1 clove garlic, minced", "garlic", "clove", 1.0, "piece"),
        ("2-3 onions", "onions", "", 2.5, "piece"),
        ("250 ml milk", "milk", "", 250.0, "ml"),
        ("2 large eggs", "eggs", "", 2.0, "piece"),
    ],
)
def testParseNLP(ingredient, name, description, amount, unit):
    [result] = parseNLP([ingredient])
    assert result.name == name
    assert result.description == description
    assert result.amount == amount
    assert result.unit == unit

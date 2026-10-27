#!/bin/bash
# Creates ~/testrepo (or the path you pass): a tiny Python project with 3 planted bugs.
set -e
R=${1:-$HOME/testrepo}
rm -rf "$R"; mkdir -p "$R/shop" "$R/tests"; cd "$R"
cat > shop/__init__.py <<'P'
P
cat > shop/pricing.py <<'P'
def parse_price(text):
    """'1,299.50' -> 1299.5 ; '$45' -> 45.0"""
    cleaned = text.replace("$", "").strip()
    return float(cleaned.replace(".", ""))


def apply_discount(price, percent):
    """apply_discount(200, 10) -> 180.0"""
    return round(price - percent, 2)
P
cat > shop/ranking.py <<'P'
def top_n(products, n):
    """Return the n most expensive products, highest price first."""
    ranked = sorted(products, key=lambda p: p["price"])
    return ranked[:n]
P
cat > tests/test_shop.py <<'P'
from shop.pricing import parse_price, apply_discount
from shop.ranking import top_n

def test_parse_simple():
    assert parse_price("$45") == 45.0

def test_parse_thousands():
    assert parse_price("1,299.50") == 1299.5

def test_discount():
    assert apply_discount(200, 10) == 180.0

def test_discount_zero():
    assert apply_discount(99.99, 0) == 99.99

def test_top_n():
    items = [{"name": "a", "price": 5}, {"name": "b", "price": 50}, {"name": "c", "price": 20}]
    assert [p["name"] for p in top_n(items, 2)] == ["b", "c"]

def test_top_n_all():
    items = [{"name": "a", "price": 1}, {"name": "b", "price": 2}]
    assert [p["name"] for p in top_n(items, 5)] == ["b", "a"]
P
git init -q && git add -A && git -c user.email=lab@x -c user.name=lab commit -qm "buggy baseline"
echo "Test repo ready at $R"

#!/bin/bash
# Task 2 (medium): implement a new Cart feature from a spec. Hidden tests grade it.
set -e
R=${1:-$HOME/testrepo2}; H=${2:-$HOME/.grader}   # project dir, hidden grader dir (kept OUTSIDE the project)
rm -rf "$R" "$H"; mkdir -p "$R/shop" "$R/tests" "$H"; cd "$R"
touch shop/__init__.py
cat > shop/pricing.py <<'P'
def parse_price(text):
    """'1,299.50' -> 1299.5 ; '$45' -> 45.0"""
    cleaned = text.replace("$", "").replace(",", "").strip()
    return float(cleaned)


def apply_discount(price, percent):
    """apply_discount(200, 10) -> 180.0"""
    return round(price * (1 - percent / 100), 2)
P
cat > SPEC.md <<'P'
# Feature: shopping cart (shop/cart.py)

Create `shop/cart.py` with a class `Cart`. Reuse `parse_price` and `apply_discount` from `shop/pricing.py`.

1. `Cart.add(name, price, qty=1)`: `price` is a string like "$1,299.50" (use parse_price).
   `qty` must be a positive int, otherwise raise `ValueError`.
   Adding a name that is already in the cart increases its quantity (keep the first price).
2. `Cart.remove(name, qty=None)`: remove `qty` units; `None` removes the item completely.
   If the quantity drops to 0 or below, the item is removed. Unknown name raises `KeyError`.
3. `Cart.subtotal()`: sum of price * qty, rounded to 2 decimals. Empty cart -> 0.0.
4. `Cart.apply_coupon(code)`: supported codes:
   - "SAVE10": 10% off the subtotal
   - "FLAT5": $5 off, only if subtotal >= 50, otherwise raise `ValueError`
   Unknown code raises `KeyError`. Only one coupon at a time: a new coupon replaces the old one.
5. `Cart.total(tax_rate=0.0)`: subtotal, minus coupon, then plus tax (tax_rate 0.08 = 8%),
   rounded to 2 decimals. Never negative.
6. `Cart.items()`: list of (name, unit_price, qty) tuples, sorted by name.

Also write your own tests in `tests/test_cart.py` and make sure `python -m pytest -q` passes.
P
cat > tests/test_pricing.py <<'P'
from shop.pricing import parse_price, apply_discount
def test_parse(): assert parse_price("1,299.50") == 1299.5
def test_discount(): assert apply_discount(200, 10) == 180.0
P
cat > "$H/test_hidden.py" <<'P'
import pytest
from shop.cart import Cart

def c(): return Cart()

def test_add_and_subtotal():
    k = c(); k.add("pen", "$2.50", 4); k.add("book", "$1,000.00")
    assert k.subtotal() == 1010.0

def test_add_merges_qty_keeps_first_price():
    k = c(); k.add("pen", "$2", 1); k.add("pen", "$9", 2)
    assert k.items() == [("pen", 2.0, 3)]

@pytest.mark.parametrize("q", [0, -1, 1.5, "2"])
def test_bad_qty(q):
    with pytest.raises(ValueError): c().add("x", "$1", q)

def test_remove_partial_and_full():
    k = c(); k.add("a", "$1", 3); k.remove("a", 1)
    assert k.items() == [("a", 1.0, 2)]
    k.remove("a", 5); assert k.items() == []

def test_remove_all_default():
    k = c(); k.add("a", "$1", 3); k.remove("a"); assert k.items() == []

def test_remove_unknown():
    with pytest.raises(KeyError): c().remove("nope")

def test_empty_subtotal():
    assert c().subtotal() == 0.0

def test_save10():
    k = c(); k.add("a", "$100"); k.apply_coupon("SAVE10"); assert k.total() == 90.0

def test_flat5_ok_and_min():
    k = c(); k.add("a", "$50"); k.apply_coupon("FLAT5"); assert k.total() == 45.0
    k2 = c(); k2.add("a", "$49.99")
    with pytest.raises(ValueError): k2.apply_coupon("FLAT5")

def test_unknown_coupon():
    k = c(); k.add("a", "$10")
    with pytest.raises(KeyError): k.apply_coupon("FREE")

def test_coupon_replaces():
    k = c(); k.add("a", "$100"); k.apply_coupon("SAVE10"); k.apply_coupon("FLAT5")
    assert k.total() == 95.0

def test_tax_after_coupon():
    k = c(); k.add("a", "$100"); k.apply_coupon("SAVE10")
    assert k.total(tax_rate=0.08) == 97.2

def test_rounding():
    k = c(); k.add("a", "$0.10", 3); assert k.subtotal() == 0.3

def test_items_sorted():
    k = c(); k.add("b", "$1"); k.add("a", "$2")
    assert [i[0] for i in k.items()] == ["a", "b"]

def test_own_tests_exist():
    import os; assert os.path.exists("tests/test_cart.py")
P
git init -q && printf "__pycache__/\n.pytest_cache/\n" > .gitignore && git add -A && git -c user.email=lab@x -c user.name=lab commit -qm "task2 baseline"
echo "Task 2 ready: $R  (hidden grader: $H)"

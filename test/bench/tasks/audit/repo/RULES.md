# Checkout rules

All amounts are in dollars and handled as exact decimals.

1. **Bulk lines.** A line with 10 or more units of the same SKU gets 5% off
   that line.
2. **Coupons.** Coupon codes are case-insensitive and ignore surrounding
   spaces. `SAVE10` takes $10 off the subtotal; the subtotal never goes
   below zero. Unknown codes are ignored.
3. **Loyalty.** Loyalty members get 10% off the subtotal, after bulk and
   coupon discounts and before tax.
4. **Tax.** Tax is 8% of the discounted subtotal. Shipping is not taxed.
5. **Shipping.** Orders whose discounted subtotal is over $200 ship free;
   otherwise shipping is $15. An order of exactly $200 pays shipping.
6. **Rounding.** Round once, at the very end, to the cent, with halves
   rounded up (away from zero).

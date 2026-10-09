# Numbers

- **Know your numeric types.** Assert integer-ness where integers are meant, use a wide integer type where 64-bit range matters, and never rely on implicit coercion.
- **`index`, `count`, and `size` are conceptually distinct types.** index + 1 = count; count × unit = size — name variables so the casts between them are visible.
- **Show division intent**: an explicit floor, ceiling, or truncation whenever a division can be fractional, to show rounding was thought through.

def clamp(value, min_value, max_value):
    """Return value constrained to the inclusive [min_value, max_value] range.

    Raises ValueError when min_value is greater than max_value.
    """
    if min_value > max_value:
        raise ValueError("min_value must be less than or equal to max_value")
    if value < min_value:
        return min_value
    if value > max_value:
        return max_value
    return value

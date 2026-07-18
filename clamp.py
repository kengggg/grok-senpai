def clamp(value, min, max):
    if min > max:
        raise ValueError("min must be less than or equal to max")
    if value < min:
        return min
    if value > max:
        return max
    return value

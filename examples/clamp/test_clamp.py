import unittest

from clamp import clamp


class ClampTests(unittest.TestCase):
    def test_below_min_returns_min(self):
        self.assertEqual(clamp(1, 2, 5), 2)

    def test_above_max_returns_max(self):
        self.assertEqual(clamp(6, 2, 5), 5)

    def test_within_range_returns_value(self):
        self.assertEqual(clamp(3, 2, 5), 3)

    def test_equal_to_min_returns_value(self):
        self.assertEqual(clamp(2, 2, 5), 2)

    def test_equal_to_max_returns_value(self):
        self.assertEqual(clamp(5, 2, 5), 5)

    def test_min_greater_than_max_raises_value_error(self):
        with self.assertRaises(ValueError):
            clamp(3, 5, 2)

    def test_equal_bounds_returns_bound(self):
        self.assertEqual(clamp(3, 4, 4), 4)  # value above collapsed bound
        self.assertEqual(clamp(0, 4, 4), 4)  # value below collapsed bound
        self.assertEqual(clamp(4, 4, 4), 4)  # value equal to collapsed bound

    def test_negative_numbers(self):
        self.assertEqual(clamp(-6, -5, -2), -5)
        self.assertEqual(clamp(-1, -5, -2), -2)
        self.assertEqual(clamp(-3, -5, -2), -3)

    def test_floats(self):
        self.assertEqual(clamp(1.25, 1.5, 2.5), 1.5)
        self.assertEqual(clamp(2.75, 1.5, 2.5), 2.5)
        self.assertEqual(clamp(2.25, 1.5, 2.5), 2.25)

    def test_keyword_arguments(self):
        self.assertEqual(clamp(3, min_value=2, max_value=5), 3)
        self.assertEqual(clamp(1, min_value=2, max_value=5), 2)
        self.assertEqual(clamp(9, min_value=2, max_value=5), 5)


if __name__ == "__main__":
    unittest.main()

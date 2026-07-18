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


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Run Buyer accessibility journeys against a local web app with synthetic API data."""
import sys

from browser_smoke import main


if __name__ == '__main__':
    main(['--synthetic-accessibility', *sys.argv[1:]])

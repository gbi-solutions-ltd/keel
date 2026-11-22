// auth-mfa: these keys go into data/fixtures.js's window.FIXTURES (the module's README says how).
  "auth": {
    "security": {
      "mfa_required": true,
      "methods_available": [
        "totp",
        "email",
        "sms"
      ],
      "factors": [
        {
          "method": "totp",
          "enabled": true,
          "added_at": "2026-08-14T07:30:00Z"
        },
        {
          "method": "email",
          "enabled": true,
          "destination": "a•••@example.com",
          "added_at": "2026-08-14T07:20:00Z"
        },
        {
          "method": "sms",
          "enabled": false
        }
      ],
      "recovery_codes_remaining": 8,
      "password_changed_at": "2026-08-14T07:10:00Z",
      "password_min_length": 12
    },
    "challenge": {
      "id": "ch_demo",
      "methods": [
        "totp",
        "email",
        "recovery_code"
      ],
      "email_destination": "a•••@example.com"
    },
    "totp_enrolment": {
      "id": "enr_demo",
      "secret": "JBSWY3DPEHPK3PXP",
      "otpauth_uri": "otpauth://totp/Service:amina%40example.com?secret=JBSWY3DPEHPK3PXP&issuer=Service",
      "qr_image": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAMAAAADACAYAAABS3GwHAAAAAklEQVR4AewaftIAAAkmSURBVO3BQYojyA5F0ZuBtyDQRPtfmCaCt4j8OTSiwEG0/Su7Q+d8ff9gjEstxrjYYoyLLca42GKMiz34A/Pgt1Aln2QedKpkh3mwQ5XsMA86VbLDPDihSjrzoFMlnXnQqZLOPPgtVMmzxRgXW4xxscUYF1uMcbEHm1TJp5kH72QedKrkFfOgUyXvZB50qmSHeXBKlbyiSjrzoFMlp1TJp5kHryzGuNhijIstxrjYYoyLPfgHzINTquSUedCpkk6VnFAln6ZKOvOgUyWnVElnHjxTJb+FeXBKlZxYjHGxxRgXW4xxscUYF3vwH2EedKrkXcyDTpXsMA86VdKpkh2qpDMPOvPgFfNghyrpzINOlfybLMa42GKMiy3GuNhijIs9+I9QJTvMg2eqZIcq6cyDHaqkMw9OqZJOlXTmQadKnpkHnSrpzIP/osUYF1uMcbHFGBdbjHGxB/+AKvm3Mw9OqZId5sEOVbLDPOhUSadKXlElv4Uq+X9bjHGxxRgXW4xxscUYF3uwyTz4tzEPOlXyzDzoVElnHuwwDzpV0pkHO8yDTpV05kGnSjrz4Jkq6cyDTpV05sEp8+A3WIxxscUYF1uMcbHFGBd78Aeq5BaqpDMPdpgHnSrpzINTquSTzINOlbyTKvmtFmNcbDHGxRZjXGwxxsW+vn/QmAedKunMg09TJTvMg06VvGIedKpkh3nwaarkk8yDHarklHnwaarkxGKMiy3GuNhijIstxrjYgzdTJe9kHuxQJZ158Ioq6cyDU6qkMw86VdKZB6fMgxOqpDMPPk2VdOZBp0p2mAedKnllMcbFFmNcbDHGxRZjXOzBH6iSv8E82KFKOvNghyp5RZXsMA8686BTJe9kHnSqpDMPTqiSzjw4pUp2qJJ3Mg86VfJsMcbFFmNcbDHGxRZjXOzr+weNedCpkr/BPDilSjrz4IQq6cyDTpW8k3lwSpWcMA92qJLOPOhUyd9gHnSq5NlijIstxrjYYoyLPfgDVdKZBztUySnzoFMl76RKTpgHp8yDTpV05sEOVdKZBzvMg09SJZ150KmSzjz4f1uMcbHFGBdbjHGxxRgX+/r+QWMedKqkMw9OqZJT5kGnSjrzoFMlr5gHO1RJZx7sUCWdebBDlewwDzpV8op50KmSv8E86FTJuyzGuNhijIstxrjYYoyLPXgzVbLDPNihSjpVskOVvGIedKpkh3mwQ5V05kGnSjrz4JQq6cyDV1RJZx50qmSHedCpks48OGUe7FAlzxZjXGwxxsUWY1xsMcbFHvwiquSdzINOlTxTJadUSWcedOZBp0o+zTx4RZW8k3nQqZJTquSUKnllMcbFFmNcbDHGxRZjXOzBP6BKOvOgUyU7zINOlXTmwQ5V0pkH76JKOlXSmQededCpkk9TJc/Mg06V7DAPdpgHnSrZYR7sUCWdedCpkmeLMS62GONiizEuthjjYl/fP2jMg06V/BbmQadKOvPghCrpzINTqmSHedCpkh3mwbuokt/CPOhUSWcedKrklcUYF1uMcbHFGBdbjHGxr+8fHDIPOlXSmQedKunMg06VfJJ50KmSTzMPdqiSHeZBp0rexTw4pUo686BTJTvMg1Oq5NlijIstxrjYYoyLLca42INN5sEO86BTJTtUyTuZB50q+STzoFMlO1TJDvOgUyWdefCKKunMg7/BPOhUSadKOvOgUyWvLMa42GKMiy3GuNhijIs9+APzoFMlnXmwwzzoVElnHnSqpDMPOlWywzz4JFXSmQedKjmlSjrzoFMlv4F58E7mwbssxrjYYoyLLca42GKMi319/+CNzINOlZwyDzpVssM86FTJM/NghyrZYR50qqQzD95JlXTmwQlVssM82KFKTpkHnSrpzINOlbyyGONiizEuthjjYosxLvb1/YPGPDilSjrz4JQq6cyD/zdV0pkHO1TJv5150KmSHeZBp0reyTzYoUqeLca42GKMiy3GuNhijIs9+EtUyTupkncxDzrzoFMlO8yDTpV8mnnwiio5ZR50qqRTJTvMg06VnFIlryzGuNhijIstxrjYYoyLPfgDVdKZB50q6cyDHebBKVXSmQfvoko686AzD3aoks486FRJZx50quSUKnlmHnSq5NPMg1PmwbssxrjYYoyLLca42Nf3DxrzoFMlp8yDTpX8DebBK6pkh3nQqZLOPDilSjrzYIcq6cyDZ6rklHnQqZJ3Mg86VfIuizEuthjjYosxLrYY42IP/gHzoFMlnSrpzINTqqQzDzpV0qmSZ+ZBZx6cMg86VfJpqqQzDzpV8op50KmSHebBDlVyyjw4pUqeLca42GKMiy3GuNhijIs9+D8wD3aoks48+H9TJTvMg06V7DAPOlVyyjx4F1VySpV05kFnHnSqpFMln7QY42KLMS62GONiizEu9vX9g8Y86FTJp5kH76RKOvPgk1RJZx50qqQzD3aoklPmwX+RKunMg06VPFuMcbHFGBdbjHGxxRgX+/r+wb+MebBDlbxiHpxSJZ150KmSzjzYoUpOmQedKnlmHnSqZId50KmSU+ZBp0p2mAedKnllMcbFFmNcbDHGxRZjXOzBH5gHv4Uq6VTJKfPgmSrZYR505kGnSk6pkh3mQadKOlVywjzoVMkp86BTJe+kSjrzoFMlzxZjXGwxxsUWY1xsMcbFHmxSJZ9mHuwwD3aokhPmwQ5V0pkHnSo5ZR7sMA9OqJLOPHgnVfJp5sGJxRgXW4xxscUYF1uMcbEH/4B5cEqVvJMqeRdVckqVvJMq6cyDTpXsMA+emQedKunMgx3mwaeZBztUySuLMS62GONiizEuthjjYg/+I8yDTpV8knmwQ5XsMA86VbLDPOhUySuqpDMPOlXSmQenVElnHuxQJZ15cGIxxsUWY1xsMcbFFmNc7MF/hCo5YR7sUCWdKjmlSjrz4N9OlewwDzpVckqVdOZBp0qeLca42GKMiy3GuNhijIs9+AdUyd+gSk6pkmfmQadKTpkHnSo5ZR6cMg8+SZXsMA86VfIbLMa42GKMiy3GuNhijIt9ff+gMQ9+C1XSmQc7VElnHpxQJafMg3dSJe9iHvwWqmSHeXBKlTxbjHGxxRgXW4xxscUYF/v6/sEYl1qMcbHFGBdbjHGx/wGJj9kdkt61lAAAAABJRU5ErkJggg==" // supply-chain-scan: allow a sample QR code (PNG) of the otpauth URI above, for the authenticator set-up screen
    },
    "recovery_codes": [
      "7KQ2-M9XD",
      "P4HT-2WNC",
      "R8JB-6YVA",
      "X3LE-Q7KS",
      "N5FG-8ZTU",
      "B2WD-4HMR",
      "K9CP-3XEJ",
      "T6VN-5QLB",
      "H4ZS-9GAD",
      "E7MY-2RPW"
    ],
    "password_policy": {
      "min_length": 12
    }
  },

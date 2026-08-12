# Report 6 — Screenshot Capture Guide

Use this guide to replace the framed `[CHÈN ẢNH HÌNH ...]` spaces in Report 6. Keep each figure caption and number unchanged. Capture at the app's native phone resolution or the full browser viewport; do not crop away the navigation/context that proves the feature.

Before capture: use test accounts only; hide passwords, access tokens, QR invite codes, e-mail/phone values, real addresses, and precise private locations. For every capture, make sure the app is fully loaded and no system keyboard or emulator toolbar covers the relevant control.

| Figure | Where to capture | Required evidence |
|---|---|---|
| 6.1 | Docker Desktop / environment setup | PostgreSQL and Redis services running; all secrets masked. |
| 6.2 | Terminal in `D:\Desktop\sep` | `pnpm dev:api` startup output without secrets. |
| 6.3 | Web browser | Web Admin sign-in or dashboard after successful load. |
| 6.4 | Android emulator | FamilyCare app open after `flutter run`. |
| 6.5 | Mobile Family / members | Family name and member management interface. |
| 6.6 | Mobile home | Bottom navigation and home content. |
| 6.7 | Mobile authentication | Actual sign-in or registration page. |
| 6.8 | Mobile invite/join | Create/join-family or member invite interface. |
| 6.9 | Mobile finance / AI | Income or expense proposal/form before confirm. |
| 6.10 | Mobile financial model | Jar model and expense-category mapping list. |
| 6.11 | Mobile AI Assistant | Pending monthly fund allocation card with month/year/amount. |
| 6.12 | Mobile model + journal | Allocation history/result and monthly finance summary. |
| 6.13 | Mobile tasks / AI | Task proposal or form with recipient name and due date. |
| 6.14 | Mobile AI Assistant | Pending calendar proposal with time and location. |
| 6.15 | Mobile calendar | Newly created event shown in calendar/list or success notification. |
| 6.16 | Mobile messages | Anonymized family conversation and message composer. |
| 6.17 | Mobile SOS | Test-mode SOS confirmation only; blur exact coordinates. |
| 6.18 | Mobile map/location | Test family-location screen; blur private places. |
| 6.19 | Mobile album | Upload action and family gallery with non-sensitive test image. |
| 6.20 | Mobile AI Assistant | Multi-turn proposal with Edit, Cancel and Confirm controls. |
| 6.21 | Mobile profile/settings | Profile/settings overview, personal data obscured. |
| 6.22 | Web Admin `/admin` | Dashboard. |
| 6.23 | Web Admin `/admin/users` | User management list/search. |
| 6.24 | Web Admin `/admin/families` | Family management list/detail. |
| 6.25 | Web Admin `/admin/plans` | Subscription plans. |
| 6.26 | Web Admin `/admin/revenue` | Revenue/payment reporting. |
| 6.27 | Web Admin `/admin/invitations` | Invitations. |
| 6.28 | Web Admin `/admin/audit-logs` | Audit-log list/filter. |
| 6.29 | Web Admin `/admin/provisioning-logs` and `/admin/backups` | Capture either one or make a two-panel composite. |
| 6.30 | Web Admin `/admin/system` | System settings; obscure keys and endpoints. |

## Insert procedure

1. Open `Report6_Software User Guides (1).docx` in Word.
2. Click the corresponding framed placeholder, then replace only the placeholder text with the screenshot. Keep the frame width within page margins.
3. Use **In Line with Text** layout, centered. Set a consistent width (about 14–15 cm for a portrait mobile capture; use two images side by side only where the caption requests two screens).
4. Keep the existing `Figure 6.x` caption directly below the image. Do not renumber figures.
5. When all images are placed, press `Ctrl+A`, then `F9` and choose **Update entire table** to refresh the Table of Contents and page numbers.

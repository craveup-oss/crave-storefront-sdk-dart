# Dart S1 food and released-menu source adoption

Canonical contracts inspected from core S1 normal merge
`679f2c89e5802c41cb8dfb4b7cdeeed1150027bc`, especially
`packages/commerce-contracts/src/domain/catalog-food.ts` and `storefront.ts`.
This branch preserves readiness PR #7 (`b375a1c0602df36f5c009693bb64e6eb21f2e894`)
and rename PR #9 (`13b5999e22ce7348619c7752c47c7454d74a3339`). Their source is
joined without altering their original branches. The metadata conflict retains
PR #7's public documentation URL and PR #9's canonical repository URLs.

## Source scope

- Mandatory released menu/channel/release and timing on product reads, and
  channel on menu reads; no global product-ID fallback.
- Source and serving/tray unit on menus, products, recommendations and new cart
  lines. Preview checks returned source/quantity against requested context.
- Anonymous configuration preview and capability/revision/idempotency-backed
  dietary preference mutation through existing request owners.
- Immutable server evaluation, contribution/provenance evidence, null unknown
  nutrients, tray yield/totals, structured warnings and missing-fact evidence.
- Cart food summary and configured/unavailable line food; draft sources cannot
  enter public cart results. No client food calculation engine.
- Current example and Flutter consumer source adopt new context, and the manifest
  explicitly declares a bounded subset of 53 operations / 52 JSON methods. It
  does not claim all 79 S1 operations or complete event-bound catering support.

## Local verification

Dart 3.10.4 / Flutter 3.38.5:

- `tool/verify.sh`: clean fatal analyzer, 176 tests, dartdoc zero warnings/errors,
  dependency status, secret scan, Flutter analyzer and one consumer test pass.
- `tool/verify_web.sh`: JavaScript example compile and 41 Chrome tests pass.
- Eight new regression cases cover same-product/two-menu context, server tray and
  unknown values, preference capability/revision persistence, add-item context,
  configured/unavailable cart evidence, distinct draft identity and mismatched
  preview source/quantity denial. Baseline readiness/rename source had 168 tests.
- Package dry-run archive inspection is separate from publication. The first
  precommit dry run completed with a dirty-source warning; final clean-tree
  evidence must be recorded on the reviewed candidate.

These are SDK transport/model tests using controlled HTTP fixtures, not deployed
API persistence or configured customer/device acceptance. Canonical core carries
its own evaluator/actual PostgreSQL HTTP evidence; that does not establish this
Dart consumer's deployed end-to-end acceptance.

## Remaining release and integration gates

Independent source review and required hosted checks remain required. PR #7 and
#9 plus this adoption must be reconciled on main before an exact reviewed release
tag can satisfy `tool/verify_release.sh`. The currently installed documented pana
fallback is 0.23.12; package score must be evaluated separately because live main
still exposes the old repository metadata until rename adoption is promoted.
No pub.dev publication, main merge, deployment, real Flutter/browser/device
journey or complete external C3 acceptance is claimed by this source handoff.

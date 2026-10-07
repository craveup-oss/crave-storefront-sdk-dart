# Changelog

All notable changes to this package are documented here. This project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased S1 adoption

- Require released menu/channel/release context and browsing timing on product reads;
  carry source and quantity unit through menus, products, recommendations and add-item requests.
- Add anonymous configured-food preview and capability/revision-backed cart dietary preferences.
- Decode server nutrient, tray yield, contributions, source identity, warning, missing-fact and
  cart-summary evidence. Unknown values remain null; no client food evaluator is introduced.
- Extend the bounded Dart manifest to 53 reviewed operations / 52 typed JSON methods. This is a
  subset of current S1 APIs, not complete catering API adoption or pub.dev release proof.

## 0.2.0

- Add anonymous `locations.getOrderingReadiness()` with sealed `OrderingReady` and
  `OrderingUnavailable` response models.
- Limit ordering-readiness requests to the four accepted `FulfillmentMethod` values: takeout,
  table-side, room-service, and delivery. The previously published robot-delivery and
  in-course-delivery enum cases remain as deprecated source-compatible values.
- Synchronize the reviewed operation manifest with all 51 Storefront routes and current operation
  identifiers; 50 JSON operations are exposed through typed SDK methods and the navigation-only
  redirect remains intentionally excluded.
- Document production, sandbox, and local environment isolation plus the equivalent TypeScript SDK.
- Update the pub.dev README, examples, dependency toolchain, and package metadata for this release.

## 0.1.0

- Add the typed `CraveStorefrontClient` and Storefront resource clients.
- Add customer identity, cart capability, checkout handoff, receipt, revision, and idempotency
  lifecycle handling.
- Add caller-owned asynchronous session storage and an in-memory test implementation.
- Serialize complete same-cart lifecycles so delayed responses cannot reverse session cleanup.
- Add typed, redaction-safe configuration, network, timeout, cancellation, decoding, session, and
  server failures, including recoverable idempotency keys for ambiguous mutation outcomes.
- Add Dart and Flutter consumer verification plus release-ready pub.dev metadata.

This is the first public preview. There are no migration steps from an earlier Dart release.

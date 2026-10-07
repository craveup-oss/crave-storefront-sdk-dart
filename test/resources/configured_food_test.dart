import 'dart:convert';
import 'dart:io';
import 'package:crave_storefront_sdk/crave_storefront_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('product reads distinguish the same product in two menu releases',
      () async {
    final requests = <http.Request>[];
    final client = CraveStorefrontClient(
        baseUri: Uri.parse('https://api.example.test'),
        merchantSlug: 'example',
        httpClient: MockClient((r) async {
          requests.add(r);
          final json =
              jsonDecode(File('test/fixtures/product.json').readAsStringSync())
                  as Map<String, Object?>;
          json['source'] = {
            'kind': 'released',
            'locationId': 'location_01',
            ...r.url.queryParameters
          }..remove('menuOnly');
          json['quantityUnit'] = 'serving';
          return http.Response(jsonEncode(json), 200);
        }));
    for (final menu in ['main', 'lunch']) {
      final product = await client.products.getForLocation(
          'location_01', 'product_01',
          context: ReleasedMenuContext(
              menuId: menu,
              menuReleaseId: 'release-$menu',
              channel: MenuChannel.online),
          menuOnly: true);
      expect(product.source.menuId, menu);
      expect(product.source.menuReleaseId, 'release-$menu');
    }
    expect(requests[0].url.queryParameters, {
      'menuId': 'main',
      'menuReleaseId': 'release-main',
      'channel': 'online',
      'menuOnly': 'true'
    });
    expect(requests[1].url.queryParameters['menuId'], 'lunch');
    client.close();
  });
  test('food preview is anonymous and preserves server tray/unknown totals',
      () async {
    late http.Request captured;
    var tokenCalls = 0;
    final client = CraveStorefrontClient(
        baseUri: Uri.parse('https://api.example.test'),
        merchantSlug: 'example',
        customerTokenProvider: () async {
          tokenCalls++;
          return 'customer-token';
        },
        httpClient: MockClient((r) async {
          captured = r;
          return http.Response(jsonEncode(foodFixture()), 200);
        }));
    final food = await client.products.previewConfiguration(
        'location_01',
        'product_01',
        ConfigurationPreviewRequest(
            context: ReleasedMenuContext(
                menuId: 'main',
                menuReleaseId: 'release-main',
                channel: MenuChannel.catering),
            quantity: 2,
            quantityUnit: QuantityUnit.tray,
            selections: [],
            preferences: DietaryPreferenceContext(
                preferences: [DietaryPreference.vegan],
                avoidAllergenIds: [AllergenId.milk])));
    expect(captured.url.path,
        '/api/v1/storefront/locations/location_01/products/product_01/configuration-preview');
    expect(captured.method, 'POST');
    expect(captured.headers, isNot(contains('authorization')));
    expect(jsonDecode(captured.body), containsPair('quantityUnit', 'tray'));
    expect(tokenCalls, 0);
    expect(food.perServing.caloriesKcal, 400);
    expect(food.perServing.proteinGrams, null);
    expect(food.perTray!.caloriesKcal, 3200);
    expect(food.lineTotal.caloriesKcal, 6400);
    expect(food.trayYield!.servingsPerTray, 8);
    expect(food.warnings.single.code, FoodWarningCode.allergenPresent);
    expect(food.missing.single.nutrient, Nutrient.proteinGrams);
    expect(food.warnings.clear, throwsUnsupportedError);
    client.close();
  });
  test('guest dietary mutation keeps capability, revision and retry authority',
      () async {
    final store = InMemoryStorefrontSessionStore();
    final scope = StorefrontSessionScope(
        apiOrigin: Uri.parse('https://api.example.test'),
        merchantSlug: 'example',
        locationId: 'location_01');
    await store.write(StorefrontCartSession(
        scope: scope,
        cartId: 'cart_01',
        accessToken: 'capability',
        revision: 3));
    final client = CraveStorefrontClient(
        baseUri: Uri.parse('https://api.example.test'),
        merchantSlug: 'example',
        sessionStore: store,
        httpClient: MockClient((r) async {
          expect(r.method, 'PUT');
          expect(r.url.path,
              '/api/v1/storefront/locations/location_01/carts/cart_01/dietary-preferences');
          expect(r.headers['x-cart-token'], 'capability');
          expect(r.headers['if-match'], '"cart-3"');
          expect(r.headers['idempotency-key'], 'clear-preferences-001');
          expect(jsonDecode(r.body),
              {'preferences': <String>[], 'avoidAllergenIds': <String>[]});
          final json =
              jsonDecode(File('test/fixtures/cart.json').readAsStringSync())
                  as Map<String, Object?>;
          json['revision'] = 4;
          return http.Response(jsonEncode(json), 200,
              headers: {'etag': '"cart-4"'});
        }));
    final cart = await client.carts.updateDietaryPreferences(
        'location_01',
        'cart_01',
        DietaryPreferenceContext(
            preferences: <DietaryPreference>[],
            avoidAllergenIds: <AllergenId>[]),
        options: StorefrontRequestOptions(
            revision: 3, idempotencyKey: 'clear-preferences-001'));
    expect(cart.revision, 4);
    expect((await store.read(scope))?.revision, 4);
    expect(cart.dietaryPreferences.preferences, isEmpty);
    client.close();
  });
  test('add-item payload retains exact release and quantity unit', () {
    final request = AddCartItemRequest(
        productId: 'product_01',
        context: ReleasedMenuContext(
            menuId: 'lunch',
            menuReleaseId: 'release-lunch',
            channel: MenuChannel.catering),
        quantity: 2,
        quantityUnit: QuantityUnit.tray,
        itemUnavailableAction: ItemUnavailableAction.removeItem,
        selections: []);
    expect(request.toJson(), {
      'menuId': 'lunch',
      'menuReleaseId': 'release-lunch',
      'channel': 'catering',
      'quantityUnit': 'tray',
      'productId': 'product_01',
      'quantity': 2,
      'itemUnavailableAction': 'remove_item',
      'selections': <Object?>[]
    });
  });
  test('cart decodes server food and explicit unavailable historical evidence',
      () {
    final json = jsonDecode(File('test/fixtures/cart.json').readAsStringSync())
        as Map<String, Object?>;
    final line =
        (json['items'] as List<Object?>).first! as Map<String, Object?>;
    final original = StorefrontCart.fromJson(json);
    expect(original.items.single.food, isA<UnavailableCartLineFood>());
    line['quantity'] = 2;
    line['food'] = {'state': 'configured', 'result': foodFixture()};
    final cart = StorefrontCart.fromJson(json);
    expect(
        (cart.items.single.food as ConfiguredCartLineFood)
            .result
            .lineTotal
            .caloriesKcal,
        6400);
    line['quantity'] = 1;
    expect(() => StorefrontCart.fromJson(json), throwsFormatException);
  });
  test('draft identity stays draft and cannot enter public cart food', () {
    final json = foodFixture();
    json['source'] = {
      'kind': 'draft',
      'locationId': 'location_01',
      'menuId': 'main',
      'channel': 'catering',
      'draftRevision': 5
    };
    expect(
        ConfiguredFoodEvaluation.fromJson(json).source, isA<DraftFoodSource>());
    expect(
        () => CartLineFoodEvidence.fromJson(
            {'state': 'configured', 'result': json}),
        throwsFormatException);
  });
  test('public preview rejects another menu release or quantity result',
      () async {
    for (final field in ['menuReleaseId', 'quantity']) {
      final json = foodFixture();
      if (field == 'quantity') {
        json['quantity'] = {'unit': 'tray', 'count': 1};
      } else {
        (json['source'] as Map<String, Object?>)[field] = 'release-other';
      }
      final client = CraveStorefrontClient(
          baseUri: Uri.parse('https://api.example.test'),
          merchantSlug: 'example',
          httpClient:
              MockClient((r) async => http.Response(jsonEncode(json), 200)));
      await expectLater(
          client.products.previewConfiguration(
              'location_01',
              'product_01',
              ConfigurationPreviewRequest(
                  context: ReleasedMenuContext(
                      menuId: 'main',
                      menuReleaseId: 'release-main',
                      channel: MenuChannel.catering),
                  quantity: 2,
                  quantityUnit: QuantityUnit.tray,
                  selections: [],
                  preferences: DietaryPreferenceContext(
                      preferences: [], avoidAllergenIds: []))),
          throwsA(isA<StorefrontDecodingException>()));
      client.close();
    }
  });
  test('decoder rejects fabricated unknown, tray and source evidence', () {
    for (final mutate in <void Function(Map<String, Object?>)>[
      (j) => j['perTray'] = null,
      (j) => (j['lineTotal'] as Map<String, Object?>)['proteinGrams'] = 0,
      (j) => j['completeness'] = 'complete',
      (j) => (j['source'] as Map<String, Object?>)['kind'] = 'bogus',
    ]) {
      final json = foodFixture();
      mutate(json);
      expect(
          () => ConfiguredFoodEvaluation.fromJson(json), throwsFormatException);
    }
  });
}

Map<String, Object?> nutrients(num kcal) => {
      'caloriesKcal': kcal,
      'proteinGrams': null,
      'carbohydrateGrams': 0,
      'fatGrams': 0,
      'fiberGrams': 0,
      'sugarGrams': 0,
      'saturatedFatGrams': 0,
      'sodiumMilligrams': 0
    };
Map<String, Object?> foodFixture() => {
      'source': {
        'kind': 'released',
        'locationId': 'location_01',
        'menuId': 'main',
        'channel': 'catering',
        'menuReleaseId': 'release-main'
      },
      'contributions': [],
      'serving': {'label': 'bowl', 'grams': null},
      'quantity': {'unit': 'tray', 'count': 2},
      'trayYield': {'servingsPerTray': 8},
      'perServing': nutrients(400),
      'perTray': nutrients(3200),
      'lineTotal': nutrients(6400),
      'completeness': 'partial',
      'missing': [
        {'entityId': 'product_01', 'nutrient': 'proteinGrams'}
      ],
      'warnings': [
        {
          'code': 'ALLERGEN_PRESENT',
          'entityId': 'cheese',
          'preferenceId': 'milk',
          'selectionPath': ['group', 'cheese']
        }
      ]
    };

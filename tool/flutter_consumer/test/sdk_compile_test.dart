import 'package:crave_storefront_sdk/crave_storefront_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('constructs the SDK from a Flutter consumer', () {
    final client = CraveStorefrontClient(
      baseUri: Uri.parse('https://api.example.com'),
      merchantSlug: 'example-merchant',
    );

    expect(client.products.previewConfiguration, isA<Function>());
    expect(client.carts.updateDietaryPreferences, isA<Function>());
    final request = ConfigurationPreviewRequest(
        context: ReleasedMenuContext(
            menuId: 'menu',
            menuReleaseId: 'release',
            channel: MenuChannel.online),
        quantity: 1,
        quantityUnit: QuantityUnit.serving,
        selections: [],
        preferences: DietaryPreferenceContext(
            preferences: [DietaryPreference.vegan], avoidAllergenIds: []));
    expect(request.toJson()['channel'], 'online');
    expect(client.baseUri, Uri.parse('https://api.example.com'));
    expect(client.merchantSlug, 'example-merchant');
    client.close();
  });
}

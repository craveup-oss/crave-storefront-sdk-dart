import '../json/json_reader.dart';
import 'catalog.dart' show SelectedModifierGroup;

/// Publication channel, distinct from the ordering app channel.
enum MenuChannel {
  /// Wire value `online`.
  online('online'),

  /// Wire value `catering`.
  catering('catering'),
  ;

  const MenuChannel(this.wireValue);

  /// Value sent to the API.
  final String wireValue;
}

/// Unit whose yield is evaluated by the server.
enum QuantityUnit {
  /// Wire value `serving`.
  serving('serving'),

  /// Wire value `tray`.
  tray('tray'),
  ;

  const QuantityUnit(this.wireValue);

  /// Value sent to the API.
  final String wireValue;
}

/// Supported customer dietary preferences.
enum DietaryPreference {
  /// Wire value `vegetarian`.
  vegetarian('vegetarian'),

  /// Wire value `vegan`.
  vegan('vegan'),
  ;

  const DietaryPreference(this.wireValue);

  /// Value sent to the API.
  final String wireValue;
}

/// Canonical allergen identifiers.
enum AllergenId {
  /// Wire value `milk`.
  milk('milk'),

  /// Wire value `egg`.
  egg('egg'),

  /// Wire value `fish`.
  fish('fish'),

  /// Wire value `crustaceanShellfish`.
  crustaceanShellfish('crustacean_shellfish'),

  /// Wire value `treeNuts`.
  treeNuts('tree_nuts'),

  /// Wire value `peanut`.
  peanut('peanut'),

  /// Wire value `wheat`.
  wheat('wheat'),

  /// Wire value `soy`.
  soy('soy'),

  /// Wire value `sesame`.
  sesame('sesame'),

  /// Wire value `celery`.
  celery('celery'),

  /// Wire value `mustard`.
  mustard('mustard'),

  /// Wire value `lupin`.
  lupin('lupin'),

  /// Wire value `molluscs`.
  molluscs('molluscs'),

  /// Wire value `sulphites`.
  sulphites('sulphites'),
  ;

  const AllergenId(this.wireValue);

  /// Value sent to the API.
  final String wireValue;
}

/// Explicit nutrient names and units.
enum Nutrient {
  /// Wire value `caloriesKcal`.
  caloriesKcal('caloriesKcal'),

  /// Wire value `proteinGrams`.
  proteinGrams('proteinGrams'),

  /// Wire value `carbohydrateGrams`.
  carbohydrateGrams('carbohydrateGrams'),

  /// Wire value `fatGrams`.
  fatGrams('fatGrams'),

  /// Wire value `fiberGrams`.
  fiberGrams('fiberGrams'),

  /// Wire value `sugarGrams`.
  sugarGrams('sugarGrams'),

  /// Wire value `saturatedFatGrams`.
  saturatedFatGrams('saturatedFatGrams'),

  /// Wire value `sodiumMilligrams`.
  sodiumMilligrams('sodiumMilligrams'),
  ;

  const Nutrient(this.wireValue);

  /// Value sent to the API.
  final String wireValue;
}

/// Known nutrient completeness; unknown is never zero.
enum FoodCompleteness {
  /// Wire value `complete`.
  complete('complete'),

  /// Wire value `partial`.
  partial('partial'),

  /// Wire value `unknown`.
  unknown('unknown'),
  ;

  const FoodCompleteness(this.wireValue);

  /// Value sent to the API.
  final String wireValue;
}

/// Server dietary and allergen advice.
enum FoodWarningCode {
  /// Wire value `DIETARY_CONFLICT`.
  dietaryConflict('DIETARY_CONFLICT'),

  /// Wire value `ALLERGEN_PRESENT`.
  allergenPresent('ALLERGEN_PRESENT'),

  /// Wire value `ALLERGEN_POSSIBLE`.
  allergenPossible('ALLERGEN_POSSIBLE'),

  /// Wire value `DIETARY_INFORMATION_UNKNOWN`.
  dietaryInformationUnknown('DIETARY_INFORMATION_UNKNOWN'),
  ;

  const FoodWarningCode(this.wireValue);

  /// Value sent to the API.
  final String wireValue;
}

T _wire<T>(Iterable<T> values, String value, String Function(T) wire) {
  for (final entry in values) {
    if (wire(entry) == value) return entry;
  }
  throw const FormatException('Unsupported configured food wire value.');
}

void _nonempty(String value) {
  if (value.trim().isEmpty) {
    throw ArgumentError('A menu/release identifier is required.');
  }
}

/// Context required for every product read, preview and new cart line.
final class ReleasedMenuContext {
  /// Creates context from a server-returned released menu source.
  ReleasedMenuContext(
      {required this.menuId,
      required this.menuReleaseId,
      required this.channel}) {
    _nonempty(menuId);
    _nonempty(menuReleaseId);
  }

  /// Canonical menu identifier.
  final String menuId;

  /// Immutable menu release identifier.
  final String menuReleaseId;

  /// Selected publication channel.
  final MenuChannel channel;

  /// Only the accepted request context fields.
  Map<String, Object?> toJson() => {
        'menuId': menuId,
        'menuReleaseId': menuReleaseId,
        'channel': channel.wireValue
      };
}

/// Server source identity. Draft revisions never masquerade as releases.
sealed class ConfiguredFoodSource {
  const ConfiguredFoodSource._(this.menuId, this.locationId, this.channel);

  /// Decodes the draft/released source union.
  factory ConfiguredFoodSource.fromJson(Map<String, Object?> json) {
    final r = JsonReader.fromObject(json, context: 'food.source');
    final kind = r.string('kind');
    final menuId = r.string('menuId');
    final locationId = r.string('locationId');
    final channel =
        _wire(MenuChannel.values, r.string('channel'), (v) => v.wireValue);
    if (menuId.isEmpty || locationId.isEmpty) {
      throw const FormatException('Missing menu source identity.');
    }
    if (kind == 'released') {
      final releaseId = r.string('menuReleaseId');
      if (releaseId.isEmpty || r.contains('draftRevision')) {
        throw const FormatException('Invalid release identity.');
      }
      return ReleasedFoodSource(
          menuId: menuId,
          locationId: locationId,
          channel: channel,
          menuReleaseId: releaseId);
    }
    if (kind == 'draft') {
      final revision = r.integer('draftRevision');
      if (revision < 1 || r.contains('menuReleaseId')) {
        throw const FormatException('Invalid draft identity.');
      }
      return DraftFoodSource(
          menuId: menuId,
          locationId: locationId,
          channel: channel,
          draftRevision: revision);
    }
    throw const FormatException('Unknown food source kind.');
  }

  /// Canonical menu identifier.
  final String menuId;

  /// Location whose effective data was evaluated.
  final String locationId;

  /// Effective publication channel.
  final MenuChannel channel;
}

/// Immutable released menu identity returned by public operations.
final class ReleasedFoodSource extends ConfiguredFoodSource {
  /// Creates a released identity.
  const ReleasedFoodSource(
      {required String menuId,
      required String locationId,
      required MenuChannel channel,
      required this.menuReleaseId})
      : super._(menuId, locationId, channel);

  /// Requires released evidence, rejecting draft data on public reads.
  factory ReleasedFoodSource.fromJson(Map<String, Object?> json) {
    final source = ConfiguredFoodSource.fromJson(json);
    if (source is! ReleasedFoodSource) {
      throw const FormatException('Public food requires a released source.');
    }
    return source;
  }

  /// Immutable release identifier.
  final String menuReleaseId;

  /// Context to pass to product/cart operations without global ID lookup.
  ReleasedMenuContext get context => ReleasedMenuContext(
      menuId: menuId, menuReleaseId: menuReleaseId, channel: channel);
}

/// Draft identity, useful for interpreting server evidence without fake releases.
final class DraftFoodSource extends ConfiguredFoodSource {
  /// Creates a draft identity.
  const DraftFoodSource(
      {required String menuId,
      required String locationId,
      required MenuChannel channel,
      required this.draftRevision})
      : super._(menuId, locationId, channel);

  /// Evaluated draft revision.
  final int draftRevision;
}

/// Preference payload persisted by the server on a cart.
final class DietaryPreferenceContext {
  /// Copies and validates supported preference lists.
  DietaryPreferenceContext(
      {required Iterable<DietaryPreference> preferences,
      required Iterable<AllergenId> avoidAllergenIds})
      : preferences = List.unmodifiable(preferences),
        avoidAllergenIds = List.unmodifiable(avoidAllergenIds) {
    if (this.preferences.toSet().length != this.preferences.length ||
        this.avoidAllergenIds.toSet().length != this.avoidAllergenIds.length) {
      throw ArgumentError('Preferences must be unique.');
    }
  }

  /// Decodes preferences without treating missing information as empty.
  factory DietaryPreferenceContext.fromJson(Map<String, Object?> json) {
    final r = JsonReader.fromObject(json, context: 'preferences');
    return DietaryPreferenceContext(
        preferences: r
            .stringList('preferences')
            .map((v) => _wire(DietaryPreference.values, v, (v) => v.wireValue)),
        avoidAllergenIds: r
            .stringList('avoidAllergenIds')
            .map((v) => _wire(AllergenId.values, v, (v) => v.wireValue)));
  }

  /// Dietary choices.
  final List<DietaryPreference> preferences;

  /// Allergen choices, separate from dietary suitability.
  final List<AllergenId> avoidAllergenIds;

  /// Empty lists explicitly clear stored preferences.
  Map<String, Object?> toJson() => {
        'preferences':
            preferences.map((v) => v.wireValue).toList(growable: false),
        'avoidAllergenIds':
            avoidAllergenIds.map((v) => v.wireValue).toList(growable: false)
      };
}

/// Server calculated nutrient values; null means unknown.
final class NutrientValues {
  /// Creates nutrient values without performing client calculations.
  const NutrientValues(
      {required this.caloriesKcal,
      required this.proteinGrams,
      required this.carbohydrateGrams,
      required this.fatGrams,
      required this.fiberGrams,
      required this.sugarGrams,
      required this.saturatedFatGrams,
      required this.sodiumMilligrams});

  /// Decodes eight explicit finite, nonnegative or null nutrient values.
  factory NutrientValues.fromJson(Map<String, Object?> json) {
    final r = JsonReader.fromObject(json, context: 'nutrients');
    double? read(String key) {
      if (!r.contains(key)) {
        throw const FormatException('Missing nutrient field.');
      }
      final value = r.nullableNumber(key);
      if (value != null && value < 0) {
        throw const FormatException('Negative nutrient.');
      }
      return value;
    }

    return NutrientValues(
        caloriesKcal: read('caloriesKcal'),
        proteinGrams: read('proteinGrams'),
        carbohydrateGrams: read('carbohydrateGrams'),
        fatGrams: read('fatGrams'),
        fiberGrams: read('fiberGrams'),
        sugarGrams: read('sugarGrams'),
        saturatedFatGrams: read('saturatedFatGrams'),
        sodiumMilligrams: read('sodiumMilligrams'));
  }

  /// `caloriesKcal` value, or unknown.
  final double? caloriesKcal;

  /// `proteinGrams` value, or unknown.
  final double? proteinGrams;

  /// `carbohydrateGrams` value, or unknown.
  final double? carbohydrateGrams;

  /// `fatGrams` value, or unknown.
  final double? fatGrams;

  /// `fiberGrams` value, or unknown.
  final double? fiberGrams;

  /// `sugarGrams` value, or unknown.
  final double? sugarGrams;

  /// `saturatedFatGrams` value, or unknown.
  final double? saturatedFatGrams;

  /// `sodiumMilligrams` value, or unknown.
  final double? sodiumMilligrams;

  /// Returns a nutrient without filling unknowns with zero.
  double? operator [](Nutrient nutrient) => switch (nutrient) {
        Nutrient.caloriesKcal => caloriesKcal,
        Nutrient.proteinGrams => proteinGrams,
        Nutrient.carbohydrateGrams => carbohydrateGrams,
        Nutrient.fatGrams => fatGrams,
        Nutrient.fiberGrams => fiberGrams,
        Nutrient.sugarGrams => sugarGrams,
        Nutrient.saturatedFatGrams => saturatedFatGrams,
        Nutrient.sodiumMilligrams => sodiumMilligrams
      };
}

/// Portion label reported by the server.
final class FoodServing {
  /// Creates a serving label.
  const FoodServing({required this.label, required this.grams});

  /// Decodes a serving label.
  factory FoodServing.fromJson(Map<String, Object?> json) {
    final r = JsonReader.fromObject(json, context: 'serving');
    return FoodServing(
        label: r.string('label'), grams: r.nullableNumber('grams'));
  }

  /// Customer-facing portion label.
  final String label;

  /// Portion weight, if known.
  final double? grams;
}

/// Server-reported catering yield, never inferred by the client.
final class TrayYield {
  /// Creates a catering yield.
  const TrayYield({required this.servingsPerTray});

  /// Servings contained in each tray.
  final double servingsPerTray;
}

/// Evidence identifying a nutrient with unavailable facts.
final class MissingNutrient {
  /// Copies missing evidence.
  const MissingNutrient(
      {required this.entityId, required this.nutrient, this.cartItemId});

  /// Decodes missing evidence.
  factory MissingNutrient.fromJson(Map<String, Object?> json) {
    final r = JsonReader.fromObject(json, context: 'food.missing');
    return MissingNutrient(
        entityId: r.string('entityId'),
        nutrient:
            _wire(Nutrient.values, r.string('nutrient'), (v) => v.wireValue),
        cartItemId: r.nullableString('cartItemId'));
  }

  /// Item/component whose fact is missing.
  final String entityId;

  /// Nutrient that must remain unknown.
  final Nutrient nutrient;

  /// Cart line, when included in a cart summary.
  final String? cartItemId;
}

/// Structured server advice; it does not remove selections or alter prices.
final class FoodWarning {
  /// Copies warning evidence.
  FoodWarning(
      {required this.code,
      required this.entityId,
      required this.preferenceId,
      required Iterable<String> selectionPath,
      this.cartItemId})
      : selectionPath = List.unmodifiable(selectionPath);

  /// Decodes dietary/allergen evidence.
  factory FoodWarning.fromJson(Map<String, Object?> json) {
    final r = JsonReader.fromObject(json, context: 'food.warning');
    final preference = r.string('preferenceId');
    if (!{
      ...DietaryPreference.values.map((v) => v.wireValue),
      ...AllergenId.values.map((v) => v.wireValue)
    }.contains(preference)) {
      throw const FormatException('Unsupported warning preference.');
    }
    return FoodWarning(
        code:
            _wire(FoodWarningCode.values, r.string('code'), (v) => v.wireValue),
        entityId: r.string('entityId'),
        preferenceId: preference,
        selectionPath: r.stringList('selectionPath'),
        cartItemId: r.nullableString('cartItemId'));
  }

  /// Advice code.
  final FoodWarningCode code;

  /// Item/option that caused the advice.
  final String entityId;

  /// Canonical dietary preference or allergen identifier.
  final String preferenceId;

  /// Canonical nested modifier path.
  final List<String> selectionPath;

  /// Cart line, when included in a cart summary.
  final String? cartItemId;
}

/// Contribution evidence supplied by the server, not a client recipe engine.
final class FoodContribution {
  FoodContribution._(this.entityId, this.selectionPath, this.numerator,
      this.denominator, this.provenance, this.nutrients);

  /// Decodes a contribution and freezes its provenance evidence.
  factory FoodContribution.fromJson(Map<String, Object?> json) {
    final r = JsonReader.fromObject(json, context: 'food.contribution');
    final f = r.object('fraction');
    final numerator = f.number('numerator');
    final denominator = f.number('denominator');
    if (numerator < 0 || denominator <= 0) {
      throw const FormatException('Invalid contribution fraction.');
    }
    return FoodContribution._(
        r.string('entityId'),
        r.stringList('selectionPath'),
        numerator,
        denominator,
        r.nullableMap('provenance'),
        NutrientValues.fromJson(r.object('nutrients').asMap()));
  }

  /// Canonical component identifier.
  final String entityId;

  /// Nested canonical selection path.
  final List<String> selectionPath;

  /// Effective fraction numerator.
  final double numerator;

  /// Effective fraction denominator.
  final double denominator;

  /// Immutable entered/provider/recipe provenance evidence.
  final Map<String, Object?>? provenance;

  /// Raw component facts, without client multiplication.
  final NutrientValues nutrients;
}

/// Complete server evaluation, with explicit source and quantity authority.
final class ConfiguredFoodEvaluation {
  ConfiguredFoodEvaluation._(
      {required this.source,
      required this.serving,
      required this.quantityUnit,
      required this.quantity,
      required this.trayYield,
      required this.perServing,
      required this.perTray,
      required this.lineTotal,
      required this.completeness,
      required this.contributions,
      required this.missing,
      required this.warnings});

  /// Decodes and checks evidence shape without recalculating totals.
  factory ConfiguredFoodEvaluation.fromJson(Map<String, Object?> json) {
    final r = JsonReader.fromObject(json, context: 'food');
    final q = r.object('quantity');
    final count = q.integer('count');
    if (count < 1 || count > 999) {
      throw const FormatException('Invalid evaluation quantity.');
    }
    final unit =
        _wire(QuantityUnit.values, q.string('unit'), (v) => v.wireValue);
    final tray = r.nullableObject('trayYield');
    final servings = tray?.number('servingsPerTray');
    final pt = r.nullableObject('perTray');
    if ((unit == QuantityUnit.tray) != (tray != null && pt != null) ||
        (unit == QuantityUnit.serving && (tray != null || pt != null)) ||
        (servings != null && servings <= 0)) {
      throw const FormatException('Invalid tray evidence.');
    }
    final ps = NutrientValues.fromJson(r.object('perServing').asMap());
    final perTray = pt == null ? null : NutrientValues.fromJson(pt.asMap());
    final total = NutrientValues.fromJson(r.object('lineTotal').asMap());
    final completeness = _wire(
        FoodCompleteness.values, r.string('completeness'), (v) => v.wireValue);
    final missing = r
        .objectList('missing')
        .map((v) => MissingNutrient.fromJson(v.asMap()))
        .toList(growable: false);
    _validateEvidence(ps, completeness, missing);
    for (final n in Nutrient.values) {
      if (ps[n] == null && (total[n] != null || perTray?[n] != null)) {
        throw const FormatException('Unknown nutrient became a known total.');
      }
    }
    return ConfiguredFoodEvaluation._(
        source: ConfiguredFoodSource.fromJson(r.object('source').asMap()),
        serving: FoodServing.fromJson(r.object('serving').asMap()),
        quantityUnit: unit,
        quantity: count,
        trayYield:
            servings == null ? null : TrayYield(servingsPerTray: servings),
        perServing: ps,
        perTray: perTray,
        lineTotal: total,
        completeness: completeness,
        contributions: List.unmodifiable(r
            .objectList('contributions')
            .map((v) => FoodContribution.fromJson(v.asMap()))),
        missing: List.unmodifiable(missing),
        warnings: List.unmodifiable(r
            .objectList('warnings')
            .map((v) => FoodWarning.fromJson(v.asMap()))));
  }

  /// Released or draft input identity.
  final ConfiguredFoodSource source;

  /// Server portion label.
  final FoodServing serving;

  /// Server accepted quantity unit.
  final QuantityUnit quantityUnit;

  /// Number of units.
  final int quantity;

  /// Catering yield; null for serving quantities.
  final TrayYield? trayYield;

  /// Nutrients per serving.
  final NutrientValues perServing;

  /// Nutrients per tray, null for servings.
  final NutrientValues? perTray;

  /// Nutrients for the entire line.
  final NutrientValues lineTotal;

  /// Completeness of the facts.
  final FoodCompleteness completeness;

  /// Component contributions.
  final List<FoodContribution> contributions;

  /// Missing fact evidence.
  final List<MissingNutrient> missing;

  /// Dietary and allergen warnings.
  final List<FoodWarning> warnings;
}

void _validateEvidence(NutrientValues values, FoodCompleteness completeness,
    List<MissingNutrient> missing) {
  final known = Nutrient.values.where((v) => values[v] != null).length;
  final expected = known == 0
      ? FoodCompleteness.unknown
      : known == 8
          ? FoodCompleteness.complete
          : FoodCompleteness.partial;
  if (completeness != expected ||
      missing.any((v) => values[v.nutrient] != null)) {
    throw const FormatException('Inconsistent nutrient evidence.');
  }
}

/// Server food summary across cart lines.
final class CartFoodSummary {
  CartFoodSummary._(this.unavailableLineIds, this.totals, this.completeness,
      this.missing, this.warnings);

  /// Decodes the authoritative summary without aggregating on the client.
  factory CartFoodSummary.fromJson(Map<String, Object?> json) {
    final r = JsonReader.fromObject(json, context: 'foodSummary');
    final ids = r.stringList('unavailableLineIds');
    final totals = NutrientValues.fromJson(r.object('totals').asMap());
    final completeness = _wire(
        FoodCompleteness.values, r.string('completeness'), (v) => v.wireValue);
    final missing = List<MissingNutrient>.unmodifiable(r
        .objectList('missing')
        .map((v) => MissingNutrient.fromJson(v.asMap())));
    _validateEvidence(totals, completeness, missing);
    if (ids.isNotEmpty && Nutrient.values.any((v) => totals[v] != null)) {
      throw const FormatException(
          'Unavailable cart lines require unknown totals.');
    }
    return CartFoodSummary._(
        ids,
        totals,
        completeness,
        missing,
        List.unmodifiable(r
            .objectList('warnings')
            .map((v) => FoodWarning.fromJson(v.asMap()))));
  }

  /// Cart lines whose food cannot be evaluated.
  final List<String> unavailableLineIds;

  /// Server cart totals.
  final NutrientValues totals;

  /// Total completeness.
  final FoodCompleteness completeness;

  /// Missing facts, with cart line identifiers.
  final List<MissingNutrient> missing;

  /// Cart warnings, with cart line identifiers.
  final List<FoodWarning> warnings;
}

/// Cart line evaluation or explicit unavailable evidence.
sealed class CartLineFoodEvidence {
  const CartLineFoodEvidence._();

  /// Decodes configured or unavailable food; neither defaults to zero.
  factory CartLineFoodEvidence.fromJson(Map<String, Object?> json) {
    final r = JsonReader.fromObject(json, context: 'line.food');
    final state = r.string('state');
    if (state == 'configured') {
      final result =
          ConfiguredFoodEvaluation.fromJson(r.object('result').asMap());
      if (result.source is! ReleasedFoodSource) {
        throw const FormatException('Cart food must use released source.');
      }
      return ConfiguredCartLineFood(result);
    }
    if (state == 'unavailable') {
      final reason = r.string('reason');
      final source = r.nullableObject('source');
      if (!{
            'HISTORICAL_MENU_RELEASE_UNAVAILABLE',
            'MENU_RELEASE_CHANGED',
            'CONFIGURATION_UNAVAILABLE'
          }.contains(reason) ||
          !r.contains('result') ||
          r.asMap()['result'] != null ||
          (reason == 'HISTORICAL_MENU_RELEASE_UNAVAILABLE') !=
              (source == null)) {
        throw const FormatException('Invalid unavailable food evidence.');
      }
      return UnavailableCartLineFood(
          reason: reason,
          source: source == null
              ? null
              : ReleasedFoodSource.fromJson(source.asMap()));
    }
    throw const FormatException('Unknown line food state.');
  }
}

/// Cart food evaluated against a released menu.
final class ConfiguredCartLineFood extends CartLineFoodEvidence {
  /// Creates configured line evidence.
  const ConfiguredCartLineFood(this.result) : super._();

  /// Server evaluation.
  final ConfiguredFoodEvaluation result;
}

/// Explicit unavailable food evidence, retaining a real source when possible.
final class UnavailableCartLineFood extends CartLineFoodEvidence {
  /// Creates unavailable evidence.
  const UnavailableCartLineFood({required this.reason, required this.source})
      : super._();

  /// Canonical unavailable reason.
  final String reason;

  /// Release source, null only for historical unavailable evidence.
  final ReleasedFoodSource? source;
}

/// Anonymous preview request for an accepted released configuration.
final class ConfigurationPreviewRequest {
  /// Creates a bounded preview payload.
  ConfigurationPreviewRequest(
      {required this.context,
      required this.quantity,
      required this.quantityUnit,
      required Iterable<SelectedModifierGroup> selections,
      required this.preferences})
      : selections = List.unmodifiable(selections) {
    if (quantity < 1 || quantity > 99 || this.selections.length > 50) {
      throw ArgumentError('Invalid preview quantity or selections.');
    }
  }

  /// Released menu context.
  final ReleasedMenuContext context;

  /// Requested unit count.
  final int quantity;

  /// Serving or tray units.
  final QuantityUnit quantityUnit;

  /// Nested modifier choices.
  final List<SelectedModifierGroup> selections;

  /// Guest preferences used only for advice.
  final DietaryPreferenceContext preferences;

  /// Only fields accepted by the configured-preview endpoint.
  Map<String, Object?> toJson() => {
        ...context.toJson(),
        'quantity': quantity,
        'quantityUnit': quantityUnit.wireValue,
        'selections': selections.map((v) => v.toJson()).toList(growable: false),
        'preferences': preferences.toJson()
      };
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/product.dart';
import '../models/scan_record.dart';

/// Strips a scanned barcode down to digits and returns it in the form the food
/// databases actually store.
///
/// A 12-digit UPC-A must be left-padded with a leading `0` to make an EAN-13,
/// because Open Food Facts stores US products in EAN-13 form. **This is the
/// single most common cause of spurious "product not found" results** — the
/// scanner hands back the 12 digits printed on the pack, OFF has the product
/// filed under 13, and the lookup misses a product that is right there in the
/// database.
///
/// The raw digits are still worth trying as a second attempt: a handful of
/// records are filed under the unpadded UPC, and EAN-8 / EAN-13 codes must be
/// passed through untouched.
String normaliseBarcode(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 12) return '0$digits';
  return digits;
}

/// Two-tier barcode lookup: Open Food Facts first (global, crowd-sourced,
/// carries structured allergen tags), USDA FoodData Central as a US-only
/// fallback for the branded products OFF has never seen.
class FoodApi {
  FoodApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Open Food Facts asks every client to identify itself; requests without a
  /// User-Agent get throttled or blocked outright.
  static const String userAgent =
      'FlyAllergySafe/1.0 (github.com/flyallergysafe)';

  /// USDA's shared DEMO_KEY is rate-limited to 30 requests/hour. A free key
  /// from https://fdc.nal.usda.gov/api-key-signup lifts that to 1000/hour.
  static const String usdaApiKey = 'DEMO_KEY';

  static const Duration _timeout = Duration(seconds: 8);

  static const String _offFields =
      'code,product_name,product_name_en,brands,quantity,image_front_small_url,'
      'ingredients_text,ingredients_text_en,lang,allergens_tags,traces_tags,'
      'additives_tags,labels_tags,states_tags';

  /// Looks a barcode up, trying the EAN-13-padded form before the raw digits,
  /// and falling back to USDA only when Open Food Facts genuinely has no record.
  Future<ScanOutcome> lookup(String barcode) async {
    final candidates = _candidates(barcode);
    if (candidates.isEmpty) {
      return const ScanOutcome(
        status: ScanStatus.notFound,
        message: 'That barcode has no digits in it.',
      );
    }

    var sawNetworkFailure = false;

    for (final code in candidates) {
      final outcome = await _openFoodFacts(code);
      if (outcome.hasProduct) return outcome;
      if (outcome.status == ScanStatus.offline ||
          outcome.status == ScanStatus.error) {
        sawNetworkFailure = true;
      }
    }

    // Only reach for USDA once OFF has said "not found" cleanly. If the network
    // was the problem, report that instead — offline is a recoverable state and
    // the caller may still have a cached answer worth showing.
    if (sawNetworkFailure) {
      return const ScanOutcome(
        status: ScanStatus.offline,
        message: 'No connection to the food databases.',
      );
    }

    for (final code in candidates) {
      final usda = await _usda(code);
      if (usda.hasProduct) return usda;
    }

    return const ScanOutcome.notFound();
  }

  /// The padded form first, then the raw digits, without duplicates.
  List<String> _candidates(String raw) {
    final normalised = normaliseBarcode(raw);
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final out = <String>[];
    if (normalised.isNotEmpty) out.add(normalised);
    if (digits.isNotEmpty && digits != normalised) out.add(digits);
    return out;
  }

  Future<ScanOutcome> _openFoodFacts(String code) async {
    final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$code.json'
      '?fields=$_offFields&lc=en&cc=us&tags_lc=en',
    );

    try {
      final res = await _client
          .get(uri, headers: const {'User-Agent': userAgent})
          .timeout(_timeout);

      if (res.statusCode >= 500) {
        return const ScanOutcome(
          status: ScanStatus.error,
          message: 'Open Food Facts is not responding.',
        );
      }
      if (res.statusCode != 200) {
        // v2 answers 404 for some malformed codes; treat it as simply absent.
        return const ScanOutcome.notFound();
      }

      final root = jsonDecode(res.body);
      if (root is! Map<String, dynamic>) return const ScanOutcome.notFound();

      // v2 returns HTTP 200 with `status: 0` for an unknown barcode, so the
      // HTTP code tells us nothing — the `status` field is the real answer.
      if (_asInt(root['status']) != 1) return const ScanOutcome.notFound();

      final raw = root['product'];
      if (raw is! Map<String, dynamic>) return const ScanOutcome.notFound();

      return ScanOutcome.found(_productFromOff(code, raw));
    } on TimeoutException {
      return const ScanOutcome(
        status: ScanStatus.offline,
        message: 'The lookup timed out.',
      );
    } on SocketException {
      return const ScanOutcome(
        status: ScanStatus.offline,
        message: 'No connection.',
      );
    } on http.ClientException {
      return const ScanOutcome(
        status: ScanStatus.offline,
        message: 'No connection.',
      );
    } on FormatException {
      return const ScanOutcome(
        status: ScanStatus.error,
        message: 'Unreadable response from Open Food Facts.',
      );
    }
  }

  Product _productFromOff(String code, Map<String, dynamic> p) {
    final states = _asTags(p['states_tags']);

    // Prefer the English ingredient text when OFF has one; fall back to the
    // product's own language rather than showing nothing.
    final english = _asString(p['ingredients_text_en']);
    final native = _asString(p['ingredients_text']);
    final ingredients = (english != null && english.trim().isNotEmpty)
        ? english
        : native;

    final nameEn = _asString(p['product_name_en']);
    final name = (nameEn != null && nameEn.trim().isNotEmpty)
        ? nameEn
        : (_asString(p['product_name']) ?? '');

    return Product(
      barcode: _asString(p['code']) ?? code,
      name: name,
      brand: _asString(p['brands']),
      quantity: _asString(p['quantity']),
      imageUrl: _asString(p['image_front_small_url']),
      ingredientsText: ingredients,
      ingredientsLanguage: english != null && english.trim().isNotEmpty
          ? 'en'
          : _asString(p['lang']),
      allergenTags: _asTags(p['allergens_tags']),
      tracesTags: _asTags(p['traces_tags']),
      additivesTags: _asTags(p['additives_tags']),
      labelsTags: _asTags(p['labels_tags']),
      source: ProductSource.openFoodFacts,
      // Without this flag an empty allergen list means nothing at all: the
      // record may simply be half-entered.
      ingredientsComplete: states.contains('en:ingredients-completed'),
      fetchedAt: DateTime.now(),
    );
  }

  /// USDA FoodData Central, US branded foods only.
  ///
  /// Any failure here — rate limit, bad key, network — is reported as a plain
  /// "not found". The user is standing in a shop; an API key error is not an
  /// answer they can do anything with.
  Future<ScanOutcome> _usda(String code) async {
    final uri = Uri.parse(
      'https://api.nal.usda.gov/fdc/v1/foods/search'
      '?query=$code&dataType=Branded&pageSize=1&api_key=$usdaApiKey',
    );

    try {
      final res = await _client.get(uri).timeout(_timeout);
      if (res.statusCode != 200) return const ScanOutcome.notFound();

      final root = jsonDecode(res.body);
      if (root is! Map<String, dynamic>) return const ScanOutcome.notFound();

      final foods = root['foods'];
      if (foods is! List || foods.isEmpty) return const ScanOutcome.notFound();

      final f = foods.first;
      if (f is! Map<String, dynamic>) return const ScanOutcome.notFound();
      final returnedCode = _asString(f['gtinUpc'])?.trim();
      if (returnedCode == null ||
          !RegExp(r'^\d{8,14}$').hasMatch(returnedCode) ||
          returnedCode.padLeft(14, '0') != code.padLeft(14, '0')) {
        return const ScanOutcome.notFound();
      }

      final ingredients = _asString(f['ingredients']);
      final description = _asString(f['description']) ?? '';

      return ScanOutcome.found(
        Product(
          barcode: _asString(f['gtinUpc'])?.trim().isNotEmpty == true
              ? _asString(f['gtinUpc'])!.trim()
              : code,
          name: description,
          brand: _asString(f['brandOwner']),
          ingredientsText: ingredients,
          // USDA publishes no allergen tag array, so every allergen decision
          // here has to come out of the ingredient text.
          allergenTags: const [],
          tracesTags: const [],
          source: ProductSource.usda,
          ingredientsComplete:
              ingredients != null && ingredients.trim().isNotEmpty,
          fetchedAt: DateTime.now(),
        ),
      );
    } on TimeoutException {
      return const ScanOutcome.notFound();
    } on SocketException {
      return const ScanOutcome.notFound();
    } on http.ClientException {
      return const ScanOutcome.notFound();
    } on FormatException {
      return const ScanOutcome.notFound();
    }
  }

  void dispose() => _client.close();

  static String? _asString(Object? v) => v is String ? v : null;

  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static List<String> _asTags(Object? v) {
    if (v is! List) return const [];
    return v.whereType<String>().where((e) => e.trim().isNotEmpty).toList();
  }
}

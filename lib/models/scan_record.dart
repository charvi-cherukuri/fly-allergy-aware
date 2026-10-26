import 'product.dart';
import 'verdict.dart';

/// A past scan, kept locally forever. Because every scan is cached, a product
/// you have scanned once resolves instantly and works with no signal at all —
/// on a plane, in a basement supermarket, abroad.
class ScanRecord {
  const ScanRecord({
    required this.id,
    required this.product,
    required this.level,
    required this.headline,
    required this.scannedAt,
    required this.profileId,
    this.saved = false,
  });

  final String id;
  final Product product;
  final VerdictLevel level;
  final String headline;
  final DateTime scannedAt;
  final String profileId;

  /// Pinned to the user's own safe list.
  final bool saved;

  ScanRecord copyWith({bool? saved}) => ScanRecord(
        id: id,
        product: product,
        level: level,
        headline: headline,
        scannedAt: scannedAt,
        profileId: profileId,
        saved: saved ?? this.saved,
      );
}

/// What a barcode lookup produced.
enum ScanStatus {
  /// Fetched live from a food database.
  found,

  /// Served from the local cache — either offline, or already seen.
  foundCached,

  /// The barcode is not in any database we can reach. This is the single most
  /// common functional failure in the category, so it gets a real UI path
  /// (photograph the label instead) rather than a dead end.
  notFound,

  /// No connectivity and nothing cached.
  offline,

  error,
}

class ScanOutcome {
  const ScanOutcome({required this.status, this.product, this.message});

  final ScanStatus status;
  final Product? product;
  final String? message;

  bool get hasProduct => product != null;

  const ScanOutcome.found(Product p)
      : status = ScanStatus.found,
        product = p,
        message = null;

  const ScanOutcome.cached(Product p)
      : status = ScanStatus.foundCached,
        product = p,
        message = null;

  const ScanOutcome.notFound()
      : status = ScanStatus.notFound,
        product = null,
        message = null;
}

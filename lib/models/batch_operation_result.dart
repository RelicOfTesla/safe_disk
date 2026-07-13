class BatchOperationFailure {
  const BatchOperationFailure({required this.name, required this.reason});

  final String name;
  final String reason;
}

class BatchOperationResult {
  const BatchOperationResult({
    required this.total,
    required this.succeeded,
    required this.skipped,
    required this.failures,
    required this.unprocessed,
    required this.remaining,
    required this.cancelled,
  });

  final int total;
  final int succeeded;
  final int skipped;
  final List<BatchOperationFailure> failures;
  final int unprocessed;
  final int remaining;
  final bool cancelled;

  int get failed => failures.length;
}

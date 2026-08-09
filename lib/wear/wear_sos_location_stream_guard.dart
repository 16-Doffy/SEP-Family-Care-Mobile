class WearSosLocationStreamGuard {
  WearSosLocationStreamGuard({this.maxConsecutiveFailures = 3});

  final int maxConsecutiveFailures;
  int _consecutiveFailures = 0;

  int get consecutiveFailures => _consecutiveFailures;

  bool recordFailure() {
    _consecutiveFailures++;
    return _consecutiveFailures >= maxConsecutiveFailures;
  }

  void recordSuccess() {
    _consecutiveFailures = 0;
  }

  void reset() {
    _consecutiveFailures = 0;
  }
}

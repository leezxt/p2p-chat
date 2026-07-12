abstract class PeerAdapter {
  Stream<Map<String, Object?>> get iceCandidates;
  Stream<String> get messages;
  Future<Map<String, Object?>> createOffer();
  Future<Map<String, Object?>> acceptOffer(Map<String, Object?> offer);
  Future<void> acceptAnswer(Map<String, Object?> answer);
  Future<void> addIceCandidate(Map<String, Object?> candidate);
  Future<void> waitUntilReady(Duration timeout);
  Future<void> send(String message);
  Future<void> close();
}

typedef PeerAdapterFactory = Future<PeerAdapter> Function(
    String sessionId, bool initiator);

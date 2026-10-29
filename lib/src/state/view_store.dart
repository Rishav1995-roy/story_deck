import '../models/story_models.dart';

/// Where a group starts when it is opened again.
enum StoryResumeMode {
  /// Always from the first item.
  restart,

  /// At the item the viewer was on last (default). A group that was watched to
  /// the end starts over.
  lastViewed,

  /// At the first item the viewer has not seen yet; from the start when all
  /// were seen.
  firstUnseen,
}

/// Remembers what the viewer has seen and where each group was left.
///
/// The default [MemoryStoryViewStore] keeps it in memory. Implement this to
/// persist it (shared preferences, a database, your backend).
abstract interface class StoryViewStore {
  /// Item index the viewer was last on in [groupId], or `null`.
  int? lastIndex(String groupId);

  /// Remembers the item index in [groupId].
  void setLastIndex(String groupId, int index);

  /// Whether [itemId] of [groupId] was seen.
  bool isSeen(String groupId, String itemId);

  /// Marks [itemId] of [groupId] as seen.
  void markSeen(String groupId, String itemId);
}

/// In-memory [StoryViewStore] with plain-map export for persistence.
class MemoryStoryViewStore implements StoryViewStore {
  /// Creates a store, optionally restored from [toJson] output.
  MemoryStoryViewStore([Map<String, Object?>? json]) {
    final last = json?['last'];
    if (last is Map) {
      last.forEach((k, v) {
        if (v is int) _last['$k'] = v;
      });
    }
    final seen = json?['seen'];
    if (seen is Map) {
      seen.forEach((k, v) {
        if (v is List) _seen['$k'] = v.map((e) => '$e').toSet();
      });
    }
  }

  final Map<String, int> _last = <String, int>{};
  final Map<String, Set<String>> _seen = <String, Set<String>>{};

  @override
  int? lastIndex(String groupId) => _last[groupId];

  @override
  void setLastIndex(String groupId, int index) => _last[groupId] = index;

  @override
  bool isSeen(String groupId, String itemId) =>
      _seen[groupId]?.contains(itemId) ?? false;

  @override
  void markSeen(String groupId, String itemId) =>
      (_seen[groupId] ??= <String>{}).add(itemId);

  /// A JSON-encodable snapshot.
  Map<String, Object?> toJson() => <String, Object?>{
        'last': Map<String, int>.of(_last),
        'seen': _seen.map((k, v) => MapEntry(k, v.toList())),
      };
}

/// The item index [group] should start at, given [store] and [mode].
int resolveStartIndex(
  StoryGroup group,
  StoryViewStore store,
  StoryResumeMode mode,
) {
  final last = group.items.length - 1;
  switch (mode) {
    case StoryResumeMode.restart:
      return 0;
    case StoryResumeMode.lastViewed:
      return (store.lastIndex(group.id) ?? 0).clamp(0, last);
    case StoryResumeMode.firstUnseen:
      for (var i = 0; i <= last; i++) {
        if (!store.isSeen(group.id, group.items[i].id)) return i;
      }
      return 0;
  }
}

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Faceless AI — Realtime Service
/// Subscribes to project status/progress changes via Supabase Realtime
class RealtimeService {
  RealtimeService._();

  static RealtimeChannel? _projectChannel;

  /// Listen to render progress updates for a specific project
  static Stream<Map<String, dynamic>> watchProject(String projectId) {
    final controller = StreamController<Map<String, dynamic>>.broadcast();

    _projectChannel?.unsubscribe();

    _projectChannel = SupabaseService.client
        .channel('project-$projectId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'projects',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: projectId,
          ),
          callback: (payload) {
            controller.add(payload.newRecord);
          },
        )
        .subscribe();

    return controller.stream;
  }

  /// Stop listening to project updates
  static Future<void> stopWatching() async {
    await _projectChannel?.unsubscribe();
    _projectChannel = null;
  }

  /// Listen to all projects for the current user (home screen)
  static Stream<Map<String, dynamic>> watchUserProjects() {
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    final userId = SupabaseService.userId;
    if (userId == null) return controller.stream;

    final channel = SupabaseService.client
        .channel('user-projects-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'projects',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            controller.add({
              'event': payload.eventType.name,
              'old': payload.oldRecord,
              'new': payload.newRecord,
            });
          },
        )
        .subscribe();

    controller.onCancel = () => channel.unsubscribe();
    return controller.stream;
  }
}
